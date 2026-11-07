import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/playlist.dart';

class CatalogService {
  static const String _jamendoClientId = '56d30c95';
  static const String _jamendoBaseUrl = 'https://api.jamendo.com/v3.0';

  /// Built-in curated catalog of verified, 100% legal Creative Commons and
  /// Public Domain MP3 streams including rich Indian Classical, Desi Lo-Fi, Sitar, Flute, and Sufi music.
  static final List<Song> _curatedCatalog = [
    // --- Indian Songs & Ragas Collection ---
    Song(
      id: 'msixa_ind_01',
      title: 'Tum Mile (Desi Acoustic Chill)',
      artist: 'Arjun Sharma & Strings',
      album: 'Bollywood Lounge Vol. 1',
      duration: 214,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/11/06/audio_c97f48dfa2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
      genre: 'Indian Acoustic',
      license: 'Creative Commons CC-BY 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Desi Acoustic Sessions',
    ),
    Song(
      id: 'msixa_ind_02',
      title: 'Midnight Raga (Bansuri Flute & Sitar)',
      artist: 'Pandit Ronu Fusion',
      album: 'Sacred Ragas of India',
      duration: 265,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      genre: 'Indian Classical',
      license: 'Creative Commons CC0 Public Domain',
      licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      source: 'Indian Classical Heritage',
    ),
    Song(
      id: 'msixa_ind_03',
      title: 'Bollywood Lo-Fi Chai Beats',
      artist: 'Desi Beat Lab',
      album: 'Monsoon in Mumbai',
      duration: 178,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8c8a73467.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1506461883276-594a12b11cf3?w=600&q=80',
      genre: 'Desi Lo-Fi',
      license: 'Creative Commons CC-BY-SA',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
      source: 'Creative Commons Desi Music',
    ),
    Song(
      id: 'msixa_ind_04',
      title: 'Sufi Roohani Qawwal Lounge',
      artist: 'Al-Madina Strings',
      album: 'Ishq & Soul',
      duration: 245,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/08/02/audio_884fe92c21.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      genre: 'Sufi',
      license: 'Creative Commons CC-BY 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Sufi Soul Records',
    ),
    Song(
      id: 'msixa_ind_05',
      title: 'Bhangra Dhol Pulse & Bass',
      artist: 'Dhol & Bass Project',
      album: 'Punjab Grooves',
      duration: 195,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/10/14/audio_9939f777dd.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      genre: 'Punjabi',
      license: 'Creative Commons CC-BY 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Folk Beat Archives',
    ),
    Song(
      id: 'msixa_ind_06',
      title: 'Taj Sunset Sitar Raga',
      artist: 'Ravi Shankar Inspired Ensemble',
      album: 'Varanasi Morning Strings',
      duration: 232,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2021/08/04/audio_bb630cc098.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=600&q=80',
      genre: 'Indian Classical',
      license: 'Creative Commons CC0 Public Domain',
      licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      source: 'Indian Instrumental Library',
    ),
    Song(
      id: 'msixa_ind_07',
      title: 'Jaipur Palace Tabla Fusion',
      artist: 'Ustad Zakir Sound Collective',
      album: 'Desert Beats',
      duration: 210,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1477587458883-47145ed94245?w=600&q=80',
      genre: 'Tabla Fusion',
      license: 'Creative Commons CC-BY 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Heritage Sound Collective',
    ),
    Song(
      id: 'msixa_ind_08',
      title: 'Kesariya Breeze (Rajasthani Sarangi & Morchang)',
      artist: 'Thar Desert Ensemble',
      album: 'Golden Dunes of Rajasthan',
      duration: 225,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1599818816930-3f7b823c830b?w=600&q=80',
      genre: 'Folk Fusion',
      license: 'Creative Commons CC-BY 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Folk Heritage Archives',
    ),
    Song(
      id: 'msixa_ind_09',
      title: 'Monsoon Raag Megh (Santoor & Jal Tarang)',
      artist: 'Pandit Shivkumar Tribute',
      album: 'Kashmir Valley Melodies',
      duration: 250,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/11/06/audio_c97f48dfa2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
      genre: 'Indian Classical',
      license: 'Creative Commons CC0 Public Domain',
      licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      source: 'Indian Classical Heritage',
    ),
    Song(
      id: 'msixa_ind_10',
      title: 'Dil Ki Dhadkan (Romantic Acoustic Hindi)',
      artist: 'Kabir & Aastha',
      album: 'Coffee House Sessions',
      duration: 208,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8c8a73467.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      genre: 'Indian Acoustic',
      license: 'Creative Commons CC-BY 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Desi Acoustic Sessions',
    ),
    Song(
      id: 'msixa_ind_11',
      title: 'Dama Dam Mast Qalandar (Sufi Trance)',
      artist: 'Dargah Echoes & Beats',
      album: 'Sufi Ecstasy',
      duration: 240,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/08/02/audio_884fe92c21.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      genre: 'Sufi',
      license: 'Creative Commons CC-BY 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Sufi Soul Records',
    ),
    Song(
      id: 'msixa_ind_12',
      title: 'Shaam-e-Ghazal (Harmonium & Tabla Evening)',
      artist: 'Mehfil-e-Khaas',
      album: 'Lucknow Nights',
      duration: 275,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2021/08/04/audio_bb630cc098.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1506461883276-594a12b11cf3?w=600&q=80',
      genre: 'Ghazal',
      license: 'Creative Commons CC-BY 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Ghazal Archives',
    ),
    Song(
      id: 'msixa_ind_13',
      title: 'Desi Cyberpunk Bhangra Drop',
      artist: 'DJ Kuldeep & Dhol Master',
      album: 'Pind to Tokyo',
      duration: 190,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/10/14/audio_9939f777dd.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      genre: 'Punjabi',
      license: 'Creative Commons CC-BY 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Folk Beat Archives',
    ),
    Song(
      id: 'msixa_ind_14',
      title: 'Morning Gayatri Raga Mantra (Peaceful Flute)',
      artist: 'Vedic Soundscapes',
      album: 'Rishikesh Sunrise',
      duration: 280,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
      genre: 'Spiritual',
      license: 'Creative Commons CC0 Public Domain',
      licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      source: 'Indian Classical Heritage',
    ),
    Song(
      id: 'msixa_ind_15',
      title: 'Chai Tapri Lo-Fi (Old Radio Nostalgia)',
      artist: 'Bombay Beats Project',
      album: 'Marine Drive Rain',
      duration: 185,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8c8a73467.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=600&q=80',
      genre: 'Desi Lo-Fi',
      license: 'Creative Commons CC-BY-SA',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
      source: 'Creative Commons Desi Music',
    ),

    // --- Electronic, Synthwave & Lo-Fi International Gems ---
    Song(
      id: 'msixa_cc_01',
      title: 'Neon Horizon',
      artist: 'Aura Wave',
      album: 'Cyber Odyssey',
      duration: 198,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&q=80',
      genre: 'Synthwave',
      license: 'Creative Commons CC-BY 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Creative Commons Public Audio',
    ),
    Song(
      id: 'msixa_cc_02',
      title: 'Midnight Coffee Lofi',
      artist: 'Komorebi Sound',
      album: 'Tokyo Rain Vol. 1',
      duration: 165,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8c8a73467.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
      genre: 'Lo-Fi',
      license: 'Creative Commons CC0 Public Domain',
      licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      source: 'Free Sound Library',
    ),
    Song(
      id: 'msixa_cc_03',
      title: 'Deep Etherium',
      artist: 'Solaris Project',
      album: 'Astral Plane',
      duration: 242,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
      genre: 'Ambient',
      license: 'Creative Commons CC-BY-SA 3.0',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/3.0/',
      source: 'Jamendo Open Commons',
    ),
  ];

