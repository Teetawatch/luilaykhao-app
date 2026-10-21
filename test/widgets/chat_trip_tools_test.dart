import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidScheduleMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/wake_alarm_service.dart';
import 'package:luilaykhao_app/widgets/chat_dropoff.dart';
import 'package:luilaykhao_app/widgets/chat_porter.dart';
import 'package:luilaykhao_app/widgets/chat_rest_stop.dart';
import 'package:luilaykhao_app/widgets/chat_trail_check.dart';
import 'package:luilaykhao_app/widgets/chat_wellness.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _trail({bool myHelp = false, int helpCount = 0}) => {
  'id': 7,
  'title': 'ขึ้นยอดภูกระดึง',
  'checkpoints': ['ซำแฮก', 'หลังแป', 'ยอด'],
  'is_closed': false,
  'total': 3,
  'counts': [2, 1, 0],
  'tail_index': -1,
  'tail_names': ['มานะ'],
  'help_count': helpCount,
  'my_help': myHelp,
  'passengers': [
    {'id': 1, 'name': 'พ่อ', 'user_id': 10, 'index': 1},
    {'id': 2, 'name': 'แม่', 'user_id': 10, 'index': 0},
    {'id': 3, 'name': 'มานะ', 'user_id': 11, 'index': null},
  ],
};

