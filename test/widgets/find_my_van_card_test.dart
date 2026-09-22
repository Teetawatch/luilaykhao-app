import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/models/tracking_model.dart';
import 'package:luilaykhao_app/widgets/find_my_van_card.dart';

/// การ์ด "คันไหนคือคันของเรา" ต้องเงียบตอนที่คำถามยังไม่เกิด และพูดให้ครบตอนที่
/// ลูกค้ายืนอยู่ในลานจอดจริง
void main() {
  BookingInfo booking({
    String? plate = 'ฮก 8899',
    String? arrivedAt,
    String? note,
    String transport = 'van',
  }) {
    return BookingInfo.fromJson({
      'booking_ref': 'LLK-20260922-0001',
      'schedule_id': 1,
      'vehicle_id': 1,
      'trip_title': 'ยอดดอยหลวง',
      'departure_point': 'จุดขึ้นรถหมอชิต',
      'pickup_lat': 13.8,
      'pickup_lng': 100.5,
      'departure_date': '2026-09-22',
      'status': 'confirmed',
      'license_plate': plate,
      'vehicle_name': 'รถตู้คันที่ 1',
      'vehicle_color': 'ขาว',
      'driver_name': 'พี่สมชาย',
      'driver_phone': '0801112222',
      'transport_type': transport,
      'pickup_arrived_at': arrivedAt,
      'pickup_arrival_note': note,
    });
  }

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('stays out of the way until the van is near', (tester) async {
    await pump(tester, FindMyVanCard(booking: booking()));

    expect(find.text('ฮก 8899'), findsNothing);
  });

  testWidgets('leads with the plate once staff say the van has arrived', (
    tester,
  ) async {
    await pump(
      tester,
      FindMyVanCard(
        booking: booking(
          arrivedAt: '2026-09-22T07:10:00+07:00',
          note: 'จอดตรงข้าม 7-11',
        ),
      ),
    );

    expect(find.text('ฮก 8899'), findsOneWidget);
    expect(find.text('รถของคุณจอดรออยู่แล้ว'), findsOneWidget);
    expect(find.text('จอดตรงข้าม 7-11'), findsOneWidget);
    expect(find.text('รถตู้คันที่ 1 · สีขาว'), findsOneWidget);
    expect(find.text('โทรหาพี่สมชาย'), findsOneWidget);
  });

  testWidgets('shows the plate while the van is minutes away too', (
    tester,
  ) async {
    await pump(tester, FindMyVanCard(booking: booking(), imminent: true));

    expect(find.text('ฮก 8899'), findsOneWidget);
    expect(find.text('มองหารถคันนี้ได้เลย'), findsOneWidget);
  });

  testWidgets('a round with no plate has nothing to help with', (tester) async {
    await pump(
      tester,
      FindMyVanCard(
        booking: booking(plate: null, arrivedAt: '2026-09-22T07:10:00+07:00'),
        imminent: true,
      ),
    );

    expect(find.text('รถของคุณจอดรออยู่แล้ว'), findsNothing);
  });

  testWidgets('flights have no van to find', (tester) async {
    await pump(
      tester,
      FindMyVanCard(
        booking: booking(transport: 'flight', arrivedAt: '2026-09-22T07:10:00+07:00'),
        imminent: true,
      ),
    );

    expect(find.text('ฮก 8899'), findsNothing);
  });
}
