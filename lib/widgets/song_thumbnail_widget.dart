import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../services/song_artwork_resolver.dart';
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
    return SongArtworkResolver.getThemeForSong(song).gradientColors;
  }

  static IconData getIconForGenre(String genre, [Song? song]) {
    if (song != null) {
      return SongArtworkResolver.getThemeForSong(song).icon;
    }
    return SongArtworkResolver.getThemeForTitle('', genre: genre).icon;
  }

  /// Studio-Grade YouTube Music Style Dynamic Thumbnail Card
  Widget _buildYouTubeStyleCard(BuildContext context) {
    final theme = SongArtworkResolver.getThemeForSong(song);
    final gradient = theme.gradientColors;
    final icon = theme.icon;
    final isCompact = size <= 60;
    final cleanTitle = song.title.replaceAll(RegExp(r'\.(mp3|m4a|wav|aac|flac)$', caseSensitive: false), '').trim();
    final cleanArtist = song.artist.trim().isNotEmpty ? song.artist.trim() : 'Msixa Music';
    final genreTag = theme.themeName.toUpperCase();

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
