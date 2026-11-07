import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/cloud_backend_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({Key? key, required this.onAuthenticated}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _backend = CloudBackendService();
  int _step = 1; // 1: Info, 2: Phone OTP, 3: Email Code

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _emailCodeCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _hintCode;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _emailCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty || name.length < 2) {
      setState(() => _errorMessage = 'कृपया अपना पूरा नाम दर्ज करें (Enter full name)');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'कृपया सही ईमेल पता दर्ज करें (Enter valid email)');
      return;
    }
    if (phone.length < 10) {
      setState(() => _errorMessage = 'कृपया 10 अंकों का मोबाइल नंबर दर्ज करें (Enter 10-digit mobile number)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final formattedPhone = phone.startsWith('+91') ? phone : '+91 $phone';
    final success = await _backend.sendPhoneOtp(
      fullName: name,
      email: email,
      phoneNumber: formattedPhone,
    );

    setState(() {
      _isLoading = false;
      if (success) {
        _step = 2;
        _hintCode = 'सुरक्षा कोड (SMS OTP sent)';
      } else {
        _errorMessage = 'OTP भेजने में समस्या हुई। कृपया दोबारा प्रयास करें।';
      }
    });
  }

  Future<void> _handleVerifyPhoneOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      setState(() => _errorMessage = 'कृपया 6 अंकों का SMS OTP दर्ज करें');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final verified = await _backend.verifyPhoneOtp(otp);

    setState(() {
      _isLoading = false;
      if (verified) {
        _step = 3;
        _hintCode = 'ईमेल कोड (Email code sent to ${_emailCtrl.text})';
      } else {
        _errorMessage = 'अमान्य OTP कोड। कृपया सही कोड दर्ज करें।';
      }
    });
  }

  Future<void> _handleVerifyEmailCode() async {
    final code = _emailCodeCtrl.text.trim();
    if (code.length < 4) {
      setState(() => _errorMessage = 'कृपया 4 अंकों का ईमेल वेरिफिकेशन कोड दर्ज करें');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = await _backend.completeVerification(code);

    setState(() => _isLoading = false);

    if (user != null) {
      widget.onAuthenticated();
    } else {
      setState(() => _errorMessage = 'अमान्य ईमेल कोड। कृपया दोबारा जाँचें।');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Center(
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
                  'Msixa Player',
                  style: GoogleFonts.syne(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'सुरक्षित श्रोता पंजीकरण (Verified Registration)',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.cyanAccent.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),

                // Stepper Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepDot(1, 'विवरण (Info)'),
                    _buildStepLine(1),
                    _buildStepDot(2, 'मोबाइल OTP'),
                    _buildStepLine(2),
                    _buildStepDot(3, 'ईमेल कोड'),
                  ],
                ),
                const SizedBox(height: 28),

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
                          label: 'पूरा नाम (Full Name)',
                          hint: 'उदा. Rajesh Kumar',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: _emailCtrl,
                          label: 'ईमेल आईडी (Email Address)',
                          hint: 'name@example.com',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: _phoneCtrl,
                          label: 'मोबाइल नंबर (10-Digit Mobile)',
                          hint: '9876543210',
                          icon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                          prefixText: '+91 ',
                        ),
                        const SizedBox(height: 22),
                        _buildSubmitButton(
                          title: 'SMS OTP प्राप्त करें (Send OTP)',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: _isLoading ? null : _handleSendOtp,
                        ),
                      ],

                      // STEP 2: Phone SMS OTP
                      if (_step == 2) ...[
                        Text(
                          'मोबाइल नंबर पर 6 अंकों का SMS भेजा गया है:',
                          style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _phoneCtrl.text,
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildInputField(
                          controller: _otpCtrl,
                          label: '6-अंकीय SMS OTP दर्ज करें',
                          hint: '123456',
                          icon: Icons.lock_outline_rounded,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        _buildSubmitButton(
                          title: 'मोबाइल नंबर सत्यापित करें (Verify Phone)',
                          icon: Icons.check_circle_outline_rounded,
                          onPressed: _isLoading ? null : _handleVerifyPhoneOtp,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => _step = 1),
                          child: const Text('नंबर बदलें (Change Phone Number)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                      ],

                      // STEP 3: Email Verification Code
                      if (_step == 3) ...[
                        Text(
                          'आपके ईमेल पर 4 अंकों का वेरिफिकेशन कोड भेजा गया है:',
                          style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _emailCtrl.text,
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildInputField(
                          controller: _emailCodeCtrl,
                          label: '4-अंकीय ईमेल कोड दर्ज करें',
                          hint: '1234',
                          icon: Icons.mark_email_read_outlined,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        _buildSubmitButton(
                          title: 'ईमेल सत्यापित करें व शुरू करें (Complete)',
                          icon: Icons.login_rounded,
                          onPressed: _isLoading ? null : _handleVerifyEmailCode,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => _step = 2),
                          child: const Text('पीछे जाएँ (Back)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  '100% मुफ़्त एवं सुरक्षित • कोई पासवर्ड याद रखने की ज़रूरत नहीं',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
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
      width: 36,
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

