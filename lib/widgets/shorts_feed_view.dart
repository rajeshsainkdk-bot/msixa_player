import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../models/short_video_item.dart';
import '../services/language_service.dart';
import '../services/shorts_service.dart';
import '../theme/app_colors.dart';

class ShortsFeedView extends StatefulWidget {
  final VoidCallback? onBackToDeviceVideos;
  const ShortsFeedView({Key? key, this.onBackToDeviceVideos}) : super(key: key);

  @override
  State<ShortsFeedView> createState() => _ShortsFeedViewState();
}

class _ShortsFeedViewState extends State<ShortsFeedView> {
  final ShortsService _shortsService = ShortsService();
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  List<ShortVideoItem> _shorts = [];
  bool _isLoading = true;
  String _activeCategory = 'Trending';
  bool _isSearching = false;
  int _currentIndex = 0;

  // Multi-Controller Preloading Pool for 0-Second Instant Playback
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _loadingIndices = {};

  final List<Map<String, String>> _categories = [
    {'id': 'Trending', 'hi': '🔥 ट्रेंडिंग', 'en': '🔥 Trending'},
    {'id': 'Marwadi', 'hi': '🐪 मारवाड़ी व राजस्थानी', 'en': '🐪 Rajasthani'},
    {'id': 'DJ Remix', 'hi': '🎧 डीजे रीमिक्स', 'en': '🎧 DJ Remix'},
    {'id': 'Haryanvi', 'hi': '🚜 हरियाणवी', 'en': '🚜 Haryanvi'},
    {'id': 'Bhakti', 'hi': '🕉️ भक्ति व महाकाल', 'en': '🕉️ Bhakti'},
    {'id': 'Romantic', 'hi': '❤️ रोमांटिक लव', 'en': '❤️ Romantic'},
  ];

  @override
  void initState() {
    super.initState();
    _loadShortsForCategory(_activeCategory);
  }

  @override
  void dispose() {
    _disposeAllControllers();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _disposeAllControllers() {
    for (final ctrl in _controllers.values) {
      try {
        ctrl.pause();
        ctrl.dispose();
      } catch (_) {}
    }
    _controllers.clear();
    _loadingIndices.clear();
  }

  Future<void> _loadShortsForCategory(String category) async {
    _disposeAllControllers();
    final initialList = _shortsService.getInitialShorts(category);
    setState(() {
      _shorts = initialList;
      _isLoading = initialList.isEmpty;
      _currentIndex = 0;
    });

    if (initialList.isNotEmpty) {
      _preloadAroundIndex(0);
    }

    try {
      final onlineList = await _shortsService.getShortsByCategory(category);
      if (mounted && onlineList.isNotEmpty) {
        setState(() {
          final existingIds = _shorts.map((e) => e.id).toSet();
          final newItems = onlineList.where((e) => !existingIds.contains(e.id)).toList();
          _shorts.addAll(newItems);
          _isLoading = false;
        });
        _preloadAroundIndex(_currentIndex);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);
    _disposeAllControllers();
    try {
      final results = await _shortsService.searchShorts(query.trim());
      if (mounted) {
        setState(() {
          _shorts = results.isNotEmpty ? results : _shortsService.getInitialShorts('Trending');
          _isLoading = false;
          _currentIndex = 0;
        });
        _preloadAroundIndex(0);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _shorts = _shortsService.getInitialShorts('Trending');
          _isLoading = false;
        });
        _preloadAroundIndex(0);
      }
    }
  }

  void _preloadAroundIndex(int center) {
    if (_shorts.isEmpty) return;
    // Pre-warm URLs in background
    final idsToPrewarm = <String>[];
    for (int i = center; i <= center + 3; i++) {
      if (i >= 0 && i < _shorts.length) {
        idsToPrewarm.add(_shorts[i].id);
      }
    }
    _shortsService.prewarmStreamUrls(idsToPrewarm);

    // Initialize VideoPlayerControllers for current, next 1, and next 2
    for (int i = center; i <= center + 2; i++) {
      if (i >= 0 && i < _shorts.length) {
        _initControllerForIndex(i);
      }
    }

    // Clean up distant controllers to avoid memory leaks
    final staleKeys = _controllers.keys.where((k) => k < center - 2 || k > center + 3).toList();
    for (final k in staleKeys) {
      try {
        _controllers[k]?.pause();
        _controllers[k]?.dispose();
      } catch (_) {}
      _controllers.remove(k);
    }
  }

