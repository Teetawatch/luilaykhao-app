import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Triggers Google Play / App Store in-app review at safe moments.
///
/// Rules:
/// * Never prompt during the first 7 days after install.
/// * Never prompt more than once every 90 days.
/// * Caller must pass a positive sentiment signal (e.g. just submitted a
///   5-star review or successfully completed a booking).
class RatingPromptService {
  RatingPromptService._();
  static final RatingPromptService instance = RatingPromptService._();

  static const _firstSeenKey = 'rating_first_seen_v1';
  static const _lastPromptKey = 'rating_last_prompt_v1';
  static const _coolDownDays = 90;
  static const _ageGateDays = 7;

  final InAppReview _review = InAppReview.instance;

  Future<void> recordFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_firstSeenKey) != null) return;
    await prefs.setInt(
      _firstSeenKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<bool> maybeRequest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final firstSeen = prefs.getInt(_firstSeenKey);
      if (firstSeen != null) {
        final installedAt = DateTime.fromMillisecondsSinceEpoch(firstSeen);
        if (now.difference(installedAt).inDays < _ageGateDays) return false;
      }
      final last = prefs.getInt(_lastPromptKey);
      if (last != null) {
        final lastDate = DateTime.fromMillisecondsSinceEpoch(last);
        if (now.difference(lastDate).inDays < _coolDownDays) return false;
      }
      if (!await _review.isAvailable()) return false;
      await _review.requestReview();
      await prefs.setInt(_lastPromptKey, now.millisecondsSinceEpoch);
      return true;
    } catch (e) {
      debugPrint('RatingPrompt error: $e');
      return false;
    }
  }
}
