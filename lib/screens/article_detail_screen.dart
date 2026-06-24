import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/article.dart';
import '../providers/article_provider.dart';
import '../theme/app_theme.dart';
import 'trip_detail_screen.dart';

class ArticleDetailScreen extends StatefulWidget {
  final String slug;
  const ArticleDetailScreen({super.key, required this.slug});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Future<Article> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ArticleProvider>().fetchDetail(widget.slug);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.isDark(context) ? AppTheme.bgDark : AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          'บทความ',
          style: appFont(
            color: AppTheme.onSurface(context),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: FutureBuilder<Article>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'โหลดบทความไม่สำเร็จ',
                  style: appFont(color: AppTheme.mutedText(context), fontSize: 15),
                ),
              ),
            );
          }
          return _content(snapshot.data!);
        },
      ),
    );
  }

  Widget _content(Article article) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (article.coverImageUrl != null)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              article.coverImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.category != null)
                Text(
                  article.category!.name,
                  style: appFont(
                    color: AppTheme.primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                article.title,
                style: appFont(
                  color: AppTheme.onSurface(context),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_byline(article)} · อ่าน ${article.readingMinutes} นาที',
                style: appFont(
                  color: AppTheme.mutedText(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: HtmlWidget(
            article.body ?? '',
            textStyle: appFont(
              color: AppTheme.onSurface(context),
              fontSize: 16,
              height: 1.7,
            ),
            onTapUrl: (url) async {
              final uri = Uri.tryParse(url);
              if (uri == null) return false;
              return launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ),
        if (article.tags.isNotEmpty) _tags(article),
        if (article.relatedTrips.isNotEmpty) _funnel(article),
        const SizedBox(height: 32),
      ],
    );
  }

  String _byline(Article article) {
    final author = article.authorName ?? 'ทีมลุยเลเขา';
    final date = article.publishedAt;
    if (date == null) return 'โดย $author';
    return 'โดย $author · ${date.day}/${date.month}/${date.year + 543}';
  }

  Widget _tags(Article article) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: article.tags
            .map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Text(
                    '#$t',
                    style: appFont(
                      color: AppTheme.mutedText(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _funnel(Article article) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2B1E), Color(0xFF087C68)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'อยากออกทริปจริง ๆ แล้วใช่ไหม? 🏕️',
            style: appFont(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'จองกับลุยเลเขา ปลอดภัย มีไกด์มืออาชีพ',
            style: appFont(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 14),
          ...article.relatedTrips.map((trip) => _tripRow(trip)),
        ],
      ),
    );
  }

  Widget _tripRow(Map<String, dynamic> trip) {
    final slug = (trip['slug'] ?? '').toString();
    final title = (trip['title'] ?? 'ทริป').toString();
    final location = trip['location']?.toString();
    final price = trip['price_per_person'];
    final cover = trip['cover_image']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: slug.isEmpty
            ? null
            : () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TripDetailScreen(slug: slug)),
                );
              },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (cover != null && cover.isNotEmpty)
                Image.network(
                  cover,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(width: 84, height: 84),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      if (location != null) ...[
                        const SizedBox(height: 2),
                        Text('📍 $location',
                            style: appFont(color: Colors.white70, fontSize: 12)),
                      ],
                      if (price != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'เริ่ม ${_formatPrice(price)} ฿',
                          style: appFont(
                            color: const Color(0xFFE8A33D),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    final n = (price is num) ? price : num.tryParse(price.toString()) ?? 0;
    return n.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
