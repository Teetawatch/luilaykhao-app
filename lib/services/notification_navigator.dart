import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart' show appNavigatorKey;
import '../models/sos_alert.dart';
import '../providers/app_provider.dart';
import '../screens/profile_screen.dart' show NotificationsScreen;
import '../screens/sos_alert_screen.dart';
import '../screens/trip_detail_screen.dart' show TripDetailScreen;

/// Maps notification type + data payload to the correct in-app screen.
///
/// The backend should include these keys in the FCM data payload:
///   type         – one of the cases below
///   booking_ref  – booking reference string (for booking/payment types)
class NotificationNavigator {
  NotificationNavigator._();

  static void handle(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'payment':
      case 'installment_due':
      case 'payment_confirmed':
      case 'payment_rejected':
      case 'booking':
      case 'booking_confirmed':
      case 'booking_cancelled':
      case 'booking_reminder':
      case 'trip_reminder':
        _openBookingDetail(data);
      case 'seat_alert':
        _switchTab(2);
      case 'sos_alert':
        _openSosAlert(data);
      case 'promo':
        _switchTab(1);
      case 'loyalty':
      case 'system':
      default:
        _openNotifications();
    }
  }

  static NavigatorState? get _nav => appNavigatorKey.currentState;

  static void _openBookingDetail(Map<String, dynamic> data) {
    final ref = data['booking_ref']?.toString();
    // If no booking_ref, fall back to bookings tab.
    if (ref == null || ref.isEmpty) {
      _switchTab(2);
      return;
    }
    _switchTab(2);
  }

  static void _openSosAlert(Map<String, dynamic> data) {
    final nav = _nav;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => SosAlertScreen(alert: SosAlert.fromNotificationData(data)),
      ),
    );
  }

  static void _openNotifications() {
    _switchTab(3);
    Future.delayed(const Duration(milliseconds: 280), () {
      _nav?.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, anim, _) => const NotificationsScreen(),
          transitionsBuilder: (_, anim, _, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    });
  }

  static void registerTabSwitcher(void Function(int) switcher) {
    _switchTab = switcher;
  }

  // ignore: prefer_function_declarations_over_variables
  static void Function(int) _switchTab = (_) {};

  /// Route a deep link like `luilaykhao://trip/koh-tao` or
  /// `luilaykhao://booking/TRD-20250101-0001` to the matching screen.
  ///
  /// Returns true when the link was recognised so the caller can swallow
  /// it; unrecognised links fall through to the social-login handler.
  static bool handleDeepLink(Uri uri) {
    if (uri.scheme != 'luilaykhao') return false;

    switch (uri.host) {
      case 'trip':
        final slug = _firstSegment(uri.pathSegments);
        if (slug == null) return false;
        _openTrip(slug);
        return true;
      case 'booking':
        final ref = _firstSegment(uri.pathSegments);
        if (ref == null) return false;
        _openBookingByRef(ref);
        return true;
    }
    return false;
  }

  static String? _firstSegment(List<String> segments) {
    if (segments.isEmpty) return null;
    final first = segments.first.trim();
    return first.isEmpty ? null : first;
  }

  static void _openTrip(String slug) {
    final nav = _nav;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(builder: (_) => TripDetailScreen(slug: slug)),
    );
  }

  static void _openBookingByRef(String ref) {
    final nav = _nav;
    if (nav == null) return;
    final ctx = nav.context;
    // Best-effort: refresh bookings then drop the user on the Bookings tab.
    // Surfacing the specific booking sheet would require deeper plumbing
    // into MyBookingsScreen state — out of scope for v1.
    try {
      ctx.read<AppProvider>().loadAccountData();
    } catch (_) {}
    _switchTab(2);
  }
}
