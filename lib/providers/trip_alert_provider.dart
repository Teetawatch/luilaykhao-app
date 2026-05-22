import 'package:flutter/foundation.dart';

import '../config/api_endpoints.dart';
import '../services/api_client.dart';

/// Tracks which trips the user has turned the "แจ้งเตือนฉัน" bell on for.
///
/// Unlike the local wishlist, alert subscriptions live on the server so push
/// notifications fire even when the app is closed. This provider mirrors the
/// server state and exposes optimistic toggles for the bell UI.
class TripAlertProvider extends ChangeNotifier {
  final Set<String> _subscribedSlugs = {};
  bool _loaded = false;
  bool _loading = false;

  bool get loaded => _loaded;
  int get count => _subscribedSlugs.length;

  bool isSubscribed(String slug) => _subscribedSlugs.contains(slug);

  /// Pull the current subscriptions from the server. Safe to call repeatedly;
  /// only the first successful load flips [loaded].
  Future<void> load(ApiClient api, {bool force = false}) async {
    if (_loading) return;
    if (_loaded && !force) return;
    if (api.token == null || api.token!.isEmpty) return;

    _loading = true;
    try {
      final res = await api.get(ApiEndpoints.tripAlerts);
      final data = api.data(res);
      _subscribedSlugs.clear();
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            final slug = item['trip_slug']?.toString() ?? '';
            if (slug.isNotEmpty) _subscribedSlugs.add(slug);
          }
        }
      }
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('TripAlert load error: $e');
    } finally {
      _loading = false;
    }
  }

  /// Toggle the bell for [slug]. Optimistically updates local state and reverts
  /// on failure so the icon never lies about the server state.
  Future<bool> toggle(ApiClient api, String slug) async {
    if (slug.isEmpty) return false;
    final wasOn = _subscribedSlugs.contains(slug);

    if (wasOn) {
      _subscribedSlugs.remove(slug);
    } else {
      _subscribedSlugs.add(slug);
    }
    notifyListeners();

    try {
      if (wasOn) {
        await api.delete(ApiEndpoints.tripAlert(slug));
      } else {
        await api.post(ApiEndpoints.tripAlert(slug));
      }
      return !wasOn;
    } catch (e) {
      // Revert optimistic change.
      if (wasOn) {
        _subscribedSlugs.add(slug);
      } else {
        _subscribedSlugs.remove(slug);
      }
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _subscribedSlugs.clear();
    _loaded = false;
    notifyListeners();
  }
}
