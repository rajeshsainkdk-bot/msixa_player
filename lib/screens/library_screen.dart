import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/app_share_service.dart';
import '../services/cloud_backend_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/song_list_tile.dart';
import 'profile_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 5 Tabs: All Songs, Favorites, Playlists (Expandable), Device, Recent
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final cloudBackend = Provider.of<CloudBackendService>(context);
    final lang = LanguageService();

    // Master list of all songs across curated master catalog, approved community, and device offline
    final Set<String> seenIds = {};
    final List<Song> allSongs = [];
    for (final s in [
      ...provider.trendingSongs,
      ...cloudBackend.approvedSongs,
      ...provider.deviceSongs,
    ]) {
      if (seenIds.add(s.id)) {
        allSongs.add(s);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(lang.isHindi ? 'आपकी लाइब्रेरी' : 'Your Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_rounded, color: AppColors.accentCyan),
            tooltip: lang.t('profile_title'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.accentCyan),
            tooltip: 'Share APK with Friends',
            onPressed: () => AppShareService.shareAppApk(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentCyan,
          indicatorWeight: 3,
          labelColor: AppColors.accentCyan,
          unselectedLabelColor: AppColors.textMuted,
          isScrollable: true,
          tabs: [
            Tab(text: '${lang.isHindi ? "सभी गाने" : "All Songs"} (${allSongs.length})'),
            Tab(text: '${lang.isHindi ? "पसंदीदा" : "Favorites"} (${provider.favorites.length})'),
            Tab(text: '${lang.isHindi ? "प्लेलिस्ट्स" : "Playlists"} (${provider.customPlaylists.length + provider.curatedPlaylists.length})'),
            Tab(text: '${lang.isHindi ? "फ़ोन स्टोरेज" : "Device"} (${provider.deviceSongs.length})'),
            Tab(text: '${lang.isHindi ? "हाल ही के" : "Recent"} (${provider.recentlyPlayed.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. All Songs Tab (Direct flat list without playlists)
          _buildAllSongsTab(context, provider, allSongs),

          // 2. Favorites Tab
          _buildFavoritesTab(context, provider),

          // 3. Playlists Tab (Expandable & Collapsible)
          _buildPlaylistsTab(context, provider),

          // 4. Device Offline Songs Tab
          _buildDeviceSongsTab(context, provider),

          // 5. Recently Played Tab
          _buildRecentTab(context, provider),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ALL SONGS (DIRECT LIST WITHOUT PLAYLISTS)
  // ==========================================
  Widget _buildAllSongsTab(BuildContext context, PlayerProvider provider, List<Song> allSongs) {
    final lang = LanguageService();

    if (allSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_off_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              lang.isHindi ? 'कोई गाना उपलब्ध नहीं है' : 'No Tracks Available',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Play All / Shuffle All Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  lang.isHindi ? 'सभी बजाएं' : 'Play All',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  provider.playSong(allSongs.first, queueContext: allSongs);
                },
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: Text(lang.isHindi ? 'शफ़ल' : 'Shuffle'),
                onPressed: () {
                  final shuffled = List.of(allSongs)..shuffle();
                  provider.playSong(shuffled.first, queueContext: shuffled);
                },
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentCyan.withOpacity(0.3)),
                ),
                child: Text(
                  '${allSongs.length} ${lang.isHindi ? "गाने" : "Tracks"}',
                  style: const TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: allSongs.length,
            itemBuilder: (context, index) {
              final song = allSongs[index];
              final isCurrent = provider.currentSong?.id == song.id;

              return SongListTile(
                song: song,
                isCurrent: isCurrent,
                onTap: () => provider.playSong(song, queueContext: allSongs),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: FAVORITES
  // ==========================================
  Widget _buildFavoritesTab(BuildContext context, PlayerProvider provider) {
    if (provider.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.favorite_border_rounded, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text(
              'No Favorite Tracks Yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the heart icon on any track to add it to your library.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play All'),
                onPressed: () {
                  provider.playSong(provider.favorites.first, queueContext: provider.favorites);
                },
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Shuffle'),
                onPressed: () {
                  final shuffled = List.of(provider.favorites)..shuffle();
                  provider.playSong(shuffled.first, queueContext: shuffled);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: provider.favorites.length,
            itemBuilder: (context, index) {
              final song = provider.favorites[index];
              final isCurrent = provider.currentSong?.id == song.id;

              return SongListTile(
                song: song,
                isCurrent: isCurrent,
                onTap: () => provider.playSong(song, queueContext: provider.favorites),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: EXPANDABLE & COLLAPSIBLE PLAYLISTS
  // ==========================================
  Widget _buildPlaylistsTab(BuildContext context, PlayerProvider provider) {
    final lang = LanguageService();
    final custom = provider.customPlaylists;
    final curated = provider.curatedPlaylists;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Create Playlist Action Button
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.accentCyan,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.accentCyan.withOpacity(0.3)),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.playlist_add_rounded, color: AppColors.accentCyan, size: 22),
            label: Text(
              lang.t('create_playlist'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () => _showCreatePlaylistDialog(context, provider, lang),
          ),
        ),

        // Custom User Playlists (Expandable)
        if (custom.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              lang.t('my_playlist_badge'),
              style: const TextStyle(
                color: AppColors.accentCyan,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...custom.map((pl) => Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accentCyan.withOpacity(0.25)),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    childrenPadding: const EdgeInsets.only(bottom: 10),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 28),
                    ),
                    title: Text(
                      pl.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15),
                    ),
                    subtitle: Text(
                      '${pl.songs.length} ${lang.isHindi ? "गाने (टैप करके देखें)" : "tracks (tap to expand)"}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                          tooltip: 'Delete Playlist',
                          onPressed: () => provider.removePlaylist(pl.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accentCyan, size: 32),
                          tooltip: 'Play Playlist',
                          onPressed: () {
                            if (pl.songs.isNotEmpty) {
                              provider.playSong(pl.songs.first, queueContext: pl.songs);
                            }
                          },
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 22),
                      ],
                    ),
                    children: [
                      if (pl.songs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            lang.t('no_songs_in_playlist'),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        )
                      else
                        ...pl.songs.asMap().entries.map((entry) {
                          final song = entry.value;
                          final isCurrent = provider.currentSong?.id == song.id && provider.isPlaying;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrent ? AppColors.accentCyan.withOpacity(0.12) : const Color(0xFF0F1626),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCurrent ? AppColors.accentCyan.withOpacity(0.4) : Colors.white.withOpacity(0.04),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: song.coverUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey.shade900,
                                    child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                                  ),
                                ),
                              ),
                              title: Text(
                                song.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isCurrent ? AppColors.accentCyan : AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${song.artist} • ${song.formattedDuration}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                maxLines: 1,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                                    tooltip: 'Remove from Playlist',
                                    onPressed: () => provider.removeSongFromPlaylist(pl.id, song.id),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isCurrent ? Icons.pause_circle_filled_rounded : Icons.play_arrow_rounded,
                                      color: isCurrent ? AppColors.accentCyan : Colors.white70,
                                      size: 26,
                                    ),
                                    onPressed: () {
                                      provider.playSong(song, queueContext: pl.songs);
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                provider.playSong(song, queueContext: pl.songs);
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 10),
        ],

        // Curated Featured Playlists (Expandable)
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            lang.isHindi ? 'विशेष प्लेलिस्ट्स (Featured Playlists)' : 'Featured Playlists',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        ...curated.map((pl) => Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  childrenPadding: const EdgeInsets.only(bottom: 10),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: AppColors.primaryGradient,
                    ),
                    child: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 28),
                  ),
                  title: Text(
                    pl.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15),
                  ),
                  subtitle: Text(
                    '${pl.songs.length} ${lang.isHindi ? "गाने • टैप करके विस्तार से देखें" : "tracks • tap to expand"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accentCyan, size: 32),
                        tooltip: 'Play Playlist',
                        onPressed: () {
                          if (pl.songs.isNotEmpty) {
                            provider.playSong(pl.songs.first, queueContext: pl.songs);
                          }
                        },
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 22),
                    ],
                  ),
                  children: [
                    if (pl.songs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          lang.t('no_songs_in_playlist'),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      )
                    else
                      ...pl.songs.asMap().entries.map((entry) {
                        final song = entry.value;
                        final isCurrent = provider.currentSong?.id == song.id && provider.isPlaying;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCurrent ? AppColors.accentCyan.withOpacity(0.12) : const Color(0xFF0F1626),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCurrent ? AppColors.accentCyan.withOpacity(0.4) : Colors.white.withOpacity(0.04),
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: song.coverUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey.shade900,
                                  child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                                ),
                              ),
                            ),
                            title: Text(
                              song.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isCurrent ? AppColors.accentCyan : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${song.artist} • ${song.formattedDuration}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              maxLines: 1,
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isCurrent ? Icons.pause_circle_filled_rounded : Icons.play_arrow_rounded,
                                color: isCurrent ? AppColors.accentCyan : Colors.white70,
                                size: 26,
                              ),
                              onPressed: () {
                                provider.playSong(song, queueContext: pl.songs);
                              },
                            ),
                            onTap: () {
                              provider.playSong(song, queueContext: pl.songs);
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 100),
      ],
    );
  }

  // ==========================================
  // TAB 4: DEVICE AUDIO
  // ==========================================
  Widget _buildDeviceSongsTab(BuildContext context, PlayerProvider provider) {
    if (provider.deviceSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.card,
                  border: Border.all(color: AppColors.accentCyan.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentCyan.withOpacity(0.15),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.folder_copy_rounded,
                  size: 44,
                  color: AppColors.accentCyan,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Play Songs from Phone Storage',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Scan your device storage (Downloads, Music folders) to play your offline MP3 songs with Msixa Player.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 6,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 22),
                label: const Text(
                  'Scan Device Songs',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () => provider.scanDeviceSongs(),
              ),
              const SizedBox(height: 14),
              Text(
                provider.hasDevicePermission
                    ? 'Storage permission granted'
                    : 'Requires Audio / Storage permission',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  provider.playSong(provider.deviceSongs.first, queueContext: provider.deviceSongs);
                },
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Shuffle'),
                onPressed: () {
                  final shuffled = List.of(provider.deviceSongs)..shuffle();
                  provider.playSong(shuffled.first, queueContext: shuffled);
                },
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Rescan Storage',
                icon: const Icon(Icons.refresh_rounded, color: AppColors.accentCyan),
                onPressed: () => provider.scanDeviceSongs(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '${provider.deviceSongs.length} Local Tracks',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Text(
                'Music Only (> 60s, No Recordings)',
                style: TextStyle(color: AppColors.accentGreen, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: provider.deviceSongs.length,
            itemBuilder: (context, index) {
              final song = provider.deviceSongs[index];
              final isCurrent = provider.currentSong?.id == song.id;

              return SongListTile(
                song: song,
                isCurrent: isCurrent,
                onTap: () => provider.playSong(song, queueContext: provider.deviceSongs),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 5: RECENTLY PLAYED
  // ==========================================
  Widget _buildRecentTab(BuildContext context, PlayerProvider provider) {
    if (provider.recentlyPlayed.isEmpty) {
      return const Center(
        child: Text(
          'No recently played tracks.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 120),
      itemCount: provider.recentlyPlayed.length,
      itemBuilder: (context, index) {
        final song = provider.recentlyPlayed[index];
        final isCurrent = provider.currentSong?.id == song.id;

        return SongListTile(
          song: song,
          isCurrent: isCurrent,
          onTap: () => provider.playSong(song, queueContext: provider.recentlyPlayed),
        );
      },
    );
  }

  // ==========================================
  // DIALOG: CREATE NEW PLAYLIST
  // ==========================================
  void _showCreatePlaylistDialog(BuildContext context, PlayerProvider provider, LanguageService lang) {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          lang.t('create_playlist'),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: lang.t('playlist_name'),
            hintStyle: TextStyle(color: Colors.grey.shade500),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accentCyan.withOpacity(0.5)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accentCyan, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.t('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final name = titleCtrl.text.trim();
              if (name.isNotEmpty) {
                provider.createPlaylist(name);
                Navigator.pop(ctx);
              }
            },
            child: Text(
              lang.isHindi ? 'बनाएं' : 'Create',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
