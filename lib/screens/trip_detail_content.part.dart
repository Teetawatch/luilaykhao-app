part of 'trip_detail_screen.dart';

/// ดอยอินทนนท์ ยอดสูงสุดของไทย — ใช้เป็นไม้บรรทัดให้ตัวเลขความสูงสะสมจับต้องได้
const double _kDoiInthanonM = 2565;

/// ข้อมูลเส้นทางเป็นตัวเลข — ระยะทาง ความสูงสะสม ระยะเวลา ระดับความยาก
///
/// คนที่จริงจังกับการเดินป่าตัดสินใจจากตัวเลขพวกนี้ ไม่ใช่จากคำโฆษณา บล็อกนี้
/// ซ่อนตัวเองถ้าแอดมินยังไม่ได้กรอกระยะทางหรือความสูง เพราะถ้าไม่มีตัวเลขจริง
/// มันก็ไม่ต่างอะไรกับข้อมูลทั่วไปที่มีอยู่แล้วด้านบน (ตรงกับหน้าเว็บ)
class RouteFactsSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const RouteFactsSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final distance = double.tryParse('${trip['distance_km'] ?? ''}') ?? 0;
    final elevation = int.tryParse('${trip['elevation_gain_m'] ?? ''}') ?? 0;
    if (distance <= 0 && elevation <= 0) return const SizedBox.shrink();

    final days = int.tryParse('${trip['duration_days'] ?? ''}') ?? 0;
    final difficultyRaw = textOf(trip['difficulty']).trim();

    final facts = <({IconData icon, String label, String value, String unit, String? note})>[
      if (distance > 0)
        (
          icon: Icons.straighten_rounded,
          label: 'ระยะทางเดิน',
          value: _trimZero(distance),
          unit: 'กม.',
          note: days > 0
              ? 'เฉลี่ย ${_trimZero(distance / days)} กม./วัน'
              : null,
        ),
      if (elevation > 0)
        (
          icon: Icons.landscape_rounded,
          label: 'ความสูงสะสม',
          value: _groupThousands(elevation),
          unit: 'ม.',
          note: null,
        ),
      if (days > 0)
        (
          icon: Icons.schedule_rounded,
          label: 'ระยะเวลา',
          value: '$days',
          unit: 'วัน',
          note: null,
        ),
      if (difficultyRaw.isNotEmpty)
        (
          icon: Icons.terrain_rounded,
          label: 'ระดับความยาก',
          value: _difficultyLabel(difficultyRaw),
          unit: '',
          note: null,
        ),
    ];

    final inthanonPercent = elevation > 0
        ? (elevation / _kDoiInthanonM * 100).round()
        : 0;

    // Shape of the actual walk, when an admin has uploaded the route's GPX.
    final track = RouteTrack.parse(trip['route_track']);

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.hiking_rounded,
            title: 'ข้อมูลเส้นทาง',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 18,
            children: [
              for (final fact in facts)
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 40 - 12) / 2,
                  child: _RouteFactCell(fact: fact),
                ),
            ],
          ),
          if (track != null) ...[
            const SizedBox(height: 22),
            Divider(
              height: 1,
              color: AppTheme.border(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'โปรไฟล์ความชัน',
              style: appFont(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 12),
            ElevationProfileChart(track: track),
            if (track.steepest != null) ...[
              const SizedBox(height: 12),
              Text(
                'ช่วงชันที่สุดอยู่ที่ กม. ${track.steepest!.fromKm.toStringAsFixed(1)}–${track.steepest!.toKm.toStringAsFixed(1)} '
                'ไต่ขึ้น ${track.steepest!.riseM} ม. (ความชัน ${track.steepest!.gradePercent.toStringAsFixed(0)}%)',
                style: appFont(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
            if (track.elevationLossM > 0) ...[
              const SizedBox(height: 6),
              Text(
                'ตลอดเส้นทางไต่ขึ้นรวม ${track.elevationGainM} ม. และลงรวม ${track.elevationLossM} ม.',
                style: appFont(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ],
          if (inthanonPercent > 0) ...[
            const SizedBox(height: 22),
            Divider(
              height: 1,
              color: AppTheme.border(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'ความสูงสะสมเทียบดอยอินทนนท์ (2,565 ม.)',
                    style: appFont(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$inthanonPercent%',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (inthanonPercent / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppTheme.subtleSurface(context),
                valueColor: const AlwaysStoppedAnimation(
                  AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteFactCell extends StatelessWidget {
  final ({IconData icon, String label, String value, String unit, String? note})
  fact;

  const _RouteFactCell({required this.fact});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(fact.icon, size: 15, color: muted),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                fact.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: fact.value,
            style: appFont(
              fontSize: 24,
              height: 1.0,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
            children: [
              if (fact.unit.isNotEmpty)
                TextSpan(
                  text: ' ${fact.unit}',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (fact.note != null) ...[
          const SizedBox(height: 4),
          Text(
            fact.note!,
            style: appFont(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ],
    );
  }
}

String _trimZero(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.truncateToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

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
            title: 'ค่าใช้จ่ายนี้รวมอะไรบ้าง',
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
            title: 'สิ่งที่ต้องจ่ายเพิ่มเอง',
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
                style: appFont(
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
            style: appFont(
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
                  style: appFont(
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
                  ),
                  child: Center(
                    child: Text(
                      marker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
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
                    style: appFont(
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
                      style: appFont(
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
