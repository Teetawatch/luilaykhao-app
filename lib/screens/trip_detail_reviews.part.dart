part of 'trip_detail_screen.dart';

class ReviewSection extends StatefulWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;

  const ReviewSection({super.key, required this.trip, required this.reviews});

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  static const _initialCount = 3;
  static const _pageSize = 10;

  late List<dynamic> _reviews;
  bool _expanded = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _recovering = false;
  int _page = 1;
  int? _totalCount;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant ReviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.reviews, widget.reviews)) {
      _syncFromWidget();
    }
  }

  /// Seeds local state from the first page handed in by the parent. The trip's
  /// aggregate `review_count` tells us whether the server has more than this
  /// first page so we can offer to load the rest.
  void _syncFromWidget() {
    _reviews = List<dynamic>.of(widget.reviews);
    _page = 1;
    _expanded = false;
    final total = int.tryParse(textOf(widget.trip['review_count']));
    _totalCount = total;
    _hasMore = total != null && total > _reviews.length;
    // The parent bundles the first page of reviews with the trip load; if that
    // sub-request failed transiently the list arrives empty even though the
    // trip advertises reviews (review_count > 0). Recover by fetching page 1
    // ourselves so the user doesn't have to leave and reopen the screen.
    if (_reviews.isEmpty && (total ?? 0) > 0) {
      _recoverFirstPage();
    }
  }

  Future<void> _recoverFirstPage() async {
    if (_recovering) return;
    final tripId = int.tryParse(textOf(widget.trip['id'])) ?? 0;
    if (tripId <= 0) return;
    _recovering = true;
    try {
      final app = Provider.of<AppProvider>(context, listen: false);
      final result = await app.tripReviewsPage(
        tripId,
        page: 1,
        perPage: _pageSize,
      );
      if (!mounted || result.items.isEmpty) return;
      setState(() {
        _reviews = result.items;
        _page = 1;
        _hasMore = result.hasMore;
      });
    } catch (_) {
      // Leave empty; the aggregate rating summary still renders.
    } finally {
      _recovering = false;
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final app = Provider.of<AppProvider>(context, listen: false);
      final tripId = int.tryParse(textOf(widget.trip['id'])) ?? 0;
      final result = await app.tripReviewsPage(
        tripId,
        page: _page + 1,
        perPage: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page += 1;
        _reviews = [..._reviews, ...result.items];
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final reviews = _reviews;
    final rating = _ratingValue(trip);
    final count = _reviewCount(trip, reviews);
    final hasReviews = count > 0 && rating > 0;
    final visibleReviews = _expanded
        ? reviews
        : reviews.take(_initialCount).toList();
    // Total still hidden behind the collapsed preview — counting reviews not
    // yet fetched from the server, so the button advertises the real remainder.
    final knownTotal = (_totalCount != null && _totalCount! > reviews.length)
        ? _totalCount!
        : reviews.length;
    final collapsedHidden = knownTotal - _initialCount;

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header row ──────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  icon: Icons.star_border_rounded,
                  title: 'รีวิว',
                ),
              ),
              if (hasReviews) _RatingPill(trip: trip, reviews: reviews),
            ],
          ),

          if (!hasReviews) ...[
            const SizedBox(height: 20),
            // ── empty state ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.subtleSurface(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Icon(
                      Icons.rate_review_outlined,
                      size: 30,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ยังไม่มีรีวิว',
                    style: appFont(
                      fontSize: AppText.sizeSubtitle,
                      fontWeight: FontWeight.w800,
                      color: _premiumText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'เป็นคนแรกที่มาสัมผัสและแชร์ประสบการณ์',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      color: _mutedText,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            // ── rating summary bar ───────────────────────────────
            _ReviewRatingSummary(trip: trip, reviews: reviews),
            const SizedBox(height: 20),
            Divider(height: 1, color: AppTheme.subtleSurface(context)),
            const SizedBox(height: 16),
            // ── review cards ────────────────────────────────────
            ...visibleReviews.map((reviewData) {
              final review = asMap(reviewData);
              return _ReviewCard(review: review);
            }),
            // ── show more / load more / show less ────────────────
            if (!_expanded && collapsedHidden > 0) ...[
              const SizedBox(height: 4),
              _ShowMoreReviewsButton(
                label: 'แสดงเพิ่มเติม ($collapsedHidden)',
                icon: Icons.keyboard_arrow_down_rounded,
                onPressed: () => setState(() => _expanded = true),
              ),
            ] else if (_expanded && _hasMore) ...[
              const SizedBox(height: 4),
              _ShowMoreReviewsButton(
                label: 'โหลดรีวิวเพิ่มเติม',
                icon: Icons.expand_more_rounded,
                loading: _loadingMore,
                onPressed: _loadMore,
              ),
            ] else if (_expanded && reviews.length > _initialCount) ...[
              const SizedBox(height: 4),
              _ShowMoreReviewsButton(
                label: 'แสดงน้อยลง',
                icon: Icons.keyboard_arrow_up_rounded,
                onPressed: () => setState(() => _expanded = false),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ShowMoreReviewsButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;

  const _ShowMoreReviewsButton({
    required this.label,
    required this.icon,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: const Color(0xFFEEF2F7)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: loading
                ? [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _premiumText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'กำลังโหลด...',
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        color: _premiumText,
                      ),
                    ),
                  ]
                : [
                    Text(
                      label,
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        color: _premiumText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(icon, size: 20, color: _premiumText),
                  ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRatingSummary extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;

  const _ReviewRatingSummary({required this.trip, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final rating = _ratingValue(trip);
    final count = _reviewCount(trip, reviews);

    // count per star from review list
    final starCounts = List.filled(5, 0);
    for (final r in reviews) {
      final v = _ratingValue(asMap(r)).round().clamp(1, 5);
      starCounts[v - 1]++;
    }

    final breakdown = _tripBreakdownAverages(trip);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // big score
            Column(
              children: [
                Text(
                  numberText(rating, fallback: '0'),
                  style: appFont(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: _premiumText,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final full = i < rating.floor();
                    final half = !full && i < rating;
                    return Icon(
                      full
                          ? Icons.star_rounded
                          : half
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: const Color(0xFFE8A117),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count รีวิว',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: _mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            // star bars
            Expanded(
              child: Column(
                children: List.generate(5, (i) {
                  final star = 5 - i;
                  final c = reviews.isEmpty ? 0 : starCounts[star - 1];
                  final pct = reviews.isEmpty ? 0.0 : c / reviews.length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          '$star',
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w700,
                            color: _mutedText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star_rounded,
                          size: 11,
                          color: Color(0xFFE8A117),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: AppTheme.subtleSurface(context),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFE8A117),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 20,
                          child: Text(
                            '$c',
                            style: appFont(
                              fontSize: AppText.sizeCaption,
                              color: _mutedText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        if (breakdown.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: breakdown
                .map((b) => _CategoryAverageTile(label: b.$1, value: b.$2))
                .toList(),
          ),
        ],
      ],
    );
  }
}

/// Reads the trip's aggregate `rating_breakdown` map into ordered
/// (label, value) pairs, skipping categories with no data.
List<(String, num)> _tripBreakdownAverages(Map<String, dynamic> trip) {
  final raw = asMap(trip['rating_breakdown']);
  const labels = {
    'guide': 'ไกด์',
    'vehicle': 'รถ',
    'food': 'อาหาร',
    'value': 'ความคุ้มค่า',
  };
  final result = <(String, num)>[];
  labels.forEach((key, label) {
    final v = raw[key];
    final value = v is num ? v : num.tryParse('${v ?? ''}');
    if (value != null && value > 0) result.add((label, value));
  });
  return result;
}

class _CategoryAverageTile extends StatelessWidget {
  final String label;
  final num value;

  const _CategoryAverageTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: const Color(0xFFEEF2F7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: _mutedText,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFE8A117)),
          const SizedBox(width: 2),
          Text(
            numberText(value),
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w800,
              color: _premiumText,
            ),
          ),
        ],
      ),
    );
  }
}

const Color _starColor = Color(0xFFF59E0B);

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  /// When set, the card ends with a tappable trip row. Used by the
  /// all-reviews screen (where reviews span many trips); left null inside a
  /// single trip's detail page, where the trip is already obvious.
  final String? tripTitle;

  const _ReviewCard({required this.review, this.tripTitle});

  @override
  Widget build(BuildContext context) {
    final user = asMap(review['user']);
    final rating = _ratingValue(review).round().clamp(0, 5);
    final comment = textOf(review['comment']).trim();
    final name = textOf(user['name'], 'ผู้ใช้ทั่วไป');
    final date = _formatRelativeDate(review['created_at']);
    final tier = TierBadge.fromUser(user, compact: true);
    final images = asList(review['images'])
        .map((e) => ApiConfig.mediaUrl(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();
    final videos = asList(review['videos'])
        .map((e) => ApiConfig.mediaUrl(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();
    final breakdown = _reviewBreakdown(review);
    final reply = textOf(review['admin_reply']).trim();
    final trip = tripTitle?.trim() ?? '';
    final showTrip = trip.isNotEmpty && trip != '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReviewAvatar(
                        name: name,
                        url: ApiConfig.mediaUrl(textOf(user['avatar_url'])),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name and tier badge wrap rather than squeeze, so a
                            // long Thai name never pushes the badge off-card.
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                    color: AppTheme.onSurface(context),
                                    strong: true,
                                  ),
                                ),
                                ?tier,
                              ],
                            ),
                            const SizedBox(height: 2),
                            // Stars and the relative date share one line when
                            // there's room; on a narrow phone or a large text
                            // scale the date drops to its own line.
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                _StarRow(rating: rating, size: 14),
                                if (date.isNotEmpty)
                                  Text(
                                    date,
                                    maxLines: 1,
                                    style: AppText.caption(
                                      color: AppTheme.mutedText(context),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _ReviewModerationButton(review: review),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ExpandableReviewText(text: comment),
                    ),
                  ],
                  if (breakdown.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: breakdown
                          .map(
                            (b) => _ReviewBreakdownChip(label: b.$1, value: b.$2),
                          )
                          .toList(),
                    ),
                  ],
                  if (videos.isNotEmpty || images.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ReviewMediaStrip(images: images, videos: videos),
                  ],
                  if (reply.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ReviewReply(
                        text: reply,
                        date: _formatRelativeDate(review['admin_replied_at']),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showTrip)
              _ReviewTripRow(
                title: trip,
                slug: textOf(review['trip_slug']).trim(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Five small stars, filled up to [rating].
class _StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const _StarRow({required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rating จาก 5 ดาว',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (i) => Icon(
              Icons.star_rounded,
              size: size,
              color: i < rating
                  ? _starColor
                  : AppTheme.border(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reviewer photo, or a flat tinted circle with their initial.
class _ReviewAvatar extends StatelessWidget {
  final String name;
  final String url;

  const _ReviewAvatar({required this.name, required this.url});

  static const double _size = 40;
  static const _hues = [
    AppTheme.primaryColor,
    AppTheme.infoColor,
    AppTheme.warningColor,
    AppTheme.flashSaleColor,
  ];

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty
        ? name.trim().characters.first.toUpperCase()
        : '?';
    final hue = _hues[initial.codeUnitAt(0) % _hues.length];
    final fallback = Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.tintOf(context, hue),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: appFont(
          color: AppTheme.onTintOf(context, hue),
          fontWeight: FontWeight.w800,
          fontSize: AppText.sizeSubtitle,
        ),
      ),
    );
    if (url.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        memCacheWidth: _thumbCacheWidth(context, _size),
        maxWidthDiskCache: _thumbCacheWidth(context, _size),
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

/// Review body clamped to a few lines with an "อ่านต่อ" toggle, so one long
/// story doesn't push every other review a screen further down.
class _ExpandableReviewText extends StatefulWidget {
  final String text;

  const _ExpandableReviewText({required this.text});

  static const int collapsedLines = 5;

  @override
  State<_ExpandableReviewText> createState() => _ExpandableReviewTextState();
}

class _ExpandableReviewTextState extends State<_ExpandableReviewText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = appFont(
      fontSize: AppText.sizeBody,
      height: 1.6,
      color: AppTheme.onSurface(context).withValues(alpha: 0.86),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: _ExpandableReviewText.collapsedLines,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : _ExpandableReviewText.collapsedLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (overflows)
              MinTapTarget(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _expanded = !_expanded);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _expanded ? 'ย่อ' : 'อ่านต่อ',
                      style: AppText.label(
                        color: AppTheme.primaryColor,
                        strong: true,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Videos then photos in one swipeable row of square-cornered tiles.
class _ReviewMediaStrip extends StatelessWidget {
  final List<String> images;
  final List<String> videos;

  const _ReviewMediaStrip({required this.images, required this.videos});

  static const double _tile = 88;

  @override
  Widget build(BuildContext context) {
    final count = videos.length + images.length;
    return SizedBox(
      height: _tile,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 8),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i < videos.length) {
            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => _FullscreenVideoPlayer(url: videos[i]),
                ),
              ),
              child: _VideoThumbCard(
                url: videos[i],
                index: i,
                width: 124,
                height: _tile,
                showLabel: false,
                // Reviews stack unbounded video tiles in a non-recycling
                // Column as more pages load; a live decoder per tile would
                // exhaust the platform pool and crash. Show the static
                // poster placeholder — tapping still opens a real player.
                livePreview: false,
              ),
            );
          }
          final index = i - videos.length;
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) =>
                    _FullscreenGallery(images: images, initialIndex: index),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: CachedNetworkImage(
                imageUrl: images[index],
                width: _tile,
                height: _tile,
                fit: BoxFit.cover,
                memCacheWidth: _thumbCacheWidth(context, _tile),
                maxWidthDiskCache: _thumbCacheWidth(context, _tile),
                placeholder: (_, _) => Container(
                  width: _tile,
                  height: _tile,
                  color: AppTheme.subtleSurface(context),
                ),
                errorWidget: (_, _, _) => Container(
                  width: _tile,
                  height: _tile,
                  color: AppTheme.subtleSurface(context),
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 22,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The team's public answer to a review (`admin_reply`), set apart as a quiet
/// indented block so it reads as a reply rather than part of the review.
class _ReviewReply extends StatelessWidget {
  final String text;
  final String date;

  const _ReviewReply({required this.text, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reply_rounded,
                size: 16,
                color: AppTheme.onTintOf(context, AppTheme.primaryColor),
              ),
              const SizedBox(width: 6),
              Text(
                'ตอบกลับจากทีมงาน',
                style: AppText.label(
                  color: AppTheme.onSurface(context),
                  strong: true,
                ),
              ),
              if (date.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '· $date',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption(color: AppTheme.mutedText(context)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: appFont(
              fontSize: AppText.sizeLabel,
              height: 1.55,
              color: AppTheme.onSurface(context).withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer row naming the trip a review belongs to; opens that trip.
class _ReviewTripRow extends StatelessWidget {
  final String title;
  final String slug;

  const _ReviewTripRow({required this.title, required this.slug});

  @override
  Widget build(BuildContext context) {
    final canOpen = slug.isNotEmpty;
    return Material(
      color: AppTheme.surface(context),
      child: InkWell(
        onTap: canOpen
            ? () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TripDetailScreen(slug: slug),
                  ),
                );
              }
            : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppTheme.border(context).withValues(alpha: 0.7),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.terrain_rounded,
                size: 16,
                color: AppTheme.onTintOf(context, AppTheme.primaryColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label(
                    color: AppTheme.onSurface(context),
                    strong: true,
                  ),
                ),
              ),
              if (canOpen)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.mutedText(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decode width (physical px) for a thumbnail of [logicalWidth] logical px.
/// Review photos are full-resolution camera uploads and every loaded card
/// stays mounted in the trip detail's single non-recycling sliver, so images
/// decoded at native size accumulate until the OS kills the app — cap the
/// decode at what the tile actually displays. Width only, so the decoded
/// frame keeps its aspect ratio for BoxFit.cover.
int _thumbCacheWidth(BuildContext context, double logicalWidth) {
  final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
  return (logicalWidth * dpr).round();
}

/// Extracts non-null per-category sub-ratings from a review map as
/// (label, value) pairs, in display order.
List<(String, num)> _reviewBreakdown(Map<String, dynamic> review) {
  const labels = {
    'rating_guide': 'ไกด์',
    'rating_vehicle': 'รถ',
    'rating_food': 'อาหาร',
    'rating_value': 'คุ้มค่า',
  };
  final result = <(String, num)>[];
  labels.forEach((key, label) {
    final raw = review[key];
    final value = raw is num ? raw : num.tryParse('${raw ?? ''}');
    if (value != null && value > 0) result.add((label, value));
  });
  return result;
}

/// Flattens the photo URLs out of a list of reviews, in order.
List<String> _collectReviewPhotos(List<dynamic> reviews) {
  final photos = <String>[];
  for (final r in reviews) {
    for (final img in asList(asMap(r)['images'])) {
      final url = ApiConfig.mediaUrl(img.toString());
      if (url.isNotEmpty) photos.add(url);
    }
  }
  return photos;
}

/// Gallery of photos pulled from all community reviews of this trip.
///
/// The parent only hands us the first page of reviews, so this seeds from that
/// for an instant render and then quietly pages through the rest in the
/// background, collecting every photo so the strip and fullscreen gallery show
/// the complete set.
class CommunityPhotosSection extends StatefulWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;

  const CommunityPhotosSection({
    super.key,
    required this.trip,
    required this.reviews,
  });

  @override
  State<CommunityPhotosSection> createState() => _CommunityPhotosSectionState();
}

class _CommunityPhotosSectionState extends State<CommunityPhotosSection> {
  late List<String> _photos;

  @override
  void initState() {
    super.initState();
    _photos = _collectReviewPhotos(widget.reviews);
    _loadRemainingPhotos();
  }

  /// Pages through every remaining review (beyond the first page already in
  /// hand) and appends any photos we haven't seen yet.
  Future<void> _loadRemainingPhotos() async {
    final total = int.tryParse(textOf(widget.trip['review_count'])) ?? 0;
    if (total <= widget.reviews.length) return;

    final tripId = int.tryParse(textOf(widget.trip['id'])) ?? 0;
    if (tripId <= 0) return;

    final app = Provider.of<AppProvider>(context, listen: false);
    final collected = <String>[..._photos];
    final seen = collected.toSet();
    // Start from page 1 (not 2) when the bundled first page arrived empty —
    // otherwise a transient first-page failure also drops page 1's photos.
    var page = widget.reviews.isEmpty ? 0 : 1;
    var hasMore = true;

    while (hasMore && mounted) {
      page += 1;
      try {
        final result = await app.tripReviewsPage(tripId, page: page);
        for (final url in _collectReviewPhotos(result.items)) {
          if (seen.add(url)) collected.add(url);
        }
        hasMore = result.hasMore;
      } catch (_) {
        break;
      }
    }

    if (mounted && collected.length != _photos.length) {
      setState(() => _photos = collected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    if (photos.isEmpty) return const SizedBox.shrink();

    const previewCount = 8;
    final preview = photos.take(previewCount).toList();
    final extra = photos.length - preview.length;

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  icon: Icons.photo_library_outlined,
                  title: 'รูปจากนักเดินทาง',
                ),
              ),
              Text(
                '${photos.length} รูป',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  color: _mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: preview.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final isLast = i == preview.length - 1 && extra > 0;
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) =>
                          _FullscreenGallery(images: photos, initialIndex: i),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: preview[i],
                          width: 104,
                          height: 104,
                          fit: BoxFit.cover,
                          memCacheWidth: _thumbCacheWidth(context, 104),
                          maxWidthDiskCache: _thumbCacheWidth(context, 104),
                          placeholder: (_, _) => Container(
                            width: 104,
                            height: 104,
                            color: AppTheme.subtleSurface(context),
                          ),
                          errorWidget: (_, _, _) => Container(
                            width: 104,
                            height: 104,
                            color: AppTheme.subtleSurface(context),
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ),
                        if (isLast)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.45),
                              alignment: Alignment.center,
                              child: Text(
                                '+$extra',
                                style: appFont(
                                  color: Colors.white,
                                  fontSize: AppText.sizeH2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewBreakdownChip extends StatelessWidget {
  final String label;
  final num value;

  const _ReviewBreakdownChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppText.caption(color: AppTheme.mutedText(context)),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.star_rounded, size: 12, color: _starColor),
          const SizedBox(width: 2),
          Text(
            numberText(value),
            style: AppText.caption(
              color: AppTheme.onSurface(context),
              strong: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ฟีดรูปหลังทริป — พรีวิวโพสต์ล่าสุดของทริปนี้ + ทางเข้าฟีดเต็ม
// ─────────────────────────────────────────────────────────────────────────────

class TripFeedSection extends StatefulWidget {
  final Map<String, dynamic> trip;

  const TripFeedSection({super.key, required this.trip});

  @override
  State<TripFeedSection> createState() => _TripFeedSectionState();
}

class _TripFeedSectionState extends State<TripFeedSection> {
  List<Map<String, dynamic>> _posts = const [];
  bool _loading = true;
  bool _canPost = false;
  int _total = 0;

  String get _slug => textOf(widget.trip['slug']);
  String get _title => textOf(widget.trip['title'], 'ทริปนี้');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_slug.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final response = await context.read<AppProvider>().tripPosts(
        slug: _slug,
      );
      if (!mounted) return;
      final meta = asMap(response['meta']);
      setState(() {
        _posts = asList(response['data']).map(asMap).toList();
        _total = int.tryParse(textOf(meta['total'])) ?? _posts.length;
        _canPost = meta['can_post'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFeed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripFeedScreen(slug: _slug, tripTitle: _title),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    // ยังโหลดอยู่ / ไม่มีโพสต์และผู้ดูโพสต์ไม่ได้ — ไม่ต้องกินพื้นที่หน้า
    if (_loading || (_posts.isEmpty && !_canPost)) {
      return const SizedBox.shrink();
    }

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  icon: Icons.dynamic_feed_rounded,
                  title: 'ฟีดจากนักเดินทาง',
                ),
              ),
              if (_total > 0)
                Text(
                  '$_total โพสต์',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_posts.isEmpty)
            Text(
              'คุณเคยไปทริปนี้มาแล้ว — แชร์รูปสวย ๆ เป็นคนแรกของฟีดเลย!',
              style: appFont(
                fontSize: AppText.sizeLabel,
                height: 1.5,
                color: AppTheme.mutedText(context),
              ),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _posts.length.clamp(0, 10),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final post = _posts[i];
                  final photos = asList(post['photos']).map(asMap).toList();
                  final url = photos.isEmpty
                      ? ''
                      : textOf(photos.first['url']);
                  final likes =
                      int.tryParse(textOf(post['likes_count'])) ?? 0;
                  return GestureDetector(
                    onTap: _openFeed,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (url.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  color: AppTheme.subtleSurface(context),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  color: AppTheme.subtleSurface(context),
                                ),
                              ),
                            if (likes > 0)
                              Positioned(
                                left: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.favorite_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$likes',
                                        style: appFont(
                                          fontSize: AppText.sizeMicro,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openFeed,
                  icon: const Icon(Icons.dynamic_feed_rounded, size: 17),
                  label: const Text('ดูฟีดทั้งหมด'),
                ),
              ),
              if (_canPost) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TripPostComposerScreen(
                            slug: _slug,
                            tripTitle: _title,
                          ),
                        ),
                      ).then((posted) {
                        if (posted == true) _load();
                      });
                    },
                    icon: const Icon(Icons.add_a_photo_rounded, size: 17),
                    label: const Text('โพสต์รูป'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// ปุ่ม "…" มุมขวาของการ์ดรีวิว → รายงานรีวิว หรือบล็อกคนเขียน
///
/// ซ่อนตัวเองบนรีวิวของผู้ใช้เอง — รายงานรีวิวตัวเองไม่มีความหมาย และ
/// เซิร์ฟเวอร์ก็ปฏิเสธอยู่แล้ว
class _ReviewModerationButton extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewModerationButton({required this.review});

  @override
  Widget build(BuildContext context) {
    final reviewId = int.tryParse(textOf(review['id'])) ?? 0;
    final authorId = int.tryParse(textOf(review['user_id']));
    final app = context.watch<AppProvider>();

    if (reviewId <= 0) return const SizedBox.shrink();
    if (authorId != null && authorId == app.userId) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'ตัวเลือกเพิ่มเติม',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () => ModerationSheet.open(
        context,
        type: ModerationSheet.typeReview,
        id: reviewId,
        authorId: authorId,
        authorName: textOf(asMap(review['user'])['name']),
        contentLabel: 'รีวิวนี้',
      ),
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: AppTheme.mutedText(context),
      ),
    );
  }
}
