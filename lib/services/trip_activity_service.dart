import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/api_endpoints.dart';
import '../models/trip_activity_state.dart';
import 'api_client.dart';
import 'push_notification_service.dart';

/// การ์ด "วันเดินทาง" — บนหน้าจอล็อก โดยไม่ต้องเปิดแอป
///
/// ตอนตี 4 ที่ยืนรอรถอยู่ข้างถนน ไม่มีใครเปิดแอป เขาปลดล็อกจอแล้วดู งานของคลาสนี้
/// คือทำให้ "ที่ที่เขาดูอยู่แล้ว" มีคำตอบอยู่ตรงนั้น
///
/// สองแพลตฟอร์มเดินคนละทางแต่จบที่เดียวกัน:
///
///   iOS 16.2+  แอปเปิด Live Activity หนึ่งครั้ง แล้วส่ง push token ไปฝากเซิร์ฟเวอร์
///              หลังจากนั้นการ์ดอัปเดตเองผ่าน APNs ตรง ๆ แม้แอปจะถูกปิดไปแล้ว
///              (iOS 17.2+ เซิร์ฟเวอร์เปิดการ์ดเองได้ด้วยซ้ำ — ดู onStartToken)
///   Android    ไม่มี ActivityKit จึงใช้ ongoing notification แทน โดยรับ state
///              ก้อนเดียวกันมาทาง FCM data message แล้ววาดเอง
///
/// สิ่งที่คลาสนี้ "ไม่ทำ" โดยตั้งใจ: ไม่คิด ETA เอง ไม่แต่งประโยคเอง ไม่ตัดสินว่า
/// ตอนนี้เป็นขั้นไหน ทั้งหมดนั้นมาจาก `TripActivityService` ฝั่ง Laravel ที่เดียว
class TripActivityService {
  TripActivityService._();

  static final instance = TripActivityService._();

  static const _channel = MethodChannel('luilaykhao/live_activity');

  /// การ์ดบนแถบแจ้งเตือน Android — id คงที่เพื่อให้ "อัปเดตใบเดิม" ไม่ใช่เด้งใบใหม่
  /// ทุกนาที
  static const int androidNotificationId = 9912;

  static const AndroidNotificationChannel androidChannel =
      AndroidNotificationChannel(
        'trip_activity',
        'การ์ดวันเดินทาง',
        description: 'สถานะรถและเวลาถึงจุดรับระหว่างวันเดินทาง',
        // เงียบโดยตั้งใจ: การ์ดนี้อัปเดตทุกนาที ถ้ามีเสียงจะกลายเป็นการรบกวน
        // ส่วนจังหวะที่ควรดัง (รถถึงจุดรับ) มี push แยกของมันอยู่แล้ว
        importance: Importance.low,
      );

  final _localNotifications = FlutterLocalNotificationsPlugin();

  ApiClient? _api;
  bool _handlerAttached = false;

  /// ใบจองที่กำลังแสดงการ์ดอยู่ — กันเปิดซ้ำและใช้ตัดสินว่าต้องปิดใบไหนเมื่อ
  /// เปลี่ยนไปทริปถัดไป
  String? _activeRef;

  String? get activeBookingRef => _activeRef;

  void attachApi(ApiClient api) {
    _api = api;
    _attachHandler();
  }

