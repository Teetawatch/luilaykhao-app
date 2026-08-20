import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luilaykhao_app/services/api_client.dart';
import 'package:luilaykhao_app/services/home_widget_service.dart';

/// วิดเจ็ตหน้าโฮมอ่านแต่ไฟล์ที่แอปเขียนไว้ ไม่ได้ต่อเน็ตเอง ทางเดินสั้น ๆ นี้จึงเป็น
/// จุดเดียวที่ทั้งฟีเจอร์แขวนอยู่ — และเป็นจุดที่ความผิดพลาดเงียบที่สุด (เขียนไม่ลง
/// ก็ไม่มีใครรู้ เพราะบนจอยังมีการ์ดใบเก่าอยู่)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('luilaykhao/home_widget');

  late List<MethodCall> calls;

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls = [];
    HomeWidgetService.instance.resetForTest();

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
    HomeWidgetService.instance.resetForTest();
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  /// snapshot ที่เซิร์ฟเวอร์ตอบกลับมา — ตัวเลขไทยถูก escape เป็น \uXXXX เหมือน
  /// ที่ Laravel ทำจริง (`response()->json()`) เพราะ package:http ถอดรหัสเป็น latin1
  String body({int countdownDays = 17, String ref = 'LLK-1'}) => jsonEncode({
    'success': true,
    'data': {
      'version': 1,
      'generated_at': '2026-08-19T10:00:00+07:00',
      'trip': {
        'booking_ref': ref,
        'trip_title': 'เขาช้างเผือก',
        'departure_date': '2026-09-05',
        'valid_until': '2026-09-06',
        'date_label': '5 ก.ย. 2569',
        'depart_time': '05:30',
        'countdown_days': countdownDays,
        'headline': 'อีก $countdownDays วันออกเดินทาง',
        'detail': 'ปั๊ม ปตท. รังสิต',
        'stage': 'countdown',
        'eta_minutes': null,
        'progress': 0,
        'is_live': false,
      },
      'payment': null,
    },
  });

  ApiClient signedInClient() => ApiClient()..token = 'token-123';

  Future<List<String>> run(
    Future<void> Function() body_, {
    required String Function(http.Request request) respond,
  }) async {
    final paths = <String>[];
    await http.runWithClient(body_, () {
      return MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          respond(request),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
    });
    return paths;
  }

  test('ดึง snapshot มาแล้วส่งต่อให้ฝั่ง native เขียน', () async {
    HomeWidgetService.instance.attachApi(signedInClient());

    final paths = await run(
      () => HomeWidgetService.instance.refresh(),
      respond: (_) => body(),
    );

    expect(paths.single, endsWith('/me/home-widget'));
    expect(calls.single.method, 'save');

    final payload =
        jsonDecode((calls.single.arguments as Map)['json'] as String) as Map;
    expect(payload['version'], 1);
    expect(payload['trip']['booking_ref'], 'LLK-1');
    // ภาษาไทยต้องรอดมาถึงฝั่ง native ครบ ไม่ใช่กลายเป็นตัวอักษรเพี้ยน
    expect(payload['trip']['trip_title'], 'เขาช้างเผือก');
    expect(payload['trip']['countdown_days'], 17);
  });

  test(
    'ข้อมูลเดิมไม่ถูกเขียนซ้ำ — iOS จำกัดจำนวนครั้งที่วิดเจ็ตวาดใหม่ต่อวัน',
    () async {
      HomeWidgetService.instance.attachApi(signedInClient());

      await run(() async {
        await HomeWidgetService.instance.refresh();
        await HomeWidgetService.instance.refresh(force: true);
      }, respond: (_) => body());

      expect(calls.where((c) => c.method == 'save').length, 1);
    },
  );

  test('ข้อมูลที่เปลี่ยนแล้วถูกเขียนใหม่', () async {
    HomeWidgetService.instance.attachApi(signedInClient());

    var days = 17;
    await run(() async {
      await HomeWidgetService.instance.refresh();
      days = 16;
      await HomeWidgetService.instance.refresh(force: true);
    }, respond: (_) => body(countdownDays: days));

    expect(calls.where((c) => c.method == 'save').length, 2);
  });

  test('การสลับแอปไปมาไม่ทำให้ยิงซ้ำ แต่ force ยิงได้', () async {
    HomeWidgetService.instance.attachApi(signedInClient());

    final paths = await run(() async {
      await HomeWidgetService.instance.refresh();
      await HomeWidgetService.instance.refresh();
      await HomeWidgetService.instance.refresh();
    }, respond: (_) => body());

    expect(paths.length, 1);
  });

  test('ยังไม่ได้ผูก ApiClient = ไม่แตะวิดเจ็ตเลย ไม่ใช่ล้างทิ้ง', () async {
    // เคสนี้คือ entry point ที่วิ่งมาก่อน AppProvider ตั้งตัวเสร็จ ถ้าเผลอล้าง
    // ทริปจะหายจากหน้าโฮมโดยที่ผู้ใช้ไม่ได้ทำอะไร
    await HomeWidgetService.instance.refresh();

    expect(calls, isEmpty);
  });

  test(
    'ออกจากระบบแล้ววิดเจ็ตต้องถูกล้าง — ทริปของคนก่อนไม่ค้างบนหน้าโฮม',
    () async {
      HomeWidgetService.instance.attachApi(ApiClient());

      await HomeWidgetService.instance.refresh();

      expect(calls.single.method, 'clear');
    },
  );

  test(
    'clear() ล้างความจำด้วย ครั้งหน้าจึงเขียนใหม่ได้แม้ข้อมูลเหมือนเดิม',
    () async {
      HomeWidgetService.instance.attachApi(signedInClient());

      await run(() async {
        await HomeWidgetService.instance.refresh();
        await HomeWidgetService.instance.clear();
        await HomeWidgetService.instance.refresh(force: true);
      }, respond: (_) => body());

      expect(calls.map((c) => c.method).toList(), ['save', 'clear', 'save']);
    },
  );

  test('เซิร์ฟเวอร์ล่มแล้วของเดิมบนหน้าโฮมต้องอยู่ต่อ ไม่ถูกล้าง', () async {
    HomeWidgetService.instance.attachApi(signedInClient());

    await http.runWithClient(
      () => HomeWidgetService.instance.refresh(),
      // Laravel escape ภาษาไทยเป็น \uXXXX จริง ๆ — เขียน byte ไทยตรง ๆ ที่นี่
      // http.Response จะโยน "Invalid argument (string)" ซึ่งไม่ใช่สิ่งที่ทดสอบ
      () => MockClient(
        (_) async => http.Response(r'{"message":"\u0e1e\u0e31\u0e07"}', 500),
      ),
    );

    expect(calls, isEmpty);
  });

  test('บนแพลตฟอร์มที่ไม่มีวิดเจ็ตไม่ยิงอะไรเลย', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    HomeWidgetService.instance.attachApi(signedInClient());

    await HomeWidgetService.instance.refresh(force: true);

    expect(calls, isEmpty);
  });
}
