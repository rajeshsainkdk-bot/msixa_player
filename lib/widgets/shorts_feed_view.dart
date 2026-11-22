import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/short_video_item.dart';
import '../services/app_share_service.dart';
import '../services/language_service.dart';
import '../services/shorts_feed_service.dart';
import '../services/shorts_player_controller.dart';
import '../theme/app_colors.dart';

/// Production-ready YouTube Shorts Feed View (Sections 1-7)
/// Integrates official YouTube Data API v3 discovery with official
/// YouTube IFrame Player API embedded vertical playback.
class ShortsFeedView extends StatefulWidget {
  final VoidCallback? onBackToDeviceVideos;
  const ShortsFeedView({Key? key, this.onBackToDeviceVideos}) : super(key: key);

  @override
  State<ShortsFeedView> createState() => _ShortsFeedViewState();
}

class _ShortsFeedViewState extends State<ShortsFeedView> {
  final ShortsFeedService _feedService = ShortsFeedService();
  final ShortsPlayerController _playbackController = ShortsPlayerController();
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  List<ShortVideoItem> _shorts = [];
  bool _isLoading = true;
  String _activeCategory = 'Trending';
  bool _isSearching = false;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    AppShareService.keepScreenOn(true);
    _playbackController.onVideoEnded = (index) {
      _onVideoCompleted(index);
    };
    _loadInitialFeed(_activeCategory);
  }

  @override
  void dispose() {
    AppShareService.keepScreenOn(false);
    _playbackController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialFeed(String categoryId) async {
    final immediateList = _feedService.getInitialShorts(categoryId);
    setState(() {
      _shorts = immediateList;
      _isLoading = immediateList.isEmpty;
    });

    if (immediateList.isNotEmpty) {
      _playbackController.onPageChanged(newIndex: 0, items: _shorts);
    }

    try {
      final freshList = await _feedService.fetchFeedPage(categoryId: categoryId, isRefresh: true);
      if (mounted && freshList.isNotEmpty) {
        setState(() {
          final existingIds = _shorts.map((e) => e.id).toSet();
          final uniqueNew = freshList.where((e) => !existingIds.contains(e.id)).toList();
          _shorts.addAll(uniqueNew);
          _isLoading = false;
        });
        _playbackController.onPageChanged(newIndex: _playbackController.activeIndex, items: _shorts);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreShorts() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;

    try {
      final nextBatch = await _feedService.fetchFeedPage(categoryId: _activeCategory);
      if (mounted && nextBatch.isNotEmpty) {
        setState(() {
          _shorts.addAll(nextBatch);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final results = await _feedService.searchShorts(query.trim());
      if (mounted) {
        setState(() {
          _shorts = results.isNotEmpty ? results : _feedService.getInitialShorts('Trending');
          _isLoading = false;
        });
        if (_shorts.isNotEmpty) {
          _playbackController.onPageChanged(newIndex: 0, items: _shorts);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onPageChanged(int index) {
    _playbackController.onPageChanged(newIndex: index, items: _shorts);

    // Infinite Feed Pagination trigger: when within 3 videos from the end
    if (index >= _shorts.length - 3 && !_isLoadingMore) {
      _loadMoreShorts();
    }
  }

  void _onVideoCompleted(int index) {
    if (!mounted) return;
    if (index < _shorts.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      // Reached the end: fetch next batch immediately and advance without repeating
      _loadMoreShorts().then((_) {
        if (mounted && _shorts.length > index + 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full-Height Vertical Swipeable PageView Feed (Section 3)
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.accentCyan),
            )
          else if (_shorts.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    lang.isHindi ? 'कोई शॉर्ट्स वीडियो नहीं मिला' : 'No short videos found',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _loadInitialFeed(_activeCategory),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(lang.isHindi ? 'ताज़ा करें' : 'Refresh'),
                  ),
                ],
              ),
            )
          else
            RefreshIndicator(
              color: AppColors.accentCyan,
              backgroundColor: const Color(0xFF131A2A),
              onRefresh: () async {
                await _loadInitialFeed(_activeCategory);
              },
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const PageScrollPhysics(),
                itemCount: _shorts.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final isCurrent = index == _playbackController.activeIndex;
                  final item = _shorts[index];
                  final controller = _playbackController.getOrCreateController(
                    index: index,
                    item: item,
                    autoPlay: isCurrent,
                  );

                  return _OfficialShortVideoCard(
                    key: ValueKey(item.id),
                    short: item,
                    isActive: isCurrent,
                    controller: controller,
                    playbackController: _playbackController,
                    onVideoCompleted: () => _onVideoCompleted(index),
                    onLikeToggle: () {
                      setState(() {
                        item.isLiked = !item.isLiked;
                        item.likesCount += item.isLiked ? 1 : -1;
                      });
                    },
                  );
                },
              ),
            ),

          // 2. Top Header Overlay (Category Chips & Search)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    if (widget.onBackToDeviceVideos != null)
                      InkWell(
                        onTap: widget.onBackToDeviceVideos,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                lang.isHindi ? 'डिवाइस' : 'Device',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _isSearching
                          ? Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.accentCyan),
                              ),
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: lang.isHindi
                                      ? 'शॉर्ट्स खोजें (बॉलीवुड, मारवाड़ी, डीजे)...'
                                      : 'Search Indian Music shorts...',
                                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accentCyan, size: 18),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                                    onPressed: () {
                                      setState(() => _isSearching = false);
                                      _loadInitialFeed(_activeCategory);
                                    },
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onSubmitted: _performSearch,
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ShortsFeedService.categories.map((cat) {
                                  final isSelected = _activeCategory == cat.id;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _activeCategory = cat.id);
                                        _loadInitialFeed(cat.id);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.accentCyan : Colors.black.withOpacity(0.55),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isSelected ? AppColors.accentCyan : Colors.white24,
                                          ),
                                        ),
                                        child: Text(
                                          lang.isHindi ? cat.labelHi : cat.labelEn,
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.white,
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                    if (!_isSearching)
                      IconButton(
                        icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                        onPressed: () => setState(() => _isSearching = true),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Official Embedded YouTube Video Card (Sections 3, 5, 6)
/// Renders official YouTube IFrame Player with native controls overlay.
class _OfficialShortVideoCard extends StatefulWidget {
  final ShortVideoItem short;
  final bool isActive;
  final ShortsIFrameInstance controller;
  final ShortsPlayerController playbackController;
  final VoidCallback onLikeToggle;
  final VoidCallback onVideoCompleted;

  const _OfficialShortVideoCard({
    Key? key,
    required this.short,
    required this.isActive,
    required this.controller,
    required this.playbackController,
    required this.onLikeToggle,
    required this.onVideoCompleted,
  }) : super(key: key);

  @override
  State<_OfficialShortVideoCard> createState() => _OfficialShortVideoCardState();
}

class _OfficialShortVideoCardState extends State<_OfficialShortVideoCard> {
  bool _isPlaying = true;
  bool _showTransientPlayIcon = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      widget.controller.playVideo();
      _isPlaying = true;
    }
  }

  @override
  void didUpdateWidget(covariant _OfficialShortVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        widget.controller.playVideo();
        setState(() => _isPlaying = true);
      } else {
        widget.controller.pauseVideo();
        setState(() => _isPlaying = false);
      }
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        widget.controller.pauseVideo();
        _isPlaying = false;
      } else {
        widget.controller.playVideo();
        _isPlaying = true;
      }
      _showTransientPlayIcon = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showTransientPlayIcon = false);
    });
  }

  Future<void> _openInYouTube() async {
    final uri = Uri.parse('https://www.youtube.com/shorts/${widget.short.id}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _handleShare() async {
    await Share.share(
      'Check out "${widget.short.title}" on YouTube Shorts: https://www.youtube.com/shorts/${widget.short.id}',
      subject: widget.short.title,
    );
  }

  void _showCommentsModal(BuildContext context) {
    final lang = LanguageService();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang.isHindi ? 'टिप्पणियाँ (Comments)' : 'Comments',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: _openInYouTube,
                    child: Row(
                      children: const [
                        Icon(Icons.open_in_new_rounded, color: AppColors.accentCyan, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'YouTube',
                          style: TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                lang.isHindi
                    ? 'यह वीडियो आधिकारिक YouTube Shorts से स्ट्रीम हो रहा है। सभी टिप्पणियाँ देखने के लिए YouTube में खोलें।'
                    : 'This video is officially streamed from YouTube Shorts. Open in YouTube to view or participate in comments.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openInYouTube();
                  },
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  label: Text(lang.isHindi ? 'यूट्यूब ऐप में खोलें' : 'Open in YouTube App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Official YouTube IFrame Player (Section 2, 5)
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: widget.controller.webViewController != null
                  ? IgnorePointer(
                      ignoring: true,
                      child: WebViewWidget(
                        controller: widget.controller.webViewController!,
                      ),
                    )
                  : Container(color: Colors.black),
            ),
          ),

          // Buffering Indicator
          if (widget.controller.state == ShortsPlaybackState.buffering ||
              widget.controller.state == ShortsPlaybackState.initializing)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentCyan,
                strokeWidth: 2.5,
              ),
            ),

          // Error and Retry State
          if (widget.controller.state == ShortsPlaybackState.error)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    LanguageService().isHindi
                        ? 'वीडियो लोड करने में समस्या हुई'
                        : 'Unable to load video',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openInYouTube,
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                    label: Text(LanguageService().isHindi ? 'यूट्यूब पर देखें' : 'Watch on YouTube'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

          // 2. Play / Pause Transient Feedback Icon
          if (_showTransientPlayIcon)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: Icon(
                  _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: Colors.white,
                  size: 54,
                ),
              ),
            ),

          // 3. Bottom Text Gradient Vignette
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 240,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.92),
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Left Bottom Video Title & Creator Attribution (Section 6)
          Positioned(
            left: 16,
            bottom: 30,
            right: 86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentCyan.withOpacity(0.5)),
                  ),
                  child: Text(
                    widget.short.category,
                    style: const TextStyle(color: AppColors.accentCyan, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.short.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded, color: AppColors.accentCyan, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.short.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 5. Right Floating Actions Column (Section 6)
          Positioned(
            right: 12,
            bottom: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Like Button
                _buildActionItem(
                  icon: widget.short.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: widget.short.isLiked ? Colors.redAccent : Colors.white,
                  label: '${widget.short.likesCount}',
                  onTap: widget.onLikeToggle,
                ),
                const SizedBox(height: 16),

                // 2. Comments Button
                _buildActionItem(
                  icon: Icons.comment_rounded,
                  color: Colors.white,
                  label: 'टिप्पणी',
                  onTap: () => _showCommentsModal(context),
                ),
                const SizedBox(height: 16),

                // 3. Audio Mute Toggle
                _buildActionItem(
                  icon: widget.playbackController.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: widget.playbackController.isMuted ? Colors.redAccent : Colors.white,
                  label: widget.playbackController.isMuted ? 'म्यूट' : 'आवाज़',
                  onTap: () {
                    widget.playbackController.toggleMute();
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),

                // 4. Open in YouTube Action (Section 6 & 12 Compliance)
                _buildActionItem(
                  icon: Icons.play_circle_fill_rounded,
                  color: const Color(0xFFFF0000), // YouTube Red
                  label: 'यूट्यूब',
                  onTap: _openInYouTube,
                ),
                const SizedBox(height: 16),

                // 5. Native Share Action
                _buildActionItem(
                  icon: Icons.share_rounded,
                  color: Colors.white,
                  label: 'शेयर',
                  onTap: _handleShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}
