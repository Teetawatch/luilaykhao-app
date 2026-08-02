import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import 'push_notification_service.dart';

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
  // ringer is silenced. Use gain (not gainTransient) so Android doesn't revoke
  // focus while the siren loops — gainTransient is designed for brief sounds.
  static final _alarmAudioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: true,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.alarm,
      audioFocus: AndroidAudioFocus.gain,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
  );

  /// Longest the siren may run unattended before it stops on its own.
  static const _maxDuration = Duration(minutes: 3);

  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _player = AudioPlayer(playerId: 'sos_siren');
  bool _initialized = false;
  bool _playing = false;
  Timer? _repeatTimer;
  Timer? _autoStopTimer;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    // Deliberately does NOT call _localNotifications.initialize() itself: the
    // plugin is a singleton and initialize() overwrites the tap callback, so
    // doing it here used to wipe PushNotificationService's handler and break
    // notification taps app-wide for the rest of the session.
    await PushNotificationService.instance.ensureLocalNotificationsReady();

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(sosChannel);

    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setAudioContext(_alarmAudioContext);

    _initialized = true;
  }

  /// [data] is the FCM/Reverb payload of the alert. It rides along on the
  /// notification so tapping it opens the SOS detail screen — without it the
  /// user hears a siren they can neither identify nor silence, since the siren
  /// only stops when that screen is closed.
  Future<void> start({
    required String senderName,
    Map<String, dynamic>? data,
  }) async {
    await _ensureInitialized();

    HapticFeedback.heavyImpact();

    // Continuous looping siren — the real "loud" part. Keeps playing until
    // stop() is called (e.g. when the SOS screen is dismissed).
    if (!_playing) {
      _playing = true;
      try {
        await _player.stop();
        // Re-apply audio context before each play so Android honours the alarm
        // stream and audio focus even when the player was previously released.
        await _player.setAudioContext(_alarmAudioContext);
        await _player.play(AssetSource('audio/sos_siren.wav'), volume: 1.0);
      } catch (e) {
        debugPrint('[SosAlarm] audio play failed: $e');
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
      payload: jsonEncode({...?data, 'type': 'sos_alert'}),
    );

    _triggerVibration();

    // Repeat vibration every ~3 s so the user can't miss it.
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _triggerVibration();
      HapticFeedback.heavyImpact();
    });

    // Safety net: a phone left in a pack with nobody to open the screen would
    // otherwise siren until the battery dies — the battery is what the group
    // needs for the rest of the rescue.
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(_maxDuration, stop);
  }

  Future<void> stop() async {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
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
