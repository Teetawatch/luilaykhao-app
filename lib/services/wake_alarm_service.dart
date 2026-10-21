import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'push_notification_service.dart';

/// ปลุกที่ตั้งไว้ในเครื่องแล้ว — [exact] = ดังตรงเวลา (Android ได้สิทธิ์ตั้งเวลาแม่นยำ
/// หรือเป็น iOS) ไม่งั้นเครื่องที่หลับลึกอาจเลื่อนไปไม่กี่นาที
@immutable
class WakeAlarmEntry {
  final DateTime at;
  final bool exact;

  const WakeAlarmEntry({required this.at, required this.exact});

  @override
  bool operator ==(Object other) =>
      other is WakeAlarmEntry && other.at == at && other.exact == exact;

  @override
  int get hashCode => Object.hash(at, exact);
}

/// ปลุกรวมในห้องแชท — ตั้งแจ้งเตือนในเครื่องไว้ที่เวลาปลุก
///
/// ทริปขึ้นดูทะเลหมอกตีสี่มักนอนในที่ที่ไม่มีสัญญาณ แจ้งเตือนจากเซิร์ฟเวอร์ (ทางหลัก)
/// ไปไม่ถึง แจ้งเตือนที่ตั้งไว้ในเครื่องตั้งแต่ตอนที่ยังมีสัญญาณจึงเป็นตัวสำรองที่ดังแน่
///
/// ตั้งเมื่อห้องแชทเห็นการ์ดปลุกที่ฉันมีคนต้องปลุก (ตัวเองหรือคนในกลุ่ม) และยกเลิก
/// เมื่อทุกคนของฉันกด "ตื่นแล้ว" / การ์ดปิด / เวลาปลุกเลื่อน (ตั้งใหม่ที่เวลาใหม่)
///
/// Android: ได้สิทธิ์ SCHEDULE_EXACT_ALARM = ตั้งแบบนาฬิกาปลุก (alarmClock) ดังตรงเวลา
/// แม้เครื่องหลับลึก ไม่ได้สิทธิ์ (ค่าตั้งต้นของ Android 14+) = ตั้งแบบไม่ตรงเป๊ะ และ
/// การ์ดมีปุ่มพาไปเปิดสิทธิ์ — กลับเข้าแอปแล้ว [refreshExactness] ย้ายไปแบบตรงเวลาให้
/// iOS ตรงเวลาเสมอ
class WakeAlarmService {
  WakeAlarmService._();

  static final instance = WakeAlarmService._();

  /// id ของแจ้งเตือนในเครื่อง — กันชนกับ id อื่นของแอป (0 = แจ้งเตือนแชท, 9911 = SOS)
  static int notificationId(int stopId) => 700000 + stopId;

