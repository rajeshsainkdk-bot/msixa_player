import 'song.dart';

class Artist {
  final String id;
  final String name;
  final int songCount;
  final List<Song> songs;
  final List<String> genres;
  final String coverUrl;
  final bool isVerified;

  const Artist({
    required this.id,
    required this.name,
    required this.songCount,
    required this.songs,
    this.genres = const [],
    this.coverUrl = '',
    this.isVerified = true,
  });

  String get genreSummary => genres.isNotEmpty ? genres.join(', ') : 'All Indian Music';
}

