import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_client.dart';

class VersionGateResult {
  final bool blocked;
  final String? minVersion;
  final String? message;
  final String? storeUrl;

  const VersionGateResult({
    required this.blocked,
    this.minVersion,
    this.message,
    this.storeUrl,
  });

  static const VersionGateResult ok = VersionGateResult(blocked: false);
}

/// Calls a lightweight `GET /app/version` endpoint and compares the response
/// with the locally installed version. The backend response is expected to
/// look like:
///
/// ```json
/// {
///   "data": {
///     "min_version": "1.2.0",
///     "store_url": "https://play.google.com/...",
///     "message": "อัปเดตเพื่อใช้ฟีเจอร์ใหม่"
///   }
/// }
/// ```
///
/// If the endpoint isn't deployed yet, the service silently degrades to
/// `VersionGateResult.ok` so the app stays usable.
class VersionGateService {
  VersionGateService._();
  static final VersionGateService instance = VersionGateService._();

  Future<VersionGateResult> check(ApiClient api) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final response = await api.get('app/version');
      final data = api.data(response);
      if (data is! Map) return VersionGateResult.ok;

      final minVersion = data['min_version']?.toString();
      if (minVersion == null || minVersion.isEmpty) {
        return VersionGateResult.ok;
      }

      final blocked = _isOutdated(current, minVersion);
      return VersionGateResult(
        blocked: blocked,
        minVersion: minVersion,
        message: data['message']?.toString(),
        storeUrl: data['store_url']?.toString(),
      );
    } catch (e) {
      debugPrint('VersionGate check failed: $e');
      return VersionGateResult.ok;
    }
  }

  bool _isOutdated(String current, String minimum) {
    final c = _parts(current);
    final m = _parts(minimum);
    final length = c.length > m.length ? c.length : m.length;
    for (var i = 0; i < length; i++) {
      final cv = i < c.length ? c[i] : 0;
      final mv = i < m.length ? m[i] : 0;
      if (cv < mv) return true;
      if (cv > mv) return false;
    }
    return false;
  }

  List<int> _parts(String version) {
    return version
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
