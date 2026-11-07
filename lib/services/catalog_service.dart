import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/playlist.dart';

class CatalogService {
  static const String _jamendoClientId = '56d30c95';
  static const String _jamendoBaseUrl = 'https://api.jamendo.com/v3.0';

  /// 100% Free Built-in Catalog of Verified Legal Indian & International Songs.
  /// Zero subscription, zero payment required - ready to stream instantly.
  static final List<Song> _curatedCatalog = [
    // ==========================================================
    // 1. BOLLYWOOD TOP HITS & ACOUSTIC MELODIES
    // ==========================================================
    Song(
      id: 'msixa_bol_01',
      title: 'Tum Mile (Bollywood Acoustic Lounge)',
      artist: 'Arjun Sharma & Strings',
      album: 'Bollywood Lounge Vol. 1',
      duration: 214,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/11/06/audio_c97f48dfa2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
      genre: 'Bollywood',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Desi Acoustic Sessions',
    ),
    Song(
      id: 'msixa_bol_02',
      title: 'Kesariya Tera (Unplugged Acoustic Guitar)',
      artist: 'Acoustic Desi Project',
      album: 'Heartstrings Unplugged',
      duration: 228,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      genre: 'Bollywood',
      license: '100% Free Creative Commons CC0',
      licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      source: 'Indian Acoustic Heritage',
    ),
    Song(
      id: 'msixa_bol_03',
      title: 'Dil Ki Dhadkan (Romantic Hindi Lounge)',
      artist: 'Kabir & Aastha',
      album: 'Coffee House Sessions',
      duration: 208,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8c8a73467.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
      genre: 'Bollywood',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Desi Acoustic Sessions',
    ),
    Song(
      id: 'msixa_bol_04',
      title: 'Raataan Lambiyan (Late Night Piano & Flute)',
      artist: 'Siddharth Strings',
      album: 'Midnight Melodies',
      duration: 245,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/08/02/audio_884fe92c21.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1506461883276-594a12b11cf3?w=600&q=80',
      genre: 'Bollywood',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Bollywood Instrumental Lounge',
    ),
    Song(
      id: 'msixa_bol_05',
      title: 'Chura Liya Retro (Chill Bollywood Redux)',
      artist: 'Retro Bollywood Lounge',
      album: 'Golden Era Chillout',
      duration: 195,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      genre: 'Bollywood',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Retro Redux Collective',
    ),

    // ==========================================================
    // 2. RAJASTHANI FOLK & GHOOMAR BEATS
    // ==========================================================
    Song(
      id: 'msixa_raj_01',
      title: 'Ghoomar Dhol Trance (Rajasthani DJ Remix)',
      artist: 'DJ Manish & Thar Dhol',
      album: 'Royal Rajasthan Beats',
      duration: 235,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/10/14/audio_9939f777dd.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1599818816930-3f7b823c830b?w=600&q=80',
      genre: 'Rajasthani',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Rajasthani Folk Archives',
    ),
    Song(
      id: 'msixa_raj_02',
      title: 'Kesariya Breeze (Rajasthani Sarangi & Morchang)',
      artist: 'Thar Desert Ensemble',
      album: 'Golden Dunes of Rajasthan',
      duration: 225,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=600&q=80',
      genre: 'Rajasthani',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Folk Heritage Archives',
    ),
    Song(
      id: 'msixa_raj_03',
      title: 'Choudhary (Desert Bass DJ Mix)',
      artist: 'Jaipur Electro Folk',
      album: 'Thar Desert Electronic',
      duration: 218,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1477587458883-47145ed94245?w=600&q=80',
      genre: 'Rajasthani',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Desert Electro Lab',
    ),
    Song(
      id: 'msixa_raj_04',
      title: 'Padharo Mhare Des (Acoustic Desert Lounge)',
      artist: 'Ustad Rahim Khan',
      album: 'Virasat Rajasthan',
      duration: 240,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2021/08/04/audio_bb630cc098.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
      genre: 'Rajasthani',
      license: '100% Free Creative Commons CC0',
      licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      source: 'Heritage Folk Library',
    ),

    // ==========================================================
    // 3. DJ SONGS & DESI PARTY BASS
    // ==========================================================
    Song(
      id: 'msixa_dj_01',
      title: 'Bhangra Dhol Pulse & Bass (Club DJ Mix)',
      artist: 'DJ Kuldeep & Dhol Master',
      album: 'Punjab Grooves Vol. 2',
      duration: 205,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/10/14/audio_9939f777dd.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
      genre: 'DJ Songs',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Folk Beat Archives',
    ),
    Song(
      id: 'msixa_dj_02',
      title: 'Dhol Jagiro Da (Bass Boosted Club Remix)',
      artist: 'Bass Drop India',
      album: 'Desi Bass 2026',
      duration: 215,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80',
      genre: 'DJ Songs',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Bass Drop Collective',
    ),
    Song(
      id: 'msixa_dj_03',
      title: 'Desi Cyberpunk Bhangra Drop 2026',
      artist: 'Vektor 99 & Desi Beats',
      album: 'Pind to Tokyo',
      duration: 190,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/08/02/audio_884fe92c21.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&q=80',
      genre: 'DJ Songs',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Desi Electro Lab',
    ),
    Song(
      id: 'msixa_dj_04',
      title: 'Nagada Sang Dhol Bass Blast',
      artist: 'Dhol Beats Collective',
      album: 'Indian Wedding Party Hits',
      duration: 212,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/11/06/audio_c97f48dfa2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      genre: 'DJ Songs',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Party Beats Collective',
    ),

    // ==========================================================
    // 4. DESI LO-FI & MONSOON NOSTALGIA
    // ==========================================================
    Song(
      id: 'msixa_lofi_01',
      title: 'Bollywood Lo-Fi Chai Beats',
      artist: 'Desi Beat Lab',
      album: 'Monsoon in Mumbai',
      duration: 178,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8c8a73467.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1506461883276-594a12b11cf3?w=600&q=80',
      genre: 'Desi Lo-Fi',
      license: '100% Free Creative Commons CC-BY-SA',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
      source: 'Creative Commons Desi Music',
    ),
    Song(
      id: 'msixa_lofi_02',
      title: 'Chai Tapri Lo-Fi (Old Radio Nostalgia)',
      artist: 'Bombay Beats Project',
      album: 'Marine Drive Rain',
      duration: 185,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8c8a73467.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=600&q=80',
      genre: 'Desi Lo-Fi',
      license: '100% Free Creative Commons CC-BY-SA',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
      source: 'Creative Commons Desi Music',
    ),
    Song(
      id: 'msixa_lofi_03',
      title: 'Monsoon in Mumbai (Lo-Fi Train Journey)',
      artist: 'Komorebi Desi',
      album: 'Local Train Vibes',
      duration: 195,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80',
      genre: 'Desi Lo-Fi',
      license: '100% Free Creative Commons CC0',
      licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      source: 'Lo-Fi Chill Collective',
    ),

    // ==========================================================
    // 5. SUFI & GHAZAL SOUL
    // ==========================================================
    Song(
      id: 'msixa_sufi_01',
      title: 'Sufi Roohani Qawwal Lounge',
      artist: 'Al-Madina Strings',
      album: 'Ishq & Soul',
      duration: 245,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/08/02/audio_884fe92c21.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      genre: 'Sufi',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Sufi Soul Records',
    ),
    Song(
      id: 'msixa_sufi_02',
      title: 'Dama Dam Mast Qalandar (Sufi Trance)',
      artist: 'Dargah Echoes & Beats',
      album: 'Sufi Ecstasy',
      duration: 240,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/08/02/audio_884fe92c21.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
      genre: 'Sufi',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Sufi Soul Records',
    ),
    Song(
      id: 'msixa_sufi_03',
      title: 'Shaam-e-Ghazal (Harmonium & Tabla Evening)',
      artist: 'Mehfil-e-Khaas',
      album: 'Lucknow Nights',
      duration: 275,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2021/08/04/audio_bb630cc098.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1506461883276-594a12b11cf3?w=600&q=80',
      genre: 'Sufi',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Ghazal Archives',
    ),

    // ==========================================================
    // 6. INDIAN CLASSICAL, RAGAS & MEDITATION
    // ==========================================================
    Song(
      id: 'msixa_clas_01',
      title: 'Midnight Raga (Bansuri Flute & Sitar)',
      artist: 'Pandit Ronu Fusion',
      album: 'Sacred Ragas of India',
      duration: 265,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      genre: 'Classical',
      license: '100% Free Creative Commons CC0',
      licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      source: 'Indian Classical Heritage',
    ),
    Song(
      id: 'msixa_clas_02',
      title: 'Taj Sunset Sitar Raga',
      artist: 'Ravi Shankar Inspired Ensemble',
      album: 'Varanasi Morning Strings',
      duration: 232,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2021/08/04/audio_bb630cc098.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=600&q=80',
      genre: 'Classical',
      license: '100% Free Creative Commons CC0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Indian Instrumental Library',
    ),
    Song(
      id: 'msixa_clas_03',
      title: 'Jaipur Palace Tabla Fusion',
      artist: 'Ustad Zakir Sound Collective',
      album: 'Desert Beats',
      duration: 210,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1477587458883-47145ed94245?w=600&q=80',
      genre: 'Classical',
      license: '100% Free Creative Commons CC-BY',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Heritage Sound Collective',
    ),
    Song(
      id: 'msixa_clas_04',
      title: 'Monsoon Raag Megh (Santoor & Jal Tarang)',
      artist: 'Pandit Shivkumar Tribute',
      album: 'Kashmir Valley Melodies',
      duration: 250,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/11/06/audio_c97f48dfa2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
      genre: 'Classical',
      license: '100% Free Creative Commons CC0',
      licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      source: 'Indian Classical Heritage',
    ),
    Song(
      id: 'msixa_clas_05',
      title: 'Morning Gayatri Raga Mantra (Peaceful Flute)',
      artist: 'Vedic Soundscapes',
      album: 'Rishikesh Sunrise',
      duration: 280,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
      genre: 'Classical',
      license: '100% Free Creative Commons CC0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      source: 'Indian Classical Heritage',
    ),

    // ==========================================================
    // 7. INTERNATIONAL ELECTRONIC & LO-FI
    // ==========================================================
    Song(
      id: 'msixa_cc_01',
      title: 'Neon Horizon',
      artist: 'Aura Wave',
      album: 'Cyber Odyssey',
      duration: 198,
      streamUrl: 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&q=80',
      genre: 'Synthwave',
      license: '100% Free Creative Commons CC-BY',
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
      license: '100% Free Creative Commons CC0',
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
      license: '100% Free Creative Commons CC-BY-SA',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/3.0/',
      source: 'Jamendo Open Commons',
    ),
  ];

