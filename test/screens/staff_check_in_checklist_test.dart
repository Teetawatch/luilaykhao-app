import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/staff_check_in_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// หน้าเช็คอินของสตาฟ — เช็คอินรายคน
///
/// ใบจอง 4 คนที่มาจริง 3 คน: สแกน QR ของใบจองแล้วต้องติ๊กได้ว่าใครมา และสิ่งที่
/// ส่งไปเซิร์ฟเวอร์ต้องเป็นเฉพาะคนที่ติ๊ก ไม่ใช่ทั้งใบเหมือนเดิม
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, dynamic> person(
    int id,
    String name, {
    bool aboard = false,
    bool notGoing = false,
  }) => {
    'id': id,
    'title': '',
    'name': name,
    'nickname': name,
    'display_name': name,
    'checked_in': aboard,
    'checked_in_at': aboard ? '2026-10-10T00:10:00Z' : null,
    'not_going': notGoing,
  };

  Map<String, dynamic> booking() => {
    'booking_ref': 'LLK-REF-0001',
    'status': 'confirmed',
    'checked_in': false,
    'passengers': [
      {'id': 11, 'name': 'เอ'},
      {'id': 12, 'name': 'บี'},
      {'id': 13, 'name': 'ซี'},
    ],
    'schedule': {
      'departure_date': '2026-10-11',
      'trip': {'title': 'ภูกระดึง'},
    },
  };

  Future<List<Map<String, dynamic>>> runFlow(
    WidgetTester tester, {
    required Map<String, dynamic> lookupMeta,
    required Future<void> Function() interact,
  }) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = AppProvider();
    provider.api.token = 'test-token';
    provider.user = {
      'id': 1,
      'roles': ['staff'],
    };

    final sent = <Map<String, dynamic>>[];

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: const MaterialApp(home: StaffCheckInScreen()),
          ),
        );
        await tester.enterText(find.byType(TextField), 'QR-GROUP');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        await interact();
      },
      () => MockClient((request) async {
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        final isConfirm = request.url.path.endsWith('/staff/check-in/confirm');
        if (isConfirm) sent.add(body);
        return http.Response(
          jsonEncode({
            'success': true,
            'message': isConfirm
                ? 'เช็คอินสำเร็จ 2 คน (ใบนี้ขึ้นรถแล้ว 2/3)'
                : 'พบข้อมูลการจอง',
            'data': booking(),
            'meta': isConfirm
                ? {
                    'can_check_in': true,
                    'passengers': [
                      person(11, 'เอ', aboard: true),
                      person(12, 'บี', aboard: true),
                      person(13, 'ซี'),
                    ],
                  }
                : lookupMeta,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    return sent;
  }

  testWidgets(
    'สแกน QR ใบจอง — ติ๊กทุกคนที่รอไว้ให้ เอาออกได้ แล้วส่งเฉพาะคนที่ติ๊ก',
    (tester) async {
      final sent = await runFlow(
        tester,
        lookupMeta: {
          'can_check_in': true,
          'scanned_passenger_id': null,
          'passengers': [person(11, 'เอ'), person(12, 'บี'), person(13, 'ซี')],
        },
        interact: () async {
          expect(find.text('ใครมาถึงแล้วบ้าง'), findsOneWidget);
          expect(find.text('เช็คอิน 3 คน'), findsOneWidget);

          // ซีไม่มา — เอาติ๊กออก
          // ชื่อซ้ำกับการ์ดผู้เดินทางด้านล่าง — รายการติ๊กอยู่บนสุด
          await tester.tap(find.text('ซี').first);
          await tester.pump();
          expect(find.text('เช็คอิน 2 คน'), findsOneWidget);

          await tester.tap(find.text('เช็คอิน 2 คน'));
          await tester.pumpAndSettle();
        },
      );

      expect(tester.takeException(), isNull);
      expect(sent, hasLength(1));
      expect(sent.single['passenger_ids'], [11, 12]);
      expect(find.text('ขึ้นรถ 2/3'), findsOneWidget);
    },
  );

  testWidgets(
    'คนที่แจ้งไม่ไปไม่ถูกติ๊กให้ และไม่มีใครถูกเลือก = กดเช็คอินไม่ได้',
    (tester) async {
      final sent = await runFlow(
        tester,
        lookupMeta: {
          'can_check_in': true,
          'passengers': [
            person(11, 'เอ', aboard: true),
            person(12, 'บี', notGoing: true),
          ],
        },
        interact: () async {
          expect(find.textContaining('แจ้งไว้ว่าไม่ไป'), findsOneWidget);
          expect(find.text('เลือกคนที่มาถึงก่อน'), findsOneWidget);
          await tester.tap(find.text('เลือกคนที่มาถึงก่อน'));
          await tester.pumpAndSettle();
        },
      );

      expect(sent, isEmpty);
    },
  );

  testWidgets('สแกนบัตรรายคน — ติ๊กไว้แค่เจ้าของบัตร', (tester) async {
    final sent = await runFlow(
      tester,
      lookupMeta: {
        'can_check_in': true,
        'scanned_passenger_id': 12,
        'passengers': [person(11, 'เอ'), person(12, 'บี'), person(13, 'ซี')],
      },
      interact: () async {
        expect(find.text('เจ้าของบัตรที่สแกน'), findsOneWidget);
        expect(find.text('เช็คอิน 1 คน'), findsOneWidget);
        await tester.tap(find.text('เช็คอิน 1 คน'));
        await tester.pumpAndSettle();
      },
    );

    expect(sent.single['passenger_ids'], [12]);
  });
}
