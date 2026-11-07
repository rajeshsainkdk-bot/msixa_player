import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { hindi, english }

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static const String _prefKey = 'msixa_app_language';
  AppLanguage _currentLanguage = AppLanguage.hindi; // Default to Hindi as preferred

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isHindi => _currentLanguage == AppLanguage.hindi;
  bool get isEnglish => _currentLanguage == AppLanguage.english;

  String get languageCode => _currentLanguage == AppLanguage.hindi ? 'hi' : 'en';
  String get displayLabel => _currentLanguage == AppLanguage.hindi ? '🇮🇳 हिंदी' : '🇬🇧 English';
  String get switchTargetLabel => _currentLanguage == AppLanguage.hindi ? 'English' : 'हिंदी';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefKey);
    if (savedCode == 'en') {
      _currentLanguage = AppLanguage.english;
    } else {
      _currentLanguage = AppLanguage.hindi;
    }
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    if (_currentLanguage == AppLanguage.hindi) {
      await setLanguage(AppLanguage.english);
    } else {
      await setLanguage(AppLanguage.hindi);
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _currentLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, lang == AppLanguage.english ? 'en' : 'hi');
    notifyListeners();
  }

  /// Translation Lookup Dictionary
  String t(String key) {
    final translations = _localizedValues[key];
    if (translations == null) return key;
    return translations[languageCode] ?? key;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    // Auth & Onboarding
    'auth_title': {'hi': 'Msixa Player', 'en': 'Msixa Player'},
    'auth_subtitle': {'hi': 'श्रोता खाता बनाएं या लॉगिन करें', 'en': 'Create Listener Account or Login'},
    'full_name': {'hi': 'पूरा नाम (Full Name) *', 'en': 'Full Name *'},
    'full_name_hint': {'hi': 'उदा. Rajesh Kumar', 'en': 'e.g. Rajesh Kumar'},
    'phone_number': {'hi': 'मोबाइल नंबर (10-Digit Mobile) *', 'en': 'Mobile Number (10 Digits) *'},
    'phone_number_hint': {'hi': '9876543210', 'en': '9876543210'},
    'email_mandatory': {'hi': 'ईमेल आईडी (Email ID) *', 'en': 'Email ID *'},
    'email_hint': {'hi': 'rajesh@example.com', 'en': 'rajesh@example.com'},
    'start_listening': {'hi': '🎧 शुरू करें (Start Listening)', 'en': '🎧 Start Listening'},
    'auth_tagline': {'hi': '100% मुफ़्त एवं सुरक्षित • OTP की कोई आवश्यकता नहीं', 'en': '100% Free & Secure • No OTP Required'},
    'account_recovery_banner': {
      'hi': '⚡ पुराना मोबाइल नंबर डालने पर आपका पिछला अकाउंट, प्लेलिस्ट व पसंदीदा गाने स्वतः रीस्टोर हो जाएंगे!',
      'en': '⚡ Entering your previous number will instantly restore your account, playlists & favorite songs!'
    },
    'err_name_required': {'hi': 'कृपया अपना पूरा नाम दर्ज करें (कम से कम 2 अक्षर)', 'en': 'Please enter your full name (at least 2 characters)'},
    'err_phone_required': {'hi': 'कृपया 10 अंकों का वैध मोबाइल नंबर दर्ज करें', 'en': 'Please enter a valid 10-digit mobile number'},
    'err_email_required': {'hi': 'कृपया एक वैध ईमेल आईडी दर्ज करें (उदा. user@mail.com)', 'en': 'Please enter a valid email address (e.g. user@mail.com)'},
    'welcome_back': {'hi': 'वापसी पर स्वागत है! आपकी प्लेलिस्ट व गाने रीस्टोर हो गए हैं।', 'en': 'Welcome back! Your playlists & songs have been restored.'},
    'welcome_new': {'hi': 'Msixa Player में आपका स्वागत है!', 'en': 'Welcome to Msixa Player!'},
    'create_playlist': {'hi': '+ नई प्लेलिस्ट बनाएं', 'en': '+ Create Playlist'},
    'my_playlist_badge': {'hi': 'मेरी प्लेलिस्ट', 'en': 'My Playlist'},
    'playlist_name': {'hi': 'प्लेलिस्ट का नाम', 'en': 'Playlist Name'},

    // User App Home Screen
    'upload_song': {'hi': '+ Upload Song', 'en': '+ Upload Song'},
    'share_apk_title': {'hi': 'दोस्तों के साथ ऐप APK शेयर करें', 'en': 'Share App APK with Friends'},
    'share_apk_desc': {'hi': 'सीधे WhatsApp, Bluetooth व Nearby Share से भेजें', 'en': 'Send directly via WhatsApp, Bluetooth & Nearby Share'},
    'share_apk_btn': {'hi': 'Share APK', 'en': 'Share APK'},
    'offline_audio_title': {'hi': 'डिवाइस ऑफ़लाइन गाने (Device Audio)', 'en': 'Device Offline Audio'},
    'offline_audio_scan': {'hi': 'फ़ोन स्टोरेज स्कैन करें', 'en': 'Scan phone folders (Downloads, Music)'},
    'offline_ready': {'hi': 'ऑफ़लाइन गाने तैयार हैं', 'en': 'offline songs ready'},
    'scan_btn': {'hi': 'Scan', 'en': 'Scan'},
    'rescan_btn': {'hi': 'Rescan', 'en': 'Rescan'},
    'community_shelf_title': {'hi': '🔥 कम्युनिटी द्वारा जोड़े गए नए गाने', 'en': '🔥 Newly Added by Community'},
    'live_badge': {'hi': 'लाइव', 'en': 'Live'},
    'free_forever': {'hi': '100% मुफ़्त हमेशा के लिए', 'en': '100% Free Forever'},
    'all_free_tracks': {'hi': 'सभी मुफ़्त भारतीय गाने', 'en': 'All Free Indian Tracks'},
    'browse_category': {'hi': 'कैटेगरी के अनुसार सुनें', 'en': 'Browse by Category'},
    'show_all': {'hi': 'सभी देखें (Show All)', 'en': 'Show All'},
    'listen_free': {'hi': 'Listen Free', 'en': 'Listen Free'},

    // Upload Screen
    'upload_heading': {'hi': 'नया गाना अपलोड करें', 'en': 'Upload New Song'},
    'pick_audio_file': {'hi': 'ऑडियो फ़ाइल चुनें (.mp3, .m4a)', 'en': 'Pick Audio File (.mp3, .m4a)'},
    'file_selected': {'hi': 'फ़ाइल चुनी गई', 'en': 'File Selected'},
    'song_title': {'hi': 'गाने का नाम (Song Title)', 'en': 'Song Title'},
    'artist_name': {'hi': 'गायक / कलाकार (Artist)', 'en': 'Artist Name'},
    'album_name': {'hi': 'एल्बम (Album)', 'en': 'Album Name'},
    'genre_label': {'hi': 'शैली / श्रेणी (Genre)', 'en': 'Genre / Category'},
    'cover_url': {'hi': 'पोस्टर इमेज लिंक (Cover URL)', 'en': 'Cover Image URL'},
    'submit_upload': {'hi': 'समीक्षा हेतु भेजें (Submit Song)', 'en': 'Submit for Review'},
    'dup_alert_title': {'hi': '⚠️ गाना पहले से मौजूद है!', 'en': '⚠️ Song Already Exists!'},
    'dup_alert_msg': {'hi': 'यह गाना पहले से ही लाइब्रेरी में उपलब्ध है। क्या आप इसे अभी सुनना चाहते हैं?', 'en': 'This song is already in the library. Would you like to play it now?'},
    'play_now': {'hi': 'गाना अभी सुनें (Play Now)', 'en': 'Play Song Now'},
    'cancel': {'hi': 'रद्द करें (Cancel)', 'en': 'Cancel'},

    // Admin Dashboard
    'admin_title': {'hi': 'Msixa Player Admin', 'en': 'Msixa Player Admin'},
    'tab_pending': {'hi': 'लंबित गाने', 'en': 'Pending Songs'},
    'tab_users': {'hi': 'यूज़र्स डेटा', 'en': 'Users Directory'},
    'tab_live': {'hi': 'लाइव गाने', 'en': 'Live Songs'},
    'metric_total_users': {'hi': 'कुल यूज़र्स', 'en': 'Total Users'},
    'metric_active_users': {'hi': 'सक्रिय (Active)', 'en': 'Active (Online)'},
    'metric_pending': {'hi': 'लंबित अप्रूवल', 'en': 'Pending Approval'},
    'metric_live': {'hi': 'लाइव गाने', 'en': 'Live Songs'},
    'preview_play': {'hi': 'सुनें (Preview)', 'en': 'Preview'},
    'preview_stop': {'hi': 'रुकें (Stop)', 'en': 'Stop'},
    'approve_btn': {'hi': 'स्वीकार करें (Approve)', 'en': 'Approve'},
    'reject_btn': {'hi': 'हटाएँ (Reject)', 'en': 'Reject'},
    'delete_btn': {'hi': 'हटाएँ (Delete)', 'en': 'Delete'},
    'edit_btn': {'hi': 'एडिट करें (Edit)', 'en': 'Edit'},
    'add_song_admin': {'hi': '+ नया गाना जोड़ें', 'en': '+ Add New Song'},
    'save_changes': {'hi': 'बदलाव सेव करें', 'en': 'Save Changes'},
    'search_users': {'hi': 'यूज़र का नाम, फ़ोन या ईमेल खोजें...', 'en': 'Search by name, phone or email...'},
    'call_tooltip': {'hi': 'कॉल करें', 'en': 'Call User'},
    'whatsapp_tooltip': {'hi': 'WhatsApp मैसेज', 'en': 'WhatsApp Message'},
    'email_tooltip': {'hi': 'ईमेल भेजें', 'en': 'Send Email'},
    'sign_out': {'hi': 'लॉग आउट', 'en': 'Sign Out'},
    'confirm_delete_title': {'hi': 'गाना हटाएँ?', 'en': 'Delete Song?'},
    'confirm_delete_msg': {'hi': 'क्या आप वाकई इस गाने को हमेशा के लिए हटाना चाहते हैं?', 'en': 'Are you sure you want to permanently remove this song?'},
    'confirm_yes': {'hi': 'हाँ, हटाएँ', 'en': 'Yes, Delete'},
    'no_pending_songs': {'hi': 'कोई लंबित गाना नहीं है!', 'en': 'No pending songs!'},
    'all_songs_approved': {'hi': 'सभी गाने अप्रूव हो चुके हैं।', 'en': 'All songs have been approved.'},
    'no_users_found': {'hi': 'कोई यूज़र नहीं मिला', 'en': 'No users found'},
    'switch_lang': {'hi': 'English में बदलें', 'en': 'हिंदी में बदलें'},
  };
}

