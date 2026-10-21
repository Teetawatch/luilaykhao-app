import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/screens/onsite_money_screen.dart';

Map<String, dynamic> _summary(String status, {bool frozen = false}) => {
  'schedule': {'id': 1, 'trip_title': 'ภูกระดึง 2 วัน'},
  'is_frozen': frozen,
  'totals': {
    'collected': 1000,
    'cash': 400,
    'transfer': 600,
    'outstanding': 200,
    'food_collected': 60,
    'food_outstanding': 60,
  },
  'mine': {
    'user_id': 7,
    'name': 'พี่ไก่',
    'cash': 400,
    'transfer': 0,
    'total': 400,
    'promptpay': null,
    'status': status,
    'handover': status == 'pending'
        ? null
        : {'total': 300, 'received_by': 'พี่บัญชี'},
  },
  'holders': [
    {
      'user_id': 5,
      'name': 'พี่หมู',
      'cash': 0,
      'transfer': 600,
      'total': 600,
      'promptpay': '081-xxx-5678',
      'status': 'submitted',
    },
    {
      'user_id': 7,
      'name': 'พี่ไก่',
      'cash': 400,
      'transfer': 0,
      'total': 400,
      'promptpay': null,
      'status': status,
    },
  ],
  'collections': [
    {
      'id': 3,
      'title': 'ค่าอุทยาน',
      'receiver': 'พี่หมู',
      'total': 900,
      'collected': 900,
      'cash': 300,
      'transfer': 600,
      'outstanding': 0,
      'unpaid': [],
    },
    {
      'id': 4,
      'title': 'ทิปไกด์',
      'receiver': 'พี่ไก่',
      'total': 300,
      'collected': 100,
      'cash': 100,
      'transfer': 0,
      'outstanding': 200,
      'unpaid': [
        {'name': 'แม่', 'amount': 100, 'claimed': true},
        {'name': 'มานะ', 'amount': 100, 'claimed': false},
      ],
    },
  ],
  'food': [
    {
      'id': 9,
      'title': 'มื้อเย็น',
      'total': 120,
      'collected': 60,
      'outstanding': 60,
      'owing_count': 1,
    },
  ],
};

Widget _host(
  Map<String, dynamic> data,
  ValueChanged<Map<String, dynamic>> onSubmit,
) => MaterialApp(
  home: Scaffold(
    body: OnsiteMoneyView(data: data, onSubmit: onSubmit),
  ),
);

void main() {
  testWidgets('shows who holds what and lets me send my money', (tester) async {
    final sent = <dynamic>[];
    await tester.pumpWidget(
      _host(_summary('pending'), (m) => sent.add(m['total'])),
    );

    expect(find.text('เงินที่คุณถือ'), findsOneWidget);
    expect(find.text('ยังไม่ได้ส่ง'), findsWidgets);
    expect(find.text('โอน ฿600 (081-xxx-5678)'), findsOneWidget);
    final unpaid = find.textContaining('ยังไม่จ่าย: แม่ ฿100 (แนบสลิปแล้ว), มานะ ฿100');
    await tester.scrollUntilVisible(unpaid, 200);
    expect(unpaid, findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('ค่าอาหาร (ไม่นับในยอดส่งบริษัท)'),
      200,
    );
    expect(find.text('฿60/฿120 · ค้าง 1 คน'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('ยืนยันส่งเงินให้บริษัท'), -200);
    await tester.tap(find.text('ยืนยันส่งเงินให้บริษัท'));
    expect(sent, [400]);
  });

  testWidgets(
    'a changed amount asks to send again, received shows who took it',
    (tester) async {
      await tester.pumpWidget(_host(_summary('changed'), (_) {}));
      expect(find.text('ส่งยอดใหม่ ฿400'), findsOneWidget);
      expect(
        find.textContaining('ยอดเปลี่ยนหลังส่ง ต้องส่งใหม่ · ส่งไว้ ฿300'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _host(_summary('received', frozen: true), (_) {}),
      );
      await tester.pump();
      expect(
        find.textContaining('การเงินรับแล้ว · โดย พี่บัญชี'),
        findsOneWidget,
      );
      expect(find.text('ยืนยันส่งเงินให้บริษัท'), findsNothing);
      expect(
        find.textContaining('ห้องแชทของรอบนี้ถูกล้างแล้ว'),
        findsOneWidget,
      );
    },
  );
}
