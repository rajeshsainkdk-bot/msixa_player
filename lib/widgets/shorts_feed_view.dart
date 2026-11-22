import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../services/app_share_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';

/// Direct Online YouTube Shorts Module
/// - Directly loads official online Shorts link (https://www.youtube.com/shorts)
/// - Starts unmuted with full audio on click & refresh
/// - Sits cleanly below system status bar (no overlap with network/battery)
/// - Full-screen when playing (hides bottom nav), shows nav when paused
/// - Completely hides YouTube logo & top-left header icons
/// - Top-left back button seamlessly returns to Discover/Home tab
class ShortsFeedView extends StatefulWidget {
  final VoidCallback? onBackToDeviceVideos;
  final VoidCallback? onBackToHome;

  /// Global refresh trigger: Tapping the bottom nav Shorts icon triggers instant refresh
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  /// Global playback state: true = playing (hide bottom nav), false = paused (show bottom nav)
  static final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  /// Global pause request trigger: used when user switches away from the Shorts tab
  static final ValueNotifier<int> pauseRequestNotifier = ValueNotifier<int>(0);

  /// Trigger instant refresh to a fresh, unrepeated short video
  static void refreshFeed() {
    refreshNotifier.value++;
  }

  /// Pause shorts playback
  static void pausePlayback() {
    pauseRequestNotifier.value++;
    isPlayingNotifier.value = false;
  }

  const ShortsFeedView({
    Key? key,
    this.onBackToDeviceVideos,
    this.onBackToHome,
  }) : super(key: key);

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

