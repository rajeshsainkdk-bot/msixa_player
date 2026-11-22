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
/// - Starts unmuted with full audio immediately on click & refresh
/// - Sits cleanly below system status bar (no overlap with network/battery)
/// - Full-screen when playing (hides bottom nav), shows nav when paused
/// - Hides YouTube top-left logo and "Open in App" popups, keeps Sign In visible
/// - Top-left back button & Android back button seamlessly return to Discover and stop audio
class ShortsFeedView extends StatefulWidget {
  final VoidCallback? onBackToDeviceVideos;
  final VoidCallback? onBackToHome;

  /// Global refresh trigger: Tapping the bottom nav Shorts icon triggers instant refresh
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  /// Global playback state: true = playing (hide bottom nav), false = paused (show bottom nav)
  static final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  /// Global pause request trigger: used when user leaves or pauses the Shorts tab
  static final ValueNotifier<int> pauseRequestNotifier = ValueNotifier<int>(0);

  /// Trigger instant refresh to a fresh, unrepeated short video
  static void refreshFeed() {
    refreshNotifier.value++;
  }

  /// Pause shorts playback and stop audio completely
  static void pausePlayback() {
    isPlayingNotifier.value = false;
    pauseRequestNotifier.value++;
  }

  const ShortsFeedView({
    Key? key,
    this.onBackToDeviceVideos,
    this.onBackToHome,
  }) : super(key: key);

  @override
  State<ShortsFeedView> createState() => _ShortsFeedViewState();
}

