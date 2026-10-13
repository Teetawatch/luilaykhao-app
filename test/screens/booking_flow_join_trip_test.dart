import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/booking_flow_screen.dart';
import 'package:provider/provider.dart';

/// "จอยทริปคืออะไร?" — ลูกค้าถามบ่อยที่ขั้นเลือกรอบ จึงมีลิงก์เปิดคำอธิบาย
/// แยกจากการกดเลือกจอยทริป
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
    // ฟอนต์จริงของแอป — ฟอนต์ทดสอบวาดอักษรไทยกว้างเกินจริง เช็คล้นไม่ได้
    Future<void> load(String family, List<String> assets) async {
      final loader = FontLoader(family);
      for (final asset in assets) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }

    await load('Inter', ['assets/fonts/Inter-Variable.ttf']);
    await load('LINE Seed Sans TH', [
      'assets/fonts/LINESeedSansTH_A_Rg.ttf',
      'assets/fonts/LINESeedSansTH_A_Bd.ttf',
    ]);
  });

  final schedules = <dynamic>[
    {
      'id': 1,
      'departure_date': '2099-03-10',
      'return_date': '2099-03-12',
      'departs_at': '2099-03-10 21:00:00',
      'total_seats': 13,
      'available_seats': 10,
      'bookable_seats': 10,
      'price': 2990,
      'effective_price': 2990,
      'status': 'open',
      'transport_type': 'van',
      'join_trip_enabled': true,
      'join_trip_price': 1990,
      'join_trip_seats': 10,
      'join_trip_booked_seats': 3,
      'pickup_points': <dynamic>[
        {
          'id': 11,
          'region': 'bkk',
          'region_label': 'กรุงเทพฯ',
          'pickup_location': 'BTS หมอชิต',
          'price': 0,
        },
      ],
    },
  ];

  final trip = <String, dynamic>{
    'id': 1,
    'title': 'ภูกระดึง เดินขึ้นยอด',
    'slug': 'phu-kradueng',
    'price_per_person': 2990,
  };

  Future<void> pump(WidgetTester tester, {bool joinTrip = false}) async {
    // จอแคบ + ตัวอักษรใหญ่สุดที่แอปยอม — ลิงก์และชีตต้องไม่ล้นกรอบ
    tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final provider = AppProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: BookingFlowScreen(
            trip: trip,
            schedules: schedules,
            initialPickupPointId: 11,
            initialJoinTrip: joinTrip,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openExplainer(WidgetTester tester) async {
    await tester.ensureVisible(find.text('จอยทริปคืออะไร?'));
    await tester.tap(find.text('จอยทริปคืออะไร?'));
    await tester.pumpAndSettle();
  }

  testWidgets('the link explains Join Trip without switching it on', (
    tester,
  ) async {
    await pump(tester);
    await openExplainer(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('นั่งรถทีม'), findsOneWidget);
    expect(find.text('จอยทริป'), findsOneWidget);
    expect(find.text('฿2,990 / คน'), findsOneWidget);
    expect(find.text('฿1,990 / คน'), findsOneWidget);
    expect(find.textContaining('ถูกกว่า ฿1,000 ต่อคน'), findsOneWidget);
    expect(find.textContaining('จอยแล้ว 3/10'), findsWidgets);
    expect(find.text('เลือกจอยทริป'), findsOneWidget);

    // ปิดชีตแล้วยังเป็นแบบนั่งรถทีมเหมือนเดิม
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    expect(find.text('นั่งรถทีม'), findsNothing);
    expect(find.text('คุณเลือกจอยทริป'), findsNothing);
  });

  testWidgets('choosing from the explainer switches the booking to Join Trip', (
    tester,
  ) async {
    await pump(tester);
    await openExplainer(tester);

    await tester.ensureVisible(find.text('เลือกจอยทริป'));
    await tester.tap(find.text('เลือกจอยทริป'));
    await tester.pumpAndSettle();

    expect(find.text('คุณเลือกจอยทริป'), findsOneWidget);
  });

  testWidgets('already on Join Trip, the explainer only closes', (
    tester,
  ) async {
    await pump(tester, joinTrip: true);
    expect(find.text('คุณเลือกจอยทริป'), findsOneWidget);

    await openExplainer(tester);
    expect(find.text('เลือกจอยทริป'), findsNothing);
    expect(find.text('เข้าใจแล้ว'), findsOneWidget);

    await tester.tap(find.text('เข้าใจแล้ว'));
    await tester.pumpAndSettle();
    expect(find.text('คุณเลือกจอยทริป'), findsOneWidget);
  });
}
