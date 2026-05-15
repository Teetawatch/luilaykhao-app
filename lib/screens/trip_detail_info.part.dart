part of 'trip_detail_screen.dart';

class DestinationInfoSection extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;
  final bool isLoading;

  const DestinationInfoSection({
    super.key,
    required this.trip,
    required this.reviews,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    if (isLoading) {
      return const _PremiumCard(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Skeleton(width: 110, height: 28, radius: 14),
              Spacer(),
              Skeleton(width: 80, height: 28, radius: 14),
            ]),
            SizedBox(height: 18),
            Skeleton(width: double.infinity, height: 36, radius: 12),
            SizedBox(height: 8),
            Skeleton(width: 220, height: 36, radius: 12),
            SizedBox(height: 14),
            Skeleton(width: 180, height: 18, radius: 9),
            SizedBox(height: 24),
            Skeleton(width: double.infinity, height: 88, radius: 20),
          ],
        ),
      );
    }

    final chips = _quickInfoItems(trip);
    final location = textOf(trip['location'] ?? trip['destination']).trim();
    final catLabel = textOf(
      trip['category_name'] ??
          asMap(trip['category'])['name'] ??
          trip['type'],
    ).trim();

    return _PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── top badge row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                _RatingSummary(trip: trip, reviews: reviews),
                const Spacer(),
                if (catLabel.isNotEmpty)
                  _InfoChip(icon: Icons.tag_rounded, label: catLabel),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── title ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _tripTitle(trip),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.anuphan(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : _premiumText,
                height: 1.2,
                letterSpacing: -0.4,
              ),
            ),
          ),
          // ── location ───────────────────────────────────────────────
          if (location.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _softAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: _softAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        fontSize: 13,
                        color: _mutedText,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ── stats grid ─────────────────────────────────────────────
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFE9F5F1),
                ),
              ),
              child: QuickInfoChips(trip: trip),
            ),
          ] else
            const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class QuickInfoChips extends StatelessWidget {
  final Map<String, dynamic> trip;

  const QuickInfoChips({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final chips = _quickInfoItems(trip);
    if (chips.isEmpty) return const SizedBox.shrink();

    // 2-column grid layout
    final rows = <List<_QuickInfoItem>>[];
    for (var i = 0; i < chips.length; i += 2) {
      rows.add([
        chips[i],
        if (i + 1 < chips.length) chips[i + 1],
      ]);
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          return Column(
            children: [
              Row(
                children: row.asMap().entries.map((e) {
                  final isLastInRow = e.key == row.length - 1;
                  final chip = e.value;
                  return Expanded(
                    child: _StatTile(
                      icon: chip.icon,
                      label: chip.label,
                      showRightBorder: !isLastInRow && row.length > 1,
                      showBottomBorder: !isLast,
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showRightBorder;
  final bool showBottomBorder;

  const _StatTile({
    required this.icon,
    required this.label,
    this.showRightBorder = false,
    this.showBottomBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE9F5F1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          right: showRightBorder
              ? BorderSide(color: dividerColor)
              : BorderSide.none,
          bottom: showBottomBorder
              ? BorderSide(color: dividerColor)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _softAccent.withValues(alpha: 0.18),
                  _softAccent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: _softAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.anuphan(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white.withValues(alpha: 0.85) : _premiumText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutSection extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isLoading;
  final bool isExpanded;
  final VoidCallback onToggle;

  const AboutSection({
    super.key,
    required this.trip,
    required this.isLoading,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 150, height: 24),
            SizedBox(height: 16),
            Skeleton(width: double.infinity, height: 16),
            SizedBox(height: 8),
            Skeleton(width: double.infinity, height: 16),
            SizedBox(height: 8),
            Skeleton(width: 260, height: 16),
          ],
        ),
      );
    }

    final description = textOf(trip['description']).trim();
    if (description.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.article_outlined,
            title: 'เกี่ยวกับทริปนี้',
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Text(
              description,
              maxLines: isExpanded ? null : 5,
              overflow: isExpanded ? TextOverflow.visible : TextOverflow.fade,
              style: GoogleFonts.anuphan(
                fontSize: 15,
                height: 1.75,
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (description.length > 160) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                foregroundColor: _softAccent,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                isExpanded ? 'อ่านน้อยลง' : 'อ่านเพิ่มเติม',
                style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MustKnowSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const MustKnowSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final items = _mustKnowItems(trip);
    final remarks = textOf(asMap(trip['must_know'])['remarks']).trim();
    if (items.isEmpty && remarks.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return _PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // amber accent header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFFB45309).withValues(alpha: 0.12)
                  : const Color(0xFFFFFBEB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFFB45309).withValues(alpha: 0.18)
                      : const Color(0xFFFDE68A),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFB45309).withValues(alpha: 0.2)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สิ่งที่ควรรู้ก่อนเดินทาง',
                        style: GoogleFonts.anuphan(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF92400E),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'อ่านก่อนทำการจอง',
                        style: GoogleFonts.anuphan(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFFD97706)
                              : const Color(0xFFB45309),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                ...items.map(
                  (item) => _FeatureRow(
                    icon: Icons.error_outline_rounded,
                    title: item.price > 0
                        ? '${item.name} · ${money(item.price)} ${item.priceTypeLabel}'
                        : item.name,
                    iconColor: const Color(0xFFD97706),
                    iconBackground: const Color(0xFFFEF3C7),
                  ),
                ),
                if (remarks.isNotEmpty)
                  _FeatureRow(
                    icon: Icons.notes_rounded,
                    title: remarks,
                    iconColor: const Color(0xFFD97706),
                    iconBackground: const Color(0xFFFEF3C7),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PreparationsSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const PreparationsSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final items = _textItems(trip['preparations']);
    if (items.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.backpack_rounded,
            title: 'สิ่งที่ควรเตรียม',
            subtitle: 'เตรียมตัวก่อนออกเดินทาง',
          ),
          const SizedBox(height: 20),
          // checklist with sequential numbers
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final text = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.anuphan(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        text,
                        style: GoogleFonts.anuphan(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.85)
                              : _premiumText,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
