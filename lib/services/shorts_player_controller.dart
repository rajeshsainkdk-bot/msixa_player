import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../models/short_video_item.dart';

/// Official Player Lifecycle State Model (Section 9)
enum ShortsPlaybackState {
  idle,
  initializing,
  ready,
  playing,
  paused,
  buffering,
  ended,
  error,
  autoplayBlocked,
}

/// Represents an individual official YouTube IFrame Player instance
class ShortsIFrameInstance {
  final int index;
  final ShortVideoItem item;
  final WebViewController? webViewController;
  ShortsPlaybackState state;

  ShortsIFrameInstance({
    required this.index,
    required this.item,
    this.webViewController,
    this.state = ShortsPlaybackState.initializing,
  });

  factory ShortsIFrameInstance.dummy({
    required int index,
    required ShortVideoItem item,
  }) {
    return ShortsIFrameInstance(
      index: index,
      item: item,
      webViewController: null,
      state: ShortsPlaybackState.ready,
    );
  }

  void playVideo() {
    try {
      webViewController?.runJavaScript('if(window.playVideo) playVideo();');
    } catch (_) {}
  }

  void pauseVideo() {
    try {
      webViewController?.runJavaScript('if(window.pauseVideo) pauseVideo();');
    } catch (_) {}
  }

  void mute() {
    try {
      webViewController?.runJavaScript('if(window.mute) mute();');
    } catch (_) {}
  }

  void unMute() {
    try {
      webViewController?.runJavaScript('if(window.unMute) unMute();');
    } catch (_) {}
  }

  void dispose() {
    try {
      pauseVideo();
      webViewController?.loadHtmlString('<html><body style="background:#000;"></body></html>');
    } catch (_) {}
  }
}

/// Controller managing official YouTube IFrame Player instances,
/// bounded sliding-window pooling, active video transitions, and lifecycle cleanup.
class ShortsPlayerController extends ChangeNotifier {
  final Map<int, ShortsIFrameInstance> _controllers = {};
  final Map<int, ShortsPlaybackState> _states = {};

  int _activeIndex = 0;
  bool _isMuted = false;
  bool _isDisposed = false;

  void Function(int index)? onVideoEnded;

  int get activeIndex => _activeIndex;
  bool get isMuted => _isMuted;

  ShortsIFrameInstance? get activeController => _controllers[_activeIndex];
  ShortsPlaybackState get activeState => _states[_activeIndex] ?? ShortsPlaybackState.idle;

  ShortsPlaybackState getStateForIndex(int index) => _states[index] ?? ShortsPlaybackState.idle;
  ShortsIFrameInstance? getControllerForIndex(int index) => _controllers[index];

  /// Initializes or retrieves an official IFrame controller for a given feed item
  ShortsIFrameInstance getOrCreateController({
    required int index,
    required ShortVideoItem item,
    bool autoPlay = false,
  }) {
    if (_controllers.containsKey(index)) {
      return _controllers[index]!;
    }

    try {
      final instance = _createIFrameInstance(
        index: index,
        item: item,
        autoPlay: autoPlay,
      );
      _controllers[index] = instance;
      _states[index] = ShortsPlaybackState.initializing;
      return instance;
    } catch (_) {
      // Safe fallback for testing or environments where WebViewPlatform is uninitialized
      final dummy = ShortsIFrameInstance.dummy(index: index, item: item);
      _controllers[index] = dummy;
      _states[index] = ShortsPlaybackState.ready;
      return dummy;
    }
  }

  ShortsIFrameInstance _createIFrameInstance({
    required int index,
    required ShortVideoItem item,
    required bool autoPlay,
  }) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url.startsWith('https://www.youtube.com') ||
                url.startsWith('https://youtube.com') ||
                url.startsWith('https://www.youtube-nocookie.com') ||
                url.startsWith('about:blank') ||
                url.startsWith('data:')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      try {
        (controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
      } catch (_) {}
    }

    controller.addJavaScriptChannel(
      'ShortsBridge',
      onMessageReceived: (JavaScriptMessage message) {
        _handleJsMessage(index, message.message);
      },
    );

    final html = _buildIFrameHtml(
      videoId: item.id,
      autoPlay: autoPlay,
      isMuted: _isMuted,
    );
    controller.loadHtmlString(html, baseUrl: 'https://www.youtube.com');

