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
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.rate_review_outlined,
                      size: 30,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ยังไม่มีรีวิว',
                    style: appFont(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _premiumText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'เป็นคนแรกที่มาสัมผัสและแชร์ประสบการณ์',
                    style: appFont(
                      fontSize: 13,
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
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _premiumText,
                      ),
                    ),
                  ]
                : [
                    Text(
                      label,
                      style: appFont(
                        fontSize: 13.5,
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
                    fontSize: 12,
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
                            fontSize: 11,
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
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFF3F4F6),
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
                              fontSize: 11,
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF2F7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: appFont(
              fontSize: 12.5,
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
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _premiumText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  /// When set, a small trip chip is shown under the comment. Used by the
  /// all-reviews screen (where reviews span many trips); left null inside a
  /// single trip's detail page, where the trip is already obvious.
  final String? tripTitle;

  const _ReviewCard({required this.review, this.tripTitle});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final user = asMap(review['user']);
    final rating = _ratingValue(review).round().clamp(0, 5);
    final comment = textOf(review['comment']).trim();
    final name = textOf(user['name'], 'ผู้ใช้ทั่วไป');
    final avatarUrl = ApiConfig.mediaUrl(textOf(user['avatar_url']));
    final date = _formatRelativeDate(review['created_at']);
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final images = asList(review['images'])
        .map((e) => ApiConfig.mediaUrl(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();
    final videos = asList(review['videos'])
        .map((e) => ApiConfig.mediaUrl(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();
    final breakdown = _reviewBreakdown(review);

    // avatar background color cycle
    final colors = [
      [const Color(0xFF059669), const Color(0xFF6EE7B7)],
      [const Color(0xFF0891B2), const Color(0xFF67E8F9)],
      [const Color(0xFF7C3AED), const Color(0xFFC4B5FD)],
      [const Color(0xFFD97706), const Color(0xFFFDE68A)],
    ];
    final colorPair = colors[(initials.codeUnitAt(0)) % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFEEF2F7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: avatarUrl.isEmpty
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colorPair,
                          )
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl,
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            memCacheWidth: _thumbCacheWidth(context, 42),
                            maxWidthDiskCache: _thumbCacheWidth(context, 42),
                            errorWidget: (_, _, _) => Center(
                              child: Text(
                                initials,
                                style: appFont(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: appFont(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : _premiumText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 14,
                              color: i < rating
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFD1D5DB),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: _mutedText.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            style: appFont(
                              fontSize: 11.5,
                              color: _mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // rating badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$rating.0',
                        style: appFont(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  comment,
                  style: appFont(
                    fontSize: 13.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : const Color(0xFF374151),
                    height: 1.65,
                  ),
                ),
              ),
            ],
            if (tripTitle != null &&
                tripTitle!.trim().isNotEmpty &&
                tripTitle!.trim() != '-') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _softAccent.withValues(alpha: isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.terrain_rounded,
                      size: 14,
                      color: _softAccent,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tripTitle!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF6EE7B7) : _premiumText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: breakdown
                    .map((b) => _ReviewBreakdownChip(label: b.$1, value: b.$2))
                    .toList(),
              ),
            ],
            if (videos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: videos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => _FullscreenVideoPlayer(url: videos[i]),
                      ),
                    ),
                    child: _VideoThumbCard(
                      url: videos[i],
                      index: i,
                      width: 110,
                      height: 76,
                      showLabel: false,
                      // Reviews stack unbounded video tiles in a non-recycling
                      // Column as more pages load; a live decoder per tile would
                      // exhaust the platform pool and crash. Show the static
                      // poster placeholder — tapping still opens a real player.
                      livePreview: false,
                    ),
                  ),
                ),
              ),
            ],
            if (images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) =>
                            _FullscreenGallery(images: images, initialIndex: i),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: images[i],
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        memCacheWidth: _thumbCacheWidth(context, 76),
                        maxWidthDiskCache: _thumbCacheWidth(context, 76),
                        placeholder: (_, _) => Container(
                          width: 76,
                          height: 76,
                          color: const Color(0xFFF1F5F9),
                        ),
                        errorWidget: (_, _, _) => Container(
                          width: 76,
                          height: 76,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(
                            Icons.broken_image_rounded,
                            size: 22,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
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
                  fontSize: 12.5,
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
                    borderRadius: BorderRadius.circular(16),
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
                            color: const Color(0xFFF1F5F9),
                          ),
                          errorWidget: (_, _, _) => Container(
                            width: 104,
                            height: 104,
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: Color(0xFF9CA3AF),
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
                                  fontSize: 20,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: appFont(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF92400E),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 11, color: Color(0xFFF59E0B)),
          const SizedBox(width: 2),
          Text(
            numberText(value),
            style: appFont(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF92400E),
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
                    fontSize: 12,
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
                fontSize: 12.5,
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
                      borderRadius: BorderRadius.circular(14),
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
                                    borderRadius: BorderRadius.circular(10),
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
                                          fontSize: 10.5,
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