  /// เปิด/รีเฟรชการ์ดให้ตรงกับใบจองที่ใกล้ที่สุดที่ยังอยู่ในช่วงวันเดินทาง
  ///
  /// เรียกได้บ่อยเท่าที่อยาก — ทุกครั้งที่แอปกลับมาหน้าจอ หลังโหลดรายการจอง ฯลฯ
  /// ทุกทางออกเงียบเสมอ นี่คือของประดับที่ดีมาก ไม่ใช่ระบบที่ธุรกิจแขวนอยู่
  Future<void> syncFromBookings(List<dynamic> bookings) async {
    final api = _api;
    if (api == null || api.token == null || api.token!.isEmpty) return;

    final due = _dueBooking(bookings);

    if (due == null) {
      if (_activeRef != null) await stop();
      return;
    }

    final ref = due['booking_ref']?.toString() ?? '';
    if (ref.isEmpty) return;

    // เปลี่ยนทริปแล้ว — เก็บการ์ดใบเก่าออกก่อน ไม่งั้นค้างสองใบ
    if (_activeRef != null && _activeRef != ref) await stop();

    try {
      final response = await api.get(ApiEndpoints.bookingLiveActivity(ref));
      final data = api.data(response) as Map?;
      final state = TripActivityState.fromJson(
        data?['state'] == null
            ? null
            : Map<String, dynamic>.from(data!['state'] as Map),
      );

      if (state == null) {
        await stop();
        return;
      }

      _activeRef = ref;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _startOnIos(state, api);
      } else {
        await showAndroidCard(state);
      }
    } catch (e) {
      debugPrint('[TripActivity] sync failed: $e');
    }
  }

  /// ปิดการ์ดทั้งบนหน้าจอล็อกและบนแถบแจ้งเตือน
  Future<void> stop() async {
    _activeRef = null;

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _channel.invokeMethod('endAll');
      } else {
        await _localNotifications.cancel(id: androidNotificationId);
      }
    } catch (e) {
      debugPrint('[TripActivity] stop failed: $e');
    }
  }

  /// วาด/อัปเดตการ์ดบนแถบแจ้งเตือนของ Android
  ///
  /// เป็น static-ish โดยเจตนา (เรียกจาก background isolate ของ FCM ได้ด้วย ซึ่ง
  /// ที่นั่นไม่มี ApiClient และไม่มี state ของแอปให้พึ่ง)
  Future<void> showAndroidCard(TripActivityState state) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await PushNotificationService.instance.ensureLocalNotificationsReady();
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(androidChannel);

      final showProgress = state.progress > 0 && state.stage != 'countdown';

      await _localNotifications.show(
        id: androidNotificationId,
        title: state.headline,
        body: state.detail,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            androidChannel.id,
            androidChannel.name,
            channelDescription: androidChannel.description,
            importance: Importance.low,
            priority: Priority.low,
            // ปัดทิ้งไม่ได้ระหว่างทริป — เป็นการ์ดสถานะ ไม่ใช่ข้อความที่อ่านแล้วจบ
            ongoing: true,
            autoCancel: false,
            // ไม่ให้ระบบเด้ง/สั่นซ้ำทุกครั้งที่อัปเดตตัวเลข
            onlyAlertOnce: true,
            showProgress: showProgress,
            maxProgress: 100,
            progress: state.progressPercent,
            category: AndroidNotificationCategory.transport,
            styleInformation: BigTextStyleInformation(
              state.detail,
              contentTitle: state.headline,
              summaryText: state.tripTitle,
            ),
          ),
        ),
        payload: jsonEncode({
          'type': 'trip_activity',
          'booking_ref': state.bookingRef,
        }),
      );
    } catch (e) {
      debugPrint('[TripActivity] android card failed: $e');
    }
  }

  /// FCM data message ที่ถือ state มาให้ — ทางเดียวที่ Android ได้ข้อมูลใหม่
  /// ระหว่างที่ผู้ใช้ไม่ได้เปิดแอป
  Future<void> handleDataMessage(Map<String, dynamic> data) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    if (data['event']?.toString() == 'end') {
      _activeRef = null;
      await _localNotifications.cancel(id: androidNotificationId);
      return;
    }

    try {
      final raw = data['state'];
      final decoded = raw is String
          ? jsonDecode(raw)
          : (raw is Map ? raw : null);
      final state = TripActivityState.fromJson(
        decoded is Map ? Map<String, dynamic>.from(decoded) : null,
      );
      if (state == null) return;

      _activeRef = state.bookingRef;
      await showAndroidCard(state);
    } catch (e) {
      debugPrint('[TripActivity] data message failed: $e');
    }
  }

  // ── iOS ────────────────────────────────────────────────────────────────

  Future<void> _startOnIos(TripActivityState state, ApiClient api) async {
    final supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    if (!supported) return;

    final result = await _channel.invokeMapMethod<String, dynamic>('start', {
      'bookingRef': state.bookingRef,
      'tripTitle': state.tripTitle ?? 'ทริปของคุณ',
      'scheduleId': state.scheduleId,
      'state': state.toContentState(),
    });

    final token = result?['pushToken']?.toString();
    if (token != null && token.isNotEmpty) {
      await _registerToken(
        bookingRef: state.bookingRef,
        pushToken: token,
        activityId: result?['activityId']?.toString(),
      );
    }
  }

  /// token ของ Activity ออกมาหลัง `start` คืนค่าไปแล้วเสมอ (บางครั้งช้าเป็นวินาที)
  /// และเปลี่ยนได้ระหว่างทาง ฝั่ง Swift จึงยิงกลับมาทางนี้ทุกครั้งที่ได้ค่าใหม่
  void _attachHandler() {
    if (_handlerAttached) return;
    _handlerAttached = true;

    _channel.setMethodCallHandler((call) async {
      final args = call.arguments is Map
          ? Map<String, dynamic>.from(call.arguments as Map)
          : <String, dynamic>{};

      switch (call.method) {
        case 'onPushToken':
          await _registerToken(
            bookingRef: args['bookingRef']?.toString() ?? '',
            pushToken: args['pushToken']?.toString() ?? '',
            activityId: args['activityId']?.toString(),
          );
        case 'onStartToken':
          await PushNotificationService.instance.setLiveActivityStartToken(
            args['startToken']?.toString() ?? '',
          );
      }
      return null;
    });
  }

  Future<void> _registerToken({
    required String bookingRef,
    required String pushToken,
    String? activityId,
  }) async {
    final api = _api;
    if (api == null || bookingRef.isEmpty || pushToken.isEmpty) return;
    if (api.token == null || api.token!.isEmpty) return;

    try {
      await api.post(
        ApiEndpoints.liveActivities,
        body: {
          'booking_ref': bookingRef,
          'push_token': pushToken,
          'activity_id': ?activityId,
          'platform': 'ios',
        },
      );
    } catch (e) {
      debugPrint('[TripActivity] register token failed: $e');
    }
  }

  // ── การเลือกใบจอง ───────────────────────────────────────────────────────

  /// ใบจองที่ควรมีการ์ดอยู่ตอนนี้ — ตั้งแต่วันก่อนเดินทางถึงวันกลับ
  ///
  /// เกณฑ์ต้องกว้างกว่าฝั่งเซิร์ฟเวอร์เล็กน้อยโดยตั้งใจ: ที่นี่แค่คัดว่า "ควรถาม
  /// เซิร์ฟเวอร์เรื่องใบไหน" ส่วนคำตอบจริงว่าควรแสดงหรือไม่มาจาก state ที่ได้กลับมา
  Map<String, dynamic>? _dueBooking(List<dynamic> bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Map<String, dynamic>? best;
    DateTime? bestDeparture;

    for (final raw in bookings) {
      if (raw is! Map) continue;
      final booking = Map<String, dynamic>.from(raw);
      if (booking['status'] != 'confirmed') continue;

      final schedule = booking['schedule'];
      if (schedule is! Map) continue;

      final departure = DateTime.tryParse('${schedule['departure_date']}');
      if (departure == null) continue;
      final returnDate =
          DateTime.tryParse('${schedule['return_date']}') ?? departure;

      final start = DateTime(
        departure.year,
        departure.month,
        departure.day,
      ).subtract(const Duration(days: 1));
      final end = DateTime(returnDate.year, returnDate.month, returnDate.day);

      if (today.isBefore(start) || today.isAfter(end)) continue;

      // จองซ้อนกันหลายใบในช่วงเดียวกัน — เอาใบที่ออกเดินทางก่อน
      if (bestDeparture == null || departure.isBefore(bestDeparture)) {
        best = booking;
        bestDeparture = departure;
      }
    }

    return best;
  }
}
