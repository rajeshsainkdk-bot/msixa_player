import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../theme/app_colors.dart';
import 'visualizer_bars.dart';

class SongThumbnailWidget extends StatelessWidget {
  final Song song;
  final double size;
  final double borderRadius;
  final bool isPlaying;
  final bool showVisualizerWhenPlaying;

  const SongThumbnailWidget({
    Key? key,
    required this.song,
    this.size = 50,
    this.borderRadius = 12,
    this.isPlaying = false,
    this.showVisualizerWhenPlaying = true,
  }) : super(key: key);

  /// Generates deterministic, vibrant gradient pairs based on song metadata
  static List<Color> getGradientForSong(Song song) {
    final genreLower = song.genre.toLowerCase();
    if (genreLower.contains('rajasthan') || genreLower.contains('marwadi')) {
      return const [Color(0xFFFF6D00), Color(0xFFFFAB00)];
    } else if (genreLower.contains('bhakti') || genreLower.contains('ram') || genreLower.contains('shyam') || genreLower.contains('krishna')) {
      return const [Color(0xFFFF9100), Color(0xFFFF3D00)];
    } else if (genreLower.contains('dj') || genreLower.contains('remix') || genreLower.contains('dance')) {
      return const [Color(0xFF00E5FF), Color(0xFF7C4DFF)];
    } else if (genreLower.contains('haryanvi') || genreLower.contains('ragni')) {
      return const [Color(0xFF00C853), Color(0xFF64DD17)];
    } else if (genreLower.contains('punjabi') || genreLower.contains('sufi')) {
      return const [Color(0xFFFFD600), Color(0xFFFF6D00)];
    } else if (genreLower.contains('bollywood') || genreLower.contains('romance')) {
      return const [Color(0xFFFF1744), Color(0xFFD500F9)];
    } else if (genreLower.contains('lo-fi') || genreLower.contains('ghazal')) {
      return const [Color(0xFF651FFF), Color(0xFF3D5AFE)];
    }

    final hash = (song.title + song.artist + song.genre).hashCode.abs();
    final palettes = [
      const [Color(0xFF00E5FF), Color(0xFF3B82F6)],
      const [Color(0xFFEC4899), Color(0xFF8B5CF6)],
      const [Color(0xFFF59E0B), Color(0xFFEF4444)],
      const [Color(0xFF10B981), Color(0xFF06B6D4)],
      const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
      const [Color(0xFFFF6D00), Color(0xFFFFAB00)],
    ];
    return palettes[hash % palettes.length];
  }

  static IconData getIconForGenre(String genre) {
    final g = genre.toLowerCase();
    if (g.contains('bhakti') || g.contains('ram') || g.contains('shyam')) {
      return Icons.wb_sunny_rounded;
    } else if (g.contains('dj') || g.contains('remix')) {
      return Icons.speaker_group_rounded;
    } else if (g.contains('rajasthan')) {
      return Icons.palette_rounded;
    } else if (g.contains('lo-fi')) {
      return Icons.nightlight_round;
    } else if (g.contains('bollywood')) {
      return Icons.movie_filter_rounded;
    }
    return Icons.music_note_rounded;
  }

  Widget _buildProceduralArt(BuildContext context) {
    final gradient = getGradientForSong(song);
    final icon = getIconForGenre(song.genre);
    final initial = song.title.trim().isNotEmpty ? song.title.trim()[0].toUpperCase() : '🎵';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Icon Watermark
          Positioned(
            right: -size * 0.1,
            bottom: -size * 0.1,
            child: Icon(
              icon,
              size: size * 0.65,
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          // Center Initial Letter / Musical Character
          Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(
                  color: Colors.black45,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    final url = song.coverUrl.trim();

    if (url.startsWith('http')) {
      content = CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildProceduralArt(context),
        errorWidget: (_, __, ___) => _buildProceduralArt(context),
      );
    } else if (url.startsWith('/') || url.startsWith('file://')) {
      final filePath = url.replaceFirst('file://', '');
      final f = File(filePath);
      if (f.existsSync()) {
        content = Image.file(
          f,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildProceduralArt(context),
        );
      } else {
        content = _buildProceduralArt(context);
      }
    } else {
      content = _buildProceduralArt(context);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox(
            width: size,
            height: size,
            child: content,
          ),
        ),
        if (isPlaying && showVisualizerWhenPlaying)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: VisualizerBars(
                isPlaying: true,
                maxHeight: size * 0.4,
                barWidth: 3,
              ),
            ),
          ),
      ],
    );
  }
}

