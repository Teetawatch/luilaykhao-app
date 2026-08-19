import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/booking_flow_screen.dart';
import 'package:provider/provider.dart';

/// รอบที่บินไปไม่มีรถวิ่งรับ — ขั้นตอนแรกของการจองต้องเป็น "จุดนัดพบ" ที่สนามบิน
/// ไม่ใช่ช่องเลือกจุดขึ้นรถที่ว่างเปล่าซึ่งเด้ง "กรุณาปักหมุดจุดรับของคุณบนแผนที่"
/// ใส่หน้าลูกค้าเมื่อกดถัดไป (ไม่มีอะไรให้ปักหมุด รถไม่ได้ไปรับ)
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  Map<String, dynamic> schedule({
    required int id,
    required String transportType,
    List<Map<String, dynamic>> pickupPoints = const [],
  }) {
    return {
      'id': id,
      'departure_date': '2099-03-10',
      'return_date': '2099-03-14',
      'total_seats': 16,
      'available_seats': 10,
      'bookable_seats': 10,
      'price': 39000,
      'effective_price': 39000,
      'status': 'open',
      'transport_type': transportType,
      'pickup_points': pickupPoints,
      if (transportType == 'flight')
        'flight_plan': {
          'meeting_point': 'สนามบินสุวรรณภูมิ ประตู 3 แถว W',
          'meeting_time': '21:30',
          'meeting_map_url': '',
          'baggage_allowance': 'โหลดใต้เครื่อง 20 กก.',
          'legs': {
            'outbound': [
              {
                'airline': 'Thai Airways',
                'flight_no': 'TG319',
                'from': 'BKK',
                'to': 'KTM',
                'depart_at': '2099-03-10 23:55:00',
              },
            ],
            'return': const [],
          },
        },
    };
  }

  final trip = <String, dynamic>{
    'id': 1,
    'title': 'เนปาล เบสแคมป์อันนาปุรณะ',
    'slug': 'abc-nepal',
    'price_per_person': 39000,
    'is_international': true,
  };

  Future<void> pump(WidgetTester tester, List<dynamic> schedules) async {
    final provider = AppProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
          home: BookingFlowScreen(trip: trip, schedules: schedules),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('รอบที่บินไปแสดงจุดนัดพบแทนการเลือก/ปักหมุดจุดขึ้นรถ', (
    tester,
  ) async {
    await pump(tester, [schedule(id: 1, transportType: 'flight')]);

    expect(find.text('จุดนัดพบ'), findsWidgets);
    expect(find.text('นัดพบ 21:30 น.'), findsOneWidget);
    expect(find.text('สนามบินสุวรรณภูมิ ประตู 3 แถว W'), findsOneWidget);
    // ปุ่มปักหมุดจุดรับเองต้องไม่โผล่ในรอบที่ไม่มีรถไปรับ
    expect(find.textContaining('ปักหมุดจุดรับเอง'), findsNothing);
    expect(find.text('จุดขึ้นรถ'), findsNothing);
  });

  testWidgets('กดถัดไปในรอบที่บินไปแล้วไปต่อได้ ไม่ขึ้นข้อความให้ปักหมุด', (
    tester,
  ) async {
    await pump(tester, [schedule(id: 1, transportType: 'flight')]);

    await tester.tap(find.text('ไปเลือกที่นั่ง'));
    await tester.pump();

    expect(find.text('กรุณาปักหมุดจุดรับของคุณบนแผนที่'), findsNothing);
  });

  testWidgets('รอบรถตู้ที่ไม่มีจุดรับยังขอให้ปักหมุดเหมือนเดิม', (tester) async {
    await pump(tester, [schedule(id: 2, transportType: 'van')]);

    expect(find.text('จุดขึ้นรถ'), findsWidgets);
    expect(find.textContaining('ปักหมุดจุดรับเอง'), findsWidgets);

    await tester.tap(find.text('ไปเลือกที่นั่ง'));
    await tester.pump();

    expect(find.text('กรุณาปักหมุดจุดรับของคุณบนแผนที่'), findsOneWidget);
  });
}
