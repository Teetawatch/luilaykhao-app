import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the last N search queries so the search field can suggest them
/// alongside live results.
class SearchHistoryService {
  SearchHistoryService._();
  static final SearchHistoryService instance = SearchHistoryService._();

  static const _key = 'search_history_v1';
  static const _max = 8;

  Future<List<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> add(String query) async {
    final term = query.trim();
    if (term.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    current
      ..removeWhere((q) => q.toLowerCase() == term.toLowerCase())
      ..insert(0, term);
    if (current.length > _max) current.removeRange(_max, current.length);
    await prefs.setStringList(_key, current);
  }

  Future<void> remove(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    current.removeWhere((q) => q == query);
    await prefs.setStringList(_key, current);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
