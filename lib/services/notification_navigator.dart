import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart' show appNavigatorKey;
import '../models/sos_alert.dart';
import '../providers/app_provider.dart';
import '../screens/chat_screen.dart';
import '../screens/group_room_screen.dart';
import '../screens/join_booking_screen.dart';
import '../screens/profile_screen.dart' show NotificationsScreen;
import '../screens/sos_alert_screen.dart';
import '../screens/trip_detail_screen.dart' show TripDetailScreen;
import 'sos_alarm_service.dart';

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
      case 'trip_checklist':
      case 'weather_alert':
      case 'vehicle_departed':
      case 'vehicle_approaching':
      case 'review_invite':
        _openBookingDetail(data);
      case 'seat_alert':
        _switchTab(2);
      case 'trip_alert':
        _openTripFromData(data);
      case 'sos_alert':
        _openSosAlert(data);
      case 'chat_message':
        _openChat(data);
      case 'promo':
        _switchTab(1);
      case 'loyalty':
      case 'system':
      default:
        _openNotifications();
    }
  }

  static NavigatorState? get _nav => appNavigatorKey.currentState;

  /// Runs [action] once the root navigator is mounted. On a cold launch from a
  /// killed state the tap is replayed during `CustomerAppScreen.initState`,
  /// before the first frame — so `appNavigatorKey.currentState` is still null.
  /// Retry briefly instead of silently dropping the navigation.
  static void _withNav(
    void Function(NavigatorState nav) action, {
    int attempt = 0,
  }) {
    final nav = _nav;
    if (nav != null) {
      action(nav);
      return;
    }
    if (attempt >= 20) return; // give up after ~5s
    Future.delayed(
      const Duration(milliseconds: 250),
      () => _withNav(action, attempt: attempt + 1),
    );
  }

  static void _openBookingDetail(Map<String, dynamic> data) {
    final ref = data['booking_ref']?.toString();
    // If no booking_ref, fall back to bookings tab.
    if (ref == null || ref.isEmpty) {
      _switchTab(2);
      return;
    }
    _switchTab(2);
  }

  static void _openTripFromData(Map<String, dynamic> data) {
    final slug = data['trip_slug']?.toString().trim() ?? '';
    if (slug.isEmpty) {
      _openNotifications();
      return;
    }
    _openTrip(slug);
  }

  static void _openChat(Map<String, dynamic> data) {
    final id = int.tryParse('${data['schedule_id']}') ?? 0;
    if (id == 0) {
      _openNotifications();
      return;
    }
    _withNav(
      (nav) => nav.push(
        MaterialPageRoute(builder: (_) => ChatScreen(scheduleId: id)),
      ),
    );
  }

  static void _openSosAlert(Map<String, dynamic> data) {
    final alert = SosAlert.fromNotificationData(data);
    SosAlarmService.instance.start(senderName: alert.userName);
    _withNav(
      (nav) => nav
          .push(
            MaterialPageRoute(
              builder: (_) => SosAlertScreen(alert: alert),
            ),
          )
          .then((_) => SosAlarmService.instance.stop()),
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

  static void goToProfile() => _switchTab(3);

  static void goToBookings() => _switchTab(2);

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
      case 'group':
        final code = _firstSegment(uri.pathSegments);
        if (code == null) return false;
        _openGroup(code);
        return true;
      case 'join':
        final token = _firstSegment(uri.pathSegments);
        if (token == null) return false;
        _openJoinBooking(token);
        return true;
    }
    return false;
  }

  static void _openJoinBooking(String token) {
    _withNav(
      (nav) => nav.push(
        MaterialPageRoute(
          builder: (_) => JoinBookingScreen(initialToken: token),
        ),
      ),
    );
  }

  static void _openGroup(String code) {
    _withNav(
      (nav) => nav.push(
        MaterialPageRoute(builder: (_) => GroupRoomScreen(inviteCode: code)),
      ),
    );
  }

  static String? _firstSegment(List<String> segments) {
    if (segments.isEmpty) return null;
    final first = segments.first.trim();
    return first.isEmpty ? null : first;
  }

  static void _openTrip(String slug) {
    _withNav(
      (nav) => nav.push(
        MaterialPageRoute(builder: (_) => TripDetailScreen(slug: slug)),
      ),
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
