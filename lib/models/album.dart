import 'song.dart';

class Album {
  final String id;
  final String title;
  final String artist;
  final int songCount;
  final List<Song> songs;
  final String genre;
  final String coverUrl;
  final String? year;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.songCount,
    required this.songs,
    this.genre = 'All Indian',
    this.coverUrl = '',
    this.year,
  });

  int get totalDurationSeconds =>
      songs.fold(0, (sum, song) => sum + song.duration);

  String get formattedTotalDuration {
    final totalSec = totalDurationSeconds;
    final minutes = totalSec ~/ 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remMinutes = minutes % 60;
      return '${hours}h ${remMinutes}m';
    }
    return '${minutes} mins';
  }
}

