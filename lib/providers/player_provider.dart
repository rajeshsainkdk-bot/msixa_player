import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/equalizer_preset.dart';
import '../services/audio_player_service.dart';
import '../services/catalog_service.dart';
import '../services/storage_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();
  final CatalogService _catalogService = CatalogService();
  final StorageService _storageService = StorageService();

  // State collections
  List<Song> _trendingSongs = [];
  List<Playlist> _curatedPlaylists = [];
  List<Song> _searchResults = [];
  List<Song> _favorites = [];
  List<Song> _recentlyPlayed = [];
  List<Playlist> _customPlaylists = [];

  bool _isLoadingTrending = false;
  bool _isSearching = false;
  String _selectedGenre = 'All';

  // Playback state
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  // Sleep Timer
  Timer? _sleepTimer;
  int _sleepMinutesRemaining = 0;

  // Equalizer
  EqualizerPreset _currentEqPreset = EqualizerPreset.defaultPresets.first;
  List<double> _bandGains = [0.0, 0.0, 0.0, 0.0, 0.0];

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
  List<Song> get searchResults => _searchResults;
  List<Song> get favorites => _favorites;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  List<Playlist> get customPlaylists => _customPlaylists;

  bool get isLoadingTrending => _isLoadingTrending;
  bool get isSearching => _isSearching;
  String get selectedGenre => _selectedGenre;
  int get sleepMinutesRemaining => _sleepMinutesRemaining;
  EqualizerPreset get currentEqPreset => _currentEqPreset;
  List<double> get bandGains => _bandGains;

  PlayerProvider() {
    _init();
  }

  void _init() async {
    // 1. Listen to audio playback events
    _audioService.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
      notifyListeners();
    });

    _audioService.positionStream.listen((pos) {
      _currentPosition = pos;
      notifyListeners();
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

    // 2. Load cached persistence
    _favorites = await _storageService.loadFavorites();
    _recentlyPlayed = await _storageService.loadRecentlyPlayed();
    _customPlaylists = await _storageService.loadCustomPlaylists();
    final eqData = await _storageService.loadEqualizerSettings();
    final presetName = eqData['preset'] as String;
    _currentEqPreset = EqualizerPreset.defaultPresets.firstWhere(
      (p) => p.name == presetName,
      orElse: () => EqualizerPreset.defaultPresets.first,
    );
    _bandGains = List<double>.from(eqData['gains']);

    // 3. Load online catalog
    await refreshCatalog();
  }

  Future<void> refreshCatalog() async {
    _isLoadingTrending = true;
    notifyListeners();

    _trendingSongs = await _catalogService.fetchTrendingTracks();
    _curatedPlaylists = _catalogService.getCuratedPlaylists();

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

    _addToRecentlyPlayed(song);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    await _audioService.togglePlayPause();
    notifyListeners();
  }

  Future<void> seek(Duration pos) async {
    await _audioService.seek(pos);
  }

  Future<void> next() async {
    await _audioService.next();
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
    _storageService.saveFavorites(_favorites);
    notifyListeners();
  }

  bool isFavorite(String songId) {
    return _favorites.any((s) => s.id == songId);
  }

  void _addToRecentlyPlayed(Song song) {
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    _storageService.saveRecentlyPlayed(_recentlyPlayed);
    notifyListeners();
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

    _searchResults = await _catalogService.searchTracks(query);
    _syncFavoritesFlag(_searchResults);
    _isSearching = false;
    notifyListeners();
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
    _sleepTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
