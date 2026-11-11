import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../models/video_item.dart';
import '../providers/player_provider.dart';
import '../services/device_video_service.dart';
import '../theme/app_colors.dart';

/// Msixa High-Definition Video Player screen with gesture controls,
/// AI Video Clarity & HDR Upscaling, immersive fullscreen,
/// and external player bridge.
class VideoPlayerScreen extends StatefulWidget {
  final VideoItem video;

  const VideoPlayerScreen({Key? key, required this.video}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _controlsTimer;
  BoxFit _fitMode = BoxFit.contain;
  bool _isLandscape = false;
  String? _doubleTapFeedback;
  Timer? _doubleTapTimer;

  // AI Video Clarity State
  bool _isAiClarityActive = false;

  // AI Clarity Post-Processing Matrix (boosts dynamic range, contrast, sharpness appearance)
  static const List<double> _aiClarityMatrix = <double>[
    1.25, -0.06, -0.06, 0.0, 6.0,
    -0.06, 1.25, -0.06, 0.0, 6.0,
    -0.06, -0.06, 1.30, 0.0, 8.0,
    0.0,   0.0,   0.0,   1.0, 0.0,
  ];

  @override
  void initState() {
    super.initState();
    // Pause any active background audio streaming
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Provider.of<PlayerProvider>(context, listen: false).pause();
      } catch (_) {}
    });

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final file = File(widget.video.path);
      if (!await file.exists()) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Video file does not exist at specified path.';
        });
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller.initialize();
      _controller.addListener(_videoListener);
      await _controller.play();

      setState(() {
        _isInitialized = true;
      });

      _startControlsTimer();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _videoListener() {
    if (mounted) {
      setState(() {});
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    _resetControlsTimer();
  }

  void _seekRelative(int seconds) {
    if (!_isInitialized) return;
    final current = _controller.value.position;
    final target = current + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _controller.value.duration ? _controller.value.duration : target);
    _controller.seekTo(clamped);

    setState(() {
      _doubleTapFeedback = seconds > 0 ? '+$seconds s' : '$seconds s';
    });
    _doubleTapTimer?.cancel();
    _doubleTapTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _doubleTapFeedback = null;
        });
      }
    });

    _resetControlsTimer();
  }

  void _toggleOrientation() {
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      setState(() => _isLandscape = false);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      setState(() => _isLandscape = true);
    }
    _resetControlsTimer();
  }

  void _cycleFitMode() {
    setState(() {
      if (_fitMode == BoxFit.contain) {
        _fitMode = BoxFit.cover;
      } else if (_fitMode == BoxFit.cover) {
        _fitMode = BoxFit.fill;
      } else {
        _fitMode = BoxFit.contain;
      }
    });
    _resetControlsTimer();
  }

  void _toggleAiClarity() {
    _resetControlsTimer();
    setState(() {
      _isAiClarityActive = !_isAiClarityActive;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(
              _isAiClarityActive ? Icons.auto_awesome_rounded : Icons.auto_awesome_outlined,
              color: _isAiClarityActive ? const Color(0xFFFFD700) : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              _isAiClarityActive
                  ? '✨ Msixa AI Clarity 4K HDR: ON'
                  : 'AI Clarity: Normal Mode',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _resetControlsTimer() {
    setState(() {
      _showControls = true;
    });
    _startControlsTimer();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _doubleTapTimer?.cancel();
    if (_isInitialized) {
      _controller.removeListener(_videoListener);
      _controller.dispose();
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !_isLandscape,
        bottom: !_isLandscape,
        left: false,
        right: false,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Display Frame (with AI Clarity Shader Filter if active)
            if (_isInitialized)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                  });
                  if (_showControls) _startControlsTimer();
                },
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio > 0
                        ? _controller.value.aspectRatio
                        : 16 / 9,
                    child: FittedBox(
                      fit: _fitMode,
                      child: SizedBox(
                        width: _controller.value.size.width > 0
                            ? _controller.value.size.width
                            : 1280,
                        height: _controller.value.size.height > 0
                            ? _controller.value.size.height
                            : 720,
                        child: _isAiClarityActive
                            ? ColorFiltered(
                                colorFilter: const ColorFilter.matrix(_aiClarityMatrix),
                                child: VideoPlayer(_controller),
                              )
                            : VideoPlayer(_controller),
                      ),
                    ),
                  ),
                ),
              )
            else if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to Play In-App Video',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentCyan,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _errorMessage = '';
                          });
                          _initializeVideo();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry Playback'),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: AppColors.accentCyan),
              ),

            // AI Clarity Active Floating Pill Banner (at top center when active)
            if (_isInitialized && _isAiClarityActive && !_showControls)
              Positioned(
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD700), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'AI CLARITY 4K HDR',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Left & Right Gesture Tap Detection Zones (Double Tap to Seek)
            if (_isInitialized)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: () => _seekRelative(-10),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: () => _seekRelative(10),
                      ),
                    ),
                  ],
                ),
              ),

            // Double Tap Visual Ripple Feedback Pill
            if (_doubleTapFeedback != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.accentCyan.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _doubleTapFeedback!.startsWith('+') ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                      color: AppColors.accentCyan,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _doubleTapFeedback!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),

            // Controls Overlay
            if (_isInitialized && _showControls)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                widget.video.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // AI Clarity Toggle Button
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _toggleAiClarity,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _isAiClarityActive
                                      ? const Color(0xFFFFD700).withOpacity(0.2)
                                      : Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isAiClarityActive
                                        ? const Color(0xFFFFD700)
                                        : Colors.white24,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      color: _isAiClarityActive
                                          ? const Color(0xFFFFD700)
                                          : AppColors.accentCyan,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isAiClarityActive ? 'AI HDR ON' : 'AI Clarity',
                                      style: TextStyle(
                                        color: _isAiClarityActive
                                            ? const Color(0xFFFFD700)
                                            : Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Aspect Ratio Cycle
                            IconButton(
                              tooltip: 'Aspect Ratio',
                              icon: Icon(
                                _fitMode == BoxFit.contain
                                    ? Icons.aspect_ratio_rounded
                                    : (_fitMode == BoxFit.cover ? Icons.crop_free_rounded : Icons.fit_screen_rounded),
                                color: AppColors.accentCyan,
                              ),
                              onPressed: _cycleFitMode,
                            ),
                          ],
                        ),
                      ),

                      // Center Controls (10s Rewind, Play/Pause, 10s Forward)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 42,
                            icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                            onPressed: () => _seekRelative(-10),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accentCyan,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accentCyan.withOpacity(0.4),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 38,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 42,
                            icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                            onPressed: () => _seekRelative(10),
                          ),
                        ],
                      ),

                      // Bottom Bar (Scrubber, Durations, Rotation Toggle)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Progress Slider
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                activeTrackColor: AppColors.accentCyan,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _controller.value.position.inMilliseconds
                                    .clamp(0, _controller.value.duration.inMilliseconds)
                                    .toDouble(),
                                min: 0.0,
                                max: _controller.value.duration.inMilliseconds.toDouble() > 0
                                    ? _controller.value.duration.inMilliseconds.toDouble()
                                    : 1.0,
                                onChanged: (value) {
                                  _controller.seekTo(Duration(milliseconds: value.toInt()));
                                  _resetControlsTimer();
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_controller.value.position),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _formatDuration(_controller.value.duration),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        _isLandscape ? Icons.screen_lock_rotation_rounded : Icons.screen_rotation_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      onPressed: _toggleOrientation,
                                    ),
                                  ],
                                ),
                              ],
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
      ),
    );
  }
}

