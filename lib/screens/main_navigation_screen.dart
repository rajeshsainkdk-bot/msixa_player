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
        return const ShortsFeedView();
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
      listenable: LanguageService(),
      builder: (context, _) {
        final lang = LanguageService();
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
          bottomNavigationBar: Container(
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
                    if (index == 2) {
                      // Pause music player so Shorts video sound plays with 100% clarity
                      try {
                        Provider.of<PlayerProvider>(context, listen: false).pause();
                      } catch (_) {}
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
                    // Center Highlighted Unique Neon Shorts Button
                    BottomNavigationBarItem(
                      icon: Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF007A), Color(0xFFFF8C00)], // Neon Magenta to Amber Glow
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF007A).withOpacity(0.55),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 2),
                            Text(
                              'SHORTS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      activeIcon: Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF007A), Color(0xFFFF8C00)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF007A).withOpacity(0.85),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, color: Colors.white, size: 17),
                            SizedBox(width: 2),
                            Text(
                              'SHORTS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
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