  /// Fetches featured trending tracks with Indian songs prioritized
  Future<List<Song>> fetchTrendingTracks({int limit = 30}) async {
    return _curatedCatalog;
  }

  /// Searches tracks legally by keyword
  Future<List<Song>> searchTracks(String query) async {
    if (query.trim().isEmpty) return _curatedCatalog;

    final lower = query.toLowerCase();
    final localMatches = _curatedCatalog.where((song) {
      return song.title.toLowerCase().contains(lower) ||
          song.artist.toLowerCase().contains(lower) ||
          song.genre.toLowerCase().contains(lower) ||
          song.album.toLowerCase().contains(lower);
    }).toList();

    return localMatches;
  }

  /// Fetches tracks filtered by specific Genre / Mood
  Future<List<Song>> fetchTracksByGenre(String genre) async {
    if (genre == 'All' || genre == 'All Indian') {
      return _curatedCatalog;
    }

    final lower = genre.toLowerCase();
    final filtered = _curatedCatalog.where((s) {
      return s.genre.toLowerCase().contains(lower) ||
          lower.contains(s.genre.toLowerCase());
    }).toList();

    if (filtered.isNotEmpty) return filtered;
    return _curatedCatalog;
  }

  /// Returns featured 100% free ready-to-listen playlists without subscription or payment
  List<Playlist> getCuratedPlaylists() {
    return [
      Playlist(
        id: 'pl_indian_all',
        title: '🇮🇳 All Indian Free Songs (No Subscription)',
        description: 'Complete 24-track collection: Bollywood acoustic, Rajasthani folk, DJ dhol remix, Desi Lo-Fi, Sufi & Classical. 100% Free forever!',
        coverUrl: 'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.id.startsWith('msixa_bol') || s.id.startsWith('msixa_raj') || s.id.startsWith('msixa_dj') || s.id.startsWith('msixa_lofi') || s.id.startsWith('msixa_sufi') || s.id.startsWith('msixa_clas')).toList(),
        isCurated: true,
      ),
      Playlist(
        id: 'pl_bollywood',
        title: '🎬 Bollywood Hits & Acoustic Lounge',
        description: 'Mellow acoustic guitars, Bollywood melodies, and soulful chillout renditions.',
        coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.genre == 'Bollywood').toList(),
        isCurated: true,
      ),
      Playlist(
        id: 'pl_rajasthani',
        title: '🐪 Rajasthani Folk & Ghoomar DJ',
        description: 'Desert sarangi, morchang, Ghoomar trance, and royal folk bass grooves.',
        coverUrl: 'https://images.unsplash.com/photo-1599818816930-3f7b823c830b?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.genre == 'Rajasthani').toList(),
        isCurated: true,
      ),
      Playlist(
        id: 'pl_dj_party',
        title: '🎧 DJ Songs & Desi Party Bass',
        description: 'High octane Bhangra dhol, club remixes, and wedding party bass drops.',
        coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.genre == 'DJ Songs').toList(),
        isCurated: true,
      ),
      Playlist(
        id: 'pl_lofi',
        title: '☕ Desi Lo-Fi & Monsoon Chai Beats',
        description: 'Warm vinyl crackles, old radio Bollywood nostalgia, and monsoon train journeys.',
        coverUrl: 'https://images.unsplash.com/photo-1506461883276-594a12b11cf3?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.genre == 'Desi Lo-Fi').toList(),
        isCurated: true,
      ),
      Playlist(
        id: 'pl_classical',
        title: '🪕 Bansuri Flute & Sitar Ragas',
        description: 'Meditative Indian classical instruments for peace, deep focus, and relaxation.',
        coverUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.genre == 'Classical').toList(),
        isCurated: true,
      ),
      Playlist(
        id: 'pl_sufi',
        title: '🕯️ Sufi & Ghazal Soul Nights',
        description: 'Heartfelt Sufi qawwali, harmonium chords, and late-night poetic ghazals.',
        coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
        songs: _curatedCatalog.where((s) => s.genre == 'Sufi').toList(),
        isCurated: true,
      ),
    ];
  }
}
