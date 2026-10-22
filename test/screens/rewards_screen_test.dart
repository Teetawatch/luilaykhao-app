import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/rewards_screen.dart';
import 'package:luilaykhao_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _App extends AppProvider {
  @override
  Future<void> loadAccountData() async {}
}

/// แต้มสะสม — แท็บของรางวัล / คูปองของฉัน / ประวัติ
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
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

  _App app() => _App()
    ..loyalty = {
      'points': 1200,
      'tier_label': 'นักเดินทาง',
      'lifetime_trips': 2,
      'transactions': [
        {'type': 'earn', 'points': 100, 'description': 'จองทริปภูกระดึง'},
      ],
    }
    ..rewards = [
      {
        'id': 1,
        'name': 'ส่วนลด 100 บาท',
        'type': 'discount_fixed',
        'value_label': 'ลด ฿100',
        'points_required': 500,
      },
    ]
    ..coupons = [
      {
        'coupon_code': 'ABC123',
        'reward_name': 'ส่วนลดคูปอง',
        'reward_type': 'discount_fixed',
        'is_used': false,
      },
    ];

  Future<void> pump(WidgetTester tester, {bool dark = false}) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const RewardsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('แตะแต่ละแท็บแล้วเห็นเนื้อหาของแท็บนั้น', (tester) async {
    await pump(tester);
    expect(find.text('ส่วนลด 100 บาท'), findsOneWidget);

    await tester.tap(find.text('คูปองของฉัน'));
    await tester.pumpAndSettle();
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('ส่วนลด 100 บาท'), findsNothing);

    await tester.tap(find.text('ประวัติ'));
    await tester.pumpAndSettle();
    expect(find.text('จองทริปภูกระดึง'), findsOneWidget);

    await tester.tap(find.text('ของรางวัล'));
    await tester.pumpAndSettle();
    expect(find.text('ส่วนลด 100 บาท'), findsOneWidget);
  });

  /// สีที่มืดที่สุดบนแถวกลางของแถบแท็บ ระหว่างอนิเมชันสลับแท็บ
  Future<int> darkestDuringSwitch(WidgetTester tester, String to) async {
    // แถวของปุ่มแท็บ และบรรทัดในช่องว่างเหนือตัวหนังสือ (padding 9pt ของปุ่ม)
    final bar = tester.getRect(
      find
          .ancestor(of: find.text('ของรางวัล'), matching: find.byType(Row))
          .first,
    );
    final y = (tester.getRect(find.text('ของรางวัล')).top - 4).round();
    await tester.tap(find.text(to));
    var darkest = 255 * 3;
    for (var frame = 0; frame < 14; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final element = tester.element(find.byType(RewardsScreen));
      final image = await captureImage(element);
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      for (var x = bar.left.round() + 6; x < bar.right.round() - 6; x++) {
        final i = (y * image.width + x) * 4;
        final sum =
            bytes.getUint8(i) + bytes.getUint8(i + 1) + bytes.getUint8(i + 2);
        if (sum < darkest) darkest = sum;
      }
      image.dispose();
    }
    await tester.pumpAndSettle();
    return darkest;
  }

  testWidgets('สลับแท็บแล้วแถบไม่กระพริบเป็นสีเทา', (tester) async {
    await pump(tester);
    // พื้นแถบเป็นสีเขียวอ่อนมาก ไฮไลต์เป็นสีขาว — ไม่มีอะไรควรมืดกว่านั้น
    // เดิมช่องเก่าและช่องใหม่ไล่สีผ่านดำโปร่งใสพร้อมกัน ลงไปถึงราว (180,186,185)
    expect(
      await darkestDuringSwitch(tester, 'คูปองของฉัน'),
      greaterThan(220 * 3),
    );
    expect(await darkestDuringSwitch(tester, 'ประวัติ'), greaterThan(220 * 3));
    expect(
      await darkestDuringSwitch(tester, 'ของรางวัล'),
      greaterThan(220 * 3),
    );
  });
}
