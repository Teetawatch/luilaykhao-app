import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/chat_food_round.dart';
import 'package:luilaykhao_app/widgets/chat_vote_sheet.dart';

Map<String, dynamic> _round({bool closed = false}) => {
      'id': 7,
      'title': 'มื้อเย็นขากลับ',
      'note': 'จ่ายเองที่ร้าน',
      'is_closed': closed,
      'closes_at': null,
      'order_count': 2,
      'skipped_count': 1,
      'dish_count': 4,
      'orders': [
        {
          'id': 1,
          'user_id': 10,
          'name': 'มิ้นท์',
          'is_guest': false,
          'skipped': false,
          'items': [
            {'name': 'กะเพราหมูสับ ไข่ดาว', 'qty': 1},
            {'name': 'ชาเย็น', 'qty': 1},
          ],
        },
        {
          'id': 2,
          'user_id': 11,
          'name': 'แบงค์',
          'is_guest': false,
          'skipped': false,
          'items': [
            {'name': 'กะเพราหมูสับ ไข่ดาว', 'qty': 2},
          ],
        },
        {
          'id': 3,
          'user_id': 12,
          'name': 'พลอย',
          'is_guest': false,
          'skipped': true,
          'items': [],
        },
      ],
      'summary': [
        {
          'name': 'กะเพราหมูสับ ไข่ดาว',
          'qty': 3,
          'people': ['มิ้นท์', 'แบงค์'],
        },
        {
          'name': 'ชาเย็น',
          'qty': 1,
          'people': ['มิ้นท์'],
        },
      ],
    };

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  test('shop text lists every dish with its count and the total', () {
    expect(
      foodRoundShopText(_round()),
      '🍜 มื้อเย็นขากลับ\n'
      '• กะเพราหมูสับ ไข่ดาว × 3\n'
      '• ชาเย็น × 1\n'
      'รวม 4 จาน',
    );
  });

  test('myFoodOrder finds the viewer by user id', () {
    expect(myFoodOrder(_round(), 11)?['name'], 'แบงค์');
    expect(myFoodOrder(_round(), 99), isNull);
    expect(myFoodOrder(_round(), null), isNull);
  });

  testWidgets('card shows my order, the running total and both actions', (
    tester,
  ) async {
    var ordered = 0;
    await tester.pumpWidget(
      _host(
        ChatFoodRoundCard(
          round: _round(),
          myUserId: 10,
          onOrder: () => ordered++,
          onOpenSummary: () {},
        ),
      ),
    );

    expect(find.text('มื้อเย็นขากลับ'), findsOneWidget);
    expect(find.textContaining('สั่งแล้ว 2 คน · 4 จาน'), findsOneWidget);
    expect(find.text('กะเพราหมูสับ ไข่ดาว, ชาเย็น'), findsOneWidget);
    expect(find.text('แก้ออเดอร์'), findsOneWidget);

    await tester.tap(find.text('แก้ออเดอร์'));
    expect(ordered, 1);
  });

  testWidgets('closed card hides the order button but keeps the summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatFoodRoundCard(
          round: _round(closed: true),
          myUserId: 99,
          onOrder: () {},
          onOpenSummary: () {},
        ),
      ),
    );

    expect(find.text('สั่งอาหาร'), findsNothing);
    expect(find.text('คุณไม่ได้สั่งรอบนี้'), findsOneWidget);
    expect(find.text('ดูรายการรวม'), findsOneWidget);
  });

  testWidgets('order sheet offers what friends ordered as one-tap chips', (
    tester,
  ) async {
    FoodOrderDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<FoodOrderDraft>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => FoodOrderSheet(round: _round()),
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

    await tester.tap(find.widgetWithText(ActionChip, 'ชาเย็น'));
    await tester.pump();
    await tester.tap(find.text('ส่งออเดอร์'));
    await tester.pumpAndSettle();

    expect(result?.items, [
      {'name': 'ชาเย็น', 'qty': 1},
    ]);
    expect(result?.skipped, isFalse);
  });

  testWidgets('summary sheet lists who has not ordered yet', (tester) async {
    final round = ValueNotifier<Map<String, dynamic>?>(_round());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodRoundSummarySheet(
            round: round,
            travellers: const [
              {'id': 10, 'name': 'มิ้นท์'},
              {'id': 12, 'name': 'พลอย'},
              {'id': 13, 'name': 'โอ๊ต'},
            ],
            canManage: true,
            myUserId: 10,
            onDeleteOrder: (_) async {},
            onAddOnBehalf: () async {},
            onSetClosed: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('ยังไม่สั่ง 1 คน'), findsOneWidget);
    expect(find.text('โอ๊ต'), findsOneWidget);
    expect(find.text('ปิดรับ แล้วไปสั่ง'), findsOneWidget);

    // realtime อัปเดตเข้ามา → ชีตวาดใหม่เอง
    round.value = {..._round(closed: true)};
    await tester.pump();
    expect(find.text('เปิดรับต่อ'), findsOneWidget);
  });

  testWidgets('vote sheet defaults to agree/disagree with a 10-minute window', (
    tester,
  ) async {
    VoteDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<VoteDraft>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const CreateVoteSheet(),
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

    await tester.enterText(find.byType(TextField).first, 'แวะคาเฟ่ไหม');
    await tester.pump();
    await tester.tap(find.text('เริ่มโหวต'));
    await tester.pumpAndSettle();

    expect(result?.question, 'แวะคาเฟ่ไหม');
    expect(result?.options, isEmpty);
    expect(result?.minutes, 10);
  });
}
