import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_item.dart';

/// Service responsible for scanning, filtering, and launching local device videos in Msixa.
class DeviceVideoService {
  static const MethodChannel _channel = MethodChannel('com.msixa.player/app_share');

  /// Request runtime permission for video access across Android versions
  static Future<bool> requestVideoPermission() async {
    if (Platform.isAndroid) {
      try {
        final videoStatus = await Permission.videos.status;
        if (videoStatus.isGranted) return true;
        final videoReq = await Permission.videos.request();
        if (videoReq.isGranted) return true;

        final storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
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

