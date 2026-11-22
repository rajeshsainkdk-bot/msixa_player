import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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

/// Pure In-App YouTube Shorts Feed View (100% In-App Playback, Zero External Redirection,
/// No Ads, No Watermarks, Strictly Vertical 9:16 Shorts with Auto-Scroll & Creator Subscriptions).
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
      // Reached list end: load next batch and advance to fresh video
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

          // 2. Top Header Overlay (Indian Categories & Search)
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

class _NativeShortVideoCardState extends State<_NativeShortVideoCard> with SingleTickerProviderStateMixin {
  final ShortsService _shortsService = ShortsService();
  final YouTubeSubscriptionService _subService = YouTubeSubscriptionService();

  bool _isPlaying = true;
  bool _showTransientPlayIcon = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isWhatsAppStatusPending = false;

  late final AnimationController _discAnimController;

  @override
  void initState() {
    super.initState();
    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

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
        if (!_discAnimController.isAnimating) _discAnimController.repeat();
      } else {
        widget.instance.pauseVideo();
        setState(() => _isPlaying = false);
        _discAnimController.stop();
      }
    }
  }

  @override
  void dispose() {
    _discAnimController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      final ctrl = widget.instance.videoPlayerController;
      if (ctrl != null && ctrl.value.isInitialized) {
        if (ctrl.value.isPlaying) {
          ctrl.pause();
          _isPlaying = false;
          _discAnimController.stop();
        } else {
          ctrl.play();
          _isPlaying = true;
          _discAnimController.repeat();
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
    if (_isWhatsAppStatusPending) return;
    final lang = LanguageService();

    setState(() {
      _isWhatsAppStatusPending = true;
      _downloadProgress = 0.0;
    });

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

    if (mounted) {
      setState(() => _isWhatsAppStatusPending = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isHindi ? 'व्हाट्सएप नहीं मिला या स्टेटस नहीं लग सका' : 'Could not launch WhatsApp status'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
          'Check out "${widget.short.title}" on Msixa Player!',
          subject: widget.short.title,
        );
      }
    }
  }

  void _showCommentsModal(BuildContext context) {
    final lang = LanguageService();
    final commentController = TextEditingController();
    final commentsList = [
      {'user': 'राजेश सैन', 'text': 'शानदार डांस! दिल खुश हो गया ❤️', 'time': 'अभी'},
      {'user': 'सुनील शर्मा', 'text': 'सुपरहिट देसी बीट्स 🔥🔥', 'time': '10 मिनट पहले'},
      {'user': 'कविता राठौड़', 'text': 'फुल बास साउंड, मजा आ गया!', 'time': '1 घंटा पहले'},
      {'user': 'अनिल कुमार', 'text': 'मारवाड़ी संस्कृति की जान 👌', 'time': '2 घंटे पहले'},
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

    // If user has not linked Gmail yet, prompt Gmail login confirmation
    if (!_subService.hasGoogleAccount) {
      final emailController = TextEditingController(text: 'rajesh.sain.kdk@gmail.com');
      showDialog(
        context: context,
        builder: (dialogCtx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF131A2A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.isHindi ? 'Google / Gmail से सब्सक्राइब करें' : 'Subscribe via Google',
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
                      ? 'क्रिएटर "$author" को सब्सक्राइब करने के लिए अपने Google / Gmail अकाउंट से कनेक्ट करें:'
                      : 'Connect your Google / Gmail account to subscribe to "$author":',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Gmail Address',
                    labelStyle: const TextStyle(color: AppColors.accentCyan),
                    filled: true,
                    fillColor: const Color(0xFF1E283C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.accentCyan, size: 20),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(lang.isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  final email = emailController.text.trim();
                  if (email.isNotEmpty) {
                    _subService.toggleSubscribe(author, defaultEmail: email);
                    Navigator.pop(dialogCtx);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(lang.isHindi ? '🎉 $author को सफलतापूर्वक सब्सक्राइब कर लिया गया!' : 'Subscribed to $author!'),
                        backgroundColor: const Color(0xFF00E5FF),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF007A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(lang.isHindi ? 'सब्सक्राइब करें' : 'Subscribe Now'),
              ),
            ],
          );
        },
      );
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

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.instance.videoPlayerController;
    final isReady = ctrl != null && ctrl.value.isInitialized;
    final isSubscribed = _subService.isSubscribed(widget.short.author);
    final lang = LanguageService();

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

          // 4. Bottom Gradient Vignette
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

          // 5. Left Bottom Creator Details, Subscribe Button & Title
          Positioned(
            left: 16,
            bottom: 24,
            right: 86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Creator Handle & Subscribe Button Row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFFF007A),
                      child: Text(
                        widget.short.author.isNotEmpty ? widget.short.author[0].toUpperCase() : 'M',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '@${widget.short.author}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Subscribe Button (Red when unsubscribed, frosted grey when subscribed)
                    GestureDetector(
                      onTap: _handleSubscribeToggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: isSubscribed
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFFFF007A), Color(0xFFFF0000)],
                                ),
                          color: isSubscribed ? Colors.white.withOpacity(0.25) : null,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSubscribed ? Colors.white38 : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSubscribed ? Icons.check_rounded : Icons.add_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isSubscribed
                                  ? (lang.isHindi ? 'सब्सक्राइब किया' : 'Subscribed')
                                  : (lang.isHindi ? 'सब्सक्राइब' : 'Subscribe'),
                              style: const TextStyle(
                                color: Colors.white,
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
                const SizedBox(height: 8),

                // Video Title
                Text(
                  widget.short.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                const SizedBox(height: 6),

                // Category Tag & Audio Track
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.accentCyan.withOpacity(0.4)),
                      ),
                      child: Text(
                        widget.short.category,
                        style: const TextStyle(color: AppColors.accentCyan, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.music_note_rounded, color: Colors.white70, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${widget.short.author} • Original Audio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 6. Right Floating Actions Column (Like, Comment, WhatsApp Status, Download, Sound, Disc)
          Positioned(
            right: 12,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Like Button
                _buildActionItem(
                  icon: widget.short.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: widget.short.isLiked ? const Color(0xFFFF007A) : Colors.white,
                  label: '${widget.short.likesCount}',
                  onTap: widget.onLikeToggle,
                ),
                const SizedBox(height: 14),

                // 2. Comments Button (In-App Bottom Sheet)
                _buildActionItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  label: 'टिप्पणी',
                  onTap: () => _showCommentsModal(context),
                ),
                const SizedBox(height: 14),

                // 3. Direct WhatsApp Status Button
                _buildActionItem(
                  icon: Icons.share_rounded,
                  color: const Color(0xFF25D366),
                  label: 'स्टेटस',
                  onTap: () => _handleWhatsAppStatus(context),
                ),
                const SizedBox(height: 14),

                // 4. Download Video Button (Direct to Phone Storage)
                _buildActionItem(
                  icon: _isDownloading ? Icons.hourglass_top_rounded : Icons.download_rounded,
                  color: _isDownloading ? AppColors.accentCyan : Colors.white,
                  label: _isDownloading ? '${(_downloadProgress * 100).toInt()}%' : 'डाउनलोड',
                  onTap: () => _handleDownload(context),
                ),
                const SizedBox(height: 14),

                // 5. Audio Mute Toggle
                _buildActionItem(
                  icon: widget.playbackController.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: widget.playbackController.isMuted ? Colors.redAccent : Colors.white,
                  label: widget.playbackController.isMuted ? 'म्यूट' : 'आवाज़',
                  onTap: () {
                    widget.playbackController.toggleMute();
                    setState(() {});
                  },
                ),
                const SizedBox(height: 14),

                // 6. Spinning Vinyl Music Disc
                RotationTransition(
                  turns: _discAnimController,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFF1E283C), Color(0xFF0B0F19), Color(0xFF000000)],
                      ),
                      border: Border.all(color: Colors.white30, width: 2),
                    ),
                    child: const Center(
                      child: Icon(Icons.music_note_rounded, color: AppColors.accentCyan, size: 16),
                    ),
                  ),
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
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 3),
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
