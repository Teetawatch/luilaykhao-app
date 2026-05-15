import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TripFilterState {
  final String? type;
  final String? difficulty;
  final num? minPrice;
  final num? maxPrice;
  final String? sort;

  const TripFilterState({
    this.type,
    this.difficulty,
    this.minPrice,
    this.maxPrice,
    this.sort,
  });

  static const empty = TripFilterState();

  Map<String, dynamic> toJson() => {
    if (type != null) 'type': type,
    if (difficulty != null) 'difficulty': difficulty,
    if (minPrice != null) 'min_price': minPrice,
    if (maxPrice != null) 'max_price': maxPrice,
    if (sort != null) 'sort': sort,
  };

  factory TripFilterState.fromJson(Map<String, dynamic> json) {
    return TripFilterState(
      type: json['type']?.toString(),
      difficulty: json['difficulty']?.toString(),
      minPrice: json['min_price'] is num
          ? json['min_price'] as num
          : num.tryParse(json['min_price']?.toString() ?? ''),
      maxPrice: json['max_price'] is num
          ? json['max_price'] as num
          : num.tryParse(json['max_price']?.toString() ?? ''),
      sort: json['sort']?.toString(),
    );
  }
}

/// Lightweight wrapper that persists the AllTrips filter selections so users
/// don't have to re-pick price/type/difficulty every time they open the tab.
class TripFilterStorage {
  TripFilterStorage._();
  static final TripFilterStorage instance = TripFilterStorage._();

  static const _key = 'trip_filter_v1';

  Future<TripFilterState> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return TripFilterState.empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return TripFilterState.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return TripFilterState.empty;
  }

  Future<void> write(TripFilterState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
