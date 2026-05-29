import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/firebase_config.dart';
import 'api_client.dart';
import 'sos_alarm_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    final options = FirebaseConfig.options;
    if (Firebase.apps.isEmpty) {
      if (options == null) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(options: options);
      }
    }

    // SOS now arrives as a notification message on the loud `sos_emergency_v2`
    // channel, which the Android system displays (with siren + vibration) on its
    // own even when killed. Only fall back to a local notification here for a
    // data-only SOS (no notification block) so we never show a duplicate.
    if (message.data['type'] == 'sos_alert' &&
        message.notification == null &&
        defaultTargetPlatform == TargetPlatform.android) {
      final localNotifications = FlutterLocalNotificationsPlugin();
      await localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final androidPlugin = localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(SosAlarmService.sosChannel);

      final senderName =
          message.data['sos_user_name']?.toString() ?? 'เพื่อนร่วมทริป';
      await localNotifications.show(
        id: 9911,
        title: '🆘 SOS — $senderName ขอความช่วยเหลือ',
        body: 'แตะเพื่อดูรายละเอียดและช่วยเหลือ',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            SosAlarmService.sosChannel.id,
            SosAlarmService.sosChannel.name,
            channelDescription: SosAlarmService.sosChannel.description,
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            ongoing: true,
            sound: const RawResourceAndroidNotificationSound('sos_siren'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
            vibrationPattern:
                Int64List.fromList([0, 500, 200, 500, 200, 500, 200, 500]),
            playSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
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

  static const _badgeChannel = MethodChannel('luilaykhao/badge');

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
  Map<String, dynamic>? _pendingTapData;

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
      // A tap may have been processed before any UI listener was registered —
      // most often a cold launch from a killed state, where main()'s early
      // initialize() consumes getInitialMessage() before CustomerAppScreen
      // mounts and registers this callback. Replay it now.
      _flushPendingTap();
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

      // App launched by tapping an FCM notification (killed state).
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage.data);
        _onRefreshRequested?.call();
      }

      // App launched by tapping a local notification shown by the background
      // handler (e.g. SOS while the app was killed on Android).
      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final payload = launchDetails!.notificationResponse?.payload;
        if (payload != null) {
          try {
            final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
            // Small delay to ensure the navigator is mounted before routing.
            Future.delayed(const Duration(milliseconds: 500), () {
              _handleNotificationTap(data);
            });
          } catch (_) {}
        }
      }
    } catch (e, st) {
      _initFuture = null; // allow retry on next initialize() call
      debugPrint('[PushNotificationService] init failed: $e\n$st');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final callback = _onNotificationTap;
    if (callback == null) {
      // No UI listener yet — hold the tap so it isn't lost, and replay it
      // once initialize() is called with an onNotificationTap callback.
      _pendingTapData = data;
      return;
    }
    final type = data['type']?.toString() ?? '';
    callback(type, data);
  }

  void _flushPendingTap() {
    final pending = _pendingTapData;
    if (pending == null) return;
    _pendingTapData = null;
    _handleNotificationTap(pending);
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

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
    // Alarm-grade SOS channel with the looping siren sound. Must exist before
    // a killed app receives an FCM SOS, otherwise Android picks a silent channel.
    await androidPlugin?.createNotificationChannel(SosAlarmService.sosChannel);

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

  /// Sets the iOS app-icon badge to [count]. APNs only updates the badge when
  /// a new push arrives, so reading notifications in-app would otherwise leave
  /// the previous count stuck on the home-screen icon.
  Future<void> setBadgeCount(int count) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final safe = count < 0 ? 0 : count;
    try {
      await _badgeChannel.invokeMethod('setBadgeCount', {'count': safe});
    } catch (e) {
      debugPrint('[FCM] setBadgeCount failed: $e');
    }
  }

  Future<void> clearBadge() => setBadgeCount(0);

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // SOS arriving while the app is foregrounded: fire the loud, looping
    // siren on every platform so it cannot be missed.
    if (message.data['type']?.toString() == 'sos_alert') {
      final senderName =
          message.data['sos_user_name']?.toString() ?? 'เพื่อนร่วมทริป';
      await SosAlarmService.instance.start(senderName: senderName);
      return;
    }

    // iOS already shows the banner via setForegroundNotificationPresentationOptions.
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
    if (!_localReady) return;

    final android = notification.android;
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
