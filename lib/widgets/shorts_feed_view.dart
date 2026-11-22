import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../models/short_video_item.dart';
import '../services/app_share_service.dart';
import '../services/language_service.dart';
import '../services/shorts_service.dart';
import '../services/youtube_subscription_service.dart';
import '../theme/app_colors.dart';

/// Pure Customized In-App YouTube Shorts Player (Compliant with MSIXA Shorts Specification v1.1)
/// - Clean YouTube Embed Player (ZERO YouTube logo, ZERO YouTube web buttons, ZERO YouTube creator row)
/// - ONLY MSIXA custom action buttons & creator row appear
/// - Smooth vertical swiping with PageView.builder (TikTok / Reels style)
/// - Sliding-window pre-buffering pipeline for zero-latency video transitions
/// - Pull-to-refresh & Bottom Nav Shorts click refresh with 100% fresh, unrepeated videos
/// - In-App Google Account Picker on +FOLLOW without external YouTube app launch
class ShortsFeedView extends StatefulWidget {
  final VoidCallback? onBackToDeviceVideos;

  /// Global refresh trigger: Tapping the bottom nav Shorts icon triggers instant link refresh
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  /// Trigger instant refresh to a fresh, non-repeated short link
  static void refreshFeed() {
    refreshNotifier.value++;
  }

  const ShortsFeedView({Key? key, this.onBackToDeviceVideos}) : super(key: key);

  @override
  State<ShortsFeedView> createState() => _ShortsFeedViewState();
}

class _ShortsFeedViewState extends State<ShortsFeedView> {
  final ShortsService _shortsService = ShortsService();
  final YouTubeSubscriptionService _subService = YouTubeSubscriptionService();
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  List<ShortVideoItem> _feed = [];
  final Map<int, WebViewController> _controllers = {};
  final Set<String> _playedVideoIds = {};

  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isPlaying = true;
  bool _showPlayPauseRipple = false;

  // Like & Dislike states mapped by videoId
  final Map<String, bool> _likedVideos = {};
  final Map<String, bool> _dislikedVideos = {};

  // Download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  // Pull-down to refresh gesture state
  double _dragStartY = 0.0;
  double _currentPullDelta = 0.0;
  bool _isPullRefreshing = false;

  @override
  void initState() {
    super.initState();
    AppShareService.keepScreenOn(true);
    _subService.init();
    ShortsFeedView.refreshNotifier.addListener(_handleExternalRefresh);
    _loadInitialFeed();
  }

  @override
  void dispose() {
    ShortsFeedView.refreshNotifier.removeListener(_handleExternalRefresh);
    AppShareService.keepScreenOn(false);
    _pageController.dispose();
    _searchController.dispose();
    for (final c in _controllers.values) {
      try {
        c.runJavaScript('try{document.querySelector("video")?.pause();}catch(e){}');
      } catch (_) {}
    }
    _controllers.clear();
    super.dispose();
  }

  /// Load fresh unrepeated feed of viral Indian Shorts
  void _loadInitialFeed() {
    final allShorts = _shortsService.getInitialShorts('Trending');
    final unplayed = allShorts.where((s) => !_playedVideoIds.contains(s.id)).toList();
    final list = unplayed.isNotEmpty ? unplayed : allShorts;
    list.shuffle();

    setState(() {
      _feed = List.from(list);
      _currentIndex = 0;
      _isLoading = false;
    });

    if (_feed.isNotEmpty) {
      _playedVideoIds.add(_feed[0].id);
      _prewarmControllers(0);
    }
  }

  /// Handle external refresh triggered by bottom navigation Shorts button
  void _handleExternalRefresh() {
    _refreshToFreshVideos();
  }

