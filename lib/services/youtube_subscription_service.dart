import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages Creator Subscriptions and Google/Gmail Account Connection
class YouTubeSubscriptionService extends ChangeNotifier {
  static final YouTubeSubscriptionService _instance = YouTubeSubscriptionService._internal();
  factory YouTubeSubscriptionService() => _instance;
  YouTubeSubscriptionService._internal();

  static const String _keySubscribed = 'msixa_subscribed_creators';
  static const String _keyUserGmail = 'msixa_connected_google_email';

  final Set<String> _subscribedCreators = {};
  String? _userGmail;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  String? get userGmail => _userGmail;
  bool get hasGoogleAccount => _userGmail != null && _userGmail!.isNotEmpty;
  Set<String> get subscribedCreators => Set.unmodifiable(_subscribedCreators);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keySubscribed) ?? [];
      _subscribedCreators.clear();
      _subscribedCreators.addAll(list.map((e) => e.trim().toLowerCase()));
      _userGmail = prefs.getString(_keyUserGmail);
      _isInitialized = true;
      notifyListeners();
    } catch (_) {
      _isInitialized = true;
    }
  }

  bool isSubscribed(String author) {
    if (author.trim().isEmpty) return false;
    return _subscribedCreators.contains(author.trim().toLowerCase());
  }

  Future<void> setGoogleAccount(String email) async {
    _userGmail = email.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserGmail, _userGmail!);
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> toggleSubscribe(String author, {String? defaultEmail}) async {
    final key = author.trim().toLowerCase();
    if (key.isEmpty) return false;

    if (!hasGoogleAccount && defaultEmail != null && defaultEmail.trim().isNotEmpty) {
      await setGoogleAccount(defaultEmail);
    }

    final willSubscribe = !_subscribedCreators.contains(key);
    if (willSubscribe) {
      _subscribedCreators.add(key);
    } else {
      _subscribedCreators.remove(key);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keySubscribed, _subscribedCreators.toList());
    } catch (_) {}

    notifyListeners();
    return willSubscribe;
  }
}
