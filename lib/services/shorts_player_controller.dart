import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
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

/// Controller managing official YouTube IFrame Player instances,
/// bounded sliding-window pooling, active video transitions, and lifecycle cleanup.
class ShortsPlayerController extends ChangeNotifier {
  final Map<int, YoutubePlayerController> _controllers = {};
  final Map<int, ShortsPlaybackState> _states = {};
  final Map<int, StreamSubscription?> _subscriptions = {};

  int _activeIndex = 0;
  bool _isMuted = false;
  bool _isDisposed = false;

  int get activeIndex => _activeIndex;
  bool get isMuted => _isMuted;

  YoutubePlayerController? get activeController => _controllers[_activeIndex];
  ShortsPlaybackState get activeState => _states[_activeIndex] ?? ShortsPlaybackState.idle;

  ShortsPlaybackState getStateForIndex(int index) => _states[index] ?? ShortsPlaybackState.idle;
  YoutubePlayerController? getControllerForIndex(int index) => _controllers[index];

  /// Initializes or retrieves an official IFrame controller for a given feed item
  YoutubePlayerController getOrCreateController({
    required int index,
    required ShortVideoItem item,
    bool autoPlay = false,
  }) {
    if (_controllers.containsKey(index)) {
      return _controllers[index]!;
    }

    _states[index] = ShortsPlaybackState.initializing;

    final controller = YoutubePlayerController(
      params: YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: _isMuted,
        loop: true,
        playsInline: true,
        strictRelatedVideos: true,
        pointerEvents: PointerEvents.none, // Transparent to swipe gestures
      ),
    );

    _controllers[index] = controller;

    // Listen to official player state changes
    final sub = controller.videoStateStream.listen(
      (videoState) {
        _handlePlayerStateChange(index, videoState);
      },
      onError: (_) {
        _states[index] = ShortsPlaybackState.error;
        notifyListeners();
      },
    );
    _subscriptions[index] = sub;

    // Load or cue based on autoplay flag
    try {
      if (autoPlay) {
        controller.loadVideoById(videoId: item.id);
      } else {
        controller.cueVideoById(videoId: item.id);
      }
    } catch (_) {
      _states[index] = ShortsPlaybackState.error;
    }

    return controller;
  }

  void _handlePlayerStateChange(int index, VideoState videoState) {
    if (_isDisposed) return;

    final playerState = videoState.playerState;
    ShortsPlaybackState newState;

    switch (playerState) {
      case PlayerState.playing:
        newState = ShortsPlaybackState.playing;
        break;
      case PlayerState.paused:
        newState = ShortsPlaybackState.paused;
        break;
      case PlayerState.buffering:
        newState = ShortsPlaybackState.buffering;
        break;
      case PlayerState.ended:
        newState = ShortsPlaybackState.ended;
        break;
      case PlayerState.cued:
        newState = ShortsPlaybackState.ready;
        break;
      default:
        newState = _states[index] ?? ShortsPlaybackState.ready;
    }

    if (_states[index] != newState) {
      _states[index] = newState;
      if (index == _activeIndex) {
        notifyListeners();
      }
    }
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
        _subscriptions[k]?.cancel();
        _subscriptions.remove(k);
        _controllers[k]?.pauseVideo();
        _controllers[k]?.close();
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
    for (final sub in _subscriptions.values) {
      sub?.cancel();
    }
    _subscriptions.clear();

    for (final ctrl in _controllers.values) {
      try {
        ctrl.pauseVideo();
        ctrl.close();
      } catch (_) {}
    }
    _controllers.clear();
    _states.clear();
    super.dispose();
  }
}
