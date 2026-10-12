import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/chat_private_screen.dart';
import 'package:luilaykhao_app/services/realtime_service.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _person(int id, String nickname) => {
  'id': id,
  'name': nickname,
  'nickname': nickname,
  'avatar_url': null,
};

Map<String, dynamic> _msg(
  int id, {
  required bool fromCustomer,
  required int userId,
  required String nickname,
  String? body,
  int? audioMs,
}) => {
  'id': id,
  'thread_user_id': 7,
  'body': body,
  'image_url': null,
  'audio_url': audioMs == null ? null : 'https://cdn.example.com/a$id.m4a',
  'audio_duration_ms': audioMs,
  'sender_role': fromCustomer ? 'customer' : 'staff',
  'from_customer': fromCustomer,
  'is_mine': false,
  'is_deleted': false,
  'user': _person(userId, nickname),
  'created_at': '2026-10-12T13:05:00.000Z',
};

class _FakeApp extends AppProvider {
  _FakeApp({
    required this.viewerRole,
    this.messages = const [],
    this.staff = const [],
    this.thread,
    this.failSend = false,
    int myId = 7,
  }) {
    user = {'id': myId, 'name': 'มานี'};
  }

  final String viewerRole;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> staff;
  final Map<String, dynamic>? thread;
  bool failSend;
  final sent = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> threads = const [];

  @override
  Future<Map<String, dynamic>> chatPrivateMessages(
    int scheduleId, {
    int? userId,
    int? beforeId,
    int? afterId,
  }) async => {
    'messages': afterId != null ? const [] : messages,
    'has_more': false,
    'thread': thread,
    'customer': _person(7, 'มานี'),
    'staff': staff,
    'viewer_role': viewerRole,
  };

  @override
  Future<Map<String, dynamic>> sendChatPrivate(
    int scheduleId, {
    int? userId,
    String? body,
    String? imagePath,
    String? audioPath,
    int? audioDurationMs,
  }) async {
    sent.add({'user_id': userId, 'body': body});
    if (failSend) throw Exception('offline');
    return {
      'message': {
        ..._msg(
          900 + sent.length,
          fromCustomer: viewerRole == 'customer',
          userId: user!['id'] as int,
          nickname: 'ฉัน',
          body: body,
        ),
        'is_mine': true,
      },
      'thread': thread,
    };
  }

  @override
  Future<Map<String, dynamic>?> markChatPrivateRead(
    int scheduleId, {
    int? userId,
    int? messageId,
  }) async => thread;

  @override
  Future<List<Map<String, dynamic>>> chatPrivateThreads(int scheduleId) async =>
      threads;

  @override
  Future<VoidCallback> subscribeChatPrivate(
    int scheduleId, {
    required bool asStaff,
    int? userId,
    RealtimeEventHandler? onMessage,
    RealtimeEventHandler? onUpdated,
    RealtimeEventHandler? onRead,
  }) async => () {};
}

Widget _host(_FakeApp app, Widget child) =>
    ChangeNotifierProvider<AppProvider>.value(
      value: app,
      child: MaterialApp(home: child),
    );

