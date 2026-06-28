part of 'trip_detail_screen.dart';

/// Full, paginated wall of every approved customer review across all trips.
/// Reached from the "ดูทั้งหมด" action on the Home "เสียงจากลูกทริป" section.
///
/// Design leans iOS/Apple: a large collapsing title, a quiet stats line, a
/// segmented star filter, then a generously spaced column of review cards with
/// infinite scroll. Reuses [_ReviewCard] (incl. its photo + video viewers) so
/// behaviour stays identical to the trip-detail reviews.
class AllReviewsScreen extends StatefulWidget {
  const AllReviewsScreen({super.key});

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _reviews = [];

  static const int _perPage = 12;

  int _page = 1;
  int _total = 0;
  int? _ratingFilter;

  bool _loading = true; // first page (or filter switch)
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _hasError = false;
        _page = 1;
        _hasMore = true;
      });
    }

    try {
      final result = await context.read<AppProvider>().allReviewsPage(
        page: 1,
        perPage: _perPage,
        rating: _ratingFilter,
      );
      if (!mounted) return;
      setState(() {
        _reviews
          ..clear()
          ..addAll(result.items.map(asMap));
        _total = result.total;
        _hasMore = result.hasMore;
        _page = 1;
        _loading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result = await context.read<AppProvider>().allReviewsPage(
        page: next,
        perPage: _perPage,
        rating: _ratingFilter,
      );
      if (!mounted) return;
      setState(() {
        _reviews.addAll(result.items.map(asMap));
        _page = next;
        _hasMore = result.hasMore;
        _total = result.total;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _refresh() => _load(reset: true);

  void _setFilter(int? rating) {
    if (_ratingFilter == rating) return;
    HapticFeedback.selectionClick();
    setState(() => _ratingFilter = rating);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        color: _softAccent,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: Theme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: 0.85),
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              title: Text(
                'รีวิวจากลูกทริป',
                style: appFont(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              leading: Navigator.canPop(context)
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark
                              ? Theme.of(context).colorScheme.onSurface
                              : AppTheme.textMain,
                          size: 19,
                        ),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    )
                  : null,
            ),
            SliverToBoxAdapter(child: _buildHeader(isDark)),
            ..._buildBody(isDark),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_loading && !_hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
            child: Text(
              _total > 0
                  ? 'รีวิวจริง $_total รายการจากผู้ที่เดินทางไปกับเรา'
                  : 'ความประทับใจจากผู้ที่เดินทางไปกับเรา',
              style: appFont(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: _mutedText,
              ),
            ),
          ),
        const SizedBox(height: 14),
        _RatingFilterBar(selected: _ratingFilter, onSelect: _setFilter),
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _buildBody(bool isDark) {
    if (_loading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => const _ReviewSkeleton(),
          ),
        ),
      ];
    }

    if (_hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _AllReviewsMessage(
            icon: Icons.wifi_off_rounded,
            title: 'โหลดรีวิวไม่สำเร็จ',
            body: 'ตรวจสอบการเชื่อมต่อแล้วลองใหม่อีกครั้ง',
            actionLabel: 'ลองใหม่',
            onAction: () => _load(reset: true),
          ),
        ),
      ];
    }

    if (_reviews.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _AllReviewsMessage(
            icon: Icons.reviews_outlined,
            title: _ratingFilter == null
                ? 'ยังไม่มีรีวิว'
                : 'ยังไม่มีรีวิว $_ratingFilter ดาว',
            body: _ratingFilter == null
                ? 'เมื่อมีรีวิวที่อนุมัติแล้ว จะแสดงที่นี่ทันที'
                : 'ลองเลือกตัวกรองคะแนนอื่น',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        sliver: SliverList.separated(
          itemCount: _reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final review = _reviews[index];
            return _ReviewCard(
              review: review,
              tripTitle: textOf(review['trip_title']),
            );
          },
        ),
      ),
      if (_loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _softAccent,
                ),
              ),
            ),
          ),
        )
      else if (!_hasMore && _reviews.length > 4)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'แสดงครบทุกรีวิวแล้ว',
                style: appFont(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _mutedText.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

/// Horizontally scrolling segmented pills to filter reviews by exact star count.
class _RatingFilterBar extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onSelect;

  const _RatingFilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final options = <(int?, String)>[
      (null, 'ทั้งหมด'),
      (5, '5'),
      (4, '4'),
      (3, '3'),
      (2, '2'),
      (1, '1'),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (value, label) = options[i];
          final active = selected == value;
          return GestureDetector(
            onTap: () => onSelect(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? _softAccent
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF1F5F4)),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: active
                      ? _softAccent
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value != null)
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: active ? Colors.white : const Color(0xFFF59E0B),
                    ),
                  if (value != null) const SizedBox(width: 3),
                  Text(
                    label,
                    style: appFont(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? Colors.white
                          : (isDark ? Colors.white70 : _premiumText),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Quiet placeholder card shown while the first page loads.
class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final base = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF1F5F4);
    final block = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE6EBEA);

    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: block,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: block, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(120, 12),
                  const SizedBox(height: 8),
                  bar(80, 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          bar(double.infinity, 10),
          const SizedBox(height: 8),
          bar(double.infinity, 10),
          const SizedBox(height: 8),
          bar(180, 10),
        ],
      ),
    );
  }
}

/// Centered icon + message used for the empty and error states.
class _AllReviewsMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _AllReviewsMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF1F5F4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: _mutedText),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : _premiumText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: _mutedText,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: _softAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: Text(
                actionLabel!,
                style: appFont(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
