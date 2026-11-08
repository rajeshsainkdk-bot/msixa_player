import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../services/app_share_service.dart';
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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_rounded, color: AppColors.accentCyan),
            tooltip: 'Profile & Settings',
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
            Tab(text: 'Favorites (${provider.favorites.length})'),
            Tab(text: 'Device (${provider.deviceSongs.length})'),
            const Tab(text: 'Playlists'),
            const Tab(text: 'Recent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Favorites Tab
          _buildFavoritesTab(context, provider),

          // Device Offline Songs Tab
          _buildDeviceSongsTab(context, provider),

          // Playlists Tab
          _buildPlaylistsTab(context, provider),

          // Recently Played Tab
          _buildRecentTab(context, provider),
        ],
      ),
    );
  }

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
              'Tap the heart icon on any streaming track to add it to your library.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Play All / Shuffle All Header
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

  Widget _buildDeviceSongsTab(BuildContext context, PlayerProvider provider) {
    if (provider.isScanningDevice) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: AppColors.accentCyan),
            SizedBox(height: 16),
            Text(
              'Scanning Device Audio...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Reading local MP3s & audio files from phone storage',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (provider.deviceSongs.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
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
        // Controls header: Play All, Shuffle, Rescan button
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

        // Custom User Playlists
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
          ...custom.map((pl) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accentCyan.withOpacity(0.2)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 54,
                    height: 54,
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
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    '${pl.songs.length} Tracks • ${pl.description}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                        icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accentCyan, size: 34),
                        onPressed: () {
                          if (pl.songs.isNotEmpty) {
                            provider.playSong(pl.songs.first, queueContext: pl.songs);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 10),
        ],

        // Curated Featured Playlists
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            lang.isHindi ? 'विशेष प्लेलिस्ट्स (Featured)' : 'Featured Playlists',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        ...curated.map((pl) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: AppColors.primaryGradient,
                  ),
                  child: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 30),
                ),
                title: Text(
                  pl.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  '${pl.songs.length} Tracks • ${pl.description}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accentCyan, size: 36),
                  onPressed: () {
                    if (pl.songs.isNotEmpty) {
                      provider.playSong(pl.songs.first, queueContext: pl.songs);
                    }
                  },
                ),
              ),
            )),
        const SizedBox(height: 100),
      ],
    );
  }

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