Future<void> _done(WidgetTester tester) async {
  // ปิดหน้าเพื่อหยุด timer ดึงข้อความ
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('traveller sees who reads, picks a suggestion and sends it', (
    tester,
  ) async {
    final app = _FakeApp(
      viewerRole: 'customer',
      staff: [_person(3, 'พี่ต้น'), _person(4, 'พี่ฝน')],
    );
    await tester.pumpWidget(
      _host(app, const ChatPrivateScreen(scheduleId: 5, tripTitle: 'ดอยหลวง')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ถามทีมงานแบบส่วนตัว'), findsOneWidget);
    expect(
      find.text('ทีมงานประจำรอบเท่านั้นที่เห็น ไม่ขึ้นในห้องแชทรวม'),
      findsOneWidget,
    );
    expect(find.text('ถึง: พี่ต้น, พี่ฝน'), findsOneWidget);
    // ช่องพิมพ์ว่าง = ปุ่มไมค์
    expect(find.bySemanticsLabel('อัดข้อความเสียง'), findsOneWidget);

    await tester.tap(find.text('ขอผ้าอนามัยหน่อยค่ะ'));
    await tester.pump();
    expect(find.bySemanticsLabel('ส่ง'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('ส่ง'));
    await tester.pumpAndSettle();

    expect(app.sent, [
      {'user_id': 7, 'body': 'ขอผ้าอนามัยหน่อยค่ะ'},
    ]);
    expect(find.text('ขอผ้าอนามัยหน่อยค่ะ'), findsOneWidget);
    await _done(tester);
  });

  testWidgets('a failed send stays with a retry', (tester) async {
    final app = _FakeApp(
      viewerRole: 'customer',
      staff: [_person(3, 'พี่ต้น')],
      failSend: true,
    );
    await tester.pumpWidget(_host(app, const ChatPrivateScreen(scheduleId: 5)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ปวดท้องค่ะ');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('ส่ง'));
    await tester.pumpAndSettle();

    expect(find.text('ส่งไม่สำเร็จ · แตะเพื่อลองใหม่'), findsOneWidget);

    app.failSend = false;
    await tester.tap(find.text('ส่งไม่สำเร็จ · แตะเพื่อลองใหม่'));
    await tester.pumpAndSettle();
    expect(find.text('ส่งไม่สำเร็จ · แตะเพื่อลองใหม่'), findsNothing);
    expect(app.sent, hasLength(2));
    await _done(tester);
  });

  testWidgets('without staff on the round, it points to the help centre', (
    tester,
  ) async {
    final app = _FakeApp(viewerRole: 'customer');
    await tester.pumpWidget(_host(app, const ChatPrivateScreen(scheduleId: 5)));
    await tester.pumpAndSettle();

    expect(find.textContaining('รอบนี้ยังไม่มีทีมงานประจำ'), findsOneWidget);
    expect(find.text('ทักศูนย์ช่วยเหลือ'), findsOneWidget);
    await _done(tester);
  });

  testWidgets('traveller sees team replies with names and a read receipt', (
    tester,
  ) async {
    final app = _FakeApp(
      viewerRole: 'customer',
      staff: [_person(3, 'พี่ต้น')],
      messages: [
        {
          ..._msg(
            1,
            fromCustomer: true,
            userId: 7,
            nickname: 'มานี',
            body: 'ปวดหัวค่ะ',
          ),
          'is_mine': true,
        },
        _msg(
          2,
          fromCustomer: false,
          userId: 3,
          nickname: 'พี่ต้น',
          body: 'เดี๋ยวเอายาไปให้นะครับ',
        ),
        {
          ..._msg(
            3,
            fromCustomer: true,
            userId: 7,
            nickname: 'มานี',
            body: 'ขอบคุณค่ะ',
          ),
          'is_mine': true,
        },
      ],
      thread: {'customer_read_id': 3, 'staff_read_id': 3},
    );
    await tester.pumpWidget(_host(app, const ChatPrivateScreen(scheduleId: 5)));
    await tester.pumpAndSettle();

    expect(find.text('พี่ต้น'), findsOneWidget);
    expect(find.text('เดี๋ยวเอายาไปให้นะครับ'), findsOneWidget);
    // "ทีมงานอ่านแล้ว" ใต้ข้อความล่าสุดของเราเท่านั้น
    expect(find.textContaining('ทีมงานอ่านแล้ว'), findsOneWidget);
    await _done(tester);
  });

  testWidgets(
    'staff see the traveller by name and their own team on the right',
    (tester) async {
      final app = _FakeApp(
        viewerRole: 'staff',
        myId: 3,
        messages: [
          _msg(
            1,
            fromCustomer: true,
            userId: 7,
            nickname: 'มานี',
            body: 'ลืมแว่นไว้บนรถค่ะ',
          ),
          _msg(
            2,
            fromCustomer: false,
            userId: 4,
            nickname: 'พี่ฝน',
            body: 'เจอแล้วครับ',
          ),
          _msg(
            3,
            fromCustomer: false,
            userId: 4,
            nickname: 'พี่ฝน',
            audioMs: 9000,
          ),
        ],
        thread: {'customer_read_id': 3, 'staff_read_id': 3},
      );
      await tester.pumpWidget(
        _host(app, const ChatPrivateScreen(scheduleId: 5, threadUserId: 7)),
      );
      await tester.pumpAndSettle();

      expect(find.text('มานี'), findsOneWidget); // AppBar
      expect(
        find.text('ข้อความส่วนตัว · ลูกทริปคนอื่นไม่เห็น'),
        findsOneWidget,
      );
      // ทีมงานคนอื่นที่ตอบไปแล้วมีชื่อกำกับ
      expect(find.text('พี่ฝน'), findsNWidgets(2));
      expect(find.text('0:09'), findsOneWidget);
      expect(find.textContaining('อ่านแล้ว'), findsOneWidget);
      // ทีมงานไม่เห็นแถบบอกความเป็นส่วนตัวของลูกทริป
      expect(find.textContaining('ไม่ขึ้นในห้องแชทรวม'), findsNothing);

      await tester.enterText(find.byType(TextField), 'ส่งให้ที่จุดรับนะครับ');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('ส่ง'));
      await tester.pumpAndSettle();
      expect(app.sent.single, {'user_id': 7, 'body': 'ส่งให้ที่จุดรับนะครับ'});
      await _done(tester);
    },
  );

  testWidgets('staff inbox lists threads with unread counts', (tester) async {
    final app = _FakeApp(viewerRole: 'staff', myId: 3)
      ..threads = [
        {
          'thread_user_id': 7,
          'customer': _person(7, 'มานี'),
          'unread': 2,
          'last_message': {
            'preview': 'เป็นประจำเดือนค่ะ',
            'from_customer': true,
            'created_at': '2026-10-12T13:05:00.000Z',
          },
        },
        {
          'thread_user_id': 8,
          'customer': _person(8, 'ชูใจ'),
          'unread': 0,
          'last_message': {
            'preview': 'ได้เลยครับ',
            'from_customer': false,
            'created_at': '2026-10-12T12:00:00.000Z',
          },
        },
      ];
    await tester.pumpWidget(
      _host(app, const ChatPrivateInboxScreen(scheduleId: 5)),
    );
    await tester.pumpAndSettle();

    expect(find.text('มานี'), findsOneWidget);
    expect(find.text('เป็นประจำเดือนค่ะ'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('ทีมงาน: ได้เลยครับ'), findsOneWidget);
    await _done(tester);
  });

  testWidgets('empty staff inbox explains what it is for', (tester) async {
    final app = _FakeApp(viewerRole: 'staff', myId: 3);
    await tester.pumpWidget(
      _host(app, const ChatPrivateInboxScreen(scheduleId: 5)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีใครถามแบบส่วนตัว'), findsOneWidget);
    await _done(tester);
  });
}
