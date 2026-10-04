import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luilaykhao_app/models/chat_notify_level.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/services/push_notification_service.dart';

/// การแจ้งเตือนรายห้องของแชททริป — ค่า, การบันทึก และ tag ที่ต้องตรงกับเซิร์ฟเวอร์
Future<T> _withHandler<T>(
  Future<T> Function() body,
  Future<http.Response> Function(http.Request request) handler,
) async {
  late T result;
  await http.runWithClient(() async {
    result = await body();
  }, () => MockClient(handler));
  return result;
}

http.Response _json(String body, [int status = 200]) => http.Response(
      body,
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('ChatNotifyLevel', () {
    test('ค่าตรงกับ ChatRoomPreference::LEVELS ฝั่ง Laravel', () {
      expect(
        ChatNotifyLevel.values.map((l) => l.value).toList(),
        ['all', 'important', 'off'],
      );
    });

    test('ค่าที่ไม่รู้จักหรือไม่มีเลย = ทุกข้อความ', () {
      expect(ChatNotifyLevel.fromValue('off'), ChatNotifyLevel.off);
      expect(ChatNotifyLevel.fromValue('important'), ChatNotifyLevel.important);
      expect(ChatNotifyLevel.fromValue(null), ChatNotifyLevel.all);
      expect(ChatNotifyLevel.fromValue('loud'), ChatNotifyLevel.all);
    });
  });

  test('tag ของแจ้งเตือนตรงกับ SendChatPushJob::tagFor()', () {
    expect(PushNotificationService.chatTag(12), 'chat-12');
    expect(PushNotificationService.chatTag(12, mention: true), 'chat-12-mention');
  });

  group('setChatNotifyLevel', () {
    test('ส่ง PUT ไปที่ห้องนั้น แล้วอัปเดตรายการห้องที่แคชไว้', () async {
      final app = AppProvider();
      app.api.token = 'test-token';
      app.chatConversations = [
        {'schedule_id': 5, 'notify_level': 'all'},
        {'schedule_id': 6, 'notify_level': 'all'},
      ];

      late http.Request sent;
      final saved = await _withHandler(
        () => app.setChatNotifyLevel(5, ChatNotifyLevel.off),
        (request) async {
          sent = request;
          return _json('{"success":true,"data":{"notify_level":"off"}}');
        },
      );

      expect(saved, ChatNotifyLevel.off);
      expect(sent.method, 'PUT');
      expect(sent.url.path, endsWith('/schedules/5/chat/notifications'));
      expect(jsonDecode(sent.body), {'level': 'off'});
      expect((app.chatConversations[0] as Map)['notify_level'], 'off');
      expect((app.chatConversations[1] as Map)['notify_level'], 'all');
    });

    test('บันทึกไม่สำเร็จ = โยน error และแคชไม่เปลี่ยน', () async {
      final app = AppProvider();
      app.api.token = 'test-token';
      app.chatConversations = [
        {'schedule_id': 5, 'notify_level': 'important'},
      ];

      await expectLater(
        _withHandler(
          () => app.setChatNotifyLevel(5, ChatNotifyLevel.off),
          (_) async => _json(
            '{"success":false,"message":"คุณไม่มีสิทธิ์เข้าถึงห้องแชทนี้"}',
            403,
          ),
        ),
        throwsA(anything),
      );

      expect((app.chatConversations[0] as Map)['notify_level'], 'important');
    });
  });
}
