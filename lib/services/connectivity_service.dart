import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Wrapper around connectivity_plus that exposes an `isOnline` `ValueNotifier`.
///
/// Widgets can `ValueListenableBuilder` against this without importing the
/// underlying package, and we can mock it out cleanly in tests.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  StreamSubscription? _sub;
  final Connectivity _connectivity = Connectivity();

  Future<void> initialize() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      isOnline.value = _hasNetwork(initial);
      _sub = _connectivity.onConnectivityChanged.listen((event) {
        isOnline.value = _hasNetwork(event);
      });
    } catch (e) {
      debugPrint('ConnectivityService init error: $e');
    }
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
