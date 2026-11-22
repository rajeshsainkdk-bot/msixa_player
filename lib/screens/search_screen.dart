import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/song_list_tile.dart';
import '../widgets/mini_player.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _activeTab = 0; // 0: Online Music (Ultra HD 320k), 1: Local & Uploads

  static const List<String> _quickTags = [
    'Arijit Singh',
    'Ed Sheeran',
    'Sidhu Moose Wala',
    'Diljit Dosanjh',
    'Taylor Swift',
    'Yo Yo Honey Singh',
    'Alan Walker',
    'Karan Aujla',
    'B Praak',
    'Hanuman Chalisa',
    'Bollywood Hits',
    'Global Pop',
    'Marwadi Songs',
    'Desi Lo-Fi',
  ];

  @override
  void initState() {
    super.initState();
    // Preload top trending online tracks on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<PlayerProvider>(context, listen: false);
      provider.loadOnlineTrending();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, PlayerProvider provider) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (_activeTab == 0) {
        provider.searchOnline(query);
      } else {
        provider.search(query);
      }
    });
  }

  void _performSearch(String query, PlayerProvider provider) {
    _debounce?.cancel();
    _searchController.text = query;
    if (_activeTab == 0) {
      provider.searchOnline(query);
    } else {
      provider.search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService(),
      builder: (context, _) {
        final provider = Provider.of<PlayerProvider>(context);
        final lang = LanguageService();

        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: (ModalRoute.of(context)?.isFirst ?? true) ? null : const MiniPlayer(),
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title: Text(
              lang.isHindi ? 'म्यूज़िक खोजें (Search)' : 'Search Music',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            centerTitle: false,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Search Mode Switcher Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A2A),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      // Online Streaming Tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_activeTab != 0) {
                              setState(() => _activeTab = 0);
                              if (_searchController.text.isNotEmpty) {
                                provider.searchOnline(_searchController.text);
                              } else {
                                provider.loadOnlineTrending();
                              }
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: _activeTab == 0
                                  ? const LinearGradient(
                                      colors: [Color(0xFF00E5FF), Color(0xFF4F46E5)],
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.cloud_download_rounded,
                                    size: 16,
                                    color: _activeTab == 0 ? Colors.black : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    lang.isHindi ? 'ऑनलाइन स्ट्रीमिंग' : 'Online Streaming',
                                    style: TextStyle(
                                      color: _activeTab == 0 ? Colors.black : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Local & Uploads Tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_activeTab != 1) {
                              setState(() => _activeTab = 1);
                              if (_searchController.text.isNotEmpty) {
                                provider.search(_searchController.text);
                              }
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: _activeTab == 1
                                  ? const LinearGradient(
                                      colors: [Color(0xFF00E5FF), Color(0xFF4F46E5)],
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.folder_rounded,
                                    size: 16,
                                    color: _activeTab == 1 ? Colors.black : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    lang.isHindi ? 'लोकल व लाइब्रेरी' : 'My Library',
                                    style: TextStyle(
                                      color: _activeTab == 1 ? Colors.black : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Search Input Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _activeTab == 0
                          ? const Color(0xFF00E5FF).withOpacity(0.3)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: _activeTab == 0
                          ? (lang.isHindi ? 'करोड़ों गाने, गायक, या एल्बम खोजें...' : 'Search millions of Hindi, Punjabi, Bollywood songs...')
                          : lang.t('search_hint'),
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _activeTab == 0 ? const Color(0xFF00E5FF) : AppColors.accentCyan,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                if (_activeTab == 0) {
                                  provider.searchOnline('');
                                } else {
                                  provider.search('');
                                }
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (query) => _onSearchChanged(query, provider),
                  ),
                ),
              ),

              // 3. Quick Tag Chips
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _quickTags.length,
                  itemBuilder: (context, index) {
                    final tag = _quickTags[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor: AppColors.card,
                        side: BorderSide(color: Colors.white.withOpacity(0.08)),
                        label: Text(tag),
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        onPressed: () => _performSearch(tag, provider),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // 4. Content Body: Results or Trending
              Expanded(
                child: _activeTab == 0
                    ? _buildOnlineStreamingView(context, provider, lang)
                    : _buildLocalLibraryView(context, provider, lang),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOnlineStreamingView(BuildContext context, PlayerProvider provider, LanguageService lang) {
    if (provider.isSearchingOnline) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00E5FF)),
            SizedBox(height: 12),
            Text(
              'Fetching 320kbps Studio Audio...',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final query = _searchController.text.trim();
    final results = provider.onlineSearchResults;

    // If query was typed and has results
    if (query.isNotEmpty) {
      if (results.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 56, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'No online tracks found for "$query"',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final song = results[index];
          final isCurrent = provider.currentSong?.id == song.id;

          return _buildOnlineSongTile(context, song, isCurrent, provider, results);
        },
      );
    }

    // Default view when search bar is empty: Show India's Top 50 Trending Tracks
    final trending = provider.onlineTrendingSongs;
    if (provider.isLoadingOnlineTrending) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
      );
    }

    if (trending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_tethering_rounded, size: 48, color: Color(0xFF00E5FF)),
            const SizedBox(height: 12),
            const Text(
              'Discover Millions of Online Songs',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Type any artist, song, or movie name above to stream in 320kbps HD.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Load India Top 50', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => provider.loadOnlineTrending(forceRefresh: true),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.whatshot_rounded, color: Color(0xFFFF6D00), size: 20),
                  SizedBox(width: 6),
                  Text(
                    "Today's Top 50 Trending Hits",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                ),
                child: const Text(
                  '320 kbps HD',
                  style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: trending.length,
            itemBuilder: (context, index) {
              final song = trending[index];
              final isCurrent = provider.currentSong?.id == song.id;

              return _buildOnlineSongTile(context, song, isCurrent, provider, trending);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineSongTile(
    BuildContext context,
    Song song,
    bool isCurrent,
    PlayerProvider provider,
    List<Song> queue,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: song.coverUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: song.coverUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFF131A2A),
                  child: const Icon(Icons.music_note_rounded, color: Color(0xFF00E5FF), size: 20),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFF131A2A),
                  child: const Icon(Icons.music_note_rounded, color: Colors.white30, size: 20),
                ),
              )
            : Container(
                width: 48,
                height: 48,
                color: const Color(0xFF131A2A),
                child: const Icon(Icons.music_note_rounded, color: Color(0xFF00E5FF), size: 20),
              ),
      ),
      title: Text(
        song.title,
        style: TextStyle(
          color: isCurrent ? const Color(0xFF00E5FF) : Colors.white,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Ultra HD',
              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              '${song.artist} • ${song.album}',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: song.isFavorite ? Colors.redAccent : Colors.white38,
              size: 20,
            ),
            onPressed: () => provider.toggleFavorite(song),
          ),
          IconButton(
            icon: Icon(
              isCurrent && provider.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: const Color(0xFF00E5FF),
              size: 28,
            ),
            onPressed: () {
              if (isCurrent && provider.isPlaying) {
                provider.pause();
              } else {
                provider.playSong(song, queueContext: queue);
              }
            },
          ),
        ],
      ),
      onTap: () => provider.playSong(song, queueContext: queue),
    );
  }

  Widget _buildLocalLibraryView(BuildContext context, PlayerProvider provider, LanguageService lang) {
    if (provider.isSearching) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
    }

    if (provider.searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.search_off_rounded, size: 56, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No matching tracks in your local library', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (provider.searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.folder_open_rounded, size: 56, color: AppColors.accentCyan),
            SizedBox(height: 16),
            Text(
              'Search Your Library & Folders',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Search across your device MP3 files, playlists, and uploaded admin tracks.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: provider.searchResults.length,
      itemBuilder: (context, index) {
        final song = provider.searchResults[index];
        final isCurrent = provider.currentSong?.id == song.id;

        return SongListTile(
          song: song,
          isCurrent: isCurrent,
          onTap: () => provider.playSong(song, queueContext: provider.searchResults),
        );
      },
    );
  }
}
