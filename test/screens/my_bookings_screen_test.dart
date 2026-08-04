import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/customer_app_screen.dart';
import 'package:provider/provider.dart';

/// หน้า "การจองของฉัน" ต้องเรนเดอร์ได้จริงกับข้อมูลที่ API ส่งมาจริง ๆ
/// (build ที่ throw จะกลายเป็นหน้าเปล่าสีเทาใน release build โดยไม่มีข้อความบอก)
void main() {
  // แอปจริงเรียกใน main() — เทสต์ต้องเตรียมเองไม่งั้น DateFormat('th_TH') โยน
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  Map<String, dynamic> booking({
    required String status,
    String? slipOcrStatus,
    String? expiresAt,
    String departureDate = '2099-01-10',
  }) {
    return {
      'id': 1,
      'booking_ref': 'LLK-20990110-0001',
      'status': status,
      'slip_ocr_status': slipOcrStatus,
      'expires_at': expiresAt,
      'payment_type': 'full',
      'total_amount': 3500,
      'paid_amount': status == 'confirmed' ? 3500 : 0,
      'created_at': '2026-08-04T10:00:00.000000Z',
      'passengers': [
        {'name': 'ผู้เดินทาง', 'nickname': 'ต้น'},
      ],
      'schedule': {
        'id': 5,
        'departure_date': departureDate,
        'return_date': departureDate,
        'trip': {'id': 2, 'title': 'ภูกระดึง', 'location': 'เลย', 'slug': 'phu'},
        'pickup_points': const [],
        'travelers': const [],
      },
    };
  }

  Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> data) async {
    final provider = AppProvider();
    provider.api.token = 'test-token';
    provider.bookings = data;
    provider.accountLoaded = true;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const MaterialApp(home: MyBookingsScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders a confirmed upcoming booking', (tester) async {
    await pump(tester, [booking(status: 'confirmed')]);
    expect(tester.takeException(), isNull);
    expect(find.text('ภูกระดึง'), findsWidgets);
  });

  testWidgets('renders an unpaid booking with its expiry countdown', (
    tester,
  ) async {
    await pump(tester, [
      booking(
        status: 'pending',
        expiresAt: DateTime.now()
            .add(const Duration(minutes: 7))
            .toIso8601String(),
      ),
    ]);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('ก่อนที่นั่งถูกคืน'), findsOneWidget);
  });

  testWidgets('renders a booking whose slip is under review', (tester) async {
    await pump(tester, [
      booking(status: 'pending', slipOcrStatus: 'pending_review'),
    ]);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('รอทีมงานตรวจสอบ'), findsOneWidget);
  });

  testWidgets('renders a finished trip as a compact history row', (
    tester,
  ) async {
    await pump(tester, [
      booking(status: 'completed', departureDate: '2020-01-10'),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a cancelled booking', (tester) async {
    await pump(tester, [
      booking(status: 'cancelled', departureDate: '2020-01-10'),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders past, upcoming and cancelled together', (tester) async {
    await pump(tester, [
      booking(status: 'confirmed'),
      booking(status: 'pending'),
      booking(status: 'completed', departureDate: '2020-01-10'),
      booking(status: 'cancelled', departureDate: '2021-01-10'),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the extras a booking can carry', (tester) async {
    final withExtras = booking(status: 'confirmed')
      ..addAll({
        'split': {'enabled': true, 'total_shares': 4, 'paid_shares': 2},
        'flexi_surcharge': 500,
        'selected_rentals': [
          {'name': 'เต็นท์', 'quantity': 1},
        ],
        'selected_addons': [
          {'name': 'อาหารเจ', 'quantity': 2},
        ],
        'is_gift': true,
        'gift': {'claimed': false},
        'custom_pickup': {
          'status': 'rejected',
          'label': 'หน้าปากซอย',
          'reject_reason': 'อยู่นอกเส้นทาง',
        },
      });

    await pump(tester, [withExtras]);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('แบ่งจ่าย 2/4 คน'), findsOneWidget);
    expect(find.textContaining('จุดรับที่ขอไว้ถูกปฏิเสธ'), findsOneWidget);
  });

  testWidgets('renders the empty state for someone with no bookings', (
    tester,
  ) async {
    await pump(tester, const []);
    expect(tester.takeException(), isNull);
    expect(find.text('ยังไม่มีการจอง'), findsOneWidget);
  });

  testWidgets('renders the error state when the load failed', (tester) async {
    final provider = AppProvider();
    provider.api.token = 'test-token';
    provider.accountLoaded = true;
    provider.accountError = 'เชื่อมต่อไม่ได้';

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const MaterialApp(home: MyBookingsScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('โหลดการจองไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
  });
}
