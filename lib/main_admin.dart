import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/cloud_backend_service.dart';
import 'screens/admin/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = CloudBackendService();
  await backend.init();

  runApp(const MsixaAdminApp());
}

class MsixaAdminApp extends StatelessWidget {
  const MsixaAdminApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Msixa Admin Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        primaryColor: const Color(0xFFFFB300),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB300),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF101726),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const AdminRootView(),
    );
  }
}

class AdminRootView extends StatefulWidget {
  const AdminRootView({Key? key}) : super(key: key);

  @override
  State<AdminRootView> createState() => _AdminRootViewState();
}

class _AdminRootViewState extends State<AdminRootView> {
  final _backend = CloudBackendService();
  final _pinCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginAdmin() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'कृपया एडमिन मास्टर पिन दर्ज करें');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final ok = await _backend.authenticateAdmin(pin);

    setState(() {
      _isLoading = false;
      if (!ok) {
        _error = 'गलत एडमिन पिन (Incorrect Admin PIN)';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_backend.isAdmin) {
      return AdminDashboardScreen(
        onSignOut: () async {
          await _backend.signOut();
          setState(() {});
        },
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Admin Crown Badge
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withOpacity(0.35),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.black, size: 40),
              ),
              const SizedBox(height: 20),

              Text(
                'Msixa Admin Control',
                style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'सुरक्षित एडमिनिस्ट्रेटर कंसोल (Executive Access Only)',
                style: TextStyle(color: Colors.amberAccent.shade100, fontSize: 12),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF101726),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                    ],

                    Text(
                      'एडमिन मास्टर पिन (Master PIN)',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.Border.all(color: Colors.white10),
                      ),
                      child: TextField(
                        controller: _pinCtrl,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 6),
                        decoration: const InputDecoration(
                          hintText: '••••',
                          hintStyle: TextStyle(color: Colors.grey, letterSpacing: 4),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _loginAdmin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : Text('एडमिन कंसोल में प्रवेश करें (Login)', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                'डिफ़ॉल्ट मास्टर पिन: 7777',
                style: TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
