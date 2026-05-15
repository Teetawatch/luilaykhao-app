import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_config.dart';

/// Centralised wrapper around Firebase Analytics + Crashlytics.
///
/// Falls back to no-op if Firebase isn't initialised — call sites never need
/// to know whether telemetry is wired up for the current build.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  bool _ready = false;
  FirebaseAnalytics? _analytics;
  FirebaseCrashlytics? _crashlytics;

  FirebaseAnalyticsObserver? _observer;
  FirebaseAnalyticsObserver? get observer => _observer;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      final options = FirebaseConfig.options;
      if (Firebase.apps.isEmpty) {
        if (options == null) {
          await Firebase.initializeApp();
        } else {
          await Firebase.initializeApp(options: options);
        }
      }
      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);

      await _crashlytics!.setCrashlyticsCollectionEnabled(!kDebugMode);

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        _crashlytics?.recordFlutterError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics?.recordError(error, stack, fatal: true);
        return true;
      };

      _ready = true;
    } catch (e) {
      debugPrint('Analytics disabled: $e');
    }
  }

  Future<void> setUser({String? id, String? email}) async {
    if (!_ready) return;
    try {
      await _analytics?.setUserId(id: id);
      if (id != null) await _crashlytics?.setUserIdentifier(id);
      if (email != null) {
        await _crashlytics?.setCustomKey('email', email);
      }
    } catch (e) {
      debugPrint('Analytics.setUser error: $e');
    }
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
  }) async {
    if (!_ready) return;
    try {
      final clean = <String, Object>{};
      parameters?.forEach((k, v) {
        if (v != null) clean[k] = v;
      });
      await _analytics?.logEvent(name: name, parameters: clean);
    } catch (e) {
      debugPrint('Analytics.logEvent error: $e');
    }
  }

  Future<void> logLogin(String method) =>
      logEvent('login', parameters: {'method': method});

  Future<void> logSignUp(String method) =>
      logEvent('sign_up', parameters: {'method': method});

  Future<void> logBookingCreated({
    required String tripSlug,
    num? amount,
  }) {
    return logEvent('booking_created', parameters: {
      'trip_slug': tripSlug,
      'amount': ?amount,
    });
  }

  Future<void> logBookingCancelled(String bookingRef) =>
      logEvent('booking_cancelled', parameters: {'booking_ref': bookingRef});

  Future<void> logReviewSubmitted(int bookingId, int rating) => logEvent(
    'review_submitted',
    parameters: {'booking_id': bookingId, 'rating': rating},
  );

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    if (!_ready) return;
    try {
      await _crashlytics?.recordError(error, stack, reason: reason);
    } catch (e) {
      debugPrint('Analytics.recordError error: $e');
    }
  }

  /// Add a breadcrumb-style log entry that surfaces in the next crash report.
  Future<void> log(String message) async {
    if (!_ready) return;
    try {
      await _crashlytics?.log(message);
    } catch (_) {}
  }
}
