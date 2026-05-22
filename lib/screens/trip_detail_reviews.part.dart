part of 'trip_detail_screen.dart';

class ReviewSection extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;

  const ReviewSection({super.key, required this.trip, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final rating = _ratingValue(trip);
    final count = _reviewCount(trip, reviews);
    final hasReviews = count > 0 && rating > 0;

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
                    style: GoogleFonts.anuphan(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _premiumText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'เป็นคนแรกที่มาสัมผัสและแชร์ประสบการณ์',
                    style: GoogleFonts.anuphan(
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
            ...reviews.take(3).map((reviewData) {
              final review = asMap(reviewData);
              return _ReviewCard(review: review);
            }),
          ],
        ],
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
              style: GoogleFonts.anuphan(
                fontSize: 44,
                fontWeight: FontWeight.w900,
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
              style: GoogleFonts.anuphan(
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
                      style: GoogleFonts.anuphan(
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
                        style: GoogleFonts.anuphan(
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
            style: GoogleFonts.anuphan(
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
            style: GoogleFonts.anuphan(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
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

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final user = asMap(review['user']);
    final rating = _ratingValue(review).round().clamp(0, 5);
    final comment = textOf(review['comment']).trim();
    final name = textOf(user['name'], 'ผู้ใช้ทั่วไป');
    final avatarUrl = textOf(user['avatar_url']);
    final date = _formatRelativeDate(review['created_at']);
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final images = asList(review['images'])
        .map((e) => e.toString())
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
                            errorWidget: (_, _, _) => Center(
                              child: Text(
                                initials,
                                style: GoogleFonts.anuphan(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: GoogleFonts.anuphan(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
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
                        style: GoogleFonts.anuphan(
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
                          Container(width: 3, height: 3, decoration: BoxDecoration(color: _mutedText.withValues(alpha: 0.4), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            style: GoogleFonts.anuphan(
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        '$rating.0',
                        style: GoogleFonts.anuphan(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
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
                  style: GoogleFonts.anuphan(
                    fontSize: 13.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : const Color(0xFF374151),
                    height: 1.65,
                  ),
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
                        placeholder: (_, _) => Container(
                          width: 76,
                          height: 76,
                          color: const Color(0xFFF1F5F9),
                        ),
                        errorWidget: (_, _, _) => Container(
                          width: 76,
                          height: 76,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.broken_image_rounded,
                              size: 22, color: Color(0xFF9CA3AF)),
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

/// Gallery of photos pulled from all community reviews of this trip.
class CommunityPhotosSection extends StatelessWidget {
  final List<dynamic> reviews;

  const CommunityPhotosSection({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final photos = <String>[];
    for (final r in reviews) {
      for (final img in asList(asMap(r)['images'])) {
        final url = img.toString();
        if (url.isNotEmpty) photos.add(url);
      }
    }
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
                style: GoogleFonts.anuphan(
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
                          placeholder: (_, _) => Container(
                            width: 104,
                            height: 104,
                            color: const Color(0xFFF1F5F9),
                          ),
                          errorWidget: (_, _, _) => Container(
                            width: 104,
                            height: 104,
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.broken_image_rounded,
                                color: Color(0xFF9CA3AF)),
                          ),
                        ),
                        if (isLast)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.45),
                              alignment: Alignment.center,
                              child: Text(
                                '+$extra',
                                style: GoogleFonts.anuphan(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
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
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.anuphan(
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
            style: GoogleFonts.anuphan(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }
}
