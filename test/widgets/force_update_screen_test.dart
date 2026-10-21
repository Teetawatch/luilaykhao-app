import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/version_gate_service.dart';
import 'package:luilaykhao_app/widgets/force_update_screen.dart';
import 'package:luilaykhao_app/widgets/maintenance_screen.dart';

const _result = VersionGateResult(
  blocked: true,
  currentVersion: '1.14.0',
  minVersion: '1.15.0',
  latestVersion: '1.16.0',
);

void _screen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
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

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('small phone', const Size(320, 568)),
    ('tablet', const Size(1024, 1366)),
    ('phone landscape', const Size(844, 390)),
  ]) {
    testWidgets('update screen is centred and fits on $name', (tester) async {
      _screen(tester, size);
      await tester.pumpWidget(
        const MaterialApp(home: ForceUpdateScreen(result: _result)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final title = tester.getCenter(find.text('อัปเดตแอปก่อนใช้งานต่อ'));
      final button = tester.getRect(find.byType(FilledButton));
      expect(title.dx, moreOrLessEquals(size.width / 2, epsilon: 1));
      expect(button.center.dx, moreOrLessEquals(size.width / 2, epsilon: 1));
      // ไม่กว้างเกินบนแท็บเล็ต
      expect(button.width, lessThanOrEqualTo(420));
      expect(find.text('1.14.0'), findsOneWidget);
      expect(find.text('1.16.0'), findsOneWidget);
    });
  }

  testWidgets('content sits in the vertical middle on a tall screen', (
    tester,
  ) async {
    _screen(tester, const Size(390, 844));
    await tester.pumpWidget(
      const MaterialApp(home: ForceUpdateScreen(result: _result)),
    );
    await tester.pumpAndSettle();

    final top = tester.getTopLeft(find.byType(Image)).dy;
    final bottom = tester
        .getBottomLeft(find.text('อัปเดตเสร็จแล้วเปิดแอปใหม่อีกครั้ง'))
        .dy;
    final middle = (top + bottom) / 2;
    expect(middle, moreOrLessEquals(844 / 2, epsilon: 30));
  });

  testWidgets('without a store link it says how to find the app', (
    tester,
  ) async {
    _screen(tester, const Size(390, 844));
    await tester.pumpWidget(
      const MaterialApp(
        home: ForceUpdateScreen(result: VersionGateResult(blocked: true)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.textContaining('ค้นหา "ลุยเลเขา"'), findsOneWidget);
  });

  testWidgets('maintenance screen shares the centred layout', (tester) async {
    _screen(tester, const Size(1024, 1366));
    await tester.pumpWidget(
      MaterialApp(home: MaintenanceScreen(checking: false, onRetry: () {})),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('ปิดปรับปรุงชั่วคราว')).dx,
      moreOrLessEquals(512, epsilon: 1),
    );
  });
}
