import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/providers/article_provider.dart';
import 'package:luilaykhao_app/providers/trip_alert_provider.dart';
import 'package:luilaykhao_app/providers/wishlist_provider.dart';
import 'package:luilaykhao_app/screens/customer_app_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ลำดับหน้าแรก: หมวดหมู่ติดกับทริปแนะนำที่มันกรอง → รีวิวถัดลงไป
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHome(WidgetTester tester, {double width = 390}) async {
    // สูงพอให้ ListView สร้างทุกส่วนพร้อมกัน จะได้วัดลำดับจากตำแหน่งจริง
    tester.view.physicalSize = Size(width, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final app = AppProvider()
      ..trips = [
        {
          'id': 1,
          'slug': 'phu-kradueng',
          'title': 'ภูกระดึง 3 วัน 2 คืน',
          'location': 'เลย',
          'price_per_person': 3200,
        },
      ]
      ..reviews = [
        {
          'id': 1,
          'rating': 5,
          'comment': 'ทีมงานดูแลดีมาก',
          'user': {'name': 'สมศรี'},
          'trip': {'title': 'ภูกระดึง 3 วัน 2 คืน'},
        },
      ];

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: app),
            ChangeNotifierProvider(create: (_) => WishlistProvider()),
            ChangeNotifierProvider(create: (_) => TripAlertProvider()),
            ChangeNotifierProvider(create: (_) => ArticleProvider()),
          ],
          child: const MaterialApp(home: ExploreScreen()),
        ),
      );
      await tester.pump();
    }, () => MockClient((_) async => http.Response('{"data":[]}', 200)));
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text).first).dy;

  testWidgets('หมวดหมู่ติดกับทริปแนะนำ และรีวิวอยู่ถัดลงไป', (tester) async {
    await pumpHome(tester);

    final categories = top(tester, 'หมวดหมู่');
    final popular = top(tester, 'ทริปแนะนำ');
    final reviews = top(tester, 'เสียงจากลูกทริป');
    expect(categories, lessThan(popular));
    expect(popular, lessThan(reviews));
  });

  testWidgets('จอแคบ 320pt: หน้าแรกทั้งหน้าไม่ล้น', (tester) async {
    await pumpHome(tester, width: 320);

    expect(tester.takeException(), isNull);
  });
}
