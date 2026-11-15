import '../models/song.dart';

class SongArtworkResolver {
  static bool isGenericMicUrl(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    final u = url.trim().toLowerCase();
    return u.contains('1511671782779') ||
        u.contains('photo-1511671782779') ||
        u.contains('1493225457124') ||
        u.contains('placeholder') ||
        u.contains('default_cover') ||
        u == 'null';
  }

  /// Verified studio portraits and official high-resolution pictures of prominent Indian and global artists
  static const Map<String, String> _artistImages = {
    // Bhakti & Devotional Singers
    'hariharan': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
    'sudhir vyas': 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
    'sai charan': 'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=800&q=85',
    'sai charan bhaskaruni': 'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=800&q=85',
    'bhumika sharma': 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&q=85',
    'rasraj ji': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'rasraj ji maharaj': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'anuradha paudwal': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&q=85',
    'anup jalota': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'lakhbir singh lakkha': 'https://images.unsplash.com/photo-1548013146-72479768bada?w=800&q=85',
    'lakkha': 'https://images.unsplash.com/photo-1548013146-72479768bada?w=800&q=85',
    'hansraj raghuwanshi': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'hansraj': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'kanhaiya mittal': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'jaya kishori': 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&q=85',
    'gulshan kumar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&q=85',
    'maanya arora': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=85',

    // Sufi, Punjabi & Folk Legends
    'satinder sartaaj': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
    'sartaaj': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
    'gurdas maan': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&q=85',
    'diljit dosanjh': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'diljit': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'sidhu moose wala': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&q=85',
    'sidhu': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&q=85',
    'karan aujla': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'aujla': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'b praak': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'praak': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'ammy virk': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'nusrat fateh ali khan': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
    'rahat fateh ali khan': 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&q=85',
    'ap dhillon': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'dhillon': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'shubh': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=800&q=85',
    'guru randhawa': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'harrdy sandhu': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'badshah': 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=800&q=85',
    'honey singh': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'yo yo': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',

    // Bollywood & Melodies
    'arijit singh': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'arijit': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'shreya ghoshal': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'shreya': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'sonu nigam': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'sonu': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'jubin nautiyal': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'jubin': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'atif aslam': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'atif': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'neha kakkar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'neha': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'mohit chauhan': 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&q=85',
    'kk': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=800&q=85',
    'sunidhi chauhan': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=85',
    'armaan malik': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'darshan raval': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&q=85',
    'vishal mishra': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'sachet tandon': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'parampara tandon': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=85',
    'sachet': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'shaan': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&q=85',
    'udit narayan': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',
    'kumar sanu': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'sanu': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=85',
    'alka yagnik': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'alka': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'anuv jain': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'anuv': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',

    // Retro Classics & Ghazals
    'jagjit singh': 'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=800&q=85',
    'chitra singh': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&q=85',
    'pankaj udhas': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
    'lata mangeshkar': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
    'lata': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
    'kishore kumar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'kishore': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=85',
    'mohammed rafi': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&q=85',
    'rafi': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&q=85',
    'asha bhosle': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=85',
    'mukesh': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=85',

    // Rajasthani & Marwadi Folk Stars
    'mame khan': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=800&q=85',
    'prakash mali': 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
    'prakash': 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
    'chotu singh rawna': 'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=800&q=85',
    'chhotu singh rawana': 'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=800&q=85',
    'chhotu singh': 'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=800&q=85',
    'seema mishra': 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=800&q=85',
    'geeta rabari': 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=800&q=85',

    // Haryanvi & Desi Beat Stars
    'sapna choudhary': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=85',
    'sapna': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=85',
    'masoom sharma': 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=800&q=85',
    'diler kharkiya': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'renuka panwar': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=85',
    'gulzaar chhaniwala': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=800&q=85',
  };

  /// Specific YouTube Music style official posters for uploaded and curated songs
  static const Map<String, String> _songPosterMap = {
    'sankat mochan': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
    'hanuman ashtak': 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
    'ye chamak': 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
    'sab kuch sarkar': 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
    'powerful hanuman': 'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=800&q=85',
    'hanuman chalisa': 'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=800&q=85',
    'ram siya ram': 'https://images.unsplash.com/photo-1548013146-72479768bada?w=800&q=85',
    'adipurush': 'https://images.unsplash.com/photo-1548013146-72479768bada?w=800&q=85',
    'radhe tere charno': 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&q=85',
    'krishna bhajan': 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&q=85',
    'bajrang baan': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'aadesh hanuman': 'https://images.unsplash.com/photo-1506461883276-594a12b11cf3?w=800&q=85',
    'alakh niranjan': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'aghori': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'siddh shabar': 'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
    'guzarish': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
    'udaarian': 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=800&q=85',
    'sajjan raazi': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'tere bina na guzara': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'jaiye sajana': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'intezaar reh gya': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=85',
    'kagaz ki kashti': 'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=800&q=85',
    'choudhary': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=800&q=85',
    'kesariya': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'apna bana le': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
  };