  Future<void> _initControllerForIndex(int index) async {
    if (index < 0 || index >= _shorts.length) return;
    if (_controllers.containsKey(index) || _loadingIndices.contains(index)) return;

    _loadingIndices.add(index);
    try {
      final item = _shorts[index];
      String? streamUrl = item.streamUrl;
      if (streamUrl == null || streamUrl.isEmpty) {
        streamUrl = await _shortsService.resolveStreamUrl(item.id, item.category);
      }

      if (streamUrl != null && streamUrl.isNotEmpty && mounted) {
        final ctrl = VideoPlayerController.networkUrl(
          Uri.parse(streamUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
        await ctrl.initialize();
        ctrl.setLooping(false);

        if (mounted) {
          setState(() {
            _controllers[index] = ctrl;
            _loadingIndices.remove(index);
          });
          // If this index is currently visible, play immediately!
          if (index == _currentIndex) {
            ctrl.play();
          }
        } else {
          ctrl.dispose();
        }
      } else {
        _loadingIndices.remove(index);
      }
    } catch (_) {
      _loadingIndices.remove(index);
      // Fallback resilience: ensure video controller initializes with verified stream
      if (mounted && !_controllers.containsKey(index)) {
        try {
          final fallbackUrl = _shortsService.getFallbackStreamUrl(_shorts[index].category);
          final ctrl = VideoPlayerController.networkUrl(
            Uri.parse(fallbackUrl),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
          );
          await ctrl.initialize();
          ctrl.setLooping(false);
          if (mounted) {
            setState(() {
              _controllers[index] = ctrl;
            });
            if (index == _currentIndex) {
              ctrl.play();
            }
          } else {
            ctrl.dispose();
          }
        } catch (_) {}
      }
    }
  }

  void _onPageChanged(int newIndex) {
    final oldIndex = _currentIndex;
    _currentIndex = newIndex;

    // Pause old video
    if (_controllers.containsKey(oldIndex)) {
      _controllers[oldIndex]?.pause();
    }

    // Play new video immediately (already preloaded in 0ms!)
    if (_controllers.containsKey(newIndex)) {
      final ctrl = _controllers[newIndex]!;
      ctrl.seekTo(Duration.zero);
      ctrl.play();
    } else {
      // In case of rapid multi-swipe
      _initControllerForIndex(newIndex);
    }

    // Preload next videos ahead
    _preloadAroundIndex(newIndex);
    setState(() {});
  }

  void _onVideoCompleted(int index) {
    if (!mounted) return;
    // Auto-scroll hands-free to next video upon completion
    if (index < _shorts.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      // Loop back to the first video smoothly
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fullscreen Vertical Swipeable PageView Feed
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
                    onPressed: () => _loadShortsForCategory('Trending'),
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
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _shorts.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final isCurrent = index == _currentIndex;
                final controller = _controllers[index];

                return _ShortVideoPlayerCard(
                  key: ValueKey(_shorts[index].id),
                  short: _shorts[index],
                  isActive: isCurrent,
                  controller: controller,
                  onVideoCompleted: () => _onVideoCompleted(index),
                  onLikeToggle: () {
                    setState(() {
                      final item = _shorts[index];
                      item.isLiked = !item.isLiked;
                      item.likesCount += item.isLiked ? 1 : -1;
                    });
                  },
                );
              },
            ),

          // 2. Top Header Overlay (Category Chips & Search)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
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
                              color: Colors.black.withOpacity(0.5),
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
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(18),
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
                                        _loadShortsForCategory(_activeCategory);
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
                                  children: _categories.map((cat) {
                                    final isSelected = _activeCategory == cat['id'];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => _activeCategory = cat['id']!);
                                          _loadShortsForCategory(cat['id']!);
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
                                            lang.isHindi ? cat['hi']! : cat['en']!,
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
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _ShortVideoPlayerCard extends StatefulWidget {
  final ShortVideoItem short;
  final bool isActive;
  final VideoPlayerController? controller;
  final VoidCallback onLikeToggle;
  final VoidCallback onVideoCompleted;

  const _ShortVideoPlayerCard({
    Key? key,
    required this.short,
    required this.isActive,
    this.controller,
    required this.onLikeToggle,
    required this.onVideoCompleted,
  }) : super(key: key);

  @override
  State<_ShortVideoPlayerCard> createState() => _ShortVideoPlayerCardState();
}

class _ShortVideoPlayerCardState extends State<_ShortVideoPlayerCard> {
  final ShortsService _shortsService = ShortsService();
  bool _isPlaying = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isWhatsAppStatusPending = false;
  bool _hasTriggeredCompletion = false;

  @override
  void initState() {
    super.initState();
    _attachListener();
    if (widget.isActive && widget.controller != null && widget.controller!.value.isInitialized) {
      widget.controller!.play();
      _isPlaying = true;
    }
  }

  @override
  void didUpdateWidget(covariant _ShortVideoPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdate);
      _attachListener();
    }

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _hasTriggeredCompletion = false;
        if (widget.controller != null && widget.controller!.value.isInitialized) {
          widget.controller!.seekTo(Duration.zero);
          widget.controller!.play();
          setState(() => _isPlaying = true);
        }
      } else {
        widget.controller?.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  void _attachListener() {
    widget.controller?.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted || widget.controller == null || !widget.isActive) return;
    final val = widget.controller!.value;
    if (val.isInitialized && val.duration > Duration.zero) {
      if (val.position >= val.duration) {
        if (!_hasTriggeredCompletion) {
          _hasTriggeredCompletion = true;
          widget.onVideoCompleted();
        }
      }
    }
  }

  void _togglePlayPause() {
    final ctrl = widget.controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
        _isPlaying = false; // Buttons & overlay become visible on pause!
      } else {
        ctrl.play();
        _isPlaying = true; // Buttons & overlay hide when video plays!
      }
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
                ? (lang.isHindi ? 'वीडियो डाउनलोड हो गया! (गैलरी में सेव्ड)' : 'Video downloaded to storage!')
                : (lang.isHindi ? 'डाउनलोड विफल रहा' : 'Download failed'),
          ),
          backgroundColor: path != null ? const Color(0xFF00E5FF) : Colors.redAccent,
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final isReady = ctrl != null && ctrl.value.isInitialized && !ctrl.value.hasError;
    // Side buttons only appear when the video is paused by the user!
    // When playing: pure, clean full-screen video with zero distractions.
    final showControls = !_isPlaying && isReady;

    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Pure Edge-to-Edge Fullscreen Video Player (FittedBox.cover)
          if (isReady)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: ctrl.value.size.width > 0 ? ctrl.value.size.width : 1080,
                  height: ctrl.value.size.height > 0 ? ctrl.value.size.height : 1920,
                  child: VideoPlayer(ctrl),
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
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF131A2A)),
                  )
                else
                  Container(color: const Color(0xFF131A2A)),
                const Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                ),
              ],
            ),

          // 2. Center Animated Play/Pause Indicator (Shown when Paused)
          if (showControls)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: const Icon(Icons.pause_rounded, color: Colors.white, size: 54),
              ),
            ),

          // 3. Subtle bottom video progress indicator
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

          // 4. Bottom Text Gradient Vignette (Fade-in on Pause)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 240,
            child: AnimatedOpacity(
              opacity: showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !showControls,
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
          ),

          // 5. Left Bottom Video Title & Creator Handle (Fade-in on Pause)
          Positioned(
            left: 16,
            bottom: 30,
            right: 86,
            child: AnimatedOpacity(
              opacity: showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !showControls,
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
            ),
          ),

          // 6. Right Floating Actions Column (Fade-in on Pause ONLY)
          Positioned(
            right: 12,
            bottom: 30,
            child: AnimatedOpacity(
              opacity: showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !showControls,
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

                    // 2. Download Button
                    _buildActionItem(
                      icon: _isDownloading
                          ? Icons.downloading_rounded
                          : (widget.short.isDownloaded ? Icons.check_circle_rounded : Icons.download_rounded),
                      color: widget.short.isDownloaded ? AppColors.accentCyan : Colors.white,
                      label: _isDownloading
                          ? '${(_downloadProgress * 100).toInt()}%'
                          : (widget.short.isDownloaded ? 'सेव्ड' : 'डाउनलोड'),
                      onTap: () => _handleDownload(context),
                    ),
                    const SizedBox(height: 16),

                    // 3. WhatsApp Status Direct Button
                    _buildActionItem(
                      icon: Icons.chat_bubble_rounded,
                      color: const Color(0xFF25D366), // WhatsApp brand green
                      label: 'स्टेटस',
                      onTap: () => _handleWhatsAppStatus(context),
                      badge: 'WA',
                    ),
                    const SizedBox(height: 16),

                    // 4. Share Button
                    _buildActionItem(
                      icon: Icons.share_rounded,
                      color: Colors.white,
                      label: 'शेयर',
                      onTap: _handleGeneralShare,
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

  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              if (badge != null)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
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
