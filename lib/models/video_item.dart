/// Model representing a local video stored on the user's Android device.
class VideoItem {
  final String id;
  final String title;
  final String displayName;
  final String path;
  final int duration; // in milliseconds
  final int size; // in bytes
  final String resolution;
  final String folder;
  final int dateAdded;

  VideoItem({
    required this.id,
    required this.title,
    required this.displayName,
    required this.path,
    required this.duration,
    required this.size,
    this.resolution = 'HD',
    this.folder = 'Videos',
    this.dateAdded = 0,
  });

  /// Formatted duration string: e.g. "04:15" or "01:22:30"
  String get formattedDuration {
    if (duration <= 0) return '00:00';
    final totalSeconds = duration ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formatted file size string: e.g. "45.2 MB" or "1.2 GB"
  String get formattedSize {
    if (size <= 0) return '';
    final mb = size / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(1)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'displayName': displayName,
    'path': path,
    'duration': duration,
    'size': size,
    'resolution': resolution,
    'folder': folder,
    'dateAdded': dateAdded,
  };

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Video',
    displayName: json['displayName']?.toString() ?? 'Video',
    path: json['path']?.toString() ?? '',
    duration: (json['duration'] is num) ? (json['duration'] as num).toInt() : 0,
    size: (json['size'] is num) ? (json['size'] as num).toInt() : 0,
    resolution: json['resolution']?.toString() ?? 'HD',
    folder: json['folder']?.toString() ?? 'Videos',
    dateAdded: (json['dateAdded'] is num) ? (json['dateAdded'] as num).toInt() : 0,
  );
}
