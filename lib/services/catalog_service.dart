import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/playlist.dart';
import 'cloud_backend_service.dart';
import 'ai_artwork_service.dart';
import 'ai_music_service.dart';

class CatalogService {
  static const String _jamendoClientId = '56d30c95';
  static const String _jamendoBaseUrl = 'https://api.jamendo.com/v3.0';
  static const String _r2BaseUrl = 'https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/songs';

  /// Returns the built-in curated catalog of songs
  static List<Song> getCuratedSongs() => _curatedCatalog;

  /// 100% Real Authentic Indian Music Library (Bollywood, Punjabi, Sufi, Bhakti, Ghazal & Indie)
  /// Hosted on Cloudflare R2 with Zero-Egress Global CDN Live Streaming.
  static final List<Song> _curatedCatalog = [];

  /// Fetch initial trending tracks (dynamically combines curated and approved community tracks, strictly filtering deleted tracks)
  Future<List<Song>> fetchTrendingTracks() async {
    final backend = CloudBackendService();
    var approved = backend.approvedSongs;
    if (approved.isEmpty) {
      await backend.syncWithCloud(force: true);
      approved = backend.approvedSongs;
    }
    final deleted = backend.deletedSongIds;

    final Map<String, Song> map = {};
    for (final s in approved) {
      if (!deleted.contains(s.id)) {
        map[s.id] = s;
      }
    }
    for (final s in _curatedCatalog) {
      if (!deleted.contains(s.id) && !map.containsKey(s.id)) {
        map[s.id] = s;
      }
    }
    final list = map.values.toList();
    return AiMusicService().cleanAndOptimizeAll(list);
  }

  /// Filter tracks by selected genre
  Future<List<Song>> fetchTracksByGenre(String genre) async {
    final all = await fetchTrendingTracks();
    final lower = genre.toLowerCase().trim();
    if (lower == 'all' || lower == 'all indian') {
      return all;
    }
    return all.where((s) => s.genre.toLowerCase() == lower).toList();
  }

  /// Get categorized curated playlists
    /// Get playlists strictly based on Admin uploaded folders and Cloud R2 playlists
  List<Playlist> getCuratedPlaylists({List<Song>? songs}) {
    final backend = CloudBackendService();
    final deleted = backend.deletedSongIds;
    final baseSongs = songs ?? (backend.approvedSongs.isNotEmpty
        ? backend.approvedSongs.where((s) => !deleted.contains(s.id)).toList()
        : _curatedCatalog.where((s) => !deleted.contains(s.id)).toList());

    final List<Playlist> playlists = [];
    final Set<String> registeredPlaylistTitles = {};

    // 1. Include all remote Cloud Playlists uploaded to R2 db/playlists.json
    for (final pl in backend.cloudPlaylists) {
      if (pl.songs.isNotEmpty && registeredPlaylistTitles.add(pl.title.toLowerCase().trim())) {
        playlists.add(pl);
      }
    }

    // 2. Group by Admin Uploaded Folders / Categories
    final Map<String, List<Song>> folderMap = {};
    for (final s in baseSongs) {
      final cleanedSong = AiMusicService().cleanAndOptimizeSong(s);

      // Check subCategory (sub-folder name)
      final sub = cleanedSong.subCategory?.trim();
      if (sub != null && sub.isNotEmpty && sub.toLowerCase() != cleanedSong.genre.toLowerCase()) {
        folderMap.putIfAbsent(sub, () => []).add(cleanedSong);
      }

      // Check album if not generic (root folder name)
      final album = cleanedSong.album.trim();
      final isGenericAlbum = album.isEmpty ||
          album.toLowerCase() == 'msixa library' ||
          album.toLowerCase() == 'musixa library' ||
          album.toLowerCase() == 'unknown album' ||
          album.toLowerCase() == 'msixa cloud hits' ||
          album.toLowerCase() == 'jamendo free catalog' ||
          album.toLowerCase().endsWith('essentials');
      if (!isGenericAlbum && album != sub) {
        folderMap.putIfAbsent(album, () => []).add(cleanedSong);
      }
    }

    // Add each folder as a playlist
    for (final entry in folderMap.entries) {
      final title = entry.key;
      if (entry.value.isNotEmpty && registeredPlaylistTitles.add(title.toLowerCase().trim())) {
        final cover = entry.value.firstWhere(
          (s) => s.coverUrl.trim().startsWith('http'),
          orElse: () => entry.value.first,
        ).coverUrl;

        playlists.add(Playlist(
          id: 'pl_folder_${entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          title: title,
          description: 'Folder collection (${entry.value.length} tracks)',
          coverUrl: cover.startsWith('http') ? cover : AiArtworkService().getAiCoverForSong(entry.value.first),
          songs: entry.value,
        ));
      }
    }

    return playlists;
  }

  /// Search online/curated catalog with live search
  Future<List<Song>> searchTracks(String query) async {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return [];

    final all = await fetchTrendingTracks();
    return all.where((s) =>
        s.title.toLowerCase().contains(lower) ||
        s.artist.toLowerCase().contains(lower) ||
        s.album.toLowerCase().contains(lower) ||
        s.genre.toLowerCase().contains(lower) ||
        (s.subCategory != null && s.subCategory!.toLowerCase().contains(lower))).toList();
  }
}
