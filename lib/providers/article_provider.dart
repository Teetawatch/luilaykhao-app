import 'package:flutter/foundation.dart';

import '../config/api_endpoints.dart';
import '../models/article.dart';
import '../services/api_client.dart';

/// Loads public blog content for the app. Articles are unauthenticated, so this
/// uses its own [ApiClient] and caches the category filter + paginated list.
class ArticleProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  final List<Article> articles = [];
  final List<ArticleCategory> categories = [];

  bool loading = false;
  bool loadingMore = false;
  String? error;
  String? activeCategorySlug;

  int _page = 1;
  int _lastPage = 1;
  bool get hasMore => _page < _lastPage;

  final Map<String, Article> _detailCache = {};

  Future<void> loadInitial({bool force = false}) async {
    if (articles.isNotEmpty && !force) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await Future.wait([_fetchCategories(), _fetchPage(reset: true)]);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectCategory(String? slug) async {
    if (activeCategorySlug == slug) return;
    activeCategorySlug = slug;
    loading = true;
    notifyListeners();
    try {
      await _fetchPage(reset: true);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      await _fetchPage(reset: false);
    } catch (_) {
      // keep what we have; surface nothing intrusive on pagination failure
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<Article> fetchDetail(String slug) async {
    if (_detailCache.containsKey(slug)) return _detailCache[slug]!;
    final res = await _api.get(ApiEndpoints.article(slug));
    final article = Article.fromJson(Map<String, dynamic>.from(res['data']));
    _detailCache[slug] = article;
    return article;
  }

  Future<void> _fetchCategories() async {
    final res = await _api.get(ApiEndpoints.articleCategories);
    final data = (res['data'] as List?) ?? const [];
    categories
      ..clear()
      ..addAll(data.map((c) => ArticleCategory.fromJson(Map<String, dynamic>.from(c))));
  }

  Future<void> _fetchPage({required bool reset}) async {
    if (reset) _page = 1;
    final res = await _api.get(ApiEndpoints.articles, query: {
      'page': reset ? 1 : _page + 1,
      if (activeCategorySlug != null) 'category': activeCategorySlug,
    });
    final data = (res['data'] as List?) ?? const [];
    final items = data.map((a) => Article.fromJson(Map<String, dynamic>.from(a))).toList();
    final meta = res['meta'] as Map?;
    _page = (meta?['current_page'] as num?)?.toInt() ?? _page;
    _lastPage = (meta?['last_page'] as num?)?.toInt() ?? _page;

    if (reset) {
      articles
        ..clear()
        ..addAll(items);
    } else {
      articles.addAll(items);
    }
  }
}
