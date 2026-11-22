import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/playlist.dart';
import '../providers/player_provider.dart';
import '../services/app_share_service.dart';
import '../services/cloud_backend_service.dart';
import '../theme/app_colors.dart';
import '../widgets/genre_card.dart';
import '../widgets/song_list_tile.dart';
import '../widgets/song_thumbnail_widget.dart';
import '../services/language_service.dart';
import '../services/update_service.dart';
import '../services/jiosaavn_service.dart';
import 'upload_song_screen.dart';
import 'profile_screen.dart';
import 'artist_detail_screen.dart';
import 'album_detail_screen.dart';
import 'search_screen.dart';
import 'genre_section_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _expandedCategories = {};
  final Map<String, String> _selectedSubCategories = {};
  String _activeDiscoverTab = 'all'; // 'all' | 'recent' | 'favorites' | 'artists' | 'albums' | 'playlists'

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _searchScope = 0; // 0: Online Streaming, 1: My Library & Device
  String _activeSearchQuery = '';

  static const List<String> _searchQuickTags = [
    'Arijit Singh',
    'Sidhu Moose Wala',
    'DJ Remix',
    'Marwadi DJ',
    'Haryanvi Hits',
    'Bhojpuri Dhamaka',
    'Punjabi Beats',
    'Diljit Dosanjh',
    '90s Retro',
    'Desi Lo-Fi',
    'Khatu Shyam',
    'Bhakti Bhajan',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<PlayerProvider>(context, listen: false);
      provider.loadOnlineTrending();
      UpdateService.checkForUpdate(context, autoPrompt: true);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, PlayerProvider provider) {
    _searchDebounce?.cancel();
    setState(() => _activeSearchQuery = query);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (query.trim().isEmpty) return;
      if (_searchScope == 0) {
        provider.searchOnline(query.trim());
      } else {
        provider.search(query.trim());
      }
    });
  }

  void _selectQuickTag(String tag, PlayerProvider provider) {
    _searchController.text = tag;
    _onSearchChanged(tag, provider);
  }

  static const List<Map<String, dynamic>> _genres = [
    {
      'title': 'DJ Remix',
      'icon': Icons.equalizer_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF4F46E5)]),
      'image': 'https://images.unsplash.com/photo-1571266028243-3716f02d2d2e?w=600&q=80',
    },
    {
      'title': 'Haryanvi',
      'icon': Icons.speaker_group_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF10B981), Color(0xFF047857)]),
      'image': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    },
    {
      'title': 'Rajasthani',
      'icon': Icons.audiotrack_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFFF6F00), Color(0xFFFFD54F)]),
      'image': 'https://images.unsplash.com/photo-1599827552599-eeddd59551c6?w=600&q=80',
    },
    {
      'title': 'Marwadi',
      'icon': Icons.celebration_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFFF3D00), Color(0xFFFF9100)]),
      'image': 'https://images.unsplash.com/photo-1599827552599-eeddd59551c6?w=600&q=80',
    },
    {
      'title': 'Bhojpuri',
      'icon': Icons.music_video_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFBE123C)]),
      'image': 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=600&q=80',
    },
    {
      'title': '90s Retro',
      'icon': Icons.radio_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777)]),
      'image': 'https://images.unsplash.com/photo-1461360370896-922624d12aa1?w=600&q=80',
    },
    {
      'title': 'Punjabi',
      'icon': Icons.bolt_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
      'image': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
    },
    {
      'title': 'Romantic',
      'icon': Icons.favorite_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFFF4081)]),
      'image': 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=600&q=80',
    },
    {
      'title': 'Bhakti',
      'icon': Icons.temple_hindu_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
      'image': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
    },
    {
      'title': 'Sad Songs',
      'icon': Icons.heart_broken_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF334155), Color(0xFF475569)]),
      'image': 'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=600&q=80',
    },
    {
      'title': 'Desi Lo-Fi',
      'icon': Icons.nightlife_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
      'image': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
    },
    {
      'title': 'Gym & Workout',
      'icon': Icons.fitness_center_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFEF4444)]),
      'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
    },
    {
      'title': 'Ghazal & Sufi',
      'icon': Icons.self_improvement_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)]),
      'image': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80',
    },
    {
      'title': 'Bollywood',
      'icon': Icons.movie_filter_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFE11D48), Color(0xFF9333EA)]),
      'image': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
    },
    {
      'title': 'Gujarati',
      'icon': Icons.music_note_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF14B8A6)]),
      'image': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    },
    {
      'title': 'South Special',
      'icon': Icons.flash_on_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
      'image': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
    },
    {
      'title': 'Classical',
      'icon': Icons.graphic_eq_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF78350F), Color(0xFFB45309)]),
      'image': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80',
    },
    {
      'title': 'Party Dance',
      'icon': Icons.nightlife_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
      'image': 'https://images.unsplash.com/photo-1571266028243-3716f02d2d2e?w=600&q=80',
    },
    {
      'title': 'Shekhawati & Mewari',
      'icon': Icons.audiotrack_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFD97706), Color(0xFFB45309)]),
      'image': 'https://images.unsplash.com/photo-1599827552599-eeddd59551c6?w=600&q=80',
    },
    {
      'title': 'Khatu Shyam Bhajan',
      'icon': Icons.temple_hindu_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFFF9933), Color(0xFFE11D48)]),
      'image': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
    },
    {
      'title': 'Shaadi & Vivah Geet',
      'icon': Icons.celebration_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFBE123C), Color(0xFFFF007F)]),
      'image': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80',
    },
    {
      'title': 'Garhwali & Pahadi',
      'icon': Icons.landscape_rounded,
      'gradient': LinearGradient(colors: [Color(0xFF047857), Color(0xFF0D9488)]),
      'image': 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=600&q=80',
    },
    {
      'title': 'All Indian',
      'icon': Icons.music_note_rounded,
      'gradient': LinearGradient(colors: [Color(0xFFFF9933), Color(0xFF138808)]),
      'image': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: LanguageService(),
        builder: (context, _) {
          final lang = LanguageService();
          return Consumer<PlayerProvider>(
            builder: (context, provider, child) {
              final trending = provider.trendingSongs;
              final heroSong = provider.onlineTrendingSongs.isNotEmpty
                  ? provider.onlineTrendingSongs.first
                  : (trending.isNotEmpty ? trending.first : null);

              return RefreshIndicator(
                color: AppColors.accentCyan,
                backgroundColor: AppColors.surface,
                onRefresh: () => provider.loadOnlineTrending(forceRefresh: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top App Header with Language Switcher & Upload Song Button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
                              Text(
                                lang.t('hero_subtitle'),
                                style: const TextStyle(
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF00E5FF), Color(0xFF4F46E5)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00E5FF).withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.cloud_upload_rounded, color: Colors.black, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        lang.t('upload_song'),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Profile & Account Settings Button
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF131A2A),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00E5FF).withOpacity(0.2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.person_rounded, color: Color(0xFF00E5FF), size: 18),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                // Available Live OTA Update Banner
                ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: UpdateService.availableUpdateNotifier,
                  builder: (context, updateData, _) {
                    if (updateData == null) return const SizedBox.shrink();
                    final vName = updateData['remoteName'] ?? '1.0.71';
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: InkWell(
                        onTap: () => UpdateService.checkForUpdate(context, autoPrompt: false),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB300), Color(0xFFFF6D00)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFB300).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.system_update_rounded, color: Colors.black, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.isHindi ? 'नया वर्ज़न उपलब्ध है: v$vName' : 'New Update Available: v$vName',
                                      style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      lang.isHindi ? '1-क्लिक में तुरंत अपडेट करें' : 'Tap to install OTA update directly',
                                      style: const TextStyle(color: Colors.black87, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  lang.isHindi ? 'अपडेट' : 'Update',
                                  style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Integrated Search Bar with Scope Switcher & Device Scanner
                _buildIntegratedSearchBar(context, provider, lang),

                if (_activeSearchQuery.trim().isNotEmpty)
                  _buildLiveSearchResultsView(context, provider, lang)
                else ...[
                // Discover Quick Category Tabs: All, Recent, Favorites, Artists, Albums, Playlists
                _buildDiscoverFilterChips(lang, provider),
                const SizedBox(height: 12),

                if (_activeDiscoverTab == 'recent')
                  _buildAllRecentlyPlayedView(context, provider, lang)
                else if (_activeDiscoverTab == 'favorites')
                  _buildAllFavoritesView(context, provider, lang)
                else if (_activeDiscoverTab == 'artists')
                  _buildAllArtistsView(context, provider, lang)
                else if (_activeDiscoverTab == 'albums')
                  _buildAllAlbumsView(context, provider, lang)
                else if (_activeDiscoverTab == 'playlists')
                  _buildAllPlaylistsView(context, provider, lang)
                else ...[
                // Featured Hero Banner
                if (heroSong != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () => provider.playSong(
                        heroSong,
                        queueContext: provider.onlineTrendingSongs.isNotEmpty ? provider.onlineTrendingSongs : trending,
                      ),
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
                                child: heroSong.displayCoverUrl.startsWith('http')
                                    ? CachedNetworkImage(
                                        imageUrl: heroSong.displayCoverUrl,
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
                                        child: Text(
                                          lang.t('hero_free_badge'),
                                          style: const TextStyle(
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
                                        '${heroSong.artist} | ${heroSong.genre}',
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
                                              children: [
                                                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                                const SizedBox(width: 4),
                                                Text(
                                                  lang.t('listen_free'),
                                                  style: const TextStyle(
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

                // Quick Access 2x2 Grid (Liked Songs, Recently Played, Device Audio, Share APK)
                _buildQuickAccessGrid(context, provider, lang),

                // ==========================================
                // 🕒 SECTION: RECENTLY PLAYED SHELF (जब गाने सुने गए हों)
                // ==========================================
                if (provider.recentlyPlayed.isNotEmpty)
                  _buildOnlineSection(
                    context: context,
                    title: 'Recently Played',
                    hindiTitle: 'हाल ही में सुने गए',
                    icon: Icons.history_rounded,
                    iconColor: const Color(0xFF00E5FF),
                    songs: provider.recentlyPlayed,
                    provider: provider,
                    lang: lang,
                  ),

                // ==========================================
                // ❤️ SECTION: LIKED SONGS SHELF (जब पसंदीदा गाने हों)
                // ==========================================
                if (provider.favorites.isNotEmpty)
                  _buildOnlineSection(
                    context: context,
                    title: 'Liked Songs',
                    hindiTitle: 'पसंदीदा गाने',
                    icon: Icons.favorite_rounded,
                    iconColor: const Color(0xFFFF4081),
                    songs: provider.favorites,
                    provider: provider,
                    lang: lang,
                  ),

                // ==========================================
                // 🔥 SECTION 1: TRENDING NOW (India Top 50)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'Trending Now (Top 50 Hits)',
                  hindiTitle: 'ट्रेंडिंग नाउ (टॉप 50 हिट्स)',
                  icon: Icons.whatshot_rounded,
                  iconColor: const Color(0xFFFF6D00),
                  songs: provider.onlineTrendingSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // 🎤 SECTION 2: POPULAR ARTISTS (Circle Avatars)
                // ==========================================
                _buildTopArtistsSection(context, lang),

                // ==========================================
                // 🎨 SECTION 3: BROWSE ALL GENRES & MOODS (Category Cards)
                // ==========================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.isHindi ? 'सभी श्रेणियां व मूड्स' : 'Browse All Genres & Moods',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        lang.isHindi ? 'सभी कार्ड्स (200+ गाने)' : 'All Cards (200+ Songs)',
                        style: const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 82,
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
                        imageUrl: g['image'] as String?,
                        badge: '200+ Songs',
                        isSelected: isSelected,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GenreSectionScreen(
                                title: g['title'] as String,
                                icon: g['icon'] as IconData,
                                gradient: g['gradient'] as LinearGradient,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // ==========================================
                // 🎧 SECTION 4: DJ REMIX & DANCE PARTY (डीजे वाले गाने)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'DJ Remix & Dance Party',
                  hindiTitle: 'डीजे वाले गाने (धमाकेदार रीमिक्स)',
                  icon: Icons.equalizer_rounded,
                  iconColor: const Color(0xFF00E5FF),
                  songs: provider.onlineDjSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // 🌾 SECTION 5: HARYANVI SUPERHITS (हरियाणवी सुपरहिट्स)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'Haryanvi Superhits',
                  hindiTitle: 'हरियाणवी सुपरहिट्स (सपना, मासूम, रेणुका)',
                  icon: Icons.speaker_group_rounded,
                  iconColor: const Color(0xFF10B981),
                  songs: provider.onlineHaryanviSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // 🐪 SECTION 6: RAJASTHANI SUPERHITS (राजस्थानी सुपरहिट्स)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'Rajasthani Superhits',
                  hindiTitle: 'राजस्थानी सुपरहिट्स (लोकगीत व परम्परा)',
                  icon: Icons.audiotrack_rounded,
                  iconColor: const Color(0xFFFF6F00),
                  songs: provider.onlineRajasthaniSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // 🪕 SECTION 7: MARWADI DESI & DJ (मारवाड़ी देसी व डीजे)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'Marwadi Desi & DJ Hits',
                  hindiTitle: 'मारवाड़ी देसी व डीजे धमाका',
                  icon: Icons.celebration_rounded,
                  iconColor: const Color(0xFFFF3D00),
                  songs: provider.onlineMarwadiSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // 💥 SECTION 8: BHOJPURI DHAMAKA (भोजपुरी टॉप 50)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'Bhojpuri Dhamaka Top 50',
                  hindiTitle: 'भोजपुरी धमाका (पवन सिंह, खेसारी, शिल्पी)',
                  icon: Icons.music_video_rounded,
                  iconColor: const Color(0xFFF43F5E),
                  songs: provider.onlineBhojpuriSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // 📻 SECTION 9: 90s EVERGREEN RETRO (90 के सदाबहार नगमे)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: '90s Bollywood Evergreen',
                  hindiTitle: '90s के सदाबहार नगमे (सोनू, अलका, उदित)',
                  icon: Icons.radio_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  songs: provider.onlineRetroSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // ❤️ SECTION 10: ROMANTIC MELODIES (Most Streamed Love Songs)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'Romantic Melodies',
                  hindiTitle: 'रोमांटिक मेलोडीज़ (लव सोंग्स)',
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFFF4081),
                  songs: provider.onlineRomanticSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // ⚡ SECTION 11: PUNJABI SUPERHITS (High Energy Beats)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'Punjabi Superhits',
                  hindiTitle: 'पंजाबी सुपरहिट्स (धमाकेदार बीट्स)',
                  icon: Icons.bolt_rounded,
                  iconColor: const Color(0xFFFFB300),
                  songs: provider.onlinePunjabiSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // 🙏 SECTION 12: BHAKTI & DEVOTION (Sacred Chants)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'Bhakti & Devotion',
                  hindiTitle: 'दिव्य भक्ति व पावन भजन',
                  icon: Icons.self_improvement_rounded,
                  iconColor: const Color(0xFFFF9100),
                  songs: provider.onlineBhaktiSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // ☕ SECTION 13: LO-FI & CHILL VIBES (सुकून भरे लो-फाई)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'Lo-Fi Chill & Relax',
                  hindiTitle: 'लो-फाई और सुकून (रिलैक्स बीट्स)',
                  icon: Icons.nightlife_rounded,
                  iconColor: const Color(0xFF06B6D4),
                  songs: provider.onlineLofiSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // 💔 SECTION 14: DARD BHARE NAGME (Sad Songs)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'Heartbroken & Sad Songs',
                  hindiTitle: 'दर्द भरे नगमे (इमोशनल व उदास)',
                  icon: Icons.heart_broken_rounded,
                  iconColor: const Color(0xFF64748B),
                  songs: provider.onlineSadSongs,
                  provider: provider,
                  lang: lang,
                ),

                // ==========================================
                // 🌍 SECTION 15: GLOBAL TOP 50 HITS (International Charts)
                // ==========================================
                _buildOnlineSection(
                  context: context,
                  title: 'Global Top 50 Hits',
                  hindiTitle: 'ग्लोबल टॉप 50 हिट्स',
                  icon: Icons.public_rounded,
                  iconColor: const Color(0xFF00E5FF),
                  songs: provider.onlineGlobalSongs,
                  provider: provider,
                  lang: lang,
                ),

                const SizedBox(height: 30),
                ], // end of else ...[ for all
              ], // end of else ...[ for activeSearchQuery empty
              ],
            ),
          ),
        );
      },
    );
      },
    ),
  );
}

  Widget _buildIntegratedSearchBar(BuildContext context, PlayerProvider provider, LanguageService lang) {
    final isOnline = _searchScope == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search Text Field
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _activeSearchQuery.isNotEmpty
                    ? AppColors.accentCyan
                    : Colors.white.withOpacity(0.12),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _onSearchChanged(val, provider),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: isOnline
                    ? (lang.isHindi
                        ? 'लाखों गाने, गायक या एल्बम खोजें...'
                        : 'Search millions of Hindi, Punjabi, Marwadi songs...')
                    : (lang.isHindi
                        ? 'माई लाइब्रेरी व फ़ोन के गाने खोजें...'
                        : 'Search library & device songs...'),
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.accentCyan,
                  size: 22,
                ),
                suffixIcon: _activeSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('', provider);
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Search Scope Switcher & Device Storage Scan Action
          Row(
            children: [
              // Online Streaming Pill
              GestureDetector(
                onTap: () {
                  if (_searchScope != 0) {
                    setState(() => _searchScope = 0);
                    if (_activeSearchQuery.isNotEmpty) {
                      provider.searchOnline(_activeSearchQuery);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOnline ? AppColors.accentCyan.withOpacity(0.2) : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOnline ? AppColors.accentCyan : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_download_rounded,
                        size: 14,
                        color: isOnline ? AppColors.accentCyan : Colors.white60,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        lang.isHindi ? 'ऑनलाइन संगीत' : 'Online Music',
                        style: TextStyle(
                          color: isOnline ? AppColors.accentCyan : Colors.white70,
                          fontSize: 11,
                          fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // My Library Pill
              GestureDetector(
                onTap: () {
                  if (_searchScope != 1) {
                    setState(() => _searchScope = 1);
                    if (_activeSearchQuery.isNotEmpty) {
                      provider.search(_activeSearchQuery);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: !isOnline ? const Color(0xFF10B981).withOpacity(0.2) : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !isOnline ? const Color(0xFF10B981) : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_rounded,
                        size: 14,
                        color: !isOnline ? const Color(0xFF10B981) : Colors.white60,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        lang.isHindi ? 'माई लाइब्रेरी' : 'My Library',
                        style: TextStyle(
                          color: !isOnline ? const Color(0xFF10B981) : Colors.white70,
                          fontSize: 11,
                          fontWeight: !isOnline ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Scan Device Audio Button (integrated right in the search bar row!)
              InkWell(
                onTap: () => provider.scanDeviceSongs(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentGreen.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sd_storage_rounded, size: 14, color: AppColors.accentGreen),
                      const SizedBox(width: 4),
                      Text(
                        provider.deviceSongs.isEmpty
                            ? (lang.isHindi ? 'स्कैन करें' : 'Scan Audio')
                            : '${provider.deviceSongs.length} ${lang.isHindi ? "गाने" : "Tracks"}',
                        style: const TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 10.5,
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
    );
  }

  Widget _buildLiveSearchResultsView(BuildContext context, PlayerProvider provider, LanguageService lang) {
    final isOnline = _searchScope == 0;
    final results = isOnline ? provider.onlineSearchResults : provider.searchResults;
    final isLoading = isOnline && provider.isSearchingOnline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick suggestions tags row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _searchQuickTags.map((tag) {
                final isSelected = _activeSearchQuery.toLowerCase() == tag.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      tag,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    backgroundColor: isSelected ? AppColors.accentCyan : AppColors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isSelected ? AppColors.accentCyan : Colors.white12),
                    ),
                    onPressed: () => _selectQuickTag(tag, provider),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Header with results count and Play All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${lang.isHindi ? (isOnline ? "ऑनलाइन खोज परिणाम" : "लाइब्रेरी खोज परिणाम") : (isOnline ? "Online Search Results" : "Library Search Results")} (${results.length})',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (results.isNotEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: Text(
                    lang.isHindi ? 'सभी चलाएं' : 'Play All',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onPressed: () => provider.playSong(results.first, queueContext: results),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Results List
          if (isLoading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
            )
          else if (results.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(isOnline ? Icons.music_off_rounded : Icons.folder_off_rounded, size: 48, color: Colors.white30),
                  const SizedBox(height: 12),
                  Text(
                    lang.isHindi ? 'कोई गाना नहीं मिला' : 'No songs found for "$_activeSearchQuery"',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lang.isHindi ? 'कृपया दूसरा नाम या गायक खोजें' : 'Try searching another song or artist name',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  if (!isOnline) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.sd_storage_rounded, size: 16),
                      label: Text(lang.isHindi ? 'फ़ोन स्टोरेज स्कैन करें' : 'Scan Device Audio'),
                      onPressed: () => provider.scanDeviceSongs(),
                    ),
                  ],
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final song = results[index];
                final isCurrent = provider.currentSong?.id == song.id;
                final playCount = provider.getPlayCount(song.id);

                return SongListTile(
                  song: song,
                  isCurrent: isCurrent,
                  rank: index + 1,
                  playCount: playCount,
                  onTap: () => provider.playSong(song, queueContext: results),
                );
              },
            ),
        ],
      ),
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

    final isExpanded = _expandedCategories.contains(genreKey);
    final lang = LanguageService();

    final subCategories = <String>{};
    for (final s in songs) {
      final sub = s.subCategory?.trim();
      if (sub != null && sub.isNotEmpty && sub.toLowerCase() != genreKey.toLowerCase()) {
        subCategories.add(sub);
      }
    }

    final selectedSub = _selectedSubCategories[genreKey] ?? 'All';
    final displayedSongs = (selectedSub == 'All')
        ? songs
        : songs.where((s) => s.subCategory?.trim() == selectedSub).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedCategories.remove(genreKey);
                    } else {
                      _expandedCategories.add(genreKey);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpanded ? AppColors.accentCyan.withOpacity(0.15) : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isExpanded ? AppColors.accentCyan : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isExpanded
                            ? (lang.isHindi ? 'कम करें ▲' : 'Collapse ▲')
                            : '${songs.length} Tracks ▼',
                        style: TextStyle(
                          color: isExpanded ? AppColors.accentCyan : AppColors.textSecondary,
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
        ),
        if (!isExpanded)
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
          )
        else ...[
          if (subCategories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  _buildSubCategoryChip(
                    label: '${lang.isHindi ? "सभी" : "All"} (${songs.length})',
                    isSelected: selectedSub == 'All',
                    onTap: () => setState(() => _selectedSubCategories[genreKey] = 'All'),
                  ),
                  const SizedBox(width: 8),
                  ...subCategories.map((sub) {
                    final count = songs.where((s) => s.subCategory?.trim() == sub).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildSubCategoryChip(
                        label: '$sub ($count)',
                        isSelected: selectedSub == sub,
                        onTap: () => setState(() => _selectedSubCategories[genreKey] = sub),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayedSongs.length,
            itemBuilder: (context, index) {
              final song = displayedSongs[index];
              return SongListTile(
                song: song,
                isCurrent: provider.currentSong?.id == song.id,
                onTap: () => provider.playSong(song, queueContext: displayedSongs),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSubCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentCyan.withOpacity(0.2) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accentCyan : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
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
                SongThumbnailWidget(
                  song: song,
                  size: 135,
                  borderRadius: 16,
                  isPlaying: isCurrent && provider.isPlaying,
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
                      '320k HD',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
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

  Widget _buildOnlineSection({
    required BuildContext context,
    required String title,
    required String hindiTitle,
    required IconData icon,
    required Color iconColor,
    required List<Song> songs,
    required PlayerProvider provider,
    required LanguageService lang,
  }) {
    if (songs.isEmpty && !provider.isLoadingOnlineTrending) {
      return const SizedBox.shrink();
    }

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
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    lang.isHindi ? hindiTitle : title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GenreSectionScreen(
                            title: title,
                            icon: icon,
                            gradient: LinearGradient(colors: [iconColor, iconColor.withOpacity(0.5)]),
                            initialSongs: songs,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        lang.isHindi ? 'सभी देखें' : 'See All',
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Ultra HD 320k',
                      style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (provider.isLoadingOnlineTrending && songs.isEmpty)
          const SizedBox(
            height: 190,
            child: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
          )
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: songs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final song = songs[index];
                return _buildIndianSongCard(context, song, provider, songs);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTopArtistsSection(BuildContext context, LanguageService lang) {
    final artists = JioSaavnService.getTopArtists();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            children: [
              const Icon(Icons.mic_external_on_rounded, color: Color(0xFFFF4081), size: 22),
              const SizedBox(width: 8),
              Text(
                lang.isHindi ? 'लोकप्रिय कलाकार' : 'Popular Artists',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 115,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: artists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final artist = artists[index];
              final name = artist['name'] ?? '';
              final imageUrl = artist['image'] ?? '';

              return GestureDetector(
                onTap: () {
                  final provider = Provider.of<PlayerProvider>(context, listen: false);
                  provider.searchOnline(name);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(
                        body: SearchScreen(),
                      ),
                    ),
                  );
                },
                child: SizedBox(
                  width: 78,
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFF1E293B),
                              child: const Icon(Icons.person_rounded, color: Colors.white38),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFF1E293B),
                              child: const Icon(Icons.person_rounded, color: Colors.white38),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context, PlayerProvider provider, LanguageService lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  title: lang.isHindi ? 'पसंदीदा गाने' : 'Liked Songs',
                  subtitle: '${provider.favorites.length} ${lang.isHindi ? "गाने" : "Tracks"}',
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFFF4081),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E1065), Color(0xFF4C0519)],
                  ),
                  borderColor: const Color(0xFFFF4081).withOpacity(0.35),
                  onTap: () => setState(() => _activeDiscoverTab = 'favorites'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  title: lang.isHindi ? 'हाल ही में सुने' : 'Recently Played',
                  subtitle: '${provider.recentlyPlayed.length} ${lang.isHindi ? "गाने" : "Tracks"}',
                  icon: Icons.history_rounded,
                  iconColor: const Color(0xFF00E5FF),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                  ),
                  borderColor: const Color(0xFF00E5FF).withOpacity(0.35),
                  onTap: () => setState(() => _activeDiscoverTab = 'recent'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  title: lang.t('offline_audio_title'),
                  subtitle: provider.deviceSongs.isEmpty
                      ? lang.t('offline_audio_scan')
                      : '${provider.deviceSongs.length} ${lang.t('offline_ready')}',
                  icon: Icons.sd_storage_rounded,
                  iconColor: AppColors.accentGreen,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF022C22)],
                  ),
                  borderColor: AppColors.accentGreen.withOpacity(0.35),
                  onTap: () => provider.scanDeviceSongs(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  title: lang.t('share_apk_title'),
                  subtitle: lang.t('share_apk_desc'),
                  icon: Icons.send_to_mobile_rounded,
                  iconColor: const Color(0xFFFFB300),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF451A03), Color(0xFF1C1917)],
                  ),
                  borderColor: const Color(0xFFFFB300).withOpacity(0.35),
                  onTap: () => AppShareService.shareAppApk(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required LinearGradient gradient,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverFilterChips(LanguageService lang, PlayerProvider provider) {
    final chips = [
      {'id': 'all', 'label': lang.isHindi ? 'सभी संगीत' : 'All Discover', 'icon': Icons.explore_rounded, 'count': null},
      {'id': 'recent', 'label': lang.isHindi ? 'हाल ही में सुने' : 'Recently Played', 'icon': Icons.history_rounded, 'count': provider.recentlyPlayed.length},
      {'id': 'favorites', 'label': lang.isHindi ? 'पसंदीदा' : 'Liked Songs', 'icon': Icons.favorite_rounded, 'count': provider.favorites.length},
      {'id': 'artists', 'label': lang.isHindi ? 'कलाकार' : 'Artists', 'icon': Icons.person_rounded, 'count': null},
      {'id': 'albums', 'label': lang.isHindi ? 'एल्बम' : 'Albums', 'icon': Icons.album_rounded, 'count': null},
      {'id': 'playlists', 'label': lang.isHindi ? 'प्लेलिस्ट्स' : 'Playlists', 'icon': Icons.playlist_play_rounded, 'count': null},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: chips.map((c) {
          final isSelected = _activeDiscoverTab == c['id'];
          final count = c['count'] as int?;
          final countStr = (count != null && count > 0) ? ' ($count)' : '';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                c['icon'] as IconData,
                size: 16,
                color: isSelected ? Colors.black : const Color(0xFF00E5FF),
              ),
              label: Text(
                '${c['label']}$countStr',
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.accentCyan,
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.accentCyan : Colors.white12,
                ),
              ),
              onSelected: (val) {
                if (val) {
                  setState(() => _activeDiscoverTab = c['id'] as String);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildArtistsCarousel(BuildContext context, PlayerProvider provider, LanguageService lang) {
    final artists = provider.artists;
    if (artists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.isHindi ? 'शीर्ष कलाकार' : 'Top Artists',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _activeDiscoverTab = 'artists'),
                child: Text(
                  lang.isHindi ? 'सभी देखें' : 'See All',
                  style: const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: artists.length > 15 ? 15 : artists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final artist = artists[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: artist)),
                  );
                },
                child: SizedBox(
                  width: 90,
                  child: Column(
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accentCyan.withOpacity(0.5), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentCyan.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: artist.coverUrl.startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: artist.coverUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: const Color(0xFF131A2A)),
                                  errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFF131A2A),
                                    child: Center(
                                      child: Text(
                                        artist.name.isNotEmpty ? artist.name[0] : '🎵',
                                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF1E1B4B),
                                  child: Center(
                                    child: Text(
                                      artist.name.isNotEmpty ? artist.name[0] : '🎵',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (artist.isVerified) ...[
                            const SizedBox(width: 2),
                            const Icon(Icons.verified_rounded, color: AppColors.accentCyan, size: 12),
                          ],
                        ],
                      ),
                      Text(
                        '${artist.songCount} ${lang.isHindi ? "गाने" : "Tracks"}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumsCarousel(BuildContext context, PlayerProvider provider, LanguageService lang) {
    final albums = provider.albums;
    if (albums.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.isHindi ? 'लोकप्रिय एल्बम' : 'Popular Albums',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _activeDiscoverTab = 'albums'),
                child: Text(
                  lang.isHindi ? 'सभी देखें' : 'See All',
                  style: const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 195,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: albums.length > 15 ? 15 : albums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final album = albums[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
                  );
                },
                child: SizedBox(
                  width: 135,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SongThumbnailWidget(
                        song: album.songs.first,
                        size: 135,
                        borderRadius: 16,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        album.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '${album.songCount} ${lang.isHindi ? "गाने" : "Tracks"}',
                        style: const TextStyle(
                          color: AppColors.accentCyan,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllArtistsView(BuildContext context, PlayerProvider provider, LanguageService lang) {
    final artists = provider.artists;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${lang.isHindi ? "सभी कलाकार" : "All Artists"} (${artists.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.72,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
            ),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: artist)),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accentCyan.withOpacity(0.5), width: 2),
                      ),
                      child: ClipOval(
                        child: artist.coverUrl.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: artist.coverUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: const Color(0xFF131A2A)),
                                errorWidget: (_, __, ___) => Container(color: const Color(0xFF131A2A)),
                              )
                            : Container(
                                color: const Color(0xFF1E1B4B),
                                child: Center(
                                  child: Text(
                                    artist.name.isNotEmpty ? artist.name[0] : '🎵',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${artist.songCount} ${lang.isHindi ? "गाने" : "Tracks"}',
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAllAlbumsView(BuildContext context, PlayerProvider provider, LanguageService lang) {
    final albums = provider.albums;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${lang.isHindi ? "सभी एल्बम" : "All Albums"} (${albums.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SongThumbnailWidget(
                        song: album.songs.first,
                        size: double.infinity,
                        borderRadius: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                    ),
                    Text(
                      '${album.songCount} ${lang.isHindi ? "गाने" : "Tracks"}',
                      style: const TextStyle(color: AppColors.accentCyan, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAllPlaylistsView(BuildContext context, PlayerProvider provider, LanguageService lang) {
    final playlists = provider.curatedPlaylists;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${lang.isHindi ? "सभी प्लेलिस्ट्स व फ़ोल्डर" : "All Playlists & Folders"} (${playlists.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pl = playlists[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: pl.songs.isNotEmpty
                      ? SongThumbnailWidget(song: pl.songs.first, size: 50, borderRadius: 10)
                      : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.playlist_play_rounded, color: AppColors.accentCyan),
                        ),
                  title: Text(
                    pl.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${pl.songs.length} ${lang.isHindi ? "गाने" : "Tracks"} | ${pl.description}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () {
                    if (pl.songs.isNotEmpty) {
                      provider.playSong(pl.songs.first, queueContext: pl.songs);
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAllRecentlyPlayedView(BuildContext context, PlayerProvider provider, LanguageService lang) {
    final recentSongs = List<Song>.from(provider.recentlyPlayed);

    // Smart auto-sort: Songs played more often float to the top
    recentSongs.sort((a, b) {
      final countA = provider.getPlayCount(a.id);
      final countB = provider.getPlayCount(b.id);
      if (countB != countA) return countB.compareTo(countA);
      return 0;
    });

    if (recentSongs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.history_rounded, size: 48, color: Color(0xFF00E5FF)),
              ),
              const SizedBox(height: 16),
              Text(
                lang.isHindi ? 'कोई हालिया गाना नहीं' : 'No Recently Played Songs',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                lang.isHindi
                    ? 'अपनी पसंद का कोई भी गाना चलाएं, वह यहां स्वतः आ जाएगा।'
                    : 'Play any track from Discover or Library to build your listening history.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: Text(
                  lang.isHindi ? 'सभी संगीत एक्सप्लोर करें' : 'Explore All Songs',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => setState(() => _activeDiscoverTab = 'all'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lang.isHindi ? "हाल ही में सुने गए" : "Recently Played"} (${recentSongs.length})',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang.isHindi ? 'सर्वाधिक सुने गए गाने स्वतः ऊपर' : 'Top played tracks automatically ranked first',
                    style: const TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  lang.isHindi ? 'सभी चलाएं' : 'Play All',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () => provider.playSong(recentSongs.first, queueContext: recentSongs),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentSongs.length,
            itemBuilder: (context, index) {
              final song = recentSongs[index];
              final playCount = provider.getPlayCount(song.id);
              final isCurrent = provider.currentSong?.id == song.id;

              return SongListTile(
                song: song,
                isCurrent: isCurrent,
                rank: index + 1,
                playCount: playCount,
                onTap: () => provider.playSong(song, queueContext: recentSongs),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAllFavoritesView(BuildContext context, PlayerProvider provider, LanguageService lang) {
    final favSongs = List<Song>.from(provider.favorites);

    // Smart auto-sort: Songs played more often float to the top
    favSongs.sort((a, b) {
      final countA = provider.getPlayCount(a.id);
      final countB = provider.getPlayCount(b.id);
      if (countB != countA) return countB.compareTo(countA);
      return 0;
    });

    if (favSongs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.favorite_rounded, size: 48, color: Color(0xFFFF4081)),
              ),
              const SizedBox(height: 16),
              Text(
                lang.isHindi ? 'कोई पसंदीदा गाना नहीं' : 'No Liked Songs Yet',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                lang.isHindi
                    ? 'किसी भी गाने पर दिल ❤️ के निशान को दबाकर उसे अपनी पसंद में जोड़ें।'
                    : 'Tap the heart icon on any song to save it to your favorite tracks.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4081),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: Text(
                  lang.isHindi ? 'सभी संगीत एक्सप्लोर करें' : 'Explore All Songs',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => setState(() => _activeDiscoverTab = 'all'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lang.isHindi ? "पसंदीदा गाने" : "Liked Songs"} (${favSongs.length})',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang.isHindi ? 'सर्वाधिक सुने गए गाने स्वतः ऊपर' : 'Top played tracks automatically ranked first',
                    style: const TextStyle(color: Color(0xFFFF4081), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4081),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  lang.isHindi ? 'सभी चलाएं' : 'Play All',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () => provider.playSong(favSongs.first, queueContext: favSongs),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: favSongs.length,
            itemBuilder: (context, index) {
              final song = favSongs[index];
              final playCount = provider.getPlayCount(song.id);
              final isCurrent = provider.currentSong?.id == song.id;

              return SongListTile(
                song: song,
                isCurrent: isCurrent,
                rank: index + 1,
                playCount: playCount,
                onTap: () => provider.playSong(song, queueContext: favSongs),
              );
            },
          ),
        ],
      ),
    );
  }
}
