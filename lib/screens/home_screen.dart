import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/app_share_service.dart';
import '../services/cloud_backend_service.dart';
import '../theme/app_colors.dart';
import '../widgets/genre_card.dart';
import '../widgets/song_list_tile.dart';
import 'upload_song_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  static const List<Map<String, dynamic>> _genres = [
    {
      'title': 'All Indian',
      'icon': Icons.music_note_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFFF9933), Color(0xFF138808)]),
    },
    {
      'title': 'Bhakti',
      'icon': Icons.temple_hindu_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
    },
    {
      'title': 'Punjabi',
      'icon': Icons.speaker_group_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
    },
    {
      'title': 'Sufi',
      'icon': Icons.self_improvement_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)]),
    },
    {
      'title': 'Bollywood',
      'icon': Icons.movie_filter_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFE11D48), Color(0xFF9333EA)]),
    },
    {
      'title': 'Spiritual',
      'icon': Icons.flare_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF3B82F6)]),
    },
    {
      'title': 'Desi Lo-Fi',
      'icon': Icons.nightlife_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
    },
    {
      'title': 'Ghazal',
      'icon': Icons.waves_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF43F5E)]),
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
                // Top App Header with Share APK Button
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
                            '100% Free Indian & Offline Music Player',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Upload Song Button
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const UploadSongScreen()),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00E5FF), Color(0xFF4F46E5)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.cloud_upload_rounded, color: Colors.black, size: 16),
                                  SizedBox(width: 5),
                                  Text(
                                    '+ Upload',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Share Application APK File Button
                          GestureDetector(
                            onTap: () => AppShareService.shareAppApk(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.accentCyan.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.share_rounded, color: AppColors.accentCyan, size: 16),
                                  SizedBox(width: 5),
                                  Text(
                                    'Share APK',
                                    style: TextStyle(
                                      color: AppColors.accentCyan,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                                child: heroSong.coverUrl.startsWith('http')
                                    ? CachedNetworkImage(
                                        imageUrl: heroSong.coverUrl,
                                        fit: BoxFit.cover,
                                        color: Colors.black.withOpacity(0.6),
                                        colorBlendMode: BlendMode.darken,
                                      )
                                    : Container(color: AppColors.card),
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
                                          '🇮🇳 100% FREE • NO PAYMENT',
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
                                                  'Listen Free',
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
                                          const Text(
                                            'Free Forever',
                                            style: TextStyle(
                                              color: AppColors.accentGreen,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
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

                // Share APK File Quick Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accentCyan.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.send_to_mobile_rounded,
                            color: AppColors.accentCyan,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Share App APK with Friends',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Send directly via WhatsApp, Bluetooth & Nearby Share',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentCyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 14),
                          label: const Text(
                            'Share APK',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => AppShareService.shareAppApk(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Device Storage Quick Access Banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.sd_storage_rounded,
                            color: AppColors.accentGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Device Offline Audio',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                provider.deviceSongs.isEmpty
                                    ? 'Scan phone folders (Downloads, Music)'
                                    : '${provider.deviceSongs.length} offline songs ready',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: provider.deviceSongs.isEmpty
                                ? AppColors.accentGreen
                                : AppColors.surface,
                            foregroundColor: provider.deviceSongs.isEmpty
                                ? Colors.black
                                : AppColors.accentGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => provider.scanDeviceSongs(),
                          child: Text(
                            provider.deviceSongs.isEmpty ? 'Scan' : 'Rescan',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ==========================================
                // 🔥 NEWLY ADDED BY COMMUNITY (Approved User Songs)
                // ==========================================
                _buildCommunitySection(context, provider),

                // ==========================================
                // SECTION 1: DIVINE BHAKTI & HANUMAN CHANTS
                // ==========================================
                _buildCategorySection(
                  context,
                  title: '🕉️ Divine Bhakti & Hanuman Chants',
                  genreKey: 'Bhakti',
                  provider: provider,
                  songs: trending.where((s) => s.genre == 'Bhakti').toList(),
                ),

                // ==========================================
                // SECTION 2: SUFI & PUNJABI (SATINDER SARTAAJ)
                // ==========================================
                _buildCategorySection(
                  context,
                  title: '🪕 Sufi & Punjabi (Satinder Sartaaj)',
                  genreKey: 'Punjabi',
                  provider: provider,
                  songs: trending.where((s) => s.genre == 'Punjabi' || s.genre == 'Sufi').toList(),
                ),

                // ==========================================
                // SECTION 3: BOLLYWOOD & INDIE MELODIES
                // ==========================================
                _buildCategorySection(
                  context,
                  title: '🎬 Bollywood & Indie Melodies',
                  genreKey: 'Bollywood',
                  provider: provider,
                  songs: trending.where((s) => s.genre == 'Bollywood' || s.genre == 'Indie Pop').toList(),
                ),

                // ==========================================
                // SECTION 4: AGHORI & SPIRITUAL TRANCE
                // ==========================================
                _buildCategorySection(
                  context,
                  title: '🔱 Aghori & Spiritual Trance',
                  genreKey: 'Spiritual',
                  provider: provider,
                  songs: trending.where((s) => s.genre == 'Spiritual').toList(),
                ),

                // ==========================================
                // SECTION 5: DESI LO-FI & GHAZALS
                // ==========================================
                _buildCategorySection(
                  context,
                  title: '☕ Desi Lo-Fi & Ghazals',
                  genreKey: 'Desi Lo-Fi',
                  provider: provider,
                  songs: trending.where((s) => s.genre == 'Desi Lo-Fi' || s.genre == 'Ghazal').toList(),
                ),

                const SizedBox(height: 20),

                // Genres / Moods Carousel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Browse by Category',
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

                const SizedBox(height: 24),

                // Trending Catalog Songs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        provider.selectedGenre == 'All' || provider.selectedGenre == 'All Indian'
                            ? 'All Free Indian Tracks'
                            : '${provider.selectedGenre} Tracks',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '100% Free Forever',
                        style: TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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

  Widget _buildCategorySection(
    BuildContext context, {
    required String title,
    required String genreKey,
    required PlayerProvider provider,
    required List<Song> songs,
  }) {
    if (songs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => provider.selectGenre(genreKey),
                child: const Text(
                  'See All',
                  style: TextStyle(color: AppColors.accentCyan, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return _buildIndianSongCard(context, song, provider, songs);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIndianSongCard(
    BuildContext context,
    Song song,
    PlayerProvider provider,
    List<Song> queue,
  ) {
    final isCurrent = provider.currentSong?.id == song.id;
    return GestureDetector(
      onTap: () => provider.playSong(song, queueContext: queue),
      child: Container(
        width: 135,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: song.coverUrl.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: song.coverUrl,
                          width: 135,
                          height: 135,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 135,
                            height: 135,
                            color: AppColors.card,
                            child: const Icon(Icons.music_note_rounded, color: AppColors.textMuted),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 135,
                            height: 135,
                            color: AppColors.card,
                            child: const Icon(Icons.music_note_rounded, color: AppColors.textMuted),
                          ),
                        )
                      : Container(
                          width: 135,
                          height: 135,
                          color: AppColors.card,
                          child: const Icon(Icons.music_note_rounded, color: AppColors.accentCyan),
                        ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isCurrent && provider.isPlaying
                          ? AppColors.accentGradient
                          : AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      isCurrent && provider.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'FREE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent ? AppColors.accentCyan : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunitySection(BuildContext context, PlayerProvider provider) {
    final backend = CloudBackendService();
    final approved = backend.approvedSongs;

    if (approved.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '🔥 Newly Added by Community',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                ),
                child: Text(
                  '${approved.length} Live',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: approved.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final song = approved[index];
              return _buildSongCard(context, song, provider, approved);
            },
          ),
        ),
      ],
    );
  }
}
