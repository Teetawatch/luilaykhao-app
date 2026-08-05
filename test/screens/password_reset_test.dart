import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/forgot_password_screen.dart';
import 'package:luilaykhao_app/screens/reset_password_screen.dart';
import 'package:luilaykhao_app/services/notification_navigator.dart';
import 'package:provider/provider.dart';

/// เส้นทางกลับเข้าบัญชีของลูกค้า — ถ้าหน้าพวกนี้พังหรือ deep link ไม่แมพ
/// คนที่ลืมรหัสผ่านจะไม่มีทางเข้าแอปได้อีกเลย
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: AppProvider(),
        child: MaterialApp(home: child),
      ),
    );
    await tester.pump();
  }

  group('ForgotPasswordScreen', () {
    testWidgets('ปฏิเสธอีเมลที่ไม่ใช่รูปแบบอีเมล โดยไม่ยิง API', (tester) async {
      await pump(tester, const ForgotPasswordScreen(initialEmail: 'ไม่ใช่อีเมล'));

      await tester.tap(find.text('ส่งลิงก์ตั้งรหัสผ่านใหม่'));
      await tester.pump();

      expect(find.text('กรุณากรอกอีเมลที่ใช้สมัครสมาชิก'), findsOneWidget);
    });

    testWidgets('เติมอีเมลที่พิมพ์ค้างไว้จากหน้าเข้าสู่ระบบ', (tester) async {
      await pump(
        tester,
        const ForgotPasswordScreen(initialEmail: 'somchai@example.com'),
      );

      expect(find.text('somchai@example.com'), findsOneWidget);
    });
  });

  group('ResetPasswordScreen', () {
    testWidgets('ลิงก์ที่ไม่มีโทเคนพาไปขอลิงก์ใหม่ ไม่ใช่ฟอร์มที่กดแล้วพัง', (
      tester,
    ) async {
      await pump(
        tester,
        const ResetPasswordScreen(token: '', email: 'somchai@example.com'),
      );

      expect(find.text('ลิงก์ไม่สมบูรณ์'), findsOneWidget);
      expect(find.text('ขอลิงก์ใหม่'), findsOneWidget);
    });

    testWidgets('รหัสผ่านสั้นเกินไปถูกปัดตกก่อนถึงเซิร์ฟเวอร์', (tester) async {
      await pump(
        tester,
        const ResetPasswordScreen(token: 'tok', email: 'somchai@example.com'),
      );

      await tester.enterText(find.byType(TextField).first, 'sh0rt');
      await tester.enterText(find.byType(TextField).last, 'sh0rt');
      await tester.tap(find.text('บันทึกรหัสผ่านใหม่'));
      await tester.pump();

      expect(find.text('รหัสผ่านต้องยาวอย่างน้อย 8 ตัวอักษร'), findsOneWidget);
    });

    testWidgets('สองช่องไม่ตรงกันต้องบอกให้ชัด', (tester) async {
      await pump(
        tester,
        const ResetPasswordScreen(token: 'tok', email: 'somchai@example.com'),
      );

      await tester.enterText(find.byType(TextField).first, 'longenough1');
      await tester.enterText(find.byType(TextField).last, 'longenough2');
      await tester.tap(find.text('บันทึกรหัสผ่านใหม่'));
      await tester.pump();

      expect(find.text('รหัสผ่านทั้งสองช่องไม่ตรงกัน'), findsOneWidget);
    });
  });

  group('deep link', () {
    test('รับทั้งลิงก์เว็บและ custom scheme ของหน้าตั้งรหัสผ่านใหม่', () {
      expect(
        NotificationNavigator.handleDeepLink(
          Uri.parse(
            'https://luilaykhao.com/reset-password?token=abc&email=a%40b.com',
          ),
        ),
        isTrue,
      );
      expect(
        NotificationNavigator.handleDeepLink(
          Uri.parse('luilaykhao://reset-password?token=abc&email=a%40b.com'),
        ),
        isTrue,
      );
    });

    test('ลิงก์เว็บอื่นยังไม่ถูกดูดเข้าแอป', () {
      expect(
        NotificationNavigator.handleDeepLink(
          Uri.parse('https://luilaykhao.com/blog/some-article'),
        ),
        isFalse,
      );
    });
  });

  group('AppProvider.needsEmailVerification', () {
    test('บัญชีที่ยังไม่ยืนยันและมีอีเมลจริง → เตือน', () {
      final app = AppProvider();
      app.user = {'email': 'somchai@example.com', 'email_verified': false};
      app.api.token = 'test-token';

      expect(app.needsEmailVerification, isTrue);
    });

    test('บัญชี social ที่ไม่มีอีเมลจริง → ไม่เตือน (ส่งเมลไปก็ไม่มีใครได้รับ)', () {
      final app = AppProvider();
      app.user = {'email': 'line_123@social.local', 'email_verified': false};
      app.api.token = 'test-token';

      expect(app.needsEmailVerification, isFalse);
    });

    test('ยืนยันแล้ว → ไม่เตือน', () {
      final app = AppProvider();
      app.user = {'email': 'somchai@example.com', 'email_verified': true};
      app.api.token = 'test-token';

      expect(app.needsEmailVerification, isFalse);
    });
  });
}
