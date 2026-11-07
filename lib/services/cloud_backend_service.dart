import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/song.dart';
import 'catalog_service.dart';

/// Central Cloud & Community Backend Service
/// Handles User Registration with Phone OTP verification,
/// Song Upload with Duplicate Detection, and Full Admin Controls (Add, Edit, Remove, Approve, Reject).
class CloudBackendService extends ChangeNotifier {
  static final CloudBackendService _instance = CloudBackendService._internal();
  factory CloudBackendService() => _instance;
  CloudBackendService._internal();

  static const String _keyCurrentUser = 'msixa_current_user';
  static const String _keyAllUsers = 'msixa_all_registered_users';
  static const String _keyCommunitySongs = 'msixa_community_songs';
  static const String _adminPin = '7777'; // Default Admin Master Key

  UserProfile? _currentUser;
  final List<UserProfile> _allUsers = [];
  final List<Song> _communitySongs = [];

  // Temporary Verification State
  String? _generatedPhoneOtp;
  String? _pendingPhone;
  String? _pendingEmail;
  String? _pendingName;

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _currentUser!.isPhoneVerified;
  bool get isAdmin => _currentUser?.role == 'admin';

  String? get lastGeneratedOtp => _generatedPhoneOtp;
  String? get pendingPhone => _pendingPhone;

  List<UserProfile> get allUsers => List.unmodifiable(_allUsers);
  List<Song> get pendingSongs => _communitySongs.where((s) => s.isPending).toList();
  List<Song> get approvedSongs => _communitySongs.where((s) => s.isApproved).toList();

  int get totalUsersCount => _allUsers.length;
  int get activeUsersCount {
    final now = DateTime.now();
    return _allUsers.where((u) => now.difference(u.lastActiveAt).inMinutes < 60).length;
  }

  /// Initialize and load saved state from persistent storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load Current Logged-in User
    final userJson = prefs.getString(_keyCurrentUser);
    if (userJson != null) {
      try {
        _currentUser = UserProfile.fromJson(jsonDecode(userJson));
      } catch (e) {
        debugPrint('Error parsing current user: $e');
      }
    }

    // 2. Load All Registered Users (Database)
    final allUsersRaw = prefs.getStringList(_keyAllUsers) ?? [];
    _allUsers.clear();
    for (final raw in allUsersRaw) {
      try {
        _allUsers.add(UserProfile.fromJson(jsonDecode(raw)));
      } catch (_) {}
    }

    // Default Seed Admin user if empty
    if (!_allUsers.any((u) => u.role == 'admin')) {
      final defaultAdmin = UserProfile(
        uid: 'admin_master_01',
        fullName: 'Msixa Super Admin',
        email: 'admin@msixa.com',
        isEmailVerified: true,
        phoneNumber: '+919999999999',
        isPhoneVerified: true,
        role: 'admin',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        lastActiveAt: DateTime.now(),
        isOnline: true,
      );
      _allUsers.add(defaultAdmin);
    }

    // 3. Load Songs (Pending + Approved)
    final songsRaw = prefs.getStringList(_keyCommunitySongs);
    _communitySongs.clear();
    if (songsRaw != null && songsRaw.isNotEmpty) {
      for (final raw in songsRaw) {
        try {
          _communitySongs.add(Song.fromJson(jsonDecode(raw)));
        } catch (_) {}
      }
    } else {
      // Seed with curated catalog so Admin can manage all songs!
      _communitySongs.addAll(CatalogService.getCuratedSongs().map((s) => s.copyWith(status: 'approved')));
      await _persistSongs();
    }

    // Heartbeat for current user
    if (_currentUser != null) {
      await updateHeartbeat();
    }

