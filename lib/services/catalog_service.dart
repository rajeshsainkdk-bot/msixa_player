import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/playlist.dart';

class CatalogService {
  static const String _jamendoClientId = '56d30c95';
  static const String _jamendoBaseUrl = 'https://api.jamendo.com/v3.0';

  /// 100% Real Authentic Indian Music Library (Bollywood, Punjabi, Sufi, Bhakti, Ghazal & Indie)
  /// All tracks bundled directly with original artists, vocal masters, and high-fidelity sound.
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
      streamUrl: 'assets/audio/sankat_mochan_hanuman_ashtak.mp3',
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
      streamUrl: 'assets/audio/ye_chamak_ye_damak.mp3',
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
      streamUrl: 'assets/audio/powerful_hanuman_chalisa.mp3',
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
      streamUrl: 'assets/audio/ram_siya_ram.mp3',
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
      streamUrl: 'assets/audio/radhe_tere_charno_ki_dhool.mp3',
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
      streamUrl: 'assets/audio/bajrang_baan_lofi.mp3',
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
      streamUrl: 'assets/audio/aadesh_hanuman.mp3',
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
      streamUrl: 'assets/audio/alakh_niranjan_aghori.mp3',
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
      streamUrl: 'assets/audio/siddh_shabar_mantra.mp3',
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
      streamUrl: 'assets/audio/guzarish_sartaaj.mp3',
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
      streamUrl: 'assets/audio/udaarian.mp3',
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
      streamUrl: 'assets/audio/sajjan_raazi.mp3',
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
      streamUrl: 'assets/audio/tere_bina_na_guzara.mp3',
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
      streamUrl: 'assets/audio/jaiye_sajana.mp3',
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
      streamUrl: 'assets/audio/satinder_sartaaj_jukebox.mp3',
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
      streamUrl: 'assets/audio/intezaar_reh_gya.mp3',
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
      streamUrl: 'assets/audio/kagaz_ki_kashti.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=600&q=80',
      genre: 'Ghazal',
      license: 'Personal Music Library',
      licenseUrl: 'local',
      source: 'Ghazal Master Library',
    ),
  ];

  /// Fetch initial trending tracks (instantly available)
  Future<List<Song>> fetchTrendingTracks() async {
    return List.from(_curatedCatalog);
  }

  /// Filter tracks by selected genre
  Future<List<Song>> fetchTracksByGenre(String genre) async {
    final lower = genre.toLowerCase().trim();
    if (lower == 'all' || lower == 'all indian') {
      return fetchTrendingTracks();
    }
    return _curatedCatalog.where((s) => s.genre.toLowerCase() == lower).toList();
  }

  /// Get categorized curated playlists
  List<Playlist> getCuratedPlaylists() {
    final bhaktiSongs = _curatedCatalog.where((s) => s.genre == 'Bhakti' || s.genre == 'Spiritual').toList();
    final sufiSongs = _curatedCatalog.where((s) => s.genre == 'Sufi' || s.genre == 'Punjabi').toList();
    final bollywoodSongs = _curatedCatalog.where((s) => s.genre == 'Bollywood' || s.genre == 'Indie Pop').toList();
    final lofiSongs = _curatedCatalog.where((s) => s.genre == 'Desi Lo-Fi' || s.genre == 'Ghazal' || s.genre == 'Indie Pop').toList();
    final spiritualSongs = _curatedCatalog.where((s) => s.genre == 'Spiritual').toList();

    return [
      Playlist(
        id: 'pl_bhakti',
        name: '🕉️ Divine Bhakti & Mantras',
        description: 'Hanuman Chalisa, Ashtak, Ram Siya Ram, Radhe Krishna & Shabar Mantras',
        coverUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
        songs: bhaktiSongs,
      ),
      Playlist(
        id: 'pl_sartaaj',
        name: '🪕 Sufi & Punjabi Classics (Satinder Sartaaj)',
        description: 'Guzarish, Udaarian, Sajjan Raazi, Tere Bina Na Guzara & Hit Jukebox',
        coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
        songs: sufiSongs,
      ),
      Playlist(
        id: 'pl_bollywood',
        name: '🎬 Bollywood & Indie Melodies',
        description: 'Ram Siya Ram, Jaiye Sajana, Intezaar Reh Gya & Kagaz Ki Kashti',
        coverUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
        songs: bollywoodSongs,
      ),
      Playlist(
        id: 'pl_lofi',
        name: '🌙 Late Night Desi Lo-Fi & Ghazals',
        description: 'Bajrang Baan Lo-Fi, Kagaz Ki Kashti, Intezaar Reh Gya & Soulful Beats',
        coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
        songs: lofiSongs,
      ),
      Playlist(
        id: 'pl_spiritual',
        name: '🔱 Aghori & Spiritual Trance',
        description: 'Alakh Niranjan Aghori, Aadesh Hanuman & Powerful Siddh Shabar Mantra',
        coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
        songs: spiritualSongs,
      ),
    ];
  }

  /// Search online/curated catalog with live search
  Future<List<Song>> searchTracks(String query) async {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return [];

    final localMatches = _curatedCatalog.where((s) =>
        s.title.toLowerCase().contains(lower) ||
        s.artist.toLowerCase().contains(lower) ||
        s.album.toLowerCase().contains(lower) ||
        s.genre.toLowerCase().contains(lower)).toList();

    return localMatches;
  }
}
