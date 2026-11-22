import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../models/short_video_item.dart';
import 'shorts_service.dart';

/// Official Player Lifecycle State Model
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

/// Represents an individual native in-app Short Video Player instance
class ShortsPlaybackInstance {
  final int index;
  final ShortVideoItem item;
  VideoPlayerController? videoPlayerController;
  ShortsPlaybackState state;

  ShortsPlaybackInstance({
    required this.index,
    required this.item,
    this.videoPlayerController,
    this.state = ShortsPlaybackState.initializing,
  });

  factory ShortsPlaybackInstance.dummy({
    required int index,
    required ShortVideoItem item,
  }) {
    return ShortsPlaybackInstance(
      index: index,
      item: item,
      videoPlayerController: null,
      state: ShortsPlaybackState.ready,
    );
  }

  void playVideo() {
    try {
      videoPlayerController?.play();
    } catch (_) {}
  }

  void pauseVideo() {
    try {
      videoPlayerController?.pause();
    } catch (_) {}
  }

  void mute() {
    try {
      videoPlayerController?.setVolume(0.0);
    } catch (_) {}
  }

  void unMute() {
    try {
      videoPlayerController?.setVolume(1.0);
    } catch (_) {}
  }

  void dispose() {
    try {
      videoPlayerController?.pause();
      videoPlayerController?.dispose();
    } catch (_) {}
    videoPlayerController = null;
  }
}

// Backwards-compatible alias for existing tests and references
typedef ShortsIFrameInstance = ShortsPlaybackInstance;

/// Controller managing native VideoPlayerController instances,
/// sliding-window pre-buffering pipeline, zero-latency transitions, and lifecycle cleanup.
class ShortsPlayerController extends ChangeNotifier {
  final ShortsService _shortsService = ShortsService();
  final Map<int, ShortsPlaybackInstance> _controllers = {};
  final Map<int, ShortsPlaybackState> _states = {};
  final Set<int> _loadingIndices = {};

  int _activeIndex = 0;
  bool _isMuted = false;
  bool _isDisposed = false;

  void Function(int index)? onVideoEnded;

  int get activeIndex => _activeIndex;
  bool get isMuted => _isMuted;

  ShortsPlaybackInstance? get activeController => _controllers[_activeIndex];
  ShortsPlaybackState get activeState => _states[_activeIndex] ?? ShortsPlaybackState.idle;

  ShortsPlaybackState getStateForIndex(int index) => _states[index] ?? ShortsPlaybackState.idle;
  ShortsPlaybackInstance? getControllerForIndex(int index) => _controllers[index];

  /// Initializes or retrieves an in-app player controller for a given feed item
  ShortsPlaybackInstance getOrCreateController({
    required int index,
    required ShortVideoItem item,
    bool autoPlay = false,
  }) {
    if (_controllers.containsKey(index)) {
      return _controllers[index]!;
    }

    final instance = ShortsPlaybackInstance(
      index: index,
      item: item,
      videoPlayerController: null,
      state: ShortsPlaybackState.initializing,
    );
    _controllers[index] = instance;
    _states[index] = ShortsPlaybackState.initializing;

    _initControllerAsync(index, item, autoPlay);

    return instance;
  }

