import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages Creator Subscriptions and Google/YouTube Account Connection
class YouTubeSubscriptionService extends ChangeNotifier {
  static final YouTubeSubscriptionService _instance = YouTubeSubscriptionService._internal();
  factory YouTubeSubscriptionService() => _instance;
  YouTubeSubscriptionService._internal();

  static const String _keySubscribed = 'msixa_subscribed_creators';
  static const String _keyUserGmail = 'msixa_connected_google_email';
  static const String _keyUserName = 'msixa_connected_google_name';

  final Set<String> _subscribedCreators = {};
  String? _userGmail;
  String? _userName;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  String? get userGmail => _userGmail;
  String? get userName => _userName;
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
      _userName = prefs.getString(_keyUserName);
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

  Future<void> setGoogleAccount(String email, {String? displayName}) async {
    _userGmail = email.trim();
    if (displayName != null && displayName.trim().isNotEmpty) {
      _userName = displayName.trim();
    } else {
      _userName = _userGmail!.split('@').first;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserGmail, _userGmail!);
      if (_userName != null) {
        await prefs.setString(_keyUserName, _userName!);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> disconnectGoogleAccount() async {
    _userGmail = null;
    _userName = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserGmail);
      await prefs.remove(_keyUserName);
    } catch (_) {}
    notifyListeners();
  }

  List<Map<String, String>> getAvailableDeviceAccounts() {
    final list = <Map<String, String>>[];
    if (_userGmail != null && _userGmail!.isNotEmpty) {
      list.add({
        'name': _userName ?? 'Google User',
        'email': _userGmail!,
      });
    }
    const defaults = [
      {'name': 'Rajesh Sain', 'email': 'rajesh.sain.kdk@gmail.com'},
      {'name': 'Msixa Music', 'email': 'msixa.official@gmail.com'},
    ];
    for (final d in defaults) {
      if (!list.any((a) => a['email']!.toLowerCase() == d['email']!.toLowerCase())) {
        list.add(d);
      }
    }
    return list;
  }

  Future<bool> toggleSubscribe(String author, {String? defaultEmail, String? displayName}) async {
    final key = author.trim().toLowerCase();
    if (key.isEmpty) return false;

    if (!hasGoogleAccount && defaultEmail != null && defaultEmail.trim().isNotEmpty) {
      await setGoogleAccount(defaultEmail, displayName: displayName);
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
