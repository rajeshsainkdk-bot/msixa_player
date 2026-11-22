import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_player.dart';
import '../services/update_service.dart';
import '../services/language_service.dart';
import '../services/feedback_service.dart';
import 'home_screen.dart';
import 'videos_screen.dart';
import 'library_screen.dart';
import 'equalizer_screen.dart';
import '../widgets/shorts_feed_view.dart';
import '../services/intent_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context, autoPrompt: true);
      IntentService.checkInitialMedia(context);
      // Check if user has played >= 5 songs and needs to submit mandatory feedback
      FeedbackService.checkAndPromptFeedback(context);
    });

    FeedbackService.triggerPromptNotifier.addListener(_onFeedbackTriggered);
  }

  void _onFeedbackTriggered() {
    if (mounted) {
      FeedbackService.checkAndPromptFeedback(context);
    }
  }

  @override
  void dispose() {
    FeedbackService.triggerPromptNotifier.removeListener(_onFeedbackTriggered);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      UpdateService.checkForUpdate(context, autoPrompt: true);
      FeedbackService.checkAndPromptFeedback(context);
    }
  }

  final Set<int> _loadedTabs = {0}; // Only instantiate Tab 0 (HomeScreen) on cold start!

  Widget _getScreen(int index) {
    if (!_loadedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const VideosScreen();
      case 2:
        return ShortsFeedView(
          onBackToHome: () {
            setState(() {
              _currentIndex = 0;
            });
          },
        );
      case 3:
        return const LibraryScreen();
      case 4:
        return const EqualizerScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([LanguageService(), ShortsFeedView.isPlayingNotifier]),
      builder: (context, _) {
        final lang = LanguageService();
        final hideBottomNav = (_currentIndex == 2 && ShortsFeedView.isPlayingNotifier.value);
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // Active Tab Screen with Instant Lazy Loading
              IndexedStack(
                index: _currentIndex,
                children: [
                  _getScreen(0),
                  _getScreen(1),
                  _getScreen(2),
                  _getScreen(3),
                  _getScreen(4),
                ],
              ),

              // Floating Persistent MiniPlayer above navigation (hidden on full-screen Shorts tab)
              if (_currentIndex != 2)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MiniPlayer(),
                ),
            ],
          ),
          bottomNavigationBar: hideBottomNav
              ? null
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                        width: 1,
                      ),
                    ),
                  ),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      if (_currentIndex == 2 && index != 2) {
                        ShortsFeedView.pausePlayback();
                      }
                      if (index == 2) {
                        // Pause music player so Shorts video sound plays with 100% clarity
                        try {
                          Provider.of<PlayerProvider>(context, listen: false).pause();
                        } catch (_) {}
                        // Direct refresh to fresh, non-repeated short link every time Shorts button is tapped
                        ShortsFeedView.refreshFeed();
                      }
                      setState(() {
                        _loadedTabs.add(index);
                        _currentIndex = index;
                      });
                    },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: AppColors.accentCyan,
                  unselectedItemColor: AppColors.textMuted,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.explore_rounded),
                      label: lang.isHindi ? 'डिस्कवर' : 'Discover',
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.video_library_rounded),
                      label: lang.t('nav_videos'),
                    ),
                    // Center Highlighted Round Circular Shorts Button with Continuous Running Rainbow Neon Border Lighting
                    BottomNavigationBarItem(
                      icon: const _RainbowGlowingCircularShortsButton(isSelected: false),
                      activeIcon: const _RainbowGlowingCircularShortsButton(isSelected: true),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.library_music_rounded),
                      label: lang.t('nav_library'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.graphic_eq_rounded),
                      label: lang.t('nav_sound_fx'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
}

/// Circular Round Shorts Nav Button with Continuous Rotating Colorful Rainbow Neon Lighting Border
class _RainbowGlowingCircularShortsButton extends StatefulWidget {
  final bool isSelected;
  const _RainbowGlowingCircularShortsButton({Key? key, required this.isSelected}) : super(key: key);

  @override
  State<_RainbowGlowingCircularShortsButton> createState() => _RainbowGlowingCircularShortsButtonState();
}

class _RainbowGlowingCircularShortsButtonState extends State<_RainbowGlowingCircularShortsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * 2 * 3.1415926535;
        return Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF007A).withOpacity(widget.isSelected ? 0.65 : 0.35),
                blurRadius: widget.isSelected ? 14 : 8,
                spreadRadius: widget.isSelected ? 2 : 1,
              ),
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(widget.isSelected ? 0.45 : 0.25),
                blurRadius: widget.isSelected ? 12 : 6,
                spreadRadius: 1,
              ),
            ],
            gradient: SweepGradient(
              startAngle: 0.0,
              endAngle: 6.2831853,
              transform: GradientRotation(angle),
              colors: const [
                Color(0xFFFF007A), // Hot Pink
                Color(0xFFFF8C00), // Amber Orange
                Color(0xFFFFD700), // Gold
                Color(0xFF00E5FF), // Cyan
                Color(0xFF7C3AED), // Purple
                Color(0xFFFF007A), // Back to Pink
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.5), // Rotating colorful border width
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0B0F19), // Dark core
              ),
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: widget.isSelected
                          ? [const Color(0xFFFF007A), const Color(0xFFFF8C00)]
                          : [const Color(0xFF2A1535), const Color(0xFF16253D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
