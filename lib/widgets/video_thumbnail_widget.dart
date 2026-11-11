import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../services/device_video_service.dart';
import '../theme/app_colors.dart';

/// Renders genuine video thumbnails extracted from device video files
/// Supports:
/// - Instant memory caching
/// - Background frame extraction via Android MediaStore / MediaMetadataRetriever
/// - Disk caching in system temp directory for instant re-loads
/// - MX Player style duration badge at bottom-right
class VideoThumbnailWidget extends StatefulWidget {
  final VideoItem video;
  final double width;
  final double height;
  final double borderRadius;
  final bool showDurationBadge;

  const VideoThumbnailWidget({
    Key? key,
    required this.video,
    this.width = 96,
    this.height = 68,
    this.borderRadius = 10,
    this.showDurationBadge = true,
  }) : super(key: key);

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbnailBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id || oldWidget.video.path != widget.video.path) {
      _loadThumbnail();
    }
  }

  void _loadThumbnail() {
    final cached = DeviceVideoService.getCachedThumbnail(widget.video.path, id: widget.video.id);
    if (cached != null) {
      _thumbnailBytes = cached;
      _isLoading = false;
      return;
    }

    _isLoading = true;
    DeviceVideoService.getVideoThumbnail(widget.video.path, id: widget.video.id).then((bytes) {
      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFF141C2B),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_thumbnailBytes != null && _thumbnailBytes!.isNotEmpty)
              Image.memory(
                _thumbnailBytes!,
                width: widget.width,
                height: widget.height,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _buildFallback(),
              )
            else
              _buildFallback(),

            // Duration badge at bottom-right (MX Player style)
            if (widget.showDurationBadge && widget.video.formattedDuration.isNotEmpty)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12, width: 0.5),
                  ),
                  child: Text(
                    widget.video.formattedDuration,
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
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B2438),
            AppColors.accentCyan.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white.withOpacity(0.7),
          size: widget.height * 0.42,
        ),
      ),
    );
  }
}

