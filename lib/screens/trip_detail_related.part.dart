part of 'trip_detail_screen.dart';

/// "ทริปที่คล้ายกัน" — a horizontal rail of related trips the backend ranks by
/// type/region/upcoming rounds. Self-loading: renders nothing until it has at
/// least one trip, so it never leaves an empty header on the page.
class RelatedTripsSection extends StatefulWidget {
  final Map<String, dynamic> trip;

  const RelatedTripsSection({super.key, required this.trip});

  @override
  State<RelatedTripsSection> createState() => _RelatedTripsSectionState();
}

class _RelatedTripsSectionState extends State<RelatedTripsSection> {
  List<dynamic> _trips = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slug = textOf(widget.trip['slug']);
    if (slug.isEmpty) {
      setState(() => _loaded = true);
      return;
    }
    try {
      final trips = await context.read<AppProvider>().relatedTrips(slug);
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to show (still loading, failed, or genuinely no matches) → keep
    // the page clean rather than render a bare heading.
    if (!_loaded || _trips.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 24),
            child: _SectionHeader(
              icon: Icons.explore_outlined,
              title: 'ทริปที่คล้ายกัน',
              subtitle: 'ทริปอื่นที่คุณอาจสนใจ',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 246,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 24),
              itemCount: _trips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  _RelatedTripCard(trip: asMap(_trips[i])),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;

  const _RelatedTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final title = textOf(trip['title'], 'ทริป');
    final location = textOf(trip['location']).trim();
    final price = trip['price_per_person'];
    final rating = num.tryParse(textOf(trip['rating'], '0')) ?? 0;
    final reviewCount = int.tryParse(textOf(trip['review_count'], '0')) ?? 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(slug: textOf(trip['slug'])),
          ),
        );
      },
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image + rating chip
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  if (image.isEmpty)
                    Container(
                      width: 200,
                      height: 120,
                      color: AppTheme.subtleSurface(context),
                      child: const Icon(
                        Icons.landscape_rounded,
                        color: _softAccent,
                        size: 36,
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: image,
                      width: 200,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          const Skeleton(width: 200, height: 120, radius: 16),
                      errorWidget: (_, _, _) => Container(
                        width: 200,
                        height: 120,
                        color: AppTheme.subtleSurface(context),
                        child: const Icon(
                          Icons.landscape_rounded,
                          color: _softAccent,
                          size: 36,
                        ),
                      ),
                    ),
                  if (reviewCount > 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating.toStringAsFixed(1),
                              style: appFont(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Title
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : _premiumText,
                height: 1.3,
                letterSpacing: -0.2,
              ),
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 13,
                    color: AppTheme.mutedText(context),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const Spacer(),
            // Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(price),
                  style: appFont(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _softAccent,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '/ คน',
                    style: appFont(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
