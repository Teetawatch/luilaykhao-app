import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/widgets/gift_voucher_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  group('voucherCoverage (ต้องตรงกับ BookingService)', () {
    test('บัตรน้อยกว่ายอด = หักเท่ายอดบัตร', () {
      expect(voucherCoverage(1500, 1000), 1000);
    });
    test('บัตรมากกว่ายอด = หักแค่ยอดที่ต้องจ่าย', () {
      expect(voucherCoverage(1500, 5000), 1500);
    });
    test('ไม่มีบัตร / ยอดเป็นศูนย์ = ไม่หัก', () {
      expect(voucherCoverage(1500, null), 0);
      expect(voucherCoverage(1500, 0), 0);
      expect(voucherCoverage(0, 1000), 0);
      expect(voucherCoverage(-10, 1000), 0);
    });
  });

  test('formatVoucherCode ใส่ขีดแบบเดียวกับหลังบ้าน', () {
    expect(formatVoucherCode('GVABCDEFGHJK'), 'GV-ABCDE-FGHJK');
    expect(formatVoucherCode('gv-abcde fghjk'), 'GV-ABCDE-FGHJK');
    expect(formatVoucherCode('SAVE200'), 'SAVE200');
  });

  test('voucherBaht ไม่โชว์ .00', () {
    expect(voucherBaht(2000), '฿2,000');
    expect(voucherBaht('1250.5'), '฿1,250.50');
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }

  testWidgets('การ์ดบัตรที่ใช้ไปบางส่วนโชว์ยอดคงเหลือและมูลค่าเดิม', (
    tester,
  ) async {
    await pump(
      tester,
      GiftVoucherCard.fromJson({
        'amount': 2000,
        'balance': 500,
        'status': 'active',
        'design': 'ocean',
        'recipient_name': 'น้องมายด์',
        'from_name': 'พี่หมี',
        'display_code': 'GV-ABCDE-FGHJK',
        'expires_at': '2099-01-10T00:00:00Z',
      }),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('คงเหลือ'), findsOneWidget);
    expect(find.text('฿500'), findsOneWidget);
    expect(find.text('จากมูลค่า ฿2,000'), findsOneWidget);
    expect(find.text('สำหรับ น้องมายด์'), findsOneWidget);
    expect(find.text('GV-ABCDE-FGHJK'), findsOneWidget);
  });

  testWidgets('บัตรที่รอจ่ายโชว์ป้ายสถานะและไม่มีรหัส', (tester) async {
    await pump(
      tester,
      GiftVoucherCard.fromJson({
        'amount': 1000,
        'balance': 0,
        'status': 'pending',
        'design': 'unknown-design',
        'display_code': null,
      }),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('รอชำระเงิน'), findsOneWidget);
    expect(find.text('มูลค่า'), findsOneWidget);
    expect(find.text('฿1,000'), findsOneWidget);
  });

  testWidgets('การ์ดไม่ล้นจอแคบและตัวหนังสือใหญ่', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: GiftVoucherCard.fromJson({
              'amount': 50000,
              'balance': 49999.5,
              'status': 'active',
              'recipient_name':
                  'ชื่อผู้รับที่ยาวมากเป็นพิเศษเพื่อทดสอบการตัดคำ',
              'from_name': 'ชื่อผู้ให้ที่ยาวมากเป็นพิเศษเพื่อทดสอบการตัดคำ',
              'display_code': 'GV-ABCDE-FGHJK',
              'expires_at': '2099-12-31T00:00:00Z',
            }),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
