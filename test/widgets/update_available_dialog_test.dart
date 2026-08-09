import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/version_gate_service.dart';
import 'package:luilaykhao_app/widgets/update_available_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  const offer = VersionGateResult(
    blocked: false,
    updateAvailable: true,
    currentVersion: '1.13.0',
    latestVersion: '1.14.0',
    storeUrl: 'https://example.test/store',
    message: 'มีของใหม่ให้ลอง',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('หน้าแรก')),
      ),
    );
  }

  group('UpdateAvailableDialog.maybeShow', () {
    testWidgets('shows the offer and settles when the user postpones it', (
      tester,
    ) async {
      await pumpHost(tester);

      final settled = UpdateAvailableDialog.maybeShow(
        navigatorKey.currentContext!,
        offer,
      );
      await tester.pumpAndSettle();

      expect(find.text('มีเวอร์ชันใหม่'), findsOneWidget);
      expect(find.text('มีของใหม่ให้ลอง'), findsOneWidget);
      expect(find.text('เวอร์ชัน 1.14.0'), findsOneWidget);

      await tester.tap(find.text('ไว้ภายหลัง'));
      await tester.pumpAndSettle();

      expect(await settled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('update_prompt_dismissed_version'), '1.14.0');
    });

    testWidgets('reports unsettled when the session teardown clears the stack', (
      tester,
    ) async {
      await pumpHost(tester);

      final settled = UpdateAvailableDialog.maybeShow(
        navigatorKey.currentContext!,
        offer,
      );
      await tester.pumpAndSettle();
      expect(find.text('มีเวอร์ชันใหม่'), findsOneWidget);

      // สิ่งที่ _handleSessionExpired ทำ — กวาดทุก route ทิ้งรวมถึง dialog ใบนี้
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('เข้าสู่ระบบ')),
        ),
        (route) => false,
      );
      await tester.pumpAndSettle();

      expect(find.text('มีเวอร์ชันใหม่'), findsNothing);
      expect(
        await settled,
        isFalse,
        reason: 'ผู้ใช้ไม่เคยเห็น — ต้องบอกผู้เรียกให้ลองใหม่ ไม่ใช่นับว่าจบแล้ว',
      );

      // และต้องไม่ไปจำว่าผู้ใช้ปฏิเสธเวอร์ชันนี้ไปแล้ว
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('update_prompt_dismissed_version'), isNull);
    });

    testWidgets('the barrier no longer swallows the prompt', (tester) async {
      await pumpHost(tester);

      UpdateAvailableDialog.maybeShow(navigatorKey.currentContext!, offer);
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(
        find.text('มีเวอร์ชันใหม่'),
        findsOneWidget,
        reason: 'แตะนอกกล่องต้องไม่ปิด ไม่งั้นแยกไม่ออกจากการโดนลบ route',
      );
    });

    testWidgets('settles without asking when there is nothing to offer', (
      tester,
    ) async {
      await pumpHost(tester);

      const nothing = VersionGateResult(blocked: false);
      expect(
        await UpdateAvailableDialog.maybeShow(
          navigatorKey.currentContext!,
          nothing,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.text('มีเวอร์ชันใหม่'), findsNothing);
    });

    testWidgets('settles without asking for a version already skipped', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'update_prompt_dismissed_version': '1.14.0',
      });
      await pumpHost(tester);

      expect(
        await UpdateAvailableDialog.maybeShow(
          navigatorKey.currentContext!,
          offer,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.text('มีเวอร์ชันใหม่'), findsNothing);
    });
  });
}
