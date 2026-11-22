import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/storage_service.dart';
import '../services/cloud_backend_service.dart';

class MandatoryFeedbackDialog extends StatefulWidget {
  const MandatoryFeedbackDialog({Key? key}) : super(key: key);

  @override
  State<MandatoryFeedbackDialog> createState() => _MandatoryFeedbackDialogState();
}

class _MandatoryFeedbackDialogState extends State<MandatoryFeedbackDialog> {
  int _selectedRating = 0;
  final TextEditingController _msgController = TextEditingController();
  bool _isSubmitting = false;
  String? _validationError;

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return '😞 सुधार की सख्त जरूरत (Needs Improvement)';
      case 2:
        return '😐 साधारण (Fair)';
      case 3:
        return '🙂 ठीक है (Good)';
      case 4:
        return '😊 बहुत बढ़िया (Very Good)';
      case 5:
        return '🌟 उत्कृष्ट (Excellent - 5 Stars!)';
      default:
        return 'रेटिंग देने के लिए स्टार दबाएं (Tap Stars to Rate)';
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedRating == 0) {
      setState(() => _validationError = 'कृपया पहले 1 से 5 स्टार में से रेटिंग चुनें।');
      return;
    }

    if (_selectedRating < 5) {
      final text = _msgController.text.trim();
      if (text.length < 5) {
        setState(() => _validationError = 'कृपया बताएं कि क्या सुधार करने की जरूरत है (कम से कम 5 अक्षर)।');
        return;
      }
    }

    setState(() {
      _validationError = null;
      _isSubmitting = true;
    });

    try {
      final storage = StorageService();
      final backend = CloudBackendService();

      await storage.setFeedbackSubmitted(
        true,
        rating: _selectedRating,
        message: _msgController.text.trim(),
      );

      await backend.submitFeedback(
        rating: _selectedRating,
        message: _msgController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'धन्यवाद! आपका बहुमूल्य फ़ीडबैक दर्ज कर लिया गया है।',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFFB300).withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB300).withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 20,
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Star Header Badge
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB300), Color(0xFFFF6D00)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB300).withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.black,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                const Text(
                  'आपका अनुभव कैसा रहा?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Msixa Player पर 5 गाने पूरे होने पर कृपया अपनी रेटिंग साझा करें। आपका फ़ीडबैक हमारे लिए अनिवार्य व महत्वपूर्ण है।',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // 5 Interactive Rating Stars
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starNum = index + 1;
                          final isFilled = starNum <= _selectedRating;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRating = starNum;
                                _validationError = null;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: AnimatedScale(
                                scale: isFilled ? 1.15 : 1.0,
                                duration: const Duration(milliseconds: 150),
                                child: Icon(
                                  isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: isFilled ? const Color(0xFFFFB300) : Colors.white38,
                                  size: 38,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getRatingLabel(_selectedRating),
                        style: TextStyle(
                          color: _selectedRating == 5
                              ? const Color(0xFF10B981)
                              : (_selectedRating > 0 ? const Color(0xFFFFB300) : Colors.white54),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Dynamic Input based on Rating
                if (_selectedRating == 5) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.thumb_up_rounded, color: Color(0xFF10B981), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⭐⭐⭐⭐⭐ बहुत-बहुत धन्यवाद! हमें खुशी है कि आपको Msixa Player पसंद आया!',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _msgController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      hintText: 'कोई सुझाव या पसंदीदा फीचर बताएं... (वैकल्पिक / Optional)',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ] else if (_selectedRating > 0 && _selectedRating < 5) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.help_outline_rounded, color: Color(0xFFFFB300), size: 18),
                            SizedBox(width: 6),
                            Text(
                              'क्या सुधार करने की जरूरत लगती है? *',
                              style: TextStyle(
                                color: Color(0xFFFFB300),
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'कृपया बताएं ताकि हम आपके लिए ऐप को और बेहतर बना सकें:',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _msgController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (val) {
                      if (_validationError != null && val.trim().length >= 5) {
                        setState(() => _validationError = null);
                      }
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      hintText: 'जैसे: गानों की क्वालिटी, अधिक गाने, सर्च, प्लेयर या अन्य कोई सुझाव...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFFFB300)),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],

                // Validation Error Banner
                if (_validationError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _validationError!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // Submit Button (Player continues uninterrupted!)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.transparent,
                      shadowColor: const Color(0xFF00E5FF).withOpacity(0.3),
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF4F46E5)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'फ़ीडबैक सबमिट करें (Submit)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '🎵 आपका संगीत बैकग्राउंड में निरंतर बजता रहेगा',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
