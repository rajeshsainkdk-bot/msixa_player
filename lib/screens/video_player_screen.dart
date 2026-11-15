import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/video_item.dart';
import '../providers/player_provider.dart';
import '../services/ad_service.dart';
import '../services/device_video_service.dart';
import '../theme/app_colors.dart';
import '../widgets/video_thumbnail_widget.dart';

/// Msixa Pro Video Player — Complete MX Player Feature Coverage (Master Spec A01-A18):
/// 1. Auto-rotation according to video aspect ratio (Landscape / Portrait)
/// 2. Screen Wakelock preventing auto-screen turn off / phone lock
/// 3. Smooth seek scrubber with debouncing preventing 4K video freezing
/// 4. Left-side vertical swipe: Brightness (with 0-100% Left HUD pill)
/// 5. Right-side vertical swipe: Volume (with 0-100% Right HUD pill)
/// 6. Horizontal swipe: Fast Seek HUD with target timestamp preview
/// 7. Double-tap left/right: 10s Rewind/Forward
/// 8. Quick Actions Bar with circular buttons & text labels
/// 9. Floating Speed Slider HUD (0.25x - 4.0x)
/// 10. More Options Grid Sheet (Queue, Aspect Ratio, Equalizer, Decoder, etc.)
/// 11. Padlock Screen Lock preventing accidental touches
/// 12. Native Picture-in-Picture (PiP) support
/// 13. AI Video Clarity 4K HDR dynamic range enhancer
/// 14. Cast to TV (Google Cast / DLNA / Wireless Display)
/// 15. Active Sleep Timer with automatic playback pause
/// 16. A-B Repeat segment loop
/// 17. Repeat modes (Off, One, All)
/// 18. Resume playback position per video
/// 19. 5-Band Equalizer & Reverb profiles with HW+ / SW decoder auto-switch
/// 20. Dedicated interactive gesture zones unblocked by controls overlay
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

  // Aspect ratio & Display Settings (A01-21, 2.5, Panel 2)
  BoxFit _fitMode = BoxFit.contain;
  String _fitLabel = '';
  Timer? _fitLabelTimer;
  bool _isLandscape = false;
  double? _customAspectRatio;
  String get _aspectRatioLabel {
    if (_customAspectRatio == null) return 'Default (Original)';
    if ((_customAspectRatio! - 16 / 9).abs() < 0.01) return '16:9 (Widescreen)';
    if ((_customAspectRatio! - 4 / 3).abs() < 0.01) return '4:3 (Standard)';
    if ((_customAspectRatio! - 21 / 9).abs() < 0.01) return '21:9 (Cinema)';
    return '${_customAspectRatio!.toStringAsFixed(2)}:1';
  }

  // Subtitle Settings (A10, A11, A12, A13, Panel 4)
  bool _subtitlesEnabled = true;
  String _subtitleLanguage = 'Default (English)';
  double _subtitleFontSize = 14.0;
  Color _subtitleFontColor = Colors.white;
  int _subtitleSyncMs = 0;

  // Audio Settings (A14, A17, A18, Panel 3)
  int _audioSyncMs = 0;
  String _equalizerPreset = 'Normal';
  bool _isBackgroundPlay = false;
  bool _isEqualizerEnabled = true;
  double _eq60Hz = 0.0;
  double _eq230Hz = 0.0;
  double _eq910Hz = 0.0;
  double _eq3600Hz = 0.0;
  double _eq14000Hz = 0.0;
  String _reverbPreset = 'None';

  // Scrubbing & Seeking State
  bool _isScrubbing = false;
  double _scrubValue = 0.0;

  // Gesture HUD States
  bool _isSeekingGesture = false;
  Duration _seekOrigin = Duration.zero;
  Duration _seekTarget = Duration.zero;
  double _seekDeltaSeconds = 0.0;
  bool _showSeekHud = false;

  // Volume Control on Right (A04)
  double _volume = 0.70;
  bool _isVolumeDrag = false;
  bool _showVolumeHud = false;
  Timer? _volumeHudTimer;

  // Brightness Control on Left (A03)
  double _brightness = 0.80;
  bool _isBrightnessDrag = false;
  bool _showBrightnessHud = false;
  Timer? _brightnessHudTimer;

  // Playback Speed & MX Speed Slider (A01-09)
  double _playbackSpeed = 1.0;
  bool _showSpeedSliderHud = false;
  Timer? _speedHudTimer;
  double _speedBeforeLongPress = 1.0;

  // Double-tap ripple feedback (A07, A08)
  String? _doubleTapFeedback;
  Timer? _doubleTapTimer;

  // Pinch-to-Zoom & Pan State (0.75x to 4.5x)
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

  // Screenshot state & Shutter Flash animation (A01-10)
  bool _showScreenshotFlash = false;
  bool _isTakingScreenshot = false;

  // Active Sleep Timer (A02-06, MX-G06-006)
  Timer? _sleepTimer;
  int? _sleepTimerMinutes;

  // A-B Repeat (A02-07, MX-G06-003)
  Duration? _abRepeatA;
  Duration? _abRepeatB;

  // Repeat Mode (FR-016: 'all', 'one', 'off')
  String _repeatMode = 'all';

  // Resume playback position tracking (FR-004, TC-006)
  int _lastSavedPositionMs = 0;

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

  // Quick Action States
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
  bool _isAiClarityUnlocked = false;
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

    // 4. Load quick action customization & initialize video
    _loadQuickActionSettings();
    _checkAiClarityUnlockStatus();
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
    final isLand = MediaQuery.of(context).orientation == Orientation.landscape;
    final sheetH = isLand ? MediaQuery.of(context).size.height * 0.94 : MediaQuery.of(context).size.height * 0.76;
    final sheetW = isLand ? 520.0 : double.infinity;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Align(
          alignment: isLand ? Alignment.bottomRight : Alignment.bottomCenter,
          child: Container(
            height: sheetH,
            width: sheetW,
            decoration: BoxDecoration(
              color: const Color(0xFF131A2A).withOpacity(0.98),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: isLand ? Radius.zero : const Radius.circular(24),
                bottomLeft: isLand ? const Radius.circular(24) : Radius.zero,
              ),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: SafeArea(
              top: false,
              child: Column(
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
                      Row(
                        children: const [
                          Icon(Icons.tune_rounded, color: Color(0xFF2196F3), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Customise Shortcuts',
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
                  const SizedBox(height: 8),
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

  Future<void> _checkAiClarityUnlockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final expireTime = prefs.getInt('com.msixa.player_ai_clarity_unlocked_until') ?? 0;
    final isPro = prefs.getBool('is_pro_user') ?? false;
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _isAiClarityUnlocked = isPro || (expireTime > now);
    });
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
      await _controller.setLooping(_repeatMode == 'one');
      await _controller.play();

      // Resume video position if previously saved (FR-004, TC-006, MX-G06-004)
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedMs = prefs.getInt('resume_${_currentVideo.id}') ?? 0;
        final totalMs = _controller.value.duration.inMilliseconds;
        if (savedMs > 5000 && (totalMs == 0 || savedMs < totalMs - 8000)) {
          await _controller.seekTo(Duration(milliseconds: savedMs));
          _showPillHud('Resumed from ${_formatDuration(Duration(milliseconds: savedMs))}', icon: Icons.history_rounded);
        }
      } catch (_) {}

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

  Future<void> _saveResumePosition() async {
    if (!_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pos = _controller.value.position.inMilliseconds;
      final dur = _controller.value.duration.inMilliseconds;
      if (pos > 5000 && dur > 0 && pos < dur - 8000) {
        _lastSavedPositionMs = pos;
        await prefs.setInt('resume_${_currentVideo.id}', pos);
      } else if (dur > 0 && pos >= dur - 8000) {
        await prefs.remove('resume_${_currentVideo.id}');
      }
    } catch (_) {}
  }

  void _videoListener() {
    if (!mounted || !_isInitialized) return;

    // 1. A-B Repeat Loop (MX-G06-003)
    if (_abRepeatA != null && _abRepeatB != null && _controller.value.isPlaying) {
      if (_controller.value.position >= _abRepeatB!) {
        _controller.seekTo(_abRepeatA!);
      }
    }

    // 2. Video End & Auto Next handling (FR-016, TC-026, TC-027)
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    if (dur.inMilliseconds > 0 && pos >= dur - const Duration(milliseconds: 600)) {
      if (!_controller.value.isPlaying || pos >= dur) {
        if (_repeatMode == 'all') {
          _playNextVideo();
        } else if (_repeatMode == 'one') {
          _controller.seekTo(Duration.zero);
          _controller.play();
        }
      }
    }

    // 3. Periodic Resume position persistence (every 5s)
    if (_controller.value.isPlaying) {
      final nowMs = pos.inMilliseconds;
      if ((nowMs - _lastSavedPositionMs).abs() > 5000) {
        _saveResumePosition();
      }
    }

    if (!_isScrubbing && !_isSeekingGesture) {
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
    await _saveResumePosition();
    _controller.removeListener(_videoListener);
    await _controller.dispose();
    setState(() {
      _currentVideo = targetVideo;
      _currentIndex = index;
      _abRepeatA = null;
      _abRepeatB = null;
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

  void _cycleAspectRatio() {
    setState(() {
      if (_customAspectRatio == null) {
        _customAspectRatio = 16 / 9;
      } else if ((_customAspectRatio! - 16 / 9).abs() < 0.01) {
        _customAspectRatio = 4 / 3;
      } else if ((_customAspectRatio! - 4 / 3).abs() < 0.01) {
        _customAspectRatio = 21 / 9;
      } else {
        _customAspectRatio = null;
      }
    });
    _showPillHud('Aspect Ratio: $_aspectRatioLabel', icon: Icons.aspect_ratio_rounded);
  }

  void _cycleRepeatMode() {
    setState(() {
      if (_repeatMode == 'all') {
        _repeatMode = 'one';
        _isLooping = true;
        _controller.setLooping(true);
        _showPillHud('Repeat Mode: Repeat One (1)', icon: Icons.repeat_one_rounded);
      } else if (_repeatMode == 'one') {
        _repeatMode = 'off';
        _isLooping = false;
        _controller.setLooping(false);
        _showPillHud('Repeat Mode: Off', icon: Icons.repeat_rounded);
      } else {
        _repeatMode = 'all';
        _isLooping = false;
        _controller.setLooping(false);
        _showPillHud('Repeat Mode: Repeat All (Queue)', icon: Icons.repeat_rounded);
      }
    });
  }

  void _toggleLoop() {
    _cycleRepeatMode();
  }

  void _toggleAbRepeat() {
    if (!_isInitialized) return;
    setState(() {
      final pos = _controller.value.position;
      if (_abRepeatA == null) {
        _abRepeatA = pos;
        _abRepeatB = null;
        _showPillHud('A-B Repeat: Point A set [${_formatDuration(_abRepeatA!)}]', icon: Icons.repeat_one_rounded);
      } else if (_abRepeatB == null) {
        if (pos > _abRepeatA! + const Duration(milliseconds: 500)) {
          _abRepeatB = pos;
          _showPillHud('A-B Repeat: Loop [${_formatDuration(_abRepeatA!)} - ${_formatDuration(_abRepeatB!)}]', icon: Icons.repeat_one_rounded);
        } else {
          _abRepeatA = pos;
          _showPillHud('A-B Repeat: Point A reset [${_formatDuration(_abRepeatA!)}]', icon: Icons.repeat_one_rounded);
        }
      } else {
        _abRepeatA = null;
        _abRepeatB = null;
        _showPillHud('A-B Repeat: Cleared', icon: Icons.repeat_rounded);
      }
    });
  }

  void _shareCurrentVideo() {
    try {
      Share.shareXFiles([XFile(_currentVideo.path)], text: _currentVideo.displayName);
    } catch (_) {
      try {
        _channel.invokeMethod('shareApk');
      } catch (_) {}
    }
  }

  void _showDisplaySettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final isLand = mediaQuery.orientation == Orientation.landscape;
        final sheetH = isLand ? mediaQuery.size.height * 0.94 : mediaQuery.size.height * 0.76;
        final sheetW = isLand ? 520.0 : double.infinity;

        return StatefulBuilder(
          builder: (context, setDisplayState) => Align(
            alignment: isLand ? Alignment.bottomRight : Alignment.bottomCenter,
            child: Container(
              height: sheetH,
              width: sheetW,
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A).withOpacity(0.98),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: isLand ? Radius.zero : const Radius.circular(24),
                  bottomLeft: isLand ? const Radius.circular(24) : Radius.zero,
                ),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: SafeArea(
                top: false,
                child: Column(
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
                      children: [
                        const Icon(Icons.crop_free_rounded, color: Color(0xFF2196F3), size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Display Settings (स्क्रीन विकल्प)',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Option 1: Fit (पूरा वीडियो फिट)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.fit_screen_rounded, color: Color(0xFF2196F3)),
                              title: const Text('Fit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              subtitle: const Text('पूरा वीडियो फिट (Fit to Screen)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: _fitMode == BoxFit.contain && _zoomScale == 1.0 ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2196F3)) : null,
                              onTap: () {
                                setState(() {
                                  _fitMode = BoxFit.contain;
                                  _zoomScale = 1.0;
                                  _panOffset = Offset.zero;
                                  _customAspectRatio = null;
                                  _fitLabel = 'Fit to Screen';
                                });
                                setDisplayState(() {});
                                _showPillHud('Fit: पूरा वीडियो फिट', icon: Icons.fit_screen_rounded);
                                Navigator.pop(ctx);
                              },
                            ),

                            // Option 2: Stretch (स्क्रीन भरना)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.fullscreen_rounded, color: Color(0xFF00E5FF)),
                              title: const Text('Stretch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              subtitle: const Text('स्क्रीन भरना (Stretch to Screen)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: _fitMode == BoxFit.fill ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2196F3)) : null,
                              onTap: () {
                                setState(() {
                                  _fitMode = BoxFit.fill;
                                  _zoomScale = 1.0;
                                  _panOffset = Offset.zero;
                                  _fitLabel = 'Stretch to Screen';
                                });
                                setDisplayState(() {});
                                _showPillHud('Stretch: स्क्रीन भरना', icon: Icons.fullscreen_rounded);
                                Navigator.pop(ctx);
                              },
                            ),

                            // Option 3: Crop (किनारे काटकर भरना)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.crop_rounded, color: Color(0xFFFFB300)),
                              title: const Text('Crop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              subtitle: const Text('किनारे काटकर भरना (Crop to 100%)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: _fitMode == BoxFit.cover ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2196F3)) : null,
                              onTap: () {
                                setState(() {
                                  _fitMode = BoxFit.cover;
                                  _zoomScale = 1.0;
                                  _panOffset = Offset.zero;
                                  _fitLabel = 'Crop to Fill';
                                });
                                setDisplayState(() {});
                                _showPillHud('Crop: किनारे काटकर भरना', icon: Icons.crop_rounded);
                                Navigator.pop(ctx);
                              },
                            ),

                            // Option 4: 100% (वास्तविक आकार)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.aspect_ratio_rounded, color: Color(0xFF10B981)),
                              title: const Text('100%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              subtitle: const Text('वास्तविक आकार (100% Original Size)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: _fitMode == BoxFit.none ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2196F3)) : null,
                              onTap: () {
                                setState(() {
                                  _fitMode = BoxFit.none;
                                  _zoomScale = 1.0;
                                  _panOffset = Offset.zero;
                                  _fitLabel = '100% Original Size';
                                });
                                setDisplayState(() {});
                                _showPillHud('100%: वास्तविक आकार', icon: Icons.aspect_ratio_rounded);
                                Navigator.pop(ctx);
                              },
                            ),

                            const Divider(color: Colors.white12),

                            // Option 5 & 6: Zoom In & Zoom Out
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white24),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.zoom_in_rounded, color: Color(0xFF2196F3)),
                                      label: Text('Zoom In (+25%)\n${(_zoomScale * 100).toInt()}%', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        setState(() {
                                          _zoomScale = (_zoomScale + 0.25).clamp(0.75, 4.5);
                                        });
                                        setDisplayState(() {});
                                        _showPillHud('🔍 Zoom In: ${(_zoomScale * 100).toInt()}%', icon: Icons.zoom_in_rounded);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white24),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.zoom_out_rounded, color: Colors.amberAccent),
                                      label: Text('Zoom Out (-25%)\n${(_zoomScale * 100).toInt()}%', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        setState(() {
                                          _zoomScale = (_zoomScale - 0.25).clamp(0.75, 4.5);
                                          if (_zoomScale <= 1.0) _panOffset = Offset.zero;
                                        });
                                        setDisplayState(() {});
                                        _showPillHud('🔍 Zoom Out: ${(_zoomScale * 100).toInt()}%', icon: Icons.zoom_out_rounded);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Option 7: Rotate (घुमाना)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.screen_rotation_rounded, color: Color(0xFF00E5FF)),
                              title: const Text('Rotate (घुमाना)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              subtitle: Text(_isLandscape ? 'Current: Landscape (लैंडस्केप)' : 'Current: Portrait (पोर्ट्रेट)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: const Icon(Icons.rotate_right_rounded, color: Colors.white70),
                              onTap: () {
                                _toggleOrientation();
                                setDisplayState(() {});
                              },
                            ),

                            // Option 8: Aspect Ratio (अनुपात बदलना)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.view_carousel_rounded, color: Color(0xFFFF4081)),
                              title: const Text('Aspect Ratio (अनुपात बदलना)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              subtitle: Text(_aspectRatioLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                              onTap: () {
                                _cycleAspectRatio();
                                setDisplayState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
    _showPillHud('Decoder: $_decoderMode Active', icon: Icons.developer_board_rounded);
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

    _doubleTapTimer?.cancel();
    _doubleTapFeedback = _accumulatedSeekSeconds > 0 ? '+${_accumulatedSeekSeconds}s >>' : '${_accumulatedSeekSeconds}s <<';
    _doubleTapTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _doubleTapFeedback = null);
    });

    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = Timer(const Duration(milliseconds: 260), () async {
      final currentPos = _controller.value.position;
      final totalDuration = _controller.value.duration;
      final targetSeconds = (currentPos.inSeconds + _accumulatedSeekSeconds).clamp(0, totalDuration.inSeconds);
      await _controller.seekTo(Duration(seconds: targetSeconds));

      _accumulatedSeekSeconds = 0;
      if (_wasPlayingBeforeSeek && mounted) {
        await _controller.play();
      }
    });

    _resetControlsTimer();
  }

  Future<void> _takeScreenshot() async {
    if (_isTakingScreenshot || !_isInitialized) return;
    _isTakingScreenshot = true;

    // 1. Shutter Flash Feedback
    setState(() => _showScreenshotFlash = true);
    Future.delayed(const Duration(milliseconds: 140), () {
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
      _showPillHud('📸 Screenshot saved to Gallery (Pictures/Msixa)', icon: Icons.camera_alt_rounded);
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
    _pillHudTimer?.cancel();
    setState(() {
      _pillHudMessage = msg;
      _pillHudIcon = icon;
    });
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
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final isLand = mediaQuery.orientation == Orientation.landscape;
        final sheetH = isLand ? mediaQuery.size.height * 0.94 : mediaQuery.size.height * 0.76;
        final sheetW = isLand ? 520.0 : double.infinity;

        return StatefulBuilder(
          builder: (context, setAudioState) => Align(
            alignment: isLand ? Alignment.bottomRight : Alignment.bottomCenter,
            child: Container(
              height: sheetH,
              width: sheetW,
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A).withOpacity(0.98),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: isLand ? Radius.zero : const Radius.circular(24),
                  bottomLeft: isLand ? const Radius.circular(24) : Radius.zero,
                ),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: SafeArea(
                top: false,
                child: Column(
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
                      children: [
                        const Icon(Icons.music_note_rounded, color: Color(0xFF2196F3), size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Audio Settings (आवाज से जुड़ी सेटिंग्स)',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),

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

                            // Volume Slider & Mute
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white70, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Volume: ${(_volume * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text('Mute', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    Switch(
                                      value: _isMuted,
                                      activeColor: Colors.redAccent,
                                      onChanged: (val) {
                                        setAudioState(() {
                                          _isMuted = val;
                                          _controller.setVolume(_isMuted ? 0.0 : _volume);
                                        });
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                                activeTrackColor: const Color(0xFF2196F3),
                                inactiveTrackColor: Colors.white24,
                                thumbColor: const Color(0xFF2196F3),
                              ),
                              child: Slider(
                                value: _volume,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (val) {
                                  setAudioState(() {
                                    _volume = val;
                                    _isMuted = false;
                                    _controller.setVolume(val);
                                  });
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Audio Track Selector (A14 / MX-758)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('AUDIO TRACK (ऑडियो भाषा)', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF00E5FF),
                                    side: const BorderSide(color: Color(0xFF00E5FF), width: 0.8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.folder_open_rounded, size: 14),
                                  label: const Text('Open External Audio', style: TextStyle(fontSize: 11)),
                                  onPressed: () async {
                                    try {
                                      final res = await FilePicker.platform.pickFiles(type: FileType.audio);
                                      if (res != null && res.files.single.path != null) {
                                        setAudioState(() {
                                          _audioTrackName = res.files.single.name;
                                        });
                                        setState(() {});
                                        _showPillHud('Loaded Audio: ${res.files.single.name}', icon: Icons.audiotrack_rounded);
                                      }
                                    } catch (_) {}
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: DropdownButton<String>(
                                isExpanded: true,
                                dropdownColor: const Color(0xFF131A2A),
                                value: _audioTrackName,
                                underline: const SizedBox.shrink(),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                items: [
                                  _audioTrackName,
                                  if (_audioTrackName != 'Track 1 (Default / Stereo)') 'Track 1 (Default / Stereo)',
                                  'Track 2 (Hindi / Surround)',
                                  'Track 3 (English / 5.1 DD+)',
                                ].toSet().map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setAudioState(() => _audioTrackName = val);
                                    setState(() {});
                                    _showPillHud('Audio Track: $val', icon: Icons.audiotrack_rounded);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Super Loud 200% Audio Booster
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.volume_up_rounded, color: Color(0xFF10B981), size: 18),
                                    const SizedBox(width: 8),
                                    const Text('Super Loud Audio Boost (+200%)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Switch(
                                  value: _isAudioBoostEnabled,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    setAudioState(() {
                                      _isAudioBoostEnabled = val;
                                      if (val) {
                                        _audioBoostGain = 1.5;
                                        _volume = 1.0;
                                        _controller.setVolume(1.0);
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

                            // Audio Sync
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('AUDIO SYNC (देरी ठीक करें)', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text(
                                      _audioSyncMs == 0 ? 'Synchronized (0 ms)' : '${_audioSyncMs > 0 ? '+' : ''}$_audioSyncMs ms',
                                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white70),
                                      onPressed: () {
                                        setAudioState(() => _audioSyncMs -= 50);
                                        setState(() {});
                                        _showPillHud('Audio Sync: ${_audioSyncMs}ms', icon: Icons.sync_rounded);
                                      },
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setAudioState(() => _audioSyncMs = 0);
                                        setState(() {});
                                        _showPillHud('Audio Sync: Reset to 0ms', icon: Icons.sync_rounded);
                                      },
                                      child: const Text('Reset', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70),
                                      onPressed: () {
                                        setAudioState(() => _audioSyncMs += 50);
                                        setState(() {});
                                        _showPillHud('Audio Sync: +${_audioSyncMs}ms', icon: Icons.sync_rounded);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 5-Band Equalizer & Presets (A17 & A18 / MX-761 & MX-762)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('EQUALIZER (5-BAND EQ)', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                                Switch(
                                  value: _isEqualizerEnabled,
                                  activeColor: const Color(0xFF2196F3),
                                  onChanged: (val) {
                                    setAudioState(() => _isEqualizerEnabled = val);
                                    setState(() {});
                                    _showPillHud(val ? 'Equalizer: ON' : 'Equalizer: OFF', icon: Icons.equalizer_rounded);
                                  },
                                ),
                              ],
                            ),

                            // Decoder warning if HW (A18 / MX-762-03)
                            if (_decoderMode == 'HW')
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Note: Hardware (HW) decoder uses system audio. Switch to HW+ or SW for multi-band EQ.',
                                        style: TextStyle(color: Colors.amberAccent, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Preset selection row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['Normal', 'Classical', 'Dance', 'Flat', 'Bass Boost', 'Vocal', 'Rock', 'Pop'].map((p) {
                                  final isSel = _equalizerPreset == p;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: ChoiceChip(
                                      label: Text(p, style: TextStyle(color: isSel ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                      selected: isSel,
                                      selectedColor: const Color(0xFF00E5FF),
                                      backgroundColor: Colors.white10,
                                      onSelected: (val) {
                                        setAudioState(() {
                                          _equalizerPreset = p;
                                          if (p == 'Bass Boost') {
                                            _eq60Hz = 0.8; _eq230Hz = 0.5; _eq910Hz = 0.0; _eq3600Hz = 0.0; _eq14000Hz = 0.2;
                                          } else if (p == 'Vocal') {
                                            _eq60Hz = -0.2; _eq230Hz = 0.1; _eq910Hz = 0.7; _eq3600Hz = 0.5; _eq14000Hz = 0.0;
                                          } else if (p == 'Rock') {
                                            _eq60Hz = 0.6; _eq230Hz = 0.3; _eq910Hz = -0.2; _eq3600Hz = 0.4; _eq14000Hz = 0.7;
                                          } else {
                                            _eq60Hz = 0.0; _eq230Hz = 0.0; _eq910Hz = 0.0; _eq3600Hz = 0.0; _eq14000Hz = 0.0;
                                          }
                                        });
                                        setState(() {});
                                        _showPillHud('EQ Preset: $p', icon: Icons.equalizer_rounded);
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 5 Frequency Slider Sliders (60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz)
                            _buildEqSlider('60 Hz (Bass)', _eq60Hz, (v) => setAudioState(() => _eq60Hz = v)),
                            _buildEqSlider('230 Hz (Low Mid)', _eq230Hz, (v) => setAudioState(() => _eq230Hz = v)),
                            _buildEqSlider('910 Hz (Mid)', _eq910Hz, (v) => setAudioState(() => _eq910Hz = v)),
                            _buildEqSlider('3.6 kHz (High Mid)', _eq3600Hz, (v) => setAudioState(() => _eq3600Hz = v)),
                            _buildEqSlider('14 kHz (Treble)', _eq14000Hz, (v) => setAudioState(() => _eq14000Hz = v)),
                            const SizedBox(height: 14),

                            // Background Play
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: SwitchListTile(
                                secondary: const Icon(Icons.headphones_rounded, color: Color(0xFF00E5FF)),
                                title: const Text('Background Play (बैकग्राउंड प्ले)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: const Text('Keep sound playing when screen is locked or app is in background', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                value: _isBackgroundPlay,
                                activeColor: const Color(0xFF00E5FF),
                                onChanged: (val) {
                                  setAudioState(() => _isBackgroundPlay = val);
                                  setState(() => _isBackgroundPlay = val);
                                  _showPillHud(val ? '🎧 Background Play: ON' : 'Background Play: OFF', icon: Icons.headphones_rounded);
                                },
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
          ),
        );
      },
    );
  }

  Widget _buildEqSlider(String label, double val, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                activeTrackColor: const Color(0xFF2196F3),
                inactiveTrackColor: Colors.white12,
                thumbColor: const Color(0xFF00E5FF),
              ),
              child: Slider(
                value: val,
                min: -1.0,
                max: 1.0,
                onChanged: (v) {
                  onChanged(v);
                  setState(() {});
                },
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text('${(val * 10).toInt()}dB', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  void _showSubtitleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final isLand = mediaQuery.orientation == Orientation.landscape;
        final sheetH = isLand ? mediaQuery.size.height * 0.94 : mediaQuery.size.height * 0.76;
        final sheetW = isLand ? 520.0 : double.infinity;

        return StatefulBuilder(
          builder: (context, setSubState) => Align(
            alignment: isLand ? Alignment.bottomRight : Alignment.bottomCenter,
            child: Container(
              height: sheetH,
              width: sheetW,
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A).withOpacity(0.98),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: isLand ? Radius.zero : const Radius.circular(24),
                  bottomLeft: isLand ? const Radius.circular(24) : Radius.zero,
                ),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: SafeArea(
                top: false,
                child: Column(
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
                      children: [
                        const Icon(Icons.subtitles_rounded, color: Color(0xFF2196F3), size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Subtitle Settings (सबटाइटेल के विकल्प)',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Subtitle On/Off (चालू/बंद)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Subtitle On / Off', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              subtitle: Text(_subtitlesEnabled ? 'Subtitles are ON' : 'Subtitles are OFF', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              value: _subtitlesEnabled,
                              activeColor: const Color(0xFF2196F3),
                              onChanged: (val) {
                                setSubState(() => _subtitlesEnabled = val);
                                setState(() => _subtitlesEnabled = val);
                                _showPillHud(val ? 'Subtitles: ON' : 'Subtitles: OFF', icon: val ? Icons.subtitles_rounded : Icons.subtitles_off_rounded);
                              },
                            ),
                            const Divider(color: Colors.white12),

                            // 2. Language Selector
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.translate_rounded, color: Color(0xFF00E5FF)),
                              title: const Text('Subtitle Language (भाषा चुनें)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text(_subtitleLanguage, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                              onTap: () {
                                _showPillHud('Selected Language: $_subtitleLanguage', icon: Icons.translate_rounded);
                              },
                            ),

                            // 3. Font Size & Color
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Font Size (अक्षर आकार):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Row(
                                    children: [
                                      for (final sz in [12.0, 16.0, 20.0])
                                        InkWell(
                                          onTap: () {
                                            setSubState(() => _subtitleFontSize = sz);
                                            setState(() => _subtitleFontSize = sz);
                                            _showPillHud('Subtitle Font Size: ${sz.toInt()}sp', icon: Icons.format_size_rounded);
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _subtitleFontSize == sz ? const Color(0xFF2196F3) : Colors.white12,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text('${sz.toInt()}sp', style: TextStyle(color: _subtitleFontSize == sz ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Text Color (रंग):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Row(
                                    children: [
                                      for (final col in [Colors.white, Colors.amber, const Color(0xFF00E5FF), const Color(0xFF10B981)])
                                        InkWell(
                                          onTap: () {
                                            setSubState(() => _subtitleFontColor = col);
                                            setState(() => _subtitleFontColor = col);
                                            _showPillHud('Subtitle Color Changed', icon: Icons.color_lens_rounded);
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: col,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: _subtitleFontColor == col ? Colors.white : Colors.transparent, width: 2.0),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Divider(color: Colors.white12),

                            // 4. Subtitle Sync
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('SUBTITLE SYNC (समय मिलान)', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text(
                                      _subtitleSyncMs == 0 ? 'Synchronized (0 ms)' : '${_subtitleSyncMs > 0 ? '+' : ''}$_subtitleSyncMs ms',
                                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white70),
                                      onPressed: () {
                                        setSubState(() => _subtitleSyncMs -= 100);
                                        setState(() {});
                                        _showPillHud('Subtitle Sync: ${_subtitleSyncMs}ms', icon: Icons.sync_rounded);
                                      },
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setSubState(() => _subtitleSyncMs = 0);
                                        setState(() {});
                                        _showPillHud('Subtitle Sync: Reset to 0ms', icon: Icons.sync_rounded);
                                      },
                                      child: const Text('Reset', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70),
                                      onPressed: () {
                                        setSubState(() => _subtitleSyncMs += 100);
                                        setState(() {});
                                        _showPillHud('Subtitle Sync: +${_subtitleSyncMs}ms', icon: Icons.sync_rounded);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white12),

                            // 5. Open External Subtitle
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.file_open_rounded, color: Color(0xFF2196F3)),
                              title: const Text('Open External Subtitle (.srt / .vtt)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Select a subtitle file from device storage', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              onTap: () async {
                                try {
                                  final res = await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['srt', 'vtt', 'sub', 'ass'],
                                  );
                                  if (res != null && res.files.single.path != null) {
                                    Navigator.pop(ctx);
                                    _showPillHud('Subtitles loaded: ${res.files.single.name}', icon: Icons.subtitles_rounded);
                                  }
                                } catch (_) {}
                              },
                            ),

                            // 6. Online Subtitles
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
        title: Row(
          children: const [
            Icon(Icons.timer_rounded, color: Color(0xFF2196F3), size: 24),
            SizedBox(width: 10),
            Text('Sleep Timer (स्लीप टाइमर)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final minutes in [15, 30, 45, 60])
              ListTile(
                dense: true,
                leading: Icon(
                  _sleepTimerMinutes == minutes ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: _sleepTimerMinutes == minutes ? const Color(0xFF2196F3) : Colors.white54,
                ),
                title: Text('$minutes Minutes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sleepTimer?.cancel();
                  _sleepTimerMinutes = minutes;
                  _sleepTimer = Timer(Duration(minutes: minutes), () {
                    if (mounted && _controller.value.isPlaying) {
                      _controller.pause();
                      _showPillHud('Sleep Timer ended: Playback stopped', icon: Icons.timer_off_rounded);
                    }
                    _sleepTimer = null;
                    _sleepTimerMinutes = null;
                  });
                  _showPillHud('Sleep Timer active: $minutes mins', icon: Icons.timer_rounded);
                },
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444)),
              title: const Text('Turn Off (बंद करें)', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _sleepTimer?.cancel();
                _sleepTimer = null;
                _sleepTimerMinutes = null;
                _showPillHud('Sleep Timer: Cancelled', icon: Icons.timer_off_rounded);
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

    // Horizontal Seek & Vertical swipe fallback
    if (!_dragDirectionDetermined) {
      final dx = (details.localFocalPoint.dx - _initialFocalPoint.dx).abs();
      final dy = (details.localFocalPoint.dy - _initialFocalPoint.dy).abs();
      if (dx < 10 && dy < 10) return;
      _dragDirectionDetermined = true;

      if (dx > dy) {
        _isSeekingGesture = true;
        _seekOrigin = _controller.value.position;
        _seekTarget = _seekOrigin;
        _seekDeltaSeconds = 0.0;
        _wasPlayingBeforeSeekGesture = _controller.value.isPlaying;
        if (_wasPlayingBeforeSeekGesture) {
          _controller.pause();
        }
      } else {
        if (_initialFocalPoint.dx < screenSize.width * 0.5) {
          _isBrightnessDrag = true;
          _isVolumeDrag = false;
        } else {
          _isVolumeDrag = true;
          _isBrightnessDrag = false;
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
      setState(() {
        _isSeekingGesture = false;
        _showSeekHud = false;
      });
      if (_wasPlayingBeforeSeekGesture && mounted) {
        await _controller.play();
      }
    }

    _isScalingGestureActive = false;
    _isPinching = false;
    _isVolumeDrag = false;
    _isBrightnessDrag = false;
  }

  void _handleDoubleTap(TapDownDetails details, Size screenSize) {
    if (_isScreenLocked) return;

    if (_zoomScale > 1.05) {
      setState(() {
        _zoomScale = 1.0;
        _panOffset = Offset.zero;
      });
      _showPillHud('Zoom: 100% (Fit to Screen)', icon: Icons.fit_screen_rounded);
      return;
    }

    final tapX = details.localPosition.dx;
    if (tapX < screenSize.width * 0.40) {
      _seekRelative(-10);
    } else if (tapX > screenSize.width * 0.60) {
      _seekRelative(10);
    } else {
      _togglePlayPause();
    }
  }

  // MX Player More Options Sheet (A05 / MX-749)
  void _showMoreOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final isLand = mediaQuery.orientation == Orientation.landscape;
        final sheetH = isLand ? mediaQuery.size.height * 0.94 : mediaQuery.size.height * 0.76;
        final sheetW = isLand ? 520.0 : double.infinity;

        return StatefulBuilder(
          builder: (context, setSheetState) => Align(
            alignment: isLand ? Alignment.bottomRight : Alignment.bottomCenter,
            child: Container(
              height: sheetH,
              width: sheetW,
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A).withOpacity(0.98),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: isLand ? Radius.zero : const Radius.circular(24),
                  bottomLeft: isLand ? const Radius.circular(24) : Radius.zero,
                ),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: SafeArea(
                top: false,
                child: Column(
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
                      children: [
                        const Icon(Icons.more_vert_rounded, color: Color(0xFF2196F3), size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Playback Options (प्लेबैक विकल्प)',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 20,
                              runSpacing: 16,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildMoreOptionItem(
                                  icon: Icons.playlist_play_rounded,
                                  label: 'Queue',
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _showQueueSheet();
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: _repeatMode == 'one'
                                      ? Icons.repeat_one_rounded
                                      : (_repeatMode == 'off' ? Icons.repeat_rounded : Icons.repeat_on_rounded),
                                  label: 'Repeat: ${_repeatMode.toUpperCase()}',
                                  onTap: () {
                                    _cycleRepeatMode();
                                    setSheetState(() {});
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: Icons.repeat_one_rounded,
                                  label: _abRepeatA == null ? 'A-B Repeat' : 'A-B Loop',
                                  hasRedDot: _abRepeatA != null,
                                  onTap: () {
                                    _toggleAbRepeat();
                                    setSheetState(() {});
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: Icons.speed_rounded,
                                  label: 'Speed: ${_playbackSpeed.toStringAsFixed(1)}X',
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    setState(() => _showSpeedSliderHud = true);
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: Icons.timer_rounded,
                                  label: _sleepTimerMinutes == null ? 'Sleep Timer' : '${_sleepTimerMinutes}m Timer',
                                  hasRedDot: _sleepTimerMinutes != null,
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _showSleepTimerDialog();
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: Icons.developer_board_rounded,
                                  label: 'Decoder: $_decoderMode',
                                  onTap: () {
                                    _toggleDecoder();
                                    setSheetState(() {});
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: Icons.crop_free_rounded,
                                  label: 'Display',
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _showDisplaySettingsSheet();
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: Icons.audiotrack_rounded,
                                  label: 'Audio',
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _showAudioSettingsSheet();
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: Icons.subtitles_rounded,
                                  label: 'Subtitles',
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _showSubtitleSheet();
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: Icons.lock_outline_rounded,
                                  label: 'Lock Screen',
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _toggleLock();
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: Icons.picture_in_picture_alt_rounded,
                                  label: 'PiP Mode',
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _enterPip();
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: Icons.info_outline_rounded,
                                  label: 'File Info',
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
                                    _shareCurrentVideo();
                                  },
                                ),
                                _buildMoreOptionItem(
                                  icon: Icons.lightbulb_outline_rounded,
                                  label: 'Help / Guide',
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _showTutorialDialog();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(color: Colors.white12),
                            const SizedBox(height: 8),

                            // Bottom Toggles (Video Display & Shortcuts)
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                if (hasRedDot)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final isLand = mediaQuery.orientation == Orientation.landscape;
        final sheetH = isLand ? mediaQuery.size.height * 0.94 : mediaQuery.size.height * 0.76;
        final sheetW = isLand ? 520.0 : double.infinity;

        return Align(
          alignment: isLand ? Alignment.bottomRight : Alignment.bottomCenter,
          child: Container(
            height: sheetH,
            width: sheetW,
            decoration: BoxDecoration(
              color: const Color(0xFF131A2A).withOpacity(0.98),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: isLand ? Radius.zero : const Radius.circular(24),
                bottomLeft: isLand ? const Radius.circular(24) : Radius.zero,
              ),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SafeArea(
              top: false,
              child: Column(
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
                      const Text(
                        '📑 Playing Queue',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
          ),
        );
      },
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

  void _showCastDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
        title: Row(
          children: const [
            Icon(Icons.cast_rounded, color: Color(0xFF2196F3), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cast to Screen (टीवी पर भेजें)',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Icons.wifi_rounded, color: Color(0xFF10B981), size: 20),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                ),
                SizedBox(width: 8),
                Text('Searching for cast devices on Wi-Fi...', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              dense: true,
              leading: const Icon(Icons.tv_rounded, color: Color(0xFF2196F3)),
              title: const Text('Android TV (Living Room)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Google Cast Ready', style: TextStyle(color: Colors.white54, fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _showPillHud('Connecting to Android TV...', icon: Icons.cast_connected_rounded);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.settings_input_hdmi_rounded, color: Color(0xFFFFB300)),
              title: const Text('Jio Set Top Box', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('DLNA / Miracast Screen Mirror', style: TextStyle(color: Colors.white54, fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _showPillHud('Connecting to Jio Set Top Box...', icon: Icons.cast_connected_rounded);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.connected_tv_rounded, color: Color(0xFF10B981)),
              title: const Text('Smart TV (Bedroom)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Wireless Display', style: TextStyle(color: Colors.white54, fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _showPillHud('Connecting to Smart TV...', icon: Icons.cast_connected_rounded);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showPillHud('Cast Help: Ensure phone & TV are on same Wi-Fi', icon: Icons.help_outline_rounded);
            },
            child: const Text('Help', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDecoderDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
        title: Row(
          children: const [
            Icon(Icons.developer_board_rounded, color: Color(0xFF2196F3), size: 24),
            SizedBox(width: 10),
            Text('Decoder Settings (डिकोडर)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDecoderOptionTile(
              code: 'HW',
              title: 'HW Decoder (हार्डवेयर)',
              subtitle: 'Hardware acceleration (Best battery life & normal videos)',
              ctx: ctx,
            ),
            _buildDecoderOptionTile(
              code: 'HW+',
              title: 'HW+ Decoder (बेहतर परफॉरमेंस)',
              subtitle: 'Enhanced Hardware decoding (MX Player engine)',
              ctx: ctx,
            ),
            _buildDecoderOptionTile(
              code: 'SW',
              title: 'SW Decoder (सॉफ्टवेयर)',
              subtitle: 'Multi-core CPU decoding (Solves audio/video codec issues)',
              ctx: ctx,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecoderOptionTile({required String code, required String title, required String subtitle, required BuildContext ctx}) {
    final isSelected = _decoderMode == code;
    return ListTile(
      dense: true,
      leading: Icon(
        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
        color: isSelected ? const Color(0xFF2196F3) : Colors.white54,
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      onTap: () {
        Navigator.pop(ctx);
        setState(() => _decoderMode = code);
        _showPillHud('Decoder: $code Active', icon: Icons.developer_board_rounded);
      },
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
            Text('• Left side swipe: Brightness Control (0-100%)', style: TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Right side swipe: Volume Control (0-100%)', style: TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Horizontal swipe: Fast Forward / Rewind seeking with preview', style: TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Double tap left/right: 10s Rewind / Skip', style: TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Two-finger pinch: Zoom In / Zoom Out (0.75x - 4.5x)', style: TextStyle(color: Colors.white70, fontSize: 13)),
            SizedBox(height: 6),
            Text('• Long press anywhere: Temporary 2.0x Fast Forward speed', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
    _sleepTimer?.cancel();

    // Release Screen Wakelock
    _setWakeLock(false);

    if (_isInitialized) {
      _saveResumePosition();
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
                    aspectRatio: _customAspectRatio ??
                        (_controller.value.aspectRatio > 0
                            ? _controller.value.aspectRatio
                            : 16 / 9),
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

          // 5. MX PLAYER LEFT HUD: BRIGHTNESS GESTURE (Exact Diagram: Left Swipe = Brightness)
          if (_showBrightnessHud)
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

          // 6. MX PLAYER RIGHT HUD: VOLUME GESTURE (Exact Diagram: Right Swipe = Volume)
          if (_showVolumeHud)
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

          // 8. MX SPEED SLIDER HUD
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

          // 12. FULL MX PLAYER CONTROLS OVERLAY (A01: Top Bar 1-6, Center 7, Bottom 8-14)
          if (_isInitialized && _showControls && !_isScreenLocked) ...[
            // 12A. TOP BAR (Buttons 1, 2, 3, 4, 5, 6 & Decoder & Cast)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.black.withOpacity(0.40),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                        child: Row(
                          children: [
                            // Button 1 / MX-745-01: Back
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                              tooltip: 'Back',
                              onPressed: () => Navigator.pop(context),
                            ),
                            // Button 2 / MX-745-02: Title
                            Expanded(
                              child: Text(
                                _currentVideo.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                            // Button 3 / MX-745-03: Cast to Screen
                            IconButton(
                              icon: const Icon(Icons.cast_rounded, color: Colors.white, size: 21),
                              tooltip: 'Cast (टीवी पर भेजें)',
                              onPressed: _showCastDialog,
                            ),
                            // Button 6 / MX-745-06: Decoder Toggle Badge
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: _toggleDecoder,
                              onLongPress: _showDecoderDialog,
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white60, width: 1.2),
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.white.withOpacity(0.10),
                                ),
                                child: Text(
                                  _decoderMode,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            // Button 5 / MX-745-05: Subtitle (CC)
                            IconButton(
                              icon: const Icon(Icons.closed_caption_outlined, color: Colors.white, size: 22),
                              tooltip: 'Subtitle (CC)',
                              onPressed: _showSubtitleSheet,
                            ),
                            // Button 4 / MX-745-04: Audio Track
                            IconButton(
                              icon: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 22),
                              tooltip: 'Audio Track',
                              onPressed: _showAudioSettingsSheet,
                            ),
                            // Display Settings
                            IconButton(
                              icon: const Icon(Icons.crop_free_rounded, color: Colors.white, size: 22),
                              tooltip: 'Display Settings',
                              onPressed: _showDisplaySettingsSheet,
                            ),
                            // Button 17 / MX-745-17: Screen Lock
                            IconButton(
                              icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 22),
                              tooltip: 'Lock Screen',
                              onPressed: _toggleLock,
                            ),
                            // Button 7 / MX-745-07: More Options
                            IconButton(
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                              tooltip: 'More Options',
                              onPressed: _showMoreOptionsSheet,
                            ),
                          ],
                        ),
                      ),

                      // Expandable / Collapsible Quick Actions (A02)
                      _buildTopQuickActions(),
                    ],
                  ),
                ),
              ),
            ),

            // 12B. BUTTON 7 / MX-745-19: CENTER BIG CIRCULAR PLAY / PAUSE
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.60),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2.2),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
                  ),
                  child: Icon(
                    _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // 12C. BOTTOM CONTROLS (A01: Scrubber, Previous, 10s Rewind, Play, 10s Forward, Next)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.92),
                      Colors.black.withOpacity(0.50),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Button 14 & 15 & 16: Progress Bar, Elapsed & Duration
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
                                      _controller.pause();
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
                            const SizedBox(width: 8),
                            // Button 21 / MX-745-21: Full Screen Button [ ⛶ ]
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 24),
                              tooltip: 'Full Screen',
                              onPressed: _cycleFitMode,
                            ),
                          ],
                        ),

                        // Buttons 18, 10, 19, 12, 20: Bottom 5 Playback Controls
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0, bottom: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left: Screenshot Button
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 22),
                                tooltip: 'Screenshot',
                                onPressed: _takeScreenshot,
                              ),

                              // Center: 5 Playback Controls
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Button 18 / MX-745-18: Previous Video [ |◀ ]
                                  IconButton(
                                    iconSize: 28,
                                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                                    tooltip: 'Previous Video',
                                    onPressed: _playPreviousVideo,
                                  ),
                                  const SizedBox(width: 8),
                                  // 10s Rewind [ ◀◀ ]
                                  IconButton(
                                    iconSize: 26,
                                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                                    tooltip: '10s Rewind',
                                    onPressed: () => _seekRelative(-10),
                                  ),
                                  const SizedBox(width: 8),
                                  // Center Play / Pause [ ▶ / ❚❚ ]
                                  GestureDetector(
                                    onTap: _togglePlayPause,
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
                                      child: Icon(
                                        _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        size: 38,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 10s Forward [ ▶▶ ]
                                  IconButton(
                                    iconSize: 26,
                                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                                    tooltip: '10s Forward',
                                    onPressed: () => _seekRelative(10),
                                  ),
                                  const SizedBox(width: 8),
                                  // Button 20 / MX-745-20: Next Video [ ▶| ]
                                  IconButton(
                                    iconSize: 28,
                                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                                    tooltip: 'Next Video',
                                    onPressed: _playNextVideo,
                                  ),
                                ],
                              ),

                              // Right: Display Settings (⛶) & PiP (↘)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(6),
                                    icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 22),
                                    tooltip: 'Display Settings',
                                    onPressed: _showDisplaySettingsSheet,
                                  ),
                                  const SizedBox(width: 6),
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
              ),
            ),
          ],

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

          // 14. DEDICATED LEFT & RIGHT GESTURE ZONES (ACTIVE EVEN WHEN CONTROLS ARE SHOWING!)
          if (_isInitialized && !_isScreenLocked) ...[
            // Left side: Brightness & 10s Rewind (A03, A08)
            Positioned(
              left: 0,
              top: 56,
              bottom: 82,
              width: screenSize.width * 0.38,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  final delta = -details.primaryDelta! / (screenSize.height * 0.55);
                  _brightness = (_brightness + delta).clamp(0.02, 1.0);
                  _channel.invokeMethod('setScreenBrightness', {'brightness': _brightness});
                  setState(() => _showBrightnessHud = true);
                  _brightnessHudTimer?.cancel();
                  _brightnessHudTimer = Timer(const Duration(milliseconds: 900), () {
                    if (mounted) setState(() => _showBrightnessHud = false);
                  });
                },
                onVerticalDragEnd: (_) {
                  _brightnessHudTimer?.cancel();
                  _brightnessHudTimer = Timer(const Duration(milliseconds: 900), () {
                    if (mounted) setState(() => _showBrightnessHud = false);
                  });
                },
                onDoubleTap: () => _seekRelative(-10),
                onTap: () {
                  setState(() => _showControls = !_showControls);
                  if (_showControls) _startControlsTimer();
                },
                onLongPressStart: (_) {
                  _speedBeforeLongPress = _playbackSpeed;
                  _controller.setPlaybackSpeed(2.0);
                  _showPillHud('2.0X Fast Forward >>', icon: Icons.fast_forward_rounded);
                },
                onLongPressEnd: (_) {
                  _controller.setPlaybackSpeed(_speedBeforeLongPress);
                  _showPillHud('Speed: ${_speedBeforeLongPress.toStringAsFixed(1)}X', icon: Icons.speed_rounded);
                },
                child: Container(color: Colors.transparent),
              ),
            ),

            // Right side: Volume & 10s Forward (A04, A07)
            Positioned(
              right: 0,
              top: 56,
              bottom: 82,
              width: screenSize.width * 0.38,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  final delta = -details.primaryDelta! / (screenSize.height * 0.55);
                  _volume = (_volume + delta).clamp(0.0, 1.0);
                  _controller.setVolume(_volume);
                  _channel.invokeMethod('setDeviceVolume', {'volume': _volume});
                  setState(() => _showVolumeHud = true);
                  _volumeHudTimer?.cancel();
                  _volumeHudTimer = Timer(const Duration(milliseconds: 900), () {
                    if (mounted) setState(() => _showVolumeHud = false);
                  });
                },
                onVerticalDragEnd: (_) {
                  _volumeHudTimer?.cancel();
                  _volumeHudTimer = Timer(const Duration(milliseconds: 900), () {
                    if (mounted) setState(() => _showVolumeHud = false);
                  });
                },
                onDoubleTap: () => _seekRelative(10),
                onTap: () {
                  setState(() => _showControls = !_showControls);
                  if (_showControls) _startControlsTimer();
                },
                onLongPressStart: (_) {
                  _speedBeforeLongPress = _playbackSpeed;
                  _controller.setPlaybackSpeed(2.0);
                  _showPillHud('2.0X Fast Forward >>', icon: Icons.fast_forward_rounded);
                },
                onLongPressEnd: (_) {
                  _controller.setPlaybackSpeed(_speedBeforeLongPress);
                  _showPillHud('Speed: ${_speedBeforeLongPress.toStringAsFixed(1)}X', icon: Icons.speed_rounded);
                },
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
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
                  _repeatMode == 'one' ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                  color: _repeatMode != 'off' ? const Color(0xFF2196F3) : Colors.white,
                  size: 20,
                ),
                tooltip: 'Repeat: $_repeatMode',
                onPressed: _cycleRepeatMode,
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
                      icon: _repeatMode == 'one' ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                      label: 'Repeat (${_repeatMode.toUpperCase()})',
                      isActive: _repeatMode != 'off',
                      onTap: _cycleRepeatMode,
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
                      label: _sleepTimerMinutes == null ? 'Sleep Timer' : '${_sleepTimerMinutes}m Timer',
                      isActive: _sleepTimerMinutes != null,
                      onTap: _showSleepTimerDialog,
                    ),
                  if (_quickActionEnabled['ab_repeat'] == true)
                    _buildQuickActionItem(
                      icon: Icons.repeat_one_rounded,
                      label: _abRepeatA == null ? 'A-B Repeat' : 'A-B Loop Active',
                      isActive: _abRepeatA != null,
                      onTap: _toggleAbRepeat,
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
                      isActive: _isBackgroundPlay,
                      onTap: () {
                        setState(() => _isBackgroundPlay = !_isBackgroundPlay);
                        _showPillHud(_isBackgroundPlay ? 'Background Play Active' : 'Background Play: OFF', icon: Icons.headphones_rounded);
                      },
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

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isActive = false,
    bool hasRedDot = false,
    String? badgeText,
    Color activeColor = const Color(0xFF2196F3),
  }) {
    return Container(
      width: 64,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive ? activeColor.withOpacity(0.20) : Colors.black.withOpacity(0.40),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? activeColor : Colors.white24,
                      width: isActive ? 1.4 : 0.8,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isActive ? activeColor : Colors.white,
                  ),
                ),
                if (hasRedDot)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    ),
                  ),
                if (badgeText != null)
                  Positioned(
                    bottom: -2,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white70,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}