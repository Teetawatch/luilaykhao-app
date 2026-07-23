import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/screens/payment_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

PaymentSubmittedScreen _screen({
  PaymentSubmissionKind kind = PaymentSubmissionKind.initial,
  int? installmentNo,
}) {
  return PaymentSubmittedScreen(
    bookingRef: 'LLK-20260723-0421',
    amount: 4300,
    kind: kind,
    paymentMethod: 'promptpay',
    transferredAt: DateTime(2026, 7, 23, 14, 30),
    installmentNo: installmentNo,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  testWidgets('shows the amount, booking ref and next steps', (tester) async {
    await tester.pumpWidget(_wrap(_screen()));
    await tester.pumpAndSettle();

    expect(find.text('แจ้งชำระเงินแล้ว'), findsOneWidget);
    expect(find.text('LLK-20260723-0421'), findsOneWidget);
    expect(find.text('ชำระเต็มจำนวน'), findsOneWidget);
    expect(find.text('QR PromptPay'), findsOneWidget);
    // เวลาที่โอนตามสลิป — วัน/เดือนไทย + ปี พ.ศ.
    expect(find.text('23 ก.ค. 2569 14:30'), findsOneWidget);

    // ไทม์ไลน์ 3 ขั้น จบด้วย "ยืนยันการจอง" สำหรับการจองใหม่
    expect(find.text('แจ้งชำระเงิน'), findsOneWidget);
    expect(find.text('ทีมงานตรวจสอบสลิป'), findsOneWidget);
    expect(find.text('ยืนยันการจอง'), findsOneWidget);
    expect(find.text('กำลังดำเนินการ'), findsOneWidget);

    // บอกว่าไม่ต้องเฝ้าหน้านี้ เดี๋ยวมีแจ้งเตือนตามไป
    expect(find.text('เราจะแจ้งให้ทราบเอง'), findsOneWidget);
    expect(find.text('ดูการจองของฉัน'), findsOneWidget);
  });

  testWidgets('installment payment names the instalment it settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _screen(kind: PaymentSubmissionKind.installment, installmentNo: 2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ชำระงวดที่ 2'), findsOneWidget);
    expect(find.text('บันทึกงวดที่ 2'), findsOneWidget);
    expect(find.text('ยืนยันการจอง'), findsNothing);
  });

  testWidgets('lays out on a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(_screen(kind: PaymentSubmissionKind.share)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ชำระส่วนของคุณ (แบ่งจ่ายกลุ่ม)'), findsOneWidget);
  });
}
