import 'package:flutter/material.dart';

import '../main.dart' show appNavigatorKey;
import '../screens/profile_screen.dart' show NotificationsScreen;

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

  static void _openNotifications() {
    _switchTab(3);
    Future.delayed(const Duration(milliseconds: 280), () {
      _nav?.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, anim, __) => const NotificationsScreen(),
          transitionsBuilder: (_, anim, __, child) {
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
}
