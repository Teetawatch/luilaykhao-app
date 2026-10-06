import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/gift_voucher_purchase_screen.dart';
import 'package:luilaykhao_app/screens/gift_voucher_screen.dart';
import 'package:provider/provider.dart';

/// บัตรของขวัญ — หน้ารวม (กระเป๋า/บัตรที่ซื้อ/เพิ่มด้วยรหัส) และหน้าซื้อ
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  Map<String, dynamic> voucher({
    required int id,
    String status = 'active',
    num amount = 1000,
    num balance = 1000,
    bool isOwner = true,
    bool isPurchaser = false,
  }) => {
    'id': id,
    'code': status == 'active' ? 'GVABCDEFGH$id' : null,
    'display_code': status == 'active' ? 'GV-ABCDE-FGH$id' : null,
    'amount': amount,
    'balance': balance,
    'status': status,
    'design': 'forest',
    'recipient_name': 'น้องมายด์',
    'from_name': 'พี่หมี',
    'is_owner': isOwner,
    'is_purchaser': isPurchaser,
    'for_self': false,
    'claimed': isOwner,
    'can_pay': isPurchaser && status == 'pending',
    'expires_at': '2099-01-10T00:00:00Z',
  };

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  http.Response ok(Object data, {String message = 'สำเร็จ'}) => http.Response(
    jsonEncode({'success': true, 'data': data, 'message': message}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<List<http.Request>> pump(
    WidgetTester tester,
    Widget home,
    Future<http.Response> Function(http.Request) handler, {
    Future<void> Function()? then,
  }) async {
    final requests = <http.Request>[];
    final app = AppProvider();
    app.api.token = 'test-token';

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: app,
            child: MaterialApp(home: home),
          ),
        );
        await tester.pumpAndSettle();
        if (then != null) await then();
      },
      () => MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
    );
    return requests;
  }

  testWidgets(
    'แยกบัตรในบัญชีกับบัตรที่ซื้อให้คนอื่น และบอกบัตรที่ยังไม่ได้จ่าย',
    (tester) async {
      await pump(tester, const GiftVoucherScreen(), (request) async {
        return ok({
          'wallet': [voucher(id: 1, balance: 400)],
          'purchased': [
            voucher(
              id: 2,
              status: 'pending',
              isOwner: false,
              isPurchaser: true,
              amount: 2000,
              balance: 0,
            ),
          ],
          'config': {'min_amount': 300, 'max_amount': 50000},
        });
      });

      expect(tester.takeException(), isNull);
      expect(find.text('บัตรของฉัน'), findsOneWidget);
      expect(find.text('฿400', skipOffstage: false), findsOneWidget);
      expect(find.text('บัตรที่ฉันซื้อ', skipOffstage: false), findsOneWidget);
      expect(
        find.text('ยังไม่ได้ชำระเงิน แตะเพื่อชำระ', skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets('กรอกรหัสแล้วเพิ่มบัตรเข้าบัญชีได้', (tester) async {
    final requests = await pump(
      tester,
      const GiftVoucherScreen(),
      (request) async {
        final path = request.url.path;
        if (path.endsWith('/gift-vouchers/lookup')) {
          return ok({
            'code': 'GVABCDEFGHJK',
            'display_code': 'GV-ABCDE-FGHJK',
            'amount': 1500,
            'balance': 1500,
            'status': 'active',
            'from_name': 'พี่หมี',
            'message': 'เที่ยวให้สนุกนะ',
            'owned_by_me': false,
            'owned_by_other': false,
            'usable': true,
          });
        }
        if (path.endsWith('/gift-vouchers/claim')) {
          return ok(voucher(id: 9, amount: 1500, balance: 1500));
        }
        return ok({'wallet': [], 'purchased': [], 'config': {}});
      },
      then: () async {
        await tester.enterText(find.byType(TextField).first, 'gv-abcde-fghjk');
        await tester.tap(find.text('ตรวจสอบ'));
        await tester.pumpAndSettle();

        expect(find.text('"เที่ยวให้สนุกนะ"'), findsOneWidget);
        await scrollTo(tester, find.text('เพิ่มบัตรเข้าบัญชี'));
        await tester.tap(find.text('เพิ่มบัตรเข้าบัญชี'));
        await tester.pumpAndSettle();
      },
    );

    expect(tester.takeException(), isNull);
    final claim = requests.firstWhere(
      (r) => r.url.path.endsWith('/gift-vouchers/claim'),
    );
    expect(jsonDecode(claim.body)['code'], 'GVABCDEFGHJK');
    // โหลดรายการใหม่หลังเพิ่มบัตร
    expect(
      requests.where((r) => r.url.path.endsWith('/gift-vouchers')).length,
      2,
    );
  });

  testWidgets('รหัสของบัญชีอื่นไม่มีปุ่มเพิ่มบัตร', (tester) async {
    await pump(tester, const GiftVoucherScreen(initialCode: 'GVABCDEFGHJK'), (
      request,
    ) async {
      if (request.url.path.endsWith('/lookup')) {
        return ok({
          'code': 'GVABCDEFGHJK',
          'amount': 1500,
          'balance': null,
          'status': 'active',
          'owned_by_me': false,
          'owned_by_other': true,
          'usable': false,
        });
      }
      return ok({'wallet': [], 'purchased': [], 'config': {}});
    });

    expect(tester.takeException(), isNull);
    expect(find.text('บัตรนี้ถูกเพิ่มเข้าบัญชีอื่นไปแล้ว'), findsOneWidget);
    expect(find.text('เพิ่มบัตรเข้าบัญชี'), findsNothing);
  });

  testWidgets(
    'ซื้อบัตร: ยอดที่พิมพ์เองนอกช่วงถูกปฏิเสธ ยอดถูกส่งไปสร้างบัตรแล้วเห็น QR',
    (tester) async {
      final requests = await pump(
        tester,
        const GiftVoucherPurchaseScreen(
          config: {
            'min_amount': 300,
            'max_amount': 50000,
            'presets': [500, 1000],
            'designs': ['forest', 'ocean'],
          },
        ),
        (request) async => ok({
          'voucher': voucher(
            id: 5,
            status: 'pending',
            amount: 750,
            balance: 0,
            isOwner: false,
            isPurchaser: true,
          ),
          'payment': {
            'voucher_id': 5,
            'amount': 750,
            'qr_payload': '00020101021229370016A000000677010111',
            'promptpay_id': '004-99923936-2071',
            'bank_name': 'ธนาคารกสิกรไทย',
            'bank_account': '230-139095-8',
            'bank_holder': 'ลุยเลเขา',
          },
        }),
        then: () async {
          final custom = find.widgetWithText(
            TextFormField,
            'หรือระบุมูลค่าเอง (บาท)',
          );
          await tester.enterText(custom, '100');
          await tester.pump();
          await scrollTo(tester, find.textContaining('ไปชำระเงิน'));
          await tester.tap(find.textContaining('ไปชำระเงิน'));
          await tester.pumpAndSettle();
          expect(find.text('มูลค่าขั้นต่ำ ฿300'), findsOneWidget);
          // รอให้แถบแจ้งเตือนหายก่อน ไม่งั้นมันบังปุ่ม
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpAndSettle();

          await tester.enterText(custom, '750');
          await tester.pump();
          await tester.enterText(
            find.widgetWithText(TextFormField, 'ชื่อผู้รับ (แสดงบนบัตร)'),
            'น้องมายด์',
          );
          await scrollTo(tester, find.text('ไปชำระเงิน ฿750'));
          await tester.tap(find.text('ไปชำระเงิน ฿750'));
          await tester.pumpAndSettle();
        },
      );

      expect(tester.takeException(), isNull);
      expect(requests, hasLength(1));
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['amount'], 750);
      expect(body['for_self'], false);
      expect(body['recipient_name'], 'น้องมายด์');
      // ขั้นจ่ายเงิน: ยอดและ QR จากหลังบ้าน ปุ่มส่งสลิปยังกดไม่ได้จนแนบรูป
      expect(find.text('ยอดที่ต้องโอน'), findsOneWidget);
      expect(find.text('฿750'), findsWidgets);
      expect(find.text('230-139095-8'), findsOneWidget);
      await scrollTo(tester, find.text('ส่งสลิป'));
      final submit = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('ส่งสลิป'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(submit.onPressed, isNull);
    },
  );
}
