import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? errors;

  /// True when the request never reached the server (no signal, DNS failure,
  /// TLS handshake failure, connection dropped mid-flight, or timeout). The UI
  /// can use this to offer "ลองใหม่" instead of treating it as a server refusal.
  final bool isNetworkError;

  const ApiException(
    this.message, {
    this.statusCode,
    this.errors,
    this.isNetworkError = false,
  });

  @override
  String toString() => message;
}

class ApiClient {
  /// Hard ceiling for a single request. Without this, a stalled connection
  /// hangs the future forever — which on the trip detail page surfaced as a
  /// half-loaded screen (trip header shown, schedules/reviews never arriving).
  static const Duration _timeout = Duration(seconds: 20);

  /// Uploads carry a photo (payment slips, SOS photos, review images) over
  /// whatever signal the user has on a mountain road, so they get a longer
  /// leash than a plain JSON call — but still a finite one. Before this,
  /// `postMultipart` had no timeout at all and a stalled upload hung forever
  /// with the payment button spinning.
  static const Duration _uploadTimeout = Duration(seconds: 60);

  /// Transport failures are retried for GET only. A retried POST could file a
  /// second payment slip or a second booking, so writes always fail fast and
  /// let the user decide — see [_send].
  static const List<Duration> _retryBackoff = [
    Duration(milliseconds: 400),
    Duration(milliseconds: 1200),
  ];

  String? token;

  /// Invoked whenever the server returns 401. Use this to wipe local credentials
  /// and route the user back to the login screen.
  void Function()? onUnauthorized;

  /// Invoked whenever the server returns 503 (Laravel maintenance mode, i.e.
  /// `php artisan down`). Use this to raise a full-screen "ปิดปรับปรุงชั่วคราว"
  /// gate so users see a calm message instead of raw request errors during a
  /// deploy or database cutover.
  void Function()? onMaintenance;

  ApiClient({this.token, this.onUnauthorized, this.onMaintenance});

  Map<String, String> _headers({bool json = true}) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('${ApiConfig.baseUrl}/$normalizedPath');
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        params[key] = value.toString();
      }
    });
    return uri.replace(queryParameters: params.isEmpty ? null : params);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) {
    return _send('POST', path, body: body);
  }

  Future<dynamic> postMultipart(
    String path, {
    required Map<String, dynamic> fields,
    required Map<String, String> files,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(_headers(json: false));
    fields.forEach((key, value) {
      if (value != null) request.fields[key] = value.toString();
    });
    for (final entry in files.entries) {
      request.files.add(
        await http.MultipartFile.fromPath(entry.key, entry.value),
      );
    }

    // An upload is a write — never retried, only guarded and bounded.
    final response = await _withTransportGuard(() async {
      final streamed = await request.send().timeout(_uploadTimeout);
      return http.Response.fromStream(streamed).timeout(_uploadTimeout);
    });
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) {
    return _send('PUT', path, body: body);
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) {
    return _send('DELETE', path, body: body);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);

    Future<http.Response> attempt() {
      switch (method) {
        case 'GET':
          return http.get(uri, headers: _headers()).timeout(_timeout);
        case 'POST':
          return http
              .post(uri, headers: _headers(), body: encoded)
              .timeout(_timeout);
        case 'PUT':
          return http
              .put(uri, headers: _headers(), body: encoded)
              .timeout(_timeout);
        case 'DELETE':
          return http
              .delete(uri, headers: _headers(), body: encoded)
              .timeout(_timeout);
        default:
          throw ApiException('Unsupported method $method');
      }
    }

    // Reads are safe to repeat; writes are not. A retried POST could submit a
    // second payment slip or a second booking against the same seat lock.
    final response = await _withTransportGuard(
      attempt,
      retries: method == 'GET' ? _retryBackoff.length : 0,
    );
    return _handleResponse(response);
  }

  /// Runs [attempt], translating transport-level failures into a Thai
  /// [ApiException] and optionally retrying with backoff.
  ///
  /// Without this, losing signal mid-request threw a raw `ClientException with
  /// SocketException: Failed host lookup ...` which several screens render
  /// straight into a snackbar via `e.toString()`.
  Future<http.Response> _withTransportGuard(
    Future<http.Response> Function() attempt, {
    int retries = 0,
  }) async {
    for (var i = 0; ; i++) {
      try {
        return await attempt();
      } on ApiException {
        rethrow;
      } catch (error) {
        final failure = _asTransportFailure(error);
        if (failure == null) rethrow;
        if (i >= retries) throw failure;
        await Future.delayed(_retryBackoff[i]);
      }
    }
  }

  /// Maps a transport-level error onto a user-facing message, or returns null
  /// when the error is something else and should keep bubbling untouched.
  ApiException? _asTransportFailure(Object error) {
    if (error is TimeoutException) {
      return const ApiException(
        'การเชื่อมต่อใช้เวลานานเกินไป กรุณาลองใหม่',
        isNetworkError: true,
      );
    }
    if (error is SocketException || error is HandshakeException) {
      return const ApiException(
        'เชื่อมต่ออินเทอร์เน็ตไม่ได้ กรุณาตรวจสอบสัญญาณแล้วลองใหม่',
        isNetworkError: true,
      );
    }
    if (error is http.ClientException) {
      return const ApiException(
        'การเชื่อมต่อขัดข้อง กรุณาลองใหม่อีกครั้ง',
        isNetworkError: true,
      );
    }
    return null;
  }

  dynamic _handleResponse(http.Response response) {
    final decoded = _decode(response.body);
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    if (response.statusCode == 503) {
      onMaintenance?.call();
      // Always a Thai message: Laravel's default 503 body is the English
      // "Service Unavailable", and the full-screen maintenance gate is what
      // the user actually sees regardless.
      throw const ApiException(
        'ระบบกำลังปิดปรับปรุงชั่วคราว กรุณาลองใหม่อีกครั้ง',
        statusCode: 503,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _message(decoded) ?? 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์',
        statusCode: response.statusCode,
        errors: decoded is Map ? decoded['errors'] : null,
      );
    }
    if (decoded is Map && decoded['success'] == false) {
      throw ApiException(
        decoded['message']?.toString() ?? 'ดำเนินการไม่สำเร็จ',
        statusCode: response.statusCode,
        errors: decoded['errors'],
      );
    }
    return decoded;
  }

  dynamic data(dynamic response) {
    if (response is Map && response.containsKey('data')) {
      return response['data'];
    }
    return response;
  }

  Map<String, dynamic>? meta(dynamic response) {
    if (response is Map && response['meta'] is Map) {
      return Map<String, dynamic>.from(response['meta'] as Map);
    }
    return null;
  }

  dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String? _message(dynamic decoded) {
    if (decoded is Map) {
      return decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          decoded['errors']?.toString();
    }
    return decoded?.toString();
  }
}
