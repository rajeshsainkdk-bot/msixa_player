import 'package:flutter/services.dart';

class AppShareService {
  static const MethodChannel _channel = MethodChannel('com.msixa.player/app_share');

  /// Directly shares the installed APK file with another phone/user
  /// via native Android Sharesheet (WhatsApp, Bluetooth, Nearby Share, Telegram, etc.)
  static Future<bool> shareAppApk() async {
    try {
      final result = await _channel.invokeMethod<bool>('shareApk');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
