import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'theme/app_theme.dart';
import 'providers/player_provider.dart';
import 'screens/main_navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      ],
      child: MaterialApp(
        title: 'Msixa Player',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainNavigationScreen(),
      ),
    );
  }
}
