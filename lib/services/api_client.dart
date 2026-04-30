import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? errors;

  const ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

class ApiClient {
  String? token;

  ApiClient({this.token});

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

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
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
    late http.Response response;

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: _headers());
        break;
      case 'POST':
        response = await http.post(uri, headers: _headers(), body: encoded);
        break;
      case 'PUT':
        response = await http.put(uri, headers: _headers(), body: encoded);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: _headers(), body: encoded);
        break;
      default:
        throw ApiException('Unsupported method $method');
    }

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final decoded = _decode(response.body);
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
    if (response is Map && response.containsKey('data'))
      return response['data'];
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
