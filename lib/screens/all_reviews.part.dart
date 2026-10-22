part of 'trip_detail_screen.dart';

/// Full, paginated wall of every approved customer review across all trips.
/// Reached from the "ดูทั้งหมด" action on the Home "เสียงจากลูกทริป" section.
///
/// Top to bottom: an overview card from `GET reviews/stats` (average, star
/// distribution, per-category scores — tapping a star row filters to it), a
/// filter bar that pins under the app bar, then the review cards with infinite
/// scroll. Reuses [_ReviewCard] (incl. its photo + video viewers) so behaviour
/// stays identical to the trip-detail reviews.
///
/// The stats call is independent of the list: if it fails the page still
/// lists reviews, just without the overview and the counts on the chips.
class AllReviewsScreen extends StatefulWidget {
  const AllReviewsScreen({super.key});

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

/// One filter at a time: everything, only reviews with photos/videos, or an
/// exact star count.
typedef _ReviewFilter = ({int? rating, bool media});

const _ReviewFilter _allReviews = (rating: null, media: false);

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _reviews = [];

  static const int _perPage = 12;

  int _page = 1;
  int _total = 0;
  _ReviewFilter _filter = _allReviews;

  /// Bumped on every reset so a slow page from the previous filter can't land
  /// in the list after the user has already switched.
  int _generation = 0;

  bool _loading = true; // first page (or filter switch)
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;

  Map<String, dynamic>? _stats;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(reset: true);
      _loadStats();
    });
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

  Future<void> _loadStats() async {
    try {
      final stats = await context.read<AppProvider>().reviewStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statsLoading = false);
    }
  }

  Future<void> _load({bool reset = false}) async {
    final generation = ++_generation;
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
        rating: _filter.rating,
        withMedia: _filter.media,
      );
      if (!mounted || generation != _generation) return;
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
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMore() async {
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result = await context.read<AppProvider>().allReviewsPage(
        page: next,
        perPage: _perPage,
        rating: _filter.rating,
        withMedia: _filter.media,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _reviews.addAll(result.items.map(asMap));
        _page = next;
        _hasMore = result.hasMore;
        _total = result.total;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    _loadStats();
    await _load(reset: true);
  }

  void _setFilter(_ReviewFilter filter) {
    if (_filter == filter) return;
    HapticFeedback.selectionClick();
    setState(() {
      _filter = filter;
      _loadingMore = false;
    });
    _load(reset: true);
  }

  /// Tapping the star row that is already the filter clears it again.
  void _toggleRating(int star) {
    _setFilter(_filter.rating == star ? _allReviews : (rating: star, media: false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
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
              backgroundColor: AppTheme.background(context),
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              title: Text(
                'รีวิวจากลูกทริป',
                style: AppTheme.appBarTitleStyle(context),
              ),
              leading: (ModalRoute.canPopOf(context) ?? false)
                  ? IconButton(
                      tooltip: 'ย้อนกลับ',
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppTheme.onSurface(context),
                        size: 19,
                      ),
                      onPressed: () => Navigator.maybePop(context),
                    )
                  : null,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: LoadingFade(
                  loading: _statsLoading,
                  child: _statsLoading
                      ? const _ReviewsOverviewSkeleton()
                      : (_stats != null && _statTotal(_stats!) > 0)
                      ? _ReviewsOverview(
                          stats: _stats!,
                          selectedRating: _filter.rating,
                          onRatingTap: _toggleRating,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ReviewFilterHeader(
                filter: _filter,
                stats: _stats,
                onSelect: _setFilter,
              ),
            ),
            // รวมเป็น sliver เดียว ให้ทั้งก้อนจางขึ้นพร้อมกันตอนโหลดเสร็จ / เปลี่ยน
            // ตัวกรอง (ตอนนั้นโหลดใหม่และโชว์โครงร่างก่อน)
            LoadingFade.sliver(
              loading: _loading,
              sliver: SliverMainAxisGroup(slivers: _buildBody()),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );
  }

  String get _listHeading {
    if (_filter.media) return 'รีวิวที่มีรูปหรือวิดีโอ';
    if (_filter.rating != null) return 'รีวิว ${_filter.rating} ดาว';
    return 'รีวิวล่าสุด';
  }

  List<Widget> _buildBody() {
    if (_loading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.builder(
            itemCount: 3,
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
      final filtered = _filter != _allReviews;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _AllReviewsMessage(
            icon: Icons.reviews_outlined,
            title: filtered ? 'ยังไม่มี$_listHeading' : 'ยังไม่มีรีวิว',
            body: filtered
                ? 'ลองเลือกตัวกรองอื่น หรือดูรีวิวทั้งหมด'
                : 'เมื่อมีรีวิวที่อนุมัติแล้ว จะแสดงที่นี่ทันที',
            actionLabel: filtered ? 'ดูรีวิวทั้งหมด' : null,
            onAction: filtered ? () => _setFilter(_allReviews) : null,
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _listHeading,
                  style: AppText.label(
                    color: AppTheme.mutedText(context),
                    strong: true,
                  ),
                ),
              ),
              Text(
                '${_groupDigits(_total)} รายการ',
                style: AppText.caption(color: AppTheme.mutedText(context)),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: _reviews.length,
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
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        )
      else if (!_hasMore && _reviews.length > 4)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(child: Divider(color: AppTheme.border(context))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'แสดงครบทุกรีวิวแล้ว',
                    style: AppText.caption(color: AppTheme.mutedText(context)),
                  ),
                ),
                Expanded(child: Divider(color: AppTheme.border(context))),
                const SizedBox(width: 40),
              ],
            ),
          ),
        ),
    ];
  }
}

