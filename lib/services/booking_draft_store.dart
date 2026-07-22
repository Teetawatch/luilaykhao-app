import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps a half-finished booking so a phone call, a dead battery, or an expired
/// seat lock does not cost the customer eleven fields per traveller.
///
/// Stored on the device only. It holds identity documents and health notes, so
/// it never leaves the phone, is dropped the moment the booking is submitted,
/// and expires on its own after [_maxAge] rather than sitting there forever.
class BookingDraftStore {
  static const String _prefix = 'booking_draft_v1.';

  /// A week is long enough to come back to a trip you were thinking about, and
  /// short enough that stale prices and sold-out rounds are not resurrected.
  static const Duration _maxAge = Duration(days: 7);

  static String _key(String tripSlug) => '$_prefix$tripSlug';

  static Future<void> save({
    required String tripSlug,
    required Map<String, dynamic> draft,
  }) async {
    if (tripSlug.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(tripSlug),
        jsonEncode({
          ...draft,
          'saved_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('[BookingDraft] save failed: $e');
    }
  }

  /// Returns the draft, or null when there is none or it has gone stale.
  /// A stale draft is deleted on the way out rather than left to accumulate.
  static Future<Map<String, dynamic>?> load(String tripSlug) async {
    if (tripSlug.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(tripSlug));
      if (raw == null) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final draft = Map<String, dynamic>.from(decoded);

      final savedAt = DateTime.tryParse('${draft['saved_at']}');
      if (savedAt == null ||
          DateTime.now().difference(savedAt) > _maxAge) {
        await clear(tripSlug);
        return null;
      }

      return draft;
    } catch (e) {
      debugPrint('[BookingDraft] load failed: $e');
      return null;
    }
  }

  static Future<void> clear(String tripSlug) async {
    if (tripSlug.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(tripSlug));
    } catch (e) {
      debugPrint('[BookingDraft] clear failed: $e');
    }
  }

  /// Wipes every draft — used on logout, since drafts carry ID numbers and
  /// health notes belonging to the account that was signed in.
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(_prefix)) await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('[BookingDraft] clearAll failed: $e');
    }
  }

  /// True when the draft has enough typed into it to be worth offering back.
  /// A draft where nobody's name was entered is just an opened screen.
  static bool isWorthRestoring(Map<String, dynamic> draft) {
    final passengers = draft['passengers'];
    if (passengers is! List) return false;

    return passengers.any((p) {
      if (p is! Map) return false;
      final name = '${p['name'] ?? ''}'.trim();
      final phone = '${p['phone'] ?? ''}'.trim();
      return name.isNotEmpty || phone.isNotEmpty;
    });
  }
}
