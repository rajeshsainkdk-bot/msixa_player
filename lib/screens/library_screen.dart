import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/song_list_tile.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentCyan,
          indicatorWeight: 3,
          labelColor: AppColors.accentCyan,
          unselectedLabelColor: AppColors.textMuted,
          tabs: [
            Tab(text: 'Favorites (${provider.favorites.length})'),
            const Tab(text: 'Recent'),
            const Tab(text: 'Playlists'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Favorites Tab
          _buildFavoritesTab(context, provider),

          // Recently Played Tab
          _buildRecentTab(context, provider),

          // Playlists Tab
          _buildPlaylistsTab(context, provider),
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
    final playlists = provider.curatedPlaylists;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pl = playlists[index];

        return Container(
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
        );
      },
    );
  }
}
