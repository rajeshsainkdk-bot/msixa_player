import '../models/song.dart';

class AiArtworkService {
  static final AiArtworkService _instance = AiArtworkService._internal();
  factory AiArtworkService() => _instance;
  AiArtworkService._internal();

  /// Curated, ultra-crisp studio album cover themes
  static const Map<String, List<String>> _genreArtworkCollections = {
    'Bhakti': [
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80', // Sacred temple aura
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=600&q=80', // Golden spiritual diya
      'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=600&q=80', // Divine temple carvings
      'https://images.unsplash.com/photo-1548013146-72479768bada?w=600&q=80', // Ayodhya spiritual dawn
      'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=600&q=80', // Golden radiance
    ],
    'Spiritual': [
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80', // Cosmic sound aura
      'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=600&q=80', // Meditative silence
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80', // Divine trance night
    ],
    'Punjabi': [
      'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80', // Vintage acoustic live
      'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=600&q=80', // Golden studio vibe
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&q=80', // Crowd concert lights
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80', // Vibrant live festival
    ],
    'Sufi': [
      'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80', // Sufi acoustic instrument
      'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80', // Soulful music aesthetic
    ],
    'Bollywood': [
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80', // Cinema stage lighting
      'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80', // Classic microphone studio
      'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=600&q=80', // Romantic dusk sky
    ],
    'Desi Lo-Fi': [
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80', // Midnight neon purple
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&q=80', // Dreamy twilight night
      'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&q=80', // Lo-fi tape cassette
    ],
    'Ghazal': [
      'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=600&q=80', // Acoustic classical strings
      'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600&q=80', // Intimate classical mehfil
    ],
    'Rajasthani': [
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=600&q=80', // Golden desert dusk
      'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=600&q=80', // Royal palace arches
      'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=600&q=80', // Marwadi sunset
    ],
    'Haryanvi': [
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80', // High-energy party stage
      'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=600&q=80', // Festival bass beats
    ],
    'DJ Remix': [
      'https://images.unsplash.com/photo-1571266028243-3716f02d2d2e?w=600&q=80', // Cyber visualizer
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80', // Neon club lasers
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&q=80', // EDM festival
    ],
  };

  /// Fallback high-res music artwork
  static const String _defaultMusicCover =
      'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80';

  /// Suggests a professional AI curated cover for a song based on its genre and title hash
  String getAiCoverForSong(Song song) {
    if (song.coverUrl.trim().startsWith('http')) {
      return song.coverUrl.trim();
    }

    final genreList = _genreArtworkCollections[song.genre];
    if (genreList != null && genreList.isNotEmpty) {
      final hash = (song.title + song.artist).hashCode.abs();
      return genreList[hash % genreList.length];
    }

    // Check lowercase matches
    for (final entry in _genreArtworkCollections.entries) {
      if (song.genre.toLowerCase().contains(entry.key.toLowerCase())) {
        final hash = (song.title + song.artist).hashCode.abs();
        return entry.value[hash % entry.value.length];
      }
    }

    return _defaultMusicCover;
  }

  /// Batch update all songs lacking a proper cover with high-resolution studio AI artwork
  List<Song> batchAutoAssignCovers(List<Song> songs) {
    return songs.map((s) {
      if (!s.coverUrl.trim().startsWith('http')) {
        final newCover = getAiCoverForSong(s);
        return s.copyWith(coverUrl: newCover);
      }
      return s;
    }).toList();
  }
}
