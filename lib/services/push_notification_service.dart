import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/firebase_config.dart';
import 'api_client.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    final options = FirebaseConfig.options;
    if (Firebase.apps.isEmpty) {
      if (options == null) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(options: options);
      }
    }
  } catch (_) {
    // Background delivery should never crash the app process.
  }
}

/// Callback fired when the user taps a notification (foreground banner or system tray).
/// [type] is the notification type string (e.g. 'payment', 'booking_reminder').
/// [data] is the full FCM data payload map.
typedef NotificationTapCallback = void Function(
  String type,
  Map<String, dynamic> data,
);

/// Callback fired when a foreground FCM message arrives, for showing an in-app banner.
typedef ForegroundNotificationCallback = void Function(
  String title,
  String body,
  String type,
  Map<String, dynamic> data,
);

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  static const _channel = AndroidNotificationChannel(
    'important_updates',
    'Important updates',
    description: 'Booking, payment, cancellation, and trip reminders.',
    importance: Importance.high,
  );

  final _localNotifications = FlutterLocalNotificationsPlugin();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  bool _firebaseReady = false;
  bool _initialized = false;
  bool _localReady = false;
  Future<void>? _initFuture;
  ApiClient? _api;
  VoidCallback? _onRefreshRequested;
  NotificationTapCallback? _onNotificationTap;
  ForegroundNotificationCallback? _onForegroundNotification;

  Future<void> initialize({
    VoidCallback? onRefreshRequested,
    NotificationTapCallback? onNotificationTap,
    ForegroundNotificationCallback? onForegroundNotification,
  }) async {
    if (onRefreshRequested != null) {
      _onRefreshRequested = onRefreshRequested;
    }
    if (onNotificationTap != null) {
      _onNotificationTap = onNotificationTap;
    }
    if (onForegroundNotification != null) {
      _onForegroundNotification = onForegroundNotification;
    }
    if (_initialized) return;
    // If a previous attempt failed, allow a retry.
    if (_initFuture != null && _firebaseReady) {
      return _initFuture;
    }
    _initFuture = _doInitialize();
    return _initFuture;
  }

  Future<void> _doInitialize() async {
    try {
      debugPrint('[FCM] starting initialization...');
      final options = FirebaseConfig.options;
      if (!_firebaseReady) {
        if (Firebase.apps.isNotEmpty) {
          _firebaseReady = true;
          debugPrint('[FCM] Firebase already initialized');
        } else if (options == null) {
          await Firebase.initializeApp();
          _firebaseReady = true;
          debugPrint('[FCM] Firebase initialized from GoogleService-Info.plist');
        } else {
          await Firebase.initializeApp(options: options);
          _firebaseReady = true;
          debugPrint('[FCM] Firebase initialized from dart-defines');
        }
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      debugPrint('[FCM] initializing local notifications...');
      await _initializeLocalNotifications();
      debugPrint('[FCM] requesting permission...');
      await _requestPermission();

      // iOS: show alert/badge/sound banners while the app is in the foreground
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] foreground presentation options set');

      FirebaseMessaging.onMessage.listen((message) {
        _showForegroundNotification(message);
        _fireForegroundCallback(message);
        _onRefreshRequested?.call();
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNotificationTap(message.data);
        _onRefreshRequested?.call();
      });

      _initialized = true;
      debugPrint('[FCM] initialization complete ✓');

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage.data);
        _onRefreshRequested?.call();
      }
    } catch (e, st) {
      _initFuture = null; // allow retry on next initialize() call
      debugPrint('[PushNotificationService] init failed: $e\n$st');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    _onNotificationTap?.call(type, data);
  }

  void _fireForegroundCallback(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final title = notification.title ?? '';
    final body = notification.body ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final type = message.data['type']?.toString() ?? '';
    _onForegroundNotification?.call(title, body, type, message.data);
  }

  Future<void> syncToken(ApiClient api) async {
    _api = api;
    if (!_firebaseReady || api.token == null || api.token!.isEmpty) return;

    try {
      // On iOS, Firebase requires an APNs token before it can issue an FCM token.
      // Poll briefly since APNs registration completes asynchronously after launch.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apns;
        for (var i = 0; i < 5 && apns == null; i++) {
          apns = await _messaging.getAPNSToken();
          if (apns == null) await Future.delayed(const Duration(seconds: 1));
        }
        if (apns == null) {
          debugPrint('FCM: APNs token unavailable — push disabled for this session');
          return;
        }
      }

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }

      _messaging.onTokenRefresh.listen(_registerToken);
    } catch (e) {
      debugPrint('Unable to sync FCM token: $e');
    }
  }

  Future<void> unregisterToken() async {
    if (!_firebaseReady || _api == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _api!.delete('notifications/push-token', body: {'token': token});
      }
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Unable to unregister FCM token: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    final api = _api;
    if (api == null || api.token == null || api.token!.isEmpty) return;

    await api.post(
      'notifications/push-token',
      body: {'token': token, 'platform': defaultTargetPlatform.name},
    );
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localReady) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // iOS: permission is requested separately via firebase_messaging,
    // so all request* flags are false here.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          try {
            final data = Map<String, dynamic>.from(
              jsonDecode(response.payload!) as Map,
            );
            _handleNotificationTap(data);
          } catch (_) {}
        }
        _onRefreshRequested?.call();
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    _localReady = true;
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] authorization status: ${settings.authorizationStatus}');

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    // iOS already shows the banner via setForegroundNotificationPresentationOptions.
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
    if (!_localReady) return;

    final notification = message.notification;
    final android = notification?.android;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
