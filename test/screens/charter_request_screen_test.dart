import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/charter_request_screen.dart';
import 'package:provider/provider.dart';

/// เหมาทริป — ฟอร์มขอ / ใบเสนอราคา / ปุ่มหลังเปิดการจอง
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  http.Response ok(Object data, {String message = 'สำเร็จ'}) => http.Response(
    jsonEncode({'success': true, 'data': data, 'message': message}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, dynamic> request({
    String status = 'quoted',
    bool canAccept = true,
    bool expired = false,
    String? bookingRef,
    String? bookingStatus,
  }) => {
    'id': 7,
    'ref': 'CH-261007-ABCD',
    'status': status,
    'destination_label': 'ภูกระดึง 3 วัน 2 คืน',
    'preferred_date': '2099-03-10',
    'alternate_date': null,
    'flexible_dates': true,
    'group_size': 20,
    'group_type_label': 'บริษัท / องค์กร',
    'pickup_area': 'สีลม',
    'budget_per_person': 3000,
    'needs_tax_invoice': true,
    'contact_name': 'คุณสมศรี',
    'contact_phone': '0812345678',
    'note': 'ทริปพนักงาน',
    'quote': {
      'trip': {'id': 1, 'title': 'ภูกระดึง 3 วัน 2 คืน'},
      'departure_date': '2099-03-10',
      'return_date': '2099-03-12',
      'group_size': 20,
      'price_per_person': 3200,
      'total': 64000,
      'includes': 'รถตู้ VIP\nที่พัก 2 คืน',
      'note': 'ราคาพิเศษ',
      'valid_until': '2099-01-01',
      'expired': expired,
    },
    'can_accept': canAccept && !expired,
    'can_decline': status == 'quoted',
    'can_cancel': ['new', 'quoted', 'declined'].contains(status),
    'booking_ref': bookingRef,
    'booking_status': bookingStatus,
  };

  Future<List<http.Request>> pump(
    WidgetTester tester,
    Widget home,
    Future<http.Response> Function(http.Request) handler, {
    Future<void> Function()? then,
  }) async {
    final requests = <http.Request>[];
    final app = AppProvider();
    app.api.token = 'test-token';
    app.user = {'name': 'สมศรี ใจดี', 'phone': '0812345678'};

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: app,
            child: MaterialApp(home: home),
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

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ใบเสนอราคาโชว์ยอดรวมและรายการที่รวม ตอบรับแล้วยิง accept', (
    tester,
  ) async {
    var accepted = false;
    final requests = await pump(
      tester,
      const CharterRequestDetailScreen(requestId: 7),
      (r) async {
        if (r.url.path.endsWith('/accept')) {
          accepted = true;
          return ok(request(status: 'accepted', canAccept: false));
        }
        return ok(request());
      },
      then: () async {
        expect(find.text('฿64,000'), findsOneWidget);
        expect(find.text('ท่านละ ฿3,200'), findsOneWidget);
        expect(find.text('รถตู้ VIP'), findsOneWidget);
        await scrollTo(tester, find.text('ตอบรับใบเสนอราคา'));
        await tester.tap(find.text('ตอบรับใบเสนอราคา'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'ตอบรับ'));
        await tester.pumpAndSettle();
      },
    );

    expect(tester.takeException(), isNull);
    expect(accepted, isTrue);
    expect(requests.last.url.path, endsWith('/charter-requests/7/accept'));
    expect(
      find.text('ตอบรับแล้ว ทีมงานจะเปิดการจองให้เร็ว ๆ นี้'),
      findsOneWidget,
    );
    // ปุ่มตอบรับหายไปหลังตอบรับ
    expect(find.text('ตอบรับใบเสนอราคา', skipOffstage: false), findsNothing);
  });

  testWidgets('ใบเสนอราคาหมดอายุ — ไม่มีปุ่มตอบรับ', (tester) async {
    await pump(
      tester,
      const CharterRequestDetailScreen(requestId: 7),
      (r) async => ok(request(expired: true)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('ตอบรับใบเสนอราคา'), findsNothing);
    expect(find.textContaining('หมดอายุ'), findsWidgets);
  });

  testWidgets('เปิดการจองแล้วและยังไม่จ่าย — ปุ่มพาไปชำระเงิน', (tester) async {
    await pump(
      tester,
      const CharterRequestDetailScreen(requestId: 7),
      (r) async => ok(
        request(
          status: 'booked',
          canAccept: false,
          bookingRef: 'LLK-20990310-0001',
          bookingStatus: 'pending',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('ชำระเงิน LLK-20990310-0001'), findsOneWidget);
    expect(find.text('ยกเลิกคำขอ'), findsNothing);
  });

  testWidgets('ฟอร์ม: กลุ่มน้อยกว่า 4 คนไม่ผ่าน ไม่ส่งอะไรออกไป', (
    tester,
  ) async {
    final requests = await pump(
      tester,
      const CharterRequestFormScreen(
        trip: {'id': 1, 'title': 'ภูกระดึง 3 วัน 2 คืน'},
      ),
      (r) async => ok(request(status: 'new')),
      then: () async {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'จำนวนคน'),
          '2',
        );
        // ช่องที่โฟกัสอยู่จะดึงจอกลับมาหาตัวเอง — ปลดโฟกัสก่อนเลื่อนไปที่ปุ่ม
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        // ฟอร์มเป็น SingleChildScrollView สร้างทุกช่องไว้แล้ว — ensureVisible พอ
        await tester.ensureVisible(find.text('ส่งคำขอ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ส่งคำขอ'));
        await tester.pumpAndSettle();
      },
    );

    expect(tester.takeException(), isNull);
    expect(requests, isEmpty);
    expect(
      find.text('กรุณาเลือกวันที่อยากไป', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('ตั้งแต่ 4 คนขึ้นไป', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('รายการคำขอว่าง — มีคำอธิบายขั้นตอนและปุ่มขอเหมา', (
    tester,
  ) async {
    await pump(tester, const CharterRequestsScreen(), (r) async => ok([]));

    expect(tester.takeException(), isNull);
    expect(find.text('ขอเหมาทริป'), findsOneWidget);
    expect(find.text('ยังไม่มีคำขอ'), findsOneWidget);
  });
}
