import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/chat_rest_stop.dart';
import 'package:luilaykhao_app/widgets/chat_vote_sheet.dart';

/// จอเล็ก + คีย์บอร์ดขึ้น ชีตดันจนเกือบเต็มจอ — ต้องมีปุ่มปิดให้กดได้เสมอ
void main() {
  Future<Object?> openOnSmallPhone(WidgetTester tester, Widget sheet) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    // คีย์บอร์ดกินครึ่งล่างของจอ
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);

    Object? result = 'ยังไม่ปิด';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<Object>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => sheet,
                  );
                },
                child: const Text('เปิด'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final close = find.byTooltip('ปิด');
    expect(close, findsOneWidget);
    // ปุ่มต้องอยู่ในจอ ไม่ถูกดันหลุดขอบบน
    expect(tester.getTopLeft(close).dy, greaterThanOrEqualTo(0));

    await tester.tap(close);
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('ชีตโหวตตัดสินปิดได้ด้วยปุ่มมุมขวาบน', (tester) async {
    final result = await openOnSmallPhone(tester, const CreateVoteSheet());

    expect(find.byType(CreateVoteSheet), findsNothing);
    expect(result, isNull);
  });

  testWidgets('ชีตที่ใช้กรอบร่วม (นัดเวลากลับรถ) ปิดได้เหมือนกัน', (
    tester,
  ) async {
    final result = await openOnSmallPhone(tester, const OpenRestStopSheet());

    expect(find.byType(OpenRestStopSheet), findsNothing);
    expect(result, isNull);
  });
}
