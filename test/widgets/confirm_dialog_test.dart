import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/confirm_dialog.dart';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('หน้าแรก')),
      ),
    );
  }

  Future<bool> open({
    String confirmLabel = 'ลบ',
    String? cancelLabel = 'ยกเลิก',
    String? detail,
  }) {
    return showConfirmDialog(
      navigatorKey.currentContext!,
      title: 'ลบเอกสารนี้?',
      message: 'ลบแล้วต้องแนบใหม่ครับ',
      detail: detail,
      tone: ConfirmTone.danger,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    );
  }

  testWidgets('confirm resolves true', (tester) async {
    await pumpHost(tester);
    final result = open(detail: 'passport.pdf');
    await tester.pumpAndSettle();

    expect(find.text('ลบเอกสารนี้?'), findsOneWidget);
    expect(find.text('ลบแล้วต้องแนบใหม่ครับ'), findsOneWidget);
    expect(find.text('passport.pdf'), findsOneWidget);

    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('cancel resolves false', (tester) async {
    await pumpHost(tester);
    final result = open();
    await tester.pumpAndSettle();

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('tapping outside the card counts as cancel', (tester) async {
    await pumpHost(tester);
    final result = open();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('ลบเอกสารนี้?'), findsNothing);
    expect(await result, isFalse);
  });

  testWidgets('short labels sit side by side, cancel first', (tester) async {
    await pumpHost(tester);
    open();
    await tester.pumpAndSettle();

    final cancel = tester.getCenter(find.text('ยกเลิก'));
    final confirm = tester.getCenter(find.text('ลบ'));
    expect(cancel.dy, confirm.dy);
    expect(cancel.dx, lessThan(confirm.dx));
  });

  testWidgets('long labels stack with confirm on top instead of wrapping', (
    tester,
  ) async {
    await pumpHost(tester);
    open(confirmLabel: 'ยกเลิกการแบ่งจ่าย', cancelLabel: 'ไม่ยกเลิก');
    await tester.pumpAndSettle();

    final confirm = tester.getCenter(find.text('ยกเลิกการแบ่งจ่าย'));
    final cancel = tester.getCenter(find.text('ไม่ยกเลิก'));
    expect(confirm.dy, lessThan(cancel.dy));
    expect(confirm.dx, cancel.dx);
  });

  testWidgets('a null cancel label shows a single acknowledgement button', (
    tester,
  ) async {
    await pumpHost(tester);
    final result = open(confirmLabel: 'ตกลง', cancelLabel: null);
    await tester.pumpAndSettle();

    expect(find.byType(TextButton), findsNothing);
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });
}
