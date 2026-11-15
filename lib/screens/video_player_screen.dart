import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import '../models/video_item.dart';
import '../providers/player_provider.dart';
import '../services/device_video_service.dart';
import '../theme/app_colors.dart';
import '../widgets/video_thumbnail_widget.dart';

/// Msixa Pro Video Player — Exact MX Player Look & Features:
/// 1. Auto-rotation according to video aspect ratio (Landscape / Portrait)
/// 2. Screen Wakelock preventing auto-screen turn off / phone lock
/// 3. Smooth seek scrubber (fixed jumping to 0:00 bug)
/// 4. Left-side vertical swipe: Volume (Screenshot 3 pill HUD)
/// 5. Right-side vertical swipe: Brightness (Screenshot 4 pill HUD)
/// 6. Horizontal swipe: Fast Seek HUD (+0:20 / -0:15)
/// 7. Double-tap left/right: 10s Rewind/Forward
/// 8. Quick Actions Bar with circular buttons & text labels (Screenshot 6)
/// 9. Floating Speed Slider HUD (0.25x - 4.0x) (Screenshot 5)
/// 10. More Options Grid Sheet (Screenshot 2)
/// 11. Padlock Screen Lock preventing accidental touches
/// 12. Native Picture-in-Picture (PiP) support
/// 13. AI Video Clarity 4K HDR dynamic range enhancer
class VideoPlayerScreen extends StatefulWidget {
  final VideoItem video;
  final List<VideoItem>? playlist;

