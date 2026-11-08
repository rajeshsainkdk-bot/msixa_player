import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Auto-Updater Service
/// Features:
/// - Checks live update manifest on Cloudflare R2 CDN (update/version.json)
/// - Background download with live progress indicator (0 - 100%)
/// - Launches native Android package installer automatically via FileProvider
/// - Supports both user-initiated check & silent app-startup auto-prompt
class UpdateService {
  static const String manifestUrl = 'https://pub-d4f2e58dc2594d0c8dc1f30bbae4344f.r2.dev/update/version.json';
  static const MethodChannel _channel = MethodChannel('com.msixa.player/app_share');
  static const String _prefKeyLastChecked = 'msixa_last_update_check';

  // Base build version code of the installed application
  static const int currentVersionCode = 2;
  static const String currentVersionName = '1.0.2';

  /// Check for latest update from Cloudflare R2
  static Future<void> checkForUpdate(BuildContext context, {bool autoPrompt = false}) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$manifestUrl?t=$ts');
      final resp = await http.get(
        uri,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) {
        if (!autoPrompt && context.mounted) {
          _showToast(context, 'अपडेट सर्वर से कनेक्ट नहीं हो सका (HTTP ${resp.statusCode})');
        }
        return;
      }

      final Map<String, dynamic> data = jsonDecode(utf8.decode(resp.bodyBytes));
      final remoteCode = data['version_code'] as int? ?? 1;
      final remoteName = data['version_name'] as String? ?? '1.0.0';
      final apkUrl = data['apk_url'] as String? ?? '';
      final sizeMb = (data['file_size_mb'] as num?)?.toDouble() ?? 23.0;
      final releaseNotes = data['release_notes'] as String? ?? 'नए फीचर्स और बग फिक्स!';
      final forceUpdate = data['force_update'] as bool? ?? false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKeyLastChecked, ts);

      if (remoteCode > currentVersionCode && apkUrl.isNotEmpty) {
        if (context.mounted) {
          _showUpdateDialog(
            context,
            remoteName: remoteName,
            sizeMb: sizeMb,
            releaseNotes: releaseNotes,
            apkUrl: apkUrl,
            forceUpdate: forceUpdate,
          );
        }
      } else {
        if (!autoPrompt && context.mounted) {
          _showToast(context, '🎉 आप पहले से नवीनतम वर्ज़न (v$currentVersionName) पर हैं!');
        }
      }
    } catch (e) {
      if (!autoPrompt && context.mounted) {
        _showToast(context, 'अपडेट चेक करने में त्रुटि: $e');
      }
    }
  }

  static void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF101726),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String remoteName,
    required double sizeMb,
    required String releaseNotes,
    required String apkUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) {
        double downloadProgress = 0.0;
        bool isDownloading = false;
        String statusText = '';
        int downloadedBytes = 0;
        int totalBytes = (sizeMb * 1024 * 1024).toInt();

        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return WillPopScope(
              onWillPop: () async => !forceUpdate && !isDownloading,
              child: AlertDialog(
                backgroundColor: const Color(0xFF131B2C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.system_update_rounded, color: Color(0xFFFFB300), size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'नया अपडेट उपलब्ध है!',
                            style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'v$remoteName • ${sizeMb.toStringAsFixed(1)} MB',
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '✨ क्या नया है (What\'s New):',
                            style: TextStyle(color: Color(0xFFFFB300), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            releaseNotes,
                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isDownloading) ...[
                      LinearProgressIndicator(
                        value: totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : null,
                        backgroundColor: Colors.white10,
                        color: const Color(0xFF00E5FF),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            statusText,
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(downloadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'यह अपडेट 1-क्लिक में बिना प्ले स्टोर के सीधे आपके फोन में इंस्टॉल हो जाएगा।',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (!isDownloading && !forceUpdate)
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('बाद में (Later)', style: TextStyle(color: Colors.grey)),
                    ),
                  if (!isDownloading)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text(
                        'तुरंत अपडेट करें (Update Now)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () async {
                        setState(() {
                          isDownloading = true;
                          statusText = 'डाउनलोड शुरू हो रहा है...';
                        });

                        try {
                          final client = http.Client();
                          final request = http.Request('GET', Uri.parse(apkUrl));
                          final response = await client.send(request);

                          if (response.statusCode != 200) {
                            throw 'Download failed with status ${response.statusCode}';
                          }

                          totalBytes = response.contentLength ?? (sizeMb * 1024 * 1024).toInt();
                          downloadedBytes = 0;

                          final tempDir = Directory.systemTemp;
                          final apkFile = File('${tempDir.path}/msixa_player_latest.apk');
                          if (await apkFile.exists()) {
                            await apkFile.delete();
                          }

                          final sink = apkFile.openWrite();

                          await response.stream.listen((chunk) {
                            sink.add(chunk);
                            downloadedBytes += chunk.length;
                            setState(() {
                              downloadProgress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.5;
                              final mbDown = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
                              final mbTot = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
                              statusText = 'डाउनलोड हो रहा है: $mbDown / $mbTot MB';
                            });
                          }).asFuture();

                          await sink.flush();
                          await sink.close();

                          setState(() {
                            statusText = 'इंस्टॉलर शुरू हो रहा है...';
                            downloadProgress = 1.0;
                          });

                          // Launch Native APK Installer
                          await _channel.invokeMethod('installApk', {'filePath': apkFile.path});

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (err) {
                          setState(() {
                            isDownloading = false;
                            statusText = 'डाउनलोड त्रुटि: $err';
                          });
                        }
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
