import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/cloud_backend_service.dart';
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
  final _player = AudioPlayer();
  late TabController _tabController;

  String? _currentlyPlayingSongId;
  bool _isPlaying = false;
  String _userSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _backend.addListener(_onBackendUpdate);

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing && state.processingState != ProcessingState.completed;
        });
      }
    });
  }

  void _onBackendUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _backend.removeListener(_onBackendUpdate);
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
        SnackBar(content: Text('ऑडियो पूर्वावलोकन चलाने में समस्या: $e')),
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
            const SizedBox(width: 10),
            Text(
              'Msixa Admin Control',
              style: GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
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
            Tab(text: 'लंबित गाने (${pending.length})'),
            Tab(text: 'यूज़र्स डेटा (${users.length})'),
            Tab(text: 'लाइव गाने (${approved.length})'),
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
                  title: 'कुल यूज़र्स',
                  value: '${_backend.totalUsersCount}',
                  icon: Icons.people_alt_rounded,
                  color: Colors.cyanAccent,
                ),
                _buildMetricCard(
                  title: 'सक्रिय (Active)',
                  value: '${_backend.activeUsersCount}',
                  icon: Icons.wifi_tethering_rounded,
                  color: Colors.greenAccent,
                ),
                _buildMetricCard(
                  title: 'लंबित अप्रूवल',
                  value: '${pending.length}',
                  icon: Icons.pending_actions_rounded,
                  color: Colors.amberAccent,
                ),
                _buildMetricCard(
                  title: 'लाइव गाने',
                  value: '${approved.length}',
                  icon: Icons.library_music_rounded,
                  color: Colors.indigoAccent,
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Pending Songs Moderation
                _buildPendingSongsTab(pending),

                // TAB 2: Users Directory
                _buildUsersDirectoryTab(filteredUsers),

                // TAB 3: Live Songs Catalog
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
            Text('कोई लंबित गाना नहीं है!', style: GoogleFonts.syne(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('सभी गाने अप्रूव हो चुके हैं।', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
            border: Border.Border.all(
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
                          'गायक: ${song.artist} • ${song.genre}',
                          style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.account_circle_outlined, size: 12, color: Colors.cyanAccent),
                            const SizedBox(width: 4),
                            Text(
                              'अपलोडर: ${song.uploaderName ?? "Unknown"} (${song.uploaderPhone ?? ""})',
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                      isThisPlaying ? 'रुकें (Playing)' : 'सुनें (Preview)',
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
                          title: const Text('गाना रिजेक्ट करें?', style: TextStyle(color: Colors.white)),
                          content: Text('क्या आप "${song.title}" को हटाना चाहते हैं?', style: const TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('हाँ, हटाएँ'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _backend.rejectOrDeleteSong(song.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('गाना हटा दिया गया।')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                    label: const Text('हटाएँ (Reject)', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),

                  // Approve Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _backend.approveSong(song.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('🎉 "${song.title}" को सभी के लिए लाइव कर दिया गया!')),
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
                    label: const Text('स्वीकार करें (Approve)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
              border: Border.Border.all(color: Colors.white10),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _userSearchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'यूज़र का नाम, फ़ोन या ईमेल खोजें...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                prefixIcon: Icon(Icons.search_rounded, color: Color(0xFFFFB300), size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Users List
        Expanded(
          child: users.isEmpty
              ? const Center(child: Text('कोई यूज़र नहीं मिला', style: TextStyle(color: Colors.grey)))
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
                        border: Border.Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          // Avatar with Online dot
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
                                    border: Border.Border.all(color: Colors.black, width: 2),
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

                          // Quick Action Buttons (Call, WhatsApp, Email)
                          if (u.phoneNumber.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.phone_outlined, color: Colors.greenAccent, size: 18),
                              onPressed: () => _launchCall(u.phoneNumber),
                              tooltip: 'कॉल करें',
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.tealAccent, size: 18),
                              onPressed: () => _launchWhatsApp(u.phoneNumber),
                              tooltip: 'WhatsApp मैसेज',
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.mail_outline_rounded, color: Colors.cyanAccent, size: 18),
                            onPressed: () => _launchMail(u.email),
                            tooltip: 'ईमेल भेजें',
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

  // TAB 3: All Live Songs
  Widget _buildLiveSongsTab(List<Song> songs) {
    if (songs.isEmpty) {
      return const Center(child: Text('कोई लाइव गाना नहीं है', style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: songs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = songs[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2C),
            borderRadius: BorderRadius.circular(12),
            border: Border.Border.all(color: Colors.white10),
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
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                onPressed: () async {
                  await _backend.rejectOrDeleteSong(s.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${s.title}" को हटा दिया गया।')),
                    );
                  }
                },
                tooltip: 'गाना हटाएँ',
              ),
            ],
          ),
        );
      },
    );
  }
}