class _ShortsFeedViewState extends State<ShortsFeedView> with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;

  // Pull-down to refresh gesture state
  double _dragStartY = 0.0;
  double _currentPullDelta = 0.0;
  bool _isPullRefreshing = false;

  static const String _shortsUrl = 'https://www.youtube.com/shorts';

  /// Cleanup CSS:
  /// 1. Completely hides YouTube website logo at top-left corner.
  /// 2. Hides "Open in YouTube App" promos, banners, and buttons.
  /// 3. Hides YouTube website bottom pivot tab bar.
  /// 4. KEEPS Google Account "Sign in" button intact and functional.
  /// 5. ALL native Shorts buttons (Like, Dislike, Comment, Share, Avatar, Subscribe) remain 100% visible & interactive!
  static const String _minimalCleanupCss = '''
    /* 1. Hide YouTube website logo on top-left corner */
    #logo,
    a#logo,
    .ytm-logo,
    ytm-home-logo,
    .topbar-logo,
    yt-icon.topbar-logo,
    a.mobile-topbar-header-endpoint,
    a[aria-label="YouTube"],
    a[aria-label="YouTube Home"],
    yt-icon[type="brand"],
    .yt-spec-icon-badge-shape--type-brand,
    .header-bar-logo {
      display: none !important;
      visibility: hidden !important;
      opacity: 0 !important;
      height: 0px !important;
      max-height: 0px !important;
      width: 0px !important;
      overflow: hidden !important;
      pointer-events: none !important;
    }

    /* 2. Hide "Open YouTube App" buttons and banners completely */
    ytm-open-app-button,
    .open-app-button,
    [data-target-id="open-app-button"],
    ytm-button-renderer[data-target-id="open-app-button"],
    a[aria-label*="Open app" i],
    button[aria-label*="Open app" i],
    a[aria-label*="Open YouTube app" i],
    button[aria-label*="Open YouTube app" i],
    .upsell-dialog-renderer,
    ytm-upsell-dialog-renderer,
    ytm-mealbar-promo-renderer,
    .banner-promo,
    #app-banner,
    .open-app-banner {
      display: none !important;
      visibility: hidden !important;
      opacity: 0 !important;
      height: 0px !important;
      width: 0px !important;
      overflow: hidden !important;
      pointer-events: none !important;
    }

    /* 3. Keep Sign In button visible and accessible at top right */
    ytm-signin-button,
    a[href*="accounts.google.com"],
    a[href*="ServiceLogin"],
    a[aria-label*="Sign in" i],
    .signin-button {
      display: inline-block !important;
      visibility: visible !important;
      opacity: 1 !important;
      pointer-events: auto !important;
    }

    /* 4. Hide YouTube website bottom tab bar (Home, Subscriptions) */
    ytm-pivot-bar-renderer,
    .pivot-bar,
    .ytm-pivot-bar {
      display: none !important;
      visibility: hidden !important;
      height: 0px !important;
      max-height: 0px !important;
      overflow: hidden !important;
    }

    /* 5. Full screen black background & smooth fit */
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
    WidgetsBinding.instance.addObserver(this);
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
          final state = message.message;
          if (state == 'playing') {
            if (mounted) ShortsFeedView.isPlayingNotifier.value = true;
          } else if (state == 'paused') {
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
            if (progress > 20) {
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
    WidgetsBinding.instance.removeObserver(this);
    ShortsFeedView.refreshNotifier.removeListener(_handleReclickRefresh);
    ShortsFeedView.pauseRequestNotifier.removeListener(_handlePauseRequest);
    ShortsFeedView.isPlayingNotifier.value = false;
    AppShareService.keepScreenOn(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ShortsFeedView.pausePlayback();
    }
  }

  void _handlePauseRequest() {
    _controller.runJavaScript('''
      (function() {
        try {
          var videos = document.querySelectorAll('video');
          for (var i = 0; i < videos.length; i++) {
            videos[i].pause();
            videos[i].muted = true;
          }
        } catch(_) {}
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
        // 1. Inject CSS to hide website logo and Open App promos
        function injectCss() {
          try {
            var style = document.getElementById('msixa-minimal-cleanup');
            if (!style) {
              style = document.createElement('style');
              style.id = 'msixa-minimal-cleanup';
              style.innerHTML = `$_minimalCleanupCss`;
              (document.head || document.documentElement).appendChild(style);
            }
          } catch(e) {}
        }
        injectCss();

        // 2. Override HTMLMediaElement prototype muted and volume setters so YouTube CANNOT mute video
        try {
          if (!window._msixaAudioPatched) {
            window._msixaAudioPatched = true;
            var nativeMutedDesc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'muted');
            Object.defineProperty(HTMLMediaElement.prototype, 'muted', {
              get: function() { return false; },
              set: function(val) {
                if (nativeMutedDesc && nativeMutedDesc.set) {
                  nativeMutedDesc.set.call(this, false);
                }
              },
              configurable: true,
              enumerable: true
            });

            var nativeVolDesc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'volume');
            Object.defineProperty(HTMLMediaElement.prototype, 'volume', {
              get: function() { return 1.0; },
              set: function(val) {
                if (nativeVolDesc && nativeVolDesc.set) {
                  nativeVolDesc.set.call(this, 1.0);
                }
              },
              configurable: true,
              enumerable: true
            });
          }
        } catch(e) {}

        // 3. Set volume unmuted in localStorage & sessionStorage
        try {
          var volData = JSON.stringify({ volume: 100, muted: false });
          localStorage.setItem('yt-player-volume', JSON.stringify({ data: volData }));
          sessionStorage.setItem('yt-player-volume', JSON.stringify({ data: volData }));
        } catch(e) {}

        // 4. Force unmute on any video elements and click any unmute overlay button
        function forceUnmute() {
          try {
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
          } catch(e) {}
        }
        forceUnmute();

        // 5. Purge clutter: remove YouTube logo & Open App button from DOM, keep Sign In
        function purgeClutter() {
          try {
            injectCss();
            forceUnmute();

            // Remove YouTube logo at top-left
            var logos = document.querySelectorAll(
              '#logo, a#logo, ytm-home-logo, .topbar-logo, yt-icon.topbar-logo, ' +
              'a.mobile-topbar-header-endpoint, a[aria-label="YouTube"], a[aria-label="YouTube Home"], ' +
              'yt-icon[type="brand"], .yt-spec-icon-badge-shape--type-brand'
            );
            for (var i = 0; i < logos.length; i++) {
              logos[i].style.setProperty('display', 'none', 'important');
              logos[i].style.setProperty('visibility', 'hidden', 'important');
            }

            // Remove Open App buttons & popups
            var openApps = document.querySelectorAll(
              'ytm-open-app-button, .open-app-button, [data-target-id="open-app-button"], ' +
              'a[aria-label*="Open app" i], button[aria-label*="Open app" i], ' +
              '.upsell-dialog-renderer, ytm-upsell-dialog-renderer, ytm-mealbar-promo-renderer, #app-banner'
            );
            for (var j = 0; j < openApps.length; j++) {
              openApps[j].remove();
            }

            // Remove YouTube bottom pivot bar
            var pivotBars = document.querySelectorAll('ytm-pivot-bar-renderer, .pivot-bar, .ytm-pivot-bar');
            for (var k = 0; k < pivotBars.length; k++) {
              pivotBars[k].style.setProperty('display', 'none', 'important');
              pivotBars[k].style.setProperty('visibility', 'hidden', 'important');
            }
          } catch(e) {}
        }
        purgeClutter();

        // 6. Playback state detection: check if video is actively playing vs paused
        var lastPlaybackState = '';
        function checkPlaybackState() {
          try {
            var videos = document.querySelectorAll('video');
            var isPlaying = false;
            for (var i = 0; i < videos.length; i++) {
              var v = videos[i];
              if (!v.paused && !v.ended && v.currentTime > 0) {
                isPlaying = true;
                break;
              }
            }
            var currentState = isPlaying ? 'playing' : 'paused';
            if (currentState !== lastPlaybackState) {
              lastPlaybackState = currentState;
              if (window.MsixaPlaybackChannel) {
                window.MsixaPlaybackChannel.postMessage(currentState);
              }
            }
          } catch(e) {}
        }
        setInterval(checkPlaybackState, 250);

        // 7. Video event listeners for instantaneous play/pause state
        ['play', 'playing'].forEach(function(evt) {
          document.addEventListener(evt, function(e) {
            if (e.target && e.target.tagName && e.target.tagName.toUpperCase() === 'VIDEO') {
              e.target.muted = false;
              e.target.volume = 1.0;
              forceUnmute();
              lastPlaybackState = 'playing';
              if (window.MsixaPlaybackChannel) {
                window.MsixaPlaybackChannel.postMessage('playing');
              }
            }
          }, true);
        });

        ['pause', 'ended'].forEach(function(evt) {
          document.addEventListener(evt, function(e) {
            if (e.target && e.target.tagName && e.target.tagName.toUpperCase() === 'VIDEO') {
              lastPlaybackState = 'paused';
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
          try {
            if (!e.target || typeof e.target.closest !== 'function') return;
            var target = e.target.closest('a, button');
            if (target) {
              var href = target.getAttribute('href') || '';
              if (href.indexOf('intent://') === 0 || href.indexOf('market://') === 0 || href.indexOf('vnd.youtube') === 0) {
                e.preventDefault();
                e.stopPropagation();
                return false;
              }
            }
          } catch(_) {}
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
        // Immediately pause and stop audio
        ShortsFeedView.pausePlayback();
        if (widget.onBackToHome != null) {
          widget.onBackToHome!();
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
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        // Stop Shorts video audio immediately before navigating away
                        ShortsFeedView.pausePlayback();
                        if (widget.onBackToHome != null) {
                          widget.onBackToHome!();
                        } else if (widget.onBackToDeviceVideos != null) {
                          widget.onBackToDeviceVideos!();
                        } else if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
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
      ),
    );
  }
}
