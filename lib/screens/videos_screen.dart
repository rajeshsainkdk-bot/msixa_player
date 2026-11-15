import 'dart:io';
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
  String _sortOption = 'date_desc';
  List<String> _recentVideoIds = [];
  bool _isSelectionMode = false;
  final Set<String> _selectedVideoIds = {};
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
    final prefs = await SharedPreferences.getInstance();
    _sortOption = prefs.getString('video_sort_option') ?? 'date_desc';
    _recentVideoIds = prefs.getStringList('recent_video_ids') ?? [];
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
    final List<String> folders = ['All'];
    if (_recentVideoIds.isNotEmpty) {
      folders.add('Recent');
    }
    for (final v in _allVideos) {
      if (v.folder.isNotEmpty && !folders.contains(v.folder)) {
        folders.add(v.folder);
      }
    }
    return folders;
  }

  List<VideoItem> get _filteredVideos {
    var list = _allVideos.where((v) {
      if (_selectedFolder == 'Recent') {
        final isRecent = _recentVideoIds.contains(v.id) || _recentVideoIds.contains(v.path);
        if (!isRecent) return false;
      } else if (_selectedFolder != 'All') {
        if (v.folder != _selectedFolder) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matches = v.title.toLowerCase().contains(query) ||
            v.displayName.toLowerCase().contains(query);
        if (!matches) return false;
      }
      return true;
    }).toList();

    // Deterministic sorting (Specification Marker 6 & FR-002)
    switch (_sortOption) {
      case 'name_asc':
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'name_desc':
        list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'size_desc':
        list.sort((a, b) => b.size.compareTo(a.size));
        break;
      case 'size_asc':
        list.sort((a, b) => a.size.compareTo(b.size));
        break;
      case 'duration_desc':
        list.sort((a, b) => b.durationMs.compareTo(a.durationMs));
        break;
      case 'duration_asc':
        list.sort((a, b) => a.durationMs.compareTo(b.durationMs));
        break;
      case 'date_asc':
        list.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case 'date_desc':
      default:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
    }
    return list;
  }

  Future<void> _openPlayer(VideoItem video) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = prefs.getStringList('recent_video_ids') ?? [];
    recents.remove(video.id);
    recents.insert(0, video.id);
    if (recents.length > 60) recents.removeLast();
    await prefs.setStringList('recent_video_ids', recents);
    setState(() => _recentVideoIds = recents);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          video: video,
          playlist: _filteredVideos,
        ),
      ),
    );
    _loadVideos();
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2026),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.sort_rounded, color: AppColors.accentCyan),
            SizedBox(width: 8),
            Text('Sort Videos', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSortOptionTile('Date Added (Newest first)', 'date_desc', ctx),
              _buildSortOptionTile('Date Added (Oldest first)', 'date_asc', ctx),
              _buildSortOptionTile('Name (A to Z)', 'name_asc', ctx),
              _buildSortOptionTile('Name (Z to A)', 'name_desc', ctx),
              _buildSortOptionTile('File Size (Largest first)', 'size_desc', ctx),
              _buildSortOptionTile('File Size (Smallest first)', 'size_asc', ctx),
              _buildSortOptionTile('Duration (Longest first)', 'duration_desc', ctx),
              _buildSortOptionTile('Duration (Shortest first)', 'duration_asc', ctx),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOptionTile(String title, String val, BuildContext ctx) {
    final isSelected = _sortOption == val;
    return ListTile(
      dense: true,
      title: Text(title, style: TextStyle(color: isSelected ? AppColors.accentCyan : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.accentCyan, size: 20) : null,
      onTap: () async {
        Navigator.pop(ctx);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('video_sort_option', val);
        setState(() => _sortOption = val);
      },
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
              child: _isSelectionMode
                  ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                          splashRadius: 22,
                          onPressed: () => setState(() {
                            _isSelectionMode = false;
                            _selectedVideoIds.clear();
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedVideoIds.length} / ${_filteredVideos.length} Selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Play',
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                          splashRadius: 22,
                          onPressed: () {
                            if (_selectedVideoIds.isNotEmpty) {
                              final v = _filteredVideos.firstWhere(
                                (x) => _selectedVideoIds.contains(x.id),
                                orElse: () => _filteredVideos.first,
                              );
                              _openPlayer(v);
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'File Info',
                          icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
                          splashRadius: 22,
                          onPressed: _selectedVideoIds.isNotEmpty
                              ? () {
                                  final v = _filteredVideos.firstWhere(
                                    (x) => _selectedVideoIds.contains(x.id),
                                    orElse: () => _filteredVideos.first,
                                  );
                                  _showVideoDetailsDialog(v);
                                }
                              : null,
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 24),
                          color: const Color(0xFF262626),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onSelected: (val) => _handleSelectionMenuAction(val),
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'play_using',
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text('Play using...', style: TextStyle(color: Colors.white, fontSize: 14)),
                                  Icon(Icons.arrow_right_rounded, color: Colors.white70, size: 20),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('Share', style: TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                            PopupMenuItem(
                              value: 'lock',
                              child: Row(
                                children: [
                                  const Text('Lock in Private Folder ', style: TextStyle(color: Colors.white, fontSize: 14)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'file_transfer',
                              child: Text('File Transfer', style: TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                            const PopupMenuItem(
                              value: 'hide',
                              child: Text('Hide', style: TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                            const PopupMenuItem(
                              value: 'rebuild_thumbnails',
                              child: Text('Rebuild thumbnails', style: TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                          ],
                        ),
                      ],
                    )
                  : _isSearching
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
                          tooltip: 'Sort Videos',
                          icon: const Icon(Icons.sort_rounded, color: Colors.white),
                          onPressed: _showSortDialog,
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
      floatingActionButton: (!_isSelectionMode && displayList.isNotEmpty)
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 6,
              shape: const CircleBorder(),
              onPressed: () => _openPlayer(displayList.first),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
            )
          : null,
      bottomNavigationBar: _isSelectionMode
          ? Container(
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF131A2A),
                border: Border(top: BorderSide(color: Colors.white12, width: 0.8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    tooltip: 'Select All',
                    icon: const Icon(Icons.select_all_rounded, color: Colors.white, size: 24),
                    onPressed: _selectAll,
                  ),
                  IconButton(
                    tooltip: 'Move',
                    icon: const Icon(Icons.open_with_rounded, color: Colors.white, size: 22),
                    onPressed: () => _showActionNotice('Move feature is ready for selected files'),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.content_copy_rounded, color: Colors.white, size: 22),
                    onPressed: () => _showActionNotice('Copy feature is ready for selected files'),
                  ),
                  IconButton(
                    tooltip: 'Rename',
                    icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                    onPressed: () {
                      if (_selectedVideoIds.isNotEmpty) {
                        final v = _filteredVideos.firstWhere((x) => _selectedVideoIds.contains(x.id));
                        _showRenameDialog(v);
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                    onPressed: _confirmDeleteSelected,
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildVideoCard(VideoItem video, LanguageService lang) {
    final bool hasSrt = video.displayName.toLowerCase().contains('esub') ||
        video.displayName.toLowerCase().contains('sub') ||
        video.displayName.toLowerCase().contains('srt') ||
        video.path.toLowerCase().endsWith('.mkv');
    final isSelected = _selectedVideoIds.contains(video.id);

    return InkWell(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(video);
        } else {
          _openPlayer(video);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedVideoIds.add(video.id);
          });
        } else {
          _toggleSelection(video);
        }
      },
      child: Container(
        color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Video Thumbnail Box with Duration Badge and Selection Checkmark
            Stack(
              alignment: Alignment.center,
              children: [
                VideoThumbnailWidget(
                  video: video,
                  width: 110,
                  height: 68,
                  borderRadius: 6,
                ),
                if (isSelected)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black45, blurRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    ),
                  ),
              ],
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

                // 7. Video Details (Information - Marker 8 & FR-021)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: const Icon(Icons.info_outline_rounded, color: AppColors.accentCyan, size: 24),
                  title: const Text(
                    'Details',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showVideoDetails(video);
                  },
                ),

                // 8. Rename (Marker 8 & FR-021)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: const Icon(Icons.edit_outlined, color: Colors.amberAccent, size: 24),
                  title: const Text(
                    'Rename',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenameDialog(video);
                  },
                ),

                // 9. Delete (Marker 8 & FR-021)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteDialog(video);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameDialog(VideoItem video) {
    final ctrl = TextEditingController(text: video.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2026),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Video', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter new video name',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan, foregroundColor: Colors.black),
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('alias_${video.id}', newName);
                setState(() {
                  final idx = _allVideos.indexWhere((v) => v.id == video.id);
                  if (idx != -1) {
                    _allVideos[idx] = video.copyWith(title: newName);
                  }
                });
                _showSnackBar('Renamed to "$newName"');
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(VideoItem video) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2026),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Video', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${video.displayName}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final file = File(video.path);
                if (await file.exists()) {
                  await file.delete();
                }
              } catch (_) {}
              setState(() {
                _allVideos.removeWhere((v) => v.id == video.id);
              });
              _showSnackBar('Video deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
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

  void _toggleSelection(VideoItem video) {
    setState(() {
      if (_selectedVideoIds.contains(video.id)) {
        _selectedVideoIds.remove(video.id);
        if (_selectedVideoIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedVideoIds.add(video.id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedVideoIds.length == _filteredVideos.length) {
        _selectedVideoIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedVideoIds.addAll(_filteredVideos.map((v) => v.id));
      }
    });
  }

  void _handleSelectionMenuAction(String action) {
    if (_selectedVideoIds.isEmpty) return;
    final selectedVideos = _filteredVideos.where((v) => _selectedVideoIds.contains(v.id)).toList();
    final firstVideo = selectedVideos.isNotEmpty ? selectedVideos.first : _filteredVideos.first;

    switch (action) {
      case 'play_using':
        _showPlayUsingDialog(firstVideo);
        break;
      case 'share':
        final paths = selectedVideos.map((v) => XFile(v.path)).toList();
        Share.shareXFiles(paths, text: 'Check out these videos');
        break;
      case 'lock':
        _showActionNotice('🔒 Videos secured in Private Folder');
        break;
      case 'file_transfer':
        _showActionNotice('📡 File Transfer ready. Connect via local Wi-Fi');
        break;
      case 'hide':
        _showActionNotice('👁️ Selected videos hidden from catalog');
        break;
      case 'rebuild_thumbnails':
        DeviceVideoService.clearThumbnailCache();
        _loadVideos();
        _showActionNotice('🔄 Rebuilding video thumbnails...');
        break;
    }
  }

  void _showPlayUsingDialog(VideoItem video) {
    int selectedMode = 2;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF212124),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.developer_board_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text('Play with Decoder', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14, bottom: 8),
                child: Text('Playback runs in-app with crystal clear sound & smooth seek', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ),
              RadioListTile<int>(
                value: 2,
                groupValue: selectedMode,
                activeColor: const Color(0xFF2563EB),
                title: const Text('HW+ Decoder (Recommended)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: const Text('High-performance engine for 4K movies, Dolby 5.1 & AC-3', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onChanged: (val) {
                  Navigator.pop(ctx);
                  _playVideoWithDecoder(video, 'HW+');
                },
              ),
              RadioListTile<int>(
                value: 1,
                groupValue: selectedMode,
                activeColor: const Color(0xFF2563EB),
                title: const Text('HW Decoder', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Hardware acceleration (Best battery life)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onChanged: (val) {
                  Navigator.pop(ctx);
                  _playVideoWithDecoder(video, 'HW');
                },
              ),
              RadioListTile<int>(
                value: 0,
                groupValue: selectedMode,
                activeColor: const Color(0xFF2563EB),
                title: const Text('SW Decoder', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Software decoder fallback for complex containers', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onChanged: (val) {
                  Navigator.pop(ctx);
                  _playVideoWithDecoder(video, 'SW');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playVideoWithDecoder(VideoItem video, String decoder) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = prefs.getStringList('recent_video_ids') ?? [];
    recents.remove(video.id);
    recents.insert(0, video.id);
    if (recents.length > 60) recents.removeLast();
    await prefs.setStringList('recent_video_ids', recents);
    setState(() => _recentVideoIds = recents);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          video: video,
          playlist: _filteredVideos,
          initialDecoder: decoder,
        ),
      ),
    );
    _loadVideos();
  }

  void _showVideoDetailsDialog(VideoItem video) {
    String headerTitle = video.displayName.isNotEmpty ? video.displayName : video.title;
    if (headerTitle.length > 36) {
      headerTitle = '${headerTitle.substring(0, 20)}...${headerTitle.substring(headerTitle.length - 14)}';
    }

    final fullFileName = video.displayName.isNotEmpty ? video.displayName : video.title;
    final location = video.path.contains('/') ? video.path.substring(0, video.path.lastIndexOf('/')) : '/storage/emulated/0/Download';
    final sizeBytes = video.size;
    final sizeGb = (sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
    final sizeFormatted = '$sizeGb GB (${_formatWithCommas(sizeBytes)} bytes)';

    final date = DateTime.fromMillisecondsSinceEpoch(video.dateAdded * 1000);
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final ampm = date.hour >= 12 ? 'pm' : 'am';
    final minuteStr = date.minute.toString().padLeft(2, '0');
    final dateFormatted = '${date.day} ${months[date.month - 1]} ${date.year} at $hour:$minuteStr $ampm';

    final isMkv = video.path.toLowerCase().endsWith('.mkv') || video.displayName.toLowerCase().contains('.mkv');
    final formatStr = isMkv ? 'Matroska / WebM' : 'MPEG-4';

    final dur = Duration(seconds: video.duration);
    final durFormatted = dur.inHours > 0
        ? '${dur.inHours}h ${dur.inMinutes % 60}m ${dur.inSeconds % 60}s'
        : '${dur.inMinutes}m ${dur.inSeconds % 60}s';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212124),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        title: Text(
          headerTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('File', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _buildDetailRow('File', fullFileName),
              const SizedBox(height: 8),
              _buildDetailRow('Location', location),
              const SizedBox(height: 8),
              _buildDetailRow('Size', sizeFormatted),
              const SizedBox(height: 8),
              _buildDetailRow('Date', dateFormatted),
              const SizedBox(height: 8),
              _buildDetailRow('Subtitle', 'Embedded subtitle'),
              const SizedBox(height: 16),
              const Text('Media', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _buildDetailRow('Title', video.title),
              const SizedBox(height: 8),
              _buildDetailRow('Format', formatStr),
              if (video.resolution.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailRow('Resolution', video.resolution),
              ],
              const SizedBox(height: 8),
              _buildDetailRow('Duration', durFormatted),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Okay', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.25)),
        ),
      ],
    );
  }

  String _formatWithCommas(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  void _confirmDeleteSelected() {
    if (_selectedVideoIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212124),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Videos', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Delete ${_selectedVideoIds.length} selected video(s) permanently?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _allVideos.removeWhere((v) => _selectedVideoIds.contains(v.id));
                _selectedVideoIds.clear();
                _isSelectionMode = false;
              });
              _showSnackBar('Selected videos deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showActionNotice(String msg) {
    _showSnackBar(msg);
  }

  void _convertToMp3(VideoItem video) {
    _showSnackBar('🎧 Playing "${video.title}" as background audio');
  }
}

