import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/booking_flow_screen.dart';
import 'package:provider/provider.dart';

/// ขั้น "ข้อมูลผู้โดยสาร" — ผู้เดินทางแต่ละคนเป็นการ์ดพับได้ หัวการ์ดบอกว่า
/// ขาดกี่ช่อง การ์ดที่พับยังถูกฟอร์มตรวจ และถูกกางออกเองเมื่อกดชำระเงิน
/// ทั้งที่ยังกรอกไม่ครบ ไม่งั้นข้อความเตือนจะซ่อนอยู่ในการ์ดที่มองไม่เห็น
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
    // ฟอนต์จริงของแอป — ฟอนต์ทดสอบวาดทุกตัวเป็นสี่เหลี่ยมกว้างเท่ากัน
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

  final schedule = <String, dynamic>{
    'id': 1,
    'departure_date': '2099-03-10',
    'return_date': '2099-03-12',
    'total_seats': 13,
    'available_seats': 9,
    'bookable_seats': 9,
    'price': 2990,
    'effective_price': 2990,
    'status': 'open',
    'transport_type': 'van',
    'pickup_points': <dynamic>[
      <String, dynamic>{
        'id': 7,
        'region': 'bkk',
        'region_label': 'กรุงเทพฯ',
        'pickup_location': 'BTS หมอชิต ทางออก 1',
        'price': 0,
        'pickup_time': '21:00',
      },
      <String, dynamic>{
        'id': 8,
        'region': 'bkk',
        'region_label': 'กรุงเทพฯ',
        'pickup_location': 'ฟิวเจอร์พาร์ค รังสิต',
        'price': 0,
        'pickup_time': '21:40',
      },
    ],
  };

  final trip = <String, dynamic>{
    'id': 1,
    'title': 'ภูกระดึง',
    'slug': 'pk',
    'price_per_person': 2990,
    'must_know': <dynamic>[
      <String, dynamic>{
        'name': 'ประกันอุบัติเหตุเพิ่มเติม',
        'price': 150,
        'price_type': 'per_person',
      },
    ],
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
            schedules: [schedule],
            initialSeatIds: const ['A1', 'A2'],
            resumeLockedSeats: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// การ์ดที่กางอยู่ = ปุ่มกรอกเร็วของคนนั้นถูกวาด (การ์ดที่พับเก็บช่องไว้แบบ
  /// offstage จึงหาไม่เจอด้วย finder ปกติ)
  Finder openCards() => find.text('กรอกเร็วจากข้อมูลที่บันทึกไว้');

  testWidgets('คนแรกกางไว้ คนที่สองพับ — แตะหัวการ์ดเพื่อกาง', (tester) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(openCards(), findsOneWidget);
    expect(find.text('แตะเพื่อกรอกข้อมูล'), findsOneWidget);

    await tester.ensureVisible(find.text('ผู้เดินทางคนที่ 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ผู้เดินทางคนที่ 2'));
    await tester.pumpAndSettle();
    expect(openCards(), findsNWidgets(2));
  });

  testWidgets('ปุ่มถัดไปพับคนนี้แล้วกางคนถัดไป', (tester) async {
    await pump(tester);

    final next = find.text('ถัดไป · ผู้เดินทางคนที่ 2');
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();

    expect(openCards(), findsOneWidget);
    expect(find.text('เรียบร้อย'), findsOneWidget);
  });

  testWidgets('หัวการ์ดนับช่องที่ขาด และใช้ชื่อที่กรอกเป็นหัว', (tester) async {
    await pump(tester);

    await tester.tap(find.text('นางสาว').first);
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'สมชาย ลุยเลยเขา').first,
      'สมหญิง ใจดี',
    );
    await tester.pump();

    expect(find.text('สมหญิง ใจดี'), findsWidgets);
    // เหลือ ชื่อเล่น เบอร์ เลขบัตร กรุ๊ปเลือด วันเกิด ผู้ติดต่อ เบอร์ฉุกเฉิน
    expect(find.text('ยังขาดอีก 7 ช่อง'), findsOneWidget);
  });

  testWidgets('กดชำระเงินทั้งที่ไม่ครบ กางการ์ดที่ยังขาดทุกใบ', (tester) async {
    await pump(tester);

    expect(openCards(), findsOneWidget);
    await tester.tap(find.text('ดำเนินการชำระเงิน'));
    await tester.pumpAndSettle();

    expect(openCards(), findsNWidgets(2));
    expect(find.text('กรุณาเลือกคำนำหน้า'), findsWidgets);
    expect(find.text('กรอกข้อมูลให้ครบถ้วนก่อนดำเนินการ'), findsNothing);
    expect(
      find.text('กรุณากรอกข้อมูลให้ครบถ้วนก่อนดำเนินการ'),
      findsOneWidget,
    );
  });

  testWidgets('ตัวเลือกเสริมกดเพิ่มแล้วได้ตัวปรับจำนวน', (tester) async {
    await pump(tester);

    await tester.ensureVisible(find.text('เพิ่ม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่ม'));
    await tester.pumpAndSettle();

    expect(find.text('เพิ่ม'), findsNothing);
    expect(find.text('+฿150.00'), findsOneWidget);
    expect(find.text('รวมตัวเลือกเสริม'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
