import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/chat_ack.dart';
import 'package:luilaykhao_app/widgets/chat_todos.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));
  await tester.pump();
}

void main() {
  group('รับทราบ', () {
    test('broadcast without acked_by_me keeps what this phone knows', () {
      final merged = mergeAck({'count': 1, 'acked_by_me': true}, {'count': 2, 'total': 5, 'acked_by_me': null});
      expect(merged, {'count': 2, 'total': 5, 'acked_by_me': true});
      expect(mergeAck({'count': 1}, null), isNull);
    });

    testWidgets('traveller taps รับทราบ; after that sees a quiet confirmation', (tester) async {
      var acked = 0;
      await _pump(
        tester,
        ChatAckBar(
          ack: const {'count': 3, 'total': 8, 'acked_by_me': false},
          canManage: false,
          onAck: () => acked++,
          onOpenDetail: () {},
        ),
      );
      expect(find.text('3/8 คน'), findsOneWidget);
      await tester.tap(find.text('รับทราบ'));
      expect(acked, 1);

      await _pump(
        tester,
        ChatAckBar(
          ack: const {'count': 4, 'total': 8, 'acked_by_me': true},
          canManage: false,
          onAck: () => acked++,
          onOpenDetail: () {},
        ),
      );
      expect(find.text('รับทราบ'), findsNothing);
      expect(find.text('คุณรับทราบแล้ว · 4/8 คน'), findsOneWidget);
    });

    testWidgets('staff see the tally and open who has not acked', (tester) async {
      var opened = 0;
      await _pump(
        tester,
        ChatAckBar(
          ack: const {'count': 2, 'total': 6},
          canManage: true,
          onAck: () {},
          onOpenDetail: () => opened++,
        ),
      );
      await tester.tap(find.text('รับทราบแล้ว 2/6 คน · ดูว่าใครยังไม่กด'));
      expect(opened, 1);
    });

    testWidgets('nudge button waits out the cooldown', (tester) async {
      final now = DateTime(2026, 10, 21, 10, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatAckDetailSheet(
              now: () => now,
              load: () async => {
                'ack': {'nudged_at': now.subtract(const Duration(minutes: 5)).toIso8601String()},
                'acked': [
                  {'id': 1, 'name': 'เอ', 'avatar_url': '', 'acked_at': now.toIso8601String()},
                ],
                'pending': [
                  {'id': 2, 'name': 'บี', 'avatar_url': ''},
                ],
              },
              onNudge: () async => {},
              onCancel: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ยังไม่กด (1)'), findsOneWidget);
      expect(find.text('สะกิดได้อีกครั้งใน 10 นาที'), findsOneWidget);
    });
  });

  group('รอคุณอยู่', () {
    final todos = ChatTodo.parseList([
      {'kind': 'vote', 'message_id': 9, 'title': 'โหวตตัดสิน', 'detail': 'ไปน้ำตกไหม', 'due_at': null},
      {'kind': 'ack', 'message_id': 7, 'title': 'กดรับทราบประกาศ', 'detail': 'นัดตีห้า'},
      {'kind': 'bad'},
    ]);

    test('parse skips rows without a message', () {
      expect(todos.map((t) => t.messageId), [9, 7]);
      expect(todos.first.urgent, isTrue);
    });

    test('due labels', () {
      final now = DateTime(2026, 10, 21, 10, 0);
      expect(todoDueLabel(null, now), isNull);
      expect(todoDueLabel(now.add(const Duration(minutes: 8)), now), 'อีก 8 นาที');
      expect(todoDueLabel(now.add(const Duration(hours: 3)), now), 'ภายใน 13:00');
      expect(todoDueLabel(now.subtract(const Duration(minutes: 1)), now), 'เลยเวลาแล้ว');
    });

    testWidgets('one item jumps straight to it, many open the list', (tester) async {
      ChatTodo? opened;
      var openedAll = 0;
      await _pump(
        tester,
        ChatTodoBar(todos: todos.take(1).toList(), onOpen: (t) => opened = t, onOpenAll: () => openedAll++),
      );
      await tester.tap(find.textContaining('รอคุณอยู่'));
      expect(opened?.messageId, 9);

      await _pump(tester, ChatTodoBar(todos: todos, onOpen: (t) => opened = null, onOpenAll: () => openedAll++));
      expect(find.text('+1'), findsOneWidget);
      await tester.tap(find.textContaining('รอคุณอยู่ 2 เรื่อง'));
      expect(openedAll, 1);
    });
  });
}