  /// เสียงผ่านช่องนาฬิกาปลุก — ดังแม้ปิดเสียงเรียกเข้าไว้ (ปลุกตีสี่ต้องดังจริง)
  static const _channel = AndroidNotificationChannel(
    'wake_call_alarm',
    'ปลุกรวมในทริป',
    description: 'ปลุกตามเวลาที่ทีมงานนัดไว้ แม้ตอนนั้นไม่มีสัญญาณ',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  final _plugin = FlutterLocalNotificationsPlugin();

  /// การ์ดปลุกที่ตั้งไว้ในเครื่องแล้ว: stopId → เวลา + ตรงเวลาไหม — การ์ดใช้บอกผู้ใช้
  /// และกันตั้งซ้ำทุกครั้งที่การ์ดอัปเดต
  final ValueNotifier<Map<int, WakeAlarmEntry>> scheduled = ValueNotifier(
    const {},
  );

  /// payload ล่าสุดของแต่ละการ์ด — ไว้ตั้งใหม่เมื่อได้สิทธิ์ตั้งเวลาแม่นยำทีหลัง
  final Map<int, ({Map<String, dynamic> stop, int? userId})> _last = {};

  bool _channelReady = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// การ์ดปลุก [stop] (payload rest_stop kind=wakeup) ควรมีปลุกในเครื่องไหม
  /// แล้วตั้ง/ย้าย/ยกเลิกให้ตรง — เรียกซ้ำได้ ไม่ตั้งซ้ำถ้าไม่มีอะไรเปลี่ยน
  Future<void> sync(Map<String, dynamic> stop, int? myUserId) async {
    final stopId = int.tryParse('${stop['id']}') ?? 0;
    if (stopId == 0 || stop['kind'] != 'wakeup') return;
    _last[stopId] = (stop: stop, userId: myUserId);

    final wakeAt = wakeTimeFor(stop, myUserId, DateTime.now());
    if (wakeAt == null) {
      _last.remove(stopId);
      await cancel(stopId);
      return;
    }

    try {
      final exact = await canRingExactly();
      final entry = WakeAlarmEntry(at: wakeAt, exact: exact);
      if (scheduled.value[stopId] == entry) return;

      await _ensureChannel();
      await _plugin.zonedSchedule(
        id: notificationId(stopId),
        title: '⏰ ได้เวลาตื่นแล้ว!',
        body: _body(stop),
        scheduledDate: tz.TZDateTime.from(wakeAt, tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            // ขึ้นเต็มจอบนหน้าจอล็อก (เครื่องไม่ให้สิทธิ์ = ขึ้นแบบป๊อปอัปแทน)
            fullScreenIntent: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBanner: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: scheduleModeFor(exact: exact),
        payload: null,
      );
      scheduled.value = {...scheduled.value, stopId: entry};
    } catch (e) {
      // ตั้งไม่ได้ (ปิดสิทธิ์แจ้งเตือน ฯลฯ) — ยังมีแจ้งเตือนจากเซิร์ฟเวอร์เป็นทางหลัก
      debugPrint('[WakeAlarm] schedule failed: $e');
    }
  }

  Future<void> cancel(int stopId) async {
    _last.remove(stopId);
    if (!scheduled.value.containsKey(stopId)) return;
    try {
      await _plugin.cancel(id: notificationId(stopId));
    } catch (e) {
      debugPrint('[WakeAlarm] cancel failed: $e');
    }
    scheduled.value = {...scheduled.value}..remove(stopId);
  }

  /// เครื่องนี้ตั้งปลุกให้ดังตรงเวลาได้ไหม — iOS ได้เสมอ, Android ขึ้นกับสิทธิ์
  Future<bool> canRingExactly() async {
    if (!_isAndroid) return true;
    try {
      return await _android()?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// พาไปเปิดสิทธิ์ "นาฬิกาปลุกและการเตือนความจำ" ในตั้งค่า แล้วตั้งปลุกใหม่ให้ตรงเวลา
  /// (ผู้ใช้กลับเข้าแอปทีหลังก็ได้ — ห้องแชทเรียก [refreshExactness] ตอน resume)
  Future<void> requestExact() async {
    if (!_isAndroid) return;
    try {
      await _android()?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('[WakeAlarm] request exact failed: $e');
    }
    await refreshExactness();
  }

  /// สิทธิ์ตั้งเวลาแม่นยำเปลี่ยนไป (เพิ่งเปิด/ปิดในตั้งค่า) — ตั้งปลุกที่มีอยู่ใหม่ให้ตรงสิทธิ์
  Future<void> refreshExactness() async {
    if (_last.isEmpty) return;
    final exact = await canRingExactly();
    final stale = scheduled.value.entries
        .where((e) => e.value.exact != exact)
        .map((e) => e.key)
        .toList();
    for (final stopId in stale) {
      final last = _last[stopId];
      if (last != null) await sync(last.stop, last.userId);
    }
  }

  /// เวลาที่ควรปลุกเครื่องนี้ — null เมื่อไม่ต้องปลุก: การ์ดปิดแล้ว, เลยเวลาแล้ว,
  /// หรือคนที่ฉันดูแลกด "ตื่นแล้ว" ครบ (หรือฉันไม่มีใครในรายชื่อเลย)
  @visibleForTesting
  static DateTime? wakeTimeFor(
    Map<String, dynamic> stop,
    int? myUserId,
    DateTime now,
  ) {
    if (stop['kind'] != 'wakeup' || stop['is_departed'] == true) return null;
    final at = DateTime.tryParse('${stop['return_at'] ?? ''}')?.toUtc();
    if (at == null || !at.isAfter(now.toUtc())) return null;
    if (myUserId == null) return null;

    final mine = (stop['passengers'] as List? ?? const [])
        .whereType<Map>()
        .where((p) => int.tryParse('${p['user_id']}') == myUserId)
        .toList();
    if (mine.isEmpty || mine.every((p) => p['boarded'] == true)) return null;
    return at;
  }

  /// ได้สิทธิ์ = แบบนาฬิกาปลุก (ตรงเวลา ไม่โดนโหมดประหยัดพลังงานเลื่อน และขึ้นไอคอน
  /// นาฬิกาปลุกบนแถบสถานะ) ไม่ได้ = แบบไม่ตรงเป๊ะที่ยังดังตอนเครื่องหลับ
  @visibleForTesting
  static AndroidScheduleMode scheduleModeFor({required bool exact}) => exact
      ? AndroidScheduleMode.alarmClock
      : AndroidScheduleMode.inexactAllowWhileIdle;

  AndroidFlutterLocalNotificationsPlugin? _android() => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  String _body(Map<String, dynamic> stop) {
    final note = stop['place']?.toString() ?? '';
    return note.isEmpty
        ? 'ตื่นแล้วเปิดแชท กด "ตื่นแล้ว" ให้ทีมงานรู้ด้วยนะครับ'
        : '$note — ตื่นแล้วกด "ตื่นแล้ว" ในแชทด้วยนะครับ';
  }

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    await PushNotificationService.instance.ensureLocalNotificationsReady();
    await _android()?.createNotificationChannel(_channel);
    _channelReady = true;
  }
}
