import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/widgets/review_dialog.dart';
import 'package:provider/provider.dart';

/// หน้าต่างรีวิวหลังจบทริป — สิ่งที่ต้องถูกคือ ส่งสำเร็จแล้วต้อง *บอก* ลูกค้า
/// (ไม่ใช่ปิดหายไปเฉย ๆ) และส่งไม่ผ่านต้องเห็นเหตุผลโดยหน้าต่างยังอยู่
void main() {
  Future<void> run(
    WidgetTester tester, {
    required http.Response Function(http.Request) reviewResponse,
    required Future<void> Function() body,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await http.runWithClient(body, () {
      return MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/reviews')) {
          return reviewResponse(request);
        }
        // รีโหลดหลังส่งรีวิว (ทริป/รีวิวของฉัน/ใบจอง) — ตอบลิสต์ว่างพอ
        return http.Response(
          jsonEncode({'success': true, 'data': []}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
    });
  }

  Future<void> openSheet(WidgetTester tester) async {
    final provider = AppProvider();
    provider.api.token = 'test-token';
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => ReviewSubmissionDialog.show(
                    context,
                    bookingId: 42,
                    tripTitle: 'ภูกระดึง',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('ส่งสำเร็จแล้วเปลี่ยนเป็นหน้าขอบคุณ กดเสร็จสิ้นแล้วปิด', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    await run(
      tester,
      reviewResponse: (request) {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'message': 'รีวิวสำเร็จแล้ว', 'data': {}}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      },
      body: () async {
        await openSheet(tester);
        expect(find.text('ทริปนี้เป็นยังไงบ้าง?'), findsOneWidget);
        expect(find.text('ประทับใจมาก'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('ให้ 4 ดาว'));
        await tester.pump();
        expect(find.text('ดีมาก'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'วิวสวยมาก สตาฟใจดี');
        await tester.tap(find.text('ส่งรีวิว'));
        await tester.pumpAndSettle();

        expect(sent?['booking_id'], 42);
        expect(sent?['rating'], 4);
        expect(sent?['comment'], 'วิวสวยมาก สตาฟใจดี');
        expect(find.text('ส่งรีวิวเรียบร้อยแล้ว'), findsOneWidget);
        expect(find.textContaining('"ภูกระดึง"'), findsOneWidget);

        await tester.tap(find.text('เสร็จสิ้น'));
        await tester.pumpAndSettle();
        expect(find.text('ส่งรีวิวเรียบร้อยแล้ว'), findsNothing);
      },
    );
  });

  testWidgets('ข้อความสั้นเกินไป ไม่ส่ง และบอกเหตุผล', (tester) async {
    var calls = 0;
    await run(
      tester,
      reviewResponse: (_) {
        calls++;
        return http.Response('{}', 201);
      },
      body: () async {
        await openSheet(tester);
        await tester.enterText(find.byType(TextField), 'ดี');
        await tester.tap(find.text('ส่งรีวิว'));
        await tester.pumpAndSettle();

        expect(calls, 0);
        expect(
          find.text('กรุณาเขียนรีวิวอย่างน้อย 4 ตัวอักษร'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('เซิร์ฟเวอร์ปฏิเสธ หน้าต่างยังอยู่และเห็นข้อความจากเซิร์ฟเวอร์', (
    tester,
  ) async {
    await run(
      tester,
      reviewResponse: (_) => http.Response(
        jsonEncode({'success': false, 'message': 'คุณรีวิวทริปนี้ไปแล้ว'}),
        422,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
      body: () async {
        await openSheet(tester);
        await tester.enterText(find.byType(TextField), 'สนุกมากครับ');
        await tester.tap(find.text('ส่งรีวิว'));
        await tester.pumpAndSettle();

        expect(find.text('คุณรีวิวทริปนี้ไปแล้ว'), findsOneWidget);
        expect(find.text('ส่งรีวิวเรียบร้อยแล้ว'), findsNothing);
        expect(find.text('ส่งรีวิว'), findsOneWidget);
      },
    );
  });
}