  /// Minimal CSS:
  /// 1. Completely hides YouTube website header/logo/icons.
  /// 2. Hides YouTube website bottom pivot bar & external app promos.
  /// 3. ALL native Shorts buttons (Like, Dislike, Comment, Share, Channel Avatar, Subscribe) remain 100% visible & interactive!
  static const String _minimalCleanupCss = '''
    /* 1. Hide YouTube website top header bar, logo, and top-left branding */
    ytm-mobile-topbar-renderer,
    .mobile-topbar-header,
    #header-bar,
    .topbar-header,
    header,
    header.mobile-topbar-header,
    #logo,
    .ytm-logo,
    ytm-home-logo,
    .topbar-logo,
    ytd-topbar-logo-renderer,
    .mobile-topbar-header-endpoint,
    yt-icon.topbar-logo,
    yt-icon[type="brand"],
    .yt-spec-icon-badge-shape--type-brand,
    a[href="/"][id*="logo"],
    a[aria-label="YouTube"],
    a[aria-label="YouTube Home"],
    .header-bar-logo,
    yt-icon.mobile-topbar-header-endpoint,
    button[aria-label*="YouTube" i] {
      display: none !important;
      visibility: hidden !important;
      opacity: 0 !important;
      height: 0px !important;
      max-height: 0px !important;
      width: 0px !important;
      overflow: hidden !important;
      pointer-events: none !important;
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
    ShortsFeedView.isPlayingNotifier.value = false;
    ShortsFeedView.refreshNotifier.addListener(_handleReclickRefresh);
    ShortsFeedView.pauseRequestNotifier.addListener(_handlePauseRequest);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..addJavaScriptChannel(
        'MsixaPlaybackChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'playing') {
            if (mounted) ShortsFeedView.isPlayingNotifier.value = true;
          } else if (message.message == 'paused') {
            if (mounted) ShortsFeedView.isPlayingNotifier.value = false;
          }
        },
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
            ShortsFeedView.isPlayingNotifier.value = false;
            _injectCleanupScript();
          },
          onProgress: (int progress) {
            if (progress > 25) {
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
    ShortsFeedView.pauseRequestNotifier.removeListener(_handlePauseRequest);
    ShortsFeedView.isPlayingNotifier.value = false;
    AppShareService.keepScreenOn(false);
    super.dispose();
  }

  void _handlePauseRequest() {
    _controller.runJavaScript('''
      (function() {
        var videos = document.querySelectorAll('video');
        for (var i = 0; i < videos.length; i++) {
          videos[i].pause();
        }
      })();
    ''').catchError((_) {});
  }

  /// Initial load or fresh load with timestamp
  void _loadFreshShorts() {
    ShortsFeedView.isPlayingNotifier.value = false;
    final freshUrl = '$_shortsUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    _controller.loadRequest(Uri.parse(freshUrl));
  }

  /// Re-click on bottom nav Shorts icon: directly reloads fresh shorts link
  void _handleReclickRefresh() {
    if (!mounted) return;
    _loadFreshShorts();
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
        // 1. Inject CSS to hide website headers and logos
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

        // 2. Unmute and force max audio volume
        function forceUnmute() {
          try {
            var volData = JSON.stringify({ volume: 100, muted: false });
            localStorage.setItem('yt-player-volume', JSON.stringify({ data: volData }));
            sessionStorage.setItem('yt-player-volume', JSON.stringify({ data: volData }));
          } catch(e) {}

          var videos = document.querySelectorAll('video');
          for (var i = 0; i < videos.length; i++) {
            var v = videos[i];
            if (v.muted) v.muted = false;
            if (v.volume < 1.0) v.volume = 1.0;
            if (v.hasAttribute('muted')) v.removeAttribute('muted');
          }

          var muteButtons = document.querySelectorAll(
            'button[aria-label*="unmute" i], ' +
            'button[aria-label*="Unmute" i], ' +
            '.ytp-mute-button[aria-pressed="true"], ' +
            'ytm-mute-button, ' +
            '[aria-label*="Unmute" i]'
          );
          for (var j = 0; j < muteButtons.length; j++) {
            var btn = muteButtons[j];
            var aria = (btn.getAttribute('aria-label') || '').toLowerCase();
            if (aria.indexOf('unmute') !== -1 || btn.getAttribute('aria-pressed') === 'true') {
              btn.click();
            }
          }
        }
        forceUnmute();

        // 3. Purge clutter and logos
        function purgeClutter() {
          injectCss();
          forceUnmute();
          var clutterSelectors = [
            'ytm-mobile-topbar-renderer',
            '.mobile-topbar-header',
            '#header-bar',
            '.topbar-header',
            'header',
            '#logo',
            '.ytm-logo',
            'ytm-home-logo',
            '.topbar-logo',
            'ytd-topbar-logo-renderer',
            '.mobile-topbar-header-endpoint',
            'yt-icon.topbar-logo',
            'yt-icon[type="brand"]',
            '.yt-spec-icon-badge-shape--type-brand',
            'a[aria-label="YouTube"]',
            'a[aria-label="YouTube Home"]',
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
              els[j].style.setProperty('width', '0px', 'important');
              els[j].style.setProperty('opacity', '0', 'important');
            }
          }
        }
        purgeClutter();

        // 4. Hook video events for play/pause state communication
        ['play', 'playing'].forEach(function(evt) {
          document.addEventListener(evt, function(e) {
            if (e.target && e.target.tagName === 'VIDEO') {
              e.target.muted = false;
              e.target.volume = 1.0;
              forceUnmute();
              if (window.MsixaPlaybackChannel) {
                window.MsixaPlaybackChannel.postMessage('playing');
              }
            }
          }, true);
        });

        ['pause', 'ended'].forEach(function(evt) {
          document.addEventListener(evt, function(e) {
            if (e.target && e.target.tagName === 'VIDEO') {
              if (window.MsixaPlaybackChannel) {
                window.MsixaPlaybackChannel.postMessage('paused');
              }
            }
          }, true);
        });

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
        if (widget.onBackToHome != null) {
          widget.onBackToHome!();
          return;
        }
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // Sits cleanly below system status bar (network, wifi, battery icons preserved)
        body: SafeArea(
          top: true,
          bottom: false,
          child: Listener(
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
                Positioned.fill(
                  child: WebViewWidget(controller: _controller),
                ),

                // Loading Spinner while initial request is fetching
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.accentCyan),
                      ),
                    ),
                  ),

                // 2. Pull-down Drag to Refresh Indicator Badge
                if (_currentPullDelta > 15.0 || _isPullRefreshing)
                  Positioned(
                    top: 20 + (_currentPullDelta * 0.35),
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

                // 3. Floating Minimal Back '<' Icon at Top-Left to Return to MSIXA Discover
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: () {
                      if (widget.onBackToDeviceVideos != null) {
                        widget.onBackToDeviceVideos!();
                      } else if (widget.onBackToHome != null) {
                        widget.onBackToHome!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