  Future<void> _initControllerAsync(int index, ShortVideoItem item, bool autoPlay) async {
    if (_isDisposed || _loadingIndices.contains(index)) return;
    _loadingIndices.add(index);

    try {
      String? streamUrl = item.streamUrl;
      if (streamUrl == null || streamUrl.isEmpty) {
        streamUrl = await _shortsService.resolveStreamUrl(item.id, item.category);
      }

      if (_isDisposed) {
        _loadingIndices.remove(index);
        return;
      }

      final url = (streamUrl != null && streamUrl.isNotEmpty)
          ? streamUrl
          : _shortsService.getFallbackStreamUrl(item.category, item.id);

      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      await ctrl.initialize();
      ctrl.setLooping(false);
      ctrl.setVolume(_isMuted ? 0.0 : 1.0);

      if (_isDisposed) {
        ctrl.dispose();
        _loadingIndices.remove(index);
        return;
      }

      final instance = _controllers[index];
      if (instance != null) {
        instance.videoPlayerController = ctrl;
        instance.state = ShortsPlaybackState.ready;
        _states[index] = ShortsPlaybackState.ready;

        // Attach listener for playback completion and buffering
        bool hasEnded = false;
        ctrl.addListener(() {
          if (_isDisposed) return;
          final val = ctrl.value;
          if (val.isInitialized && val.duration > Duration.zero) {
            if (val.position >= val.duration) {
              if (!hasEnded) {
                hasEnded = true;
                _states[index] = ShortsPlaybackState.ended;
                instance.state = ShortsPlaybackState.ended;
                if (index == _activeIndex) {
                  onVideoEnded?.call(index);
                  notifyListeners();
                }
              }
            } else {
              hasEnded = false;
              final newState = val.isPlaying
                  ? (val.isBuffering ? ShortsPlaybackState.buffering : ShortsPlaybackState.playing)
                  : ShortsPlaybackState.paused;
              if (_states[index] != newState) {
                _states[index] = newState;
                instance.state = newState;
                if (index == _activeIndex) notifyListeners();
              }
            }
          }
        });

        if (autoPlay && index == _activeIndex) {
          ctrl.play();
          instance.state = ShortsPlaybackState.playing;
          _states[index] = ShortsPlaybackState.playing;
        }

        notifyListeners();
      } else {
        ctrl.dispose();
      }
    } catch (_) {
      // Automatic fallback recovery to reliable CDN pool
      try {
        final fallbackUrl = _shortsService.getFallbackStreamUrl(item.category, item.id);
        final fallbackCtrl = VideoPlayerController.networkUrl(
          Uri.parse(fallbackUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
        await fallbackCtrl.initialize();
        fallbackCtrl.setLooping(false);
        fallbackCtrl.setVolume(_isMuted ? 0.0 : 1.0);

        if (!_isDisposed && _controllers.containsKey(index)) {
          final instance = _controllers[index]!;
          instance.videoPlayerController = fallbackCtrl;
          instance.state = ShortsPlaybackState.ready;
          _states[index] = ShortsPlaybackState.ready;
          if (autoPlay && index == _activeIndex) {
            fallbackCtrl.play();
            instance.state = ShortsPlaybackState.playing;
            _states[index] = ShortsPlaybackState.playing;
          }
          notifyListeners();
        } else {
          fallbackCtrl.dispose();
        }
      } catch (fallbackErr) {
        if (_controllers.containsKey(index)) {
          _controllers[index]!.state = ShortsPlaybackState.ready;
          _states[index] = ShortsPlaybackState.ready;
        }
      }
    } finally {
      _loadingIndices.remove(index);
    }
  }

  /// Single Active Player Transition on Swipe with Dual Pre-Buffering Pipeline
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

    // 2. Play active video immediately
    if (newIndex >= 0 && newIndex < items.length) {
      final ctrl = getOrCreateController(
        index: newIndex,
        item: items[newIndex],
        autoPlay: true,
      );
      try {
        ctrl.videoPlayerController?.seekTo(Duration.zero);
        ctrl.playVideo();
      } catch (_) {}
    }

    // 3. Pre-warm NEXT 2 videos (+1, +2) for INSTANT zero-buffering playback on swipe
    final nextIndex1 = newIndex + 1;
    if (nextIndex1 < items.length) {
      getOrCreateController(
        index: nextIndex1,
        item: items[nextIndex1],
        autoPlay: false,
      );
    }
    final nextIndex2 = newIndex + 2;
    if (nextIndex2 < items.length) {
      getOrCreateController(
        index: nextIndex2,
        item: items[nextIndex2],
        autoPlay: false,
      );
    }

    // 4. Background Stream URL Pre-resolution for upcoming items
    final prewarmIds = <String>[];
    for (int i = 1; i <= 3; i++) {
      final idx = newIndex + i;
      if (idx < items.length) {
        prewarmIds.add(items[idx].id);
      }
    }
    if (prewarmIds.isNotEmpty) {
      _shortsService.prewarmStreamUrls(prewarmIds);
    }

    // 5. Memory Cleanup: Keep window [newIndex - 1, newIndex, newIndex + 1, newIndex + 2]
    _cleanupDistantControllers(newIndex);

    notifyListeners();
  }

  /// Disposes controllers out of the sliding window to prevent hardware decoder exhaustion
  void _cleanupDistantControllers(int centerIndex) {
    final keysToRemove = _controllers.keys.where((k) => (k - centerIndex).abs() > 2).toList();
    for (final k in keysToRemove) {
      try {
        _controllers[k]?.dispose();
        _controllers.remove(k);
        _states.remove(k);
      } catch (_) {}
    }
  }

  /// Clears all player instances on pull-to-refresh or category switch
  void clearAll() {
    for (final ctrl in _controllers.values) {
      try {
        ctrl.dispose();
      } catch (_) {}
    }
    _controllers.clear();
    _states.clear();
    _loadingIndices.clear();
    _activeIndex = 0;
    notifyListeners();
  }

  /// Toggles play / pause on the active video
  void togglePlayPause() {
    final ctrl = activeController;
    if (ctrl == null) return;

    final vCtrl = ctrl.videoPlayerController;
    if (vCtrl != null && vCtrl.value.isInitialized) {
      if (vCtrl.value.isPlaying) {
        vCtrl.pause();
        _states[_activeIndex] = ShortsPlaybackState.paused;
        ctrl.state = ShortsPlaybackState.paused;
      } else {
        vCtrl.play();
        _states[_activeIndex] = ShortsPlaybackState.playing;
        ctrl.state = ShortsPlaybackState.playing;
      }
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
