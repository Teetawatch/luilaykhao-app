import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/article.dart';
import '../providers/article_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import 'article_detail_screen.dart';

/// "บทความ/ทริคเที่ยว" — helpful articles that draw readers in and funnel them
/// toward booking. Mirrors the web blog.
class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArticleProvider>().loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      context.read<ArticleProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArticleProvider>();

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
        centerTitle: false,
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(ArticleProvider provider) {
    if (provider.loading && provider.articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.articles.isEmpty) {
      return EmptyStateView(
        icon: Icons.wifi_off_rounded,
        title: 'โหลดบทความไม่สำเร็จ',
        body: 'ตรวจสอบการเชื่อมต่อแล้วลองใหม่อีกครั้ง',
        actionLabel: 'ลองใหม่',
        onAction: () => provider.loadInitial(force: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadInitial(force: true),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          if (provider.categories.isNotEmpty)
            SliverToBoxAdapter(child: _CategoryFilter(provider: provider)),
          if (provider.articles.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateView(
                icon: Icons.menu_book_rounded,
                title: 'ยังไม่มีบทความในหมวดนี้',
                body: 'ลองดูหมวดอื่น หรือกลับมาใหม่เร็ว ๆ นี้',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList.separated(
                itemCount: provider.articles.length + (provider.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index >= provider.articles.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _ArticleCard(article: provider.articles[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final ArticleProvider provider;
  const _CategoryFilter({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _chip(context, 'ทั้งหมด', provider.activeCategorySlug == null,
              () => provider.selectCategory(null)),
          for (final c in provider.categories)
            _chip(context, c.name, provider.activeCategorySlug == c.slug,
                () => provider.selectCategory(c.slug)),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryColor : AppTheme.surface(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AppTheme.primaryColor : AppTheme.border(context),
            ),
          ),
          child: Text(
            label,
            style: appFont(
              color: active ? Colors.white : AppTheme.mutedText(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;
  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ArticleDetailScreen(slug: article.slug)),
        );
      },
      child: Container(
        decoration: AppTheme.cardDecoration(context),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.coverImageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  article.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    child: const Icon(Icons.image_outlined, color: Colors.white54),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.category != null)
                    Text(
                      article.category!.name,
                      style: appFont(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    article.title,
                    style: appFont(
                      color: AppTheme.onSurface(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  if (article.excerpt != null && article.excerpt!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      article.excerpt!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        color: AppTheme.mutedText(context),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    '${_formatDate(article.publishedAt)} · อ่าน ${article.readingMinutes} นาที',
                    style: appFont(
                      color: AppTheme.mutedText(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year + 543}';
  }
}
