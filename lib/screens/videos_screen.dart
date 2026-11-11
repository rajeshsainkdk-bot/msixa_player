import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/video_item.dart';
import '../services/device_video_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import 'video_player_screen.dart';

/// Screen displaying all local device video files organized by folders
/// with instant search, folder filter chips, and in-app video playback in Msixa.
class VideosScreen extends StatefulWidget {
  const VideosScreen({Key? key}) : super(key: key);

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  List<VideoItem> _allVideos = [];
  bool _isLoading = true;
  String _selectedFolder = 'All';
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    await DeviceVideoService.requestVideoPermission();
    final list = await DeviceVideoService.fetchDeviceVideos();
    if (mounted) {
      setState(() {
        _allVideos = list;
        _isLoading = false;
      });
    }
  }

  List<String> _getFolders() {
    final Set<String> folders = {'All'};
    for (final v in _allVideos) {
      if (v.folder.isNotEmpty) {
        folders.add(v.folder);
      }
    }
    return folders.toList();
  }

  List<VideoItem> get _filteredVideos {
    return _allVideos.where((v) {
      final matchesFolder = _selectedFolder == 'All' || v.folder == _selectedFolder;
      final matchesSearch = _searchQuery.isEmpty ||
          v.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFolder && matchesSearch;
    }).toList();
  }

  void _openPlayer(VideoItem video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(video: video),
      ),
    );
  }

  void _showVideoDetails(VideoItem video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.accentCyan),
                  const SizedBox(width: 8),
                  const Text(
                    'Video Details',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              _detailRow('File Name', video.displayName),
              _detailRow('Folder', video.folder),
              _detailRow('Duration', video.formattedDuration),
              _detailRow('File Size', video.formattedSize),
              _detailRow('Resolution', video.resolution),
              _detailRow('Storage Path', video.path),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    final folders = _getFolders();
    final displayList = _filteredVideos;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _isSearching
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search videos...',
                              hintStyle: const TextStyle(color: Colors.white54),
                              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accentCyan),
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            ),
                            onChanged: (val) {
                              setState(() => _searchQuery = val.trim());
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () {
                            setState(() {
                              _isSearching = false;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.video_library_rounded, color: AppColors.accentCyan, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.isHindi ? 'डिवाइस वीडियो' : 'Device Videos',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_allVideos.length} ${lang.isHindi ? 'वीडियो उपलब्ध' : 'videos detected'}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Search Videos',
                          icon: const Icon(Icons.search_rounded, color: Colors.white),
                          onPressed: () => setState(() => _isSearching = true),
                        ),
                        IconButton(
                          tooltip: 'Pick Video from Storage',
                          icon: const Icon(Icons.file_open_rounded, color: AppColors.accentCyan),
                          onPressed: () async {
                            final picked = await DeviceVideoService.pickCustomVideo();
                            if (picked != null) {
                              _openPlayer(picked);
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'Rescan Videos',
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                          onPressed: _loadVideos,
                        ),
                      ],
                    ),
            ),

            // Horizontal Folder Filter Chips
            if (folders.length > 1)
              SizedBox(
                height: 42,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: folders.length,
                  itemBuilder: (ctx, i) {
                    final folder = folders[i];
                    final isSelected = _selectedFolder == folder;
                    final count = folder == 'All'
                        ? _allVideos.length
                        : _allVideos.where((v) => v.folder == folder).length;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text('$folder ($count)'),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        backgroundColor: AppColors.surface,
                        selectedColor: AppColors.accentCyan,
                        checkmarkColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.accentCyan : Colors.white12,
                          ),
                        ),
                        onSelected: (_) {
                          setState(() => _selectedFolder = folder);
                        },
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),

            // Video List or Empty State
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accentCyan),
                    )
                  : displayList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_off_rounded, size: 64, color: Colors.white.withOpacity(0.2)),
                                const SizedBox(height: 12),
                                Text(
                                  lang.isHindi ? 'कोई वीडियो नहीं मिला' : 'No Videos Found',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  lang.isHindi
                                      ? 'फ़ोन में कोई वीडियो फ़ाइल नहीं मिली या परमिशन आवश्यक है।'
                                      : 'No video files found in storage or permission required.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentCyan,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () async {
                                    final picked = await DeviceVideoService.pickCustomVideo();
                                    if (picked != null) {
                                      _openPlayer(picked);
                                    }
                                  },
                                  icon: const Icon(Icons.folder_open_rounded),
                                  label: Text(lang.isHindi ? 'स्टोरेज से वीडियो चुनें' : 'Pick Video File'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                          itemCount: displayList.length,
                          itemBuilder: (ctx, i) {
                            final video = displayList[i];
                            return _buildVideoCard(video, lang);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(VideoItem video, LanguageService lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openPlayer(video),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Video Thumbnail Box with Duration Badge
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1B2438),
                          AppColors.accentCyan.withOpacity(0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Center(
                      child: Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 28),
                    ),
                  ),
                  if (video.formattedDuration.isNotEmpty)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Title and Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Folder Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.folder,
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Resolution Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.resolution,
                            style: const TextStyle(color: AppColors.accentCyan, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // File Size
                        if (video.formattedSize.isNotEmpty)
                          Text(
                            video.formattedSize,
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Options Popup Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'play_in') {
                    _openPlayer(video);
                  } else if (val == 'play_ext') {
                    DeviceVideoService.openExternalPlayer(video.path, id: video.id);
                  } else if (val == 'share') {
                    Share.shareXFiles([XFile(video.path)], text: video.title);
                  } else if (val == 'details') {
                    _showVideoDetails(video);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'play_in',
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow_rounded, color: AppColors.accentCyan, size: 18),
                        SizedBox(width: 8),
                        Text('Play In-App', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'play_ext',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Play in External App', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share_rounded, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Share Video', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'details',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Video Details', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