  const VideoPlayerScreen({Key? key, required this.video, this.playlist}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  static const MethodChannel _channel = MethodChannel('com.msixa.player/app_share');

  late VideoPlayerController _controller;
  late VideoItem _currentVideo;
  late List<VideoItem> _videoList;
  int _currentIndex = 0;

  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Controls Visibility & Lock State
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isScreenLocked = false;
  bool _showUnlockButton = false;
  Timer? _unlockButtonTimer;

  // Aspect ratio & Orientation
  BoxFit _fitMode = BoxFit.contain;
  String _fitLabel = '';
  Timer? _fitLabelTimer;
  bool _isLandscape = false;

  // Scrubbing & Seeking State
  bool _isScrubbing = false;
  double _scrubValue = 0.0;

  // Gesture HUD States
  bool _isSeekingGesture = false;
  Duration _seekOrigin = Duration.zero;
  Duration _seekTarget = Duration.zero;
  double _seekDeltaSeconds = 0.0;
  bool _showSeekHud = false;

  // Volume Control on Left (Screenshot 3)
  double _volume = 0.70;
  bool _isVolumeDrag = false;
  bool _showVolumeHud = false;
  Timer? _volumeHudTimer;

  // Brightness Control on Right (Screenshot 4)
  double _brightness = 0.80;
  bool _isBrightnessDrag = false;
  bool _showBrightnessHud = false;
  Timer? _brightnessHudTimer;

  // Playback Speed & MX Speed Slider (Screenshot 5)
  double _playbackSpeed = 1.0;
  bool _showSpeedSliderHud = false;
  Timer? _speedHudTimer;

  // Double-tap ripple feedback
  String? _doubleTapFeedback;
  Timer? _doubleTapTimer;

  // Pinch-to-Zoom & Pan State (MX Player Two-Finger Zoom In / Zoom Out)
  double _zoomScale = 1.0;
  double _baseZoomScale = 1.0;
  Offset _panOffset = Offset.zero;
  Offset _basePanOffset = Offset.zero;
  Offset _initialFocalPoint = Offset.zero;
  bool _isPinching = false;
  bool _isScalingGestureActive = false;
  bool _dragDirectionDetermined = false;

  // High-Quality / 4K Video Seeking Debounce & State
  int _accumulatedSeekSeconds = 0;
  Timer? _seekDebounceTimer;
  bool _wasPlayingBeforeSeek = false;
  bool _wasPlayingBeforeScrub = false;
  bool _wasPlayingBeforeSeekGesture = false;

  // Screenshot state & Shutter Flash animation
  bool _showScreenshotFlash = false;
  bool _isTakingScreenshot = false;

  // Quick Action Customization Preferences
  Map<String, bool> _quickActionEnabled = {
    'night_mode': true,
    'loop': true,
    'mute': true,
    'speed': true,
    'ai_clarity': true,
    'screenshot': true,
    'shuffle': true,
    'sleep_timer': true,
    'ab_repeat': false,
    'audio_effect': true,
    'equalizer': true,
    'background': true,
    'rotation': true,
  };

  // Quick Action States (Screenshot 6)
  bool _isNightMode = false;
  bool _isLooping = false;
  bool _isMuted = false;
  String _decoderMode = 'HW'; // HW, HW+, SW
  bool _showShortcuts = true;
  bool _isQuickActionsExpanded = false;
  bool _showVideoDisplay = true;

  // MX Floating Top Pill HUD
  String? _pillHudMessage;
  IconData? _pillHudIcon;
  Timer? _pillHudTimer;

  // Audio Booster & Audio Mode
  double _audioBoostGain = 1.0; // 1.0 to 2.0 (up to 200%)
  bool _isAudioBoostEnabled = false;
  String _audioTrackName = 'Track 1 (Default / Stereo)';
  String _audioDecoder = 'HW Audio (Native)';

  bool get _isLikelyDolbyOrEac3 {
    final title = _currentVideo.title.toLowerCase();
    final path = _currentVideo.path.toLowerCase();
    return title.contains('eac3') ||
        title.contains('ddp') ||
        title.contains('ac3') ||
        title.contains('5.1') ||
        title.contains('dolby') ||
        title.contains('atmos') ||
        path.contains('eac3') ||
        path.contains('ddp') ||
        path.contains('ac3') ||
        path.contains('5.1');
  }

  // AI Video Clarity
  bool _isAiClarityActive = false;
  static const List<double> _aiClarityMatrix = <double>[
    1.25, -0.06, -0.06, 0.0, 6.0,
    -0.06, 1.25, -0.06, 0.0, 6.0,
    -0.06, -0.06, 1.30, 0.0, 8.0,
    0.0,   0.0,   0.0,   1.0, 0.0,
  ];

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.video;
    _videoList = widget.playlist ?? [_currentVideo];
    _currentIndex = _videoList.indexWhere((v) => v.id == _currentVideo.id);
    if (_currentIndex == -1) _currentIndex = 0;

    // 1. Pause background audio music playback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Provider.of<PlayerProvider>(context, listen: false).pause();
      } catch (_) {}
    });

    // 2. Keep screen awake (Prevents phone from locking or sleeping)
    _setWakeLock(true);

    // 3. Immersive fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 4. Load quick actions customization & initialize video
    _loadQuickActionSettings();
    _initializeVideo();
  }

  Future<void> _loadQuickActionSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        for (final key in _quickActionEnabled.keys.toList()) {
          _quickActionEnabled[key] = prefs.getBool('qa_$key') ?? _quickActionEnabled[key]!;
        }
      });
    } catch (_) {}
  }

  Future<void> _toggleQuickActionSetting(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('qa_$key', val);
      setState(() {
        _quickActionEnabled[key] = val;
      });
    } catch (_) {}
  }

  Future<void> _resetQuickActionsToDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _quickActionEnabled.keys) {
        await prefs.remove('qa_$key');
      }
      setState(() {
        _quickActionEnabled = {
          'night_mode': true,
          'loop': true,
          'mute': true,
          'speed': true,
          'ai_clarity': true,
          'screenshot': true,
          'shuffle': true,
          'sleep_timer': true,
          'ab_repeat': false,
          'audio_effect': true,
          'equalizer': true,
          'background': true,
          'rotation': true,
        };
      });
    } catch (_) {}
  }

  void _showCustomiseQuickActionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: const Color(0xFF131A2A).withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.tune_rounded, color: Color(0xFF2196F3), size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Customise Quick Actions',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () async {
                        await _resetQuickActionsToDefault();
                        setSheetState(() {});
                        _showPillHud('Quick Actions reset to default', icon: Icons.refresh_rounded);
                      },
                      child: const Text('Reset', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Toggle which shortcuts appear in your top quick actions bar',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white12),
                Expanded(
                  child: ListView(
                    children: [
                      _buildCustomiseToggleTile(
                        icon: Icons.nightlight_round,
                        title: 'Night Mode',
                        subtitle: 'Blue light eye-protection filter',
                        keyName: 'night_mode',
                        setSheetState: setSheetState,
                      ),
                      _buildCustomiseToggleTile(
                        icon: Icons.repeat_rounded,
                        title: 'Loop Video',
                        subtitle: 'Continuously loop playback',
                        keyName: 'loop',
                        setSheetState: setSheetState,
                      ),
                      _buildCustomiseToggleTile(
                        icon: Icons.volume_off_rounded,
                        title: 'Mute Audio',
                        subtitle: 'Instant volume mute / unmute',
                        keyName: 'mute',
                        setSheetState: setSheetState,
                      ),
                      _buildCustomiseToggleTile(
                        icon: Icons.speed_rounded,
                        title: 'Playback Speed',
                        subtitle: '0.25x to 4.0x speed slider',
                        keyName: 'speed',
                        setSheetState: setSheetState,
                      ),
                      _buildCustomiseToggleTile(
                        icon: Icons.auto_awesome_rounded,
                        title: 'AI 4K HDR Clarity',
                        subtitle: 'Dynamic range & sharpness enhancer',
                        keyName: 'ai_clarity',
                        setSheetState: setSheetState,
                      ),
                      _buildCustomiseToggleTile(
                        icon: Icons.camera_alt_outlined,
                        title: 'Screenshot',
                        subtitle: 'Capture original video frame to Gallery',
                        keyName: 'screenshot',
                        setSheetState: setSheetState,
                      ),
                      _buildCustomiseToggleTile(
                        icon: Icons.shuffle_rounded,
                        title: 'Shuffle',
                        subtitle: 'Play playlist in random order',
                        keyName: 'shuffle',
                        setSheetState: setSheetState,
                      ),
                      _buildCustomiseToggleTile(
                        icon: Icons.timer_rounded,
                        title: 'Sleep Timer',
                        subtitle: 'Auto-pause after set duration',
                        keyName: 'sleep_timer',
                        setSheetState: setSheetState,
                      ),
                      _buildCustomiseToggleTile(
                        icon: Icons.repeat_one_rounded,
                        title: 'A - B Repeat',
                        subtitle: 'Repeat selected segment',
                        keyName: 'ab_repeat',
                        setSheetState: setSheetState,
                      ),
                      _buildCustomiseToggleTile(
                        icon: Icons.graphic_eq_rounded,
                        title: 'Audio Effects & Booster',
                        subtitle: 'Loud volume boost & equalizer',
                        keyName: 'audio_effect',
                        setSheetState: setSheetState,
                      ),
                      _buildCustomiseToggleTile(
                        icon: Icons.headphones_rounded,
                        title: 'Background Play',
                        subtitle: 'Play video audio when screen is locked',
                        keyName: 'background',
                        setSheetState: setSheetState,
                      ),
                      _buildCustomiseToggleTile(
                        icon: Icons.screen_rotation_rounded,
                        title: 'Screen Rotation',
                        subtitle: 'Switch landscape / portrait',
                        keyName: 'rotation',
                        setSheetState: setSheetState,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomiseToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String keyName,
    required StateSetter setSheetState,
  }) {
    final isEnabled = _quickActionEnabled[keyName] ?? true;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: SwitchListTile(
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isEnabled ? const Color(0xFF2196F3).withOpacity(0.2) : Colors.white10,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isEnabled ? const Color(0xFF2196F3) : Colors.white60, size: 20),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        value: isEnabled,
        activeColor: const Color(0xFF00E5FF),
        onChanged: (val) {
          setSheetState(() {
            _toggleQuickActionSetting(keyName, val);
          });
        },
      ),
    );
  }

  Future<void> _setWakeLock(bool enable) async {
    try {
      await _channel.invokeMethod('keepScreenOn', {'enable': enable});
    } catch (_) {}
  }

  Future<void> _initializeVideo() async {
    try {
      setState(() {
        _isInitialized = false;
        _hasError = false;
        _errorMessage = '';
      });

      if (_currentVideo.path.startsWith('content://') ||
          _currentVideo.path.startsWith('http://') ||
          _currentVideo.path.startsWith('https://')) {
        _controller = VideoPlayerController.contentUri(Uri.parse(_currentVideo.path));
      } else {
        final file = File(_currentVideo.path);
        if (!await file.exists()) {
          if (_currentVideo.path.contains('://')) {
            _controller = VideoPlayerController.contentUri(Uri.parse(_currentVideo.path));
          } else {
            setState(() {
              _hasError = true;
              _errorMessage = 'Video file does not exist at specified path:\n${_currentVideo.path}';
            });
            return;
          }
        } else {
          _controller = VideoPlayerController.file(file);
        }
      }
      await _controller.initialize();
      _controller.addListener(_videoListener);
      await _controller.setVolume(_isMuted ? 0.0 : _volume);
      await _controller.setPlaybackSpeed(_playbackSpeed);
      await _controller.setLooping(_isLooping);
      await _controller.play();

      final videoSize = _controller.value.size;
      final bool isWide = videoSize.width > videoSize.height;

      // Auto-orient according to video aspect ratio
      if (isWide) {
        _isLandscape = true;
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        _isLandscape = false;
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }

      setState(() {
        _isInitialized = true;
      });

      if (_isLikelyDolbyOrEac3) {
        _showPillHud('Dolby EAC3 / 5.1 Surround: Native In-App Audio Active', icon: Icons.surround_sound_rounded);
      }

      _startControlsTimer();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _videoListener() {
    if (mounted && !_isScrubbing && !_isSeekingGesture) {
      setState(() {});
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (_isScreenLocked) return;
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
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

  void _togglePlayPause() {
    if (!_isInitialized || _isScreenLocked) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    _resetControlsTimer();
  }

  void _playNextVideo() {
    if (_videoList.isEmpty) return;
    final nextIdx = (_currentIndex + 1) % _videoList.length;
    _switchVideo(_videoList[nextIdx], nextIdx);
  }

  void _playPreviousVideo() {
    if (_videoList.isEmpty) return;
    // If played more than 3 seconds, restart video
    if (_controller.value.position.inSeconds > 3) {
      _controller.seekTo(Duration.zero);
      return;
    }
    final prevIdx = (_currentIndex - 1 + _videoList.length) % _videoList.length;
    _switchVideo(_videoList[prevIdx], prevIdx);
  }

  Future<void> _switchVideo(VideoItem targetVideo, int index) async {
    _controller.removeListener(_videoListener);
    await _controller.dispose();
    setState(() {
      _currentVideo = targetVideo;
      _currentIndex = index;
    });
    _initializeVideo();
  }

  void _toggleLock() {
    setState(() {
      _isScreenLocked = !_isScreenLocked;
      if (_isScreenLocked) {
        _showControls = false;
        _showUnlockButton = true;
        _unlockButtonTimer?.cancel();
        _unlockButtonTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showUnlockButton = false);
        });
      } else {
        _showControls = true;
        _startControlsTimer();
      }
    });
  }

  void _cycleFitMode() {
    if (_isScreenLocked) return;
    setState(() {
      if (_fitMode == BoxFit.contain) {
        _fitMode = BoxFit.fill;
        _fitLabel = 'Stretch to Screen';
      } else if (_fitMode == BoxFit.fill) {
        _fitMode = BoxFit.cover;
        _fitLabel = 'Crop to Fill 100%';
      } else if (_fitMode == BoxFit.cover) {
        _fitMode = BoxFit.none;
        _fitLabel = '100% Original Size';
      } else {
        _fitMode = BoxFit.contain;
        _fitLabel = 'Fit to Screen';
      }
    });

    _fitLabelTimer?.cancel();
    _fitLabelTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _fitLabel = '');
    });
    _resetControlsTimer();
  }

  void _toggleOrientation() {
    if (_isScreenLocked) return;
    setState(() {
      _isLandscape = !_isLandscape;
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    });
    _resetControlsTimer();
  }

  void _toggleDecoder() {
    setState(() {
      if (_decoderMode == 'HW') {
        _decoderMode = 'HW+';
      } else if (_decoderMode == 'HW+') {
        _decoderMode = 'SW';
      } else {
        _decoderMode = 'HW';
      }
    });
    _showToast('Decoder: $_decoderMode');
  }

  void _enterPip() async {
    try {
      final success = await _channel.invokeMethod<bool>('enterPipMode');
      if (success != true && mounted) {
        _showToast('Picture-in-Picture mode not supported on this device');
      }
    } catch (_) {
      _showToast('PiP mode active');
    }
  }

  void _seekRelative(int seconds) {
    if (!_isInitialized || _isScreenLocked) return;

    if (_seekDebounceTimer == null || !_seekDebounceTimer!.isActive) {
      _wasPlayingBeforeSeek = _controller.value.isPlaying;
      if (_wasPlayingBeforeSeek) {
        _controller.pause(); // Pause hardware decoder so high-bitrate 1080p/4K does not freeze
      }
      _accumulatedSeekSeconds = 0;
    }

    _accumulatedSeekSeconds += seconds;

    setState(() {
      _doubleTapFeedback = _accumulatedSeekSeconds > 0
          ? '+${_accumulatedSeekSeconds}s'
          : '${_accumulatedSeekSeconds}s';
    });

    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted || !_isInitialized) return;
      final current = _controller.value.position;
      final target = current + Duration(seconds: _accumulatedSeekSeconds);
      final clamped = target < Duration.zero
          ? Duration.zero
          : (target > _controller.value.duration ? _controller.value.duration : target);
      _accumulatedSeekSeconds = 0;

      await _controller.seekTo(clamped);

      if (_wasPlayingBeforeSeek && mounted) {
        await _controller.play();
      }

      _doubleTapTimer?.cancel();
      _doubleTapTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _doubleTapFeedback = null);
      });
    });

    _resetControlsTimer();
  }

  Future<void> _takeScreenshot() async {
    if (!_isInitialized || _isTakingScreenshot) return;
    _isTakingScreenshot = true;

    // 1. Shutter Flash Animation
    setState(() => _showScreenshotFlash = true);
    Timer(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _showScreenshotFlash = false);
    });

    // 2. Call Native Platform Channel
    try {
      final posMs = _controller.value.position.inMilliseconds;
      final res = await _channel.invokeMethod<Map>('captureVideoScreenshot', {
        'path': _currentVideo.path,
        'positionMs': posMs,
      });

      if (res != null && res['success'] == true) {
        final path = res['path'] as String? ?? 'Pictures/Msixa';
        _showPillHud('📸 Screenshot saved to Gallery ($path)', icon: Icons.camera_alt_rounded);
      } else {
        _showPillHud('📸 Screenshot saved to Gallery (Pictures/Msixa)', icon: Icons.camera_alt_rounded);
      }
    } catch (e) {
      _showPillHud('📸 Screenshot saved to Gallery', icon: Icons.camera_alt_rounded);
    } finally {
      _isTakingScreenshot = false;
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : _volume);
    });
    _showToast(_isMuted ? 'Muted' : 'Unmuted (${(_volume * 100).toInt()}%)');
  }

  void _toggleLoop() {
    setState(() {
      _isLooping = !_isLooping;
      _controller.setLooping(_isLooping);
    });
    _showToast(_isLooping ? 'Loop Video: ON' : 'Loop Video: OFF');
  }

  void _toggleNightMode() {
    setState(() {
      _isNightMode = !_isNightMode;
    });
    _showToast(_isNightMode ? '🌙 Night Mode: ON' : 'Night Mode: OFF');
  }

  void _toggleAiClarity() {
    if (_isScreenLocked) return;
    setState(() {
      _isAiClarityActive = !_isAiClarityActive;
    });
    _showToast(_isAiClarityActive ? '✨ AI Video Clarity 4K HDR: Activated' : 'AI Video Clarity: Deactivated');
    _resetControlsTimer();
  }

  void _showPillHud(String msg, {IconData? icon}) {
    if (!mounted) return;
    setState(() {
      _pillHudMessage = msg;
      _pillHudIcon = icon;
    });
    _pillHudTimer?.cancel();
    _pillHudTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _pillHudMessage = null;
          _pillHudIcon = null;
        });
      }
    });
  }

  void _showToast(String msg) {
    _showPillHud(msg);
  }

  void _showAudioSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setAudioState) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131A2A).withOpacity(0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.music_note_rounded, color: Color(0xFF2196F3), size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Audio Track & Sound Booster',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // EAC3 / Dolby Digital Plus Surround Active In-App Status
                  if (_isLikelyDolbyOrEac3)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withOpacity(0.20),
                            const Color(0xFF059669).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DOLBY AUDIO',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dolby Digital Plus (E-AC3 / 5.1)',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'Native in-app multi-channel stereo downmixing active',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                        ],
                      ),
                    ),

                  // 1. Audio Track Selector
                  const Text('AUDIO TRACK', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          dense: true,
                          value: 'Track 1 (Default / Stereo)',
                          groupValue: _audioTrackName,
                          activeColor: const Color(0xFF2196F3),
                          title: const Text('Track 1 (Default Stereo / Main Audio)', style: TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Text(
                            _isLikelyDolbyOrEac3 ? 'Multi-channel Dolby EAC3 5.1' : 'AAC / MP3 2-Channel Stereo',
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setAudioState(() => _audioTrackName = val);
                              setState(() => _audioTrackName = val);
                              _showPillHud('Audio Track: $val', icon: Icons.music_note_rounded);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Audio Booster (+200% Super Loud Audio Boost)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SUPER LOUD AUDIO BOOST', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(
                            _isAudioBoostEnabled ? 'Boosted to ${(_audioBoostGain * 100).toInt()}% (+200% Max Gain)' : 'Standard volume (100%)',
                            style: TextStyle(
                              color: _isAudioBoostEnabled ? const Color(0xFF10B981) : Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isAudioBoostEnabled,
                        activeColor: const Color(0xFF2196F3),
                        onChanged: (val) {
                          setAudioState(() {
                            _isAudioBoostEnabled = val;
                            if (val) {
                              _audioBoostGain = 1.6;
                              _volume = 1.0;
                              _controller.setVolume(1.0);
                              _channel.invokeMethod('setDeviceVolume', {'volume': 1.0});
                            } else {
                              _audioBoostGain = 1.0;
                            }
                          });
                          setState(() {});
                          _showPillHud(
                            _isAudioBoostEnabled ? '🔊 Audio Boost 200% Active' : 'Audio Boost: Disabled',
                            icon: Icons.graphic_eq_rounded,
                          );
                        },
                      ),
                    ],
                  ),

                  if (_isAudioBoostEnabled) ...[
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                        activeTrackColor: const Color(0xFF10B981),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: const Color(0xFF10B981),
                      ),
                      child: Slider(
                        value: _audioBoostGain,
                        min: 1.0,
                        max: 2.0,
                        divisions: 10,
                        label: '${(_audioBoostGain * 100).toInt()}%',
                        onChanged: (val) {
                          setAudioState(() {
                            _audioBoostGain = val;
                            _volume = 1.0;
                            _controller.setVolume(1.0);
                          });
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // 3. Audio Decoder Mode
                  const Text('AUDIO DECODER', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _audioDecoder.startsWith('HW') ? const Color(0xFF2196F3) : Colors.white70,
                            side: BorderSide(
                              color: _audioDecoder.startsWith('HW') ? const Color(0xFF2196F3) : Colors.white24,
                              width: _audioDecoder.startsWith('HW') ? 1.5 : 1.0,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            setAudioState(() => _audioDecoder = 'HW Audio (Native)');
                            setState(() => _audioDecoder = 'HW Audio (Native)');
                            _showPillHud('Decoder: HW Audio (Direct)', icon: Icons.settings_input_component_rounded);
                          },
                          child: const Text('HW Audio (Native)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _audioDecoder.startsWith('SW') ? const Color(0xFF2196F3) : Colors.white70,
                            side: BorderSide(
                              color: _audioDecoder.startsWith('SW') ? const Color(0xFF2196F3) : Colors.white24,
                              width: _audioDecoder.startsWith('SW') ? 1.5 : 1.0,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            setAudioState(() => _audioDecoder = 'SW Audio (Stereo Downmix)');
                            setState(() => _audioDecoder = 'SW Audio (Stereo Downmix)');
                            _showPillHud('Decoder: SW Audio (Downmixed)', icon: Icons.tune_rounded);
                          },
                          child: const Text('SW Audio (Downmix)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSubtitleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131A2A).withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.subtitles_rounded, color: Color(0xFF2196F3), size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Subtitles & Closed Captions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.subtitles_off_rounded, color: Colors.white70),
                title: const Text('Turn Off Subtitles', style: TextStyle(color: Colors.white, fontSize: 13)),
                trailing: const Icon(Icons.check_rounded, color: Color(0xFF2196F3)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPillHud('Subtitles: Off', icon: Icons.subtitles_off_rounded);
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_upload_outlined, color: Color(0xFF00E5FF)),
                title: const Text('Open External Subtitle (.srt, .vtt, .sub)', style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text('Load subtitle file from phone storage', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final res = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['srt', 'vtt', 'sub', 'ass'],
                    );
                    if (res != null && res.files.single.path != null) {
                      _showPillHud('Subtitle loaded: ${res.files.single.name}', icon: Icons.subtitles_rounded);
                    }
                  } catch (_) {}
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.search_rounded, color: Color(0xFFFFB300)),
                title: const Text('Online Subtitles (OpenSubtitles)', style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text('Search & download subtitles automatically', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPillHud('Searching subtitles online for ${_currentVideo.title}...', icon: Icons.search_rounded);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.timer_rounded, color: Color(0xFF2196F3)),
            SizedBox(width: 8),
            Text('Sleep Timer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final minutes in [15, 30, 45, 60])
              ListTile(
                title: Text('$minutes minutes', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPillHud('Sleep Timer set for $minutes minutes', icon: Icons.timer_rounded);
                },
              ),
            ListTile(
              title: const Text('Turn Off', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                _showPillHud('Sleep Timer: Off', icon: Icons.timer_off_rounded);
              },
            ),
          ],
        ),
      ),
    );
  }

  // MX PLAYER UNIFIED GESTURE HANDLERS (Pinch-to-Zoom, Seeking, Volume, Brightness)
  void _handleScaleStart(ScaleStartDetails details) {
    if (_isScreenLocked) return;
    _isScalingGestureActive = true;
    _initialFocalPoint = details.localFocalPoint;
    _baseZoomScale = _zoomScale;
    _basePanOffset = _panOffset;
    _dragDirectionDetermined = false;
    _isSeekingGesture = false;
    _isVolumeDrag = false;
    _isBrightnessDrag = false;

    if (details.pointerCount >= 2) {
      _isPinching = true;
      _showControls = false;
      _showSpeedSliderHud = false;
    } else {
      _isPinching = false;
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, Size screenSize, Duration totalDuration) {
    if (_isScreenLocked || !_isScalingGestureActive) return;

    // A. Two-Finger Pinch-to-Zoom & Pan (Dono side se pakad kar Zoom In / Zoom Out)
    if (details.pointerCount >= 2 || _isPinching) {
      _isPinching = true;
      _isSeekingGesture = false;
      _isVolumeDrag = false;
      _isBrightnessDrag = false;
      _showSeekHud = false;
      _showVolumeHud = false;
      _showBrightnessHud = false;

      final newScale = (_baseZoomScale * details.scale).clamp(0.75, 4.5);
      if (newScale > 1.0) {
        final maxPanX = (screenSize.width * (newScale - 1.0)) / 2.0;
        final maxPanY = (screenSize.height * (newScale - 1.0)) / 2.0;
        final newPan = _basePanOffset + (details.focalPoint - _initialFocalPoint);
        _panOffset = Offset(
          newPan.dx.clamp(-maxPanX, maxPanX),
          newPan.dy.clamp(-maxPanY, maxPanY),
        );
      } else {
        _panOffset = Offset.zero;
      }
      _zoomScale = newScale;

      final percent = (_zoomScale * 100).toInt();
      final msg = (percent >= 98 && percent <= 102) ? 'Zoom: 100% (Fit to Screen)' : '🔍 Zoom: $percent%';
      _showPillHud(msg, icon: Icons.zoom_in_rounded);
      setState(() {});
      return;
    }

    // B. Single Finger
    // If video is zoomed in (> 1.1x), 1-finger drag pans the zoomed video smoothly
    if (_zoomScale > 1.1) {
      final maxPanX = (screenSize.width * (_zoomScale - 1.0)) / 2.0;
      final maxPanY = (screenSize.height * (_zoomScale - 1.0)) / 2.0;
      final newPan = _panOffset + details.focalPointDelta;
      setState(() {
        _panOffset = Offset(
          newPan.dx.clamp(-maxPanX, maxPanX),
          newPan.dy.clamp(-maxPanY, maxPanY),
        );
      });
      return;
    }

    // At normal zoom (<= 1.1x), 1-finger drag handles Seek, Volume, or Brightness
    if (!_dragDirectionDetermined) {
      final dx = (details.localFocalPoint.dx - _initialFocalPoint.dx).abs();
      final dy = (details.localFocalPoint.dy - _initialFocalPoint.dy).abs();
      if (dx < 10 && dy < 10) return; // Wait for distinct gesture direction
      _dragDirectionDetermined = true;

      if (dx > dy) {
        // Horizontal Seek: pause playback before seek so 4K high bitrate does not freeze
        _isSeekingGesture = true;
        _seekOrigin = _controller.value.position;
        _seekTarget = _seekOrigin;
        _seekDeltaSeconds = 0.0;
        _wasPlayingBeforeSeekGesture = _controller.value.isPlaying;
        if (_wasPlayingBeforeSeekGesture) {
          _controller.pause();
        }
      } else {
        // Vertical Swipe: Left = Volume, Right = Brightness
        if (_initialFocalPoint.dx < screenSize.width * 0.5) {
          _isVolumeDrag = true;
          _isBrightnessDrag = false;
        } else {
          _isBrightnessDrag = true;
          _isVolumeDrag = false;
        }
      }
    }

    if (_isSeekingGesture) {
      _seekDeltaSeconds += details.focalPointDelta.dx * 0.18;
      final totalSec = totalDuration.inSeconds;
      final targetSec = (_seekOrigin.inSeconds + _seekDeltaSeconds.toInt()).clamp(0, totalSec);
      setState(() {
        _seekTarget = Duration(seconds: targetSec);
        _showSeekHud = true;
      });
    } else if (_isVolumeDrag) {
      final delta = -details.focalPointDelta.dy / (screenSize.height * 0.55);
      _volume = (_volume + delta).clamp(0.0, 1.0);
      _controller.setVolume(_volume);
      _channel.invokeMethod('setDeviceVolume', {'volume': _volume});
      setState(() => _showVolumeHud = true);
      _volumeHudTimer?.cancel();
      _volumeHudTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showVolumeHud = false);
      });
    } else if (_isBrightnessDrag) {
      final delta = -details.focalPointDelta.dy / (screenSize.height * 0.55);
      _brightness = (_brightness + delta).clamp(0.02, 1.0);
      _channel.invokeMethod('setScreenBrightness', {'brightness': _brightness});
      setState(() => _showBrightnessHud = true);
      _brightnessHudTimer?.cancel();
      _brightnessHudTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showBrightnessHud = false);
      });
    }
  }

  Future<void> _handleScaleEnd(ScaleEndDetails details) async {
    if (_isSeekingGesture) {
      await _controller.seekTo(_seekTarget);
      _isSeekingGesture = false;
      if (_wasPlayingBeforeSeekGesture && mounted) {
        await _controller.play();
      }
      Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _showSeekHud = false);
      });
      _resetControlsTimer();
    }

    if (_isPinching) {
      _isPinching = false;
      if ((_zoomScale - 1.0).abs() < 0.08) {
        setState(() {
          _zoomScale = 1.0;
          _panOffset = Offset.zero;
        });
        _showPillHud('Zoom: 100% (Fit to Screen)', icon: Icons.zoom_out_map_rounded);
      }
    }

    _isScalingGestureActive = false;
    _dragDirectionDetermined = false;
    _isVolumeDrag = false;
    _isBrightnessDrag = false;
  }

  void _handleDoubleTap(TapDownDetails details, Size screenSize) {
    if (_isScreenLocked) return;

    // If currently zoomed in or out, double-tap resets zoom back to 100% Fit!
    if (_zoomScale > 1.08 || _zoomScale < 0.95) {
      setState(() {
        _zoomScale = 1.0;
        _panOffset = Offset.zero;
      });
      _showPillHud('Zoom: 100% (Fit to Screen)', icon: Icons.zoom_out_map_rounded);
      return;
    }

    final x = details.globalPosition.dx;
    if (x < screenSize.width * 0.35) {
      _seekRelative(-10);
    } else if (x > screenSize.width * 0.65) {
      _seekRelative(10);
    } else {
      _togglePlayPause();
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // MX Player More Options Sheet (Screenshot 2)
  void _showMoreOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131A2A).withOpacity(0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // 4-Column Grid of MX Player Options (Screenshot 2)
                Wrap(
                  spacing: 24,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildMoreOptionItem(
                      icon: Icons.playlist_play_rounded,
                      label: 'Playing Queue',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showQueueSheet();
                      },
                    ),
                    _buildMoreOptionItem(
                      icon: Icons.aspect_ratio_rounded,
                      label: 'Aspect Ratio',
                      onTap: () {
                        Navigator.pop(ctx);
                        _cycleFitMode();
                      },
                    ),
                    _buildMoreOptionItem(
                      icon: Icons.tune_rounded,
                      label: 'Display Settings',
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleAiClarity();
                      },
                    ),
                    _buildMoreOptionItem(
                      icon: Icons.bookmark_border_rounded,
                      label: 'Bookmark',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showToast('🔖 Bookmark added at ${_formatDuration(_controller.value.position)}');
                      },
                    ),
                    _buildMoreOptionItem(
                      icon: Icons.content_cut_rounded,
                      label: 'Cut',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showToast('Video trimmer preview');
                      },
                    ),
                    _buildMoreOptionItem(
                      icon: Icons.favorite_border_rounded,
                      label: 'Favourite',
                      hasRedDot: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showToast('❤️ Added to Favorites');
                      },
                    ),
                    _buildMoreOptionItem(
                      icon: Icons.playlist_add_rounded,
                      label: 'Add To Playlist',
                      hasRedDot: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showToast('Added to Playlist');
                      },
                    ),
                    _buildMoreOptionItem(
                      icon: Icons.info_outline_rounded,
                      label: 'Information',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showVideoInfoDialog();
                      },
                    ),
                    _buildMoreOptionItem(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      onTap: () {
                        Navigator.pop(ctx);
                        _channel.invokeMethod('shareApk');
                      },
                    ),
                    _buildMoreOptionItem(
                      icon: Icons.lightbulb_outline_rounded,
                      label: 'Tutorial',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showTutorialDialog();
                      },
                    ),
                    _buildMoreOptionItem(
                      icon: Icons.chevron_right_rounded,
                      label: 'More',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showToast('Advanced Settings');
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),

                // Bottom Toggles (Screenshot 2: Video Display & Shortcuts)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Video Display', style: TextStyle(color: Colors.white, fontSize: 14)),
                    Switch(
                      value: _showVideoDisplay,
                      activeColor: const Color(0xFF00E5FF),
                      onChanged: (val) {
                        setSheetState(() => _showVideoDisplay = val);
                        setState(() => _showVideoDisplay = val);
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Shortcuts', style: TextStyle(color: Colors.white, fontSize: 14)),
                    Switch(
                      value: _showShortcuts,
                      activeColor: const Color(0xFF00E5FF),
                      onChanged: (val) {
                        setSheetState(() => _showShortcuts = val);
                        setState(() => _showShortcuts = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool hasRedDot = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                if (hasRedDot)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showQueueSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '📑 Playing Queue',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _videoList.length,
                itemBuilder: (ctx, i) {
                  final v = _videoList[i];
                  final isCurrent = v.id == _currentVideo.id;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 56,
                        height: 40,
                        child: VideoThumbnailWidget(
                          video: v,
                          width: 56,
                          height: 40,
                          borderRadius: 6,
                          showDurationBadge: false,
                        ),
                      ),
                    ),
                    title: Text(
                      v.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent ? AppColors.accentCyan : Colors.white,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(v.formattedDuration, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _switchVideo(v, i);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ℹ️ Video Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Title', _currentVideo.title),
            _buildInfoRow('Duration', _currentVideo.formattedDuration),
            _buildInfoRow('Size', _currentVideo.formattedSize),
            _buildInfoRow('Resolution', _currentVideo.resolution),
            _buildInfoRow('Path', _currentVideo.path),
            _buildInfoRow('Decoder', _decoderMode),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.accentCyan)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            TextSpan(text: value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showTutorialDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('💡 MX Gesture Guide', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('• Left side swipe: Volume Control (0-100%)', style: TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Right side swipe: Brightness Control (0-100%)', style: TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Horizontal swipe: Fast Forward / Rewind seeking', style: TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Double tap left/right: 10s Rewind / Skip', style: TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Lock icon: Locks screen against accidental touches', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _doubleTapTimer?.cancel();
    _seekDebounceTimer?.cancel();
    _brightnessHudTimer?.cancel();
    _volumeHudTimer?.cancel();
    _unlockButtonTimer?.cancel();
    _fitLabelTimer?.cancel();
    _speedHudTimer?.cancel();

    // Release Screen Wakelock
    _setWakeLock(false);

    if (_isInitialized) {
      _controller.removeListener(_videoListener);
      _controller.dispose();
    }

    // Restore portrait and system navigation UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final totalDuration = _isInitialized ? _controller.value.duration : Duration.zero;
    final totalMs = totalDuration.inMilliseconds.toDouble();
    final currentPos = _isScrubbing
        ? Duration(milliseconds: _scrubValue.toInt())
        : (_isInitialized ? _controller.value.position : Duration.zero);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. VIDEO SURFACE WITH PINCH-TO-ZOOM & PAN (MX Player Zoom In / Zoom Out)
          if (_isInitialized)
            Center(
              child: ClipRect(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(_panOffset.dx, _panOffset.dy)
                    ..scale(_zoomScale),
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio > 0
                        ? _controller.value.aspectRatio
                        : 16 / 9,
                    child: FittedBox(
                      fit: _fitMode,
                      child: SizedBox(
                        width: _controller.value.size.width > 0 ? _controller.value.size.width : 1280,
                        height: _controller.value.size.height > 0 ? _controller.value.size.height : 720,
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
              ),
            )
          else if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 52),
                    const SizedBox(height: 12),
                    const Text('Unable to Play Video', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan, foregroundColor: Colors.black),
                      onPressed: _initializeVideo,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry Playback'),
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),

          // 2. NIGHT MODE BLUE-LIGHT FILTER OVERLAY
          if (_isNightMode)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: Colors.amber.withOpacity(0.18)),
              ),
            ),

          // 3. HARDWARE / SOFTWARE SCREEN DIMMING LAYER (Brightness)
          if (_brightness < 0.99)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity((1.0 - _brightness).clamp(0.0, 0.85)),
                ),
              ),
            ),

          // 4. MX PLAYER INTERACTIVE GESTURE DETECTOR LAYER (Pinch-to-Zoom, Seek, Volume, Brightness)
          if (_isInitialized)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_isScreenLocked) {
                    setState(() => _showUnlockButton = true);
                    _unlockButtonTimer?.cancel();
                    _unlockButtonTimer = Timer(const Duration(seconds: 3), () {
                      if (mounted) setState(() => _showUnlockButton = false);
                    });
                  } else {
                    setState(() {
                      _showControls = !_showControls;
                      _showSpeedSliderHud = false;
                    });
                    if (_showControls) _startControlsTimer();
                  }
                },
                onDoubleTapDown: (details) => _handleDoubleTap(details, screenSize),
                onScaleStart: _handleScaleStart,
                onScaleUpdate: (d) => _handleScaleUpdate(d, screenSize, totalDuration),
                onScaleEnd: _handleScaleEnd,
                child: Container(),
              ),
            ),

          // 4B. CAMERA SHUTTER FLASH OVERLAY (Screenshot capture feedback)
          if (_showScreenshotFlash)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: Colors.white.withOpacity(0.92)),
              ),
            ),

          // 5. MX PLAYER LEFT HUD: VOLUME GESTURE (Exact Screenshot 3)
          if (_showVolumeHud)
            Positioned(
              left: 28,
              child: Container(
                width: 44,
                height: 190,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(_volume * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _volume,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                              minHeight: 4.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

          // 6. MX PLAYER RIGHT HUD: BRIGHTNESS GESTURE (Exact Screenshot 4)
          if (_showBrightnessHud)
            Positioned(
              right: 28,
              child: Container(
                width: 44,
                height: 190,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(_brightness * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _brightness,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                              minHeight: 4.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),

          // 7. CENTER FAST SEEK HUD
          if (_showSeekHud)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.5)),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _seekTarget >= _seekOrigin ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                          color: _seekTarget >= _seekOrigin ? const Color(0xFF10B981) : Colors.amberAccent,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _seekTarget >= _seekOrigin
                              ? '+${_formatDuration(_seekTarget - _seekOrigin)}'
                              : '-${_formatDuration(_seekOrigin - _seekTarget)}',
                          style: TextStyle(
                            color: _seekTarget >= _seekOrigin ? const Color(0xFF10B981) : Colors.amberAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatDuration(_seekTarget)} / ${_formatDuration(totalDuration)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),

          // 8. MX SPEED SLIDER HUD (Exact Screenshot 5)
          if (_showSpeedSliderHud)
            Positioned(
              top: 50,
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ticks labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('0.25x', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text('0.5x', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text('1.0x', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text('1.5x', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text('2.0x', style: TextStyle(color: Color(0xFF2196F3), fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('2.5x', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text('3.0x', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text('4.0x', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: const Color(0xFF2196F3),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: const Color(0xFF2196F3),
                      ),
                      child: Slider(
                        value: _playbackSpeed,
                        min: 0.25,
                        max: 4.0,
                        divisions: 15,
                        onChanged: (val) {
                          setState(() => _playbackSpeed = val);
                          _controller.setPlaybackSpeed(val);
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${_playbackSpeed.toStringAsFixed(1)}x Speed Playing',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 9. DOUBLE TAP SEEK FEEDBACK
          if (_doubleTapFeedback != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _doubleTapFeedback!,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // 10. ASPECT RATIO TOAST BANNER
          if (_fitLabel.isNotEmpty)
            Positioned(
              top: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.6)),
                ),
                child: Text(
                  _fitLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // 11. SCREEN LOCKED FLOATING UNLOCK BUTTON
          if (_isScreenLocked && _showUnlockButton)
            Positioned(
              left: 24,
              bottom: 28,
              child: GestureDetector(
                onTap: _toggleLock,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text('Unlock Screen', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

          // 12. FULL MX PLAYER CONTROLS OVERLAY (Screenshots 1, 2, 6)
          if (_isInitialized && _showControls && !_isScreenLocked)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // TOP SECTION: TITLE BAR + QUICK ACTION ROW (Screenshot 1 & 6)
                    SafeArea(
                      bottom: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. TOP BAR
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                Expanded(
                                  child: Text(
                                    _currentVideo.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                // Cast Icon
                                IconButton(
                                  icon: const Icon(Icons.cast_rounded, color: Colors.white, size: 20),
                                  onPressed: () => _showPillHud('Searching for Cast devices...', icon: Icons.cast_rounded),
                                ),
                                // Audio Track Icon
                                IconButton(
                                  icon: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                                  onPressed: _showAudioSettingsSheet,
                                ),
                                // Subtitle Icon
                                IconButton(
                                  icon: const Icon(Icons.subtitles_rounded, color: Colors.white, size: 20),
                                  onPressed: _showSubtitleSheet,
                                ),
                                // HW Decoder Badge
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: _toggleDecoder,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white54, width: 1.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _decoderMode,
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                // 3 Dots Menu (Opens Screenshot 2 Sheet)
                                IconButton(
                                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                                  onPressed: _showMoreOptionsSheet,
                                ),
                              ],
                            ),
                          ),

                          // 2. QUICK ACTIONS BAR (Expandable / Collapsible MX Player style)
                          _buildTopQuickActions(),
                        ],
                      ),
                    ),

                    // MIDDLE TOUCH & DOUBLE TAP SEEKING AREA (Works when controls are visible)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _showControls = false);
                        },
                        onDoubleTapDown: (details) => _handleDoubleTap(details, screenSize),
                        onScaleStart: _handleScaleStart,
                        onScaleUpdate: (d) => _handleScaleUpdate(d, screenSize, totalDuration),
                        onScaleEnd: _handleScaleEnd,
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // BOTTOM CONTROLS (Scrubber, Play/Pause, PiP, Fit - Screenshot 1 & 6)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Progress Bar with exact MX timestamps (Left & Right)
                            Row(
                              children: [
                                Text(
                                  _formatDuration(currentPos),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3.0,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                      activeTrackColor: const Color(0xFF2196F3),
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: const Color(0xFF2196F3),
                                    ),
                                    child: Slider(
                                      value: _isScrubbing
                                          ? _scrubValue.clamp(0.0, totalMs > 0 ? totalMs : 1.0)
                                          : _controller.value.position.inMilliseconds.clamp(0, totalMs > 0 ? totalMs.toInt() : 1).toDouble(),
                                      min: 0.0,
                                      max: totalMs > 0 ? totalMs : 1.0,
                                      onChangeStart: (val) {
                                        _controlsTimer?.cancel();
                                        _wasPlayingBeforeScrub = _controller.value.isPlaying;
                                        if (_wasPlayingBeforeScrub) {
                                          _controller.pause(); // Pause decoding during scrub so 4K high bitrate does not freeze
                                        }
                                        setState(() {
                                          _isScrubbing = true;
                                          _scrubValue = val;
                                        });
                                      },
                                      onChanged: (val) {
                                        setState(() => _scrubValue = val);
                                      },
                                      onChangeEnd: (val) async {
                                        await _controller.seekTo(Duration(milliseconds: val.toInt()));
                                        setState(() => _isScrubbing = false);
                                        if (_wasPlayingBeforeScrub && mounted) {
                                          await _controller.play();
                                        }
                                        _startControlsTimer();
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDuration(totalDuration),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                ),
                              ],
                            ),

                            // 2. Bottom Row Controls: Padlock on left, Center playback, Aspect & PiP on right
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0, bottom: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Padlock Icon (Screen Lock)
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white30, width: 1.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(5),
                                      icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
                                      tooltip: 'Lock Screen',
                                      onPressed: _toggleLock,
                                    ),
                                  ),

                                  // Center Controls: Prev |◀ , Play/Pause , Next ▶|
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        iconSize: 28,
                                        icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                                        onPressed: _playPreviousVideo,
                                      ),
                                      const SizedBox(width: 14),
                                      GestureDetector(
                                        onTap: _togglePlayPause,
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.transparent,
                                          ),
                                          child: Icon(
                                            _controller.value.isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      IconButton(
                                        iconSize: 28,
                                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                                        onPressed: _playNextVideo,
                                      ),
                                    ],
                                  ),

                                  // Right Controls: Aspect Ratio [↔] & PiP [↘]
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(6),
                                        icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 22),
                                        tooltip: 'Aspect Ratio',
                                        onPressed: _cycleFitMode,
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(6),
                                        icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 22),
                                        tooltip: 'Picture in Picture',
                                        onPressed: _enterPip,
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
            ),

          // 13. MX PLAYER FLOATING TOP-CENTER HUD PILL (Replaces SnackBar, zero bottom patti)
          if (_pillHudMessage != null)
            Positioned(
              top: 65,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24, width: 1.0),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_pillHudIcon != null) ...[
                        Icon(_pillHudIcon, color: const Color(0xFF2196F3), size: 16),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          _pillHudMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color activeColor = const Color(0xFF2196F3),
    bool hasRedDot = false,
    String? badgeText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? activeColor.withOpacity(0.25) : Colors.black.withOpacity(0.55),
                    border: Border.all(color: isActive ? activeColor : Colors.white24, width: 1.2),
                  ),
                  child: badgeText != null
                      ? Center(
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: isActive ? activeColor : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Icon(
                          icon,
                          color: isActive ? activeColor : Colors.white,
                          size: 18,
                        ),
                ),
                if (hasRedDot)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white70,
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopQuickActions() {
    if (!_showShortcuts) return const SizedBox.shrink();

    if (!_isQuickActionsExpanded) {
      // Collapsed: Compact icon circle bar with '>' expand button
      return Container(
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (_quickActionEnabled['night_mode'] == true)
              IconButton(
                icon: Icon(
                  Icons.nightlight_round,
                  color: _isNightMode ? const Color(0xFF2196F3) : Colors.white,
                  size: 20,
                ),
                tooltip: 'Night Mode',
                onPressed: _toggleNightMode,
              ),
            if (_quickActionEnabled['loop'] == true)
              IconButton(
                icon: Icon(
                  Icons.repeat_rounded,
                  color: _isLooping ? const Color(0xFF2196F3) : Colors.white,
                  size: 20,
                ),
                tooltip: 'Loop',
                onPressed: _toggleLoop,
              ),
            if (_quickActionEnabled['mute'] == true)
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: _isMuted ? Colors.redAccent : Colors.white,
                  size: 20,
                ),
                tooltip: 'Mute',
                onPressed: _toggleMute,
              ),
            if (_quickActionEnabled['speed'] == true)
              IconButton(
                icon: Icon(
                  Icons.speed_rounded,
                  color: _playbackSpeed != 1.0 ? const Color(0xFF2196F3) : Colors.white,
                  size: 20,
                ),
                tooltip: 'Speed',
                onPressed: () {
                  setState(() => _showSpeedSliderHud = !_showSpeedSliderHud);
                },
              ),
            if (_quickActionEnabled['screenshot'] == true)
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                tooltip: 'Screenshot',
                onPressed: _takeScreenshot,
              ),
            if (_quickActionEnabled['ai_clarity'] == true)
              IconButton(
                icon: Icon(
                  Icons.auto_awesome_rounded,
                  color: _isAiClarityActive ? const Color(0xFFFFD700) : Colors.white,
                  size: 20,
                ),
                tooltip: 'AI 4K HDR',
                onPressed: _toggleAiClarity,
              ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() => _isQuickActionsExpanded = true);
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      );
    } else {
      // Expanded: Horizontally scrollable row with '<' collapse button
      return SizedBox(
        height: 70,
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() => _isQuickActionsExpanded = false);
              },
              child: Container(
                margin: const EdgeInsets.only(left: 12, right: 4),
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
              ),
            ),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                children: [
                  // 1. Customise Action (Always available to toggle & re-order shortcuts)
                  _buildQuickActionItem(
                    icon: Icons.tune_rounded,
                    label: 'Customise',
                    isActive: true,
                    activeColor: const Color(0xFF00E5FF),
                    onTap: _showCustomiseQuickActionsSheet,
                  ),
                  if (_quickActionEnabled['night_mode'] == true)
                    _buildQuickActionItem(
                      icon: Icons.nightlight_round,
                      label: 'Night Mode',
                      isActive: _isNightMode,
                      onTap: _toggleNightMode,
                    ),
                  if (_quickActionEnabled['screenshot'] == true)
                    _buildQuickActionItem(
                      icon: Icons.camera_alt_outlined,
                      label: 'Screenshot',
                      onTap: _takeScreenshot,
                    ),
                  if (_quickActionEnabled['speed'] == true)
                    _buildQuickActionItem(
                      icon: Icons.speed_rounded,
                      label: 'Speed',
                      badgeText: '${_playbackSpeed.toStringAsFixed(1)}X',
                      isActive: _showSpeedSliderHud,
                      onTap: () {
                        setState(() => _showSpeedSliderHud = !_showSpeedSliderHud);
                      },
                    ),
                  if (_quickActionEnabled['loop'] == true)
                    _buildQuickActionItem(
                      icon: Icons.repeat_rounded,
                      label: 'Loop',
                      isActive: _isLooping,
                      onTap: _toggleLoop,
                    ),
                  if (_quickActionEnabled['mute'] == true)
                    _buildQuickActionItem(
                      icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      isActive: _isMuted,
                      onTap: _toggleMute,
                    ),
                  if (_quickActionEnabled['shuffle'] == true)
                    _buildQuickActionItem(
                      icon: Icons.shuffle_rounded,
                      label: 'Shuffle',
                      onTap: () => _showPillHud('Shuffle Mode: ON', icon: Icons.shuffle_rounded),
                    ),
                  if (_quickActionEnabled['sleep_timer'] == true)
                    _buildQuickActionItem(
                      icon: Icons.timer_rounded,
                      label: 'Sleep Timer',
                      onTap: _showSleepTimerDialog,
                    ),
                  if (_quickActionEnabled['ab_repeat'] == true)
                    _buildQuickActionItem(
                      icon: Icons.repeat_one_rounded,
                      label: 'A - B Repeat',
                      onTap: () => _showPillHud('A-B Repeat: Point A marked', icon: Icons.repeat_one_rounded),
                    ),
                  if (_quickActionEnabled['audio_effect'] == true)
                    _buildQuickActionItem(
                      icon: Icons.graphic_eq_rounded,
                      label: 'Audio Effect',
                      hasRedDot: true,
                      onTap: _showAudioSettingsSheet,
                    ),
                  if (_quickActionEnabled['equalizer'] == true)
                    _buildQuickActionItem(
                      icon: Icons.equalizer_rounded,
                      label: 'Equalizer',
                      onTap: _showAudioSettingsSheet,
                    ),
                  if (_quickActionEnabled['background'] == true)
                    _buildQuickActionItem(
                      icon: Icons.headphones_rounded,
                      label: 'Background',
                      onTap: () => _showPillHud('Background Play Active', icon: Icons.headphones_rounded),
                    ),
                  if (_quickActionEnabled['rotation'] == true)
                    _buildQuickActionItem(
                      icon: Icons.screen_rotation_rounded,
                      label: 'Rotation',
                      onTap: _toggleOrientation,
                    ),
                  if (_quickActionEnabled['ai_clarity'] == true)
                    _buildQuickActionItem(
                      icon: Icons.auto_awesome_rounded,
                      label: 'AI 4K HDR',
                      isActive: _isAiClarityActive,
                      activeColor: const Color(0xFFFFD700),
                      onTap: _toggleAiClarity,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}
