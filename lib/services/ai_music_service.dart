import '../models/song.dart';
import '../models/artist.dart';
import '../models/album.dart';

class AiMusicService {
  static final AiMusicService _instance = AiMusicService._internal();
  factory AiMusicService() => _instance;
  AiMusicService._internal();

  /// Known prominent Indian & global music artists for intelligent parsing
  static const List<String> _knownArtists = [
    // Bhakti & Devotional
    'Hariharan', 'Anuradha Paudwal', 'Anup Jalota', 'Lakhbir Singh Lakkha',
    'Rasraj Ji Maharaj', 'Hansraj Raghuwanshi', 'Kanhiya Mittal', 'Gulshan Kumar',
    'Maanya Arora', 'Prembhushan Ji Maharaj', 'Ravindra Jain', 'Narendra Chanchal',
    'Sudhir Vyas', 'Sai Charan Bhaskaruni', 'Bhumika Sharma',

    // Punjabi & Sufi
    'Satinder Sartaaj', 'Gurdas Maan', 'Diljit Dosanjh', 'Sidhu Moose Wala',
    'B Praak', 'Karan Aujla', 'Ammy Virk', 'Jassi Gill', 'Nusrat Fateh Ali Khan',
    'Rahat Fateh Ali Khan', 'Wadali Brothers', 'Nooran Sisters', 'Kanwar Grewal',
    'Babbu Maan', 'AP Dhillon', 'Shubh', 'Harrdy Sandhu', 'Guru Randhawa',

    // Bollywood & Melodies
    'Arijit Singh', 'Shreya Ghoshal', 'Sonu Nigam', 'Jubin Nautiyal', 'Atif Aslam',
    'Neha Kakkar', 'Mohit Chauhan', 'KK', 'Sunidhi Chauhan', 'Armaan Malik',
    'Darshan Raval', 'Vishal Mishra', 'Papon', 'Prateek Kuhad', 'Anuv Jain',
    'Sachet Tandon', 'Parampara Tandon', 'Shaan', 'Udit Narayan', 'Kumar Sanu',
    'Alka Yagnik', 'Kavita Krishnamurthy', 'Sadhana Sargam',

    // Retro Classics & Ghazals
    'Kishore Kumar', 'Lata Mangeshkar', 'Mohammed Rafi', 'Asha Bhosle',
    'Mukesh', 'Manna Dey', 'Jagjit Singh', 'Pankaj Udhas', 'Bhupinder Singh',
    'Ghulam Ali', 'Mehdi Hassan', 'Talat Mahmood', 'Hemant Kumar',

    // Rajasthani & Folk
    'Seema Mishra', 'Prakash Mali', 'Chotu Singh Rawna', 'Rani Rangili',
    'Mame Khan', 'Ila Arun', 'Swaroop Khan',

    // Haryanvi
    'Sapna Choudhary', 'Diler Kharkiya', 'Masoom Sharma', 'Renuka Panwar',
    'Gulzaar Chhaniwala', 'Raju Punjabi', 'Ajay Hooda',

    // Bhojpuri
    'Pawan Singh', 'Khesari Lal Yadav', 'Shilpi Raj', 'Manoj Tiwari',
  ];

  /// High-resolution verified portraits for top artists
  static const Map<String, String> _artistImages = {
    'Satinder Sartaaj': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&q=80',
    'Arijit Singh': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&q=80',
    'Hariharan': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&q=80',
    'Shreya Ghoshal': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&q=80',
    'Diljit Dosanjh': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&q=80',
    'Sonu Nigam': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600&q=80',
    'Jubin Nautiyal': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=600&q=80',
    'Sidhu Moose Wala': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=600&q=80',
    'B Praak': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=600&q=80',
    'Kishore Kumar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=600&q=80',
    'Lata Mangeshkar': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=600&q=80',
    'Jagjit Singh': 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=600&q=80',
    'Prakash Mali': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=600&q=80',
  };

