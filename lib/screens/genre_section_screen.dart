import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/jiosaavn_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_list_tile.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.initialSongs != null && widget.initialSongs!.isNotEmpty) {
      _songs = List.from(widget.initialSongs!);
      _isLoading = false;
    }
    _loadGenreSongs();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadGenreSongs() async {
    try {
      final fetched = await _saavnService.getGenreSongs(widget.title, limit: 100);
      if (mounted) {
        setState(() {
          // Merge with any initial songs, deduplicating by ID
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

  List<Song> get _filteredSongs {
    if (_filterQuery.trim().isEmpty) return _songs;
    final q = _filterQuery.toLowerCase();
    return _songs.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final lang = LanguageService();
    final displayed = _filteredSongs;

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
                              ? '${_songs.length} गाने उपलब्ध'
                              : '${_songs.length} Tracks Available',
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
                        ? 'सभी लोकप्रिय और नए ${widget.title} गाने (Ultra HD 320k)'
                        : 'Top Trending & Classic ${widget.title} Tracks (Ultra HD 320k)',
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
                            lang.isHindi ? 'सभी चलाएं' : 'Play All',
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

          // 2. Search Filter in this Genre
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _filterController,
                  onChanged: (val) => setState(() => _filterQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: lang.isHindi
                        ? '${widget.title} गानों में खोजें...'
                        : 'Filter in ${widget.title}...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00E5FF), size: 20),
                    suffixIcon: _filterQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                            onPressed: () {
                              _filterController.clear();
                              setState(() => _filterQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // 3. Songs List
          if (_isLoading && _songs.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
              ),
            )
          else if (displayed.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  lang.isHindi ? 'कोई गाना नहीं मिला' : 'No songs found',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = displayed[index];
                    final isCurrent = provider.currentSong?.id == song.id;

                    return SongListTile(
                      song: song,
                      isCurrent: isCurrent,
                      onTap: () => provider.playSong(song, queueContext: displayed),
                    );
                  },
                  childCount: displayed.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
