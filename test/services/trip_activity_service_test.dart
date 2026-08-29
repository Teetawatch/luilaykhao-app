import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luilaykhao_app/services/api_client.dart';
import 'package:luilaykhao_app/services/trip_activity_service.dart';

/// การ์ด "วันเดินทาง" อัปเดตตัวเองผ่าน APNs ได้ก็ต่อเมื่อเซิร์ฟเวอร์ถือ push token
/// ของมันอยู่ การฝาก token จึงเป็นจุดเดียวที่ทั้งฟีเจอร์แขวนอยู่ — และเป็นจุดที่
/// ล้มได้ง่ายที่สุดด้วย เพราะมันเกิดตอนกดจองเสร็จ ซึ่งคนมักอยู่นอกบ้าน
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('luilaykhao/live_activity');

  late List<MethodCall> calls;
  late List<Map<String, dynamic>> activeTokens;

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls = [];
    activeTokens = [];

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'activeTokens') return activeTokens;
      if (call.method == 'isSupported') return true;
      if (call.method == 'start') {
        return {
          'activityId': 'activity-new',
          'pushToken': 'cafebabe',
          'bookingRef': 'LLK-20260810-0001',
        };
      }
      return null;
    });
  });

  tearDown(() async {
    // `stop()` ล้าง state ที่ค้างในซิงเกิลตัน ทำให้เทสต์ไม่ขึ้นต่อกันตามลำดับ
    await TripActivityService.instance.stop();
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  /// รัน [body] โดยให้ทุกคำขอ HTTP ตอบตามที่ [respond] บอก และคืนรายการ path
  /// ที่ถูกยิงจริง
  Future<List<String>> capture(
    Future<void> Function() body, {
    http.Response Function(http.Request request)? respond,
  }) async {
    final paths = <String>[];
    await http.runWithClient(body, () {
      return MockClient((request) async {
        paths.add(request.url.path);
        return respond?.call(request) ??
            http.Response('{"success":true,"data":{}}', 200);
      });
    });
    return paths;
  }

  ApiClient loggedIn() => ApiClient(token: 'test-token');

  test('ฝาก token ของการ์ดที่ยังเปิดค้างอยู่ตอนแอปกลับมาหน้าจอ', () async {
    activeTokens = [
      {
        'bookingRef': 'LLK-20260810-0001',
        'activityId': 'activity-1',
        'pushToken': 'deadbeef',
      },
    ];

    TripActivityService.instance.attachApi(loggedIn());

    final bodies = <Map<String, dynamic>>[];
    final paths = await capture(
      () => TripActivityService.instance.reregisterActiveTokens(),
      respond: (request) {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{"success":true,"data":{}}', 200);
      },
    );

    expect(paths.single, endsWith('live-activities'));
    expect(bodies.single['booking_ref'], 'LLK-20260810-0001');
    expect(bodies.single['push_token'], 'deadbeef');
    expect(bodies.single['activity_id'], 'activity-1');
  });

  test('ไม่ยิงซ้ำใบที่เซิร์ฟเวอร์รับไปแล้ว', () async {
    activeTokens = [
      {
        'bookingRef': 'LLK-20260810-0001',
        'activityId': 'activity-1',
        'pushToken': 'deadbeef',
      },
    ];

    TripActivityService.instance.attachApi(loggedIn());

    final first = await capture(
      () => TripActivityService.instance.reregisterActiveTokens(),
    );
    final second = await capture(
      () => TripActivityService.instance.reregisterActiveTokens(),
    );

    expect(first, hasLength(1));
    expect(second, isEmpty, reason: 'ฝากสำเร็จแล้วไม่ต้องฝากอีก');
  });

  test('ฝากไม่สำเร็จแล้วลองใหม่รอบหน้า — นี่คือทั้งหมดที่ทางนี้มีไว้ทำ', () async {
    activeTokens = [
      {
        'bookingRef': 'LLK-20260810-0001',
        'activityId': 'activity-1',
        'pushToken': 'deadbeef',
      },
    ];

    TripActivityService.instance.attachApi(loggedIn());

    // ครั้งแรกเน็ตหลุด (แบบเดียวกับตอนกดจองเสร็จแล้วสัญญาณหาย)
    final first = await capture(
      () => TripActivityService.instance.reregisterActiveTokens(),
      respond: (_) => http.Response('', 500),
    );
    final second = await capture(
      () => TripActivityService.instance.reregisterActiveTokens(),
    );

    expect(first, hasLength(1));
    expect(second, hasLength(1), reason: 'ครั้งก่อนล้มเหลว ต้องได้ลองใหม่');
  });

  test('การ์ดที่ token ยังไม่ออกถูกข้ามไปเงียบ ๆ', () async {
    // เคสปกติ ไม่ใช่เคสขอบ: token ยังไม่ออกตอน Activity.request() เพิ่งคืนค่า
    activeTokens = [
      {'bookingRef': 'LLK-20260810-0001', 'activityId': 'activity-1'},
    ];

    TripActivityService.instance.attachApi(loggedIn());

    final paths = await capture(
      () => TripActivityService.instance.reregisterActiveTokens(),
    );

    expect(paths, isEmpty);
  });

  /// รอบที่ "วันนี้อยู่กลางทริป" — ต้องคำนวณจากวันนี้จริง ไม่ใช่วันตายตัว ไม่งั้น
  /// เทสต์จะเขียวอยู่พักหนึ่งแล้วแดงเองโดยไม่มีใครแตะโค้ด
  List<Map<String, dynamic>> midTripBookings() {
    final today = DateTime.now();
    String day(int offset) =>
        today.add(Duration(days: offset)).toIso8601String().split('T').first;

    return [
      {
        'booking_ref': 'LLK-20260810-0001',
        'status': 'confirmed',
        'schedule': {'departure_date': day(0), 'return_date': day(1)},
      },
    ];
  }

  http.Response liveState(http.Request request) {
    if (!request.url.path.endsWith('live-activities')) {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'state': {
              'stage': 'itinerary',
              'headline': '10:00 น. · ถึงจุดชมวิวผาตั้ง',
              'detail': 'ถัดไปในกำหนดการ · ผ่านมาแล้ว 2 จาก 4 จุด',
              'progress': 0.5,
              'booking_ref': 'LLK-20260810-0001',
              'schedule_id': 7,
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{"success":true,"data":{}}', 200);
  }

  test('ระบบเก็บการ์ดไปกลางทริป — กลับเข้าแอปแล้วต้องได้ใบใหม่', () async {
    // iOS สั่งจบ Live Activity เองที่ราว 8 ชม. ทริปสองวันจึงมีช่วงที่ไม่มีการ์ด
    // ทั้งที่ยังอยู่กลางทาง ต่ออายุใบเดิมไม่ได้ แต่เปิดใบใหม่ได้
    activeTokens = [];
    TripActivityService.instance.attachApi(loggedIn());

    final paths = await capture(
      () => TripActivityService.instance.reregisterActiveTokens(
        bookings: midTripBookings(),
      ),
      respond: liveState,
    );

    expect(calls.map((c) => c.method), contains('start'));
    expect(paths.last, endsWith('live-activities'));
  });

  test('การ์ดที่ยังอยู่ไม่ถูกเปิดซ้อน', () async {
    activeTokens = [
      {
        'bookingRef': 'LLK-20260810-0001',
        'activityId': 'activity-1',
        'pushToken': 'deadbeef',
      },
    ];
    TripActivityService.instance.attachApi(loggedIn());

    await capture(
      () => TripActivityService.instance.reregisterActiveTokens(
        bookings: midTripBookings(),
      ),
      respond: liveState,
    );

    expect(calls.map((c) => c.method), isNot(contains('start')));
  });

  test('รายการจองยังโหลดไม่มา ห้ามไปยุ่งกับการ์ดที่มีอยู่', () async {
    // resume ตอนแอปเพิ่งตื่น รายการจองอาจยังว่าง ถ้าเผลอเดินต่อจะกลายเป็นสั่ง
    // ปิดการ์ดที่ดีอยู่แล้วทิ้ง
    activeTokens = [];
    TripActivityService.instance.attachApi(loggedIn());

    await capture(
      () => TripActivityService.instance.reregisterActiveTokens(),
      respond: liveState,
    );

    expect(calls.map((c) => c.method), ['activeTokens']);
  });

  test('ยังไม่ได้ล็อกอินก็ไม่ต้องถาม iOS ด้วยซ้ำ', () async {
    TripActivityService.instance.attachApi(ApiClient());

    final paths = await capture(
      () => TripActivityService.instance.reregisterActiveTokens(),
    );

    expect(paths, isEmpty);
    expect(calls.where((c) => c.method == 'activeTokens'), isEmpty);
  });

  test('บน Android ไม่แตะ channel นี้เลย', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TripActivityService.instance.attachApi(loggedIn());

    final paths = await capture(
      () => TripActivityService.instance.reregisterActiveTokens(),
    );

    expect(paths, isEmpty);
    expect(calls, isEmpty);
  });
}