    return ShortsIFrameInstance(
      index: index,
      item: item,
      webViewController: controller,
      state: ShortsPlaybackState.initializing,
    );
  }

  static String _buildIFrameHtml({
    required String videoId,
    required bool autoPlay,
    required bool isMuted,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin:0; padding:0; box-sizing:border-box; background-color:#000000; overflow:hidden; }
    html, body { width:100%; height:100%; background:#000000; }
    #player-wrap { width:100%; height:100%; position:relative; overflow:hidden; }
    #player { width:100%; height:100%; border:none; pointer-events:none; }
  </style>
</head>
<body>
  <div id="player-wrap">
    <div id="player"></div>
  </div>
  <script>
    var tag = document.createElement('script');
    tag.src = "https://www.youtube.com/iframe_api";
    var firstScriptTag = document.getElementsByTagName('script')[0];
    firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

    var player;
    var isReady = false;
    var pendingPlay = false;

    function onYouTubeIframeAPIReady() {
      player = new YT.Player('player', {
        height: '100%',
        width: '100%',
        videoId: '$videoId',
        playerVars: {
          'autoplay': ${autoPlay ? 1 : 0},
          'controls': 0,
          'disablekb': 1,
          'fs': 0,
          'playsinline': 1,
          'rel': 0,
          'modestbranding': 1,
          'iv_load_policy': 3,
          'loop': 1,
          'playlist': '$videoId',
          'enablejsapi': 1,
          'origin': 'https://www.youtube.com'
        },
        events: {
          'onReady': onPlayerReady,
          'onStateChange': onPlayerStateChange,
          'onError': onPlayerError
        }
      });
    }

    function onPlayerReady(event) {
      isReady = true;
      if (${isMuted}) {
        player.mute();
      } else {
        player.unMute();
      }
      if (${autoPlay} || pendingPlay) {
        player.playVideo();
      }
      if (window.ShortsBridge) {
        window.ShortsBridge.postMessage(JSON.stringify({type: 'ready'}));
      }
    }

    function onPlayerStateChange(event) {
      if (window.ShortsBridge) {
        window.ShortsBridge.postMessage(JSON.stringify({type: 'state', code: event.data}));
      }
    }

    function onPlayerError(event) {
      if (window.ShortsBridge) {
        window.ShortsBridge.postMessage(JSON.stringify({type: 'error', code: event.data}));
      }
    }

    function playVideo() {
      if (player && player.playVideo) {
        player.playVideo();
      } else {
        pendingPlay = true;
      }
    }

    function pauseVideo() {
      pendingPlay = false;
      if (player && player.pauseVideo) {
        player.pauseVideo();
      }
    }

    function mute() {
      if (player && player.mute) {
        player.mute();
      }
    }

    function unMute() {
      if (player && player.unMute) {
        player.unMute();
      }
    }
  </script>
</body>
</html>
''';
  }

  void _handleJsMessage(int index, String rawMessage) {
    if (_isDisposed) return;
    try {
      final map = jsonDecode(rawMessage) as Map<String, dynamic>;
      final type = map['type'] as String?;

      if (type == 'state') {
        final code = map['code'] as int?;
        ShortsPlaybackState newState = _states[index] ?? ShortsPlaybackState.ready;
        switch (code) {
          case 1: // PLAYING
            newState = ShortsPlaybackState.playing;
            break;
          case 2: // PAUSED
            newState = ShortsPlaybackState.paused;
            break;
          case 3: // BUFFERING
            newState = ShortsPlaybackState.buffering;
            break;
          case 0: // ENDED
            newState = ShortsPlaybackState.ended;
            if (index == _activeIndex) {
              onVideoEnded?.call(index);
            }
            break;
          case 5: // CUED
            newState = ShortsPlaybackState.ready;
            break;
        }
        _states[index] = newState;
        if (_controllers.containsKey(index)) {
          _controllers[index]?.state = newState;
        }
        if (index == _activeIndex) {
          notifyListeners();
        }
      } else if (type == 'ready') {
        _states[index] = ShortsPlaybackState.ready;
        if (_controllers.containsKey(index)) {
          _controllers[index]?.state = ShortsPlaybackState.ready;
        }
        if (index == _activeIndex) {
          notifyListeners();
        }
      } else if (type == 'error') {
        _states[index] = ShortsPlaybackState.error;
        if (_controllers.containsKey(index)) {
          _controllers[index]?.state = ShortsPlaybackState.error;
        }
        if (index == _activeIndex) {
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Single Active Player Transition on Swipe (Section 9)
  void onPageChanged({
    required int newIndex,
    required List<ShortVideoItem> items,
  }) {
    if (_isDisposed || newIndex == _activeIndex) return;

    final oldIndex = _activeIndex;
    _activeIndex = newIndex;

    // 1. Immediately pause the old video to eliminate audio bleed
    if (_controllers.containsKey(oldIndex)) {
      try {
        _controllers[oldIndex]?.pauseVideo();
        _states[oldIndex] = ShortsPlaybackState.paused;
      } catch (_) {}
    }

    // 2. Play the active video immediately
    if (newIndex >= 0 && newIndex < items.length) {
      final ctrl = getOrCreateController(
        index: newIndex,
        item: items[newIndex],
        autoPlay: true,
      );
      try {
        ctrl.playVideo();
      } catch (_) {}
    }

    // 3. Pre-warm / Cue the NEXT video (+1) for zero startup delay on swipe
    final nextIndex = newIndex + 1;
    if (nextIndex < items.length) {
      getOrCreateController(
        index: nextIndex,
        item: items[nextIndex],
        autoPlay: false,
      );
    }

    // 4. Memory Cleanup: Strictly keep only [newIndex - 1, newIndex, newIndex + 1]
    _cleanupDistantControllers(newIndex);

    notifyListeners();
  }

  /// Disposes controllers out of the sliding window to prevent hardware decoder exhaustion
  void _cleanupDistantControllers(int centerIndex) {
    final keysToRemove = _controllers.keys.where((k) => (k - centerIndex).abs() > 1).toList();
    for (final k in keysToRemove) {
      try {
        _controllers[k]?.dispose();
        _controllers.remove(k);
        _states.remove(k);
      } catch (_) {}
    }
  }

  /// Toggles play / pause on the active video
  void togglePlayPause() {
    final ctrl = activeController;
    if (ctrl == null) return;

    if (activeState == ShortsPlaybackState.playing) {
      ctrl.pauseVideo();
      _states[_activeIndex] = ShortsPlaybackState.paused;
    } else {
      ctrl.playVideo();
      _states[_activeIndex] = ShortsPlaybackState.playing;
    }
    notifyListeners();
  }

  /// Toggles mute across all active and queued player instances
  void toggleMute() {
    _isMuted = !_isMuted;
    for (final ctrl in _controllers.values) {
      try {
        if (_isMuted) {
          ctrl.mute();
        } else {
          ctrl.unMute();
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Cleans up all resources when user exits the Shorts feed
  @override
  void dispose() {
    _isDisposed = true;
    for (final ctrl in _controllers.values) {
      try {
        ctrl.dispose();
      } catch (_) {}
    }
    _controllers.clear();
    _states.clear();
    super.dispose();
  }
}
