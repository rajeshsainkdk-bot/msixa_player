import 'package:flutter/material.dart';
import 'storage_service.dart';
import '../widgets/mandatory_feedback_dialog.dart';

class FeedbackService {
  static final ValueNotifier<int> triggerPromptNotifier = ValueNotifier<int>(0);
  static bool _isDialogShowing = false;
  static bool get isDialogShowing => _isDialogShowing;

  /// Check if the user has completed at least 5 songs and has not yet submitted feedback.
  /// If condition is met, displays the non-dismissible mandatory feedback dialog.
  /// Note: The audio playback runs uninterrupted in the background.
  static Future<void> checkAndPromptFeedback(BuildContext context) async {
    final storage = StorageService();
    final hasSubmitted = await storage.hasSubmittedFeedback();
    if (hasSubmitted) return;

    final completedCount = await storage.getCompletedSongsCount();
    if (completedCount >= 5 && !_isDialogShowing) {
      if (!context.mounted) return;
      _isDialogShowing = true;
      try {
        await showDialog(
          context: context,
          barrierDismissible: false,
          useSafeArea: true,
          builder: (ctx) => const MandatoryFeedbackDialog(),
        );
      } finally {
        _isDialogShowing = false;
      }
    }
  }
}