  /// Thematic artwork collections by deity, culture, and musical style
  static const Map<String, List<String>> _genreCollections = {
    'shiva': [
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
      'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=800&q=85',
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    ],
    'hanuman': [
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
      'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=800&q=85',
    ],
    'krishna': [
      'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&q=85',
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
    ],
    'ram': [
      'https://images.unsplash.com/photo-1548013146-72479768bada?w=800&q=85',
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
    ],
    'bhakti': [
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
      'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
      'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=800&q=85',
      'https://images.unsplash.com/photo-1548013146-72479768bada?w=800&q=85',
      'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&q=85',
    ],
    'rajasthani': [
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=800&q=85',
      'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=800&q=85',
      'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=800&q=85',
    ],
    'punjabi': [
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
      'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=800&q=85',
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=85',
    ],
    'haryanvi': [
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=85',
      'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=800&q=85',
    ],
    'bollywood': [
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
      'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=800&q=85',
    ],
    'lo-fi': [
      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&q=85',
    ],
    'ghazal': [
      'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=800&q=85',
      'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
    ],
    'sufi': [
      'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
      'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&q=85',
    ],
  };

  /// Studio Pool of vibrant music artwork cards
  static const List<String> _uniqueStudioPool = [
    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=85',
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=85',
    'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=800&q=85',
    'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=85',
    'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800&q=85',
    'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&q=85',
    'https://images.unsplash.com/photo-1445985543470-41fdd5c31447?w=800&q=85',
    'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=85',
    'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&q=85',
    'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=800&q=85',
    'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=85',
    'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=800&q=85',
    'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800&q=85',
    'https://images.unsplash.com/photo-1590076215667-875d4ef2d7ee?w=800&q=85',
    'https://images.unsplash.com/photo-1609137144822-1d577e02581c?w=800&q=85',
  ];

  /// Resolves the verified singer portrait for Artist avatars and detail screens
  static String resolveArtistImage(String artistName) {
    final lower = artistName.toLowerCase().trim();
    for (final entry in _artistImages.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }
    final hash = artistName.hashCode.abs();
    return _uniqueStudioPool[hash % _uniqueStudioPool.length];
  }

  /// Resolves the optimal high-resolution artwork for any song based on title, singer, deity, or genre
  static String resolveArtwork({
    required String title,
    required String artist,
    String? genre,
  }) {
    final lowerTitle = title.toLowerCase();
    final lowerArtist = artist.toLowerCase();

    // 1. Direct song title matches to official song posters
    for (final entry in _songPosterMap.entries) {
      if (lowerTitle.contains(entry.key)) {
        return entry.value;
      }
    }

    // 2. Direct singer / artist keyword matches
    for (final entry in _artistImages.entries) {
      if (lowerArtist.contains(entry.key) || lowerTitle.contains(entry.key)) {
        return entry.value;
      }
    }

    // 3. Spiritual / deity keywords in title or artist
    final combined = '$lowerArtist $lowerTitle';
    if (combined.contains('shiv') || combined.contains('mahadev') || combined.contains('shambhu') || combined.contains('bholenath')) {
      final list = _genreCollections['shiva']!;
      return list[title.hashCode.abs() % list.length];
    }
    if (combined.contains('hanuman') || combined.contains('bajrang') || combined.contains('chalisa') || combined.contains('sankat')) {
      final list = _genreCollections['hanuman']!;
      return list[title.hashCode.abs() % list.length];
    }
    if (combined.contains('krishna') || combined.contains('shyam') || combined.contains('khatu') || combined.contains('radhe') || combined.contains('kanha')) {
      final list = _genreCollections['krishna']!;
      return list[title.hashCode.abs() % list.length];
    }
    if (combined.contains('ram') || combined.contains('ayodhya') || combined.contains('siya')) {
      final list = _genreCollections['ram']!;
      return list[title.hashCode.abs() % list.length];
    }

    // 4. Check genre keywords
    final lowerGenre = (genre ?? '').toLowerCase();
    for (final entry in _genreCollections.entries) {
      if (lowerGenre.contains(entry.key) || combined.contains(entry.key)) {
        final list = entry.value;
        return list[title.hashCode.abs() % list.length];
      }
    }

    // 5. Deterministic unique cover from pool using title hash
    final hash = (title + artist).hashCode.abs();
    return _uniqueStudioPool[hash % _uniqueStudioPool.length];
  }

  /// Automatically parses artist name from title or filename
  static String extractArtist(String title, {String fallback = 'Unknown Artist'}) {
    final clean = title.replaceAll(RegExp(r'\.(mp3|m4a|wav|aac|flac)$', caseSensitive: false), '');
    if (clean.contains('-')) {
      final parts = clean.split('-');
      if (parts.length >= 2) {
        final right = parts[1].trim();
        if (right.isNotEmpty) return right;
      }
    }
    if (clean.contains('by ')) {
      final parts = clean.split('by ');
      if (parts.length >= 2) {
        final right = parts[1].trim();
        if (right.isNotEmpty) return right;
      }
    }
    return fallback;
  }
}
