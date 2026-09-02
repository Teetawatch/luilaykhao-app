import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/customer_app_screen.dart';
import 'package:luilaykhao_app/services/search_history_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// แถบ "ค้นหาล่าสุด" ในหน้าทริปทั้งหมด
///
/// สิ่งที่ต้องถูกคือ *อะไรถึงจะได้ลงประวัติ* — คำที่ผู้ใช้ตั้งใจค้นและเจอทริป
/// จริงเท่านั้น ไม่ใช่ทุกตัวอักษรที่พิมพ์ผ่านหรือคำที่ค้นแล้วว่างเปล่า
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Map<String, dynamic> trip(String title) => {
    'id': 1,
    'slug': 'phu-kradueng',
    'title': title,
    'location': 'เลย',
    'duration_days': 2,
    'price_per_person': 3500,
    'type': 'trekking',
  };

  /// ยิงอะไรก็ตอบตามเส้นทาง — รายการทริปคือของที่เทสต์นี้สนใจ ที่เหลือคืนว่าง
  MockClient client(List<Map<String, dynamic>> trips) {
    return MockClient((request) async {
      final path = request.url.path;
      final body = path.endsWith('/trips')
          ? {
              'success': true,
              'data': trips,
              'meta': {
                'current_page': 1,
                'last_page': 1,
                'total': trips.length,
              },
            }
          : {'success': true, 'data': const []};

      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

  /// เปิดหน้าทริปทั้งหมดแล้วรัน [body] *ในโซนเดียวกัน* — การกดค้นหลังจากนี้
  /// ยิง API อีกรอบเสมอ ถ้า body อยู่นอก runWithClient มันจะหลุดไปยิงเน็ตจริง
  Future<void> openScreen(
    WidgetTester tester, {
    List<String> history = const [],
    List<Map<String, dynamic>>? trips,
    String? initialSearch,
    Future<void> Function()? body,
  }) async {
    // เรียงจากเก่าไปใหม่ ประวัติที่ได้จึงเรียงตามลำดับที่ส่งเข้ามา
    for (final query in history.reversed) {
      await SearchHistoryService.instance.add(query);
    }

    await http.runWithClient(
      () async {
        final provider = AppProvider();
        provider.api.token = 'test-token';

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: MaterialApp(
              home: AllTripsScreen(initialSearch: initialSearch),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (body != null) await body();
      },
      () => client(trips ?? [trip('ภูกระดึง')]),
    );
  }

  Future<void> submit(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('มีประวัติแล้วช่องค้นหายังว่าง จึงเห็นชิปคำค้นล่าสุด', (
    tester,
  ) async {
    await openScreen(tester, history: ['โดดดอย', 'เกาะเต่า']);

    expect(tester.takeException(), isNull);
    expect(find.text('ค้นหาล่าสุด'), findsOneWidget);
    expect(find.text('โดดดอย'), findsOneWidget);
    expect(find.text('เกาะเต่า'), findsOneWidget);
    expect(find.text('ล้างประวัติ'), findsOneWidget);
  });

  testWidgets('ยังไม่เคยค้น ก็ไม่มีแถบมากินที่', (tester) async {
    await openScreen(tester);

    expect(find.text('ค้นหาล่าสุด'), findsNothing);
    expect(find.text('ล้างประวัติ'), findsNothing);
  });

  testWidgets('มีคำค้นอยู่ในช่อง แถบประวัติต้องหลบให้ผลลัพธ์', (tester) async {
    await openScreen(tester, history: ['โดดดอย'], initialSearch: 'ภูกระดึง');

    expect(find.text('ค้นหาล่าสุด'), findsNothing);
  });

  testWidgets('แตะชิปแล้วเติมคำลงช่องค้นหาและค้นให้ทันที', (tester) async {
    await openScreen(
      tester,
      history: ['โดดดอย'],
      body: () async {
        await tester.tap(find.text('โดดดอย'));
        await tester.pumpAndSettle();

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller?.text, 'โดดดอย');
        // ช่องมีคำแล้ว แถบประวัติจึงหุบไป
        expect(find.text('ค้นหาล่าสุด'), findsNothing);
        // ค้นซ้ำแล้วยังอยู่ในประวัติ ไม่ถูกเบิ้ลเป็นสองบรรทัด
        expect(await SearchHistoryService.instance.read(), ['โดดดอย']);
      },
    );
  });

  testWidgets('กดค้นแล้วเจอทริป คำนั้นถึงจะถูกจำ', (tester) async {
    await openScreen(
      tester,
      body: () async {
        await submit(tester, 'ภูกระดึง');
        expect(await SearchHistoryService.instance.read(), ['ภูกระดึง']);
      },
    );
  });

  testWidgets('พิมพ์ทิ้งไว้เฉย ๆ ไม่ได้กดค้น จะไม่ถูกจำ', (tester) async {
    await openScreen(
      tester,
      body: () async {
        // ปล่อยให้ debounce ยิงเอง — ผลขึ้นแล้วแต่ยังไม่นับว่าผู้ใช้ตั้งใจค้น
        await tester.enterText(find.byType(TextField), 'ภูก');
        await tester.pumpAndSettle();

        expect(await SearchHistoryService.instance.read(), isEmpty);
      },
    );
  });

  testWidgets('ค้นแล้วไม่เจอทริปสักรอบ ไม่ต้องจำ', (tester) async {
    await openScreen(
      tester,
      trips: const [],
      body: () async {
        await submit(tester, 'ไม่มีทริปนี้');
        expect(await SearchHistoryService.instance.read(), isEmpty);
      },
    );
  });

  testWidgets('คำที่ค้นมาจากหน้าแรกก็ถูกจำเหมือนกัน', (tester) async {
    await openScreen(tester, initialSearch: 'ภูกระดึง');

    expect(await SearchHistoryService.instance.read(), ['ภูกระดึง']);
  });

  testWidgets('ล้างคำค้นแล้วแถบประวัติกลับมา พร้อมคำที่เพิ่งค้น', (
    tester,
  ) async {
    await openScreen(
      tester,
      body: () async {
        await submit(tester, 'ภูกระดึง');
        await tester.tap(find.byTooltip('ล้างคำค้นหา'));
        await tester.pumpAndSettle();

        expect(find.text('ค้นหาล่าสุด'), findsOneWidget);
        expect(find.text('ภูกระดึง'), findsWidgets);
      },
    );
  });

  testWidgets('กากบาทบนชิปลบเฉพาะคำนั้นออกจากประวัติ', (tester) async {
    await openScreen(
      tester,
      history: ['โดดดอย', 'เกาะเต่า'],
      body: () async {
        await tester.tap(
          find.bySemanticsLabel('ลบ โดดดอย ออกจากประวัติการค้นหา'),
        );
        await tester.pumpAndSettle();

        expect(await SearchHistoryService.instance.read(), ['เกาะเต่า']);
        expect(find.text('โดดดอย'), findsNothing);
        expect(find.text('เกาะเต่า'), findsOneWidget);
      },
    );
  });

  testWidgets('ล้างประวัติแล้วแถบหายไปทั้งแถบ', (tester) async {
    await openScreen(
      tester,
      history: ['โดดดอย', 'เกาะเต่า'],
      body: () async {
        await tester.tap(find.text('ล้างประวัติ'));
        await tester.pumpAndSettle();

        expect(await SearchHistoryService.instance.read(), isEmpty);
        expect(find.text('ค้นหาล่าสุด'), findsNothing);
      },
    );
  });
}
