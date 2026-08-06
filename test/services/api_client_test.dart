import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luilaykhao_app/services/api_client.dart';

/// Runs [body] with every top-level `http.*` call in [ApiClient] served by
/// [handler], and reports how many times the handler was hit.
Future<int> _withHandler(
  Future<void> Function() body,
  Future<http.Response> Function(http.Request request) handler,
) async {
  var calls = 0;
  await http.runWithClient(body, () {
    return MockClient((request) {
      calls++;
      return handler(request);
    });
  });
  return calls;
}

http.Response _ok() => http.Response('{"success":true,"data":{"ok":1}}', 200);

/// `{"message":"ไม่พบทริป"}` exactly as Laravel puts it on the wire — Thai
/// escaped to \uXXXX, so the payload is ASCII. Verified against
/// `Illuminate\Http\JsonResponse`, whose default encoding options do not
/// include JSON_UNESCAPED_UNICODE.
const _laravelJson =
    '{"message":"\\u0e44\\u0e21\\u0e48\\u0e1e\\u0e1a\\u0e17\\u0e23\\u0e34\\u0e1b"}';

void main() {
  group('transport failures become Thai ApiExceptions', () {
    test('no signal reads as a connection problem, not a server error', () async {
      ApiException? caught;
      await _withHandler(() async {
        try {
          await ApiClient().get('trips');
        } on ApiException catch (e) {
          caught = e;
        }
      }, (_) => throw const SocketException('Failed host lookup'));

      expect(caught, isNotNull);
      expect(caught!.isNetworkError, isTrue);
      expect(caught!.message, contains('เชื่อมต่ออินเทอร์เน็ตไม่ได้'));
      // The raw dart:io text must never reach the user — several screens render
      // the message straight into a snackbar.
      expect(caught!.message, isNot(contains('SocketException')));
    });

    test('a dropped connection reads in Thai too', () async {
      ApiException? caught;
      await _withHandler(() async {
        try {
          await ApiClient().get('trips');
        } on ApiException catch (e) {
          caught = e;
        }
      }, (_) => throw http.ClientException('Connection closed'));

      expect(caught!.isNetworkError, isTrue);
      expect(caught!.message, contains('การเชื่อมต่อขัดข้อง'));
    });

    test('an HTTP error is not mistaken for a network error', () async {
      ApiException? caught;
      await _withHandler(() async {
        try {
          await ApiClient().get('trips');
        } on ApiException catch (e) {
          caught = e;
        }
      }, (_) async => http.Response(_laravelJson, 404));

      expect(caught!.statusCode, 404);
      expect(caught!.isNetworkError, isFalse);
      expect(caught!.message, 'ไม่พบทริป');
    });

    test('a Thai server message survives decoding intact', () async {
      // Laravel sends `Content-Type: application/json` with no charset, and
      // package:http then decodes the body as latin1. That is only safe because
      // Laravel escapes non-ASCII as \uXXXX, leaving the body pure ASCII — see
      // _laravelJson. If the API ever starts emitting raw UTF-8 (e.g. via
      // JSON_UNESCAPED_UNICODE), every Thai message in the app turns to
      // mojibake and this test is what catches it.
      expect(_laravelJson, matches(RegExp(r'^[\x00-\x7F]*$')));

      ApiException? caught;
      await _withHandler(() async {
        try {
          await ApiClient().get('trips');
        } on ApiException catch (e) {
          caught = e;
        }
      }, (_) async => http.Response(_laravelJson, 422));

      expect(caught!.message, 'ไม่พบทริป');
    });
  });

  group('retry policy', () {
    test('a GET that fails once is retried and succeeds', () async {
      var attempt = 0;
      final calls = await _withHandler(
        () async {
          final result = await ApiClient().get('trips');
          expect(result['success'], isTrue);
        },
        (_) {
          attempt++;
          if (attempt == 1) throw const SocketException('flaky');
          return Future.value(_ok());
        },
      );

      expect(calls, 2);
    });

    test('a GET gives up after the backoff list is exhausted', () async {
      final calls = await _withHandler(() async {
        await expectLater(
          ApiClient().get('trips'),
          throwsA(isA<ApiException>()),
        );
      }, (_) => throw const SocketException('down'));

      // One initial attempt plus one per backoff step.
      expect(calls, 3);
    });

    test(
      'a POST is never retried — a second try could double-charge',
      () async {
        final calls = await _withHandler(() async {
          await expectLater(
            ApiClient().post('payments/charge', body: {'amount': 1200}),
            throwsA(isA<ApiException>()),
          );
        }, (_) => throw const SocketException('down'));

        expect(calls, 1);
      },
    );

    test('PUT and DELETE are not retried either', () async {
      final puts = await _withHandler(() async {
        await expectLater(ApiClient().put('me'), throwsA(isA<ApiException>()));
      }, (_) => throw const SocketException('down'));
      expect(puts, 1);

      final deletes = await _withHandler(() async {
        await expectLater(
          ApiClient().delete('saved-travellers/1'),
          throwsA(isA<ApiException>()),
        );
      }, (_) => throw const SocketException('down'));
      expect(deletes, 1);
    });
  });

  group('response handling still holds', () {
    test('401 fires the unauthorized hook', () async {
      var unauthorized = false;
      await _withHandler(() async {
        final client = ApiClient()..onUnauthorized = () => unauthorized = true;
        await expectLater(client.get('me'), throwsA(isA<ApiException>()));
      }, (_) async => http.Response('{"message":"Unauthenticated."}', 401));

      expect(unauthorized, isTrue);
    });

    test('503 raises the maintenance gate with a Thai message', () async {
      var maintenance = false;
      ApiException? caught;
      await _withHandler(() async {
        final client = ApiClient()..onMaintenance = () => maintenance = true;
        try {
          await client.get('trips');
        } on ApiException catch (e) {
          caught = e;
        }
      }, (_) async => http.Response('Service Unavailable', 503));

      expect(maintenance, isTrue);
      expect(caught!.statusCode, 503);
      expect(caught!.message, contains('ปิดปรับปรุง'));
    });

    test('a 503 is not retried into a thundering herd on a deploy', () async {
      final calls = await _withHandler(() async {
        await expectLater(
          ApiClient().get('trips'),
          throwsA(isA<ApiException>()),
        );
      }, (_) async => http.Response('Service Unavailable', 503));

      expect(calls, 1);
    });
  });

  group('a non-JSON body never reaches a caller', () {
    // An unknown /api/v1 path does not 404 on production — it falls through to
    // the website's SPA catch-all and comes back 200 with the page shell.
    const spaShell =
        '<!DOCTYPE html><html lang="th"><head><meta charset="utf-8">'
        '<title>Luilaykhao</title></head><body><div id="app"></div></body></html>';

    test('a 200 HTML page is an error, not a payload', () async {
      ApiException? caught;
      await _withHandler(() async {
        try {
          await ApiClient().get('settings/app');
        } on ApiException catch (e) {
          caught = e;
        }
      }, (_) async => http.Response(spaShell, 200));

      expect(
        caught,
        isNotNull,
        reason: 'the HTML must not be returned as data',
      );
      expect(caught!.statusCode, 200);
      expect(
        caught!.message,
        contains('เซิร์ฟเวอร์ตอบกลับในรูปแบบที่ไม่ถูกต้อง'),
      );
    });

    test('it fails at the client, not later as a cast error', () async {
      // The regression this guards: the body used to come back as a String,
      // travel through api.data(), and blow up in a screen as "type 'String'
      // is not a subtype of type 'Map<dynamic, dynamic>' in type cast" — with
      // no mention of which endpoint answered wrong.
      Object? caught;
      await _withHandler(() async {
        try {
          final client = ApiClient();
          final response = await client.get('settings/app');
          Map<String, dynamic>.from(client.data(response) as Map);
        } catch (e) {
          caught = e;
        }
      }, (_) async => http.Response(spaShell, 200));

      expect(caught, isA<ApiException>());
      expect(caught, isNot(isA<TypeError>()));
    });

    test('an HTML error page does not become the snackbar text', () async {
      ApiException? caught;
      await _withHandler(
        () async {
          try {
            await ApiClient().get('trips');
          } on ApiException catch (e) {
            caught = e;
          }
        },
        (_) async =>
            http.Response('<html><body>502 Bad Gateway</body></html>', 502),
      );

      expect(caught!.statusCode, 502);
      expect(caught!.message, 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์');
      expect(caught!.message, isNot(contains('<')));
    });

    test('an empty 200 body is still a legitimate null', () async {
      await _withHandler(() async {
        expect(await ApiClient().delete('saved-travellers/1'), isNull);
      }, (_) async => http.Response('', 200));
    });
  });
}
