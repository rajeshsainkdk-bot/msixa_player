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
  static final List<Song> _curatedCatalog = [
    // ==========================================================
    // 1. BHAKTI, DEVOTIONAL & SPIRITUAL MANTRAS
    // ==========================================================
    Song(
      id: 'msixa_bhakti_01',
      title: 'Sankat Mochan Hanuman Ashtak',
      artist: 'Hariharan',
      album: 'Shree Hanuman Amritwani',
      duration: 236,
      streamUrl: '$_r2BaseUrl/sankat_mochan_hanuman_ashtak.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
      genre: 'Bhakti',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Devotional Master Library',
    ),
    Song(
      id: 'msixa_bhakti_02',
      title: 'Ye Chamak Ye Damak (Sab Kuch Sarkar Tumhi Se)',
      artist: 'Sudhir Vyas',
      album: 'Sab Kuch Sarkar Tumhi Se Hai',
      duration: 228,
      streamUrl: '$_r2BaseUrl/ye_chamak_ye_damak.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=600&q=80',
      genre: 'Bhakti',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Devotional Master Library',
    ),
    Song(
      id: 'msixa_bhakti_03',
      title: 'Powerful Hanuman Chalisa',
      artist: 'Sai Charan Bhaskaruni',
      album: 'HanuMan Original Motion Picture',
      duration: 234,
      streamUrl: '$_r2BaseUrl/powerful_hanuman_chalisa.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=600&q=80',
      genre: 'Bhakti',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Devotional Master Library',
    ),
    Song(
      id: 'msixa_bhakti_04',
      title: 'Ram Siya Ram',
      artist: 'Sachet Tandon & Parampara Tandon',
      album: 'Adipurush Soundscapes',
      duration: 230,
      streamUrl: '$_r2BaseUrl/ram_siya_ram.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
      genre: 'Bollywood',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Bollywood Master Library',
    ),
    Song(
      id: 'msixa_bhakti_05',
      title: 'Radhe Tere Charno Ki Dhool',
      artist: 'Bhumika Sharma',
      album: 'Krishna Bhajan Amrit 2025',
      duration: 290,
      streamUrl: '$_r2BaseUrl/radhe_tere_charno_ki_dhool.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
      genre: 'Bhakti',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Devotional Master Library',
    ),
    Song(
      id: 'msixa_bhakti_06',
      title: 'Bajrang Baan Lofi (11 Baar Non-Stop)',
      artist: 'Rasraj Ji Maharaj',
      album: 'Divine Lo-Fi Chants',
      duration: 1412,
      streamUrl: '$_r2BaseUrl/bajrang_baan_lofi.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
      genre: 'Desi Lo-Fi',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Devotional Lo-Fi Library',
    ),
    Song(
      id: 'msixa_bhakti_07',
      title: 'Aadesh Hanuman (Alakh Niranjan)',
      artist: 'Baba Gorakhnath Parampara',
      album: 'Powerful Hanuman Stotra',
      duration: 245,
      streamUrl: '$_r2BaseUrl/aadesh_hanuman.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1506461883276-594a12b11cf3?w=600&q=80',
      genre: 'Spiritual',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Spiritual Master Library',
    ),
    Song(
      id: 'msixa_bhakti_08',
      title: 'Alakh Niranjan (Aghori Trance)',
      artist: 'Aghori Music',
      album: 'Tandav Spiritual Vibes',
      duration: 485,
      streamUrl: '$_r2BaseUrl/alakh_niranjan_aghori.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      genre: 'Spiritual',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Spiritual Master Library',
    ),
    Song(
      id: 'msixa_bhakti_09',
      title: 'Powerful Siddh Shabar Mantra',
      artist: 'Baba Gorakhnath Tradition',
      album: 'Siddh Shabar Sangrah',
      duration: 350,
      streamUrl: '$_r2BaseUrl/siddh_shabar_mantra.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=600&q=80',
      genre: 'Spiritual',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Spiritual Master Library',
    ),

    // ==========================================================
    // 2. SUFI, PUNJABI & CLASSIC SOUL (SATINDER SARTAAJ)
    // ==========================================================
    Song(
      id: 'msixa_punjabi_01',
      title: 'Guzarish (गुज़ारिश)',
      artist: 'Satinder Sartaaj',
      album: 'Shayar Soul Tracks',
      duration: 220,
      streamUrl: '$_r2BaseUrl/guzarish_sartaaj.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      genre: 'Sufi',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Sufi Master Library',
    ),
    Song(
      id: 'msixa_punjabi_02',
      title: 'Udaarian (Badi Lambi Hai Kahani)',
      artist: 'Satinder Sartaaj',
      album: 'Seasons of Sartaaj',
      duration: 242,
      streamUrl: '$_r2BaseUrl/udaarian.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=600&q=80',
      genre: 'Punjabi',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Punjabi Master Library',
    ),
    Song(
      id: 'msixa_punjabi_03',
      title: 'Sajjan Raazi',
      artist: 'Satinder Sartaaj',
      album: 'Sajjan Raazi Romantic Sufi',
      duration: 232,
      streamUrl: '$_r2BaseUrl/sajjan_raazi.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
      genre: 'Sufi',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Sufi Master Library',
    ),
    Song(
      id: 'msixa_punjabi_04',
      title: 'Tere Bina Na Guzara',
      artist: 'Satinder Sartaaj & Neeru Bajwa',
      album: 'Shayar Emotional Tracks',
      duration: 185,
      streamUrl: '$_r2BaseUrl/tere_bina_na_guzara.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      genre: 'Punjabi',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Punjabi Master Library',
    ),
    Song(
      id: 'msixa_punjabi_05',
      title: 'Jaiye Sajana',
      artist: 'Satinder Sartaaj, Shashwat Sachdev, Jasmine Sandlas',
      album: 'Dhurandhar Soundtrack',
      duration: 195,
      streamUrl: '$_r2BaseUrl/jaiye_sajana.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80',
      genre: 'Bollywood',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Bollywood Master Library',
    ),
    Song(
      id: 'msixa_punjabi_06',
      title: 'Best Punjabi Hits Jukebox',
      artist: 'Satinder Sartaaj',
      album: 'Sartaaj Live & Studio Classics',
      duration: 980,
      streamUrl: '$_r2BaseUrl/satinder_sartaaj_jukebox.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80',
      genre: 'Punjabi',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Punjabi Master Library',
    ),

    // ==========================================================
    // 3. INDIE, GHAZAL & HEARTFELT CLASSICS
    // ==========================================================
    Song(
      id: 'msixa_indie_01',
      title: 'Intezaar Reh Gya (Pain in Love)',
      artist: 'Vibe Chapters',
      album: 'Broken Hearts Chapter 1',
      duration: 178,
      streamUrl: '$_r2BaseUrl/intezaar_reh_gya.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      genre: 'Indie Pop',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Indie Master Library',
    ),
    Song(
      id: 'msixa_indie_02',
      title: 'Kagaz Ki Kashti Dariya Hai Gehra',
      artist: 'Jagjit Singh & Chitra Singh',
      album: 'The Golden Ghazals Collection',
      duration: 235,
      streamUrl: '$_r2BaseUrl/kagaz_ki_kashti.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=600&q=80',
      genre: 'Ghazal',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Ghazal Master Library',
    ),
  ];

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
  List<Playlist> getCuratedPlaylists({List<Song>? songs}) {
    final backend = CloudBackendService();
    final deleted = backend.deletedSongIds;
    final baseSongs = songs ?? (backend.approvedSongs.isNotEmpty
        ? backend.approvedSongs.where((s) => !deleted.contains(s.id)).toList()
        : _curatedCatalog.where((s) => !deleted.contains(s.id)).toList());

    final rajasthaniSongs = baseSongs.where((s) => s.genre == 'Rajasthani').toList();
    final bhaktiSongs = baseSongs.where((s) => s.genre == 'Bhakti' || s.genre == 'Spiritual').toList();
    final haryanviSongs = baseSongs.where((s) => s.genre == 'Haryanvi').toList();
    final sufiSongs = baseSongs.where((s) => s.genre == 'Sufi' || s.genre == 'Punjabi').toList();
    final bollywoodSongs = baseSongs.where((s) => s.genre == 'Bollywood' || s.genre == 'Indie Pop').toList();
    final lofiSongs = baseSongs.where((s) => s.genre == 'Desi Lo-Fi' || s.genre == 'Ghazal').toList();
    final spiritualSongs = baseSongs.where((s) => s.genre == 'Spiritual').toList();

    final List<Playlist> playlists = [];

    if (rajasthaniSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_rajasthani',
        title: '🐪 Rangeelo Rajasthan & Marwadi',
        description: 'Rajasthani Folk, Marwadi DJ, Bhajan & Traditional Beats',
        coverUrl: 'https://images.unsplash.com/photo-1599827552599-eeddd59551c6?w=600&q=80',
        songs: rajasthaniSongs,
      ));
    }

    if (bhaktiSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_bhakti',
        title: '🕉️ Divine Bhakti & Mantras',
        description: 'Hanuman Chalisa, Ashtak, Ram Siya Ram, Radhe Krishna & Shabar Mantras',
        coverUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
        songs: bhaktiSongs,
      ));
    }

    if (haryanviSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_haryanvi',
        title: '🌾 Haryanvi & Desi Ragni',
        description: 'Top Haryanvi Hits, Folk & High-Energy Desi Beats',
        coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
        songs: haryanviSongs,
      ));
    }

    if (sufiSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_sartaaj',
        title: '🪕 Sufi & Punjabi Classics (Satinder Sartaaj)',
        description: 'Guzarish, Udaarian, Sajjan Raazi, Tere Bina Na Guzara & Hit Jukebox',
        coverUrl: 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80',
        songs: sufiSongs,
      ));
    }

    if (bollywoodSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_bollywood',
        title: '🎬 Bollywood & Indie Melodies',
        description: 'Ram Siya Ram, Jaiye Sajana, Intezaar Reh Gya & Kagaz Ki Kashti',
        coverUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
        songs: bollywoodSongs,
      ));
    }

    if (lofiSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_lofi',
        title: '🌙 Late Night Desi Lo-Fi & Ghazals',
        description: 'Bajrang Baan Lo-Fi, Kagaz Ki Kashti, Intezaar Reh Gya & Soulful Beats',
        coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
        songs: lofiSongs,
      ));
    }

    if (spiritualSongs.isNotEmpty) {
      playlists.add(Playlist(
        id: 'pl_spiritual',
        title: '🔱 Aghori & Spiritual Trance',
        description: 'Alakh Niranjan Aghori, Aadesh Hanuman & Powerful Siddh Shabar Mantra',
        coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
        songs: spiritualSongs,
      ));
    }

    // 0. Include all remote Cloud Playlists uploaded to R2 db/playlists.json
    final Set<String> registeredPlaylistTitles = {};
    for (final pl in backend.cloudPlaylists) {
      if (pl.songs.isNotEmpty && registeredPlaylistTitles.add(pl.title.toLowerCase().trim())) {
        playlists.add(pl);
      }
    }

    // 1. Group by Folders / Sub-Categories (Admin multi-folder & folder uploads)
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
          album.toLowerCase() == 'unknown album' ||
          album.toLowerCase() == 'msixa cloud hits' ||
          album.toLowerCase() == 'jamendo free catalog' ||
          album.toLowerCase().endsWith('essentials');
      if (!isGenericAlbum && album != sub) {
        folderMap.putIfAbsent(album, () => []).add(cleanedSong);
      }
    }

    // Add each discovered folder as an auto-created playlist
    for (final entry in folderMap.entries) {
      final title = '📁 ${entry.key}';
      if (entry.value.isNotEmpty && registeredPlaylistTitles.add(title.toLowerCase().trim())) {
        final cover = entry.value.firstWhere(
          (s) => s.coverUrl.trim().startsWith('http'),
          orElse: () => entry.value.first,
        ).coverUrl;

        playlists.insert(0, Playlist(
          id: 'pl_folder_${entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          title: title,
          description: 'Folder collection (${entry.value.length} tracks)',
          coverUrl: cover.startsWith('http') ? cover : AiArtworkService().getAiCoverForSong(entry.value.first),
          songs: entry.value,
        ));
      }
    }

    // 2. Group custom genres
    final knownPlaylistGenreSet = {
      'rajasthani',
      'bhakti',
      'spiritual',
      'haryanvi',
      'sufi',
      'punjabi',
      'bollywood',
      'indie pop',
      'desi lo-fi',
      'ghazal',
    };

    final Map<String, List<Song>> customGenreMap = {};
    for (final s in baseSongs) {
      final g = s.genre.trim();
      if (g.isNotEmpty && !knownPlaylistGenreSet.contains(g.toLowerCase())) {
        customGenreMap.putIfAbsent(g, () => []).add(AiMusicService().cleanAndOptimizeSong(s));
      }
    }
    for (final entry in customGenreMap.entries) {
      final title = '🎵 ${entry.key}';
      if (entry.value.isNotEmpty && registeredPlaylistTitles.add(title.toLowerCase().trim())) {
        final cover = entry.value.firstWhere(
          (s) => s.coverUrl.trim().startsWith('http'),
          orElse: () => entry.value.first,
        ).coverUrl;

        playlists.add(Playlist(
          id: 'pl_custom_${entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          title: title,
          description: '${entry.value.length} tracks • ${entry.key}',
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
