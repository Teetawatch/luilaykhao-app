import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/payment_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ใบที่ยืนยันแล้วแต่ยังมียอดเพิ่มเติม (แอดมินข้ามการชำระให้จ่ายทีหลัง หรือเพิ่ม
/// ของให้ทีหลัง) ต้องเปิดหน้าชำระเงินได้จริง — เดิมหน้านี้เห็นว่า "ยืนยันแล้ว"
/// เลยกลายเป็นการ์ด "พร้อมสำหรับเช็คอิน" ที่ไม่มีทางจ่าย
class _FakeApp extends AppProvider {
  _FakeApp(this.data);

  final Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> booking(String ref) async => data;

  @override
  Future<void> loadActiveSeatLocks({bool silent = false}) async {}
}

Map<String, dynamic> _booking({required num extraDue}) => {
  'booking_ref': 'LLK-20261010-AB12',
  'status': 'confirmed',
  'payment_type': 'full',
  'payment_method': 'admin_skip',
  'total_amount': 3600,
  'paid_amount': 3000,
  'waived_amount': 0,
  'extra_due': {'amount': extraDue},
  'qr_code': 'LLK-QR-1',
  'payment_gateway': {'provider': 'manual'},
  'passengers': [
    {'name': 'ผู้เดินทาง'},
  ],
  'schedule': {
    'departure_date': '2026-11-10',
    'trip': {'title': 'ภูกระดึง'},
  },
};

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> data, {
  bool extraOnly = false,
}) async {
  tester.view.physicalSize = const Size(900 * 3, 3000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: _FakeApp(data),
      child: MaterialApp(
        home: PaymentScreen(bookingRef: 'LLK', extraOnly: extraOnly),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th');
    await initializeDateFormatting('th_TH');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a confirmed booking with an extra due collects it', (
    tester,
  ) async {
    await _pump(tester, _booking(extraDue: 600));

    expect(find.text('มียอดที่ต้องชำระเพิ่ม'), findsOneWidget);
    expect(find.text('พร้อมสำหรับเช็คอิน'), findsNothing);
    expect(find.textContaining('ชำระยอดเพิ่มเติม'), findsWidgets);

    // ปิดหน้าเพื่อหยุด ticker นับถอยหลังของหน้าชำระเงิน
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a fully paid confirmed booking is ready to check in', (
    tester,
  ) async {
    await _pump(tester, _booking(extraDue: 0));

    expect(find.text('พร้อมสำหรับเช็คอิน'), findsOneWidget);
    expect(find.text('มียอดที่ต้องชำระเพิ่ม'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // มัดจำที่ยังค้างยอดคงเหลือ + สั่งเช่าอุปกรณ์เพิ่ม — ปกติหน้านี้เก็บยอดคงเหลือก่อน
  // แต่มาจากหน้าเช่าอุปกรณ์ต้องเก็บค่าเช่า ไม่งั้นลูกค้าโอนยอดคงเหลือทั้งก้อนแทน
  Map<String, dynamic> depositWithRental() => {
    ..._booking(extraDue: 300),
    'payment_type': 'deposit',
    'total_amount': 3300,
    'paid_amount': 1000,
    'deposit_amount': 1000,
    'balance_amount': 2000,
    'balance_due_at': '2026-11-01T00:00:00Z',
  };

  testWidgets('a deposit booking collects its balance first by default', (
    tester,
  ) async {
    await _pump(tester, depositWithRental());

    expect(find.text('มียอดที่ต้องชำระเพิ่ม'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('extraOnly collects the rental even with a balance open', (
    tester,
  ) async {
    await _pump(tester, depositWithRental(), extraOnly: true);

    expect(find.text('มียอดที่ต้องชำระเพิ่ม'), findsOneWidget);
    expect(find.textContaining('ชำระยอดเพิ่มเติม'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