void main() {
  group('เช็คพอยต์', () {
    testWidgets('moves only the people of my group who are behind', (
      tester,
    ) async {
      final reached = <String>[];
      await tester.pumpWidget(
        _host(
          ChatTrailCheckCard(
            trail: _trail(),
            myUserId: 10,
            canManage: false,
            onReach: (ids, index) => reached.add('$ids→$index'),
            onHelp: () {},
            onCancelHelp: () {},
            onOpenBoard: () {},
          ),
        ),
      );

      expect(find.text('2/3'), findsOneWidget);
      expect(
        find.textContaining('ท้ายสุด: มานะ (ยังไม่ถึง ซำแฮก)'),
        findsOneWidget,
      );
      // แม่อยู่ซำแฮก พ่ออยู่หลังแป → พาแม่ไปหลังแป
      await tester.tap(find.text('ถึง หลังแป แล้ว'));
      expect(reached, ['[2]→1']);
      expect(find.text('ขอพัก'), findsOneWidget);
    });

    testWidgets('a pending break shows "caught up" and staff see the count', (
      tester,
    ) async {
      var cancelled = 0;
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              ChatTrailCheckCard(
                trail: _trail(myHelp: true, helpCount: 1),
                myUserId: 11,
                canManage: false,
                onReach: (_, _) {},
                onHelp: () {},
                onCancelHelp: () => cancelled++,
                onOpenBoard: () {},
              ),
              ChatTrailCheckCard(
                trail: _trail(helpCount: 2),
                myUserId: 99,
                canManage: true,
                onReach: (_, _) {},
                onHelp: () {},
                onCancelHelp: () {},
                onOpenBoard: () {},
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('ตามทันแล้ว'));
      expect(cancelled, 1);
      expect(find.text('ขอพัก 2 คน — แตะเพื่อดูว่าใคร'), findsOneWidget);
      expect(
        find.text('ขอพัก 1 คน — แตะเพื่อดูว่าใคร'),
        findsNothing,
        reason: 'ลูกทริปไม่เห็นจำนวนคนขอพัก',
      );
    });

    testWidgets('open sheet refuses duplicate names', (tester) async {
      _tall(tester);
      TrailDraft? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    draft = await showModalBottomSheet<TrailDraft>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const OpenTrailCheckSheet(),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'ยอด');
      await tester.enterText(fields.at(2), 'ยอด');
      await tester.pump();
      expect(find.text('ชื่อจุดซ้ำกัน'), findsOneWidget);

      await tester.enterText(fields.at(2), 'ซำแฮก');
      await tester.pump();
      await tester.tap(find.text('ประกาศเช็คพอยต์ · 2 จุด'));
      await tester.pumpAndSettle();
      expect(draft?.checkpoints, ['ยอด', 'ซำแฮก']);
    });
  });

  group('เช็คอาการ', () {
    testWidgets(
      'one tap for "fine", a sheet for tired/unwell with that choice picked',
      (tester) async {
        final answers = <String>[];
        final opened = <String?>[];
        await tester.pumpWidget(
          _host(
            ChatWellnessCard(
              wellness: const {
                'id': 3,
                'label': 'ก่อนขึ้นช่วงชัน',
                'is_closed': false,
                'total': 4,
                'answered_count': 1,
                'mine': [
                  {
                    'id': 1,
                    'name': 'พ่อ',
                    'status': null,
                    'note': null,
                    'handled': false,
                  },
                ],
              },
              canManage: false,
              onAnswer: (a) => answers.add('${a.passengerIds}:${a.status}'),
              onOpenAnswer: opened.add,
              onOpenStaff: () {},
            ),
          ),
        );

        expect(find.textContaining('ตอบแล้ว 1/4 คน'), findsOneWidget);
        await tester.tap(find.text('สบาย'));
        expect(answers, ['[1]:ok']);
        await tester.tap(find.text('ไม่ค่อยไหว'));
        expect(opened, ['unwell']);
        expect(find.text('ดูอาการทุกคน'), findsNothing);
      },
    );

    testWidgets(
      'answer sheet groups the family by answer and asks for a note',
      (tester) async {
        _tall(tester);
        List<WellnessAnswer>? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async =>
                      result = await showModalBottomSheet<List<WellnessAnswer>>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const WellnessAnswerSheet(
                          mine: [
                            {'id': 1, 'name': 'พ่อ', 'status': null},
                            {'id': 2, 'name': 'แม่', 'status': null},
                          ],
                        ),
                      ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('สบาย').first);
        await tester.tap(find.text('ไม่ค่อยไหว').last);
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'เวียนหัว');
        await tester.pump();
        await tester.tap(find.text('ส่งคำตอบ'));
        await tester.pumpAndSettle();

        expect(
          result!
              .map((a) => '${a.passengerIds}:${a.status}:${a.note}')
              .toList(),
          ['[1]:ok:null', '[2]:unwell:เวียนหัว'],
        );
      },
    );
  });

  group('จุดลงขากลับ', () {
    testWidgets('card shows my drop point and the stop progress', (
      tester,
    ) async {
      var chose = 0;
      await tester.pumpWidget(
        _host(
          ChatDropoffCard(
            dropoff: const {
              'id': 4,
              'is_closed': false,
              'total': 5,
              'dropped_count': 2,
              'stop_count': 3,
              'stops_done': 1,
              'mine': [
                {
                  'id': 1,
                  'name': 'พ่อ',
                  'label': 'หมอชิต',
                  'is_default': true,
                  'dropped': false,
                },
              ],
            },
            canManage: false,
            onChoose: () => chose++,
            onOpenStaff: () {},
          ),
        ),
      );

      expect(find.text('ส่งแล้ว 1/3 จุด · 2/5 คน'), findsOneWidget);
      expect(find.text('จุดลงของคุณ: หมอชิต (จุดรับเดิม)'), findsOneWidget);
      await tester.tap(find.text('เปลี่ยนจุดลง'));
      expect(chose, 1);
      expect(find.text('รายการจุดส่ง'), findsNothing);
    });

    testWidgets('choosing another pickup point', (tester) async {
      _tall(tester);
      DropoffDraft? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    draft = await showModalBottomSheet<DropoffDraft>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => DropoffChooseSheet(
                        mine: const [
                          {
                            'id': 1,
                            'name': 'พ่อ',
                            'label': 'หมอชิต',
                            'is_default': true,
                            'dropped': false,
                          },
                        ],
                        options: const [
                          {
                            'id': 20,
                            'label': 'ปั๊ม ปตท. รังสิต',
                            'region': 'กรุงเทพฯ',
                          },
                        ],
                        onPickOnMap: (_) async => null,
                      ),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ปั๊ม ปตท. รังสิต'));
      await tester.pump();
      await tester.tap(find.text('บันทึกจุดลง'));
      await tester.pumpAndSettle();
      expect(draft?.passengerIds, [1]);
      expect(draft?.pickupPointId, 20);
      expect(draft?.reset, isFalse);
    });

    testWidgets('staff list numbers pending stops in route order', (
      tester,
    ) async {
      _tall(tester);
      final dropped = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropoffStaffSheet(
              dropoff: ValueNotifier({
                'is_closed': false,
                'stops_done': 1,
                'stop_count': 3,
                'detail': {
                  'van': {'lat': 14.2, 'lng': 100.6},
                  'stops': [
                    {
                      'key': 'pp:1',
                      'label': 'รังสิต',
                      'lat': 14.0,
                      'lng': 100.6,
                      'distance_km': 18.4,
                      'dropped': false,
                      'passengers': [
                        {'id': 1, 'name': 'พ่อ', 'note': null},
                      ],
                    },
                    {
                      'key': 'pp:2',
                      'label': 'หมอชิต',
                      'lat': 13.8,
                      'lng': 100.5,
                      'distance_km': 44.0,
                      'dropped': false,
                      'passengers': [
                        {'id': 2, 'name': 'มานะ', 'note': 'หน้าเซเว่น'},
                      ],
                    },
                    {
                      'key': 'pp:3',
                      'label': 'อยุธยา',
                      'lat': 14.3,
                      'lng': 100.5,
                      'dropped': true,
                      'passengers': [
                        {'id': 3, 'name': 'ชูใจ', 'note': null},
                      ],
                    },
                  ],
                },
              }),
              onDrop: (ids, d) async => dropped.add('$ids:$d'),
              onClose: () async {},
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('มานะ · "หน้าเซเว่น"'), findsOneWidget);
      expect(find.text('ลง 1 คน · 18 กม.'), findsOneWidget);
      await tester.tap(find.text('ส่งถึงแล้ว').first);
      await tester.tap(find.text('ยกเลิก'));
      expect(dropped, ['[1]:true', '[3]:false']);
    });
  });

  group('ลูกหาบ', () {
    Map<String, dynamic> porter() => {
      'id': 9,
      'title': 'ลูกหาบขึ้นภูกระดึง',
      'rate_per_kg': 30,
      'min_charge': 50,
      'round_up': true,
      'is_closed': false,
      'is_billed': false,
      'paid_passenger_ids': [],
      'bag_count': 3,
      'weighed_count': 2,
      'returned_count': 0,
      'total_kg': 13,
      'total_fee': 390,
      'bags': [
        {
          'id': 1,
          'tag_no': 1,
          'passenger_id': 1,
          'name': 'พ่อ',
          'user_id': 10,
          'weight_kg': 8,
          'fee': 240,
          'note': 'เป้แดง',
          'returned': false,
        },
        {
          'id': 2,
          'tag_no': 2,
          'passenger_id': 3,
          'name': 'มานะ',
          'user_id': 11,
          'weight_kg': 5,
          'fee': 150,
          'note': null,
          'returned': false,
        },
        {
          'id': 3,
          'tag_no': 3,
          'passenger_id': 1,
          'name': 'พ่อ',
          'user_id': 10,
          'weight_kg': null,
          'fee': null,
          'note': null,
          'returned': false,
        },
      ],
      'mine': [
        {'id': 1, 'name': 'พ่อ'},
      ],
    };

    testWidgets('card shows the rate and my own bags with tag numbers', (
      tester,
    ) async {
      var registered = 0;
      await tester.pumpWidget(
        _host(
          ChatPorterCard(
            porter: porter(),
            myUserId: 10,
            canManage: false,
            onRegister: () => registered++,
            onOpen: () {},
          ),
        ),
      );

      expect(
        find.text('กก.ละ ฿30 · ขั้นต่ำใบละ ฿50 · ปัดขึ้นเป็นกิโลเต็ม'),
        findsOneWidget,
      );
      expect(find.text('#1 · 8 กก. · ฿240'), findsOneWidget);
      expect(find.text('#3 · ยังไม่ชั่ง'), findsOneWidget);
      expect(
        find.textContaining('#2'),
        findsNothing,
        reason: 'กระเป๋าคนอื่นไม่ขึ้นในส่วนของฉัน',
      );
      await tester.tap(find.text('ฝากกระเป๋า'));
      expect(registered, 1);
    });

    testWidgets('staff cannot bill until every bag is weighed', (tester) async {
      _tall(tester);
      var billed = 0;
      final data = ValueNotifier<Map<String, dynamic>?>(porter());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PorterManageSheet(
              porter: data,
              canManage: true,
              myUserId: 99,
              onWeigh: (_, _) async {},
              onRemove: (_) async {},
              onReturned: (_, _) async {},
              onAddForSomeone: () async {},
              onBill: () async => billed++,
              onSetClosed: (_) async {},
              onOpenCollection: () {},
            ),
          ),
        ),
      );

      expect(find.text('ชั่งให้ครบก่อน (เหลือ 1 ใบ)'), findsOneWidget);
      final weighed = porter();
      (weighed['bags'] as List).last['weight_kg'] = 2;
      data.value = weighed;
      await tester.pump();
      expect(find.text('ส่งยอดเก็บเงิน · ฿390'), findsOneWidget);
      expect(billed, 0);
    });

    testWidgets('register sheet caps bags per person', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PorterRegisterSheet(
              people: [
                {'id': 1, 'name': 'พ่อ'},
              ],
              existingBags: {1: 4},
            ),
          ),
        ),
      );

      expect(find.text('ฝาก 1 ใบ'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(find.text('ฝากได้อีก 1 ใบ'), findsOneWidget);
    });
  });

  group('ปลุกรวม', () {
    final now = DateTime.utc(2026, 10, 20, 12);
    Map<String, dynamic> stop({bool departed = false, bool dadAwake = false}) =>
        {
          'id': 5,
          'kind': 'wakeup',
          'is_departed': departed,
          'return_at': '2026-10-20T20:30:00Z',
          'passengers': [
            {'id': 1, 'name': 'พ่อ', 'user_id': 10, 'boarded': dadAwake},
            {'id': 2, 'name': 'มานะ', 'user_id': 11, 'boarded': true},
          ],
        };

    test('rings only people who still have someone to wake', () {
      expect(
        WakeAlarmService.wakeTimeFor(stop(), 10, now),
        DateTime.utc(2026, 10, 20, 20, 30),
      );
      expect(
        WakeAlarmService.wakeTimeFor(stop(), 11, now),
        isNull,
        reason: 'ตื่นแล้ว',
      );
      expect(
        WakeAlarmService.wakeTimeFor(stop(dadAwake: true), 10, now),
        isNull,
      );
      expect(
        WakeAlarmService.wakeTimeFor(stop(departed: true), 10, now),
        isNull,
      );
      expect(
        WakeAlarmService.wakeTimeFor(stop(), 99, now),
        isNull,
        reason: 'ไม่มีชื่อในรายการ',
      );
      expect(
        WakeAlarmService.wakeTimeFor(
          stop(),
          10,
          DateTime.utc(2026, 10, 20, 21),
        ),
        isNull,
        reason: 'เลยเวลาแล้ว',
      );
      expect(
        WakeAlarmService.wakeTimeFor({...stop(), 'kind': 'meetup'}, 10, now),
        isNull,
      );
    });

    testWidgets('wake-up card speaks wake-up and blocks ticking too early', (
      tester,
    ) async {
      final wakeAt = DateTime.now().add(const Duration(hours: 5));
      await tester.pumpWidget(
        _host(
          ChatRestStopCard(
            stop: {
              ...stop(),
              'place': 'ออกเดิน 04:00',
              'return_at': wakeAt.toUtc().toIso8601String(),
              'total': 2,
              'boarded_count': 1,
            },
            myUserId: 10,
            canManage: false,
            onBoard: (_, _) {},
            onOpenRoll: () {},
          ),
        ),
      );

      expect(find.text('ปลุกรวม · ออกเดิน 04:00'), findsOneWidget);
      expect(find.textContaining('ปลุก · อีก'), findsOneWidget);
      expect(find.textContaining('กด "ตื่นแล้ว" ได้ตั้งแต่'), findsOneWidget);
      expect(find.text('ฉันตื่นแล้ว'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('ปลุกในเครื่อง Android', () {
    test('rings like an alarm clock when allowed, inexact otherwise', () {
      expect(
        WakeAlarmService.scheduleModeFor(exact: true),
        AndroidScheduleMode.alarmClock,
      );
      expect(
        WakeAlarmService.scheduleModeFor(exact: false),
        AndroidScheduleMode.inexactAllowWhileIdle,
      );
    });

    testWidgets('inexact alarm offers to ring on time', (tester) async {
      var asked = 0;
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              WakeAlarmStatus(exact: false, onMakeExact: () => asked++),
              WakeAlarmStatus(exact: true, onMakeExact: () => asked++),
            ],
          ),
        ),
      );

      expect(
        find.text('ตั้งปลุกในเครื่องแล้ว แต่อาจช้าไม่กี่นาที'),
        findsOneWidget,
      );
      expect(
        find.text('เครื่องนี้ตั้งปลุกไว้แล้ว ดังตรงเวลาแม้ไม่มีสัญญาณ'),
        findsOneWidget,
      );
      expect(find.text('ให้ปลุกตรงเวลา'), findsOneWidget);
      await tester.tap(find.text('ให้ปลุกตรงเวลา'));
      expect(asked, 1);
    });
  });
}
