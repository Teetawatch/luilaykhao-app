import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/chat_rest_stop.dart';

Map<String, dynamic> _stop({
  bool departed = false,
  Duration left = const Duration(minutes: 12),
  bool ownerBoarded = false,
}) =>
    {
      'id': 3,
      'place': 'ปั๊ม ปตท. วังน้อย',
      'return_at': DateTime.now().add(left).toUtc().toIso8601String(),
      'is_departed': departed,
      'total': 3,
      'boarded_count': ownerBoarded ? 2 : 0,
      'passengers': [
        {'id': 1, 'name': 'สมชาย', 'user_id': 10, 'boarded': ownerBoarded},
        {'id': 2, 'name': 'สมหญิง', 'user_id': 10, 'boarded': ownerBoarded},
        {'id': 3, 'name': 'มานะ', 'user_id': 11, 'boarded': false, 'phone': '0811111111'},
      ],
    };

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  test('myRestStopPassengers returns the group this account looks after', () {
    expect(
      myRestStopPassengers(_stop(), 10).map((p) => p['name']),
      ['สมชาย', 'สมหญิง'],
    );
    expect(myRestStopPassengers(_stop(), 99), isEmpty);
  });

  testWidgets('one tap boards the whole group the owner booked for', (
    tester,
  ) async {
    List<int>? ids;
    bool? boarded;
    await tester.pumpWidget(
      _host(
        ChatRestStopCard(
          stop: _stop(),
          myUserId: 10,
          canManage: false,
          onBoard: (i, b) {
            ids = i;
            boarded = b;
          },
          onOpenRoll: () {},
        ),
      ),
    );

    expect(find.text('ปั๊ม ปตท. วังน้อย'), findsOneWidget);
    expect(find.text('ขึ้นรถแล้ว 0/3 คน'), findsOneWidget);
    expect(find.textContaining('กลับขึ้นรถ · อีก'), findsOneWidget);

    await tester.tap(find.text('ขึ้นรถแล้ว (2 คน)'));
    expect(ids, [1, 2]);
    expect(boarded, isTrue);
  });

  testWidgets('late stop shows how far past the deadline it is', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatRestStopCard(
          stop: _stop(left: const Duration(minutes: -3, seconds: -10)),
          myUserId: 11,
          canManage: false,
          onBoard: (_, _) {},
          onOpenRoll: () {},
        ),
      ),
    );

    expect(find.textContaining('เลยเวลา 3 นาที'), findsOneWidget);
    expect(find.text('ฉันขึ้นรถแล้ว'), findsOneWidget);
  });

  testWidgets('departed stop hides the boarding button', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatRestStopCard(
          stop: _stop(departed: true),
          myUserId: 10,
          canManage: true,
          onBoard: (_, _) {},
          onOpenRoll: () {},
        ),
      ),
    );

    expect(find.text('ออกรถแล้ว'), findsOneWidget);
    expect(find.textContaining('ขึ้นรถแล้ว ('), findsNothing);
    expect(find.text('ดูรายชื่อ'), findsOneWidget);
  });

  testWidgets('roll sheet lists who is missing with a call button for staff', (
    tester,
  ) async {
    final stop = ValueNotifier<Map<String, dynamic>?>(_stop(ownerBoarded: true));
    int? toggled;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RestStopRollSheet(
            stop: stop,
            canManage: true,
            onToggle: (id, _) async => toggled = id,
            onExtend: (_) async {},
            onDepart: () async {},
          ),
        ),
      ),
    );

    expect(find.text('ยังไม่ขึ้น 1 คน — แตะเพื่อติ๊กแทน'), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.text('+5 นาที'), findsOneWidget);

    await tester.tap(find.text('มานะ'));
    expect(toggled, 3);

    // realtime ที่ตามมาไม่มีเบอร์ — ปุ่มโทรยังอยู่จากที่จำไว้
    final next = _stop(ownerBoarded: true);
    (next['passengers'] as List).last.remove('phone');
    stop.value = next;
    await tester.pump();
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('meetup far ahead says when arrival opens instead of a button', (
    tester,
  ) async {
    final stop = {
      ..._stop(left: const Duration(hours: 8)),
      'kind': 'meetup',
      'place': 'หน้าลานกางเต็นท์',
    };
    await tester.pumpWidget(
      _host(
        ChatRestStopCard(
          stop: stop,
          myUserId: 11,
          canManage: false,
          onBoard: (_, _) {},
          onOpenRoll: () {},
        ),
      ),
    );

    expect(find.text('นัดรวมพล · หน้าลานกางเต็นท์'), findsOneWidget);
    expect(find.textContaining('กด "มาถึงแล้ว" ได้ตั้งแต่'), findsOneWidget);
    expect(find.text('ฉันมาถึงแล้ว'), findsNothing);
    expect(find.text('มาถึงแล้ว 0/3 คน'), findsOneWidget);
  });

  testWidgets('meetup close to the time lets you mark arrival', (tester) async {
    final stop = {
      ..._stop(left: const Duration(minutes: 40)),
      'kind': 'meetup',
    };
    await tester.pumpWidget(
      _host(
        ChatRestStopCard(
          stop: stop,
          myUserId: 11,
          canManage: false,
          onBoard: (_, _) {},
          onOpenRoll: () {},
        ),
      ),
    );

    expect(find.text('ฉันมาถึงแล้ว'), findsOneWidget);
    expect(find.textContaining('นัดรวมพล · อีก'), findsOneWidget);
  });
}
