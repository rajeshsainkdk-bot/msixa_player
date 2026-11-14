import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_item.dart';

/// Service responsible for scanning, filtering, and launching local device videos in Msixa.
class DeviceVideoService {
  static const MethodChannel _channel = MethodChannel('com.msixa.player/app_share');
  static bool _hasRequestedPermissionThisSession = false;

  /// Check whether video or storage permission is already granted without prompting
  static Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final videoStatus = await Permission.videos.status;
      if (videoStatus.isGranted) return true;
      final storageStatus = await Permission.storage.status;
      return storageStatus.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Request runtime permission for video access across Android versions
  /// Only prompts if not already granted and has not been prompted in this session
  static Future<bool> requestVideoPermission({bool forcePrompt = false}) async {
    if (Platform.isAndroid) {
      try {
        final alreadyGranted = await hasPermission();
        if (alreadyGranted) return true;

        if (!forcePrompt && _hasRequestedPermissionThisSession) {
          return false;
        }

        final videoStatus = await Permission.videos.status;
        final storageStatus = await Permission.storage.status;
        if (!forcePrompt && (videoStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied)) {
          return false;
        }

        _hasRequestedPermissionThisSession = true;
        final videoReq = await Permission.videos.request();
        if (videoReq.isGranted) return true;

        if (!videoReq.isPermanentlyDenied) {
          final storageReq = await Permission.storage.request();
          return storageReq.isGranted;
        }
        return false;
      } catch (_) {
        return true;
      }
    }
    return true;
  }

  /// Query all video files present on the device MediaStore
  static Future<List<VideoItem>> fetchDeviceVideos() async {
    final List<VideoItem> videos = [];

    // 1. Try Native Android MediaStore query (Fastest & most complete)
    try {
      final res = await _channel.invokeMethod('queryDeviceVideos');
      if (res is List) {
        for (final item in res) {
          if (item is Map) {
            videos.add(VideoItem.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
    } catch (_) {
      // MethodChannel fallback
    }

    // 2. If MediaStore returned empty, scan storage directories
    if (videos.isEmpty && Platform.isAndroid) {
      videos.addAll(await _scanStorageDirectories());
    }

    return videos;
  }

  /// Scan typical storage paths as fallback
  static Future<List<VideoItem>> _scanStorageDirectories() async {
    final List<VideoItem> found = [];
    final supportedExtensions = {'.mp4', '.mkv', '.webm', '.avi', '.3gp', '.mov', '.flv'};

    final candidatePaths = [
      '/storage/emulated/0/DCIM/Camera',
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
      '/storage/emulated/0/Telegram/Telegram Video',
      '/storage/emulated/0/Pictures',
    ];

    for (final path in candidatePaths) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) {
          final entities = dir.listSync(recursive: false, followLinks: false);
          for (final entity in entities) {
            if (entity is File) {
              final ext = entity.path.substring(entity.path.lastIndexOf('.')).toLowerCase();
              if (supportedExtensions.contains(ext)) {
                final stat = entity.statSync();
                final fileName = entity.path.split(Platform.pathSeparator).last;
                final folderName = path.split(Platform.pathSeparator).last;
                found.add(VideoItem(
                  id: entity.path,
                  title: fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
                  displayName: fileName,
                  path: entity.path,
                  duration: 0,
                  size: stat.size,
                  resolution: 'HD',
                  folder: folderName.isEmpty ? 'Videos' : folderName,
                  dateAdded: stat.modified.millisecondsSinceEpoch ~/ 1000,
                ));
              }
            }
          }
        }
      } catch (_) {}
    }

    return found;
  }

  /// Pick custom video from file explorer
  static Future<VideoItem?> pickCustomVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final name = result.files.single.name;
        final size = await file.length();
        return VideoItem(
          id: file.path,
          title: name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
          displayName: name,
          path: file.path,
          duration: 0,
          size: size,
          resolution: 'Video',
          folder: 'Picked',
          dateAdded: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Open video with system external player (MX Player, VLC, Samsung Video, etc.)
  static Future<void> openExternalPlayer(String path, {String? id}) async {
    try {
      await _channel.invokeMethod('openVideoWithApp', {
        'path': path,
        'id': id,
      });
    } catch (_) {}
  }

  static final Map<String, Uint8List?> _thumbnailMemoryCache = {};
  static final Map<String, Future<Uint8List?>> _inFlightThumbnails = {};

  /// Synchronously retrieve cached thumbnail if already loaded into memory
  static Uint8List? getCachedThumbnail(String path, {String? id}) {
    final key = '$id:$path';
    return _thumbnailMemoryCache[key];
  }

  /// Asynchronously retrieve video thumbnail bytes from memory, disk cache, or native extractor
  static Future<Uint8List?> getVideoThumbnail(String path, {String? id}) async {
    final key = '$id:$path';
    if (_thumbnailMemoryCache.containsKey(key)) {
      return _thumbnailMemoryCache[key];
    }
    if (_inFlightThumbnails.containsKey(key)) {
      return await _inFlightThumbnails[key];
    }

    final future = _loadThumbnailInternal(path, id: id, key: key);
    _inFlightThumbnails[key] = future;
    final res = await future;
    _inFlightThumbnails.remove(key);
    return res;
  }

  static Future<Uint8List?> _loadThumbnailInternal(String path, {String? id, required String key}) async {
    try {
      // 1. Check disk cache in system temporary directory
      final tempDir = Directory.systemTemp;
      final fileHash = (key.hashCode).abs();
      final diskFile = File('${tempDir.path}/vthumb_$fileHash.jpg');

      if (await diskFile.exists()) {
        final bytes = await diskFile.readAsBytes();
        if (bytes.isNotEmpty) {
          _thumbnailMemoryCache[key] = bytes;
          return bytes;
        }
      }

      // 2. Request from native platform MethodChannel
      final nativeBytes = await _channel.invokeMethod<Uint8List>('getVideoThumbnail', {
        'path': path,
        'id': id,
      });

      if (nativeBytes != null && nativeBytes.isNotEmpty) {
        _thumbnailMemoryCache[key] = nativeBytes;
        try {
          await diskFile.writeAsBytes(nativeBytes, flush: true);
        } catch (_) {}
        return nativeBytes;
      }
    } catch (_) {}

    _thumbnailMemoryCache[key] = null;
    return null;
  }

  /// Group video list by folder name with counts
  static Map<String, List<VideoItem>> groupVideosByFolder(List<VideoItem> videos) {
    final Map<String, List<VideoItem>> map = {};
    for (final v in videos) {
      final folder = v.folder.isEmpty ? 'Videos' : v.folder;
      map.putIfAbsent(folder, () => []).add(v);
    }
    return map;
  }
}

