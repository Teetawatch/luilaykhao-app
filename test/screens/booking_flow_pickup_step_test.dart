import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/booking_flow_screen.dart';
import 'package:provider/provider.dart';

/// ขั้นที่ 1 "จุดขึ้นรถ" — รอบเป็นแถบวันที่ ภูมิภาคเป็นชิป จุดขึ้นรถเป็นการ์ดเลือก
/// แทน dropdown สามช่องเดิม (ซึ่งโชว์แค่ภูมิภาคที่เลือกอยู่ จึงย้ายภูมิภาคไม่ได้)
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
    // ฟอนต์จริงของแอป — ฟอนต์ทดสอบวาดทุกตัวเป็นสี่เหลี่ยมกว้างเท่ากัน
    // การเช็คว่าล้นกรอบไหมจะไม่ตรงกับเครื่องจริงเลย
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

  Map<String, dynamic> point(
    int id,
    String region,
    String regionLabel,
    String location, {
    num price = 0,
    String? time,
    String? notes,
    String? mapUrl,
  }) {
    return {
      'id': id,
      'region': region,
      'region_label': regionLabel,
      'pickup_location': location,
      'price': price,
      'original_price': price,
      'pickup_time': time,
      'notes': notes,
      'map_url': mapUrl,
    };
  }

  final bangkokPoints = [
    point(
      11,
      'bkk',
      'กรุงเทพฯ',
      'ปั๊ม ปตท. วิภาวดี ขาออก',
      time: '21:30',
      notes: 'จอดหน้าร้านกาแฟ อเมซอน',
      mapUrl: 'https://maps.google.com/?q=1',
    ),
    point(12, 'bkk', 'กรุงเทพฯ', 'BTS หมอชิต ทางออก 1', time: '21:00'),
    point(13, 'bkk', 'กรุงเทพฯ', 'เซ็นทรัล รามอินทรา', time: '22:00'),
    point(14, 'bkk', 'กรุงเทพฯ', 'ฟิวเจอร์พาร์ค รังสิต', time: '22:20'),
    point(15, 'bkk', 'กรุงเทพฯ', 'ม.ธรรมศาสตร์ รังสิต', time: '22:40'),
    point(16, 'bkk', 'กรุงเทพฯ', 'ปั๊มบางจาก นวนคร', time: '22:50'),
  ];
  final northPoints = [
    point(
      21,
      'north',
      'ภาคเหนือ',
      'ขนส่งเชียงใหม่ อาเขต',
      price: 3490,
      time: '05:30',
    ),
  ];

  Map<String, dynamic> schedule(int id, String date, {int seats = 10}) {
    return {
      'id': id,
      'departure_date': date,
      'return_date': '2099-03-${int.parse(date.substring(8)) + 2}',
      'departs_at': '$date 21:00:00',
      'total_seats': 13,
      'available_seats': seats,
      'bookable_seats': seats,
      'price': 2990,
      'effective_price': 2990,
      'status': 'open',
      'transport_type': 'van',
      'pickup_points': <dynamic>[...bangkokPoints, ...northPoints],
    };
  }

  final schedules = <dynamic>[
    schedule(1, '2099-03-10'),
    schedule(2, '2099-03-17', seats: 2),
    schedule(3, '2099-03-24', seats: 0),
  ];

  final trip = <String, dynamic>{
    'id': 1,
    'title': 'ภูกระดึง เดินขึ้นยอด',
    'slug': 'phu-kradueng',
    'price_per_person': 2990,
  };

  Future<void> pump(WidgetTester tester) async {
    // จอโทรศัพท์แคบ + ตัวอักษรใหญ่สุดที่แอปยอม — ต้องไม่มีอะไรล้นกรอบ
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('รอบเป็นแถบวันที่ บอกที่ว่างทุกรอบ', (tester) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('เลือกรอบเดินทาง'), findsOneWidget);
    expect(find.text('ว่าง 10 ที่'), findsOneWidget);
    expect(find.text('เหลือ 2 ที่'), findsOneWidget);
    expect(find.text('เต็มแล้ว'), findsOneWidget);

    await tester.tap(find.text('17'));
    await tester.pumpAndSettle();
    expect(find.textContaining('17 มี.ค.'), findsWidgets);
  });

  testWidgets('สลับภูมิภาคได้จากชิป และเลือกจุดจากการ์ด', (tester) async {
    await pump(tester);

    expect(find.text('ขึ้นรถ 21:30 น.'), findsOneWidget);
    expect(find.text('ดูแผนที่'), findsOneWidget);
    expect(find.text('ขนส่งเชียงใหม่ อาเขต'), findsNothing);

    await tester.tap(find.textContaining('ภาคเหนือ').first);
    await tester.pumpAndSettle();

    expect(find.text('ขนส่งเชียงใหม่ อาเขต'), findsWidgets);
    expect(find.text('ปั๊ม ปตท. วิภาวดี ขาออก'), findsNothing);
    expect(find.textContaining('จุดขึ้นรถ ขนส่งเชียงใหม่ อาเขต'), findsOneWidget);
  });

  testWidgets('จุดขึ้นรถเยอะพับไว้ก่อน กดดูทั้งหมดได้', (tester) async {
    await pump(tester);

    expect(find.text('ปั๊มบางจาก นวนคร'), findsNothing);
    await tester.ensureVisible(find.text('ดูจุดขึ้นรถอีก 2 จุด'));
    await tester.tap(find.text('ดูจุดขึ้นรถอีก 2 จุด'));
    await tester.pumpAndSettle();
    expect(find.text('ปั๊มบางจาก นวนคร'), findsOneWidget);

    await tester.ensureVisible(find.text('ปั๊มบางจาก นวนคร'));
    await tester.tap(find.text('ปั๊มบางจาก นวนคร'));
    await tester.pumpAndSettle();
    expect(find.textContaining('จุดขึ้นรถ ปั๊มบางจาก นวนคร'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
