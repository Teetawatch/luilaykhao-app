import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';
import 'staff_check_in_screen.dart' show asMap, dateText, textOf;

/// รีวิวจากลูกค้า — เปิดจากช่อง "คะแนนเฉลี่ย" ในแท็บงานสตาฟ
///
/// เดิมสตาฟเห็นแค่ตัวเลขเฉลี่ยแต่อ่านไม่ได้ว่าลูกค้าพูดถึงตัวเองว่าอะไร
/// หน้านี้โชว์ภาพรวมดาว แล้วตามด้วยรีวิวทีละอันพร้อมคอมเมนต์ ใหม่สุดก่อน
class StaffReviewsScreen extends StatefulWidget {
  /// ภาพรวมจากแท็บงานสตาฟ — ให้หัวหน้าขึ้นทันทีระหว่างรอหน้าแรก
  final Map<String, dynamic> initialSummary;

  const StaffReviewsScreen({super.key, this.initialSummary = const {}});

  @override
  State<StaffReviewsScreen> createState() => _StaffReviewsScreenState();
}

class _StaffReviewsScreenState extends State<StaffReviewsScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  late Map<String, dynamic> _summary = widget.initialSummary;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 400) _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_hasMore)) return;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      final page = reset ? 1 : _page + 1;
      final result = await context.read<AppProvider>().staffReviewsPage(
        page: page,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items.map(asMap));
        if (result.summary.isNotEmpty) _summary = result.summary;
        _page = page;
        _hasMore = result.hasMore;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadedOnce = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'รีวิวจากลูกค้า',
          style: appFont(
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_loadedOnce && _items.isEmpty) {
      return const SkeletonList(count: 5, padding: EdgeInsets.only(top: 8));
    }
    if (_items.isEmpty && _error != null) {
      return ScrollableEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'โหลดรีวิวไม่สำเร็จ',
        body: _error!,
        actionLabel: 'ลองใหม่',
        onAction: () => _load(reset: true),
        accent: AppTheme.errorColor,
      );
    }
    if (_items.isEmpty) {
      return const ScrollableEmptyState(
        icon: Icons.rate_review_outlined,
        title: 'ยังไม่มีรีวิว',
        body: 'เมื่อลูกค้ารีวิวการดูแลของคุณหลังจบทริป จะขึ้นที่นี่',
      );
    }

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _items.length + 2,
      separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 16 : 10),
      itemBuilder: (context, i) {
        if (i == 0) return _SummaryCard(summary: _summary);
        if (i == _items.length + 1) return _buildFooter();
        return _ReviewCard(review: _items[i - 1]);
      },
    );
  }

  Widget _buildFooter() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (_error != null && _hasMore) {
      return Center(
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('โหลดเพิ่มไม่สำเร็จ ลองใหม่'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

int _int(dynamic v) => int.tryParse(textOf(v, '0')) ?? 0;

class _Stars extends StatelessWidget {
  final int rating;
  final double size;

  const _Stars({required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < rating
              ? AppTheme.warningColor
              : AppTheme.mutedText(context).withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// คะแนนเฉลี่ยตัวใหญ่ + แท่งจำนวนรีวิวแยกตามดาว
class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = _int(summary['total_reviews']);
    final avg = double.tryParse(textOf(summary['avg_rating'])) ?? 0.0;
    final breakdown = asMap(summary['breakdown']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                total == 0 ? '–' : avg.toStringAsFixed(1),
                style: appFont(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                  letterSpacing: -0.8,
                ),
              ),
              _Stars(rating: avg.round(), size: 15),
              const SizedBox(height: 4),
              Text(
                '$total รีวิว',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
          // เซิร์ฟเวอร์เก่าไม่ส่ง breakdown มา — โชว์แค่ตัวเลขเฉลี่ยก็พอ
          if (breakdown.isNotEmpty && total > 0) ...[
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  for (final star in const [5, 4, 3, 2, 1])
                    _BreakdownRow(
                      star: star,
                      count: _int(breakdown['$star']),
                      total: total,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final int star;
  final int count;
  final int total;

  const _BreakdownRow({
    required this.star,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              '$star',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
          ),
          const Icon(
            Icons.star_rounded,
            size: 12,
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : count / total,
                minHeight: 6,
                backgroundColor: AppTheme.border(context),
                valueColor: const AlwaysStoppedAnimation(AppTheme.warningColor),
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// รีวิวหนึ่งอัน — ดาว วันที่ คอมเมนต์ แล้วบอกว่าใครเขียนจากทริปไหน
class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = _int(review['rating']).clamp(0, 5);
    final comment = textOf(review['comment']).trim();
    final reviewer = textOf(review['reviewer_name'], 'ลูกค้า');
    final trip = textOf(review['trip_title']);
    final departure = textOf(review['departure_date']);
    final muted = AppTheme.mutedText(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Stars(rating: rating),
              const Spacer(),
              Text(
                dateText(review['created_at']),
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.isEmpty
                ? 'ให้คะแนนอย่างเดียว ไม่ได้เขียนความคิดเห็น'
                : comment,
            style: comment.isEmpty
                ? appFont(
                    fontSize: AppText.sizeLabel,
                    fontStyle: FontStyle.italic,
                    color: muted,
                  )
                : appFont(
                    fontSize: AppText.sizeBody,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurface(context),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 15, color: muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [
                    reviewer,
                    if (trip.isNotEmpty) trip,
                    if (departure.isNotEmpty) 'รอบ ${dateText(departure)}',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
