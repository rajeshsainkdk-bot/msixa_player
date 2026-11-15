import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'theme/app_theme.dart';
import 'providers/player_provider.dart';
import 'services/cloud_backend_service.dart';
import 'services/language_service.dart';
import 'services/r2_storage_service.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/auth/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaKit backend for video_player:
  // Native in-app software & hardware decoding for EAC3 (Dolby Digital Plus), AC3, DTS, 5.1/7.1 surround downmix!
  VideoPlayerMediaKit.ensureInitialized(
    android: true,
  );

  // Initialize background audio playback with system notification controls
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.msixa.player.channel.audio',
      androidNotificationChannelName: 'Msixa Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    );
  } catch (_) {}

  // Initialize Cloud & Authentication Backend
  await R2StorageService().init();
  final backend = CloudBackendService();
  await backend.init();
  await LanguageService().init();

  // Set system UI to immersive dark styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF131C2E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MsixaPlayerApp());
}

class MsixaPlayerApp extends StatelessWidget {
  const MsixaPlayerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => PlayerProvider(),
        ),
        ChangeNotifierProvider<CloudBackendService>.value(
          value: CloudBackendService(),
        ),
        ChangeNotifierProvider<R2StorageService>.value(
          value: R2StorageService(),
        ),
        ChangeNotifierProvider<LanguageService>.value(
          value: LanguageService(),
        ),
      ],
      child: AnimatedBuilder(
        animation: LanguageService(),
        builder: (context, _) {
          return MaterialApp(
            title: 'Msixa Player',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: const UserAppRootView(),
          );
        },
      ),
    );
  }
}

class UserAppRootView extends StatefulWidget {
  const UserAppRootView({Key? key}) : super(key: key);

  @override
  State<UserAppRootView> createState() => _UserAppRootViewState();
}

class _UserAppRootViewState extends State<UserAppRootView> {
  @override
  Widget build(BuildContext context) {
    final backend = context.watch<CloudBackendService>();

    // Mandatory Verification Check: User must be registered with verified Phone OTP & Email
    if (!backend.isAuthenticated) {
      return AuthScreen(
        onAuthenticated: () {
          context.read<PlayerProvider>().onUserAuthenticated();
          setState(() {});
        },
      );
    }

    return const MainNavigationScreen();
  }
}
