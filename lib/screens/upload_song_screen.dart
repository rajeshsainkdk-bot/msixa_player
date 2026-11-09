import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/cloud_backend_service.dart';
import '../services/r2_storage_service.dart';
import '../providers/player_provider.dart';

class UploadSongScreen extends StatefulWidget {
  const UploadSongScreen({Key? key}) : super(key: key);

  @override
  State<UploadSongScreen> createState() => _UploadSongScreenState();
}

class _UploadSongScreenState extends State<UploadSongScreen> {
  final _backend = CloudBackendService();
  final _titleCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _albumCtrl = TextEditingController();
  final _coverUrlCtrl = TextEditingController();

  String _selectedGenre = 'Rajasthani';
  String? _pickedFilePath;
  String? _pickedFileName;
  int? _pickedFileSize;

  Song? _duplicateMatch;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadStatusText;
  String? _errorMessage;

  final List<String> _genres = [
    'Rajasthani',
    'Bhakti',
    'Haryanvi',
    'Punjabi',
    'Sufi',
    'Bollywood',
    'Desi Lo-Fi',
    'Ghazal',
    'DJ Remix',
    'Bhojpuri',
    'Spiritual',
    'Folk Fusion',
    'Classical',
    'Pop / Indie',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onFieldChanged);
    _artistCtrl.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onFieldChanged);
    _artistCtrl.removeListener(_onFieldChanged);
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _coverUrlCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final title = _titleCtrl.text.trim();
    final artist = _artistCtrl.text.trim();

    if (title.length >= 3) {
      final duplicate = _backend.checkDuplicateSong(title: title, artist: artist);
      setState(() {
        _duplicateMatch = duplicate;
      });
    } else {
      if (_duplicateMatch != null) {
        setState(() => _duplicateMatch = null);
      }
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'flac'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        final size = await file.length();
        final name = result.files.single.name;

        setState(() {
          _pickedFilePath = path;
          _pickedFileName = name;
          _pickedFileSize = size;
          _errorMessage = null;

          // Auto-fill title from filename if empty
          if (_titleCtrl.text.isEmpty) {
            final cleanName = name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ');
            _titleCtrl.text = cleanName;
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'फ़ाइल चुनने में समस्या: $e');
    }
  }

  Future<void> _submitSong() async {
    final title = _titleCtrl.text.trim();
    final artist = _artistCtrl.text.trim();
    final album = _albumCtrl.text.trim();
    final cover = _coverUrlCtrl.text.trim();

    if (_pickedFilePath == null) {
      setState(() => _errorMessage = 'कृपया फ़ोन से कोई MP3 गाना चुनें');
      return;
    }
    if (title.isEmpty) {
      setState(() => _errorMessage = 'गाने का नाम (Title) दर्ज करें');
      return;
    }
    if (artist.isEmpty) {
      setState(() => _errorMessage = 'गायक या आर्टिस्ट का नाम (Artist) दर्ज करें');
      return;
    }
    if (_duplicateMatch != null) {
      setState(() => _errorMessage = 'यह गाना पहले से मौजूद है, इसे दोबारा अपलोड नहीं किया जा सकता।');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
      _uploadStatusText = 'गाना प्रोसेस हो रहा है...';
      _errorMessage = null;
    });

    try {
      String finalAudioUrl = _pickedFilePath!;
      final r2 = R2StorageService();

      if (r2.isConfigured) {
        setState(() {
          _uploadStatusText = 'Cloudflare R2 क्लाउड पर अपलोड हो रहा है...';
          _uploadProgress = 0.3;
        });

        try {
          final cloudUrl = await r2.uploadAudioFile(
            File(_pickedFilePath!),
            customId: 'user_${DateTime.now().millisecondsSinceEpoch}',
            onProgress: (p) => setState(() => _uploadProgress = p),
          );
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            finalAudioUrl = cloudUrl;
          }
        } catch (e) {
          debugPrint('R2 Upload fallback: $e');
        }
      }

      final song = await _backend.submitUserSong(
        title: title,
        artist: artist,
        album: album.isEmpty ? 'Community Music' : album,
        genre: _selectedGenre,
        audioPath: finalAudioUrl,
        coverUrl: cover.isNotEmpty ? cover : null,
      );

      setState(() => _isUploading = false);

      if (!mounted) return;

      // Show Celebration Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 28),
              SizedBox(width: 10),
              Text('गाना सबमिट हुआ!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'आपका गाना "${song.title}" रिव्यू के लिए एडमिन के पास भेज दिया गया है।',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B101D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.hourglass_top_rounded, color: Colors.amberAccent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'एडमिन के अप्रूव (Approve) करते ही यह गाना सभी यूज़र्स के होम पेज पर दिखने लगेगा।',
                        style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              child: const Text('ठीक है (Done)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'अपलोड करने में विफल: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'गाना अपलोड करें (Upload Song)',
          style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00E5FF).withOpacity(0.12), const Color(0xFF4F46E5).withOpacity(0.12)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: Color(0xFF00E5FF), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('कम्युनिटी म्यूज़िक शेयरिंग', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('कोई भी नया MP3 अपलोड करें। एडमिन अप्रूवल के बाद यह सभी के लिए लाइव होगा।', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // File Picker Box
            GestureDetector(
              onTap: _pickAudioFile,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131A2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _pickedFilePath != null ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.12),
                    width: _pickedFilePath != null ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _pickedFilePath != null ? const Color(0xFF00E5FF).withOpacity(0.15) : Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _pickedFilePath != null ? Icons.audio_file_rounded : Icons.folder_open_rounded,
                        color: _pickedFilePath != null ? const Color(0xFF00E5FF) : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _pickedFileName ?? 'फोन से MP3 ऑडियो फ़ाइल चुनें',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _pickedFileName != null ? Colors.white : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pickedFileSize != null
                          ? '${(_pickedFileSize! / (1024 * 1024)).toStringAsFixed(2)} MB • तैयार'
                          : 'MP3, M4A, WAV समर्थित (Click to browse)',
                      style: TextStyle(
                        fontSize: 11,
                        color: _pickedFileSize != null ? const Color(0xFF00E5FF) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Duplicate Detection Alert
            if (_duplicateMatch != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 22),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'यह गाना पहले से उपलब्ध है! (Already in Library)',
                            style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              _duplicateMatch!.coverUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: Colors.grey.shade800),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_duplicateMatch!.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                                Text(_duplicateMatch!.artist, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              context.read<PlayerProvider>().playSong(_duplicateMatch!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('बजाया जा रहा है: ${_duplicateMatch!.title}')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('सुनें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else if (_titleCtrl.text.length >= 3) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 18),
                    SizedBox(width: 8),
                    Text('✅ नया गाना! यह हमारे डेटाबेस में पहले से नहीं है।', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              const SizedBox(height: 12),
            ],

            // Input Fields
            _buildTextField(controller: _titleCtrl, label: 'गाने का शीर्षक (Song Title)', hint: 'उदा. राम सिया राम / Kesariya'),
            const SizedBox(height: 14),
            _buildTextField(controller: _artistCtrl, label: 'गायक / आर्टिस्ट (Artist)', hint: 'उदा. Sachet Tandon, Arijit Singh'),
            const SizedBox(height: 14),
            _buildTextField(controller: _albumCtrl, label: 'एल्बम (Album - Optional)', hint: 'उदा. Single / Soundtrack'),
            const SizedBox(height: 14),

            // Genre Dropdown
            Text('संगीत विधा (Genre / Category)', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade300)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF131A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGenre,
                  dropdownColor: const Color(0xFF131A2A),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF)),
                  items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGenre = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            _buildTextField(
              controller: _coverUrlCtrl,
              label: 'पोस्टर आर्ट लिंक (Cover Image URL - Optional)',
              hint: 'https://images.unsplash.com/... (खाली छोड़ने पर डिफ़ॉल्ट पोस्टर लगेगा)',
            ),
            if (_isUploading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  backgroundColor: Colors.white10,
                  color: const Color(0xFF00E5FF),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _uploadStatusText ?? 'अपलोड हो रहा है...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 28),

            // Submit Button
            ElevatedButton(
              onPressed: (_isUploading || _duplicateMatch != null) ? null : _submitSong,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'एडमिन को सबमिट करें (Submit for Approval)',
                          style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade300),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

