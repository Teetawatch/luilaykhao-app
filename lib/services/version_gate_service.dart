import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_client.dart';

class VersionGateResult {
  /// The installed build must be upgraded before the app can be used at all
  /// (current version is below `min_version`). Drives the blocking
  /// [ForceUpdateScreen].
  final bool blocked;

  /// A newer version is on the store but the current build is still usable
  /// (current version is below `latest_version` but at/above `min_version`).
  /// Drives the dismissible "มีเวอร์ชันใหม่" prompt.
  final bool updateAvailable;

  final String? currentVersion;
  final String? minVersion;
  final String? latestVersion;
  final String? message;
  final String? storeUrl;
  final String? iosStoreUrl;
  final String? androidStoreUrl;

  const VersionGateResult({
    required this.blocked,
    this.updateAvailable = false,
    this.currentVersion,
    this.minVersion,
    this.latestVersion,
    this.message,
    this.storeUrl,
    this.iosStoreUrl,
    this.androidStoreUrl,
  });

  static const VersionGateResult ok = VersionGateResult(blocked: false);

  /// The store link appropriate for the current platform, falling back to the
  /// generic `store_url` when a platform-specific link isn't configured.
  String? get resolvedStoreUrl {
    String? platformUrl;
    if (!kIsWeb) {
      if (Platform.isIOS || Platform.isMacOS) {
        platformUrl = iosStoreUrl;
      } else if (Platform.isAndroid) {
        platformUrl = androidStoreUrl;
      }
    }
    final resolved = (platformUrl?.isNotEmpty == true) ? platformUrl : storeUrl;
    return (resolved?.isNotEmpty == true) ? resolved : null;
  }
}

/// Calls a lightweight `GET /app/version` endpoint and compares the response
/// with the locally installed version. The backend response is expected to
/// look like:
///
/// ```json
/// {
///   "data": {
///     "min_version": "1.2.0",
///     "latest_version": "1.8.0",
///     "store_url": "https://play.google.com/...",
///     "ios_store_url": "https://apps.apple.com/...",
///     "android_store_url": "https://play.google.com/...",
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
      final latestVersion = data['latest_version']?.toString();

      final blocked = minVersion != null && minVersion.isNotEmpty
          ? _isOutdated(current, minVersion)
          : false;

      // Only surface the soft prompt when the build is still usable — a blocked
      // build already gets the full-screen force-update flow.
      final updateAvailable = !blocked &&
          latestVersion != null &&
          latestVersion.isNotEmpty &&
          _isOutdated(current, latestVersion);

      return VersionGateResult(
        blocked: blocked,
        updateAvailable: updateAvailable,
        currentVersion: current,
        minVersion: minVersion,
        latestVersion: latestVersion,
        message: data['message']?.toString(),
        storeUrl: data['store_url']?.toString(),
        iosStoreUrl: data['ios_store_url']?.toString(),
        androidStoreUrl: data['android_store_url']?.toString(),
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
