import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/video_item.dart';
import '../providers/player_provider.dart';
import '../screens/video_player_screen.dart';
import '../screens/now_playing_screen.dart';

/// Service that handles files opened externally in Msixa via Android's default file association
/// (e.g. tapping an audio or video in WhatsApp, File Manager, Telegram, Downloads).
class IntentService {
  static const MethodChannel _channel = MethodChannel('com.msixa.player/app_share');
  static bool _hasHandledInitial = false;

  /// Check if the application was launched to play an audio or video file
  static Future<void> checkInitialMedia(BuildContext context) async {
    if (_hasHandledInitial) return;
    _hasHandledInitial = true;

    try {
      final res = await _channel.invokeMethod('getInitialMediaUri');
      if (res is Map && res['uri'] != null) {
        final uri = res['uri'].toString();
        if (uri.isEmpty) return;

        final isAudio = res['isAudio'] == true;
        final isVideo = res['isVideo'] == true;
        final displayName = res['displayName']?.toString() ?? 'Media File';

        if (isVideo) {
          final video = VideoItem(
            id: uri,
            title: displayName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
            displayName: displayName,
            path: uri,
            duration: 0,
            size: 0,
            resolution: 'HD',
            folder: 'External Media',
          );

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video)),
            );
          }
        } else if (isAudio) {
          final song = Song(
            id: uri,
            title: displayName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
            artist: 'Default Player',
            album: 'Device Media',
            duration: 0,
            streamUrl: uri,
            coverUrl: '',
            genre: 'Offline Media',
          );

          if (context.mounted) {
            final provider = Provider.of<PlayerProvider>(context, listen: false);
            await provider.playSong(song);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
            );
          }
        }
      }
    } catch (_) {}
  }
}

