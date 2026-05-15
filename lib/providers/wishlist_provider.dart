import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';

/// Local-first wishlist. Tracks favourite trips by slug.
///
/// Items are persisted as a JSON-encoded list in SharedPreferences so removing
/// the app cleans them up naturally — no backend table required for v1.
class WishlistProvider extends ChangeNotifier {
  static const _key = 'wishlist_v1';

  final Map<String, Map<String, dynamic>> _items = {};
  bool _loaded = false;
  bool get loaded => _loaded;

  List<Map<String, dynamic>> get items =>
      _items.values.toList(growable: false);

  int get count => _items.length;

  bool contains(String slug) => _items.containsKey(slug);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final slug = item['slug']?.toString() ?? '';
              if (slug.isEmpty) continue;
              _items[slug] = Map<String, dynamic>.from(item);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Wishlist load error: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<bool> toggle(Map<String, dynamic> trip) async {
    final slug = trip['slug']?.toString() ?? '';
    if (slug.isEmpty) return false;
    final wasFavourite = _items.containsKey(slug);
    if (wasFavourite) {
      _items.remove(slug);
    } else {
      _items[slug] = _summary(trip);
      unawaited(
        AnalyticsService.instance.logEvent(
          'wishlist_added',
          parameters: {'trip_slug': slug},
        ),
      );
    }
    notifyListeners();
    await _flush();
    return !wasFavourite;
  }

  Future<void> remove(String slug) async {
    if (!_items.containsKey(slug)) return;
    _items.remove(slug);
    notifyListeners();
    await _flush();
  }

  Map<String, dynamic> _summary(Map<String, dynamic> trip) {
    return {
      'slug': trip['slug']?.toString() ?? '',
      'title': trip['title']?.toString() ?? '',
      'location': trip['location']?.toString() ?? '',
      'price_per_person': trip['price_per_person'],
      'cover_image': trip['cover_image']?.toString() ?? '',
      'thumbnail_image': trip['thumbnail_image']?.toString() ?? '',
      'type': trip['type']?.toString() ?? '',
      'added_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_items.values.toList()));
    } catch (e) {
      debugPrint('Wishlist flush error: $e');
    }
  }
}
