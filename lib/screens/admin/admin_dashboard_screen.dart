import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/cloud_backend_service.dart';
import '../../services/language_service.dart';
import '../../services/r2_storage_service.dart';
import '../../models/song.dart';
import '../../models/user_profile.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onSignOut;

  const AdminDashboardScreen({Key? key, required this.onSignOut}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final _backend = CloudBackendService();
  final _lang = LanguageService();
  final _player = AudioPlayer();
  late TabController _tabController;

  String? _currentlyPlayingSongId;
  bool _isPlaying = false;
  String _userSearchQuery = '';
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _backend.addListener(_onUpdate);
    _lang.addListener(_onUpdate);

    // Initial sync with shared storage
    _backend.syncSharedData();

    // Periodic background sync every 4 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _backend.syncSharedData();
      }
    });

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing && state.processingState != ProcessingState.completed;
        });
      }
    });
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _tabController.dispose();
    _backend.removeListener(_onUpdate);
    _lang.removeListener(_onUpdate);
    _player.dispose();
    super.dispose();
  }

  Future<void> _playSongPreview(Song song) async {
    try {
      if (_currentlyPlayingSongId == song.id && _isPlaying) {
        await _player.pause();
        return;
      }

      setState(() => _currentlyPlayingSongId = song.id);

      if (song.streamUrl.startsWith('assets/')) {
        await _player.setAsset(song.streamUrl);
      } else if (song.streamUrl.startsWith('/') || song.streamUrl.startsWith('file://')) {
        await _player.setFilePath(song.streamUrl.replaceFirst('file://', ''));
      } else {
        await _player.setUrl(song.streamUrl);
      }
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio Preview Error: $e')),
      );
    }
  }

  Future<void> _launchCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$clean?text=Hello%20from%20Msixa%20Admin');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchMail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=Msixa%20Player%20Support');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showAddSongDialog() {
    final titleCtrl = TextEditingController();
    final artistCtrl = TextEditingController();
    final albumCtrl = TextEditingController(text: 'Msixa Originals');
    final audioCtrl = TextEditingController();
    final coverCtrl = TextEditingController();
    String selectedGenre = 'Bhakti';
    final genres = ['Bhakti', 'Punjabi', 'Sufi', 'Bollywood', 'Spiritual', 'Desi Lo-Fi', 'Ghazal', 'Indie Pop'];
    bool isUploadingToR2 = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: Row(
            children: [
              const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFFFB300)),
              const SizedBox(width: 8),
              Text(
                _lang.t('add_song_admin'),
                style: GoogleFonts.syne(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAdminTextField(titleCtrl, _lang.t('song_title'), 'उदा. Shree Ram Dhun'),
                const SizedBox(height: 10),
                _buildAdminTextField(artistCtrl, _lang.t('artist_name'), 'उदा. Hariharan'),
                const SizedBox(height: 10),
                _buildAdminTextField(albumCtrl, _lang.t('album_name'), 'Msixa Originals'),
                const SizedBox(height: 10),

                // Cloudflare R2 Upload Button
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00E5FF),
                      side: const BorderSide(color: Color(0xFF00E5FF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: isUploadingToR2
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)))
                        : const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: Text(
                      isUploadingToR2 ? 'R2 क्लाउड पर अपलोड हो रहा है...' : '📁 डिवाइस से MP3 चुनें और R2 पर अपलोड करें',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: isUploadingToR2
                        ? null
                        : () async {
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['mp3', 'm4a', 'wav'],
                              );
                              if (result != null && result.files.single.path != null) {
                                setDialogState(() => isUploadingToR2 = true);
                                final pickedFile = File(result.files.single.path!);
                                final r2 = R2StorageService();
                                final cloudUrl = await r2.uploadAudioFile(pickedFile);
                                setDialogState(() {
                                  isUploadingToR2 = false;
                                  if (cloudUrl != null) {
                                    audioCtrl.text = cloudUrl;
                                    if (titleCtrl.text.isEmpty) {
                                      titleCtrl.text = result.files.single.name
                                          .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                                          .replaceAll('_', ' ');
                                    }
                                  }
                                });
                              }
                            } catch (e) {
                              setDialogState(() => isUploadingToR2 = false);
                            }
                          },
                  ),
                ),
                const SizedBox(height: 6),

                _buildAdminTextField(audioCtrl, 'ऑडियो लिंक या पाथ (Audio Stream URL)', 'https://pub-d4f2... or assets/audio/...'),
                const SizedBox(height: 10),
                _buildAdminTextField(coverCtrl, _lang.t('cover_url'), 'https://.../cover.jpg'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedGenre,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: _lang.t('genre_label'),
                    labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFFB300))),
                  ),
                  items: genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedGenre = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_lang.t('cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300), foregroundColor: Colors.black),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || artistCtrl.text.trim().isEmpty) return;
                await _backend.addAdminSong(
                  title: titleCtrl.text,
                  artist: artistCtrl.text,
                  album: albumCtrl.text,
                  genre: selectedGenre,
                  audioPath: audioCtrl.text.trim().isNotEmpty ? audioCtrl.text.trim() : 'assets/audio/sankat_mochan_hanuman_ashtak.mp3',
                  coverUrl: coverCtrl.text.trim().isNotEmpty ? coverCtrl.text.trim() : null,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('🎉 "${titleCtrl.text}" ${_lang.isHindi ? "सफलतापूर्वक लाइव कर दिया गया!" : "successfully published live!"}')),
                  );
                }
              },
              child: Text(_lang.isHindi ? 'गाना लाइव करें' : 'Publish Live', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSongDialog(Song song) {
    final titleCtrl = TextEditingController(text: song.title);
    final artistCtrl = TextEditingController(text: song.artist);
    final albumCtrl = TextEditingController(text: song.album);
    final audioCtrl = TextEditingController(text: song.streamUrl);
    final coverCtrl = TextEditingController(text: song.coverUrl);
    String selectedGenre = song.genre;
    final genres = ['Bhakti', 'Punjabi', 'Sufi', 'Bollywood', 'Spiritual', 'Desi Lo-Fi', 'Ghazal', 'Indie Pop'];
    if (!genres.contains(selectedGenre)) genres.add(selectedGenre);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_lang.t('edit_btn')}: ${song.title}',
                  style: GoogleFonts.syne(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAdminTextField(titleCtrl, _lang.t('song_title'), ''),
                const SizedBox(height: 10),
                _buildAdminTextField(artistCtrl, _lang.t('artist_name'), ''),
                const SizedBox(height: 10),
                _buildAdminTextField(albumCtrl, _lang.t('album_name'), ''),
                const SizedBox(height: 10),
                _buildAdminTextField(audioCtrl, 'ऑडियो लिंक या पाथ (Audio Stream URL)', ''),
                const SizedBox(height: 10),
                _buildAdminTextField(coverCtrl, _lang.t('cover_url'), ''),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedGenre,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: _lang.t('genre_label'),
                    labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00E5FF))),
                  ),
                  items: genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedGenre = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_lang.t('cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
              onPressed: () async {
                await _backend.editSong(
                  songId: song.id,
                  title: titleCtrl.text,
                  artist: artistCtrl.text,
                  album: albumCtrl.text,
                  genre: selectedGenre,
                  streamUrl: audioCtrl.text,
                  coverUrl: coverCtrl.text,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ "${titleCtrl.text}" ${_lang.t('save_changes')}')),
                  );
                }
              },
              child: Text(_lang.t('save_changes'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminTextField(TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFFB300))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildR2CloudStatusCard() {
    final r2 = R2StorageService();
    final isConnected = r2.isConfigured;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFFFB300).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFFFB300).withOpacity(0.15),
            ),
            child: Icon(
              isConnected ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
              color: isConnected ? const Color(0xFF10B981) : const Color(0xFFFFB300),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Cloudflare R2 Storage',
                      style: GoogleFonts.syne(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isConnected ? const Color(0xFF10B981).withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isConnected ? '🟢 10 GB Free Live' : '⚠️ Setup Required',
                        style: TextStyle(
                          color: isConnected ? Colors.greenAccent : Colors.amberAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected
                      ? 'Bucket: ${r2.bucketName ?? "msixa-music"} • CDN Live Streaming Active'
                      : 'Tap to configure Account ID & API Tokens',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: const Color(0xFF00E5FF),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.3)),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.settings_rounded, size: 14),
            label: const Text('Settings', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: _showR2SettingsDialog,
          ),
        ],
      ),
    );
  }

  void _showR2SettingsDialog() {
    final r2 = R2StorageService();
    final accountIdCtrl = TextEditingController(text: r2.accountId ?? R2StorageService.defaultAccountId);
    final bucketNameCtrl = TextEditingController(text: r2.bucketName ?? R2StorageService.defaultBucketName);
    final accessKeyCtrl = TextEditingController(text: r2.accessKeyId ?? R2StorageService.defaultAccessKeyId);
    final secretKeyCtrl = TextEditingController(text: r2.secretAccessKey ?? R2StorageService.defaultSecretAccessKey);
    final publicDomainCtrl = TextEditingController(text: r2.publicDomain ?? R2StorageService.defaultPublicDomain);

    bool isTesting = false;
    String? testResultMsg;
    bool? testSuccess;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.cloud_circle_rounded, color: Color(0xFF00E5FF), size: 26),
              SizedBox(width: 8),
              Text(
                'Cloudflare R2 Server Settings',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '10 GB Free Storage • 0 Bandwidth Fees • Fast Global Edge Streaming',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 14),
                _buildAdminTextField(accountIdCtrl, 'Account ID', '25622df2e...'),
                const SizedBox(height: 10),
                _buildAdminTextField(bucketNameCtrl, 'Bucket Name', 'msixa-music'),
                const SizedBox(height: 10),
                _buildAdminTextField(accessKeyCtrl, 'Access Key ID', '3857da306...'),
                const SizedBox(height: 10),
                _buildAdminTextField(secretKeyCtrl, 'Secret Access Key', '77ef640b7...'),
                const SizedBox(height: 10),
                _buildAdminTextField(publicDomainCtrl, 'Public CDN Domain / r2.dev', 'pub-xxxx.r2.dev'),
                const SizedBox(height: 14),

                if (isTesting)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: const [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF))),
                        SizedBox(width: 10),
                        Text('Testing connection to Cloudflare R2...', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                      ],
                    ),
                  ),

                if (testResultMsg != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: testSuccess == true ? const Color(0xFF10B981).withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: testSuccess == true ? Colors.greenAccent : Colors.redAccent),
                    ),
                    child: Text(
                      testResultMsg!,
                      style: TextStyle(
                        color: testSuccess == true ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF)),
              ),
              onPressed: isTesting
                  ? null
                  : () async {
                      setDialogState(() {
                        isTesting = true;
                        testResultMsg = null;
                      });
                      await r2.saveConfig(
                        accountId: accountIdCtrl.text,
                        bucketName: bucketNameCtrl.text,
                        accessKeyId: accessKeyCtrl.text,
                        secretAccessKey: secretKeyCtrl.text,
                        publicDomain: publicDomainCtrl.text,
                      );
                      final res = await r2.testConnection();
                      setDialogState(() {
                        isTesting = false;
                        testSuccess = res['success'] == true;
                        testResultMsg = res['message']?.toString();
                      });
                      if (mounted) setState(() {});
                    },
              child: const Text('⚡ Test Connection', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300), foregroundColor: Colors.black),
              onPressed: () async {
                await r2.saveConfig(
                  accountId: accountIdCtrl.text,
                  bucketName: bucketNameCtrl.text,
                  accessKeyId: accessKeyCtrl.text,
                  secretAccessKey: secretKeyCtrl.text,
                  publicDomain: publicDomainCtrl.text,
                );
                if (mounted) {
                  setState(() {});
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Cloudflare R2 Credentials Saved & Synced!')),
                  );
                }
              },
              child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _backend.pendingSongs;
    final approved = _backend.approvedSongs;
    final users = _backend.allUsers;

    final filteredUsers = users.where((u) {
      final q = _userSearchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return u.fullName.toLowerCase().contains(q) ||
          u.phoneNumber.contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101726),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF6F00)]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _lang.t('admin_title'),
                style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Language Switcher Toggle Button
          InkWell(
            onTap: () => _lang.toggleLanguage(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, color: Color(0xFFFFB300), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _lang.displayLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: _lang.t('refresh_data'),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFFB300), size: 22),
            onPressed: () async {
              await _backend.syncSharedData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${_lang.t('data_refreshed')} (${_backend.allUsers.length} Users)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    backgroundColor: const Color(0xFFFFB300),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: _lang.t('sign_out'),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            onPressed: widget.onSignOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFB300),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFFB300),
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: '${_lang.t('tab_pending')} (${pending.length})'),
            Tab(text: '${_lang.t('tab_users')} (${users.length})'),
            Tab(text: '${_lang.t('tab_live')} (${approved.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Live Analytics Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF121B2D),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCard(
                  title: _lang.t('metric_total_users'),
                  value: '${_backend.totalUsersCount}',
                  icon: Icons.people_alt_rounded,
                  color: Colors.cyanAccent,
                ),
                _buildMetricCard(
                  title: _lang.t('metric_active_users'),
                  value: '${_backend.activeUsersCount}',
                  icon: Icons.wifi_tethering_rounded,
                  color: Colors.greenAccent,
                ),
                _buildMetricCard(
                  title: _lang.t('metric_pending'),
                  value: '${pending.length}',
                  icon: Icons.pending_actions_rounded,
                  color: Colors.amberAccent,
                ),
                _buildMetricCard(
                  title: _lang.t('metric_live'),
                  value: '${approved.length}',
                  icon: Icons.library_music_rounded,
                  color: Colors.indigoAccent,
                ),
              ],
            ),
          ),

          // Cloudflare R2 Cloud Server Status & Control Pill
          _buildR2CloudStatusCard(),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Pending Songs Moderation
                _buildPendingSongsTab(pending),

                // TAB 2: Users Directory
                _buildUsersDirectoryTab(filteredUsers),

                // TAB 3: Live Songs Catalog (with Add, Edit, Delete)
                _buildLiveSongsTab(approved),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
      ],
    );
  }

  // TAB 1: Song Moderation
  Widget _buildPendingSongsTab(List<Song> pending) {
    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent.withOpacity(0.5), size: 54),
            const SizedBox(height: 12),
            Text(_lang.t('no_pending_songs'), style: GoogleFonts.syne(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_lang.t('all_songs_approved'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final song = pending[index];
        final isThisPlaying = _currentlyPlayingSongId == song.id && _isPlaying;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isThisPlaying ? const Color(0xFFFFB300) : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      song.coverUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.music_note, color: Colors.white30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${song.artist} • ${song.genre}',
                          style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.account_circle_outlined, size: 12, color: Colors.cyanAccent),
                            const SizedBox(width: 4),
                            Text(
                              '${song.uploaderName ?? "User"} (${song.uploaderPhone ?? ""})',
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF00E5FF), size: 22),
                    tooltip: _lang.t('edit_btn'),
                    onPressed: () => _showEditSongDialog(song),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 10),

              // Action Buttons
              Row(
                children: [
                  // Play / Pause Preview Button
                  ElevatedButton.icon(
                    onPressed: () => _playSongPreview(song),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isThisPlaying ? const Color(0xFFFFB300) : const Color(0xFF1E293B),
                      foregroundColor: isThisPlaying ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      isThisPlaying ? _lang.t('preview_stop') : _lang.t('preview_play'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),

                  // Reject Button
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF131A2A),
                          title: Text(_lang.t('confirm_delete_title'), style: const TextStyle(color: Colors.white)),
                          content: Text('${_lang.t('confirm_delete_msg')} ("${song.title}")', style: const TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_lang.t('cancel'))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(_lang.t('confirm_yes')),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _backend.rejectOrDeleteSong(song.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"${song.title}" removed.')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                    label: Text(_lang.t('reject_btn'), style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),

                  // Approve Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _backend.approveSong(song.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('🎉 "${song.title}" live!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(_lang.t('approve_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 2: Users Directory
  Widget _buildUsersDirectoryTab(List<UserProfile> users) {
    return Column(
      children: [
        // Search Box
        Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131B2C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _userSearchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: _lang.t('search_users'),
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFFB300), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Users List
        Expanded(
          child: users.isEmpty
              ? Center(child: Text(_lang.t('no_users_found'), style: const TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final u = users[index];
                    final isOnline = DateTime.now().difference(u.lastActiveAt).inMinutes < 60;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2C),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: u.role == 'admin' ? const Color(0xFFFFB300) : const Color(0xFF4F46E5),
                                child: Text(
                                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: isOnline ? Colors.greenAccent : Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // User Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        u.fullName,
                                        style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (u.role == 'admin')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB300).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('ADMIN', style: TextStyle(color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_rounded, size: 11, color: Colors.greenAccent),
                                    const SizedBox(width: 3),
                                    Text(
                                      u.phoneNumber.isNotEmpty ? u.phoneNumber : 'No phone',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified_rounded, size: 12, color: Colors.cyanAccent),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.mail_outline_rounded, size: 11, color: Colors.cyanAccent),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        u.email,
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Quick Action Buttons
                          if (u.phoneNumber.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.phone_outlined, color: Colors.greenAccent, size: 18),
                              onPressed: () => _launchCall(u.phoneNumber),
                              tooltip: _lang.t('call_tooltip'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.tealAccent, size: 18),
                              onPressed: () => _launchWhatsApp(u.phoneNumber),
                              tooltip: _lang.t('whatsapp_tooltip'),
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.mail_outline_rounded, color: Colors.cyanAccent, size: 18),
                            onPressed: () => _launchMail(u.email),
                            tooltip: _lang.t('email_tooltip'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 3: All Live Songs (with Add, Edit, and Delete)
  Widget _buildLiveSongsTab(List<Song> songs) {
    return Column(
      children: [
        // Add Song Header Button Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF0F1728),
          child: Row(
            children: [
              Text(
                '${_lang.t('tab_live')} (${songs.length})',
                style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  _lang.t('add_song_admin'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _showAddSongDialog,
              ),
            ],
          ),
        ),

        Expanded(
          child: songs.isEmpty
              ? Center(child: Text(_lang.t('no_pending_songs'), style: const TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: songs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final s = songs[index];
                    final isThisPlaying = _currentlyPlayingSongId == s.id && _isPlaying;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isThisPlaying ? const Color(0xFFFFB300) : Colors.white10,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              s.coverUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: Colors.grey.shade800),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                                Text('${s.artist} • ${s.genre}', style: const TextStyle(color: Colors.white60, fontSize: 11), maxLines: 1),
                              ],
                            ),
                          ),
                          // Preview Button
                          IconButton(
                            icon: Icon(
                              isThisPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              color: isThisPlaying ? const Color(0xFFFFB300) : Colors.white70,
                              size: 26,
                            ),
                            tooltip: _lang.t('preview_play'),
                            onPressed: () => _playSongPreview(s),
                          ),
                          // Edit Button
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF00E5FF), size: 22),
                            tooltip: _lang.t('edit_btn'),
                            onPressed: () => _showEditSongDialog(s),
                          ),
                          // Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                            tooltip: _lang.t('delete_btn'),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF131A2A),
                                  title: Text(_lang.t('confirm_delete_title'), style: const TextStyle(color: Colors.white)),
                                  content: Text('${_lang.t('confirm_delete_msg')} ("${s.title}")', style: const TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_lang.t('cancel'))),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(_lang.t('confirm_yes')),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await _backend.rejectOrDeleteSong(s.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('"${s.title}" removed.')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
