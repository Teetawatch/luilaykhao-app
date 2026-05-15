import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight JSON-blob cache backed by SharedPreferences.
///
/// Entries are namespaced ("public", "account") so a logout can wipe only
/// the account-scoped portion. Each write is debounced to coalesce bursts
/// (e.g. several setters firing during a single API round trip).
class OfflineCache {
  OfflineCache._();
  static final OfflineCache instance = OfflineCache._();

  static const _prefix = 'offline_cache_v1.';
  static const _accountPrefix = '${_prefix}account.';
  static const _publicPrefix = '${_prefix}public.';

  final Map<String, dynamic> _public = {};
  final Map<String, dynamic> _account = {};
  bool _loaded = false;
  Timer? _flushTimer;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        final name = key.startsWith(_accountPrefix)
            ? key.substring(_accountPrefix.length)
            : key.startsWith(_publicPrefix)
            ? key.substring(_publicPrefix.length)
            : null;
        if (name == null) continue;
        if (key.startsWith(_accountPrefix)) {
          _account[name] = decoded;
        } else {
          _public[name] = decoded;
        }
      } catch (e) {
        debugPrint('OfflineCache decode error for $key: $e');
      }
    }
    _loaded = true;
  }

  T? readPublic<T>(String key) {
    final value = _public[key];
    if (value is T) return value;
    return null;
  }

  T? readAccount<T>(String key) {
    final value = _account[key];
    if (value is T) return value;
    return null;
  }

  void writePublic(String key, Object? value) {
    if (value == null) {
      _public.remove(key);
    } else {
      _public[key] = value;
    }
    _scheduleFlush();
  }

  void writeAccount(String key, Object? value) {
    if (value == null) {
      _account.remove(key);
    } else {
      _account[key] = value;
    }
    _scheduleFlush();
  }

  Future<void> clearAccount() async {
    _account.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_accountPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  Future<void> flush() async {
    _flushTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _public.entries) {
        await prefs.setString(
          '$_publicPrefix${entry.key}',
          jsonEncode(entry.value),
        );
      }
      for (final entry in _account.entries) {
        await prefs.setString(
          '$_accountPrefix${entry.key}',
          jsonEncode(entry.value),
        );
      }
    } catch (e) {
      debugPrint('OfflineCache flush error: $e');
    }
  }
}
