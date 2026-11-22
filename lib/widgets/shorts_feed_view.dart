import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../services/app_share_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';

/// Direct Online YouTube Shorts Module
/// - Directly loads official online Shorts link (https://m.youtube.com/shorts)
/// - All custom app overlay buttons removed (uses genuine native YouTube Shorts buttons directly)
/// - Re-click on bottom nav Shorts button: instantly refreshes / scrolls to next fresh short
/// - Up-to-down drag (pull-to-refresh): directly reloads fresh Shorts link
/// - Floating Back '<' icon at top-left for seamless return to MSIXA
class ShortsFeedView extends StatefulWidget {
  final VoidCallback? onBackToDeviceVideos;

  /// Global refresh trigger: Tapping the bottom nav Shorts icon triggers instant refresh
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  /// Trigger instant refresh to a fresh, unrepeated short video
  static void refreshFeed() {
    refreshNotifier.value++;
  }

  const ShortsFeedView({Key? key, this.onBackToDeviceVideos}) : super(key: key);

  @override
  State<ShortsFeedView> createState() => _ShortsFeedViewState();
}

class _ShortsFeedViewState extends State<ShortsFeedView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // Pull-down to refresh gesture state
  double _dragStartY = 0.0;
  double _currentPullDelta = 0.0;
  bool _isPullRefreshing = false;

  static const String _shortsUrl = 'https://www.youtube.com/shorts';

  /// Minimal CSS: Only hides YouTube website header/bottom navbar & 'Open in app' popups.
  /// ALL Shorts native buttons (Like, Dislike, Comment, Share, Creator avatar, Subscribe) remain 100% visible & interactive!
  static const String _minimalCleanupCss = '''
    /* 1. Hide YouTube website top header bar */
    ytm-mobile-topbar-renderer,
    .mobile-topbar-header,
    #header-bar,
    .topbar-header,
    header.mobile-topbar-header {
      display: none !important;
      visibility: hidden !important;
      height: 0px !important;
      max-height: 0px !important;
      overflow: hidden !important;
    }

    /* 2. Hide YouTube website bottom tab bar (Home, Subscriptions, etc.) since MSIXA has its own */
    ytm-pivot-bar-renderer,
    .pivot-bar,
    .ytm-pivot-bar {
      display: none !important;
      visibility: hidden !important;
      height: 0px !important;
      max-height: 0px !important;
      overflow: hidden !important;
    }

    /* 3. Hide annoying 'Open in YouTube App' banners and promos */
    .upsell-dialog-renderer,
    #app-banner,
    .open-app-banner,
    ytm-upsell-dialog-renderer,
    ytm-mealbar-promo-renderer,
    .banner-promo,
    ytm-button-renderer[data-target-id="open-app-button"],
    ytm-open-app-button,
    .open-app-button {
      display: none !important;
      visibility: hidden !important;
      height: 0px !important;
    }

    /* 4. Full screen black background & smooth fit */
    body, html {
      background-color: #000000 !important;
      margin: 0 !important;
      padding: 0 !important;
      overflow: hidden !important;
      user-select: none !important;
      -webkit-user-select: none !important;
    }
  ''';

  @override
  void initState() {
    super.initState();
    AppShareService.keepScreenOn(true);
    ShortsFeedView.refreshNotifier.addListener(_handleReclickRefresh);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            // Prevent external app launch attempts (stay inside MSIXA)
            if (url.startsWith('intent://') ||
                url.startsWith('market://') ||
                url.startsWith('vnd.youtube:') ||
                url.startsWith('youtube://')) {
              return NavigationDecision.prevent;
            }
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
            if (mounted) setState(() => _isLoading = true);
            _injectCleanupScript();
          },
          onProgress: (int progress) {
            if (progress > 30) {
              _injectCleanupScript();
            }
          },
          onPageFinished: (String url) {
            _injectCleanupScript();
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    _loadFreshShorts();
  }

  @override
  void dispose() {
    ShortsFeedView.refreshNotifier.removeListener(_handleReclickRefresh);
    AppShareService.keepScreenOn(false);
    super.dispose();
  }

  /// Initial load or fresh load with timestamp
  void _loadFreshShorts() {
    final freshUrl = '$_shortsUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    _controller.loadRequest(Uri.parse(freshUrl));
  }

  /// Re-click on bottom nav Shorts icon: smoothly scrolls to next short or reloads fresh session
  void _handleReclickRefresh() {
    if (!mounted) return;

    // Trigger next short scroll in YouTube Shorts carousel
    _controller.runJavaScript('''
      (function() {
        try {
          window.scrollBy({ top: window.innerHeight, behavior: 'smooth' });
          var nextBtn = document.querySelector('button[aria-label*="Next"]') ||
                        document.querySelector('button[aria-label*="next"]') ||
                        document.querySelector('.ytp-next-button');
          if (nextBtn) nextBtn.click();
        } catch(e) {}
      })();
    ''').catchError((_) {
      _loadFreshShorts();
    });
  }

  /// Pull-down to refresh: reloads fresh online shorts link
  Future<void> _handlePullRefresh() async {
    if (_isPullRefreshing) return;
    if (mounted) setState(() => _isPullRefreshing = true);

    try {
      _loadFreshShorts();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() {
        _isPullRefreshing = false;
        _currentPullDelta = 0.0;
      });
    }
  }

  void _injectCleanupScript() {
    final script = '''
      (function() {
        function injectCss() {
          var style = document.getElementById('msixa-minimal-cleanup');
          if (!style) {
            style = document.createElement('style');
            style.id = 'msixa-minimal-cleanup';
            style.innerHTML = `$_minimalCleanupCss`;
            (document.head || document.documentElement).appendChild(style);
          }
        }
        injectCss();

        function purgeClutter() {
          injectCss();
          var clutterSelectors = [
            'ytm-mobile-topbar-renderer',
            '.mobile-topbar-header',
            '#header-bar',
            '.topbar-header',
            'ytm-pivot-bar-renderer',
            '.pivot-bar',
            '#app-banner',
            '.open-app-banner',
            'ytm-upsell-dialog-renderer',
            'ytm-mealbar-promo-renderer'
          ];
          for (var i = 0; i < clutterSelectors.length; i++) {
            var els = document.querySelectorAll(clutterSelectors[i]);
            for (var j = 0; j < els.length; j++) {
              els[j].style.setProperty('display', 'none', 'important');
              els[j].style.setProperty('visibility', 'hidden', 'important');
              els[j].style.setProperty('height', '0px', 'important');
            }
          }
        }
        purgeClutter();

        var observer = new MutationObserver(function() {
          purgeClutter();
        });
        observer.observe(document.documentElement || document.body, { childList: true, subtree: true });
        setInterval(purgeClutter, 400);

        // Prevent opening external YouTube app
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
      })();
    ''';
    _controller.runJavaScript(script).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();

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
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _dragStartY = event.position.dy;
            _currentPullDelta = 0.0;
          },
          onPointerMove: (event) {
            final deltaY = event.position.dy - _dragStartY;
            // Detect pull down to refresh from upper 50% of screen
            if (_dragStartY < MediaQuery.of(context).size.height * 0.50 && deltaY > 0) {
              if (mounted) {
                setState(() {
                  _currentPullDelta = deltaY.clamp(0.0, 120.0);
                });
              }
            }
          },
          onPointerUp: (event) {
            if (_currentPullDelta > 50.0 && !_isPullRefreshing) {
              _handlePullRefresh();
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
              // 1. Official Online YouTube Shorts Engine (Direct Link, Native Shorts Buttons Only)
              WebViewWidget(controller: _controller),

              // Loading Spinner while initial request is fetching
              if (_isLoading)
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.accentCyan),
                  ),
                ),

              // 2. Pull-down Drag to Refresh Indicator Badge
              if (_currentPullDelta > 15.0 || _isPullRefreshing)
                Positioned(
                  top: 50 + (_currentPullDelta * 0.35),
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

              // 3. Floating Minimal Back '<' Icon at Top-Left to Return to MSIXA
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GestureDetector(
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
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1))],
                        ),
                      ),
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
}
