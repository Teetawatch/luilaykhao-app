import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/providers/wishlist_provider.dart';
import 'package:luilaykhao_app/screens/customer_app_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// แถบ "ตัวกรองที่ใช้อยู่" ในหน้าทริปทั้งหมด — บอกว่ากำลังกรองอะไร เอาออก
/// ทีละอันได้ และล้างทั้งหมดแล้วกดเลิกทำได้
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  MockClient client() => MockClient((request) async {
    final body = request.url.path.endsWith('/trips')
        ? {
            'success': true,
            'data': [
              {
                'id': 1,
                'slug': 'phu-kradueng',
                'title': 'ภูกระดึง',
                'location': 'เลย',
                'duration_days': 2,
                'price_per_person': 3500,
                'type': 'trekking',
              },
            ],
            'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
          }
        : {'success': true, 'data': const []};
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  Future<void> openScreen(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      final provider = AppProvider()
        ..categories = [
          {'slug': 'trekking', 'name': 'เดินป่า', 'icon': 'hiking'},
          {'slug': 'diving', 'name': 'ดำน้ำ', 'icon': 'scuba'},
        ];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: provider),
            ChangeNotifierProvider(create: (_) => WishlistProvider()),
          ],
          child: const MaterialApp(home: AllTripsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await body();
    }, client);
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).first);
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  Finder activeChip(String label) =>
      find.bySemanticsLabel('เอาตัวกรอง $label ออก');

  testWidgets('ยังไม่ได้กรองอะไร = ไม่มีแถบสรุป', (tester) async {
    await openScreen(tester, () async {
      expect(find.text('ตัวกรองที่ใช้อยู่'), findsNothing);
      expect(find.text('ล้างทั้งหมด'), findsNothing);
    });
  });

  testWidgets('แถบบอกทุกตัวกรองที่ใช้อยู่ พร้อมจำนวน', (tester) async {
    await openScreen(tester, () async {
      await search(tester, 'ภูกระดึง');
      await tapChip(tester, 'เดินป่า');

      expect(find.text('ตัวกรองที่ใช้อยู่'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(activeChip('“ภูกระดึง”'), findsOneWidget);
      expect(activeChip('เดินป่า'), findsOneWidget);
    });
  });

  testWidgets('กดชิปเอาออกได้ทีละอัน ที่เหลือยังอยู่', (tester) async {
    await openScreen(tester, () async {
      await search(tester, 'ภูกระดึง');
      await tapChip(tester, 'เดินป่า');

      await tester.tap(activeChip('“ภูกระดึง”'));
      await tester.pumpAndSettle();

      expect(activeChip('“ภูกระดึง”'), findsNothing);
      expect(activeChip('เดินป่า'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      // ช่องค้นหาถูกล้างตามไปด้วย
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      await tester.tap(activeChip('เดินป่า'));
      await tester.pumpAndSettle();
      expect(find.text('ตัวกรองที่ใช้อยู่'), findsNothing);
    });
  });

  testWidgets('ล้างทั้งหมดแล้วกด "เลิกทำ" ได้ตัวกรองเดิมคืนมาครบ', (
    tester,
  ) async {
    await openScreen(tester, () async {
      await search(tester, 'ภูกระดึง');
      await tapChip(tester, 'เดินป่า');

      await tester.tap(find.text('ล้างทั้งหมด'));
      await tester.pump();
      expect(find.text('ตัวกรองที่ใช้อยู่'), findsNothing);
      expect(find.text('ล้างตัวกรอง 2 รายการแล้ว'), findsOneWidget);

      // รอ snackbar เลื่อนขึ้นมาจนสุดก่อนกด
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('เลิกทำ'));
      await tester.pumpAndSettle();
      expect(find.text('ตัวกรองที่ใช้อยู่'), findsOneWidget);
      expect(activeChip('“ภูกระดึง”'), findsOneWidget);
      expect(activeChip('เดินป่า'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'ภูกระดึง',
      );
    });
  });

  testWidgets('แจ้ง "ล้างตัวกรองแล้ว" หายไปเองตามเวลา ไม่ค้างรอให้กดเลิกทำ', (
    tester,
  ) async {
    await openScreen(tester, () async {
      await search(tester, 'ภูกระดึง');

      await tester.tap(find.text('ล้างทั้งหมด'));
      await tester.pump();
      expect(find.text('ล้างตัวกรอง 1 รายการแล้ว'), findsOneWidget);

      // Flutter ให้ snackbar ที่มีปุ่มค้างตลอดถ้าไม่ตั้ง persist: false
      // นาฬิกาเริ่มนับหลัง snackbar เลื่อนขึ้นจนสุด แล้วนับ 3 วินาที
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('ล้างตัวกรอง 1 รายการแล้ว'), findsNothing);
    });
  });
}