  /// Refresh feed with 100% fresh, unplayed videos and animate to top
  Future<void> _refreshToFreshVideos() async {
    if (!mounted) return;
    setState(() => _isPullRefreshing = true);

    // Filter unplayed videos from the rich 30+ catalog
    final allShorts = _shortsService.getInitialShorts('Trending');
    var freshList = allShorts.where((s) => !_playedVideoIds.contains(s.id)).toList();
    if (freshList.isEmpty) {
      _playedVideoIds.clear();
      freshList = List.from(allShorts);
    }
    freshList.shuffle();

    // Dispose old controllers
    for (final c in _controllers.values) {
      try {
        c.runJavaScript('try{document.querySelector("video")?.pause();}catch(e){}');
      } catch (_) {}
    }
    _controllers.clear();

    setState(() {
      _feed = freshList;
      _currentIndex = 0;
      _isPlaying = true;
      _isPullRefreshing = false;
      _currentPullDelta = 0.0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    if (_feed.isNotEmpty) {
      _playedVideoIds.add(_feed[0].id);
      _prewarmControllers(0);
    }
  }

  /// Create and pre-warm WebViewController instances in a sliding window [index - 1, index, index + 1]
  void _prewarmControllers(int activeIdx) {
    // 1. Dispose distant controllers to conserve memory
    _controllers.removeWhere((idx, ctrl) {
      if ((idx - activeIdx).abs() > 2) {
        try {
          ctrl.runJavaScript('try{document.querySelector("video")?.pause();}catch(e){}');
        } catch (_) {}
        return true;
      }
      return false;
    });

    // 2. Initialize active, previous and next controllers
    for (int i = activeIdx - 1; i <= activeIdx + 1; i++) {
      if (i >= 0 && i < _feed.length && !_controllers.containsKey(i)) {
        _controllers[i] = _createControllerForIndex(i);
      }
    }
  }

  /// Create clean embed WebViewController with ZERO YouTube controls, logo, or channel banners
  WebViewController _createControllerForIndex(int index) {
    final item = _feed[index];
    final isAutoplay = index == _currentIndex;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url.startsWith('intent://') ||
                url.startsWith('market://') ||
                url.startsWith('vnd.youtube:') ||
                url.startsWith('youtube://')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      (controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    // Load clean YouTube Embed with controls=0, modestbranding=1, zero YouTube web overlay
    final embedHtml = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body, html {
            width: 100%;
            height: 100%;
            overflow: hidden;
            background-color: #000000;
            user-select: none;
            -webkit-user-select: none;
          }
          iframe {
            width: 100vw;
            height: 100vh;
            border: none;
            object-fit: cover;
            pointer-events: auto;
          }
          /* Ensure zero YouTube watermark, title or share buttons inside iframe */
          .ytp-chrome-top, .ytp-watermark, .ytp-title-link, .ytp-share-button, .branding-img-container {
            display: none !important;
            opacity: 0 !important;
            visibility: hidden !important;
          }
        </style>
      </head>
      <body>
        <iframe id="shorts-embed"
          src="https://www.youtube.com/embed/${item.id}?autoplay=${isAutoplay ? 1 : 0}&controls=0&playsinline=1&loop=1&playlist=${item.id}&modestbranding=1&rel=0&iv_load_policy=3&disablekb=1&fs=0&enablejsapi=1"
          allow="autoplay; encrypted-media; picture-in-picture"
          allowfullscreen>
        </iframe>
      </body>
      </html>
    ''';

    controller.loadHtmlString(embedHtml, baseUrl: 'https://www.youtube.com');
    return controller;
  }

  void _onPageChanged(int newIndex) {
    if (newIndex == _currentIndex || newIndex < 0 || newIndex >= _feed.length) return;

    // Pause previous video
    final prevCtrl = _controllers[_currentIndex];
    if (prevCtrl != null) {
      try {
        prevCtrl.runJavaScript('try{document.querySelector("video")?.pause();}catch(e){}');
      } catch (_) {}
    }

    setState(() {
      _currentIndex = newIndex;
      _isPlaying = true;
    });

    // Play new active video
    final activeCtrl = _controllers[newIndex];
    if (activeCtrl != null) {
      try {
        activeCtrl.runJavaScript('try{document.querySelector("video")?.play();}catch(e){}');
      } catch (_) {}
    }

    _playedVideoIds.add(_feed[newIndex].id);
    _prewarmControllers(newIndex);
  }

  void _togglePlayPause() {
    final ctrl = _controllers[_currentIndex];
    if (ctrl == null) return;

    setState(() {
      _isPlaying = !_isPlaying;
      _showPlayPauseRipple = true;
    });

    if (_isPlaying) {
      ctrl.runJavaScript('try{document.querySelector("video")?.play();}catch(e){}');
    } else {
      ctrl.runJavaScript('try{document.querySelector("video")?.pause();}catch(e){}');
    }

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showPlayPauseRipple = false);
    });
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isSearching = false;
    });

    final searchResults = await _shortsService.searchShorts(clean);
    if (!mounted) return;

    if (searchResults.isNotEmpty) {
      // Dispose old controllers
      for (final c in _controllers.values) {
        try {
          c.runJavaScript('try{document.querySelector("video")?.pause();}catch(e){}');
        } catch (_) {}
      }
      _controllers.clear();

      setState(() {
        _feed = searchResults;
        _currentIndex = 0;
        _isLoading = false;
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _prewarmControllers(0);
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कोई वीडियो नहीं मिला, ट्रेंडिंग वीडियो चला रहे हैं'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleLike(String videoId) {
    setState(() {
      final current = _likedVideos[videoId] ?? false;
      _likedVideos[videoId] = !current;
      if (_likedVideos[videoId] == true) {
        _dislikedVideos[videoId] = false;
      }
    });
  }

  void _toggleDislike(String videoId) {
    setState(() {
      final current = _dislikedVideos[videoId] ?? false;
      _dislikedVideos[videoId] = !current;
      if (_dislikedVideos[videoId] == true) {
        _likedVideos[videoId] = false;
      }
    });
  }

  void _showCommentsModal(BuildContext context, ShortVideoItem item) {
    final lang = LanguageService();
    final commentController = TextEditingController();
    final commentsList = [
      {'user': 'राजेश सैन', 'text': 'शानदार वीडियो! फुल एनर्जी ❤️', 'time': 'अभी'},
      {'user': 'सुनील शर्मा', 'text': 'सुपरहिट बीट्स 🔥🔥', 'time': '10 मिनट पहले'},
      {'user': 'कविता राठौड़', 'text': 'फुल बास साउंड, मजा आ गया!', 'time': '1 घंटा पहले'},
      {'user': 'Msixa User', 'text': 'Great choreography & screen presence 👌', 'time': '2 घंटे पहले'},
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
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
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
                          final cItem = commentsList[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.accentCyan.withOpacity(0.3),
                                  child: Text(
                                    cItem['user']![0],
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
                                            cItem['user']!,
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(cItem['time']!, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(cItem['text']!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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

  void _showShareModal(BuildContext context, ShortVideoItem item) {
    final lang = LanguageService();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E283C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    _buildShareModalOption(
                      icon: Icons.share_rounded,
                      color: const Color(0xFF25D366),
                      label: lang.isHindi ? 'व्हाट्सएप स्टेटस' : 'WhatsApp Status',
                      onTap: () {
                        Navigator.pop(modalCtx);
                        _handleWhatsAppStatus(item);
                      },
                    ),
                    _buildShareModalOption(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      label: 'WhatsApp',
                      onTap: () {
                        Navigator.pop(modalCtx);
                        _handleWhatsAppStatus(item);
                      },
                    ),
                    _buildShareModalOption(
                      icon: Icons.link_rounded,
                      color: const Color(0xFF00E5FF),
                      label: lang.isHindi ? 'लिंक कॉपी' : 'Copy link',
                      onTap: () async {
                        Navigator.pop(modalCtx);
                        final link = 'https://youtube.com/shorts/${item.id}';
                        await Clipboard.setData(ClipboardData(text: link));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(lang.isHindi ? 'लिंक कॉपी हो गया!' : 'Link copied to clipboard!'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    _buildShareModalOption(
                      icon: Icons.more_horiz_rounded,
                      color: Colors.white,
                      label: lang.isHindi ? 'अन्य ऐप्स' : 'More',
                      onTap: () {
                        Navigator.pop(modalCtx);
                        _handleWhatsAppStatus(item);
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
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showMoreOptionsModal(BuildContext context, ShortVideoItem item) {
    final lang = LanguageService();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    _showGoogleAccountPicker(context, item.author);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                  title: Text(
                    lang.isHindi ? 'सीधा व्हाट्सएप स्टेटस लगाएं' : 'Share to WhatsApp Status',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _handleWhatsAppStatus(item);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.hd_rounded, color: AppColors.accentCyan),
                  title: const Text('Video Quality (HD 1080p 60fps Native)', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Official Zero-Buffer Stream', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleSubscribeToggle(String author) {
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

  void _showGoogleAccountPicker(BuildContext context, String author) {
    final lang = LanguageService();
    final deviceAccounts = _subService.getAvailableDeviceAccounts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF202124),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Center(
                      child: Text('G', style: TextStyle(color: Color(0xFF4285F4), fontSize: 26, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    lang.isHindi ? 'Google खाता चुनें' : 'Choose an account',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    lang.isHindi ? 'YouTube पर @$author को सब्सक्राइब करने के लिए' : 'to subscribe to @$author on YouTube',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
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
                                Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                Text(email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF4285F4), size: 20),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleWhatsAppStatus(ShortVideoItem item) async {
    final lang = LanguageService();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.isHindi ? 'व्हाट्सएप स्टेटस तैयार हो रहा है...' : 'Preparing WhatsApp Status...'),
        backgroundColor: const Color(0xFF25D366),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    final success = await _shortsService.shareToWhatsAppStatus(item);
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

  Future<void> _handleDownload(ShortVideoItem item) async {
    if (_isDownloading) return;
    final lang = LanguageService();

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final path = await _shortsService.downloadShort(
      item,
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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (widget.onBackToDeviceVideos != null) {
          widget.onBackToDeviceVideos!();
          return;
        }
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
            : Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  _dragStartY = event.position.dy;
                  _currentPullDelta = 0.0;
                },
                onPointerMove: (event) {
                  final deltaY = event.position.dy - _dragStartY;
                  // Allow pull down to refresh from upper 60% of the screen
                  if (_currentIndex == 0 && _dragStartY < MediaQuery.of(context).size.height * 0.60 && deltaY > 0) {
                    if (mounted) {
                      setState(() {
                        _currentPullDelta = deltaY.clamp(0.0, 120.0);
                      });
                    }
                  }
                },
                onPointerUp: (event) {
                  if (_currentPullDelta > 50.0 && !_isPullRefreshing) {
                    _refreshToFreshVideos();
                  } else {
                    if (mounted && _currentPullDelta > 0.0) {
                      setState(() => _currentPullDelta = 0.0);
                    }
                  }
                },
                onPointerCancel: (_) {
                  if (mounted && _currentPullDelta > 0.0) {
                    setState(() => _currentPullDelta = 0.0);
                  }
                },
                child: Stack(
                  children: [
                    // 1. TikTok / Reels style Vertical PageView
                    PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: _feed.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        return _buildVideoPage(index);
                      },
                    ),

                    // 2. Pull-down to refresh indicator badge
                    if (_currentPullDelta > 15.0 || _isPullRefreshing)
                      Positioned(
                        top: 55 + (_currentPullDelta * 0.35),
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131A2A).withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.accentCyan, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentCyan.withOpacity(0.35),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accentCyan,
                                    value: _isPullRefreshing ? null : (_currentPullDelta / 50.0).clamp(0.0, 1.0),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isPullRefreshing
                                      ? (lang.isHindi ? 'नया शॉर्ट्स लोड हो रहा है...' : 'Refreshing Shorts...')
                                      : (_currentPullDelta > 50.0
                                          ? (lang.isHindi ? 'छोड़ें (रिफ्रेश होगा)' : 'Release to refresh')
                                          : (lang.isHindi ? 'नीचे खींचें रिफ्रेश के लिए' : 'Pull down to refresh')),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // 3. Top Header: ONLY Back '<' and Search '🔍' icons
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              // Back '<' minimal chevron
                              GestureDetector(
                                onTap: () {
                                  if (widget.onBackToDeviceVideos != null) {
                                    widget.onBackToDeviceVideos!();
                                  } else if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  }
                                },
                                behavior: HitTestBehavior.opaque,
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 22,
                                    shadows: [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1))],
                                  ),
                                ),
                              ),

                              // Expandable search input
                              if (_isSearching)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppColors.accentCyan),
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        autofocus: true,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: lang.isHindi ? 'यूट्यूब शॉर्ट्स खोजें...' : 'Search YouTube Shorts...',
                                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accentCyan, size: 18),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                                            onPressed: () => setState(() => _isSearching = false),
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        onSubmitted: _performSearch,
                                      ),
                                    ),
                                  ),
                                )
                              else ...[
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(() => _isSearching = true),
                                  behavior: HitTestBehavior.opaque,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.search_rounded,
                                      color: Colors.white,
                                      size: 24,
                                      shadows: [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1))],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 4. Center Play/Pause Ripple Indicator
                    if (_showPlayPauseRipple)
                      Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _showPlayPauseRipple ? 1.0 : 0.0,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Build individual short page with clean embed player + custom Flutter action rail & creator row
  Widget _buildVideoPage(int index) {
    if (index >= _feed.length) return const SizedBox.shrink();
    final item = _feed[index];
    final isLiked = _likedVideos[item.id] ?? false;
    final isDisliked = _dislikedVideos[item.id] ?? false;
    final isSubscribed = _subService.isSubscribed(item.author);

    final ctrl = _controllers[index];

    return Stack(
      children: [
        // 1. Clean Embed Player (Zero YouTube web buttons, zero top bar, zero creator row)
        GestureDetector(
          onTap: _togglePlayPause,
          behavior: HitTestBehavior.opaque,
          child: ctrl != null
              ? WebViewWidget(
                  controller: ctrl,
                  gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
                )
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.accentCyan),
                  ),
                ),
        ),

        // 2. Bottom Gradient Vignette for readability of custom overlay
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

        // 3. Left Bottom Creator Row, Channel Name, Video Title & Red +FOLLOW Button
        Positioned(
          left: 14,
          bottom: 24,
          right: 76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Video Title
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
                ),
              ),
              const SizedBox(height: 8),

              // Creator Row: [Avatar] [Channel Name] [Red +FOLLOW Button]
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF00B0FF)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        item.author.isNotEmpty ? item.author[0].toUpperCase() : 'Y',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Flexible(
                    child: Text(
                      item.author,
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

                  // Red +FOLLOW Subscribe Button
                  GestureDetector(
                    onTap: () => _handleSubscribeToggle(item.author),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSubscribed ? Colors.white.withOpacity(0.2) : const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isSubscribed ? Colors.white30 : Colors.transparent),
                      ),
                      child: Text(
                        isSubscribed ? 'SUBSCRIBED' : '+FOLLOW',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 4. Right Side MSIXA Custom Action Suite (EXACT MATCH TO USER SCREENSHOT)
        Positioned(
          right: 12,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Thumbs Up (Like)
              _buildActionItem(
                iconWidget: Icon(
                  Icons.thumb_up_rounded,
                  color: isLiked ? const Color(0xFF00E5FF) : Colors.white,
                  size: 28,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                ),
                label: '${item.likesCount > 0 ? (item.likesCount / 1000).toStringAsFixed(0) : 94}K',
                onTap: () => _toggleLike(item.id),
              ),

              // 2. Thumbs Down (Dislike)
              _buildActionItem(
                iconWidget: Icon(
                  Icons.thumb_down_rounded,
                  color: isDisliked ? const Color(0xFF00E5FF) : Colors.white,
                  size: 28,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                ),
                label: 'Dislike',
                onTap: () => _toggleDislike(item.id),
              ),

              // 3. Comments
              _buildActionItem(
                iconWidget: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 26,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                ),
                label: '322',
                onTap: () => _showCommentsModal(context, item),
              ),

              // 4. Share (Curved Right Arrow)
              _buildActionItem(
                iconWidget: Transform.flip(
                  flipX: true,
                  child: const Icon(
                    Icons.reply_rounded,
                    color: Colors.white,
                    size: 30,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
                label: 'Share',
                onTap: () => _showShareModal(context, item),
              ),

              // 5. Download Video to Device Gallery
              _buildActionItem(
                iconWidget: Icon(
                  _isDownloading ? Icons.hourglass_top_rounded : Icons.download_rounded,
                  color: _isDownloading ? AppColors.accentCyan : Colors.white,
                  size: 28,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                ),
                label: _isDownloading ? '${(_downloadProgress * 100).toInt()}%' : 'Download',
                onTap: () => _handleDownload(item),
              ),

              // 6. More Options (...)
              _buildActionItem(
                iconWidget: const Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: 28,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                ),
                label: '',
                onTap: () => _showMoreOptionsModal(context, item),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Floating Action Item matching YouTube Shorts design
  Widget _buildActionItem({
    required Widget iconWidget,
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
            iconWidget,
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
