import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/account_claim_screen.dart';
import 'package:luilaykhao_app/services/notification_navigator.dart';
import 'package:provider/provider.dart';

/// SMS "ทีมงานเปิดการจองให้คุณแล้ว" เปิดเข้าแอป — สิ่งที่ต้องถูกคือ คนที่ยังไม่
/// ล็อกอินถูกพาไปล็อกอินก่อน (ไม่ใช่กดรับแล้วพัง), คนที่ล็อกอินแล้วกดปุ่มเดียวจบ
/// และลิงก์ที่ใช้ไปแล้วบอกตรง ๆ ว่าใช้แล้ว
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  final preview = {
    'name': 'สมชาย ใจดี',
    'phone_hint': '5678',
    'bookings': [
      {
        'booking_ref': 'LLK-20991010-0001',
        'trip_title': 'ภูกระดึง',
        'departure_date': '2099-10-10',
        'status': 'confirmed',
      },
    ],
  };

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  /// เปิดหน้าจากหน้าแรกอีกชั้น เหมือนตอนเปิดจาก deep link จริง (หน้าปิดตัวเองได้)
  /// [act] รันใน zone เดียวกับ MockClient — การกดที่ยิง HTTP ต้องอยู่ในนี้
  Future<AppProvider> pump(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler, {
    bool loggedIn = true,
    Future<void> Function(AppProvider provider)? act,
  }) async {
    late AppProvider provider;
    await http.runWithClient(() async {
      provider = AppProvider();
      if (loggedIn) {
        provider.api.token = 'test-token';
        provider.user = {
          'id': 7,
          'name': 'สมชาย LINE',
          'email': 'line_U123@social.local',
        };
      }
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AccountClaimScreen(token: 'tok'),
                      ),
                    ),
                    child: const Text('เปิดลิงก์'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('เปิดลิงก์'));
      await tester.pumpAndSettle();
      if (act != null) await act(provider);
    }, () => MockClient(handler));
    return provider;
  }

  Future<void> tapAccept(WidgetTester tester) async {
    await tester.ensureVisible(find.text('รับการจองเข้าบัญชีนี้'));
    await tester.tap(find.text('รับการจองเข้าบัญชีนี้'));
    await tester.pumpAndSettle();
  }

  testWidgets('ยังไม่ล็อกอิน เห็นทริปของตัวเอง แล้วถูกชวนให้ล็อกอินก่อนรับ', (
    tester,
  ) async {
    await pump(
      tester,
      (_) async => json({'success': true, 'data': preview}),
      loggedIn: false,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('สวัสดีคุณสมชาย ใจดี'), findsOneWidget);
    expect(find.textContaining('ลงท้าย 5678'), findsOneWidget);
    expect(find.text('ภูกระดึง'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบเพื่อรับการจอง'), findsOneWidget);
    expect(find.text('รับการจองเข้าบัญชีนี้'), findsNothing);
  });

  testWidgets(
    'กดล็อกอิน → เข้าด้วย LINE กลับมาทาง deep link → หน้าล็อกอินปิดเอง เหลือปุ่มรับ',
    (tester) async {
      final provider = await pump(
        tester,
        (_) async => json({'success': true, 'data': preview}),
        loggedIn: false,
      );

      await tester.ensureVisible(find.text('เข้าสู่ระบบเพื่อรับการจอง'));
      await tester.tap(find.text('เข้าสู่ระบบเพื่อรับการจอง'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('สมัครสมาชิกฟรี'), findsOneWidget);

      // completeSocialLogin() ตั้ง token + user แล้ว notify — หน้าล็อกอินไม่รู้ตัว
      // เพราะปุ่ม LINE เลิกหมุนไปตั้งแต่เปิดเบราว์เซอร์ หน้านี้ต้องปิดให้เอง
      provider.api.token = 'test-token';
      provider.user = {'id': 7, 'name': 'สมชาย LINE'};
      provider.notifyListeners();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('สมัครสมาชิกฟรี'), findsNothing);
      expect(find.byType(AccountClaimScreen), findsOneWidget);
      expect(find.text('เข้าสู่ระบบเพื่อรับการจอง'), findsNothing);
      expect(find.text('สมชาย LINE'), findsOneWidget);
      expect(find.text('รับการจองเข้าบัญชีนี้'), findsOneWidget);
    },
  );

  testWidgets('ล็อกอินอยู่ กดรับครั้งเดียว ย้ายเข้าบัญชีแล้วปิดหน้า', (
    tester,
  ) async {
    final posts = <String>[];
    await pump(
      tester,
      (req) async {
        if (req.method == 'POST') posts.add(req.url.path);
        if (req.url.path.endsWith('/account/claim/tok')) {
          return json({'success': true, 'data': preview});
        }
        if (req.url.path.endsWith('/me/claim/tok')) {
          return json({
            'success': true,
            'message': 'รับการจองเข้าบัญชีของคุณแล้ว',
            'data': {'bookings_moved': 1, 'bookings': preview['bookings']},
          });
        }
        return json({'success': true, 'data': <String, dynamic>{}});
      },
      act: (_) async {
        // อีเมลที่ระบบสร้างให้ตอนเข้าด้วย LINE ไม่ใช่ของลูกค้า — ไม่ต้องโชว์
        expect(find.text('สมชาย LINE'), findsOneWidget);
        expect(find.text('line_U123@social.local'), findsNothing);
        await tapAccept(tester);
      },
    );

    expect(tester.takeException(), isNull);
    expect(posts, hasLength(1));
    expect(posts.single, endsWith('/me/claim/tok'));
    expect(find.byType(AccountClaimScreen), findsNothing);
    expect(find.text('รับการจอง 1 รายการเข้าบัญชีของคุณแล้ว'), findsOneWidget);
  });

  testWidgets('มีคนกดรับไปก่อน เห็นข้อความจากเซิร์ฟเวอร์ และยังอยู่หน้าเดิม', (
    tester,
  ) async {
    await pump(tester, (req) async {
      if (req.method == 'POST') {
        return json({'success': false, 'message': 'ลิงก์นี้ถูกใช้ไปแล้ว'}, 422);
      }
      return json({'success': true, 'data': preview});
    }, act: (_) => tapAccept(tester));

    expect(find.byType(AccountClaimScreen), findsOneWidget);
    expect(find.text('ลิงก์นี้ถูกใช้ไปแล้ว'), findsOneWidget);
  });

  testWidgets('เปิดลิงก์ที่ใช้ไปแล้ว บอกว่าใช้แล้ว และพาไปหน้าการจอง', (
    tester,
  ) async {
    await pump(
      tester,
      (_) async => json({
        'success': false,
        'message': 'ลิงก์นี้ใช้ไม่ได้แล้ว อาจถูกใช้ไปแล้วหรือหมดอายุ',
      }, 404),
    );

    expect(find.textContaining('ลิงก์นี้ถูกใช้ไปแล้ว'), findsOneWidget);
    expect(find.text('ไปที่การจองของฉัน'), findsOneWidget);
    expect(find.text('รับการจองเข้าบัญชีนี้'), findsNothing);
  });

  test('ลิงก์ /claim/TOKEN เปิดในแอป แต่หน้า /claim-done ไม่ใช่ของแอป', () {
    expect(
      NotificationNavigator.handleDeepLink(
        Uri.parse('https://luilaykhao.com/claim/abc123'),
      ),
      isTrue,
    );
    expect(
      NotificationNavigator.handleDeepLink(Uri.parse('luilaykhao://claim/abc')),
      isTrue,
    );
    expect(
      NotificationNavigator.handleDeepLink(
        Uri.parse('https://luilaykhao.com/claim-done'),
      ),
      isFalse,
    );
    expect(
      NotificationNavigator.handleDeepLink(
        Uri.parse('https://luilaykhao.com/claim/'),
      ),
      isFalse,
    );
  });
}
