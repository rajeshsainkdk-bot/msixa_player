import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/short_video_item.dart';

class ShortsService {
  static final ShortsService _instance = ShortsService._internal();
  factory ShortsService() => _instance;
  ShortsService._internal();

  static const MethodChannel _channel = MethodChannel('com.msixa.player/app_share');
  final Map<String, String> _streamCache = {};

  // Curated initial catalog for zero-latency instant startup
  static final List<ShortVideoItem> _curatedShorts = [
    ShortVideoItem(
      id: 'marwadi_sample_1',
      title: 'Rajasthani Desi Dhol Thali Dance • मारवाड़ी विवाह डांस शॉर्ट्स',
      author: 'Marwadi Folk Beats',
      thumbnailUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&fit=crop',
      category: 'Marwadi',
      likesCount: 24500,
      shareCount: 6800,
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    ),
    ShortVideoItem(
      id: 'dj_remix_sample_2',
      title: 'Full Bass DJ Remix Status • न्यू डीजे रीमिक्स सॉन्ग स्टेटस',
      author: 'DJ Bass King',
      thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&fit=crop',
      category: 'DJ Remix',
      likesCount: 38900,
      shareCount: 12400,
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    ),
    ShortVideoItem(
      id: 'haryanvi_sample_3',
      title: 'Haryanvi Ragni & Desi Beats Status • हरियाणवी वायरल शॉर्ट्स',
      author: 'Desi Haryanvi Swag',
      thumbnailUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&fit=crop',
      category: 'Haryanvi',
      likesCount: 19200,
      shareCount: 4300,
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    ),
    ShortVideoItem(
      id: 'bhakti_sample_4',
      title: 'Har Har Mahadev Shiv Tandav Status • महाकाल व्हाट्सएप स्टेटस',
      author: 'Bhakti Sagar Music',
      thumbnailUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&fit=crop',
      category: 'Bhakti',
      likesCount: 52100,
      shareCount: 28900,
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyBlazes.mp4',
    ),
    ShortVideoItem(
      id: 'romantic_sample_5',
      title: 'Slowed & Reverb Romantic Acoustic Status • दिल छू लेने वाला स्टेटस',
      author: 'Soulful Melody',
      thumbnailUrl: 'https://images.unsplash.com/photo-1518895949257-7621c3c786d7?w=600&fit=crop',
      category: 'Romantic',
      likesCount: 31400,
      shareCount: 8900,
      streamUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
    ),
  ];

  /// Resolves direct .mp4 media stream URL on-the-fly without login
  Future<String?> resolveStreamUrl(String videoId) async {
    if (_streamCache.containsKey(videoId)) {
      return _streamCache[videoId];
    }

    // Check if it's already a direct http URL
    if (videoId.startsWith('http://') || videoId.startsWith('https://')) {
      _streamCache[videoId] = videoId;
      return videoId;
    }

    // Use YoutubeExplode for direct clean MP4 stream extraction
    YoutubeExplode? yt;
    try {
      yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(
        const Duration(seconds: 7),
      );
      final muxedStreams = manifest.muxed.sortByVideoQuality();
      if (muxedStreams.isNotEmpty) {
        final url = muxedStreams.first.url.toString();
        _streamCache[videoId] = url;
        return url;
      }
    } catch (_) {
      // In case of any extractor timeout, return null or fallback
    } finally {
      yt?.close();
    }
    return null;
  }

  /// Searches Shorts across all genres without user login
  Future<List<ShortVideoItem>> searchShorts(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    YoutubeExplode? yt;
    try {
      yt = YoutubeExplode();
      final searchFilter = cleanQuery.toLowerCase().contains('short') ? cleanQuery : '$cleanQuery shorts';
      final results = await yt.search.search(searchFilter, filter: TypeFilters.video).timeout(
        const Duration(seconds: 7),
      );

      final List<ShortVideoItem> items = [];
      for (final v in results.take(25)) {
        items.add(
          ShortVideoItem(
            id: v.id.value,
            title: v.title,
            author: v.author,
            thumbnailUrl: v.thumbnails.highResUrl,
            duration: v.duration ?? const Duration(seconds: 30),
            category: 'Search',
            likesCount: 1500 + (v.title.length * 73) % 45000,
            shareCount: 400 + (v.title.length * 29) % 12000,
          ),
        );
      }
      return items;
    } catch (_) {
      // Fallback search in curated items
      final q = cleanQuery.toLowerCase();
      return _curatedShorts.where((s) => s.title.toLowerCase().contains(q) || s.category.toLowerCase().contains(q)).toList();
    } finally {
      yt?.close();
    }
  }

