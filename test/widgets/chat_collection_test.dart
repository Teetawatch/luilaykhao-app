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
    {
      'passenger_id': 1,
      'name': 'พ่อ',
      'user_id': 10,
      'amount': 200,
      'status': 'unpaid',
    },
    {
      'passenger_id': 2,
      'name': 'แม่',
      'user_id': 10,
      'amount': 200,
      'status': 'claimed',
    },
    {
      'passenger_id': 3,
      'name': 'มานะ',
      'user_id': 11,
      'amount': 200,
      'status': 'paid',
    },
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

  Map<String, dynamic> slipCollection() => {
    ..._collection(),
    'collected': 200,
    'collected_cash': 200,
    'dues': [
      {
        'passenger_id': 1,
        'name': 'พ่อ',
        'user_id': 10,
        'amount': 200,
        'status': 'claimed',
        'has_slip': true,
      },
      {
        'passenger_id': 2,
        'name': 'แม่',
        'user_id': 10,
        'amount': 200,
        'status': 'claimed',
        'has_slip': true,
      },
      {
        'passenger_id': 3,
        'name': 'มานะ',
        'user_id': 11,
        'amount': 200,
        'status': 'paid',
        'method': 'cash',
        'marked_by': 'พี่หมู',
      },
      {
        'passenger_id': 4,
        'name': 'ชูใจ',
        'user_id': 12,
        'amount': 200,
        'status': 'unpaid',
        'has_slip': false,
      },
    ],
  };

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'staff confirm a slip for everyone it covers, cash shows who took it',
    (tester) async {
      tallScreen(tester);
      final calls = <String>[];
      final requested = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectionListSheet(
              collection: ValueNotifier(slipCollection()),
              canManage: true,
              onSetPaid: (ids, paid, method, reason) async =>
                  calls.add('$ids $paid $method'),
              onSetClosed: (_) async {},
              onEditPayers: () async {},
              // ไม่มีลิงก์ = ไม่แตะเน็ตในเทส
              onLoadSlip: (id) async {
                requested.add(id);
                return null;
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('เงินสด ฿200'), findsOneWidget);
      expect(find.text('รับโดย พี่หมู'), findsOneWidget);
      expect(find.textContaining('แนบสลิปแล้ว'), findsNWidgets(2));

      await tester.tap(find.text('พ่อ'));
      await tester.pumpAndSettle();
      expect(requested, [1]);
      expect(find.text('ยอดในสลิปควรเป็น ฿400 (2 คน)'), findsOneWidget);
      await tester.tap(find.text('ยืนยันยอดโอน ฿400'));
      await tester.pumpAndSettle();
      expect(calls, ['[1, 2] true transfer']);
    },
  );

  testWidgets('rejecting a slip asks why and sends it back for the group', (
    tester,
  ) async {
    tallScreen(tester);
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionListSheet(
            collection: ValueNotifier(slipCollection()),
            canManage: true,
            onSetPaid: (ids, paid, method, reason) async =>
                calls.add('$ids $paid $method $reason'),
            onSetClosed: (_) async {},
            onEditPayers: () async {},
            onLoadSlip: (_) async => null,
          ),
        ),
      ),
    );

    await tester.tap(find.text('แม่'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('สลิปไม่ถูกต้อง ให้แนบใหม่'));
    await tester.pumpAndSettle();
    expect(find.text('สลิปไม่ผ่านเพราะอะไร'), findsOneWidget);
    await tester.tap(find.text('ยอดในสลิปไม่ตรง'));
    await tester.pumpAndSettle();
    expect(calls, ['[1, 2] false null ยอดในสลิปไม่ตรง']);
  });

  testWidgets('no slip means no transfer confirm — only cash', (tester) async {
    tallScreen(tester);
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionListSheet(
            collection: ValueNotifier(slipCollection()),
            canManage: true,
            onSetPaid: (ids, paid, method, reason) async =>
                calls.add('$ids $paid $method'),
            onSetClosed: (_) async {},
            onEditPayers: () async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('ชูใจ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ยืนยันยอดโอน ฿'), findsNothing);
    expect(find.textContaining('ยังไม่มีสลิป'), findsOneWidget);
    await tester.tap(find.text('รับเงินสด ฿200'));
    await tester.pumpAndSettle();
    expect(calls, ['[4] true cash']);
  });

  testWidgets('pay sheet asks for a slip instead of a bare "transferred"', (
    tester,
  ) async {
    tallScreen(tester);
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showCollectionPaySheet(
                context,
                _collection(),
                10,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('โอนแล้ว แจ้งทีมงาน'), findsNothing);
    await tester.tap(find.text('แนบสลิปแจ้งโอน'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('weight-based collections do not claim one price for everyone', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatCollectionCard(
          collection: {..._collection(), 'amount': 0, 'amounts_vary': true},
          myUserId: 10,
          canManage: false,
          onPay: () {},
          onOpenList: () {},
        ),
      ),
    );

    expect(find.textContaining('ยอดแต่ละคนไม่เท่ากัน'), findsOneWidget);
    expect(find.textContaining('คนละ'), findsNothing);
  });
}
