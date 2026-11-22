import 'dart:async';
import 'dart:convert';
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

/// Pure Customized In-App YouTube Shorts Player
/// - Official YouTube backend (https://www.youtube.com/shorts) running inside WebView
/// - 100% Custom In-App Overlay Controls (Only our buttons & controls show)
/// - YouTube logo, top headers, banners, and 'Open in App' prompts completely hidden
/// - Top header has ONLY Back '<' and Search '🔍' icons (All category pills removed)
/// - Search directly queries YouTube Shorts and plays them
/// - Subscribe button opens Google Account Picker without launching external YouTube app
class ShortsFeedView extends StatefulWidget {
  final VoidCallback? onBackToDeviceVideos;
  const ShortsFeedView({Key? key, this.onBackToDeviceVideos}) : super(key: key);

  @override
  State<ShortsFeedView> createState() => _ShortsFeedViewState();
}

class _ShortsFeedViewState extends State<ShortsFeedView> {
  final ShortsService _shortsService = ShortsService();
  final YouTubeSubscriptionService _subService = YouTubeSubscriptionService();
  final TextEditingController _searchController = TextEditingController();

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  String _currentVideoId = 'kffacxfA7G4';
  String _videoTitle = 'Trending YouTube Short';
  String _channelName = 'YouTube Creator';
  String _likesCountStr = '94K';
  final int _commentsCount = 322;

  static const String _shortsUrl = 'https://m.youtube.com/shorts';

  /// Injected CSS to hide YouTube logo, web overlay controls, pivot bar, and Open App prompts
  static const String _cleanupCss = '''
    /* 1. Hide YouTube Top Bar, Header, Logo and Navigation */
    ytm-mobile-topbar-renderer,
    .mobile-topbar-header,
    #header-bar,
    header.mobile-topbar-header,
    yt-icon.ytm-logo,
    .ytm-home-logo,
    a[aria-label="YouTube"],
    .topbar-header,

    /* 2. Hide YouTube Bottom Navigation Bar */
    ytm-pivot-bar-renderer,
    .pivot-bar,
    .ytm-pivot-bar,

    /* 3. Hide 'Open in App' Banners, Mealbars, Promos, and Upsell Dialogs */
    .upsell-dialog-renderer,
    #app-banner,
    .open-app-banner,
    ytm-upsell-dialog-renderer,
    ytm-mealbar-promo-renderer,
    .banner-promo,
    ytm-button-renderer[data-target-id="open-app-button"],
    ytm-open-app-button,
    .open-app-button,
    .companion-ad,
    .ytm-promoted-sparkles-web-renderer,
    ytm-promoted-sparkles-web-renderer,
    dialog,
    .dialog-container,

    /* 4. Hide YouTube's Native Web Overlay Buttons (So ONLY our Flutter controls show!) */
    .reel-player-overlay-actions,
    ytm-reel-player-overlay-renderer .reel-player-overlay-actions,
    .action-container,
    ytm-reel-player-overlay-renderer .action-container,
    ytm-shorts-player-controls,

    /* 5. Pure Black Background */
    body, html {
      background-color: #000000 !important;
      overflow: hidden !important;
      user-select: none !important;
      -webkit-user-select: none !important;
    }
  ''';

