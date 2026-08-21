import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/tracking_provider.dart';
import 'package:luilaykhao_app/screens/guest_booking_lookup_screen.dart';
import 'package:provider/provider.dart';

/// "ค้นหาการจอง" ของคนที่ยังไม่ได้ล็อกอิน — เดิมเจอแล้วขึ้นแค่ชื่อทริปกับวันที่
/// ตอนนี้ต้องเห็นจุดขึ้นรถ ผู้เดินทาง ที่นั่ง ยอดเงิน และกำหนดการครบ
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  Map<String, dynamic> payload({bool full = true}) => {
    'booking_ref': full ? 'LLK-20990110-0001' : null,
    'status': 'confirmed',
    'qr_code': full ? 'QR-TEST' : null,
    'trip_title': 'ภูกระดึง',
    'departure_date': '2099-01-10',
    'departs_at': '2099-01-09 20:00:00',
    'schedule_id': 5,
    'vehicle_id': 3,
    'driver_name': 'พี่สมชาย',
    'license_plate': 'ฮก-1234',
    'share_url': full ? 'https://luilaykhao.com/track/abc' : null,
    'checked_in': false,
    'trip': {
      'title': 'ภูกระดึง',
      'location': 'เลย',
      'duration_days': 3,
      'cover_image': '',
      'thumbnail_image': '',
    },
    'schedule': {
      'departure_date': '2099-01-10',
      'return_date': '2099-01-12',
      'departs_at': '2099-01-09 20:00:00',
      'transport_type': 'van',
    },
    'pickup': {
      'kind': 'point',
      'region_label': 'กรุงเทพฯ',
      'location': 'ปั๊ม ปตท. รังสิต',
      'pickup_time': '19:30',
      'notes': 'จอดฝั่งร้านกาแฟ',
    },
    'vehicle': {
      'name': 'รถตู้ 1',
      'license_plate': 'ฮก-1234',
      'driver_name': 'พี่สมชาย',
      'driver_phone': '0891112222',
    },
    'staff': [
      {'name': 'ไกด์', 'phone': full ? '0812223333' : null},
    ],
    'passengers': [
      {
        'name': 'นาย ต้น',
        'phone': '081-xxx-1111',
        'seat': 'A1',
        'halal_food': false,
        'pickup_location': 'ปั๊ม ปตท. รังสิต',
      },
      {'name': 'นาย บอม', 'phone': '082-xxx-2222', 'halal_food': true},
    ],
    'payment': {
      'payment_type': 'deposit',
      'is_fully_paid': false,
      'has_outstanding': true,
      'amounts_hidden': !full,
      if (full) 'total_amount': 7000,
      if (full) 'paid_amount': 3000,
      if (full) 'outstanding_amount': 4000,
      if (full)
        'addons': [
          {'name': 'ถุงนอน', 'quantity': 2, 'price': 200},
        ],
    },
    'itinerary': [
      {
        'item_date': '2099-01-10',
        'time': '05:00',
        'title': 'ถึงที่พัก',
        'detail': 'เก็บของแล้วออกเดิน',
      },
    ],
  };

  Future<void> search(
    WidgetTester tester, {
    required Object data,
    bool byName = false,
  }) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          ChangeNotifierProvider<TrackingProvider>(
            create: (_) => TrackingProvider(),
            child: const MaterialApp(home: GuestBookingLookupScreen()),
          ),
        );

        if (byName) {
          await tester.tap(find.text('ชื่อ + เบอร์โทร'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).at(0), 'ต้น');
          await tester.enterText(find.byType(TextField).at(1), '0810001111');
        } else {
          await tester.enterText(
            find.byType(TextField).at(0),
            'LLK-20990110-0001',
          );
          await tester.enterText(find.byType(TextField).at(1), '1111');
        }

        // ชื่อหน้าก็เขียนว่า "ค้นหาการจอง" — กดที่ปุ่มเท่านั้น
        await tester.tap(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.text('ค้นหาการจอง'),
          ),
        );
        await tester.pumpAndSettle();
      },
      () => MockClient(
        (request) async => http.Response(
          jsonEncode({'success': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
  }

  testWidgets('ค้นด้วยรหัสการจอง — เห็นรายละเอียดครบทุกหัวข้อ', (tester) async {
    await search(tester, data: payload());

    expect(tester.takeException(), isNull);
    expect(find.text('ภูกระดึง'), findsWidgets);
    expect(find.text('LLK-20990110-0001'), findsWidgets);

    // จุดขึ้นรถ + เวลา + หมายเหตุ
    expect(find.text('จุดขึ้นรถ'), findsOneWidget);
    expect(find.text('ปั๊ม ปตท. รังสิต'), findsWidgets);
    expect(find.text('19:30 น.'), findsOneWidget);
    expect(find.text('จอดฝั่งร้านกาแฟ'), findsOneWidget);

    // ผู้เดินทาง + ที่นั่ง + เบอร์ที่ปิดกลางไว้
    expect(find.text('ผู้เดินทาง (2 คน)'), findsOneWidget);
    expect(find.text('นาย ต้น'), findsOneWidget);
    expect(find.textContaining('ที่นั่ง A1'), findsOneWidget);
    expect(find.textContaining('081-xxx-1111'), findsOneWidget);

    // เงิน + ของแถม + ทีมงาน + กำหนดการ
    expect(find.text('การชำระเงิน'), findsOneWidget);
    expect(find.textContaining('7,000'), findsOneWidget);
    expect(find.textContaining('ถุงนอน'), findsOneWidget);
    expect(find.textContaining('โทรหาคนขับ'), findsOneWidget);
    expect(find.text('กำหนดการ'), findsOneWidget);
    expect(find.text('ถึงที่พัก'), findsOneWidget);
  });

  testWidgets('ค้นด้วยชื่อ — ไม่มีรหัส/QR และไม่โชว์ตัวเลขเงิน', (tester) async {
    await search(tester, data: [payload(full: false)], byName: true);

    expect(tester.takeException(), isNull);
    expect(find.text('ภูกระดึง'), findsWidgets);
    expect(find.text('LLK-20990110-0001'), findsNothing);
    expect(find.textContaining('7,000'), findsNothing);

    // ผลเดียวกางให้เลย และยังบอกได้ว่ายังค้างจ่ายอยู่
    expect(find.text('ยังมียอดค้างชำระ'), findsOneWidget);
    expect(find.text('ปั๊ม ปตท. รังสิต'), findsWidgets);
  });

  testWidgets('เจอหลายรอบ — เริ่มแบบย่อ แล้วกางดูทีละใบ', (tester) async {
    await search(
      tester,
      data: [payload(full: false), payload(full: false)],
      byName: true,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('ดูรายละเอียดทั้งหมด'), findsNWidgets(2));
    expect(find.text('การชำระเงิน'), findsNothing);

    final expander = find.text('ดูรายละเอียดทั้งหมด').first;
    await tester.ensureVisible(expander);
    await tester.pumpAndSettle();
    await tester.tap(expander);
    await tester.pumpAndSettle();
    expect(find.text('การชำระเงิน'), findsOneWidget);
  });
}
