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

  /// Generates deterministic, vibrant studio gradient pairs based on song metadata
  static List<Color> getGradientForSong(Song song) {
    final genreLower = song.genre.toLowerCase();
    final titleLower = song.title.toLowerCase();

    if (genreLower.contains('rajasthan') || genreLower.contains('marwadi')) {
      return const [Color(0xFFFF5722), Color(0xFFFF9800), Color(0xFFFFC107)];
    } else if (genreLower.contains('bhakti') ||
        genreLower.contains('ram') ||
        genreLower.contains('shyam') ||
        genreLower.contains('krishna') ||
        titleLower.contains('hanuman') ||
        titleLower.contains('chalisa') ||
        genreLower.contains('spiritual')) {
      return const [Color(0xFFE65100), Color(0xFFFF6D00), Color(0xFFFFD54F)];
    } else if (genreLower.contains('dj') || genreLower.contains('remix') || genreLower.contains('dance')) {
      return const [Color(0xFF7C4DFF), Color(0xFF00E5FF), Color(0xFF00B0FF)];
    } else if (genreLower.contains('haryanvi') || genreLower.contains('ragni')) {
      return const [Color(0xFF1B5E20), Color(0xFF00C853), Color(0xFF64DD17)];
    } else if (genreLower.contains('punjabi') || genreLower.contains('sufi')) {
      return const [Color(0xFF4A148C), Color(0xFF8E24AA), Color(0xFFFF6D00)];
    } else if (genreLower.contains('bollywood') || genreLower.contains('romance')) {
      return const [Color(0xFF880E4F), Color(0xFFD81B60), Color(0xFFFF4081)];
    } else if (genreLower.contains('lo-fi') || genreLower.contains('ghazal')) {
      return const [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF3A86FF)];
    }

    final hash = (song.title + song.artist + song.genre).hashCode.abs();
    final palettes = [
      const [Color(0xFF0A192F), Color(0xFF00E5FF), Color(0xFF3B82F6)],
      const [Color(0xFF31103F), Color(0xFFEC4899), Color(0xFF8B5CF6)],
      const [Color(0xFF451A03), Color(0xFFF59E0B), Color(0xFFEF4444)],
      const [Color(0xFF022C22), Color(0xFF10B981), Color(0xFF06B6D4)],
      const [Color(0xFF1E1B4B), Color(0xFF8B5CF6), Color(0xFF6366F1)],
      const [Color(0xFF3E1F00), Color(0xFFFF6D00), Color(0xFFFFAB00)],
    ];
    return palettes[hash % palettes.length];
  }

  static IconData getIconForGenre(String genre) {
    final g = genre.toLowerCase();
    if (g.contains('bhakti') || g.contains('ram') || g.contains('shyam') || g.contains('spiritual')) {
      return Icons.flare_rounded;
    } else if (g.contains('dj') || g.contains('remix')) {
      return Icons.speaker_group_rounded;
    } else if (g.contains('rajasthan')) {
      return Icons.wb_sunny_rounded;
    } else if (g.contains('lo-fi')) {
      return Icons.nightlight_round;
    } else if (g.contains('bollywood')) {
      return Icons.movie_filter_rounded;
    } else if (g.contains('punjabi') || g.contains('sufi')) {
      return Icons.audiotrack_rounded;
    }
    return Icons.album_rounded;
  }

  /// Studio-Grade YouTube Music Style Dynamic Thumbnail Card
  Widget _buildYouTubeStyleCard(BuildContext context) {
    final gradient = getGradientForSong(song);
    final icon = getIconForGenre(song.genre);
    final isCompact = size <= 60;
    final cleanTitle = song.title.replaceAll(RegExp(r'\.(mp3|m4a|wav|aac|flac)$', caseSensitive: false), '').trim();
    final cleanArtist = song.artist.trim().isNotEmpty ? song.artist.trim() : 'Msixa Music';
    final genreTag = song.genre.toUpperCase();

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
            color: gradient.first.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.20),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Ambient Background Pattern & Watermark Icon
            Positioned(
              right: -size * 0.15,
              bottom: -size * 0.15,
              child: Icon(
                icon,
                size: size * 0.72,
                color: Colors.white.withOpacity(0.14),
              ),
            ),

            // Layer 2: Subtle Vinyl Grooves Texture
            Positioned.fill(
              child: CustomPaint(
                painter: _VinylGroovesPainter(),
              ),
            ),

            // Layer 3: Dark Vignette Gradient for high readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.65),
                    ],
                  ),
                ),
              ),
            ),

            // Layer 4: Top Studio Pill (e.g. "HD", "MASTER")
            Positioned(
              top: isCompact ? 3 : 6,
              left: isCompact ? 3 : 6,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 3 : 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Text(
                  genreTag.length > 7 ? genreTag.substring(0, 7) : genreTag,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: isCompact ? 5.5 : 7.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),

            // Layer 5: Main Content Typography (YouTube Music Thumbnail Look)
            if (isCompact)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        cleanTitle,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size * 0.16,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cleanArtist,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: size * 0.11,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cleanTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.09,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cleanArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: size * 0.065,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Layer 6: Mini Audio Wave Indicator at bottom
            Positioned(
              bottom: 2,
              right: 4,
              child: Icon(
                Icons.graphic_eq_rounded,
                size: isCompact ? 10 : 16,
                color: Colors.white.withOpacity(0.70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Detects legacy hardcoded microphone placeholder from Unsplash or generic fallbacks
  static bool isGenericMicUrl(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    final u = url.trim().toLowerCase();
    return u.contains('1511671782779') ||
        u.contains('photo-1511671782779') ||
        u.contains('1493225457124') ||
        u.contains('placeholder') ||
        u.contains('default_cover') ||
        u == 'null';
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    final url = song.coverUrl.trim();
    final effectiveHttpUrl = (url.startsWith('http') && !isGenericMicUrl(url))
        ? url
        : song.displayCoverUrl;

    if ((url.startsWith('/') || url.startsWith('file://')) && !isGenericMicUrl(url)) {
      final filePath = url.replaceFirst('file://', '');
      final f = File(filePath);
      if (f.existsSync()) {
        content = Image.file(
          f,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CachedNetworkImage(
            imageUrl: effectiveHttpUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => _buildYouTubeStyleCard(context),
            errorWidget: (_, __, ___) => _buildYouTubeStyleCard(context),
          ),
        );
      } else {
        content = CachedNetworkImage(
          imageUrl: effectiveHttpUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildYouTubeStyleCard(context),
          errorWidget: (_, __, ___) => _buildYouTubeStyleCard(context),
        );
      }
    } else {
      content = CachedNetworkImage(
        imageUrl: effectiveHttpUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildYouTubeStyleCard(context),
        errorWidget: (_, __, ___) => _buildYouTubeStyleCard(context),
      );
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
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                color: Colors.black.withOpacity(0.55),
              ),
              child: const Center(
                child: VisualizerBars(
                  isPlaying: true,
                  barCount: 3,
                  maxHeight: 18,
                  barWidth: 3,
                  color: AppColors.accentCyan,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final maxRadius = size.width * 0.48;
    for (double r = maxRadius * 0.3; r < maxRadius; r += maxRadius * 0.22) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
