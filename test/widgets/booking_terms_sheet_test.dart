import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/widgets/booking_terms_sheet.dart';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  const lines = [
    'หากผู้เดินทางขอยกเลิกเอง ทีมงานขอสงวนสิทธิ์ไม่คืนเงินมัดจำและค่าทริป',
    'หากรอบเดินทางต้องยกเลิกหรือเลื่อนเพราะเหตุสุดวิสัย ทีมงานจะเลื่อนวันเดินทางให้',
  ];

  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  Future<Future<bool>> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('หน้าจอง')),
      ),
    );
    final result = BookingTermsSheet.show(
      navigatorKey.currentContext!,
      lines: lines,
      version: '2026-09-29',
      summary: '2 ท่าน · ฿3,000',
    );
    await tester.pumpAndSettle();
    return result;
  }

  FilledButton confirmButton(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'ยืนยันการจอง'));

  testWidgets('shows every line, the version, and the booking summary', (
    tester,
  ) async {
    await open(tester);

    for (final line in lines) {
      expect(find.text(line), findsOneWidget);
    }
    expect(find.text('เงื่อนไขฉบับวันที่ 29 กันยายน 2569'), findsOneWidget);
    expect(find.text('สรุปการจอง: 2 ท่าน · ฿3,000'), findsOneWidget);
  });

  // ยืนยันได้ก็ต่อเมื่อติ๊กยอมรับ — ไม่งั้นหลักฐานว่า "ยอมรับแล้ว" ไม่มีความหมาย
  testWidgets('cannot confirm until the customer ticks the agreement', (
    tester,
  ) async {
    final result = await open(tester);

    expect(confirmButton(tester).onPressed, isNull);

    await tester.tap(
      find.text('ข้าพเจ้าได้อ่านและยอมรับเงื่อนไขข้างต้นทุกข้อแล้ว'),
    );
    await tester.pumpAndSettle();
    expect(confirmButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('ยืนยันการจอง'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('cancelling returns false', (tester) async {
    final result = await open(tester);

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('unticking again disables the confirm button', (tester) async {
    await open(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(confirmButton(tester).onPressed, isNull);
  });
}
