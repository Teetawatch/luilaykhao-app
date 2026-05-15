import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around flutter_secure_storage with sensible Android options.
///
/// We keep the API surface tiny on purpose — the only things the app needs
/// to persist securely are the Sanctum token and the biometric unlock flag.
class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static const _authTokenKey = 'auth_token_v1';
  static const _biometricEnabledKey = 'biometric_enabled_v1';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _authTokenKey);
    } catch (e) {
      debugPrint('SecureStorage.readToken error: $e');
      return null;
    }
  }

  Future<void> writeToken(String token) async {
    try {
      await _storage.write(key: _authTokenKey, value: token);
    } catch (e) {
      debugPrint('SecureStorage.writeToken error: $e');
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _authTokenKey);
    } catch (_) {}
  }

  Future<bool> readBiometricEnabled() async {
    try {
      final raw = await _storage.read(key: _biometricEnabledKey);
      return raw == '1';
    } catch (_) {
      return false;
    }
  }

  Future<void> writeBiometricEnabled(bool enabled) async {
    try {
      await _storage.write(
        key: _biometricEnabledKey,
        value: enabled ? '1' : '0',
      );
    } catch (e) {
      debugPrint('SecureStorage.writeBiometricEnabled error: $e');
    }
  }
}
