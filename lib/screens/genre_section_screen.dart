import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/jiosaavn_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_list_tile.dart';
import '../widgets/song_thumbnail_widget.dart';

class GenreSectionScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final List<Song>? initialSongs;

  const GenreSectionScreen({
    Key? key,
    required this.title,
    required this.icon,
    required this.gradient,
    this.initialSongs,
  }) : super(key: key);

  @override
  State<GenreSectionScreen> createState() => _GenreSectionScreenState();
}

class _GenreSectionScreenState extends State<GenreSectionScreen> {
  final JioSaavnService _saavnService = JioSaavnService();
  final TextEditingController _filterController = TextEditingController();

  List<Song> _songs = [];
  bool _isLoading = true;
  String _filterQuery = '';

  int _searchMode = 0; // 0: In this card, 1: Global All Online Songs
  List<Song> _globalSearchResults = [];
  bool _isSearchingGlobal = false;
  Timer? _globalDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialSongs != null && widget.initialSongs!.isNotEmpty) {
      _songs = List.from(widget.initialSongs!);
      if (_songs.length >= 100) {
        _isLoading = false;
      }
    }
    _loadGenreSongs();
  }

  @override
  void dispose() {
    _globalDebounce?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  void _onSearchInputChanged(String val) {
    setState(() => _filterQuery = val);
    if (_searchMode == 1) {
      _performGlobalSearch(val);
    }
  }

  void _performGlobalSearch(String query) {
    _globalDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _globalSearchResults = [];
        _isSearchingGlobal = false;
      });
      return;
    }

    setState(() => _isSearchingGlobal = true);
    _globalDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final res = await _saavnService.searchSongs(query.trim(), limit: 50);
        if (mounted) {
          setState(() {
            _globalSearchResults = res;
            _isSearchingGlobal = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearchingGlobal = false);
      }
    });
  }

  Future<void> _loadGenreSongs({bool forceRefresh = false}) async {
    try {
      final fetched = await _saavnService.getGenreSongs(
        widget.title,
        limit: 300,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          final Set<String> seen = {};
          final List<Song> all = [];
          for (final s in [..._songs, ...fetched]) {
            if (seen.add(s.id)) {
              all.add(s);
            }
          }
          _songs = all;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Song> _getSortedAndFilteredSongs(PlayerProvider provider) {
    final list = List<Song>.from(_songs);

    // Automatic Smart Ranking: Songs played more often in this card float to the top
    list.sort((a, b) {
      final countA = provider.getPlayCount(a.id);
      final countB = provider.getPlayCount(b.id);
      if (countB != countA) {
        return countB.compareTo(countA); // Highest play count on top!
      }
      return 0;
    });

    if (_filterQuery.trim().isEmpty) return list;
    final q = _filterQuery.toLowerCase();
    return list.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final lang = LanguageService();
    final displayed = _getSortedAndFilteredSongs(provider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF)),
            tooltip: lang.isHindi ? 'ताज़ा करें' : 'Refresh List',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadGenreSongs(forceRefresh: true);
            },
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: CustomScrollView(
        slivers: [
          // 1. Hero Gradient Header Banner
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: widget.gradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: widget.gradient.colors.first.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 36),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          lang.isHindi
                              ? '${_songs.length}+ गाने (टॉप प्ले पहले)'
                              : '${_songs.length}+ Tracks (Top Played First)',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang.isHindi
                        ? 'विशाल 200+ गानों का संग्रह • अधिक सुने जाने वाले गाने अपने आप ऊपर आएंगे'
                        : 'Mega 200+ tracks collection • Most played songs automatically rank first',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  // Play All & Shuffle Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: displayed.isNotEmpty
                              ? () => provider.playSong(displayed.first, queueContext: displayed)
                              : null,
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                          label: Text(
                            lang.isHindi ? 'सभी चलाएं (Play All)' : 'Play All',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: displayed.isNotEmpty
                              ? () {
                                  final shuffled = List<Song>.from(displayed)..shuffle();
                                  provider.playSong(shuffled.first, queueContext: shuffled);
                                }
                              : null,
                          icon: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 18),
                          label: Text(
                            lang.isHindi ? 'शफ़ल' : 'Shuffle',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.25),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Search Filter in this Genre with Scope Switcher
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A2A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _filterQuery.isNotEmpty ? const Color(0xFF00E5FF) : Colors.white12,
                        width: _filterQuery.isNotEmpty ? 1.2 : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _filterController,
                      onChanged: _onSearchInputChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _searchMode == 0
                            ? (lang.isHindi
                                ? '${widget.title} गानों में खोजें (${_songs.length}+ गाने)...'
                                : 'Filter in ${widget.title} (${_songs.length}+ songs)...')
                            : (lang.isHindi
                                ? 'ऑनलाइन सभी गानों में खोजें (करोड़ों गाने)...'
                                : 'Search all online streaming songs...'),
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: Icon(
                          _searchMode == 0 ? Icons.search_rounded : Icons.public_rounded,
                          color: const Color(0xFF00E5FF),
                          size: 20,
                        ),
                        suffixIcon: _filterQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                                onPressed: () {
                                  _filterController.clear();
                                  _onSearchInputChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Search Mode Switcher: In this card vs All Online Songs
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_searchMode != 0) {
                            setState(() => _searchMode = 0);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _searchMode == 0 ? const Color(0xFF00E5FF).withOpacity(0.2) : const Color(0xFF131A2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _searchMode == 0 ? const Color(0xFF00E5FF) : Colors.white12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_list_rounded,
                                size: 13,
                                color: _searchMode == 0 ? const Color(0xFF00E5FF) : Colors.white60,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lang.isHindi ? 'इस कार्ड में (${_songs.length}+)' : 'In Card (${_songs.length}+)',
                                style: TextStyle(
                                  color: _searchMode == 0 ? const Color(0xFF00E5FF) : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: _searchMode == 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (_searchMode != 1) {
                            setState(() => _searchMode = 1);
                            if (_filterQuery.trim().isNotEmpty) {
                              _performGlobalSearch(_filterQuery);
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _searchMode == 1 ? const Color(0xFFFFB300).withOpacity(0.2) : const Color(0xFF131A2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _searchMode == 1 ? const Color(0xFFFFB300) : Colors.white12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.public_rounded,
                                size: 13,
                                color: _searchMode == 1 ? const Color(0xFFFFB300) : Colors.white60,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lang.isHindi ? '🌐 ऑनलाइन सभी गाने' : 'All Online Songs',
                                style: TextStyle(
                                  color: _searchMode == 1 ? const Color(0xFFFFB300) : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: _searchMode == 1 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Quick bridge to Global Search when typing in card mode
                  if (_searchMode == 0 && _filterQuery.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        setState(() => _searchMode = 1);
                        _performGlobalSearch(_filterQuery);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.travel_explore_rounded, color: Color(0xFFFFB300), size: 15),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lang.isHindi
                                    ? 'कार्ड में नहीं मिला? "$_filterQuery" को ऑनलाइन सभी गानों में खोजें'
                                    : 'Not in this card? Search "$_filterQuery" across all online songs',
                                style: const TextStyle(
                                  color: Color(0xFFFFB300),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFFB300), size: 11),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. Songs List with Top Played Indicator or Global Search
          if (_searchMode == 1) ...[
            if (_isSearchingGlobal)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFB300)),
                ),
              )
            else if (_globalSearchResults.isEmpty && _filterQuery.trim().isNotEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    lang.isHindi
                        ? 'ऑनलाइन खोज में कोई गाना नहीं मिला'
                        : 'No online songs found for "$_filterQuery"',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
              )
            else if (_globalSearchResults.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    lang.isHindi
                        ? 'ऑनलाइन किसी भी गाने का नाम लिखकर खोजें'
                        : 'Type any song or artist name to search all songs',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = _globalSearchResults[index];
                      final isCurrent = provider.currentSong?.id == song.id;
                      final playCount = provider.getPlayCount(song.id);

                      return SongListTile(
                        song: song,
                        isCurrent: isCurrent,
                        rank: index + 1,
                        playCount: playCount,
                        onTap: () => provider.playSong(song, queueContext: _globalSearchResults),
                      );
                    },
                    childCount: _globalSearchResults.length,
                  ),
                ),
              ),
          ] else ...[
            if (_isLoading && _songs.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                ),
              )
            else if (displayed.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lang.isHindi ? 'इस कार्ड में कोई गाना नहीं मिला' : 'No songs found in this card',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      if (_filterQuery.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB300),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.public_rounded, size: 16),
                          label: Text(
                            lang.isHindi ? 'ऑनलाइन सभी गानों में खोजें' : 'Search All Online Songs',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            setState(() => _searchMode = 1);
                            _performGlobalSearch(_filterQuery);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
                sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = displayed[index];
                    final isCurrent = provider.currentSong?.id == song.id;
                    final playCount = provider.getPlayCount(song.id);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.primary.withOpacity(0.18)
                            : (playCount > 0 ? const Color(0xFF1E293B).withOpacity(0.6) : const Color(0xFF131A2A)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.accentCyan.withOpacity(0.6)
                              : (playCount > 0 ? const Color(0xFFFFB300).withOpacity(0.3) : Colors.white.withOpacity(0.04)),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => provider.playSong(song, queueContext: displayed),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                SongThumbnailWidget(
                                  song: song,
                                  size: 52,
                                  borderRadius: 12,
                                  isPlaying: isCurrent && provider.isPlaying,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              song.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isCurrent ? AppColors.accentCyan : Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (playCount > 0) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFB300).withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.5)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB300), size: 12),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '#${index + 1} ($playCount)',
                                                    style: const TextStyle(
                                                      color: Color(0xFFFFB300),
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${song.artist} • ${song.album}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    provider.isFavorite(song.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: provider.isFavorite(song.id) ? Colors.redAccent : Colors.white38,
                                    size: 20,
                                  ),
                                  onPressed: () => provider.toggleFavorite(song),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: displayed.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
