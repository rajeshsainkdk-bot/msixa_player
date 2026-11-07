import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/genre_card.dart';
import '../widgets/song_list_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  static const List<Map<String, dynamic>> _genres = [
    {
      'title': 'Synthwave',
      'icon': Icons.bolt_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
    },
    {
      'title': 'Lo-Fi',
      'icon': Icons.nightlight_round,
      'gradient': LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
    },
    {
      'title': 'Electronic',
      'icon': Icons.album_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)]),
    },
    {
      'title': 'Ambient',
      'icon': Icons.waves_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF3B82F6)]),
    },
    {
      'title': 'Chillhop',
      'icon': Icons.coffee_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
    },
    {
      'title': 'Acoustic',
      'icon': Icons.music_note_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFF6366F1)]),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final trending = provider.trendingSongs;
        final heroSong = trending.isNotEmpty ? trending.first : null;

        return RefreshIndicator(
          color: AppColors.accentCyan,
          backgroundColor: AppColors.surface,
          onRefresh: () => provider.refreshCatalog(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.graphic_eq_rounded, color: AppColors.accentCyan, size: 28),
                              SizedBox(width: 8),
                              Text(
                                'Msixa Player',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Legal Free Online Audio Streaming',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: AppColors.accentCyan,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                // Featured Hero Banner
                if (heroSong != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () => provider.playSong(heroSong, queueContext: trending),
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: AppColors.heroGradient,
                          border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Ambient Background Image with Dark Vignette
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: CachedNetworkImage(
                                  imageUrl: heroSong.coverUrl,
                                  fit: BoxFit.cover,
                                  color: Colors.black.withOpacity(0.6),
                                  colorBlendMode: BlendMode.darken,
                                ),
                              ),
                            ),

                            // Content overlay
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'FEATURED STREAM',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.stream_rounded, color: AppColors.accentCyan, size: 20),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        heroSong.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${heroSong.artist} • ${heroSong.genre}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient: AppColors.primaryGradient,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              children: const [
                                                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Stream Now',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            heroSong.license.split(' ').take(3).join(' '),
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Genres / Moods Carousel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Explore Genres & Moods',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (provider.selectedGenre != 'All')
                        GestureDetector(
                          onTap: () => provider.selectGenre('All'),
                          child: const Text(
                            'Show All',
                            style: TextStyle(color: AppColors.accentCyan, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 75,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _genres.length,
                    itemBuilder: (context, index) {
                      final g = _genres[index];
                      final isSelected = provider.selectedGenre == g['title'];

                      return GenreCard(
                        title: g['title'] as String,
                        icon: g['icon'] as IconData,
                        gradient: g['gradient'] as LinearGradient,
                        isSelected: isSelected,
                        onTap: () {
                          provider.selectGenre(g['title'] as String);
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // Trending Catalog Songs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        provider.selectedGenre == 'All'
                            ? 'Trending Legal MP3s'
                            : '${provider.selectedGenre} Top Tracks',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (provider.isLoadingTrending)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentCyan,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: trending.length,
                  itemBuilder: (context, index) {
                    final song = trending[index];
                    final isCurrent = provider.currentSong?.id == song.id;

                    return SongListTile(
                      song: song,
                      isCurrent: isCurrent,
                      onTap: () => provider.playSong(song, queueContext: trending),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
