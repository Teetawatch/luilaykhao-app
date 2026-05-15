import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-category notification toggles persisted locally.
///
/// The OS-level permission still governs whether notifications can be shown at
/// all; these toggles let users opt out of specific categories without
/// muting the whole channel.
class NotificationPreferences extends ChangeNotifier {
  static const _prefix = 'notif_pref_v1.';

  static const categories = [
    'booking',
    'payment',
    'promotion',
    'reminder',
    'tracking',
  ];

  final Map<String, bool> _enabled = {
    for (final c in categories) c: true,
  };

  bool isEnabled(String category) => _enabled[category] ?? true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final c in categories) {
      final raw = prefs.getBool('$_prefix$c');
      if (raw != null) _enabled[c] = raw;
    }
    notifyListeners();
  }

  Future<void> setEnabled(String category, bool value) async {
    _enabled[category] = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$category', value);
  }

  bool shouldDeliver(String? type) {
    if (type == null || type.isEmpty) return true;
    // FCM data payload `type` maps to category prefixes used by backend.
    if (type.startsWith('payment')) return isEnabled('payment');
    if (type.startsWith('booking_reminder')) return isEnabled('reminder');
    if (type.startsWith('booking')) return isEnabled('booking');
    if (type.startsWith('promotion')) return isEnabled('promotion');
    if (type.startsWith('tracking')) return isEnabled('tracking');
    return true;
  }
}