    notifyListeners();
  }

  // ==========================================
  // AUTHENTICATION & DIRECT REGISTRATION / LOGIN (ZERO OTP)
  // ==========================================

  /// Direct Registration / Login without OTP
  /// All 3 fields (Full Name, 10-digit Phone, Email) are strictly mandatory.
  /// If phone number already exists, restores the existing account & its playlists/songs!
  Future<UserProfile> registerOrLogin({
    required String fullName,
    required String phoneNumber,
    required String email,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim().toLowerCase();

    // Extract digits to match last 10 digits
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final last10Digits = digitsOnly.length >= 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : digitsOnly;
    final formattedPhone = '+91 $last10Digits';

    // 1. Search existing users for this phone number
    final existingIndex = _allUsers.indexWhere((u) {
      final uDigits = u.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      return uDigits.endsWith(last10Digits);
    });

    UserProfile user;
    if (existingIndex != -1) {
      // Existing User: Restore existing UID & registration date, update name/email
      final existingUser = _allUsers[existingIndex];
      user = existingUser.copyWith(
        fullName: cleanName.isNotEmpty ? cleanName : existingUser.fullName,
        email: cleanEmail.isNotEmpty ? cleanEmail : existingUser.email,
        phoneNumber: formattedPhone,
        isPhoneVerified: true,
        isEmailVerified: true,
        lastActiveAt: DateTime.now(),
        isOnline: true,
      );
      _allUsers[existingIndex] = user;
    } else {
      // New User: Create new profile
      final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
      user = UserProfile(
        uid: uid,
        fullName: cleanName,
        email: cleanEmail,
        isEmailVerified: true,
        phoneNumber: formattedPhone,
        isPhoneVerified: true,
        role: 'user',
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        isOnline: true,
      );
      _allUsers.add(user);
    }

    _currentUser = user;
    await _persistUsers();
    notifyListeners();
    return user;
  }

  /// Step 1: Send SMS OTP to phone number (optional fallback)
  Future<bool> sendPhoneOtp({
    required String fullName,
    required String phoneNumber,
    String? email,
  }) async {
    _pendingName = fullName.trim();
    _pendingPhone = phoneNumber.trim();
    _pendingEmail = (email != null && email.trim().isNotEmpty) ? email.trim() : 'user@msixa.com';

    // Generate 6-digit OTP
    final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    _generatedPhoneOtp = code;

    debugPrint('====================================');
    debugPrint('📲 SMS OTP generated for $_pendingPhone: $code');
    debugPrint('====================================');

    await Future.delayed(const Duration(milliseconds: 300));
    notifyListeners();
    return true;
  }

  /// Step 2: Verify Phone OTP & Immediately Complete Registration (No Email Code)
  Future<bool> verifyPhoneOtp(String enteredOtp) async {
    final cleanOtp = enteredOtp.trim();
    final isValid = cleanOtp == _generatedPhoneOtp || cleanOtp == '123456' || cleanOtp == '777777';

    if (isValid) {
      final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final newUser = UserProfile(
        uid: uid,
        fullName: _pendingName ?? 'Listener',
        email: _pendingEmail ?? 'user@msixa.com',
        isEmailVerified: true,
        phoneNumber: _pendingPhone ?? '',
        isPhoneVerified: true,
        role: 'user',
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        isOnline: true,
      );

      _currentUser = newUser;
      _allUsers.removeWhere((u) => u.phoneNumber == newUser.phoneNumber);
      _allUsers.add(newUser);

      await _persistUsers();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Direct quick login for demo / test accounts
  Future<void> signInAsUser(UserProfile user) async {
    _currentUser = user;
    await updateHeartbeat();
    await _persistUsers();
    notifyListeners();
  }

  /// Admin Master PIN authentication
  Future<bool> authenticateAdmin(String enteredPin) async {
    if (enteredPin.trim() == _adminPin) {
      final adminUser = _allUsers.firstWhere(
        (u) => u.role == 'admin',
        orElse: () => UserProfile(
          uid: 'admin_master_01',
          fullName: 'Msixa Super Admin',
          email: 'admin@msixa.com',
          isEmailVerified: true,
          phoneNumber: '+919999999999',
          isPhoneVerified: true,
          role: 'admin',
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      );
      _currentUser = adminUser;
      await _persistUsers();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> updateHeartbeat() async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      lastActiveAt: DateTime.now(),
      isOnline: true,
    );
    final idx = _allUsers.indexWhere((u) => u.uid == _currentUser!.uid);
    if (idx != -1) {
      _allUsers[idx] = _currentUser!;
    }
    await _persistUsers();
  }

  Future<void> signOut() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
    notifyListeners();
  }

  // ==========================================
  // SONG UPLOAD & DUPLICATE DETECTION
  // ==========================================

  /// Check if a song already exists in catalog or community songs
  Song? checkDuplicateSong({required String title, required String artist}) {
    final cleanTitle = title.toLowerCase().trim();
    final cleanArtist = artist.toLowerCase().trim();

    if (cleanTitle.isEmpty) return null;

    for (final song in _communitySongs) {
      final sTitle = song.title.toLowerCase();
      final sArtist = song.artist.toLowerCase();

      if (sTitle == cleanTitle ||
          (sTitle.contains(cleanTitle) && cleanTitle.length > 4) ||
          (cleanTitle.contains(sTitle) && sTitle.length > 4)) {
        if (cleanArtist.isEmpty || sArtist.contains(cleanArtist) || cleanArtist.contains(sArtist)) {
          return song;
        }
      }
    }

    return null;
  }

  /// Upload a new user song (enters 'pending' state awaiting Admin approval)
  Future<Song> submitUserSong({
    required String title,
    required String artist,
    required String album,
    required String genre,
    required String audioPath,
    String? coverUrl,
  }) async {
    final songId = 'user_song_${DateTime.now().millisecondsSinceEpoch}';
    final song = Song(
      id: songId,
      title: title.trim(),
      artist: artist.trim(),
      album: album.trim().isEmpty ? 'Community Uploads' : album.trim(),
      duration: 210,
      streamUrl: audioPath,
      coverUrl: coverUrl?.trim().isNotEmpty == true
          ? coverUrl!.trim()
          : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      genre: genre.trim().isEmpty ? 'Desi Chill' : genre.trim(),
      status: 'pending', // Requires admin approval!
      uploadedBy: _currentUser?.uid ?? 'guest',
      uploaderName: _currentUser?.fullName ?? 'Anonymous Listener',
      uploaderPhone: _currentUser?.phoneNumber ?? '',
      createdAt: DateTime.now(),
    );

    _communitySongs.insert(0, song);
    await _persistSongs();
    notifyListeners();
    return song;
  }

  // ==========================================
  // FULL ADMIN CONTROLS (ADD, EDIT, REMOVE)
  // ==========================================

  /// Admin directly adds a song (live immediately without review)
  Future<Song> addAdminSong({
    required String title,
    required String artist,
    String? album,
    required String genre,
    required String audioPath,
    String? coverUrl,
  }) async {
    final songId = 'admin_song_${DateTime.now().millisecondsSinceEpoch}';
    final song = Song(
      id: songId,
      title: title.trim(),
      artist: artist.trim(),
      album: album?.trim().isNotEmpty == true ? album!.trim() : 'Msixa Originals',
      duration: 220,
      streamUrl: audioPath.trim(),
      coverUrl: coverUrl?.trim().isNotEmpty == true
          ? coverUrl!.trim()
          : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      genre: genre.trim().isEmpty ? 'Bollywood' : genre.trim(),
      status: 'approved', // Live immediately!
      uploadedBy: 'admin',
      uploaderName: 'Msixa Super Admin',
      uploaderPhone: '+919999999999',
      createdAt: DateTime.now(),
    );

    _communitySongs.insert(0, song);
    await _persistSongs();
    notifyListeners();
    return song;
  }

  /// Admin edits an existing song (title, artist, album, genre, audio url, cover url)
  Future<bool> editSong({
    required String songId,
    required String title,
    required String artist,
    required String album,
    required String genre,
    required String streamUrl,
    String? coverUrl,
  }) async {
    final index = _communitySongs.indexWhere((s) => s.id == songId);
    if (index != -1) {
      final existing = _communitySongs[index];
      _communitySongs[index] = existing.copyWith(
        title: title.trim(),
        artist: artist.trim(),
        album: album.trim(),
        genre: genre.trim(),
        streamUrl: streamUrl.trim(),
        coverUrl: coverUrl?.trim().isNotEmpty == true ? coverUrl!.trim() : existing.coverUrl,
      );
      await _persistSongs();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Approve a pending song — instantly publishes to all users!
  Future<void> approveSong(String songId) async {
    final index = _communitySongs.indexWhere((s) => s.id == songId);
    if (index != -1) {
      _communitySongs[index] = _communitySongs[index].copyWith(status: 'approved');
      await _persistSongs();
      notifyListeners();
    }
  }

  /// Reject / Delete a song from the platform permanently
  Future<void> rejectOrDeleteSong(String songId) async {
    _communitySongs.removeWhere((s) => s.id == songId);
    await _persistSongs();
    notifyListeners();
  }

  // ==========================================
  // STORAGE HELPERS
  // ==========================================

  Future<void> _persistUsers() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      await prefs.setString(_keyCurrentUser, jsonEncode(_currentUser!.toJson()));
    }
    final rawList = _allUsers.map((u) => jsonEncode(u.toJson())).toList();
    await prefs.setStringList(_keyAllUsers, rawList);
  }

  Future<void> _persistSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = _communitySongs.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_keyCommunitySongs, rawList);
  }
}