  /// Clean, parse, and optimize a song's metadata using intelligent heuristics
  Song cleanAndOptimizeSong(Song song) {
    String rawTitle = song.title.trim();
    String rawArtist = song.artist.trim();
    String rawAlbum = song.album.trim();
    String rawGenre = song.genre.trim();

    // 1. Remove file extensions (.mp3, .wav, .m4a, etc.)
    rawTitle = rawTitle.replaceAll(RegExp(r'\.(mp3|wav|m4a|aac|flac|ogg|opus)$', caseSensitive: false), '');

    // 2. Replace underscores with spaces
    rawTitle = rawTitle.replaceAll('_', ' ');

    // 3. Remove promotional tags, website watermarks & bitrate notes
    rawTitle = rawTitle.replaceAll(
      RegExp(r'\[.*?(djbaap|songspk|pagalworld|mr-jatt|pendujatt|naasongs|hungama|wynk|gaana|jiosaavn|youtube|remix|320kbps|128kbps|192kbps|kbps|official|audio|video|lyric|hd|4k|hq|rip).*?\]', caseSensitive: false),
      '',
    );
    rawTitle = rawTitle.replaceAll(
      RegExp(r'\(.*?(djbaap|songspk|pagalworld|mr-jatt|pendujatt|naasongs|hungama|wynk|gaana|jiosaavn|youtube|remix|320kbps|128kbps|192kbps|kbps|official|audio|video|lyric|hd|4k|hq|rip).*?\)', caseSensitive: false),
      '',
    );

    // 4. Remove leading track numbering like '01. ', '02 - ', '1. '
    rawTitle = rawTitle.replaceAll(RegExp(r'^[0-9]{1,3}[\s.\-_]+'), '');

    // 5. Check for "Artist - Title" format
    if (rawTitle.contains(' - ')) {
      final parts = rawTitle.split(' - ');
      if (parts.length >= 2) {
        final left = parts[0].trim();
        final right = parts.sublist(1).join(' - ').trim();

        // If artist was generic or empty, assign left as artist
        if (rawArtist.isEmpty || rawArtist.toLowerCase() == 'msixa artist' || rawArtist.toLowerCase() == 'unknown artist') {
          rawArtist = left;
          rawTitle = right;
        } else if (_isKnownArtist(left)) {
          rawArtist = left;
          rawTitle = right;
        }
      }
    }

    // 6. Detect known Indian artist if mentioned in title or artist string
    for (final artist in _knownArtists) {
      if (rawTitle.toLowerCase().contains(artist.toLowerCase())) {
        if (rawArtist.isEmpty ||
            rawArtist.toLowerCase() == 'msixa artist' ||
            rawArtist.toLowerCase() == 'unknown artist' ||
            rawArtist.toLowerCase() == 'various artists') {
          rawArtist = artist;
        }
      }
    }

    // 7. Title Fallback Recovery: If title is still 'Track 1' or 'bulk_...'
    if (RegExp(r'^(track\s*\d+|bulk_\d+)', caseSensitive: false).hasMatch(rawTitle)) {
      if (song.subCategory != null && song.subCategory!.isNotEmpty) {
        rawTitle = '${song.subCategory} • Track ${song.id.replaceAll(RegExp(r'[^0-9]'), '')}';
      } else {
        // Derive from stream URL basename if available
        final uri = Uri.tryParse(song.streamUrl);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          final filename = uri.pathSegments.last.replaceAll(RegExp(r'\.(mp3|wav|m4a|aac)$', caseSensitive: false), '');
          if (!filename.startsWith('bulk_')) {
            rawTitle = _toTitleCase(filename.replaceAll('_', ' '));
          }
        }
      }
    }

    // 8. Auto-Format Title Case
    rawTitle = _toTitleCase(rawTitle);
    if (rawTitle.isEmpty) rawTitle = 'Track ${song.id}';

    // 9. Artist fallback
    if (rawArtist.isEmpty || rawArtist.toLowerCase() == 'msixa artist' || rawArtist.toLowerCase() == 'unknown artist') {
      if (song.subCategory != null && song.subCategory!.isNotEmpty && !_isGenericFolderName(song.subCategory!)) {
        rawArtist = song.subCategory!;
      } else {
        rawArtist = 'Indian Master Music';
      }
    }
    rawArtist = _toTitleCase(rawArtist);

    // 10. Album fallback
    if (rawAlbum.isEmpty || rawAlbum.toLowerCase() == 'msixa library' || rawAlbum.toLowerCase() == 'unknown album') {
      if (song.subCategory != null && song.subCategory!.isNotEmpty) {
        rawAlbum = song.subCategory!;
      } else {
        rawAlbum = '$rawArtist Essentials';
      }
    }
    rawAlbum = _toTitleCase(rawAlbum);

    // 11. Intelligent Genre Detection
    rawGenre = _detectGenre(rawTitle, rawArtist, rawAlbum, song.subCategory ?? '', rawGenre);

