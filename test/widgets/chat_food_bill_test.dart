import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/chat_food_bill.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('baht drops satang only when there are none', () {
    expect(baht(110), '฿110');
    expect(baht('1250.00'), '฿1,250');
    expect(baht(62.5), '฿62.50');
    expect(baht(1234567), '฿1,234,567');
  });

  testWidgets('my bill row shows the amount, status and a pay button', (
    tester,
  ) async {
    var paid = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyFoodBillRow(
            order: const {
              'amount': 110,
              'balance': 110,
              'pay_status': 'unpaid',
              'promptpay_payload': '000201...',
            },
            onPay: () => paid++,
          ),
        ),
      ),
    );

    expect(find.textContaining('ยอดของคุณ ฿110'), findsOneWidget);
    expect(find.textContaining('ยังไม่จ่าย'), findsOneWidget);
    await tester.tap(find.text('จ่ายเงิน'));
    expect(paid, 1);
  });

  testWidgets('paid bill has no pay button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyFoodBillRow(
            order: const {'amount': 110, 'pay_status': 'paid'},
            onPay: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('จ่ายแล้ว'), findsOneWidget);
    expect(find.text('จ่ายเงิน'), findsNothing);
  });

  testWidgets('bill sheet totals live and only sends once every dish is priced', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);
    FoodBillDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<FoodBillDraft>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const FoodBillSheet(
                    round: {
                      'summary': [
                        {'name': 'กะเพราหมูสับ', 'qty': 3, 'price': null},
                        {'name': 'ชาเย็น', 'qty': 2, 'price': 25},
                      ],
                    },
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // ชาเย็นมีราคาเดิม 25 × 2 แต่กะเพรายังไม่มีราคา → ส่งยอดไม่ได้
    expect(find.text('ส่งยอดให้ทุกคน · รวม ฿50'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '60');
    await tester.enterText(fields.at(2), '081-234-5678');
    await tester.pump();
    expect(find.text('ส่งยอดให้ทุกคน · รวม ฿230'), findsOneWidget);

    await tester.tap(find.text('ส่งยอดให้ทุกคน · รวม ฿230'));
    await tester.pumpAndSettle();

    expect(result?.notify, isTrue);
    expect(result?.promptPayId, '0812345678');
    expect(result?.prices, [
      {'name': 'กะเพราหมูสับ', 'price': 60.0},
      {'name': 'ชาเย็น', 'price': 25.0},
    ]);
  });
}
