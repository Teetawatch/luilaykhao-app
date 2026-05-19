import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

/// Fires a loud, continuously looping siren when an SOS is received.
///
/// Call [start] when the alert arrives, [stop] when the SOS screen is
/// dismissed. Safe to call stop() multiple times or without a prior start().
class SosAlarmService {
  SosAlarmService._();
  static final instance = SosAlarmService._();

  static const _channelId = 'sos_emergency_v2';
  static const _channelName = 'SOS ฉุกเฉิน';

  // 500 ms on, 200 ms off × 4 — repeated every 3 s by [_repeatTimer].
  static const _vibrationPattern = [0, 500, 200, 500, 200, 500, 200, 500];

  /// Shared so [PushNotificationService] can register an identical channel at
  /// startup — the channel must exist before a killed app receives an FCM SOS.
  static const sosChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: 'สัญญาณ SOS ฉุกเฉินจากเพื่อนร่วมทริป',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('sos_siren'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
    playSound: true,
  );

  // Route playback through the alarm stream so it stays loud even when the
  // ringer is silenced, and grab audio focus so music/podcasts pause.
  static final _alarmAudioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: true,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.alarm,
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
  );

  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _player = AudioPlayer(playerId: 'sos_siren');
  bool _initialized = false;
  bool _playing = false;
  Timer? _repeatTimer;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(sosChannel);

    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setAudioContext(_alarmAudioContext);

    _initialized = true;
  }

  Future<void> start({required String senderName}) async {
    await _ensureInitialized();

    HapticFeedback.heavyImpact();

    // Continuous looping siren — the real "loud" part. Keeps playing until
    // stop() is called (e.g. when the SOS screen is dismissed).
    if (!_playing) {
      _playing = true;
      try {
        await _player.stop();
        await _player.play(AssetSource('audio/sos_siren.wav'), volume: 1.0);
      } catch (_) {
        _playing = false;
      }
    }

    // Visual alert + full-screen intent to wake the screen. Sound/vibration
    // are suppressed here (silent: true) because the looping AudioPlayer and
    // the vibration timer below already cover those.
    await _localNotifications.show(
      id: 9911,
      title: '🆘 SOS — $senderName ขอความช่วยเหลือ',
      body: 'แตะเพื่อดูรายละเอียดและช่วยเหลือ',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          ongoing: true,
          silent: true,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: false,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );

    _triggerVibration();

    // Repeat vibration every ~3 s so the user can't miss it.
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _triggerVibration();
      HapticFeedback.heavyImpact();
    });
  }

  Future<void> stop() async {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    Vibration.cancel();
    _playing = false;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _localNotifications.cancel(id: 9911);
    } catch (_) {}
  }

  void _triggerVibration() {
    Vibration.vibrate(
      pattern: _vibrationPattern,
      intensities: [0, 255, 0, 255, 0, 255, 0, 255],
    );
  }
}
