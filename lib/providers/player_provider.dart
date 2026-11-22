import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/equalizer_preset.dart';
import '../services/audio_player_service.dart';
import '../services/catalog_service.dart';
import '../services/storage_service.dart';
import '../services/device_audio_service.dart';
import '../services/cloud_backend_service.dart';
import '../services/ai_music_service.dart';
import '../services/song_artwork_resolver.dart';
import '../services/jiosaavn_service.dart';
import '../services/feedback_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();
  final CatalogService _catalogService = CatalogService();
  final StorageService _storageService = StorageService();
  final DeviceAudioService _deviceAudioService = DeviceAudioService();
  final JioSaavnService _saavnService = JioSaavnService();

  // State collections
  List<Song> _trendingSongs = [];
  List<Playlist> _curatedPlaylists = [];
  List<Song> _searchResults = [];
  List<Song> _favorites = [];
  List<Song> _recentlyPlayed = [];
  List<Playlist> _customPlaylists = [];
  List<Song> _deviceSongs = [];
  Map<String, int> _playCounts = {};

  // Online Streaming State (Ultra HD 320kbps)
  List<Song> _onlineSearchResults = [];
  bool _isSearchingOnline = false;
  List<Song> _onlineTrendingSongs = [];
  List<Song> _onlineGlobalSongs = [];
  List<Song> _onlineRomanticSongs = [];
  List<Song> _onlinePunjabiSongs = [];
  List<Song> _onlineBhaktiSongs = [];
  List<Song> _onlineDjSongs = [];
  List<Song> _onlineHaryanviSongs = [];
  List<Song> _onlineRajasthaniSongs = [];
  List<Song> _onlineMarwadiSongs = [];
  List<Song> _onlineBhojpuriSongs = [];
  List<Song> _onlineRetroSongs = [];
  List<Song> _onlineLofiSongs = [];
  List<Song> _onlineSadSongs = [];
  bool _isLoadingOnlineTrending = false;

  bool _isLoadingTrending = false;
  bool _isSearching = false;
  bool _isScanningDevice = false;
  bool _hasDevicePermission = false;
  String _selectedGenre = 'All';

  // Playback state
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  // Sleep Timer & Cloud Sync
  Timer? _sleepTimer;
  Timer? _cloudSyncTimer;
  int _sleepMinutesRemaining = 0;

  // Equalizer
  EqualizerPreset _currentEqPreset = EqualizerPreset.defaultPresets.first;
  List<double> _bandGains = [0.0, 0.0, 0.0, 0.0, 0.0];

  List<Artist> _cachedArtists = [];
  List<Album> _cachedAlbums = [];
  DateTime _lastPositionNotify = DateTime.fromMillisecondsSinceEpoch(0);

  // Getters
  Song? get currentSong => _audioService.currentSong;
  List<Song> get queue => _audioService.queue;
  int get currentIndex => _audioService.currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  Duration get bufferedPosition => _bufferedPosition;
  RepeatMode get repeatMode => _audioService.repeatMode;
  bool get isShuffle => _audioService.isShuffle;
  double get speed => _audioService.speed;
  double get volume => _audioService.volume;

  List<Song> get trendingSongs => _trendingSongs;
  List<Playlist> get curatedPlaylists => _curatedPlaylists;
  List<Artist> get artists => _cachedArtists;
  List<Album> get albums => _cachedAlbums;
  List<Song> get searchResults => _searchResults;
  List<Song> get favorites => _favorites;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  Map<String, int> get playCounts => _playCounts;
  int getPlayCount(String songId) => _playCounts[songId] ?? 0;
  List<Playlist> get customPlaylists => _customPlaylists;
  List<Song> get deviceSongs => _deviceSongs;
  List<Song> get onlineSearchResults => _onlineSearchResults;
  bool get isSearchingOnline => _isSearchingOnline;
  List<Song> get onlineTrendingSongs => _onlineTrendingSongs;
  List<Song> get onlineGlobalSongs => _onlineGlobalSongs;
  List<Song> get onlineRomanticSongs => _onlineRomanticSongs;
  List<Song> get onlinePunjabiSongs => _onlinePunjabiSongs;
  List<Song> get onlineBhaktiSongs => _onlineBhaktiSongs;
  List<Song> get onlineDjSongs => _onlineDjSongs;
  List<Song> get onlineHaryanviSongs => _onlineHaryanviSongs;
  List<Song> get onlineRajasthaniSongs => _onlineRajasthaniSongs;
  List<Song> get onlineMarwadiSongs => _onlineMarwadiSongs;
  List<Song> get onlineBhojpuriSongs => _onlineBhojpuriSongs;
  List<Song> get onlineRetroSongs => _onlineRetroSongs;
  List<Song> get onlineLofiSongs => _onlineLofiSongs;
  List<Song> get onlineSadSongs => _onlineSadSongs;
  bool get isLoadingOnlineTrending => _isLoadingOnlineTrending;

  bool get isLoadingTrending => _isLoadingTrending;
  bool get isSearching => _isSearching;
  bool get isScanningDevice => _isScanningDevice;
  bool get hasDevicePermission => _hasDevicePermission;
  String get selectedGenre => _selectedGenre;
  int get sleepMinutesRemaining => _sleepMinutesRemaining;
  EqualizerPreset get currentEqPreset => _currentEqPreset;
  List<double> get bandGains => _bandGains;

  // Stream getters for targeted widget progress updates without full-screen rebuilds
  Stream<Duration> get positionStream => _audioService.positionStream;
  Stream<Duration?> get durationStream => _audioService.durationStream;
  Stream<Duration> get bufferedPositionStream => _audioService.bufferedPositionStream;

  PlayerProvider() {
    _init();
    // Realtime synchronization: listen to CloudBackendService so admin additions & deletions update user player immediately
    CloudBackendService().addListener(_onBackendCatalogUpdated);

    // Periodic cloud poll every 30 seconds so User app detects song updates without hammering battery/radio
    _cloudSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      CloudBackendService().syncSharedData();
    });
  }

  void _onBackendCatalogUpdated() {
    refreshCatalog();
  }

  void _init() async {
    // 1. Listen to audio playback events with infinite-loading protection watchdog
    Timer? bufferingWatchdog;
    _audioService.playerStateStream.listen((state) async {
      final isCompleted = state.processingState == ProcessingState.completed;
      if (isCompleted) {
        final count = await _storageService.incrementCompletedSongsCount();
        if (count >= 5 && !(await _storageService.hasSubmittedFeedback())) {
          FeedbackService.triggerPromptNotifier.value = count;
        }
      }
      _isPlaying = state.playing && !isCompleted;
      _isBuffering = (state.processingState == ProcessingState.buffering ||
              state.processingState == ProcessingState.loading) &&
          !isCompleted;

      bufferingWatchdog?.cancel();
      if (_isBuffering) {
        bufferingWatchdog = Timer(const Duration(seconds: 8), () {
          if (_isBuffering) {
            _isBuffering = false;
            notifyListeners();
          }
        });
      }
      notifyListeners();
    });

    _audioService.positionStream.listen((pos) {
      _currentPosition = pos;
      // Note: We deliberately do NOT call notifyListeners() on position ticks!
      // Position updates are consumed reactively via positionStream StreamBuilder
      // in MiniPlayer and NowPlayingScreen. This completely prevents full-screen rebuilds
      // and ensures 100% fluid, jank-free 60-120 FPS scrolling while music plays!
    });

    _audioService.durationStream.listen((dur) {
      if (dur != null) {
        _totalDuration = dur;
        notifyListeners();
      }
    });

    _audioService.bufferedPositionStream.listen((buf) {
      _bufferedPosition = buf;
      notifyListeners();
    });

    _audioService.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _audioService.queue.length) {
        final s = _audioService.queue[index];
        _playCounts[s.id] = (_playCounts[s.id] ?? 0) + 1;
        _storageService.incrementPlayCount(s.id);
        _addToRecentlyPlayed(s);
      }
      notifyListeners();
    });

    // 0. Seed memory catalog immediately for instant sub-second cold start!
    if (_trendingSongs.isEmpty) {
      _trendingSongs = List.from(CatalogService.getCuratedSongs());
      _cachedArtists = AiMusicService().extractArtists(_trendingSongs);
      _cachedAlbums = AiMusicService().extractAlbums(_trendingSongs);
    }

    // 2. Load cached persistence concurrently with Future.wait
    final currentUserPhone = CloudBackendService().currentUser?.phoneNumber;
    final results = await Future.wait([
      _storageService.loadFavorites(currentUserPhone),
      _storageService.loadRecentlyPlayed(currentUserPhone),
      _storageService.loadCustomPlaylists(currentUserPhone),
      _storageService.loadEqualizerSettings(),
      _storageService.loadPlayCounts(),
      _loadCachedOnlineSections(), // Awaited in parallel so songs are ready in RAM on frame 1 with ZERO blink!
    ]);
    _favorites = results[0] as List<Song>;
    _recentlyPlayed = results[1] as List<Song>;
    _customPlaylists = results[2] as List<Playlist>;
    final eqData = results[3] as Map<String, dynamic>;
    _playCounts = results[4] as Map<String, int>;
    final presetName = eqData['preset'] as String;
    _currentEqPreset = EqualizerPreset.defaultPresets.firstWhere(
      (p) => p.name == presetName,
      orElse: () => EqualizerPreset.defaultPresets.first,
    );
    _bandGains = List<double>.from(eqData['gains']);

    // 3. Scan device audio in background so initial UI rendering is 0ms instantaneous!
    _hasDevicePermission = await _deviceAudioService.hasPermission();
    if (_hasDevicePermission) {
      Future.microtask(() async {
        _deviceSongs = await _deviceAudioService.scanDeviceSongs();
        _syncFavoritesFlag(_deviceSongs);
        notifyListeners();
      });
    }

    // Notify listeners once with fully initialized cached data for a smooth, single-pass render
    notifyListeners();

    // 4. Load online catalog in background without blocking UI startup or blinking
    Future.microtask(() => refreshCatalog());
  }

  /// Called immediately when a user registers or logs in on any device
  Future<void> onUserAuthenticated() async {
    final backend = CloudBackendService();
    await backend.syncWithCloud();
    await refreshCatalog();
    final currentUserPhone = backend.currentUser?.phoneNumber;
    _favorites = await _storageService.loadFavorites(currentUserPhone);
    _recentlyPlayed = await _storageService.loadRecentlyPlayed(currentUserPhone);
    _customPlaylists = await _storageService.loadCustomPlaylists(currentUserPhone);
    _syncFavoritesFlag(_trendingSongs);
    notifyListeners();
  }

  /// Scan local songs from device storage folders
  Future<void> scanDeviceSongs() async {
    _isScanningDevice = true;
    notifyListeners();

    _deviceSongs = await _deviceAudioService.scanDeviceSongs();
    _hasDevicePermission = await _deviceAudioService.hasPermission();
    _syncFavoritesFlag(_deviceSongs);

    _isScanningDevice = false;
    notifyListeners();
  }

  Future<void> refreshCatalog() async {
    // Only set _isLoadingTrending = true if we have zero songs in memory!
    // If tracks are already present, refresh silently in the background with ZERO flicker/blink!
    if (_trendingSongs.isEmpty) {
      _isLoadingTrending = true;
      notifyListeners();
    }

    final backend = CloudBackendService();

    // If backend has no songs yet on startup/new device, explicitly trigger cloud sync!
    if (backend.approvedSongs.isEmpty) {
      await backend.syncWithCloud(force: true, forceNotify: true);
    }

    final deleted = backend.deletedSongIds;

    _trendingSongs = await _catalogService.fetchTrendingTracks();
    _curatedPlaylists = _catalogService.getCuratedPlaylists(songs: _trendingSongs);

    // Cache artists and albums so getters don't loop/regex on 438 songs during playback!
    _cachedArtists = AiMusicService().extractArtists(_trendingSongs);
    _cachedAlbums = AiMusicService().extractAlbums(_trendingSongs);

    // If currently playing song was deleted by admin, immediately stop playback!
    if (_audioService.currentSong != null && deleted.contains(_audioService.currentSong!.id)) {
      await _audioService.stop();
    }

    // Purge deleted songs from favorites and recent history
    _favorites.removeWhere((s) => deleted.contains(s.id));
    _recentlyPlayed.removeWhere((s) => deleted.contains(s.id));

    // Also purge deleted songs from custom playlists
    for (final pl in _customPlaylists) {
      pl.songs.removeWhere((s) => deleted.contains(s.id));
    }

    _syncFavoritesFlag(_trendingSongs);
    _isLoadingTrending = false;
    notifyListeners();
  }

  void _syncFavoritesFlag(List<Song> songs) {
    final favIds = _favorites.map((f) => f.id).toSet();
    for (var song in songs) {
      song.isFavorite = favIds.contains(song.id);
    }
  }

  // Playback Controls
  Future<void> playSong(Song song, {List<Song>? queueContext}) async {
    if (queueContext != null) {
      final index = queueContext.indexWhere((s) => s.id == song.id);
      await _audioService.setQueue(queueContext, initialIndex: index != -1 ? index : 0);
    } else {
      await _audioService.playSong(song);
    }

    _playCounts[song.id] = (_playCounts[song.id] ?? 0) + 1;
    _storageService.incrementPlayCount(song.id);
    CloudBackendService().recordSongPlay(song);
    _addToRecentlyPlayed(song);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    await _audioService.togglePlayPause();
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioService.pause();
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioService.stop();
    notifyListeners();
  }

  Future<void> seek(Duration pos) async {
    _currentPosition = pos;
    _lastPositionNotify = DateTime.now();
    notifyListeners();
    await _audioService.seek(pos);
  }

  Future<void> next() async {
    await _audioService.next(autoLoop: true);
    if (currentSong != null) {
      _addToRecentlyPlayed(currentSong!);
    }
    notifyListeners();
  }

  Future<void> previous() async {
    await _audioService.previous();
    if (currentSong != null) {
      _addToRecentlyPlayed(currentSong!);
    }
    notifyListeners();
  }

  void toggleRepeat() {
    _audioService.toggleRepeatMode();
    notifyListeners();
  }

  void toggleShuffle() {
    _audioService.toggleShuffle();
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    await _audioService.setSpeed(speed);
    notifyListeners();
  }

  Future<void> setVolume(double vol) async {
    await _audioService.setVolume(vol);
    notifyListeners();
  }

  /// Reload user-specific data (favorites, playlists, history) upon login / account recovery
  Future<void> reloadUserData([String? userPhone]) async {
    final phone = userPhone ?? CloudBackendService().currentUser?.phoneNumber;
    _favorites = await _storageService.loadFavorites(phone);
    _recentlyPlayed = await _storageService.loadRecentlyPlayed(phone);
    _customPlaylists = await _storageService.loadCustomPlaylists(phone);
    _syncFavoritesFlag(_trendingSongs);
    _syncFavoritesFlag(_deviceSongs);
    notifyListeners();
  }

  // Favorite Management
  void toggleFavorite(Song song) {
    final index = _favorites.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      _favorites.removeAt(index);
      song.isFavorite = false;
    } else {
      song.isFavorite = true;
      _favorites.insert(0, song);
    }
    _storageService.saveFavorites(
      _favorites,
      CloudBackendService().currentUser?.phoneNumber,
    );
    notifyListeners();
  }

  bool isFavorite(String songId) {
    return _favorites.any((s) => s.id == songId);
  }

  void _addToRecentlyPlayed(Song song) {
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    _storageService.saveRecentlyPlayed(
      _recentlyPlayed,
      CloudBackendService().currentUser?.phoneNumber,
    );
    notifyListeners();
  }

  // User Custom Playlists Management
  void createPlaylist(String title, [List<Song>? initialSongs]) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return;

    // Prevent duplicate playlist names: if already exists, append new songs to it
    final existingIdx = _customPlaylists.indexWhere(
      (p) => p.title.trim().toLowerCase() == cleanTitle.toLowerCase(),
    );

    if (existingIdx != -1) {
      if (initialSongs != null && initialSongs.isNotEmpty) {
        final existing = _customPlaylists[existingIdx];
        final existingIds = existing.songs.map((s) => s.id).toSet();
        final newSongs = initialSongs.where((s) => !existingIds.contains(s.id)).toList();
        if (newSongs.isNotEmpty) {
          final updatedSongs = [...existing.songs, ...newSongs];
          _customPlaylists[existingIdx] = existing.copyWith(
            songs: updatedSongs,
            coverUrl: existing.coverUrl.isNotEmpty ? existing.coverUrl : newSongs.first.displayCoverUrl,
          );
          _storageService.saveCustomPlaylists(
            _customPlaylists,
            CloudBackendService().currentUser?.phoneNumber,
          );
          notifyListeners();
        }
      }
      return;
    }

    final newPlaylist = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: cleanTitle,
      description: 'Created by you',
      coverUrl: initialSongs?.isNotEmpty == true
          ? initialSongs!.first.displayCoverUrl
          : SongArtworkResolver.resolveArtwork(title: cleanTitle, artist: 'Playlist'),
      songs: initialSongs ?? [],
    );
    _customPlaylists.insert(0, newPlaylist);
    _storageService.saveCustomPlaylists(
      _customPlaylists,
      CloudBackendService().currentUser?.phoneNumber,
    );
    notifyListeners();
  }

  void addSongToPlaylist(String playlistId, Song song) {
    final index = _customPlaylists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final pl = _customPlaylists[index];
      if (!pl.songs.any((s) => s.id == song.id)) {
        final updatedSongs = List<Song>.from(pl.songs)..add(song);
        _customPlaylists[index] = Playlist(
          id: pl.id,
          title: pl.title,
          description: pl.description,
          coverUrl: pl.coverUrl.isNotEmpty ? pl.coverUrl : song.coverUrl,
          songs: updatedSongs,
        );
        _storageService.saveCustomPlaylists(
          _customPlaylists,
          CloudBackendService().currentUser?.phoneNumber,
        );
        notifyListeners();
      }
    }
  }

  void removePlaylist(String playlistId) {
    _customPlaylists.removeWhere((p) => p.id == playlistId);
    _storageService.saveCustomPlaylists(
      _customPlaylists,
      CloudBackendService().currentUser?.phoneNumber,
    );
    notifyListeners();
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    final index = _customPlaylists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final pl = _customPlaylists[index];
      final updatedSongs = pl.songs.where((s) => s.id != songId).toList();
      _customPlaylists[index] = Playlist(
        id: pl.id,
        title: pl.title,
        description: pl.description,
        coverUrl: updatedSongs.isNotEmpty ? updatedSongs.first.coverUrl : pl.coverUrl,
        songs: updatedSongs,
      );
      _storageService.saveCustomPlaylists(
        _customPlaylists,
        CloudBackendService().currentUser?.phoneNumber,
      );
      notifyListeners();
    }
  }

  // Search & Filtering
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    final catalogResults = await _catalogService.searchTracks(query);
    final lower = query.toLowerCase().trim();
    final deviceResults = _deviceSongs.where((s) =>
        s.title.toLowerCase().contains(lower) ||
        s.artist.toLowerCase().contains(lower) ||
        s.album.toLowerCase().contains(lower) ||
        s.genre.toLowerCase().contains(lower) ||
        (s.subCategory != null && s.subCategory!.toLowerCase().contains(lower))).toList();

    _searchResults = [...catalogResults, ...deviceResults];
    _syncFavoritesFlag(_searchResults);
    _isSearching = false;
    notifyListeners();
  }

  /// Live Search on JioSaavn database with millions of online streaming songs
  Future<void> searchOnline(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      _onlineSearchResults = [];
      _isSearchingOnline = false;
      notifyListeners();
      return;
    }

    _isSearchingOnline = true;
    notifyListeners();

    try {
      _onlineSearchResults = await _saavnService.searchSongs(clean);
      _syncFavoritesFlag(_onlineSearchResults);
    } catch (e) {
      debugPrint('Error searching online JioSaavn: $e');
      _onlineSearchResults = [];
    }

    _isSearchingOnline = false;
    notifyListeners();
  }

  /// Load Today's Trending Hits, Global Top 50, Regional & Curated Sections
  Future<void> loadOnlineTrending({bool forceRefresh = false}) async {
    final hasData = _onlineTrendingSongs.isNotEmpty &&
        _onlineGlobalSongs.isNotEmpty &&
        _onlineRomanticSongs.isNotEmpty &&
        _onlinePunjabiSongs.isNotEmpty &&
        _onlineBhaktiSongs.isNotEmpty &&
        _onlineDjSongs.isNotEmpty &&
        _onlineHaryanviSongs.isNotEmpty &&
        _onlineRajasthaniSongs.isNotEmpty &&
        _onlineMarwadiSongs.isNotEmpty;

    // If data is already in memory from disk cache, update silently in background with ZERO UI flicker or blink!
    if (hasData && !forceRefresh) {
      _fetchOnlineTrendingSilently();
      return;
    }

    if (!hasData) {
      _isLoadingOnlineTrending = true;
      notifyListeners();
    }

    await _fetchOnlineTrendingSilently();
    _isLoadingOnlineTrending = false;
    notifyListeners();
  }

  Future<void> _fetchOnlineTrendingSilently() async {
    try {
      final futures = await Future.wait([
        _saavnService.getTrendingToday(),
        _saavnService.getGlobalTop50(),
        _saavnService.getRomanticTop50(),
        _saavnService.getPunjabiTop50(),
        _saavnService.getBhaktiTop50(),
        _saavnService.getDjRemixTop50(),
        _saavnService.getHaryanviTop50(),
        _saavnService.getRajasthaniTop50(),
        _saavnService.getMarwadiHits(),
        _saavnService.getBhojpuriTop50(),
        _saavnService.get90sRetroTop50(),
        _saavnService.getLofiHits(),
        _saavnService.getSadSongsTop50(),
      ]);

      // 🔥 TRENDING NOW: Strictly the Top 50 songs most played across all users combined!
      _onlineTrendingSongs = await CloudBackendService().getGlobalTop50TrendingSongs(
        candidatePool: futures[0],
      );
      if (futures[1].isNotEmpty) _onlineGlobalSongs = futures[1];
      if (futures[2].isNotEmpty) _onlineRomanticSongs = futures[2];
      if (futures[3].isNotEmpty) _onlinePunjabiSongs = futures[3];
      if (futures[4].isNotEmpty) _onlineBhaktiSongs = futures[4];
      if (futures[5].isNotEmpty) _onlineDjSongs = futures[5];
      if (futures[6].isNotEmpty) _onlineHaryanviSongs = futures[6];
      if (futures[7].isNotEmpty) _onlineRajasthaniSongs = futures[7];
      if (futures[8].isNotEmpty) _onlineMarwadiSongs = futures[8];
      if (futures[9].isNotEmpty) _onlineBhojpuriSongs = futures[9];
      if (futures[10].isNotEmpty) _onlineRetroSongs = futures[10];
      if (futures[11].isNotEmpty) _onlineLofiSongs = futures[11];
      if (futures[12].isNotEmpty) _onlineSadSongs = futures[12];

      _syncFavoritesFlag(_onlineTrendingSongs);
      _syncFavoritesFlag(_onlineGlobalSongs);
      _syncFavoritesFlag(_onlineRomanticSongs);
      _syncFavoritesFlag(_onlinePunjabiSongs);
      _syncFavoritesFlag(_onlineBhaktiSongs);
      _syncFavoritesFlag(_onlineDjSongs);
      _syncFavoritesFlag(_onlineHaryanviSongs);
      _syncFavoritesFlag(_onlineRajasthaniSongs);
      _syncFavoritesFlag(_onlineMarwadiSongs);
      _syncFavoritesFlag(_onlineBhojpuriSongs);
      _syncFavoritesFlag(_onlineRetroSongs);
      _syncFavoritesFlag(_onlineLofiSongs);
      _syncFavoritesFlag(_onlineSadSongs);

      _saveCachedOnlineSections();
    } catch (e) {
      debugPrint('Error loading online streaming sections: $e');
    }
  }

  Future<void> _loadCachedOnlineSections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trRaw = prefs.getString('cache_online_trending');
      final glRaw = prefs.getString('cache_online_global');
      final roRaw = prefs.getString('cache_online_romantic');
      final puRaw = prefs.getString('cache_online_punjabi');
      final bhRaw = prefs.getString('cache_online_bhakti');
      final djRaw = prefs.getString('cache_online_dj');
      final hrRaw = prefs.getString('cache_online_haryanvi');
      final rjRaw = prefs.getString('cache_online_rajasthani');
      final mwRaw = prefs.getString('cache_online_marwadi');
      final bpRaw = prefs.getString('cache_online_bhojpuri');
      final rtRaw = prefs.getString('cache_online_retro');
      final lfRaw = prefs.getString('cache_online_lofi');
      final sdRaw = prefs.getString('cache_online_sad');

      if (trRaw != null) _onlineTrendingSongs = _restoreSongsFromCache(trRaw);
      if (glRaw != null) _onlineGlobalSongs = _restoreSongsFromCache(glRaw);
      if (roRaw != null) _onlineRomanticSongs = _restoreSongsFromCache(roRaw);
      if (puRaw != null) _onlinePunjabiSongs = _restoreSongsFromCache(puRaw);
      if (bhRaw != null) _onlineBhaktiSongs = _restoreSongsFromCache(bhRaw);
      if (djRaw != null) _onlineDjSongs = _restoreSongsFromCache(djRaw);
      if (hrRaw != null) _onlineHaryanviSongs = _restoreSongsFromCache(hrRaw);
      if (rjRaw != null) _onlineRajasthaniSongs = _restoreSongsFromCache(rjRaw);
      if (mwRaw != null) _onlineMarwadiSongs = _restoreSongsFromCache(mwRaw);
      if (bpRaw != null) _onlineBhojpuriSongs = _restoreSongsFromCache(bpRaw);
      if (rtRaw != null) _onlineRetroSongs = _restoreSongsFromCache(rtRaw);
      if (lfRaw != null) _onlineLofiSongs = _restoreSongsFromCache(lfRaw);
      if (sdRaw != null) _onlineSadSongs = _restoreSongsFromCache(sdRaw);

      if (_onlineTrendingSongs.isNotEmpty || _onlineHaryanviSongs.isNotEmpty) {
        _syncFavoritesFlag(_onlineTrendingSongs);
        _syncFavoritesFlag(_onlineGlobalSongs);
        _syncFavoritesFlag(_onlineRomanticSongs);
        _syncFavoritesFlag(_onlinePunjabiSongs);
        _syncFavoritesFlag(_onlineBhaktiSongs);
        _syncFavoritesFlag(_onlineDjSongs);
        _syncFavoritesFlag(_onlineHaryanviSongs);
        _syncFavoritesFlag(_onlineRajasthaniSongs);
        _syncFavoritesFlag(_onlineMarwadiSongs);
        _syncFavoritesFlag(_onlineBhojpuriSongs);
        _syncFavoritesFlag(_onlineRetroSongs);
        _syncFavoritesFlag(_onlineLofiSongs);
        _syncFavoritesFlag(_onlineSadSongs);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached online sections: $e');
    }
  }

  Future<void> _saveCachedOnlineSections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_onlineTrendingSongs.isNotEmpty) {
        prefs.setString('cache_online_trending', jsonEncode(_onlineTrendingSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlineGlobalSongs.isNotEmpty) {
        prefs.setString('cache_online_global', jsonEncode(_onlineGlobalSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlineRomanticSongs.isNotEmpty) {
        prefs.setString('cache_online_romantic', jsonEncode(_onlineRomanticSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlinePunjabiSongs.isNotEmpty) {
        prefs.setString('cache_online_punjabi', jsonEncode(_onlinePunjabiSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlineBhaktiSongs.isNotEmpty) {
        prefs.setString('cache_online_bhakti', jsonEncode(_onlineBhaktiSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlineDjSongs.isNotEmpty) {
        prefs.setString('cache_online_dj', jsonEncode(_onlineDjSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlineHaryanviSongs.isNotEmpty) {
        prefs.setString('cache_online_haryanvi', jsonEncode(_onlineHaryanviSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlineRajasthaniSongs.isNotEmpty) {
        prefs.setString('cache_online_rajasthani', jsonEncode(_onlineRajasthaniSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlineMarwadiSongs.isNotEmpty) {
        prefs.setString('cache_online_marwadi', jsonEncode(_onlineMarwadiSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlineBhojpuriSongs.isNotEmpty) {
        prefs.setString('cache_online_bhojpuri', jsonEncode(_onlineBhojpuriSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlineRetroSongs.isNotEmpty) {
        prefs.setString('cache_online_retro', jsonEncode(_onlineRetroSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlineLofiSongs.isNotEmpty) {
        prefs.setString('cache_online_lofi', jsonEncode(_onlineLofiSongs.map((s) => s.toJson()).toList()));
      }
      if (_onlineSadSongs.isNotEmpty) {
        prefs.setString('cache_online_sad', jsonEncode(_onlineSadSongs.map((s) => s.toJson()).toList()));
      }
    } catch (e) {
      debugPrint('Error saving cached online sections: $e');
    }
  }

  List<Song> _restoreSongsFromCache(String rawJson) {
    try {
      final list = jsonDecode(rawJson) as List? ?? [];
      return list.map((item) => Song.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> selectGenre(String genre) async {
    _selectedGenre = genre;
    _isLoadingTrending = true;
    notifyListeners();

    if (genre == 'All') {
      _trendingSongs = await _catalogService.fetchTrendingTracks();
    } else {
      _trendingSongs = await _catalogService.fetchTracksByGenre(genre);
    }
    _syncFavoritesFlag(_trendingSongs);
    _isLoadingTrending = false;
    notifyListeners();
  }

  // Sleep Timer
  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      _sleepMinutesRemaining = 0;
      notifyListeners();
      return;
    }

    _sleepMinutesRemaining = minutes;
    notifyListeners();

    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_sleepMinutesRemaining > 1) {
        _sleepMinutesRemaining--;
        notifyListeners();
      } else {
        _sleepMinutesRemaining = 0;
        _audioService.pause();
        timer.cancel();
        notifyListeners();
      }
    });
  }

  // Equalizer
  void setEqPreset(EqualizerPreset preset) {
    _currentEqPreset = preset;
    _bandGains = List<double>.from(preset.bandGains);
    _storageService.saveEqualizerSettings(preset.name, _bandGains);
    notifyListeners();
  }

  void updateBandGain(int index, double gain) {
    if (index >= 0 && index < _bandGains.length) {
      _bandGains[index] = gain;
      _currentEqPreset = const EqualizerPreset(name: 'Custom', bandGains: []);
      _storageService.saveEqualizerSettings('Custom', _bandGains);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cloudSyncTimer?.cancel();
    _sleepTimer?.cancel();
    CloudBackendService().removeListener(_onBackendCatalogUpdated);
    _audioService.dispose();
    super.dispose();
  }
}
