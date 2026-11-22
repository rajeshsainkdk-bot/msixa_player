class ShortVideoItem {
  final String id;
  final String title;
  final String author;
  final String? streamUrl;
  final String thumbnailUrl;
  final Duration duration;
  final String category;
  bool isLiked;
  int likesCount;
  int shareCount;
  bool isDownloaded;
  String? localPath;

  ShortVideoItem({
    required this.id,
    required this.title,
    required this.author,
    this.streamUrl,
    required this.thumbnailUrl,
    this.duration = const Duration(seconds: 30),
    this.category = 'Trending',
    this.isLiked = false,
    this.likesCount = 1200,
    this.shareCount = 350,
    this.isDownloaded = false,
    this.localPath,
  });

  ShortVideoItem copyWith({
    String? id,
    String? title,
    String? author,
    String? streamUrl,
    String? thumbnailUrl,
    Duration? duration,
    String? category,
    bool? isLiked,
    int? likesCount,
    int? shareCount,
    bool? isDownloaded,
    String? localPath,
  }) {
    return ShortVideoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      streamUrl: streamUrl ?? this.streamUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      shareCount: shareCount ?? this.shareCount,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'streamUrl': streamUrl,
    'thumbnailUrl': thumbnailUrl,
    'durationMs': duration.inMilliseconds,
    'category': category,
    'isLiked': isLiked,
    'likesCount': likesCount,
    'shareCount': shareCount,
    'isDownloaded': isDownloaded,
    'localPath': localPath,
  };

  factory ShortVideoItem.fromJson(Map<String, dynamic> json) {
    return ShortVideoItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Shorts Video',
      author: json['author'] as String? ?? 'Msixa Creator',
      streamUrl: json['streamUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 30000),
      category: json['category'] as String? ?? 'Trending',
      isLiked: json['isLiked'] as bool? ?? false,
      likesCount: json['likesCount'] as int? ?? 1000,
      shareCount: json['shareCount'] as int? ?? 200,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      localPath: json['localPath'] as String?,
    );
  }
}
