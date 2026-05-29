part of 'trip_detail_screen.dart';

class HighlightsSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const HighlightsSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final highlights = _highlightItems(trip['highlights']);
    if (highlights.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(icon: Icons.auto_awesome, title: 'ไฮไลท์'),
          const SizedBox(height: 16),
          ...highlights.map(
            (item) => _FeatureRow(
              icon: _iconFor(item.icon) ?? Icons.check_rounded,
              title: item.title,
              description: item.description,
            ),
          ),
        ],
      ),
    );
  }
}

class IncludedSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const IncludedSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final inclusions = asList(trip['inclusions'])
        .map((item) => textOf(item).trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (inclusions.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.verified_outlined,
            title: 'สิ่งที่รวมในแพ็กเกจ',
          ),
          const SizedBox(height: 16),
          ...inclusions.map(
            (item) => _FeatureRow(icon: Icons.check_rounded, title: item),
          ),
        ],
      ),
    );
  }
}

class ExcludedSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const ExcludedSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final exclusions = asList(trip['exclusions'])
        .map((item) => textOf(item).trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (exclusions.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.remove_circle_outline_rounded,
            title: 'สิ่งที่ไม่รวมในแพ็กเกจ',
          ),
          const SizedBox(height: 16),
          ...exclusions.map(
            (item) => _FeatureRow(
              icon: Icons.close_rounded,
              title: item,
              iconColor: const Color(0xFFEF4444),
              iconBackground: const Color(0xFFFEF2F2),
            ),
          ),
        ],
      ),
    );
  }
}

class ItinerarySection extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String? pickupRegionKey;
  final String? pickupRegionLabel;

  const ItinerarySection({
    super.key,
    required this.trip,
    this.pickupRegionKey,
    this.pickupRegionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final sectors = _itinerarySectors(
      trip,
      regionKey: pickupRegionKey,
      regionLabel: pickupRegionLabel,
    );
    if (sectors.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.route_rounded,
            title: 'แผนการเดินทาง',
            subtitle: '${sectors.fold(0, (sum, s) => sum + s.items.length)} กิจกรรม',
          ),
          const SizedBox(height: 20),
          ...sectors.asMap().entries.map(
            (entry) => _ItinerarySectorTile(
              sector: entry.value,
              index: entry.key,
              total: sectors.length,
              initiallyExpanded: sectors.length == 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItinerarySectorTile extends StatelessWidget {
  final _ItinerarySector sector;
  final int index;
  final int total;
  final bool initiallyExpanded;

  const _ItinerarySectorTile({
    required this.sector,
    required this.index,
    required this.total,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    // gradient color cycle per sector
    final gradients = [
      [const Color(0xFF059669), const Color(0xFF10B981)],
      [const Color(0xFF0891B2), const Color(0xFF06B6D4)],
      [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)],
      [const Color(0xFFD97706), const Color(0xFFF59E0B)],
    ];
    final grad = gradients[index % gradients.length];

    return Container(
      margin: EdgeInsets.only(top: index == 0 ? 0 : 10),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: _softAccent,
          collapsedIconColor: _mutedText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: grad[0].withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.anuphan(
                  color: grad[0],
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          title: Text(
            sector.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(
              color: isDark ? Colors.white : _premiumText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: grad[0].withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${sector.items.length} รายการ',
                  style: GoogleFonts.anuphan(
                    color: grad[0],
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          children: [
            ...sector.items.asMap().entries.map(
              (entry) => _ItineraryTimelineItem(
                item: entry.value,
                isLast: entry.key == sector.items.length - 1,
                accentColor: grad[0],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItineraryTimelineItem extends StatelessWidget {
  final _ItineraryItem item;
  final bool isLast;
  final Color accentColor;

  const _ItineraryTimelineItem({
    required this.item,
    required this.isLast,
    this.accentColor = _softAccent,
  });

  @override
  Widget build(BuildContext context) {
    final marker = item.day.isNotEmpty ? item.day : '${item.index}';
    final isDark = AppTheme.isDark(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // timeline column
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor,
                        accentColor.withValues(alpha: 0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      marker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accentColor.withValues(alpha: 0.4),
                            accentColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.anuphan(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : _premiumText,
                      height: 1.35,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: GoogleFonts.anuphan(
                        fontSize: 13.5,
                        color: _mutedText,
                        height: 1.65,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
