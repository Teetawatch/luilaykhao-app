import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/chat_requests.dart';

const _kinds = [
  {'key': 'toilet', 'label': 'ขอแวะห้องน้ำ', 'emoji': '🚻'},
  {'key': 'too_cold', 'label': 'แอร์หนาวไป', 'emoji': '🥶'},
  {'key': 'too_hot', 'label': 'แอร์ร้อนไป', 'emoji': '🥵'},
];

const _items = [
  {'key': 'motion_sickness', 'label': 'ยาแก้เมารถ', 'emoji': '💊'},
  {'key': 'other', 'label': 'อื่น ๆ', 'emoji': '📦'},
];

Future<T?> _openSheet<T>(WidgetTester tester, Widget sheet) async {
  T? result;
  tester.view.physicalSize = const Size(1200, 2600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<T>(
                context: context,
                isScrollControlled: true,
                builder: (_) => sheet,
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
  return result;
}

void main() {
  testWidgets('anon sheet sends a kind, marks sent ones, and toilet can be urgent', (
    tester,
  ) async {
    AnonRequestAction? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showModalBottomSheet<AnonRequestAction>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const AnonRequestSheet(
                    kinds: _kinds,
                    mine: {'too_cold'},
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

    expect(find.text('ส่งแล้ว · แตะเพื่อถอน'), findsOneWidget);
    await tester.tap(find.text('ด่วน'));
    await tester.pumpAndSettle();
    expect(picked?.kind, 'toilet');
    expect(picked?.urgent, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('แอร์หนาวไป'));
    await tester.pumpAndSettle();
    expect(picked?.kind, 'too_cold');
    expect(picked?.cancel, isTrue, reason: 'แตะเรื่องที่ส่งแล้ว = ถอน');
  });

  testWidgets('staff banner shows only kinds with requests, plus the supply queue', (
    tester,
  ) async {
    String? tapped;
    var supplies = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffRequestBanner(
            kinds: _kinds,
            counts: const {'toilet': 2, 'too_cold': 0, 'too_hot': 3},
            urgentToilet: 1,
            supplyPending: 1,
            onKind: (k) => tapped = k,
            onSupplies: () => supplies++,
          ),
        ),
      ),
    );

    expect(find.text('🚻 ขอแวะห้องน้ำ 2 · ด่วน 1'), findsOneWidget);
    expect(find.text('🥵 แอร์ร้อนไป 3'), findsOneWidget);
    expect(find.textContaining('แอร์หนาวไป'), findsNothing);

    await tester.tap(find.text('🥵 แอร์ร้อนไป 3'));
    expect(tapped, 'too_hot');
    await tester.tap(find.text('📦 ขอยา/ของ 1'));
    expect(supplies, 1);
  });

  testWidgets('staff banner is empty when nothing is pending', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffRequestBanner(
            kinds: _kinds,
            counts: const {'toilet': 0},
            urgentToilet: 0,
            supplyPending: 0,
            onKind: (_) {},
            onSupplies: () {},
          ),
        ),
      ),
    );
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('supply sheet asks who it is for and requires a note for other', (
    tester,
  ) async {
    final sent = <List<Object?>>[];
    await _openSheet<void>(
      tester,
      SupplyRequestSheet(
        items: _items,
        load: () async => {
          'requests': [
            {
              'id': 9,
              'label': 'ทิชชู่',
              'emoji': '🧻',
              'for_name': 'มานะ',
              'status': 'declined',
              'decline_note': 'หมดแล้ว',
            },
          ],
          'passengers': [
            {'passenger_id': 1, 'name': 'มานะ', 'seat_label': 'C3'},
            {'passenger_id': 2, 'name': 'มานี', 'seat_label': 'C4'},
          ],
        },
        onSend: (item, passengerId, note) async =>
            sent.add([item, passengerId, note]),
        onCancel: (_) async {},
      ),
    );

    expect(find.text('ทีมงานไม่มีของนี้ — หมดแล้ว'), findsOneWidget);

    await tester.tap(find.text('📦 อื่น ๆ'));
    await tester.pump();
    final send = find.widgetWithText(FilledButton, 'ส่งคำขอ');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.tap(find.text('💊 ยาแก้เมารถ'));
    await tester.tap(find.text('มานี · C4'));
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(sent, [
      ['motion_sickness', 2, null],
    ]);
  });

  testWidgets('staff queue shows the seat first and splits pending from handled', (
    tester,
  ) async {
    int? delivered;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupplyQueueSheet(
            data: ValueNotifier({
              'requests': [
                {
                  'id': 1,
                  'label': 'ยาแก้เมารถ',
                  'emoji': '💊',
                  'seat_label': 'C3',
                  'for_name': 'มานะ',
                  'note': 'แพ้ยาพารา',
                  'status': 'pending',
                },
                {
                  'id': 2,
                  'label': 'ทิชชู่',
                  'emoji': '🧻',
                  'seat_label': 'A1',
                  'for_name': 'ปิติ',
                  'status': 'delivered',
                },
              ],
            }),
            onDeliver: (id) async => delivered = id,
            onDecline: (_, _) async {},
          ),
        ),
      ),
    );

    expect(find.text('C3'), findsOneWidget);
    expect(find.text('มานะ · แพ้ยาพารา'), findsOneWidget);
    expect(find.text('✅ A1 ปิติ — ทิชชู่'), findsOneWidget);
    await tester.tap(find.text('ส่งแล้ว'));
    expect(delivered, 1);
  });
}
