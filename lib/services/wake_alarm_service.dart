import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'push_notification_service.dart';

/// ปลุกรวมในห้องแชท — ตั้งแจ้งเตือนในเครื่องไว้ที่เวลาปลุก
///
/// ทริปขึ้นดูทะเลหมอกตีสี่มักนอนในที่ที่ไม่มีสัญญาณ แจ้งเตือนจากเซิร์ฟเวอร์ (ทางหลัก)
/// ไปไม่ถึง แจ้งเตือนที่ตั้งไว้ในเครื่องตั้งแต่ตอนที่ยังมีสัญญาณจึงเป็นตัวสำรองที่ดังแน่
///
/// ตั้งเมื่อห้องแชทเห็นการ์ดปลุกที่ฉันมีคนต้องปลุก (ตัวเองหรือคนในกลุ่ม) และยกเลิก
/// เมื่อทุกคนของฉันกด "ตื่นแล้ว" / การ์ดปิด / เวลาปลุกเลื่อน (ตั้งใหม่ที่เวลาใหม่)
///
/// Android ใช้แบบไม่ตรงเวลาเป๊ะ (inexact) เมื่อเครื่องไม่ให้สิทธิ์ตั้งเวลาแม่นยำ —
/// แอปไม่ขอสิทธิ์ SCHEDULE_EXACT_ALARM โดยตั้งใจ เครื่องที่หลับลึกอาจช้าไปไม่กี่นาที
/// แต่ยังดังแม้ไม่มีเน็ต ส่วน iOS ตรงเวลาเสมอ
class WakeAlarmService {
  WakeAlarmService._();

  static final instance = WakeAlarmService._();

  /// id ของแจ้งเตือนในเครื่อง — กันชนกับ id อื่นของแอป (0 = แจ้งเตือนแชท, 9911 = SOS)
  static int notificationId(int stopId) => 700000 + stopId;

  static const _channel = AndroidNotificationChannel(
    'wake_call',
    'ปลุกรวมในทริป',
    description: 'ปลุกตามเวลาที่ทีมงานนัดไว้ แม้ตอนนั้นไม่มีสัญญาณ',
    importance: Importance.max,
  );

  final _plugin = FlutterLocalNotificationsPlugin();

  /// การ์ดปลุกที่ตั้งไว้ในเครื่องแล้ว: stopId → เวลาปลุก (UTC) — การ์ดใช้บอกผู้ใช้ว่า
  /// "เครื่องนี้ตั้งปลุกไว้แล้ว" และกันตั้งซ้ำทุกครั้งที่การ์ดอัปเดต
  final ValueNotifier<Map<int, DateTime>> scheduled = ValueNotifier(const {});

  bool _channelReady = false;

  /// การ์ดปลุก [stop] (payload rest_stop kind=wakeup) ควรมีปลุกในเครื่องไหม
  /// แล้วตั้ง/ย้าย/ยกเลิกให้ตรง — เรียกซ้ำได้ ไม่ตั้งซ้ำถ้าไม่มีอะไรเปลี่ยน
  Future<void> sync(Map<String, dynamic> stop, int? myUserId) async {
    final stopId = int.tryParse('${stop['id']}') ?? 0;
    if (stopId == 0 || stop['kind'] != 'wakeup') return;

    final wakeAt = wakeTimeFor(stop, myUserId, DateTime.now());
    if (wakeAt == null) {
      await cancel(stopId);
      return;
    }
    if (scheduled.value[stopId] == wakeAt) return;

    try {
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
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBanner: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: await _scheduleMode(),
        payload: null,
      );
      scheduled.value = {...scheduled.value, stopId: wakeAt};
    } catch (e) {
      // ตั้งไม่ได้ (ปิดสิทธิ์แจ้งเตือน ฯลฯ) — ยังมีแจ้งเตือนจากเซิร์ฟเวอร์เป็นทางหลัก
      debugPrint('[WakeAlarm] schedule failed: $e');
    }
  }

  Future<void> cancel(int stopId) async {
    if (!scheduled.value.containsKey(stopId)) return;
    try {
      await _plugin.cancel(id: notificationId(stopId));
    } catch (e) {
      debugPrint('[WakeAlarm] cancel failed: $e');
    }
    scheduled.value = {...scheduled.value}..remove(stopId);
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

  String _body(Map<String, dynamic> stop) {
    final note = stop['place']?.toString() ?? '';
    return note.isEmpty
        ? 'ตื่นแล้วเปิดแชท กด "ตื่นแล้ว" ให้ทีมงานรู้ด้วยนะครับ'
        : '$note — ตื่นแล้วกด "ตื่นแล้ว" ในแชทด้วยนะครับ';
  }

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    await PushNotificationService.instance.ensureLocalNotificationsReady();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    _channelReady = true;
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }
}