    return song.copyWith(
      title: rawTitle,
      artist: rawArtist,
      album: rawAlbum,
      genre: rawGenre,
    );
  }

  /// Clean and optimize a full list of songs
  List<Song> cleanAndOptimizeAll(List<Song> songs) {
    return songs.map((s) => cleanAndOptimizeSong(s)).toList();
  }

  /// Group songs automatically into categorized Artists with high-fidelity profiles
  List<Artist> extractArtists(List<Song> songs) {
    final Map<String, List<Song>> map = {};
    for (final song in songs) {
      final cleaned = cleanAndOptimizeSong(song);
      final artistName = cleaned.artist.trim();
      if (artistName.isNotEmpty) {
        map.putIfAbsent(artistName, () => []).add(cleaned);
      }
    }

    final List<Artist> artists = [];
    map.forEach((name, artistSongs) {
      final genres = artistSongs.map((s) => s.genre).toSet().toList();
      final cover = _artistImages[name] ??
          (artistSongs.firstWhere((s) => s.coverUrl.startsWith('http'), orElse: () => artistSongs.first).coverUrl);

      final isKnown = _isKnownArtist(name);

      artists.add(Artist(
        id: 'artist_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        name: name,
        songCount: artistSongs.length,
        songs: artistSongs,
        genres: genres,
        coverUrl: cover,
        isVerified: isKnown || artistSongs.length >= 3,
      ));
    });

    // Sort by song count descending (most popular artists first)
    artists.sort((a, b) => b.songCount.compareTo(a.songCount));
    return artists;
  }

  /// Group songs automatically into clean Albums with track counts & durations
  List<Album> extractAlbums(List<Song> songs) {
    final Map<String, List<Song>> map = {};
    for (final song in songs) {
      final cleaned = cleanAndOptimizeSong(song);
      final albumKey = '${cleaned.artist} • ${cleaned.album}'.trim();
      map.putIfAbsent(albumKey, () => []).add(cleaned);
    }

    final List<Album> albums = [];
    map.forEach((key, albumSongs) {
      final first = albumSongs.first;
      final cover = albumSongs.firstWhere((s) => s.coverUrl.startsWith('http'), orElse: () => first).coverUrl;

      albums.add(Album(
        id: 'album_${first.album.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        title: first.album,
        artist: first.artist,
        songCount: albumSongs.length,
        songs: albumSongs,
        genre: first.genre,
        coverUrl: cover,
        year: '2025',
      ));
    });

    // Sort by track count descending
    albums.sort((a, b) => b.songCount.compareTo(a.songCount));
    return albums;
  }

  bool _isKnownArtist(String query) {
    final lower = query.toLowerCase().trim();
    return _knownArtists.any((a) => a.toLowerCase() == lower);
  }

  bool _isGenericFolderName(String name) {
    final lower = name.toLowerCase().trim();
    return lower == 'music' || lower == 'songs' || lower == 'mp3' || lower == 'audio' || lower == 'download';
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  String _detectGenre(String title, String artist, String album, String subCategory, String fallback) {
    final combined = '$title $artist $album $subCategory'.toLowerCase();

    if (combined.contains('hanuman') ||
        combined.contains('ram') ||
        combined.contains('shyam') ||
        combined.contains('krishna') ||
        combined.contains('radhe') ||
        combined.contains('bhajan') ||
        combined.contains('aarti') ||
        combined.contains('chalisa') ||
        combined.contains('mantra') ||
        combined.contains('ashtak') ||
        combined.contains('govind') ||
        combined.contains('shiv') ||
        combined.contains('mahadev') ||
        combined.contains('bhakti')) {
      return 'Bhakti';
    }

    if (combined.contains('sartaaj') ||
        combined.contains('sufi') ||
        combined.contains('qawwali') ||
        combined.contains('punjabi') ||
        combined.contains('sidhu') ||
        combined.contains('diljit') ||
        combined.contains('karan aujla')) {
      return combined.contains('sufi') ? 'Sufi' : 'Punjabi';
    }

    if (combined.contains('aghori') ||
        combined.contains('spiritual') ||
        combined.contains('trance') ||
        combined.contains('shabar') ||
        combined.contains('tandav')) {
      return 'Spiritual';
    }

    if (combined.contains('rajasthan') ||
        combined.contains('marwadi') ||
        combined.contains('ghoomar') ||
        combined.contains('choudhary') ||
        combined.contains('tejaji')) {
      return 'Rajasthani';
    }

    if (combined.contains('haryanvi') ||
        combined.contains('ragni') ||
        combined.contains('sapna') ||
        combined.contains('desi beats')) {
      return 'Haryanvi';
    }

    if (combined.contains('lofi') ||
        combined.contains('lo-fi') ||
        combined.contains('slowed') ||
        combined.contains('reverb') ||
        combined.contains('chill')) {
      return 'Desi Lo-Fi';
    }

    if (combined.contains('ghazal') ||
        combined.contains('jagjit') ||
        combined.contains('kashti')) {
      return 'Ghazal';
    }

    if (combined.contains('remix') ||
        combined.contains('dj') ||
        combined.contains('bass boost') ||
        combined.contains('dholki') ||
        combined.contains('mashup')) {
      return 'DJ Remix';
    }

    if (combined.contains('arijit') ||
        combined.contains('bollywood') ||
        combined.contains('shreya') ||
        combined.contains('sonu nigam') ||
        combined.contains('romantic')) {
      return 'Bollywood';
    }

    return fallback.isNotEmpty ? fallback : 'All Indian';
  }
}

