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
  bool _localReady = false;
  ApiClient? _api;
  VoidCallback? _onRefreshRequested;

  Future<void> initialize({VoidCallback? onRefreshRequested}) async {
    _onRefreshRequested = onRefreshRequested;
    if (_firebaseReady) return;

    try {
      final options = FirebaseConfig.options;
      if (options == null) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(options: options);
      }
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Push notifications disabled: $e');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initializeLocalNotifications();
    await _requestPermission();

    FirebaseMessaging.onMessage.listen((message) {
      _showForegroundNotification(message);
      _onRefreshRequested?.call();
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _onRefreshRequested?.call();
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _onRefreshRequested?.call();
    }
  }

  Future<void> syncToken(ApiClient api) async {
    _api = api;
    if (!_firebaseReady || api.token == null || api.token!.isEmpty) return;

    try {
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
    const settings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (_) => _onRefreshRequested?.call(),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    _localReady = true;
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
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
