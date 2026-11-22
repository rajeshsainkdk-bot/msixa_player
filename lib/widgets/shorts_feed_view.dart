import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../models/short_video_item.dart';
import '../services/app_share_service.dart';
import '../services/language_service.dart';
import '../services/shorts_feed_service.dart';
import '../services/shorts_service.dart';
import '../services/shorts_player_controller.dart';
import '../services/youtube_subscription_service.dart';
import '../theme/app_colors.dart';

/// Pure In-App YouTube Shorts Feed View
/// Matches official YouTube Shorts layout:
/// - Floating right-side buttons (Thumbs Up with count, Thumbs Down 'Dislike', Comments, Share, Download, '...')
/// - Compact bottom creator row with avatar, channel name, and red '+FOLLOW' subscribe button
/// - Google Account Picker dialog on subscribe tap
/// - 100% In-App Playback, Zero External Redirection, No Ads, Strictly Vertical 9:16 Shorts with Auto-Scroll
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
    YouTubeSubscriptionService().init();

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

    // Continuous Infinite Pagination: prefetch when within 3 videos of list end
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
          // 1. Full-Height Vertical Swipeable PageView Feed (Native In-App Playback)
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

                  return _NativeShortVideoCard(
                    key: ValueKey(item.id),
                    short: item,
                    isActive: isCurrent,
                    instance: controller,
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

          // 2. Top Header Overlay (Simple '<' Back Button from screenshot + Categories)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    // Simple Back Arrow '<' matching screenshot
                    GestureDetector(
                      onTap: () {
                        if (widget.onBackToDeviceVideos != null) {
                          widget.onBackToDeviceVideos!();
                        } else if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Indian Categories or Search
                    Expanded(
                      child: _isSearching
                          ? Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.accentCyan),
                              ),
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: lang.isHindi ? 'शॉर्ट्स खोजें (मारवाड़ी, डीजे, भक्ति)...' : 'Search any shorts...',
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
                                  final isSelected = _activeCategory.toLowerCase() == cat.id.toLowerCase();
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
                                          color: isSelected ? Colors.white : Colors.black.withOpacity(0.45),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isSelected ? Colors.white : Colors.white24,
                                          ),
                                        ),
                                        child: Text(
                                          lang.isHindi ? cat.labelHi : cat.labelEn,
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.white,
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

/// Pure In-App Native Short Video Player Card
class _NativeShortVideoCard extends StatefulWidget {
  final ShortVideoItem short;
  final bool isActive;
  final ShortsPlaybackInstance instance;
  final ShortsPlayerController playbackController;
  final VoidCallback onLikeToggle;
  final VoidCallback onVideoCompleted;

  const _NativeShortVideoCard({
    Key? key,
    required this.short,
    required this.isActive,
    required this.instance,
    required this.playbackController,
    required this.onLikeToggle,
    required this.onVideoCompleted,
  }) : super(key: key);

  @override
  State<_NativeShortVideoCard> createState() => _NativeShortVideoCardState();
}

class _NativeShortVideoCardState extends State<_NativeShortVideoCard> {
  final ShortsService _shortsService = ShortsService();
  final YouTubeSubscriptionService _subService = YouTubeSubscriptionService();

  bool _isPlaying = true;
  bool _showTransientPlayIcon = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isDisliked = false;
  final int _commentsCount = 322;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      widget.instance.playVideo();
      _isPlaying = true;
    }
  }

  @override
  void didUpdateWidget(covariant _NativeShortVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        widget.instance.videoPlayerController?.seekTo(Duration.zero);
        widget.instance.playVideo();
        setState(() => _isPlaying = true);
      } else {
        widget.instance.pauseVideo();
        setState(() => _isPlaying = false);
      }
    }
  }

  void _togglePlayPause() {
    setState(() {
      final ctrl = widget.instance.videoPlayerController;
      if (ctrl != null && ctrl.value.isInitialized) {
        if (ctrl.value.isPlaying) {
          ctrl.pause();
          _isPlaying = false;
        } else {
          ctrl.play();
          _isPlaying = true;
        }
      } else {
        _isPlaying = !_isPlaying;
      }
      _showTransientPlayIcon = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showTransientPlayIcon = false);
    });
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      final k = (count / 1000).toStringAsFixed(count % 1000 >= 100 ? 1 : 0);
      return '${k}K';
    }
    return '$count';
  }

  Future<void> _handleDownload(BuildContext context) async {
    if (_isDownloading) return;
    final lang = LanguageService();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final path = await _shortsService.downloadShort(
      widget.short,
      onProgress: (p) {
        if (mounted) setState(() => _downloadProgress = p);
      },
    );

    if (mounted) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path != null
                ? (lang.isHindi ? 'वीडियो डाउनलोड हो गया! (गैलरी में सेव्ड)' : 'Video downloaded to gallery!')
                : (lang.isHindi ? 'डाउनलोड विफल रहा' : 'Download failed'),
          ),
          backgroundColor: path != null ? AppColors.accentCyan : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleWhatsAppStatus(BuildContext context) async {
    final lang = LanguageService();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(lang.isHindi ? 'व्हाट्सएप स्टेटस तैयार हो रहा है...' : 'Preparing WhatsApp Status...'),
          ],
        ),
        backgroundColor: const Color(0xFF25D366),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );

    final success = await _shortsService.shareToWhatsAppStatus(
      widget.short,
      onProgress: (p) {
        if (mounted) setState(() => _downloadProgress = p);
      },
    );

    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.isHindi ? 'व्हाट्सएप नहीं मिला या स्टेटस नहीं लग सका' : 'Could not launch WhatsApp status'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleGeneralShare() async {
    final path = widget.short.localPath;
    if (path != null && File(path).existsSync()) {
      await Share.shareXFiles([XFile(path)], text: widget.short.title);
    } else {
      final cached = await _shortsService.downloadShort(widget.short);
      if (cached != null) {
        await Share.shareXFiles([XFile(cached)], text: widget.short.title);
      } else {
        await Share.share(
          'Check out "${widget.short.title}" on Msixa Player!\nhttps://youtube.com/shorts/${widget.short.id}',
          subject: widget.short.title,
        );
      }
    }
  }

  void _showShareModal(BuildContext context) {
    final lang = LanguageService();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E283C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  lang.isHindi ? 'शेयर करें (Share)' : 'Share',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // 1. WhatsApp Status
                    _buildShareModalOption(
                      icon: Icons.share_rounded,
                      color: const Color(0xFF25D366),
                      label: lang.isHindi ? 'व्हाट्सएप स्टेटस' : 'WhatsApp Status',
                      onTap: () {
                        Navigator.pop(modalCtx);
                        _handleWhatsAppStatus(context);
                      },
                    ),
                    // 2. WhatsApp Direct
                    _buildShareModalOption(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      label: 'WhatsApp',
                      onTap: () {
                        Navigator.pop(modalCtx);
                        _handleGeneralShare();
                      },
                    ),
                    // 3. Copy Link
                    _buildShareModalOption(
                      icon: Icons.link_rounded,
                      color: const Color(0xFF00E5FF),
                      label: lang.isHindi ? 'लिंक कॉपी' : 'Copy link',
                      onTap: () async {
                        Navigator.pop(modalCtx);
                        await Clipboard.setData(ClipboardData(text: 'https://youtube.com/shorts/${widget.short.id}'));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(lang.isHindi ? 'लिंक क्लिपबोर्ड पर कॉपी हो गया!' : 'Link copied to clipboard!'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    // 4. More Apps
                    _buildShareModalOption(
                      icon: Icons.more_horiz_rounded,
                      color: Colors.white,
                      label: lang.isHindi ? 'अन्य ऐप्स' : 'More',
                      onTap: () {
                        Navigator.pop(modalCtx);
                        _handleGeneralShare();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareModalOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptionsModal(BuildContext context) {
    final lang = LanguageService();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                // Mute / Unmute
                ListTile(
                  leading: Icon(
                    widget.playbackController.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: widget.playbackController.isMuted ? Colors.redAccent : AppColors.accentCyan,
                  ),
                  title: Text(
                    widget.playbackController.isMuted
                        ? (lang.isHindi ? 'आवाज़ चालू करें (Unmute)' : 'Unmute audio')
                        : (lang.isHindi ? 'आवाज़ बंद करें (Mute)' : 'Mute audio'),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    widget.playbackController.toggleMute();
                    setState(() {});
                  },
                ),
                // Connected Google Account
                ListTile(
                  leading: const Icon(Icons.account_circle_rounded, color: Color(0xFF4285F4)),
                  title: Text(
                    _subService.hasGoogleAccount
                        ? '${_subService.userGmail}'
                        : (lang.isHindi ? 'Google अकाउंट कनेक्ट करें' : 'Connect Google Account'),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    _subService.hasGoogleAccount
                        ? (lang.isHindi ? 'अकाउंट बदलें या नया जोड़ें' : 'Switch or add account')
                        : (lang.isHindi ? 'सब्सक्राइब करने के लिए लॉगिन करें' : 'Sign in to subscribe'),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _showGoogleAccountPicker(context, widget.short.author);
                  },
                ),
                // WhatsApp Status shortcut
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                  title: Text(
                    lang.isHindi ? 'सीधा व्हाट्सएप स्टेटस लगाएं' : 'Share to WhatsApp Status',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _handleWhatsAppStatus(context);
                  },
                ),
                // Video Quality info
                ListTile(
                  leading: const Icon(Icons.hd_rounded, color: AppColors.accentCyan),
                  title: Text(
                    lang.isHindi ? 'वीडियो क्वालिटी (HD 1080p Native)' : 'Video Quality (HD 1080p Native)',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    lang.isHindi ? 'नॉन-स्टॉप बफर-फ्री प्लेबैक' : 'Smooth buffer-free playback',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCommentsModal(BuildContext context) {
    final lang = LanguageService();
    final commentController = TextEditingController();
    final commentsList = [
      {'user': 'राजेश सैन', 'text': 'शानदार डांस! दिल खुश हो गया ❤️', 'time': 'अभी'},
      {'user': 'सुनील शर्मा', 'text': 'सुपरहिट देसी बीट्स 🔥🔥', 'time': '10 मिनट पहले'},
      {'user': 'कविता राठौड़', 'text': 'फुल बास साउंड, मजा आ गया!', 'time': '1 घंटा पहले'},
      {'user': 'Strictly Fan', 'text': 'Great energy and screen presence 👌', 'time': '2 घंटे पहले'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: SizedBox(
                height: 440,
                child: Column(
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          lang.isHindi ? 'टिप्पणियाँ (Comments)' : 'Comments',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: commentsList.length,
                        itemBuilder: (c, idx) {
                          final item = commentsList[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.accentCyan.withOpacity(0.3),
                                  child: Text(
                                    item['user']![0],
                                    style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            item['user']!,
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            item['time']!,
                                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item['text']!,
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E283C),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: TextField(
                                controller: commentController,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: lang.isHindi ? 'अपनी टिप्पणी लिखें...' : 'Add a comment...',
                                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppColors.accentCyan),
                            onPressed: () {
                              final text = commentController.text.trim();
                              if (text.isNotEmpty) {
                                setModalState(() {
                                  commentsList.insert(0, {
                                    'user': _subService.userGmail ?? (lang.isHindi ? 'आप (यूजर)' : 'You'),
                                    'text': text,
                                    'time': 'अभी',
                                  });
                                  commentController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleSubscribeToggle() {
    final author = widget.short.author;
    final lang = LanguageService();

    if (_subService.isSubscribed(author)) {
      _subService.toggleSubscribe(author);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.isHindi ? '$author की सदस्यता समाप्त की' : 'Unsubscribed from $author'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // If user has not linked Google account yet, prompt the official Google Account Chooser!
    if (!_subService.hasGoogleAccount) {
      _showGoogleAccountPicker(context, author);
    } else {
      _subService.toggleSubscribe(author);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.isHindi ? '🎉 $author को सब्सक्राइब कर लिया गया!' : 'Subscribed to $author!'),
          backgroundColor: const Color(0xFF00E5FF),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Google Account Chooser Dialog (Prompts user to select their phone Google Account)
  void _showGoogleAccountPicker(BuildContext context, String author) {
    final lang = LanguageService();
    final deviceAccounts = _subService.getAvailableDeviceAccounts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF202124), // Google Dark Surface
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Google "G" Logo Header
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: Color(0xFF4285F4),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Center(
                  child: Text(
                    lang.isHindi ? 'Google खाता चुनें' : 'Choose an account',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    lang.isHindi
                        ? 'YouTube पर @$author को सब्सक्राइब करने के लिए'
                        : 'to subscribe to @$author on YouTube',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),

                // Available Phone Google Accounts List
                ...deviceAccounts.map((acc) {
                  final email = acc['email'] ?? '';
                  final name = acc['name'] ?? email.split('@').first;
                  final isSelected = _subService.userGmail?.toLowerCase() == email.toLowerCase();

                  return InkWell(
                    onTap: () async {
                      Navigator.pop(modalCtx);
                      await _subService.setGoogleAccount(email, displayName: name);
                      await _subService.toggleSubscribe(author);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              lang.isHindi
                                  ? '✓ $email से YouTube कनेक्ट हुआ • @$author को सब्सक्राइब किया!'
                                  : '✓ Connected as $email • Subscribed to @$author!',
                            ),
                            backgroundColor: const Color(0xFF00E5FF),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isSelected ? const Color(0xFF4285F4) : const Color(0xFF0F9D58),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'G',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  email,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF4285F4), size: 20),
                        ],
                      ),
                    ),
                  );
                }),

                // Add Another Account Option
                InkWell(
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _showCustomEmailInputDialog(context, author);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white70, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          lang.isHindi ? 'दूसरा खाता जोड़ें' : 'Use another account',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),

                // Google Terms/Privacy Footer Note
                Center(
                  child: Text(
                    lang.isHindi
                        ? 'जारी रखने के लिए, Google आपका नाम और ईमेल पता YouTube के साथ साझा करेगा।'
                        : 'To continue, Google will share your name and email address with YouTube.',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomEmailInputDialog(BuildContext context, String author) {
    final lang = LanguageService();
    final emailCtrl = TextEditingController(text: 'rajesh.sain.kdk@gmail.com');

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF202124),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang.isHindi ? 'Google अकाउंट दर्ज करें' : 'Enter Google Account',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.isHindi
                    ? 'YouTube पर @$author को सब्सक्राइब करने के लिए अपना Gmail पता डालें:'
                    : 'Enter your Gmail address to subscribe to @$author on YouTube:',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Gmail / Google ID',
                  labelStyle: const TextStyle(color: AppColors.accentCyan),
                  filled: true,
                  fillColor: const Color(0xFF2D2F33),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.accentCyan, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text(lang.isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isNotEmpty) {
                  Navigator.pop(dlgCtx);
                  await _subService.setGoogleAccount(email);
                  await _subService.toggleSubscribe(author);
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lang.isHindi
                              ? '✓ $email से YouTube कनेक्ट हुआ • @$author को सब्सक्राइब किया!'
                              : '✓ Connected as $email • Subscribed to @$author!',
                        ),
                        backgroundColor: const Color(0xFF00E5FF),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(lang.isHindi ? 'सब्सक्राइब करें' : 'Subscribe'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.instance.videoPlayerController;
    final isReady = ctrl != null && ctrl.value.isInitialized;
    final isSubscribed = _subService.isSubscribed(widget.short.author);

    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Native In-App Video Player (Strictly 9:16 Vertical Shorts, Zero Over-Zooming)
          if (isReady)
            Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: ctrl.value.size.width > 0 ? ctrl.value.size.width : 720,
                      height: ctrl.value.size.height > 0 ? ctrl.value.size.height : 1280,
                      child: VideoPlayer(ctrl),
                    ),
                  ),
                ),
              ),
            )
          else
            Stack(
              fit: StackFit.expand,
              children: [
                if (widget.short.thumbnailUrl.isNotEmpty)
                  Image.network(
                    widget.short.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0A0E17)),
                  )
                else
                  Container(color: const Color(0xFF0A0E17)),
                const Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                ),
              ],
            ),

          // Buffering Indicator
          if (isReady && ctrl.value.isBuffering)
            const Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  color: AppColors.accentCyan,
                  strokeWidth: 3,
                ),
              ),
            ),

          // 2. Center Play/Pause Transient Feedback Icon
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

          // 3. Bottom Progress Bar
          if (isReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                ctrl,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF00E5FF),
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),

          // 4. Bottom Gradient Vignette for Readability
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 250,
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

          // 5. Left Bottom Creator Details & Compact Subscribe Button (EXACT MATCH TO SCREENSHOT)
          Positioned(
            left: 14,
            bottom: 20,
            right: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Video Title (Clean, 1-2 lines with drop shadow)
                Text(
                  widget.short.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Creator Row: [Avatar (32dp)] [Channel Name] [Red +FOLLOW Button]
                Row(
                  children: [
                    // 1. Creator Circular Avatar (Compact 32x32)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2979FF), Color(0xFF00E5FF)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.short.author.isNotEmpty ? widget.short.author[0].toUpperCase() : 'M',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. Channel Name (Small bold white)
                    Flexible(
                      child: Text(
                        widget.short.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 3. Compact Red Subscribe Button (+FOLLOW / SUBSCRIBE)
                    GestureDetector(
                      onTap: _handleSubscribeToggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSubscribed
                              ? Colors.white.withOpacity(0.2)
                              : const Color(0xFFE50914), // Official YouTube Red
                          borderRadius: BorderRadius.circular(4), // Clean rounded rectangle from screenshot
                          border: Border.all(
                            color: isSubscribed ? Colors.white30 : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSubscribed)
                              const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                            else
                              const Text(
                                '+',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            const SizedBox(width: 3),
                            Text(
                              isSubscribed ? 'SUBSCRIBED' : 'FOLLOW',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Audio Track Tag
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded, color: Colors.white70, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${widget.short.author} • Original Audio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 6. Right Side Panel Actions Suite (EXACT MATCH TO SCREENSHOT)
          // 1. Thumbs Up (Like) with count (e.g. 94K)
          // 2. Thumbs Down (Dislike) with label 'Dislike'
          // 3. Comments with count (e.g. 322)
          // 4. Share with label 'Share'
          // 5. Download with label 'Download'
          // 6. More options '...' with no label
          Positioned(
            right: 12,
            bottom: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Thumbs Up (Like)
                _buildActionItem(
                  icon: widget.short.isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                  color: widget.short.isLiked ? const Color(0xFF00E5FF) : Colors.white,
                  label: _formatCount(widget.short.likesCount),
                  onTap: () {
                    widget.onLikeToggle();
                    if (_isDisliked) {
                      setState(() => _isDisliked = false);
                    }
                  },
                ),

                // 2. Thumbs Down (Dislike)
                _buildActionItem(
                  icon: _isDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_alt_outlined,
                  color: _isDisliked ? const Color(0xFF00E5FF) : Colors.white,
                  label: 'Dislike',
                  onTap: () {
                    setState(() {
                      _isDisliked = !_isDisliked;
                      if (_isDisliked && widget.short.isLiked) {
                        widget.onLikeToggle();
                      }
                    });
                  },
                ),

                // 3. Comments
                _buildActionItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  label: _formatCount(_commentsCount),
                  onTap: () => _showCommentsModal(context),
                ),

                // 4. Share
                _buildActionItem(
                  icon: Icons.share_rounded,
                  color: Colors.white,
                  label: 'Share',
                  onTap: () => _showShareModal(context),
                ),

                // 5. Download
                _buildActionItem(
                  icon: _isDownloading ? Icons.hourglass_top_rounded : Icons.download_rounded,
                  color: _isDownloading ? AppColors.accentCyan : Colors.white,
                  label: _isDownloading ? '${(_downloadProgress * 100).toInt()}%' : 'Download',
                  onTap: () => _handleDownload(context),
                ),

                // 6. More Options (...)
                _buildActionItem(
                  icon: Icons.more_horiz_rounded,
                  color: Colors.white,
                  label: '',
                  onTap: () => _showMoreOptionsModal(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Floating Action Item matching YouTube Shorts design (Pure white icon with drop shadow, no circular background)
  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
