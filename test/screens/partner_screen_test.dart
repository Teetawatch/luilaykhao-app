import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/partner_screen.dart';
import 'package:luilaykhao_app/services/partner_ref_store.dart';
import 'package:luilaykhao_app/widgets/partner_code_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// พาร์ทเนอร์ช่วยขาย — หน้ายอดคอมของพาร์ทเนอร์ และช่องรหัสผู้แนะนำในการจอง
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  http.Response ok(Object? data, {Map<String, dynamic>? meta}) => http.Response(
    jsonEncode({
      'success': true,
      'data': data,
      'message': 'สำเร็จ',
      'meta': ?meta,
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, dynamic> partner({Map<String, dynamic>? account}) => {
    'id': 1,
    'code': 'PAGEPA',
    'display_name': 'เพจเที่ยวป่า',
    'status': 'active',
    'rate_label': '10%',
    'share_url': 'https://luilaykhao.com/?partner=PAGEPA',
    'liff_url': null,
    'payout_account': account,
    'summary': {
      'pending': 400,
      'approved': 1250.5,
      'paid': 3000,
      'bookings': 6,
      'seats': 11,
    },
    'recent_commissions': [],
    'rules': ['ลูกค้าจ่ายเงินเข้าบริษัทโดยตรงเสมอ คุณไม่ต้องรับเงินแทน'],
  };

  final rows = [
    {
      'id': 9,
      'booking_ref': 'LLK-20261101-0001',
      'trip_title': 'ภูกระดึง 3 วัน 2 คืน',
      'departure_date': '2026-11-01',
      'type': 'commission',
      'status': 'approved',
      'seats': 2,
      'amount': 400,
      'void_reason': null,
    },
    {
      'id': 10,
      'booking_ref': 'LLK-20261001-0002',
      'trip_title': 'ดอยหลวง',
      'departure_date': '2026-10-01',
      'type': 'clawback',
      'status': 'approved',
      'seats': 0,
      'amount': -200,
      'void_reason': 'คืนเงินการจอง หลังจ่ายคอมแล้ว',
    },
  ];

  Future<List<http.Request>> pump(
    WidgetTester tester,
    Widget home,
    Future<http.Response> Function(http.Request) handler, {
    Future<void> Function()? then,
  }) async {
    tester.view.physicalSize = const Size(430 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final requests = <http.Request>[];
    final app = AppProvider();
    app.api.token = 'test-token';

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: app,
            child: MaterialApp(home: Scaffold(body: home)),
          ),
        );
        await tester.pumpAndSettle();
        if (then != null) await then();
      },
      () => MockClient((r) {
        requests.add(r);
        return handler(r);
      }),
    );
    return requests;
  }

  testWidgets('พาร์ทเนอร์เห็นโค้ด ยอดสามช่อง และคอมรายใบรวมยอดหักคืน', (
    tester,
  ) async {
    await pump(tester, const PartnerScreen(), (r) async {
      if (r.url.path.endsWith('/partner/commissions')) {
        return ok(rows, meta: {'current_page': 1, 'last_page': 1});
      }
      return ok(partner());
    });

    expect(tester.takeException(), isNull);
    expect(find.text('PAGEPA'), findsOneWidget);
    expect(find.text('โค้ดพาร์ทเนอร์ของคุณ · คอม 10%'), findsOneWidget);
    expect(find.text('฿400'), findsWidgets);
    expect(find.text('฿1,250.50'), findsOneWidget);
    expect(find.text('฿3,000'), findsOneWidget);
    expect(find.text('ขายได้ 6 ใบจอง · 11 ที่นั่ง'), findsOneWidget);
    expect(find.text('ภูกระดึง 3 วัน 2 คืน'), findsOneWidget);
    expect(find.text('-฿200'), findsOneWidget);
    expect(find.text('หักคืน'), findsOneWidget);
    // ยังไม่มีบัญชีรับเงิน → ชวนให้ใส่
    expect(
      find.text('ยังไม่ได้ใส่ — ใส่ไว้เพื่อให้ทีมงานโอนได้'),
      findsOneWidget,
    );
  });

  testWidgets('กรองสถานะแล้วขอรายการใหม่ด้วย status', (tester) async {
    final requests = await pump(
      tester,
      const PartnerScreen(),
      (r) async {
        if (r.url.path.endsWith('/partner/commissions')) {
          return ok(
            r.url.queryParameters['status'] == 'paid' ? [] : rows,
            meta: {'current_page': 1, 'last_page': 1},
          );
        }
        return ok(partner());
      },
      then: () async {
        final chip = find.widgetWithText(ChoiceChip, 'โอนแล้ว');
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
      },
    );

    expect(
      requests.last.url.queryParameters['status'],
      'paid',
      reason: 'ต้องส่ง status ไปกับคำขอ',
    );
    expect(find.text('ยังไม่มีรายการ'), findsOneWidget);
  });

  testWidgets('บัญชีที่ไม่ใช่พาร์ทเนอร์ เห็นคำแนะนำให้ติดต่อทีมงาน', (
    tester,
  ) async {
    final requests = await pump(
      tester,
      const PartnerScreen(),
      (r) async => ok(null),
    );

    expect(find.text('บัญชีนี้ยังไม่ได้เป็นพาร์ทเนอร์'), findsOneWidget);
    expect(
      requests.where((r) => r.url.path.endsWith('/partner/commissions')),
      isEmpty,
    );
  });

  testWidgets('ใส่บัญชีรับเงินผ่านแผ่นล่าง แล้วการ์ดโชว์เลขที่ปิดไว้', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    await pump(
      tester,
      const PartnerScreen(),
      (r) async {
        if (r.method == 'PUT') {
          sent = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
          return ok({
            'payout_account': {
              'bank': 'กสิกรไทย',
              'number_masked': 'xxx-7890',
              'name': 'เพจเที่ยวป่า',
            },
          });
        }
        if (r.url.path.endsWith('/partner/commissions')) {
          return ok([], meta: {'current_page': 1, 'last_page': 1});
        }
        return ok(partner());
      },
      then: () async {
        await tester.tap(find.widgetWithText(TextButton, 'ใส่บัญชี'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'กสิกรไทย');
        await tester.enterText(fields.at(1), '123-4-56789-0');
        await tester.enterText(fields.at(2), 'เพจเที่ยวป่า');
        await tester.tap(find.text('บันทึก'));
        await tester.pumpAndSettle();
      },
    );

    expect(sent?['number'], '123-4-56789-0');
    expect(find.text('กสิกรไทย xxx-7890 · เพจเที่ยวป่า'), findsOneWidget);
  });

  testWidgets(
    'ช่องรหัสผู้แนะนำ: โค้ดจากลิงก์ขึ้นชื่อพาร์ทเนอร์และส่งต่อให้การจอง',
    (tester) async {
      await PartnerRefStore.remember('pagepa');
      PartnerRef? current;

      await pump(
        tester,
        PartnerCodeTile(onChanged: (ref) => current = ref),
        (r) async => ok({
          'valid': true,
          'code': 'PAGEPA',
          'display_name': 'เพจเที่ยวป่า',
        }),
      );

      expect(find.text('แนะนำโดย เพจเที่ยวป่า'), findsOneWidget);
      expect(current?.code, 'PAGEPA');
      expect(current?.source, 'link');

      await tester.tap(find.text('เอาออก'));
      await tester.pumpAndSettle();
      expect(current, isNull);
      expect(await PartnerRefStore.read(), isNull);
    },
  );

  testWidgets(
    'ช่องรหัสผู้แนะนำ: พิมพ์รหัสผิดเห็นข้อความ พิมพ์ถูกจำไว้เป็น code',
    (tester) async {
      PartnerRef? current;

      await pump(
        tester,
        PartnerCodeTile(onChanged: (ref) => current = ref),
        (r) async => r.url.queryParameters['code'] == 'NOPE'
            ? ok({'valid': false, 'code': 'NOPE'})
            : ok({
                'valid': true,
                'code': 'PAGEPA',
                'display_name': 'เพจเที่ยวป่า',
              }),
        then: () async {
          await tester.tap(find.text('มีรหัสผู้แนะนำ/พาร์ทเนอร์?'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'nope');
          await tester.tap(find.text('ตรวจสอบ'));
          await tester.pumpAndSettle();
          expect(
            find.text('ไม่พบรหัสนี้ ลองตรวจตัวสะกดอีกครั้ง'),
            findsOneWidget,
          );

          await tester.enterText(find.byType(TextField), 'pagepa');
          await tester.tap(find.text('ตรวจสอบ'));
          await tester.pumpAndSettle();
        },
      );

      expect(find.text('แนะนำโดย เพจเที่ยวป่า'), findsOneWidget);
      expect(current?.source, 'code');
      expect((await PartnerRefStore.read())?.code, 'PAGEPA');
    },
  );
}
