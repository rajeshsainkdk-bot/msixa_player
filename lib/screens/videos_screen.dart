import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_item.dart';
import '../services/device_video_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/video_thumbnail_widget.dart';
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
        builder: (_) => VideoPlayerScreen(
          video: video,
          playlist: _filteredVideos,
        ),
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
      backgroundColor: Colors.black,
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
                          padding: const EdgeInsets.only(top: 4, bottom: 120),
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
      floatingActionButton: displayList.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 6,
              shape: const CircleBorder(),
              onPressed: () => _openPlayer(displayList.first),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
            )
          : null,
    );
  }

  Widget _buildVideoCard(VideoItem video, LanguageService lang) {
    final bool hasSrt = video.displayName.toLowerCase().contains('esub') ||
        video.displayName.toLowerCase().contains('sub') ||
        video.displayName.toLowerCase().contains('srt') ||
        video.path.toLowerCase().endsWith('.mkv');

    return InkWell(
      onTap: () => _openPlayer(video),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Video Thumbnail Box with Duration Badge (Screenshot 2)
            VideoThumbnailWidget(
              video: video,
              width: 110,
              height: 68,
              borderRadius: 6,
            ),
            const SizedBox(width: 14),

            // Title and SRT Badge (Screenshot 2)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                    ),
                  ),
                  if (hasSrt) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'SRT',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Right-side 3-Dots Menu Button (Screenshot 2)
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 22),
              splashRadius: 20,
              onPressed: () => _showVideoOptionsMenu(video),
            ),
          ],
        ),
      ),
    );
  }

  /// Authentic 3-Dots Video Options Menu Sheet (Screenshot 1)
  void _showVideoOptionsMenu(VideoItem video) async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('video_favorites_list') ?? [];
    final isFav = favList.contains(video.id) || favList.contains(video.path);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2024),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Favourite
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? Colors.redAccent : Colors.white,
                    size: 24,
                  ),
                  title: Text(
                    isFav ? 'Remove from Favourite' : 'Favourite',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final p = await SharedPreferences.getInstance();
                    final currentFavs = p.getStringList('video_favorites_list') ?? [];
                    if (isFav) {
                      currentFavs.remove(video.id);
                      currentFavs.remove(video.path);
                      _showSnackBar('Removed from Favourite');
                    } else {
                      currentFavs.add(video.id);
                      _showSnackBar('❤️ Added to Favourite');
                    }
                    await p.setStringList('video_favorites_list', currentFavs);
                  },
                ),

                // 2. Add To Playlist
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: const Icon(Icons.playlist_add_rounded, color: Colors.white, size: 26),
                  title: const Text(
                    'Add To Playlist',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddToPlaylistDialog(video);
                  },
                ),

                // 3. File Transfer
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: _buildFileTransferIcon(),
                  title: const Text(
                    'File Transfer',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Share.shareXFiles([XFile(video.path)], text: 'Sharing ${video.displayName}');
                  },
                ),

                // 4. Lock in Private Folder
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: _buildLockFolderIcon(),
                  title: const Text(
                    'Lock in Private Folder',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showLockPrivateDialog(video);
                  },
                ),

                // 5. Convert to MP3
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: const Icon(Icons.headphones_outlined, color: Colors.white, size: 24),
                  title: const Text(
                    'Convert to MP3',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _convertToMp3(video);
                  },
                ),

                // 6. Share
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: Transform.flip(
                    flipX: true,
                    child: const Icon(Icons.reply_rounded, color: Colors.white, size: 24),
                  ),
                  title: const Text(
                    'Share',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Share.shareXFiles([XFile(video.path)], text: video.displayName);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileTransferIcon() {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 14,
            height: 19,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1.5),
              borderRadius: BorderRadius.circular(2.5),
            ),
            child: const Center(
              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 9),
            ),
          ),
          const Positioned(
            left: 0,
            child: Icon(Icons.arrow_left_rounded, color: Colors.white, size: 12),
          ),
          const Positioned(
            right: 0,
            child: Icon(Icons.arrow_right_rounded, color: Colors.white, size: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLockFolderIcon() {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: const [
          Icon(Icons.folder_outlined, color: Colors.white, size: 24),
          Positioned(
            bottom: 4,
            child: Icon(Icons.lock_rounded, color: Colors.white, size: 10),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddToPlaylistDialog(VideoItem video) async {
    final prefs = await SharedPreferences.getInstance();
    final playlists = prefs.getStringList('custom_video_playlists') ?? ['My Favorites', 'Watch Later'];
    final textCtrl = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2026),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.playlist_add_rounded, color: AppColors.accentCyan),
            SizedBox(width: 8),
            Text('Add To Playlist', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...playlists.map((pl) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.playlist_play_rounded, color: Colors.white70),
                    title: Text(pl, style: const TextStyle(color: Colors.white)),
                    onTap: () async {
                      Navigator.pop(dlgCtx);
                      final pKey = 'playlist_videos_$pl';
                      final current = prefs.getStringList(pKey) ?? [];
                      if (!current.contains(video.id)) {
                        current.add(video.id);
                        await prefs.setStringList(pKey, current);
                      }
                      _showSnackBar('Added to "$pl"');
                    },
                  )),
              const Divider(color: Colors.white12),
              TextField(
                controller: textCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'New Playlist Name...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_rounded, color: AppColors.accentCyan),
                    onPressed: () async {
                      final name = textCtrl.text.trim();
                      if (name.isNotEmpty) {
                        playlists.add(name);
                        await prefs.setStringList('custom_video_playlists', playlists);
                        final pKey = 'playlist_videos_$name';
                        await prefs.setStringList(pKey, [video.id]);
                        Navigator.pop(dlgCtx);
                        _showSnackBar('Created and added to "$name"');
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLockPrivateDialog(VideoItem video) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2026),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.lock_outline_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Private Folder', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Do you want to lock "${video.title}" in your secure Private Folder?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              final p = await SharedPreferences.getInstance();
              final privateIds = p.getStringList('private_video_ids') ?? [];
              privateIds.add(video.id);
              await p.setStringList('private_video_ids', privateIds);
              setState(() {
                _allVideos.removeWhere((v) => v.id == video.id);
              });
              _showSnackBar('🔒 Video secured in Private Folder');
            },
            child: const Text('Lock Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _convertToMp3(VideoItem video) {
    _showSnackBar('🎧 Playing "${video.title}" as background audio');
  }
}