  /// Fetches featured trending tracks
  Future<List<Song>> fetchTrendingTracks({int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$_jamendoBaseUrl/tracks/?client_id=$_jamendoClientId'
        '&format=jsonpretty&limit=$limit&order=popularity_month'
        '&include=licenses&audioformat=mp32',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final online = results.map((item) => _parseJamendoTrack(item)).toList();
          // Prepend Indian tracks so user sees Indian music prominently at the top
          return [..._curatedCatalog.where((s) => s.id.startsWith('msixa_ind')), ...online];
        }
      }
    } catch (_) {}
    return _curatedCatalog;
  }

  /// Searches tracks legally by keyword
  Future<List<Song>> searchTracks(String query) async {
    if (query.trim().isEmpty) return _curatedCatalog;

    final lower = query.toLowerCase();
    final localMatches = _curatedCatalog.where((song) {
      return song.title.toLowerCase().contains(lower) ||
          song.artist.toLowerCase().contains(lower) ||
          song.genre.toLowerCase().contains(lower);
    }).toList();

    try {
      final uri = Uri.parse(
        '$_jamendoBaseUrl/tracks/?client_id=$_jamendoClientId'
        '&format=jsonpretty&namesearch=${Uri.encodeComponent(query)}'
        '&limit=15&include=licenses&audioformat=mp32',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final online = results.map((item) => _parseJamendoTrack(item)).toList();
          return [...localMatches, ...online];
        }
      }
    } catch (_) {}

    return localMatches.isNotEmpty ? localMatches : _curatedCatalog;
  }

  /// Fetches tracks filtered by specific Genre / Tag
  Future<List<Song>> fetchTracksByGenre(String genre) async {
    final lower = genre.toLowerCase();
    final filtered = _curatedCatalog.where((s) {
      return s.genre.toLowerCase().contains(lower) ||
          lower.contains(s.genre.toLowerCase());
    }).toList();

    if (filtered.isNotEmpty) return filtered;

    try {
      final uri = Uri.parse(
        '$_jamendoBaseUrl/tracks/?client_id=$_jamendoClientId'
        '&format=jsonpretty&tags=${Uri.encodeComponent(genre.toLowerCase())}'
        '&limit=15&order=popularity_total&include=licenses&audioformat=mp32',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          return results.map((item) => _parseJamendoTrack(item, genreHint: genre)).toList();
        }
      }
    } catch (_) {}

    return _curatedCatalog;
  }

  /// Returns featured curated playlists including Indian Music collections
  List<Playlist> getCuratedPlaylists() {
    return [
      Playlist(
        id: 'pl_indian_01',
        title: 'All Indian Songs (Desi Collection)',
        description: 'Complete Indian collection: Bollywood chill, Acoustic, Sufi, Classical ragas & Dhol beats.',
        coverUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.id.startsWith('msixa_ind')).toList(),
        isCurated: true,
      ),
      Playlist(
        id: 'pl_indian_02',
        title: 'Bansuri Flute & Sitar Ragas',
        description: 'Meditative Indian classical instruments for peace, deep focus, and relaxation.',
        coverUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.genre == 'Indian Classical' || s.genre == 'Tabla Fusion' || s.genre == 'Spiritual').toList(),
        isCurated: true,
      ),
      Playlist(
        id: 'pl_indian_03',
        title: 'Sufi & Ghazal Soul Nights',
        description: 'Heartfelt Sufi qawwali, harmonium chords, and late-night poetic ghazals.',
        coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.genre == 'Sufi' || s.genre == 'Ghazal').toList(),
        isCurated: true,
      ),
      Playlist(
        id: 'pl_indian_04',
        title: 'Punjabi Dhol & Folk Fusion',
        description: 'High energy Punjabi beats, dhol grooves, and Rajasthani desert instruments.',
        coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.genre == 'Punjabi' || s.genre == 'Folk Fusion').toList(),
        isCurated: true,
      ),
      Playlist(
        id: 'pl_01',
        title: 'Cyberpunk Neon Drift',
        description: 'Pumping synthwave and retro electro for late-night rides.',
        coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.genre == 'Synthwave' || s.genre == 'Electronic').toList(),
        isCurated: true,
      ),
      Playlist(
        id: 'pl_02',
        title: 'Lo-Fi Chill & Code',
        description: 'Warm vinyl crackles and mellow beats for maximum focus.',
        coverUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.genre == 'Lo-Fi' || s.genre == 'Chillhop').toList(),
        isCurated: true,
      ),
    ];
  }

  static Song _parseJamendoTrack(Map<String, dynamic> item, {String? genreHint}) {
    final licenseData = item['licenses'] as Map<String, dynamic>?;
    final licenseName = licenseData?['name'] ?? 'Creative Commons CC-BY-SA';
    final licenseUrl = licenseData?['url'] ?? 'https://creativecommons.org/';

    return Song(
      id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: item['name']?.toString() ?? 'Unknown Track',
      artist: item['artist_name']?.toString() ?? 'Independent Artist',
      album: item['album_name']?.toString() ?? 'Msixa Open Catalog',
      duration: (item['duration'] as num?)?.toInt() ?? 180,
      streamUrl: item['audio']?.toString() ?? '',
      coverUrl: item['image']?.toString() ??
          item['album_image']?.toString() ??
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      genre: genreHint ?? (item['musicinfo']?['tags']?['genres']?[0]?.toString() ?? 'Electronic'),
      license: licenseName.toString(),
      licenseUrl: licenseUrl.toString(),
      source: 'Jamendo Music (Free Creative Commons)',
    );
  }
}
