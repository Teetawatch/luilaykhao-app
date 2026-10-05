import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/chat_collection.dart';

Map<String, dynamic> _collection({bool closed = false, bool withQr = true}) => {
      'id': 5,
      'title': 'ค่าลูกหาบ',
      'note': null,
      'amount': 200,
      'promptpay_id': withQr ? '0812345678' : null,
      'payee_name': 'พี่สตาฟ',
      'is_closed': closed,
      'total': 600,
      'collected': 200,
      'outstanding': 400,
      'unpaid_count': 2,
      'dues': [
        {'passenger_id': 1, 'name': 'พ่อ', 'user_id': 10, 'amount': 200, 'status': 'unpaid'},
        {'passenger_id': 2, 'name': 'แม่', 'user_id': 10, 'amount': 200, 'status': 'claimed'},
        {'passenger_id': 3, 'name': 'มานะ', 'user_id': 11, 'amount': 200, 'status': 'paid'},
      ],
      'payloads': withQr ? {'10': '000201...'} : {},
    };

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  test('my status needs every open due claimed before it reads claimed', () {
    final c = _collection();
    expect(myCollectionStatus(myCollectionDues(c, 10)), 'unpaid');
    expect(myCollectionStatus(myCollectionDues(c, 11)), 'paid');
    expect(myCollectionDues(c, 99), isEmpty);
  });

  testWidgets('group owner sees the group total and a pay button', (
    tester,
  ) async {
    var paid = 0;
    await tester.pumpWidget(
      _host(
        ChatCollectionCard(
          collection: _collection(),
          myUserId: 10,
          canManage: false,
          onPay: () => paid++,
          onOpenList: () {},
        ),
      ),
    );

    expect(find.text('ค่าลูกหาบ'), findsOneWidget);
    expect(find.textContaining('ยอดของคุณ ฿400 (2 คน)'), findsOneWidget);
    await tester.tap(find.text('จ่ายเงิน'));
    expect(paid, 1);
  });

  testWidgets('cash-only collection tells people to pay staff', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatCollectionCard(
          collection: _collection(withQr: false),
          myUserId: 10,
          canManage: false,
          onPay: () {},
          onOpenList: () {},
        ),
      ),
    );

    expect(find.text('จ่ายเงินสดกับน้องสตาฟได้เลย'), findsOneWidget);
    expect(find.text('จ่ายเงิน'), findsNothing);
  });

  testWidgets('paid person sees their full amount marked paid', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatCollectionCard(
          collection: _collection(),
          myUserId: 11,
          canManage: true,
          onPay: () {},
          onOpenList: () {},
        ),
      ),
    );

    expect(find.textContaining('ยอดของคุณ ฿200'), findsOneWidget);
    expect(find.textContaining('จ่ายแล้ว'), findsOneWidget);
    expect(find.text('เช็คยอด'), findsOneWidget);
  });
}