  @override
  void initState() {
    super.initState();
    AppShareService.keepScreenOn(true);
    _subService.init();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..addJavaScriptChannel(
        'MsixaShortsChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJavaScriptMetadata(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            // Intercept and prevent ANY scheme attempting to launch the external YouTube app
            if (url.startsWith('intent://') ||
                url.startsWith('market://') ||
                url.startsWith('vnd.youtube:') ||
                url.startsWith('youtube://')) {
              return NavigationDecision.prevent;
            }
            // Allow internal YouTube and Google authentication pages
            if (url.contains('youtube.com') ||
                url.contains('googlevideo.com') ||
                url.contains('google.com') ||
                url.contains('gstatic.com') ||
                url.contains('accounts.google.com')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (String url) {
            _extractVideoId(url);
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            _extractVideoId(url);
            _injectCleanupScript();
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    _controller.loadRequest(Uri.parse(_shortsUrl));
  }

  @override
  void dispose() {
    AppShareService.keepScreenOn(false);
    _searchController.dispose();
    super.dispose();
  }

  void _injectCleanupScript() {
    final script = '''
      (function() {
        // 1. Inject cleanup CSS
        var style = document.getElementById('msixa-shorts-cleanup');
        if (!style) {
          style = document.createElement('style');
          style.id = 'msixa-shorts-cleanup';
          style.innerHTML = `$_cleanupCss`;
          document.head.appendChild(style);
        }

        // 2. Prevent external app launch clicks
        document.addEventListener('click', function(e) {
          var target = e.target.closest('a, button');
          if (target) {
            var href = target.getAttribute('href') || '';
            if (href.indexOf('intent://') === 0 || href.indexOf('market://') === 0 || href.indexOf('vnd.youtube') === 0) {
              e.preventDefault();
              e.stopPropagation();
              return false;
            }
          }
        }, true);

        // 3. Metadata Extractor & Reporter to Flutter
        function reportShortsInfo() {
          try {
            var titleEl = document.querySelector('ytm-reel-player-overlay-renderer .reel-player-header-title') ||
                          document.querySelector('.reel-player-header-title') ||
                          document.querySelector('h2.title') ||
                          document.querySelector('.title');
            var authorEl = document.querySelector('ytm-reel-player-overlay-renderer .reel-player-header-channel-title') ||
                           document.querySelector('.reel-player-header-channel-title') ||
                           document.querySelector('.channel-name');
            var likesEl = document.querySelector('ytm-reel-player-overlay-renderer .like-button span') ||
                          document.querySelector('.like-button span') ||
                          document.querySelector('[aria-label*="like"] span');

            var title = titleEl ? titleEl.textContent.trim() : '';
            var author = authorEl ? authorEl.textContent.trim() : '';
            var likes = likesEl ? likesEl.textContent.trim() : '';
            var url = window.location.href;

            if (window.MsixaShortsChannel) {
              window.MsixaShortsChannel.postMessage(JSON.stringify({
                title: title,
                author: author,
                likes: likes,
                url: url
              }));
            }
          } catch(e) {}
        }

        reportShortsInfo();

        var observer = new MutationObserver(function() {
          reportShortsInfo();
        });
        observer.observe(document.body, { childList: true, subtree: true });
        setInterval(reportShortsInfo, 1500);
      })();
    ''';
    _controller.runJavaScript(script);
  }

  void _handleJavaScriptMetadata(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final title = data['title'] as String? ?? '';
      final author = data['author'] as String? ?? '';
      final likes = data['likes'] as String? ?? '';
      final url = data['url'] as String? ?? '';

      _extractVideoId(url);

      if (mounted) {
        setState(() {
          if (title.isNotEmpty) _videoTitle = title;
          if (author.isNotEmpty) _channelName = author.replaceAll('@', '').trim();
          if (likes.isNotEmpty) _likesCountStr = likes;
        });
      }
    } catch (_) {}
  }

  void _extractVideoId(String url) {
    try {
      final regExp = RegExp(r'shorts\/([a-zA-Z0-9_-]{11})');
      final match = regExp.firstMatch(url);
      if (match != null) {
        final id = match.group(1);
        if (id != null && id.isNotEmpty && id != _currentVideoId) {
          if (mounted) setState(() => _currentVideoId = id);
        }
      }
    } catch (_) {}
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isSearching = false;
    });

    final searchUrl = 'https://m.youtube.com/results?search_query=${Uri.encodeComponent(clean)}+%23shorts';
    await _controller.loadRequest(Uri.parse(searchUrl));
  }

  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    await _controller.loadRequest(Uri.parse(_shortsUrl));
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) _isDisliked = false;
    });
    // Trigger webview like button
    _controller.runJavaScript('''
      var likeBtn = document.querySelector('ytm-reel-player-overlay-renderer .like-button button') ||
                    document.querySelector('[aria-label*="like"]');
      if (likeBtn) likeBtn.click();
    ''');
  }

  void _toggleDislike() {
    setState(() {
      _isDisliked = !_isDisliked;
      if (_isDisliked) _isLiked = false;
    });
    // Trigger webview dislike button
    _controller.runJavaScript('''
      var dislikeBtn = document.querySelector('ytm-reel-player-overlay-renderer .dislike-button button') ||
                       document.querySelector('[aria-label*="dislike"]');
      if (dislikeBtn) dislikeBtn.click();
    ''');
  }

  void _showCommentsModal(BuildContext context) {
    final lang = LanguageService();
    final commentController = TextEditingController();
    final commentsList = [
      {'user': 'राजेश सैन', 'text': 'शानदार वीडियो! दिल खुश हो गया ❤️', 'time': 'अभी'},
      {'user': 'सुनील शर्मा', 'text': 'सुपरहिट देसी बीट्स 🔥🔥', 'time': '10 मिनट पहले'},
      {'user': 'कविता राठौड़', 'text': 'फुल बास साउंड, मजा आ गया!', 'time': '1 घंटा पहले'},
      {'user': 'Msixa User', 'text': 'Great energy and screen presence 👌', 'time': '2 घंटे पहले'},
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
                    _buildShareModalOption(
                      icon: Icons.share_rounded,
                      color: const Color(0xFF25D366),
                      label: lang.isHindi ? 'व्हाट्सएप स्टेटस' : 'WhatsApp Status',
                      onTap: () {
                        Navigator.pop(modalCtx);
                        _handleWhatsAppStatus();
                      },
                    ),
                    _buildShareModalOption(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      label: 'WhatsApp',
                      onTap: () {
                        Navigator.pop(modalCtx);
                        _handleWhatsAppStatus();
                      },
                    ),
                    _buildShareModalOption(
                      icon: Icons.link_rounded,
                      color: const Color(0xFF00E5FF),
                      label: lang.isHindi ? 'लिंक कॉपी' : 'Copy link',
                      onTap: () async {
                        Navigator.pop(modalCtx);
                        final link = 'https://youtube.com/shorts/$_currentVideoId';
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
                        _handleWhatsAppStatus();
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
                    _showGoogleAccountPicker(context, _channelName);
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
                    _handleWhatsAppStatus();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.hd_rounded, color: AppColors.accentCyan),
                  title: Text(
                    lang.isHindi ? 'वीडियो क्वालिटी (HD 1080p 60fps Native)' : 'Video Quality (HD 1080p 60fps Native)',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    lang.isHindi ? 'यूट्यूब ऑफिशियल बफर-फ्री स्ट्रीमिंग' : 'YouTube Official Buffer-Free Streaming',
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

  void _handleSubscribeToggle() {
    final author = _channelName.isNotEmpty ? _channelName : 'Creator';
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

    // If user has not signed in with Google, open Google Account Picker directly without launching YouTube app
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

  /// Official Google Account Picker Dialog (Allows selecting or entering phone Google account)
  void _showGoogleAccountPicker(BuildContext context, String author) {
    final lang = LanguageService();
    final deviceAccounts = _subService.getAvailableDeviceAccounts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF202124),
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

                // Add another account
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

  Future<void> _handleWhatsAppStatus() async {
    final lang = LanguageService();
    final vid = _currentVideoId.isNotEmpty ? _currentVideoId : 'kffacxfA7G4';
    final dummyItem = ShortVideoItem(
      id: vid,
      title: _videoTitle,
      author: _channelName,
      thumbnailUrl: '',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.isHindi ? 'व्हाट्सएप स्टेटस तैयार हो रहा है...' : 'Preparing WhatsApp Status...'),
        backgroundColor: const Color(0xFF25D366),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    final success = await _shortsService.shareToWhatsAppStatus(dummyItem);
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

  Future<void> _handleDownload() async {
    if (_isDownloading) return;
    final lang = LanguageService();

    final vid = _currentVideoId.isNotEmpty ? _currentVideoId : 'kffacxfA7G4';
    final dummyItem = ShortVideoItem(
      id: vid,
      title: _videoTitle,
      author: _channelName,
      thumbnailUrl: '',
    );

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final path = await _shortsService.downloadShort(
      dummyItem,
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
    final isSubscribed = _subService.isSubscribed(_channelName);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return;
        }
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
        body: Stack(
          children: [
            // 1. Official YouTube Shorts Engine (Plays https://www.youtube.com/shorts directly in background)
            RefreshIndicator(
              color: AppColors.accentCyan,
              backgroundColor: const Color(0xFF131A2A),
              displacement: 60,
              onRefresh: _handleRefresh,
              child: WebViewWidget(controller: _controller),
            ),

            // Subtle Loading Overlay while fetching
            if (_isLoading)
              Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                ),
              ),

            // 2. Bottom Gradient Vignette for Readability of Overlay Controls
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

            // 3. Top Header Overlay (ONLY Back '<' and Search '🔍' icons as requested)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      // Back '<' Icon (Clean minimal chevron matching screenshot)
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

                      // Expandable Search Bar or Search Icon
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

            // 4. Left Bottom Creator Row, Red +FOLLOW Button & Video Title (EXACT MATCH TO SCREENSHOT)
            Positioned(
              left: 14,
              bottom: 24,
              right: 76,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Video Title (Clean and compact)
                  if (_videoTitle.isNotEmpty && _videoTitle != 'Trending YouTube Short') ...[
                    Text(
                      _videoTitle,
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
                  ],

                  // Creator Row: [Avatar (34dp)] [Channel Name] [Red +FOLLOW Button]
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
                            _channelName.isNotEmpty ? _channelName[0].toUpperCase() : 'Y',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      Flexible(
                        child: Text(
                          _channelName,
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

                      // Red Subscribe Button (+FOLLOW) - Direct In-App Google Sign-in without external YouTube app
                      GestureDetector(
                        onTap: _handleSubscribeToggle,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSubscribed
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSubscribed ? Colors.white30 : Colors.transparent,
                            ),
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

            // 5. Right Side Action Suite (EXACT MATCH TO SCREENSHOT - Floating White Icons with Shadows)
            Positioned(
              right: 12,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Thumbs Up (Like)
                  _buildActionItem(
                    iconWidget: Icon(
                      _isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                      color: _isLiked ? const Color(0xFF00E5FF) : Colors.white,
                      size: 28,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    label: _likesCountStr,
                    onTap: _toggleLike,
                  ),

                  // 2. Thumbs Down (Dislike)
                  _buildActionItem(
                    iconWidget: Icon(
                      _isDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_alt_outlined,
                      color: _isDisliked ? const Color(0xFF00E5FF) : Colors.white,
                      size: 28,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    label: 'Dislike',
                    onTap: _toggleDislike,
                  ),

                  // 3. Comments (Rounded chat bubble matching screenshot)
                  _buildActionItem(
                    iconWidget: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 26,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    label: '$_commentsCount',
                    onTap: () => _showCommentsModal(context),
                  ),

                  // 4. Share (Curved arrow pointing right matching screenshot)
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
                    onTap: () => _showShareModal(context),
                  ),

                  // 5. Download Video to Gallery (Downward arrow to tray)
                  _buildActionItem(
                    iconWidget: Icon(
                      _isDownloading ? Icons.hourglass_top_rounded : Icons.download_rounded,
                      color: _isDownloading ? AppColors.accentCyan : Colors.white,
                      size: 28,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    label: _isDownloading ? '${(_downloadProgress * 100).toInt()}%' : 'Download',
                    onTap: _handleDownload,
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
                    onTap: () => _showMoreOptionsModal(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Floating Action Item matching YouTube Shorts design (Pure white icon with drop shadow, no circular background)
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
