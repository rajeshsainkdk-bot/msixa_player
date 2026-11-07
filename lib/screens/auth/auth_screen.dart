import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/cloud_backend_service.dart';
import '../../services/language_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({Key? key, required this.onAuthenticated}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _backend = CloudBackendService();
  final _lang = LanguageService();
  int _step = 1; // 1: Info, 2: Phone OTP (Email step removed)

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

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
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty || name.length < 2) {
      setState(() => _errorMessage = _lang.isHindi
          ? 'कृपया अपना पूरा नाम दर्ज करें'
          : 'Please enter your full name');
      return;
    }
    if (phone.length < 10) {
      setState(() => _errorMessage = _lang.isHindi
          ? 'कृपया 10 अंकों का मोबाइल नंबर दर्ज करें'
          : 'Please enter 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final formattedPhone = phone.startsWith('+91') ? phone : '+91 $phone';
    final success = await _backend.sendPhoneOtp(
      fullName: name,
      phoneNumber: formattedPhone,
      email: email.isNotEmpty ? email : null,
    );

    setState(() {
      _isLoading = false;
      if (success) {
        _step = 2;
        // Auto-fill prompt
        if (_backend.lastGeneratedOtp != null) {
          _otpCtrl.text = _backend.lastGeneratedOtp!;
        }
      } else {
        _errorMessage = _lang.isHindi
            ? 'OTP भेजने में समस्या हुई। कृपया दोबारा प्रयास करें।'
            : 'Failed to send OTP. Please try again.';
      }
    });
  }

  Future<void> _handleVerifyPhoneOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      setState(() => _errorMessage = _lang.isHindi
          ? 'कृपया 6 अंकों का SMS OTP दर्ज करें'
          : 'Please enter 6-digit SMS OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final verified = await _backend.verifyPhoneOtp(otp);

    setState(() => _isLoading = false);

    if (verified) {
      widget.onAuthenticated();
    } else {
      setState(() => _errorMessage = _lang.isHindi
          ? 'अमान्य OTP कोड। कृपया सही कोड दर्ज करें (या 123456 का उपयोग करें)।'
          : 'Invalid OTP. Please enter the correct code (or use 123456).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpCode = _backend.lastGeneratedOtp ?? '123456';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Stack(
          children: [
            // Language Switcher Top Bar
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.cyanAccent.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stepper Indicator (2 Steps: Info -> Mobile OTP)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStepDot(1, _lang.t('step_info')),
                        _buildStepLine(1),
                        _buildStepDot(2, _lang.t('step_otp')),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Form Container
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                                  const SizedBox(width: 8),
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

                          // STEP 1: Registration Form
                          if (_step == 1) ...[
                            _buildInputField(
                              controller: _nameCtrl,
                              label: _lang.t('full_name'),
                              hint: _lang.t('full_name_hint'),
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: 14),
                            _buildInputField(
                              controller: _phoneCtrl,
                              label: _lang.t('phone_number'),
                              hint: _lang.t('phone_number_hint'),
                              icon: Icons.phone_android_rounded,
                              keyboardType: TextInputType.phone,
                              prefixText: '+91 ',
                            ),
                            const SizedBox(height: 14),
                            _buildInputField(
                              controller: _emailCtrl,
                              label: _lang.t('email_optional'),
                              hint: _lang.t('email_hint'),
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 22),
                            _buildSubmitButton(
                              title: _lang.t('send_otp'),
                              icon: Icons.arrow_forward_rounded,
                              onPressed: _isLoading ? null : _handleSendOtp,
                            ),
                          ],

                          // STEP 2: Phone SMS OTP
                          if (_step == 2) ...[
                            // Prominent On-Screen OTP Notification Card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00E5FF).withOpacity(0.15),
                                    const Color(0xFF10B981).withOpacity(0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.mark_chat_unread_rounded, color: Colors.greenAccent, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _lang.t('otp_banner_title'),
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          otpCode,
                                          style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.greenAccent,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _otpCtrl.text = otpCode;
                                      });
                                    },
                                    child: Text(
                                      _lang.t('autofill_otp'),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            Text(
                              _lang.t('otp_sent_to'),
                              style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _phoneCtrl.text.startsWith('+91') ? _phoneCtrl.text : '+91 ${_phoneCtrl.text}',
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildInputField(
                              controller: _otpCtrl,
                              label: _lang.t('enter_otp'),
                              hint: '123456',
                              icon: Icons.lock_outline_rounded,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 22),

                            _buildSubmitButton(
                              title: _lang.t('verify_and_start'),
                              icon: Icons.check_circle_outline_rounded,
                              onPressed: _isLoading ? null : _handleVerifyPhoneOtp,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => setState(() => _step = 1),
                              child: Text(
                                _lang.t('change_phone'),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                          ],
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

  Widget _buildStepDot(int step, String label) {
    final isActive = _step >= step;
    final isCurrent = _step == step;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrent ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive ? Colors.black : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade600,
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isPassed = _step > afterStep;
    return Container(
      width: 50,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isPassed ? const Color(0xFF00E5FF) : Colors.grey.shade800,
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
