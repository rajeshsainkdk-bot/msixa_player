import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/playlist.dart';

class StorageService {
  static const String _keyFavorites = 'msixa_favorites';
  static const String _keyRecent = 'msixa_recently_played';
  static const String _keyCustomPlaylists = 'msixa_user_playlists';
  static const String _keyEqPreset = 'msixa_eq_preset';
  static const String _keyEqGains = 'msixa_eq_gains';

  Future<List<Song>> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyFavorites) ?? [];
      return list.map((item) => Song.fromJson(json.decode(item))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFavorites(List<Song> songs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = songs.map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_keyFavorites, list);
    } catch (_) {}
  }

  Future<List<Song>> loadRecentlyPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyRecent) ?? [];
      return list.map((item) => Song.fromJson(json.decode(item))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecentlyPlayed(List<Song> songs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only last 30 played songs
      final trimmed = songs.take(30).map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_keyRecent, trimmed);
    } catch (_) {}
  }

  Future<List<Playlist>> loadCustomPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyCustomPlaylists) ?? [];
      return list.map((item) => Playlist.fromJson(json.decode(item))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomPlaylists(List<Playlist> playlists) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = playlists.map((p) => json.encode(p.toJson())).toList();
      await prefs.setStringList(_keyCustomPlaylists, list);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> loadEqualizerSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presetName = prefs.getString(_keyEqPreset) ?? 'Flat';
      final gainsStr = prefs.getStringList(_keyEqGains);
      List<double> gains = [0.0, 0.0, 0.0, 0.0, 0.0];
      if (gainsStr != null && gainsStr.length == 5) {
        gains = gainsStr.map((e) => double.tryParse(e) ?? 0.0).toList();
      }
      return {'preset': presetName, 'gains': gains};
    } catch (_) {
      return {'preset': 'Flat', 'gains': [0.0, 0.0, 0.0, 0.0, 0.0]};
    }
  }

  Future<void> saveEqualizerSettings(String presetName, List<double> gains) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEqPreset, presetName);
      await prefs.setStringList(_keyEqGains, gains.map((e) => e.toString()).toList());
    } catch (_) {}
  }
}
