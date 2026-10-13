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

/// แถบโปรไฟล์ + กระดิ่งบนหน้าแรก — ใสบนรูป hero, เลื่อนลงแล้วทึบเต็มและขอบตรง
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
    // ฟอนต์จริงของแอป — ฟอนต์ทดสอบวาดทุกตัวเป็นสี่เหลี่ยมกว้างเท่ากัน ปุ่มใน
    // หน้าแรกที่กว้างตามข้อความจะล้นในเทสต์ทั้งที่บนเครื่องจริงไม่ล้น
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

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppProvider()),
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

  /// กล่องพื้นหลังของแถบหัว — ตัวที่ห่อ SafeArea ของแถวทักทาย
  BoxDecoration topBarDecoration(WidgetTester tester) {
    final bar = find
        .ancestor(
          of: find.textContaining('สวัสดี'),
          matching: find.byType(AnimatedContainer),
        )
        .last;
    final container = tester.widget<AnimatedContainer>(bar);
    return container.decoration! as BoxDecoration;
  }

  SystemUiOverlayStyle statusBarStyle(WidgetTester tester) => tester
      .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      )
      .value;

  testWidgets('บนรูป hero: แถบใส ไอคอนแถบสถานะสีขาว', (tester) async {
    await pumpHome(tester);

    expect(topBarDecoration(tester).color!.a, 0);
    expect(statusBarStyle(tester), SystemUiOverlayStyle.light);
  });

  testWidgets('เลื่อนลง: แถบทึบเต็ม ไม่มีขอบโค้ง ไอคอนแถบสถานะสีเข้ม', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    final decoration = topBarDecoration(tester);
    expect(decoration.color!.a, 1);
    expect(decoration.borderRadius, isNull);
    // ไม่มีกรอบตัดโค้งห่อแถบหัวอีกแล้ว
    expect(
      find.ancestor(
        of: find.textContaining('สวัสดี'),
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
    );
    expect(statusBarStyle(tester), SystemUiOverlayStyle.dark);
  });
}
