class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration; // in seconds
  final String streamUrl;
  final String coverUrl;
  final String genre;
  final String license;
  final String licenseUrl;
  final String source;
  bool isFavorite;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.streamUrl,
    required this.coverUrl,
    this.genre = 'Electronic',
    this.license = 'Creative Commons BY-SA',
    this.licenseUrl = 'https://creativecommons.org/licenses/',
    this.source = 'Jamendo Free Catalog',
    this.isFavorite = false,
  });

  String get formattedDuration {
    final minutes = (duration ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get isOffline =>
      streamUrl.startsWith('/') ||
      streamUrl.startsWith('content://') ||
      streamUrl.startsWith('file://') ||
      id.startsWith('device_') ||
      genre == 'Offline';

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? streamUrl,
    String? coverUrl,
    String? genre,
    String? license,
    String? licenseUrl,
    String? source,
    bool? isFavorite,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      streamUrl: streamUrl ?? this.streamUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      genre: genre ?? this.genre,
      license: license ?? this.license,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      source: source ?? this.source,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'streamUrl': streamUrl,
      'coverUrl': coverUrl,
      'genre': genre,
      'license': license,
      'licenseUrl': licenseUrl,
      'source': source,
      'isFavorite': isFavorite,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String? ?? 'Msixa Player Catalog',
      duration: (json['duration'] as num?)?.toInt() ?? 180,
      streamUrl: json['streamUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      genre: json['genre'] as String? ?? 'Chill',
      license: json['license'] as String? ?? 'Creative Commons',
      licenseUrl: json['licenseUrl'] as String? ?? 'https://creativecommons.org/',
      source: json['source'] as String? ?? 'Legal Free Music',
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
