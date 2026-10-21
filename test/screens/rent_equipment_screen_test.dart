import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/payment_screen.dart';
import 'package:luilaykhao_app/screens/rent_equipment_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// เช่าอุปกรณ์เพิ่มหลังจอง — เลือกจำนวน สั่งแล้วไปหน้าชำระยอดเพิ่มเติม
class _FakeApp extends AppProvider {
  _FakeApp(this.overview, {this.booking_ = const {}});

  Map<String, dynamic> overview;
  final Map<String, dynamic> booking_;
  Map<String, int>? ordered;

  @override
  Future<Map<String, dynamic>> bookingRentals(String ref) async => overview;

  @override
  Future<Map<String, dynamic>> orderRentals(
    String ref,
    Map<String, int> quantities,
  ) async {
    ordered = quantities;
    overview = {
      ...overview,
      'orders': [
        {
          'id': 1,
          'status': 'awaiting_payment',
          'amount': 600,
          'items': [
            {'name': 'เต็นท์ 2 คน', 'quantity': 2},
          ],
        },
      ],
    };
    return {'overview': overview};
  }

  @override
  Future<Map<String, dynamic>> booking(String ref) async => booking_;

  @override
  Future<void> loadActiveSeatLocks({bool silent = false}) async {}
}

Map<String, dynamic> _overview({bool open = true, List orders = const []}) => {
  'open': open,
  'closed_reason': open ? null : 'ปิดรับเช่าอุปกรณ์ในแอปแล้ว',
  'last_day_label': '29 ตุลาคม 2569',
  'cutoff_days': 2,
  'catalog': [
    {
      'key': 'tent',
      'name': 'เต็นท์ 2 คน',
      'price': 300,
      'description': '',
      'image_url': '',
      'parts': [
        {'name': 'ถุงนอน', 'quantity': 2},
      ],
    },
  ],
  'selected_rentals': [
    {'name': 'ถุงนอน', 'quantity': 1},
  ],
  'orders': orders,
};

Future<void> _pump(WidgetTester tester, _FakeApp app) async {
  tester.view.physicalSize = const Size(900 * 3, 3000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: app,
      child: const MaterialApp(home: RentEquipmentScreen(bookingRef: 'LLK')),
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

  testWidgets('picking items shows the total and orders by key', (
    tester,
  ) async {
    final app = _FakeApp(
      _overview(),
      booking_: {
        'booking_ref': 'LLK',
        'status': 'confirmed',
        'payment_type': 'full',
        'total_amount': 3600,
        'paid_amount': 3000,
        'extra_due': {'amount': 600},
        'payment_gateway': {'provider': 'manual'},
        'schedule': {
          'departure_date': '2026-10-31',
          'trip': {'title': 'ภูกระดึง'},
        },
      },
    );
    await _pump(tester, app);

    expect(find.text('เช่าได้ถึง 29 ตุลาคม 2569'), findsOneWidget);
    expect(find.text('อุปกรณ์ในการจองนี้'), findsOneWidget);
    expect(find.text('ในชุดมี: ถุงนอน 2'), findsOneWidget);
    expect(find.text('สั่งเช่าและชำระเงิน'), findsNothing);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(find.text('รวม 2 ชิ้น'), findsOneWidget);
    await tester.tap(find.text('สั่งเช่าและชำระเงิน'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(app.ordered, {'tent': 2});
    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(find.text('มียอดที่ต้องชำระเพิ่ม'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an unpaid order blocks new picks and offers pay/cancel', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeApp(
        _overview(
          orders: [
            {
              'id': 3,
              'status': 'awaiting_payment',
              'amount': 300,
              'items': [
                {'name': 'เต็นท์ 2 คน', 'quantity': 1},
              ],
            },
          ],
        ),
      ),
    );

    expect(find.text('รอชำระค่าเช่า'), findsOneWidget);
    expect(find.text('ชำระเงิน'), findsOneWidget);
    expect(find.text('ยกเลิกรายการ'), findsOneWidget);
    expect(find.text('เลือกอุปกรณ์ที่ต้องการเช่าเพิ่ม'), findsNothing);
  });

  testWidgets('a closed round explains why', (tester) async {
    await _pump(tester, _FakeApp(_overview(open: false)));

    expect(find.text('ปิดรับเช่าอุปกรณ์ในแอปแล้ว'), findsOneWidget);
    expect(find.text('เลือกอุปกรณ์ที่ต้องการเช่าเพิ่ม'), findsNothing);
  });
}
