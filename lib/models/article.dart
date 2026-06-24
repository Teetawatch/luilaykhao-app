/// Blog article shown in the app — mirrors the web blog so the same helpful
/// content (and booking funnel via [relatedTrips]) reaches mobile readers.
class Article {
  final int id;
  final String title;
  final String slug;
  final String? excerpt;
  final String? body; // sanitized HTML (detail only)
  final String? coverImageUrl;
  final int readingMinutes;
  final DateTime? publishedAt;
  final ArticleCategory? category;
  final String? authorName;
  final List<String> tags;
  final List<Map<String, dynamic>> relatedTrips;

  const Article({
    required this.id,
    required this.title,
    required this.slug,
    this.excerpt,
    this.body,
    this.coverImageUrl,
    this.readingMinutes = 1,
    this.publishedAt,
    this.category,
    this.authorName,
    this.tags = const [],
    this.relatedTrips = const [],
  });

  bool get hasBody => (body ?? '').trim().isNotEmpty;

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      excerpt: json['excerpt']?.toString(),
      body: json['body']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString(),
      readingMinutes: (json['reading_minutes'] as num?)?.toInt() ?? 1,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString())
          : null,
      category: json['category'] is Map
          ? ArticleCategory.fromJson(Map<String, dynamic>.from(json['category']))
          : null,
      authorName: json['author'] is Map ? json['author']['name']?.toString() : null,
      tags: json['tags'] is List
          ? (json['tags'] as List)
              .map((t) => t is Map ? (t['name'] ?? '').toString() : t.toString())
              .where((t) => t.isNotEmpty)
              .toList()
          : const [],
      relatedTrips: json['trips'] is List
          ? (json['trips'] as List)
              .whereType<Map>()
              .map((t) => Map<String, dynamic>.from(t))
              .toList()
          : const [],
    );
  }
}

class ArticleCategory {
  final int id;
  final String name;
  final String slug;
  final int articlesCount;

  const ArticleCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.articlesCount = 0,
  });

  factory ArticleCategory.fromJson(Map<String, dynamic> json) {
    return ArticleCategory(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      articlesCount: (json['articles_count'] as num?)?.toInt() ?? 0,
    );
  }
}
