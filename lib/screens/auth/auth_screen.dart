import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/cloud_backend_service.dart';
import '../../services/language_service.dart';
import '../../providers/player_provider.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({Key? key, required this.onAuthenticated}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _backend = CloudBackendService();
  final _lang = LanguageService();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _lang.addListener(_onLangUpdate);
  }

  void _onLangUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lang.removeListener(_onLangUpdate);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegisterOrLogin() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    // 1. Mandatory Name Validation (>= 2 characters)
    if (name.isEmpty || name.length < 2) {
      setState(() => _errorMessage = _lang.t('err_name_required'));
      return;
    }

    // 2. Mandatory Mobile Number Validation (Strictly 10 digits)
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = digitsOnly.length >= 10 ? digitsOnly.substring(digitsOnly.length - 10) : digitsOnly;
    if (last10.length != 10) {
      setState(() => _errorMessage = _lang.t('err_phone_required'));
      return;
    }

    // 3. Mandatory Email ID Validation (RFC compliant standard regex)
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = _lang.t('err_email_required'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if user already exists before registration to tailor welcome message
      final existingIndex = _backend.allUsers.indexWhere((u) {
        final uDigits = u.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        return uDigits.endsWith(last10);
      });
      final isExisting = existingIndex != -1;

      final user = await _backend.registerOrLogin(
        fullName: name,
        phoneNumber: last10,
        email: email,
      );

      if (mounted) {
        // Automatically restore and reload user playlists, favorites & history
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        await playerProvider.reloadUserData(user.phoneNumber);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isExisting ? _lang.t('welcome_back') : _lang.t('welcome_new'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: isExisting ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        widget.onAuthenticated();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Stack(
          children: [
            // Top Right: Language Switcher Button
            Positioned(
              top: 14,
              right: 18,
              child: InkWell(
                onTap: () => _lang.toggleLanguage(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A2A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_rounded, size: 15, color: Color(0xFF00E5FF)),
                      const SizedBox(width: 6),
                      Text(
                        _lang.displayLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo / Shield
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // App Title
                    Text(
                      _lang.t('auth_title'),
                      style: GoogleFonts.syne(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _lang.t('auth_subtitle'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.cyanAccent.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Account Recovery & Auto-Sync Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sync_rounded, color: Color(0xFF00E5FF), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _lang.t('account_recovery_banner'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Form Container with 3 Mandatory Fields
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 1. Mandatory Full Name Field
                          _buildInputField(
                            controller: _nameCtrl,
                            label: _lang.t('full_name'),
                            hint: _lang.t('full_name_hint'),
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(height: 14),

                          // 2. Mandatory 10-Digit Mobile Number Field
                          _buildInputField(
                            controller: _phoneCtrl,
                            label: _lang.t('phone_number'),
                            hint: _lang.t('phone_number_hint'),
                            icon: Icons.phone_android_rounded,
                            keyboardType: TextInputType.phone,
                            prefixText: '+91 ',
                          ),
                          const SizedBox(height: 14),

                          // 3. Mandatory Email Address Field
                          _buildInputField(
                            controller: _emailCtrl,
                            label: _lang.t('email_mandatory'),
                            hint: _lang.t('email_hint'),
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 22),

                          // Submit Button: Instant Direct Sign-up / Login
                          _buildSubmitButton(
                            title: _lang.t('start_listening'),
                            icon: Icons.headphones_rounded,
                            onPressed: _isLoading ? null : _handleRegisterOrLogin,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      _lang.t('auth_tagline'),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade300,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B101D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textAlign: textAlign,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              prefixIcon: Icon(icon, color: const Color(0xFF00E5FF), size: 20),
              prefixText: prefixText,
              prefixStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton({
    required String title,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 18),
              ],
            ),
    );
  }
}