  /// Gets Shorts by Category
  Future<List<ShortVideoItem>> getShortsByCategory(String category) async {
    final List<ShortVideoItem> baseList = _curatedShorts.where((s) {
      if (category == 'Trending' || category == 'All') return true;
      return s.category.toLowerCase() == category.toLowerCase();
    }).toList();

    // Query query string based on category
    String querySearch = 'trending shorts hindi';
    switch (category.toLowerCase()) {
      case 'marwadi':
      case 'rajasthani':
        querySearch = 'marwadi rajasthani shorts status';
        break;
      case 'dj remix':
      case 'dj':
        querySearch = 'dj remix bass boosted status shorts';
        break;
      case 'haryanvi':
        querySearch = 'haryanvi trending status shorts';
        break;
      case 'bhakti':
        querySearch = 'mahadev bhakti shorts status';
        break;
      case 'romantic':
        querySearch = 'romantic love status shorts slowed';
        break;
      default:
        querySearch = 'trending indian shorts status';
        break;
    }

    try {
      final onlineResults = await searchShorts(querySearch);
      if (onlineResults.isNotEmpty) {
        return [...baseList, ...onlineResults];
      }
    } catch (_) {}

    return baseList.isNotEmpty ? baseList : _curatedShorts;
  }

  /// Downloads Short Video to device storage with progress callback
  Future<String?> downloadShort(ShortVideoItem item, {Function(double progress)? onProgress}) async {
    try {
      // 1. Resolve direct stream URL
      String? streamUrl = item.streamUrl;
      if (streamUrl == null || streamUrl.isEmpty) {
        streamUrl = await resolveStreamUrl(item.id);
      }
      if (streamUrl == null || streamUrl.isEmpty) {
        return null;
      }

      // 2. Prepare destination path
      Directory saveDir = Directory('/storage/emulated/0/Download/Msixa/Shorts');
      if (!await saveDir.exists()) {
        try {
          await saveDir.create(recursive: true);
        } catch (_) {
          saveDir = Directory('${Directory.systemTemp.path}/msixa_shorts');
          if (!await saveDir.exists()) await saveDir.create(recursive: true);
        }
      }

      final cleanName = item.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = 'msixa_${item.id}_${cleanName.take(20)}.mp4';
      final targetFile = File('${saveDir.path}/$fileName');

      if (await targetFile.exists() && await targetFile.length() > 10000) {
        item.isDownloaded = true;
        item.localPath = targetFile.path;
        onProgress?.call(1.0);
        return targetFile.path;
      }

      // 3. Download bytes with progress reporting
      final request = http.Request('GET', Uri.parse(streamUrl));
      final response = await http.Client().send(request);
      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;

      final sink = targetFile.openWrite();
      await response.stream.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes);
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      item.isDownloaded = true;
      item.localPath = targetFile.path;

      // 4. Register in Android MediaStore
      try {
        await _channel.invokeMethod('scanMediaFile', {'path': targetFile.path});
      } catch (_) {}

      return targetFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Directly triggers WhatsApp Status posting with native 1-tap intent
  Future<bool> shareToWhatsAppStatus(ShortVideoItem item, {Function(double progress)? onProgress}) async {
    try {
      String? localPath = item.localPath;

      // Ensure file is cached locally
      if (localPath == null || !File(localPath).existsSync()) {
        localPath = await downloadShort(item, onProgress: onProgress);
      }

      if (localPath == null || !File(localPath).existsSync()) {
        return false;
      }

      // Trigger native WhatsApp Status intent
      final bool? success = await _channel.invokeMethod<bool>('shareToWhatsAppStatus', {
        'videoPath': localPath,
      });

      return success ?? true;
    } catch (_) {
      return false;
    }
  }
}

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
