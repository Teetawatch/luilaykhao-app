import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';

/// เครื่องมือรายงาน/บล็อกฝั่งแอป — ที่ทดสอบตรงนี้คือ "บล็อกแล้วต้องเงียบทันที"
/// ซึ่งเป็นสิ่งที่เซิร์ฟเวอร์ช่วยไม่ได้กับข้อความที่วิ่งมาทาง WebSocket
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

http.Response _json(String body) => http.Response(
      body,
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('การบล็อกผู้ใช้', () {
    test('บล็อกแล้ว isBlocked ตอบจริงทันที ไม่ต้องรอโหลดใหม่', () async {
      final app = AppProvider();
      app.api.token = 'test-token';

      expect(app.isBlocked(42), isFalse);

      await _withHandler(
        () => app.blockUser(42),
        (_) async => _json('{"success":true,"data":null}'),
      );

      expect(app.isBlocked(42), isTrue);
    });

    test('เลิกบล็อกแล้วกลับมาเห็นเหมือนเดิม', () async {
      final app = AppProvider();
      app.api.token = 'test-token';

      await _withHandler(
        () => app.blockUser(7),
        (_) async => _json('{"success":true,"data":null}'),
      );
      await _withHandler(
        () => app.unblockUser(7),
        (_) async => _json('{"success":true,"data":null}'),
      );

      expect(app.isBlocked(7), isFalse);
    });

    test('โหลดรายการบล็อกแล้วเซ็ตในเครื่องตรงกับเซิร์ฟเวอร์', () async {
      final app = AppProvider();
      app.api.token = 'test-token';

      final blocks = await _withHandler(
        () => app.blockedUsers(),
        (_) async => _json(
          '{"success":true,"data":{"blocks":['
          '{"user_id":1,"name":"A","avatar_url":null,"blocked_at":null},'
          '{"user_id":2,"name":"B","avatar_url":null,"blocked_at":null}'
          ']}}',
        ),
      );

      expect(blocks, hasLength(2));
      expect(app.isBlocked(1), isTrue);
      expect(app.isBlocked(2), isTrue);
      expect(app.isBlocked(3), isFalse);
    });

    test('รายการที่เซิร์ฟเวอร์ส่งมาเป็นความจริง — คนที่หายไปถือว่าไม่ถูกบล็อกแล้ว',
        () async {
      final app = AppProvider();
      app.api.token = 'test-token';

      await _withHandler(
        () => app.blockUser(99),
        (_) async => _json('{"success":true,"data":null}'),
      );
      expect(app.isBlocked(99), isTrue);

      // เลิกบล็อกจากอีกเครื่องหนึ่ง — พอโหลดรายการใหม่ต้องหายจากเซ็ตในเครื่องนี้ด้วย
      await _withHandler(
        () => app.blockedUsers(),
        (_) async => _json('{"success":true,"data":{"blocks":[]}}'),
      );

      expect(app.isBlocked(99), isFalse);
    });

    test('isBlocked ไม่พังเมื่อ id เป็น null', () {
      expect(AppProvider().isBlocked(null), isFalse);
    });
  });
}
