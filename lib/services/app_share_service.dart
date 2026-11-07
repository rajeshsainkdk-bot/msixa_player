import 'dart:io';
import 'package:share_plus/share_plus.dart';

class AppShareService {
  /// Shares Msixa Player APK file or invitation link directly via native Android sharesheet
  /// (WhatsApp, Bluetooth, Quick Share, Telegram, Messages, etc.)
  static Future<void> shareAppApk() async {
    try {
      // Check common APK paths on device
      final candidatePaths = [
        '/storage/emulated/0/Download/MsixaPlayer.apk',
        '/storage/emulated/0/Download/app-release.apk',
      ];

      for (final p in candidatePaths) {
        final f = File(p);
        if (await f.exists()) {
          await Share.shareXFiles(
            [XFile(f.path, mimeType: 'application/vnd.android.package-archive')],
            text: 'Install Msixa Player - 100% Free Indian Music & Offline MP3 Player!',
            subject: 'Msixa Player APK',
          );
          return;
        }
      }

      // If local APK file not found in download folder, share direct APK release link
      await Share.share(
        '🎵 Install Msixa Player - 100% Free Indian Music & Offline MP3 Player!\nZero subscription, no payment required.\n\nDirect APK Download:\nhttps://github.com/rajeshsainkdk-bot/msixa_player/releases',
        subject: 'Msixa Player APK',
      );
    } catch (_) {}
  }
}
