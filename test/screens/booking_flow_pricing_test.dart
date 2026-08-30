import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/booking_flow_screen.dart';
import 'package:provider/provider.dart';

/// ราคาจุดขึ้นรถเป็น "ราคาต่อคนเต็มจำนวน" ที่ทับราคารอบ (ไม่ใช่ค่าบวกเพิ่ม)
/// ฝั่งเซิร์ฟเวอร์คิดราคานี้ให้ผู้เดินทางทุกคนที่ยังไม่ได้เลือกจุดของตัวเอง
/// (BookingService: `$passengerPickupPoints[] = $pickupPoint`) ยอดที่แอปโชว์
/// จึงต้องคิดแบบเดียวกัน ไม่งั้นเลือกที่นั่งหลายที่แล้วยอดจะต่ำกว่าที่เก็บจริง
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  final schedule = <String, dynamic>{
    'id': 1,
    'departure_date': '2099-03-10',
    'return_date': '2099-03-11',
    'total_seats': 9,
    'available_seats': 9,
    'bookable_seats': 9,
    'price': 1500,
    'effective_price': 1500,
    'status': 'open',
    'transport_type': 'van',
    // ชนิดเดียวกับที่ jsonDecode คืนมาจริง (List<dynamic> ของ Map<String, dynamic>)
    'pickup_points': <dynamic>[
      <String, dynamic>{
        'id': 7,
        'name': 'อนุสาวรีย์ชัยสมรภูมิ',
        'region': 'bangkok',
        'price': 2000,
        'sort_order': 1,
      },
    ],
  };

  final trip = <String, dynamic>{
    'id': 1,
    'title': 'เขาใหญ่ 2 วัน 1 คืน',
    'slug': 'khaoyai',
    'price_per_person': 1500,
  };

  Future<void> pump(
    WidgetTester tester, {
    List<String> seats = const [],
  }) async {
    final provider = AppProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
          home: BookingFlowScreen(
            trip: trip,
            schedules: [schedule],
            initialSeatIds: seats,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('คนเดียวคิดราคาจุดขึ้นรถ ไม่ใช่ราคาฐานของรอบ', (tester) async {
    await pump(tester);

    expect(find.text('฿2,000.00'), findsWidgets);
  });

  testWidgets('เลือกหลายที่นั่ง ทุกคนต้องคิดราคาจุดขึ้นรถเท่ากัน', (
    tester,
  ) async {
    await pump(tester, seats: ['A1', 'B1', 'C1']);

    // 3 × 2,000 — ไม่ใช่ 2,000 + 1,500 × 2 ที่ได้จากคนที่ถูกเพิ่มมาพร้อมที่นั่ง
    // แล้วไม่ได้รับจุดขึ้นรถของการจองติดมาด้วย
    // 3 × 2,000 — ไม่ใช่ 2,000 + 1,500 × 2 ที่ได้จากคนที่ถูกเพิ่มมาพร้อมที่นั่ง
    // แล้วไม่ได้รับจุดขึ้นรถของการจองติดมาด้วย
    expect(find.text('฿6,000.00'), findsWidgets);
  });
}