int _statTotal(Map<String, dynamic> stats) =>
    int.tryParse(textOf(stats['total'])) ?? 0;

int _statDistribution(Map<String, dynamic> stats, int star) =>
    int.tryParse(textOf(asMap(stats['distribution'])['$star'])) ?? 0;

/// "1,234" — review counts read better grouped once they pass a thousand.
String _groupDigits(int n) => NumberFormat.decimalPattern().format(n);

/// Average score, star distribution and per-category scores for every
/// approved review. Each distribution row is a filter shortcut.
class _ReviewsOverview extends StatelessWidget {
  final Map<String, dynamic> stats;
  final int? selectedRating;
  final ValueChanged<int> onRatingTap;

  const _ReviewsOverview({
    required this.stats,
    required this.selectedRating,
    required this.onRatingTap,
  });

  static const _categories = <(String, String, IconData)>[
    ('guide', 'ไกด์', Icons.hiking_rounded),
    ('vehicle', 'การเดินทาง', Icons.airport_shuttle_rounded),
    ('food', 'อาหาร', Icons.restaurant_rounded),
    ('value', 'ความคุ้มค่า', Icons.savings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final total = _statTotal(stats);
    final average = num.tryParse(textOf(stats['average'])) ?? 0;
    final categories = asMap(stats['categories']);
    final scored = [
      for (final (key, label, icon) in _categories)
        if (num.tryParse(textOf(asMap(categories[key])['average']))
            case final value? when value > 0)
          (label, icon, value),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 104,
                child: Column(
                  children: [
                    Text(
                      average.toStringAsFixed(1),
                      style: appFont(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        letterSpacing: -1,
                        color: AppTheme.onSurface(context),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StarRow(rating: average.round(), size: 15),
                    const SizedBox(height: 6),
                    Text(
                      '${_groupDigits(total)} รีวิว',
                      style: AppText.caption(color: AppTheme.mutedText(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    for (var star = 5; star >= 1; star--)
                      _DistributionRow(
                        star: star,
                        count: _statDistribution(stats, star),
                        total: total,
                        selected: selectedRating == star,
                        dimmed: selectedRating != null && selectedRating != star,
                        onTap: () => onRatingTap(star),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (scored.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: AppTheme.border(context).withValues(alpha: 0.7)),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final (label, icon, value) in scored)
                  Expanded(
                    child: _CategoryScore(label: label, icon: icon, value: value),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 15,
                color: AppTheme.onTintOf(context, AppTheme.primaryColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ทุกรีวิวมาจากผู้ที่ร่วมทริปจริง',
                  style: AppText.caption(color: AppTheme.mutedText(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final int star;
  final int count;
  final int total;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _DistributionRow({
    required this.star,
    required this.count,
    required this.total,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : count / total;
    final muted = AppTheme.mutedText(context);

    return Semantics(
      button: true,
      selected: selected,
      label: 'กรองรีวิว $star ดาว มี $count รายการ',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: count == 0 && !selected ? null : onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: dimmed ? 0.45 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 10,
                    child: Text(
                      '$star',
                      textAlign: TextAlign.center,
                      style: AppText.caption(
                        color: selected ? AppTheme.onSurface(context) : muted,
                        strong: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.star_rounded, size: 12, color: _starColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: 6,
                        backgroundColor: AppTheme.fieldSurface(context),
                        valueColor: const AlwaysStoppedAnimation(_starColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text(
                      _groupDigits(count),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      style: AppText.caption(
                        color: selected ? AppTheme.onSurface(context) : muted,
                        strong: selected,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryScore extends StatelessWidget {
  final String label;
  final IconData icon;
  final num value;

  const _CategoryScore({
    required this.label,
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.mutedText(context)),
        const SizedBox(height: 6),
        Text(
          value.toStringAsFixed(1),
          style: AppText.subtitle(color: AppTheme.onSurface(context), strong: true),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption(color: AppTheme.mutedText(context)),
        ),
      ],
    );
  }
}

class _ReviewsOverviewSkeleton extends StatelessWidget {
  const _ReviewsOverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = AppTheme.fieldSurface(context);
    Widget bar(double? w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: block,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
    );

    return Container(
      height: 196,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              bar(72, 44),
              const SizedBox(height: 10),
              bar(84, 12),
              const SizedBox(height: 8),
              bar(56, 10),
            ],
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: bar(null, 6),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chips that pin under the app bar. A hairline appears only once
/// reviews are scrolling beneath it.
class _ReviewFilterHeader extends SliverPersistentHeaderDelegate {
  final _ReviewFilter filter;
  final Map<String, dynamic>? stats;
  final ValueChanged<_ReviewFilter> onSelect;

  _ReviewFilterHeader({
    required this.filter,
    required this.stats,
    required this.onSelect,
  });

  static const double _height = 60;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_ReviewFilterHeader old) =>
      old.filter != filter || !identical(old.stats, stats);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final s = stats;
    int? countFor(_ReviewFilter f) {
      if (s == null) return null;
      if (f.media) return int.tryParse(textOf(s['with_media']));
      if (f.rating != null) return _statDistribution(s, f.rating!);
      return _statTotal(s);
    }

    final options = <(_ReviewFilter, String, IconData?, String)>[
      (_allReviews, 'ทั้งหมด', null, 'แสดงรีวิวทั้งหมด'),
      (
        (rating: null, media: true),
        'มีรูป/วิดีโอ',
        Icons.photo_library_outlined,
        'แสดงรีวิวที่มีรูปหรือวิดีโอ',
      ),
      for (var star = 5; star >= 1; star--)
        (
          (rating: star, media: false),
          '$star',
          Icons.star_rounded,
          'แสดงรีวิว $star ดาว',
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background(context),
        border: Border(
          bottom: BorderSide(
            color: overlapsContent
                ? AppTheme.border(context).withValues(alpha: 0.7)
                : Colors.transparent,
          ),
        ),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: options.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (value, label, icon, semantics) = options[i];
            return _ReviewFilterChip(
              label: label,
              semanticLabel: semantics,
              icon: icon,
              count: countFor(value),
              selected: filter == value,
              onTap: () => onSelect(value),
            );
          },
        ),
      ),
    );
  }
}

class _ReviewFilterChip extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final IconData? icon;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _ReviewFilterChip({
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final fill = selected
        ? (dark ? AppTheme.accentColor : AppTheme.primaryColor)
        : AppTheme.surface(context);
    final ink = selected
        ? (dark ? const Color(0xFF052E24) : Colors.white)
        : AppTheme.onSurface(context);
    final iconColor = selected
        ? ink
        : (icon == Icons.star_rounded ? _starColor : AppTheme.mutedText(context));

    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? semanticLabel : '$semanticLabel $count รายการ',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: selected ? fill : AppTheme.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: iconColor),
                const SizedBox(width: 4),
              ],
              Text(label, style: AppText.label(color: ink, strong: true)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  _groupDigits(count!),
                  style: AppText.caption(
                    color: selected
                        ? ink.withValues(alpha: 0.8)
                        : AppTheme.mutedText(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet placeholder card shown while the first page loads.
class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = AppTheme.fieldSurface(context);

    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: block,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.fieldSurface(context),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppTheme.mutedText(context)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.title(color: AppTheme.onSurface(context)),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppText.body(color: AppTheme.mutedText(context)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.onSurface(context),
                side: BorderSide(color: AppTheme.border(context)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
              ),
              child: Text(
                actionLabel!,
                style: AppText.label(color: AppTheme.onSurface(context), strong: true),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
