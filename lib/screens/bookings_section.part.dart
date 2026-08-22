part of 'customer_app_screen.dart';

BoxDecoration _ecoCardDecoration(BuildContext context) {
  return AppTheme.cardDecoration(
    context,
    radius: 32,
    borderColor: AppTheme.border(context).withValues(alpha: 0.45),
    shadowOpacity: 0.05,
  );
}

// ─── Bookings Header ──────────────────────────────────────────────────────────

class _BookingsHeader extends StatelessWidget {
  final int totalCount;
  final int upcomingCount;
  final int completedCount;
  final int provinceCount;
  final Map<String, dynamic>? nextTrip;

  const _BookingsHeader({
    required this.totalCount,
    required this.upcomingCount,
    required this.completedCount,
    required this.provinceCount,
    this.nextTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nextTrip != null) ...[
          _NextTripHeroCard(booking: nextTrip!),
          const SizedBox(height: 12),
        ],
        _TravelStatsPanel(
          upcomingCount: upcomingCount,
          completedCount: completedCount,
          provinceCount: provinceCount,
        ),
      ],
    );
  }
}

class _NextTripHeroCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _NextTripHeroCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final title = textOf(trip['title'], 'ทริปถัดไป');
    final travelDate = bookingTravelDate(booking);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = travelDate?.difference(today).inDays;
    final image = ApiConfig.mediaUrl(
      textOf(trip['thumbnail_image'], textOf(trip['cover_image'])),
    );
    final bookingRef = textOf(booking['booking_ref']);

    final (String badge, Color badgeColor) = switch (days) {
      null => ('รอวันเดินทาง', AppTheme.primaryColor),
      < 0 => ('กำลังดำเนินการ', const Color(0xFF16A34A)),
      0 => ('เดินทางวันนี้!', const Color(0xFF16A34A)),
      1 => ('พรุ่งนี้!', const Color(0xFFD97706)),
      <= 3 => ('อีก $days วัน!', const Color(0xFFD97706)),
      _ => ('อีก $days วัน', AppTheme.primaryColor),
    };

    return GestureDetector(
      onTap: () {
        if (bookingRef.isEmpty) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BookingDetailSheet(bookingRef: bookingRef),
        );
      },
      child: Container(
        height: 132,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          color: const Color(0xFF065F46),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.50),
                colorBlendMode: BlendMode.darken,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ทริปถัดไปของคุณ',
                          style: appFont(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: appFont(
                            color: Colors.white,
                            fontSize: AppText.sizeTitle,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (travelDate != null) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                color: Colors.white60,
                                size: 11,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'd MMMM yyyy',
                                  'th_TH',
                                ).format(travelDate),
                                style: appFont(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  fontSize: AppText.sizeCaption,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          badge,
                          style: appFont(
                            color: Colors.white,
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'กดดูรายละเอียด',
                        style: appFont(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: AppText.sizeMicro,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// สรุปการเดินทางสามตัวเลขในแผงเดียว คั่นด้วยเส้นบาง ๆ
/// อ่านเป็นชุดข้อมูลเดียวกัน ไม่ใช่การ์ดสามใบที่แข่งกันเรียกสายตา
class _TravelStatsPanel extends StatelessWidget {
  final int upcomingCount;
  final int completedCount;
  final int provinceCount;

  const _TravelStatsPanel({
    required this.upcomingCount,
    required this.completedCount,
    required this.provinceCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TravelStat(
              icon: Icons.event_available_rounded,
              label: 'กำลังจะถึง',
              value: upcomingCount,
              unit: 'ทริป',
              accent: AppTheme.primaryColor,
            ),
          ),
          _statDivider(context),
          Expanded(
            child: _TravelStat(
              icon: Icons.backpack_rounded,
              label: 'เดินทางแล้ว',
              value: completedCount,
              unit: 'ทริป',
              accent: const Color(0xFF6366F1),
            ),
          ),
          _statDivider(context),
          Expanded(
            child: _TravelStat(
              icon: Icons.terrain_rounded,
              label: 'จังหวัดที่ไป',
              value: provinceCount,
              unit: 'จังหวัด',
              accent: const Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppTheme.border(context).withValues(alpha: 0.5),
    );
  }
}

class _TravelStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String unit;
  final Color accent;

  const _TravelStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accent, size: 13),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  color: AppTheme.mutedText(context),
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$value',
              style: appFont(
                color: AppTheme.onSurface(context),
                fontSize: AppText.sizeH1,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: -0.6,
                // ตัวเลขความกว้างเท่ากัน สามช่องจึงไม่ขยับตามค่าที่เปลี่ยน
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: appFont(
                color: AppTheme.mutedText(context),
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Segment Tabs ─────────────────────────────────────────────────────────────

class ReservationSegmentTabs extends StatelessWidget {
  final _ReservationSegment selected;
  final Map<_ReservationSegment, int> counts;
  final ValueChanged<_ReservationSegment> onChanged;

  const ReservationSegmentTabs({
    super.key,
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (_ReservationSegment.all, 'ทั้งหมด', Icons.grid_view_rounded),
      (
        _ReservationSegment.upcoming,
        'กำลังจะถึง',
        Icons.event_available_rounded,
      ),
      (_ReservationSegment.past, 'เดินทางแล้ว', Icons.history_rounded),
      (_ReservationSegment.cancelled, 'ยกเลิก', Icons.event_busy_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            for (final tab in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  selected: selected == tab.$1,
                  onSelected: (_) => onChanged(tab.$1),
                  showCheckmark: false,
                  avatar: Icon(
                    tab.$3,
                    size: 14,
                    color: selected == tab.$1
                        ? Colors.white
                        : AppTheme.mutedText(context),
                  ),
                  label: Text('${tab.$2} ${counts[tab.$1] ?? 0}'),
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: selected == tab.$1
                        ? Colors.white
                        : AppTheme.mutedText(context),
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Utility Bar ──────────────────────────────────────────────────────────────

class _BookingUtilityBar extends StatelessWidget {
  final TextEditingController controller;
  final String sort;
  final String statusFilter;
  final bool showStatusFilter;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onStatusFilterChanged;

  const _BookingUtilityBar({
    required this.controller,
    required this.sort,
    required this.statusFilter,
    required this.showStatusFilter,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onSortChanged,
    required this.onStatusFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchRow(context),
        // ตัวกรองสถานะเคยซ่อนอยู่หลังไอคอน ไม่มีใครหาเจอและไม่รู้ว่าเปิดค้างไว้
        // อยู่หรือเปล่า — ย้ายมาเป็นชิปที่เห็นสถานะตัวเองชัด ๆ
        if (showStatusFilter) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (final option in const [
                ('all', 'ทุกสถานะ'),
                ('confirmed', 'ยืนยันแล้ว'),
                ('pending', 'รอชำระเงิน'),
              ]) ...[
                if (option.$1 != 'all') const SizedBox(width: 8),
                _StatusFilterChip(
                  label: option.$2,
                  selected: statusFilter == option.$1,
                  onTap: () => onStatusFilterChanged(option.$1),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _searchRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface(context),
            ),
            decoration: InputDecoration(
              hintText: 'ค้นหาการจอง',
              hintStyle: appFont(
                color: AppTheme.mutedText(context),
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppTheme.mutedText(context),
                size: 18,
              ),
              // ปุ่มล้างคำค้น — เดิมต้องลบทีละตัวอักษรเอง
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'ล้างคำค้นหา',
                        icon: Icon(
                          Icons.cancel_rounded,
                          size: 17,
                          color: AppTheme.mutedText(context),
                        ),
                        onPressed: onClearQuery,
                      ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              filled: true,
              fillColor: AppTheme.surface(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(
                  color: AppTheme.border(context).withValues(alpha: 0.55),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(
                  color: AppTheme.border(context).withValues(alpha: 0.55),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'เรียงลำดับ',
          initialValue: sort,
          onSelected: onSortChanged,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'upcoming', child: Text('วันเดินทางใกล้สุด')),
            PopupMenuItem(value: 'latest', child: Text('จองล่าสุด')),
          ],
          child: const _UtilityIconButton(icon: Icons.swap_vert_rounded),
        ),
      ],
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryColor.withValues(alpha: 0.10)
                  : AppTheme.surface(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: selected
                    ? AppTheme.primaryColor.withValues(alpha: 0.45)
                    : AppTheme.border(context).withValues(alpha: 0.55),
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                color: selected
                    ? AppTheme.primaryColor
                    : AppTheme.mutedText(context),
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UtilityIconButton extends StatelessWidget {
  final IconData icon;

  const _UtilityIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Icon(icon, color: AppTheme.onSurface(context), size: 20),
    );
  }
}

// ─── Booking Sections ─────────────────────────────────────────────────────────

class UpcomingSection extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;

  const UpcomingSection({super.key, required this.bookings});

  @override
  Widget build(BuildContext context) {
    return BookingSection(
      eyebrow: 'ทริปถัดไปของคุณ',
      title: 'กำลังจะถึง',
      bookings: bookings,
    );
  }
}

class PastTripsSection extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;

  const PastTripsSection({super.key, required this.bookings});

  @override
  Widget build(BuildContext context) {
    return BookingSection(
      eyebrow: 'ความทรงจำที่ผ่านมา',
      title: 'เดินทางแล้ว',
      bookings: bookings,
    );
  }
}

class BookingSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final List<Map<String, dynamic>> bookings;

  const BookingSection({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.bookings,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      color: AppTheme.mutedText(context),
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.onSurface(context),
                      fontSize: AppText.sizeH2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                '${bookings.length} รายการ',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final booking in bookings) ...[
          ReservationCard(booking: booking),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ─── Reservation Card ─────────────────────────────────────────────────────────

class ReservationCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const ReservationCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final bookingRef = textOf(booking['booking_ref'], '-');
    final isCancelled = _isCancelledBooking(booking);
    final isUpcoming = _isUpcomingBooking(booking);
    final isPast = _isPastBooking(booking);
    final status = textOf(booking['status']);

    // ทริปที่จบหรือยกเลิกไปแล้วเป็น "ประวัติ" ไม่ใช่สิ่งที่ต้องลงมือทำต่อ
    // ย่อเหลือแถวเดียวเพื่อให้เลื่อนหาทริปข้างหน้าเจอเร็ว รายละเอียดอยู่ในชีตครบเหมือนเดิม
    // (ยกเว้นรายการที่ยังรีวิวได้/ยังติดตามเงินคืนอยู่ — ยังมีสิ่งที่ต้องทำ)
    final hasPendingAction =
        _asBool(booking['can_review']) ||
        (isCancelled &&
            (num.tryParse(textOf(booking['paid_amount'])) ?? 0) > 0);
    if ((isPast || isCancelled) && !hasPendingAction) {
      return _CompactHistoryCard(
        booking: booking,
        onTap: () => _openDetail(context, bookingRef),
      );
    }
    final paymentType = textOf(booking['payment_type'], 'full');
    final image = ApiConfig.mediaUrl(
      textOf(
        trip['thumbnail_image'],
        textOf(trip['cover_image'], '/images/landscape.webp'),
      ),
    );

    return _PressableCard(
      onTap: () => _openDetail(context, bookingRef),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero image ──
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg),
              ),
              child: Stack(
                children: [
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      color: isCancelled ? Colors.grey : null,
                      colorBlendMode: isCancelled ? BlendMode.saturation : null,
                      placeholder: (_, _) =>
                          Container(color: AppTheme.border(context)),
                      errorWidget: (_, _, _) => Container(
                        color: AppTheme.border(context),
                        child: const Icon(Icons.landscape_rounded),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.black.withValues(alpha: 0.52),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: _DateBadge(date: bookingTravelDate(booking)),
                  ),
                  Positioned(
                    right: 14,
                    top: 14,
                    child: BookingStatusChip(booking: booking),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                      child: _CountdownPill(booking: booking),
                    ),
                  ),
                  // Past, completed trips: a gentle farewell — a slim centered
                  // glass pill instead of a full dark cover, so the photo still
                  // shows. Reviewing is offered via the CTA in the body.
                  if (isPast && !isCancelled)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            border: Border.all(
                              color: AppTheme.surface(context).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ยินดีที่ได้พบกันครับ',
                                style: appFont(
                                  color: Colors.white,
                                  fontSize: AppText.sizeLabel,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    textOf(trip['title'], 'การจอง'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.onSurface(context),
                      fontSize: AppText.sizeTitle,
                      height: 1.22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Booking ref + payment type badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bookingRef,
                          style: TextStyle(
                            color: AppTheme.mutedText(context),
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (paymentType.isNotEmpty)
                        _PaymentTypeBadge(type: paymentType),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Meta strip
                  _BookingMetaStrip(booking: booking),

                  // Actual vehicle departure (e.g. leaves the night before the
                  // trip day) — shown only when the round defines departs_at.
                  if (!isCancelled && scheduleDepartsAt(schedule) != null) ...[
                    const SizedBox(height: 10),
                    _DepartureTimeNote(schedule: schedule),
                  ],

                  // จุดรับที่ปักหมุดเองยังรออนุมัติ/ถูกปฏิเสธ — ต้องรู้ก่อนถึงวันเดินทาง
                  if (!isCancelled) _CustomPickupStatusNote(booking: booking),

                  // แบ่งจ่ายกลุ่ม / ส่วนต่างวันเดินทาง / อุปกรณ์เช่า / ของขวัญ
                  if (!isCancelled) _BookingExtrasChips(booking: booking),

                  const SizedBox(height: 12),

                  // Who's travelling — overlapping passenger avatars
                  if (!isCancelled) ...[
                    _TravelerAvatars(booking: booking),
                    const SizedBox(height: 12),
                  ],

                  // Payment status
                  _PaymentStatusRow(
                    booking: booking,
                    onPayPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(bookingRef: bookingRef),
                      ),
                    ),
                  ),

                  // Compact check-in (confirmed upcoming only)
                  if (status == 'confirmed' && isUpcoming) ...[
                    const SizedBox(height: 12),
                    _CompactCheckInRow(
                      booking: booking,
                      onTap: () => _openDetail(context, bookingRef),
                    ),
                  ],

                  // Quick actions (calendar, tracking, reschedule, change pickup).
                  // Vehicle/driver, full check-in, readiness, briefing and more
                  // detail now live one tap deeper in the detail sheet.
                  _BookingActionDeck(booking: booking),

                  // Review CTA — finished trips can be reviewed until done once.
                  if (_asBool(booking['can_review'])) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => ReviewSubmissionDialog.show(
                          context,
                          bookingId: int.parse(booking['id'].toString()),
                          tripTitle: textOf(trip['title'], 'การจอง'),
                        ),
                        icon: const Icon(Icons.star_rounded, size: 18),
                        label: const Text('รีวิวทริปนี้'),
                      ),
                    ),
                  ],

                  // Refund CTA
                  _RefundStatusCallToAction(booking: booking),

                  // Explicit affordance into the detail sheet (ticket/QR,
                  // passengers, pickup, itinerary). The whole card is tappable,
                  // but this makes "there's more inside" obvious.
                  const SizedBox(height: 12),
                  _ViewDetailsButton(
                    isPast: isPast,
                    onTap: () => _openDetail(context, bookingRef),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, String bookingRef) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingDetailSheet(bookingRef: bookingRef),
    );
  }
}

/// การ์ดแบบย่อสำหรับทริปที่จบ/ยกเลิกแล้ว — รูปเล็ก ชื่อ วันที่ สถานะ จบ
/// เต็มใบสูงกว่า 400px ต่อรายการ พอมีประวัติหลายสิบทริปเลื่อนหาอะไรไม่เจอเลย
class _CompactHistoryCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  const _CompactHistoryCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final isCancelled = _isCancelledBooking(booking);
    final image = ApiConfig.mediaUrl(
      textOf(
        trip['thumbnail_image'],
        textOf(trip['cover_image'], '/images/landscape.webp'),
      ),
    );

    return _PressableCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.55),
          ),
        ),
        // ความสูงมาจากรูปที่ fix ไว้ 88 — ห้ามใช้ stretch ตรงนี้ เพราะการ์ดอยู่ใน
        // Column ที่ความสูงไม่จำกัด stretch จะส่ง constraint สูงอนันต์ให้ลูก
        // แล้ว layout ทั้ง sliver ล้มทั้งแผง (ในโหมด release = หน้าเปล่า)
        child: Row(
          children: [
            SizedBox(
              width: 84,
              height: 88,
              child: CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                color: isCancelled ? Colors.grey : null,
                colorBlendMode: isCancelled ? BlendMode.saturation : null,
                placeholder: (_, _) => Container(color: AppTheme.border(context)),
                errorWidget: (_, _, _) => Container(
                  color: AppTheme.border(context),
                  child: const Icon(Icons.landscape_rounded, size: 20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      textOf(trip['title'], 'การจอง'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        color: AppTheme.onSurface(context),
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 12,
                          color: AppTheme.mutedText(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _travelDateText(booking),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(
                              color: AppTheme.mutedText(context),
                              fontSize: AppText.sizeCaption,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        BookingStatusChip(booking: booking),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            textOf(booking['booking_ref'], '-'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(
                              color: AppTheme.mutedText(context),
                              fontSize: AppText.sizeMicro,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clear "open the detail sheet" affordance at the foot of a reservation card —
/// the ticket/QR, passenger list, pickup and itinerary live one tap deeper, and
/// users wouldn't always realise the card itself is tappable.
class _ViewDetailsButton extends StatelessWidget {
  final bool isPast;
  final VoidCallback onTap;

  const _ViewDetailsButton({required this.isPast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.10),
          foregroundColor: AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        icon: Icon(
          isPast
              ? Icons.receipt_long_rounded
              : Icons.confirmation_number_rounded,
          size: 18,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPast ? 'ดูรายละเอียดการเดินทาง' : 'ดูตั๋ว & รายละเอียด',
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Booking Meta Strip ───────────────────────────────────────────────────────

class _BookingMetaStrip extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingMetaStrip({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _MetaStripItem(
                icon: Icons.calendar_month_rounded,
                text: _travelDateText(booking),
              ),
            ),
            VerticalDivider(
              width: 20,
              thickness: 1,
              color: AppTheme.border(context),
            ),
            Expanded(
              child: _MetaStripItem(
                icon: Icons.groups_rounded,
                text: _travelerText(booking),
              ),
            ),
            VerticalDivider(
              width: 20,
              thickness: 1,
              color: AppTheme.border(context),
            ),
            Expanded(
              child: _MetaStripItem(
                icon: Icons.location_on_rounded,
                text: _pickupText(booking),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartureTimeNote extends StatelessWidget {
  final Map<String, dynamic> schedule;

  const _DepartureTimeNote({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final departsAt = scheduleDepartsAt(schedule);
    final tripDate = DateTime.tryParse(textOf(schedule['departure_date']));
    final beforeTripDay = departsAt != null &&
        tripDate != null &&
        DateTime(departsAt.year, departsAt.month, departsAt.day)
            .isBefore(DateTime(tripDate.year, tripDate.month, tripDate.day));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFB45309).withValues(alpha: 0.12)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_bus_rounded,
            size: 18,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: appFont(
                  color: isDark
                      ? const Color(0xFFFCD34D)
                      : const Color(0xFF92400E),
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
                children: [
                  const TextSpan(text: 'รถออก '),
                  TextSpan(
                    text: departureText(schedule),
                    style: appFont(
                      color: isDark
                          ? const Color(0xFFFCD34D)
                          : const Color(0xFF92400E),
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (beforeTripDay)
                    const TextSpan(text: ' · ออกก่อนวันทริป โปรดมาก่อนเวลา'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaStripItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaStripItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.primaryColor),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Traveler Avatars ─────────────────────────────────────────────────────────

/// Overlapping avatar circles of the people on this booking, giving the card a
/// sense of "who's going". Hidden for solo bookings to avoid noise.
class _TravelerAvatars extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _TravelerAvatars({required this.booking});

  static const _gradients = [
    [Color(0xFF059669), Color(0xFF6EE7B7)],
    [Color(0xFF0891B2), Color(0xFF67E8F9)],
    [Color(0xFF7C3AED), Color(0xFFC4B5FD)],
    [Color(0xFFD97706), Color(0xFFFDE68A)],
    [Color(0xFFDB2777), Color(0xFFF9A8D4)],
  ];

  @override
  Widget build(BuildContext context) {
    // ทุกคนที่เดินทางในรอบนี้ (จากทุกการจอง) — แสดงตัวเราเองไว้ก่อน
    final schedule = asMap(booking['schedule']);
    final travelers = asList(schedule['travelers']).map(asMap).toList()
      ..sort((a, b) {
        final aSelf = a['is_self'] == true ? 0 : 1;
        final bSelf = b['is_self'] == true ? 0 : 1;
        return aSelf.compareTo(bSelf);
      });
    // เผื่อ API เวอร์ชันเก่าที่ยังไม่มี travelers ให้ย้อนไปใช้ผู้โดยสารในการจองนี้
    final people = travelers.isNotEmpty
        ? travelers
        : asList(booking['passengers']).map(asMap).toList();
    if (people.length < 2) return const SizedBox.shrink();

    const maxShown = 5;
    final shown = people.take(maxShown).toList();
    final extra = people.length - shown.length;
    const size = 30.0;
    const overlap = 10.0;

    final circles = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      final name = textOf(
        shown[i]['name'],
        textOf(shown[i]['nickname'], '?'),
      ).trim();
      final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
      final isSelf = shown[i]['is_self'] == true;
      final pair = isSelf
          ? const [AppTheme.primaryColor, AppTheme.primaryColor]
          : _gradients[initial.codeUnitAt(0) % _gradients.length];
      circles.add(
        Positioned(
          left: i * (size - overlap),
          child: _AvatarCircle(initial: initial, colors: pair, size: size),
        ),
      );
    }
    if (extra > 0) {
      circles.add(
        Positioned(
          left: shown.length * (size - overlap),
          child: _AvatarCircle(
            initial: '+$extra',
            colors: [AppTheme.mutedText(context), AppTheme.border(context)],
            size: size,
          ),
        ),
      );
    }

    final stackWidth =
        (shown.length + (extra > 0 ? 1 : 0)) * (size - overlap) + overlap;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(
            width: stackWidth,
            height: size,
            child: Stack(clipBehavior: Clip.none, children: circles),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'ร่วมเดินทางในรอบนี้ ${people.length} คน',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.mutedText(context),
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String initial;
  final List<Color> colors;
  final double size;

  const _AvatarCircle({
    required this.initial,
    required this.colors,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.surface(context), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: appFont(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: initial.length > 1 ? 11 : 13,
        ),
      ),
    );
  }
}

// ─── Vehicle & Driver Strip (card) ────────────────────────────────────────────

// ─── Payment Status Row ───────────────────────────────────────────────────────

class _PaymentStatusRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onPayPressed;

  const _PaymentStatusRow({required this.booking, required this.onPayPressed});

  @override
  Widget build(BuildContext context) {
    final status = textOf(booking['status']);
    final paymentType = textOf(booking['payment_type'], 'full');
    final total = num.tryParse(booking['total_amount']?.toString() ?? '') ?? 0;
    final paid = num.tryParse(booking['paid_amount']?.toString() ?? '') ?? 0;

    if (status == 'pending') {
      // ส่งสลิปแล้วแต่ยอดไม่ตรง → backend ค้างสถานะ pending ไว้รอแอดมินตรวจ
      // ต้องไม่ชวนให้จ่ายซ้ำ และไม่ต้องนับถอยหลัง (ที่นั่งถูกถือไว้ให้แล้ว)
      if (textOf(booking['slip_ocr_status']).isNotEmpty) {
        return const _SlipUnderReviewBar();
      }
      return _PendingPaymentBar(
        total: total,
        expiresAt: DateTime.tryParse(textOf(booking['expires_at'])),
        onPay: onPayPressed,
      );
    }

    if (status == 'cancelled' || status == 'refunded') {
      if (paid <= 0) return const SizedBox.shrink();
      return _SimpleStatusBar(
        icon: Icons.cancel_outlined,
        color: AppTheme.mutedText(context),
        label: 'ยกเลิก · ชำระไปแล้ว ${money(paid)}',
      );
    }

    if (status == 'completed') {
      return _SimpleStatusBar(
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF3B82F6),
        label: 'เดินทางสำเร็จ · ${money(total)}',
      );
    }

    if (paymentType == 'deposit') {
      final balance =
          num.tryParse(booking['balance_amount']?.toString() ?? '') ?? 0;
      final balancePaidAt = textOf(booking['balance_paid_at']);
      final dueDate = textOf(booking['balance_due_at']);
      if (balancePaidAt.isEmpty && balance > 0) {
        return _DepositBar(deposit: paid, balance: balance, dueDate: dueDate);
      }
      return _PaidFullBar(total: total);
    }

    if (paymentType == 'installment') {
      final installments = asList(booking['installment_payments']);
      if (installments.isNotEmpty) {
        return _InstallmentBar(
          installments: installments,
          paid: paid,
          total: total,
        );
      }
    }

    return _PaidFullBar(total: total);
  }
}

/// ส่งสลิปแล้ว ยอดไม่ตรงจึงค้างรอแอดมินอนุมัติ — ห้ามชวนให้จ่ายอีกรอบ
class _SlipUnderReviewBar extends StatelessWidget {
  const _SlipUnderReviewBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: Color(0xFF1D4ED8),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ได้รับสลิปแล้ว · รอทีมงานตรวจสอบ',
                  style: appFont(
                    color: const Color(0xFF1E3A8A),
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ที่นั่งถูกจองไว้ให้แล้ว ไม่ต้องโอนซ้ำ',
                  style: appFont(
                    color: const Color(0xFF1D4ED8),
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPaymentBar extends StatefulWidget {
  final num total;
  final DateTime? expiresAt;
  final VoidCallback onPay;

  const _PendingPaymentBar({
    required this.total,
    required this.expiresAt,
    required this.onPay,
  });

  @override
  State<_PendingPaymentBar> createState() => _PendingPaymentBarState();
}

class _PendingPaymentBarState extends State<_PendingPaymentBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _PendingPaymentBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// เดินวินาทีเฉพาะตอนยังเหลือเวลาจริง แล้วหยุดเองเมื่อหมด
  void _syncTicker() {
    if (_remaining() > Duration.zero) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        _syncTicker();
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Duration _remaining() {
    final deadline = widget.expiresAt;
    if (deadline == null) return Duration.zero;
    final diff = deadline.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining();
    final expired = widget.expiresAt != null && remaining == Duration.zero;
    final mm = remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFFFBD38D)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD97706),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'รอชำระเงิน',
                  style: appFont(
                    color: const Color(0xFF92400E),
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  money(widget.total),
                  style: appFont(
                    color: const Color(0xFFD97706),
                    fontSize: AppText.sizeTitle,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
                // เส้นตายที่ระบบจะคืนที่นั่งอัตโนมัติ — เดิมเงียบสนิท ลูกค้า
                // กลับมาอีกทีเจอ "ยกเลิก" โดยไม่รู้ว่าเพราะอะไร
                if (widget.expiresAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    expired
                        ? 'หมดเวลาชำระเงินแล้ว · ที่นั่งกำลังถูกคืน'
                        : 'เหลือเวลาชำระอีก $mm:$ss นาที ก่อนที่นั่งถูกคืน',
                    style: appFont(
                      color: const Color(0xFF92400E),
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          FilledButton(
            onPressed: widget.onPay,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'ชำระเงิน',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaidFullBar extends StatelessWidget {
  final num total;

  const _PaidFullBar({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.primaryColor,
            size: 17,
          ),
          const SizedBox(width: 8),
          Text(
            'ชำระครบแล้ว · ',
            style: appFont(
              color: AppTheme.primaryColor,
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            money(total),
            style: appFont(
              color: AppTheme.primaryColor,
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DepositBar extends StatelessWidget {
  final num deposit;
  final num balance;
  final String dueDate;

  const _DepositBar({
    required this.deposit,
    required this.balance,
    required this.dueDate,
  });

  @override
  Widget build(BuildContext context) {
    final dueDateText = dueDate.isNotEmpty ? dateText(dueDate) : 'ไม่ระบุ';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFFFBD38D)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'มัดจำแล้ว',
                  style: appFont(
                    color: const Color(0xFF065F46),
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  money(deposit),
                  style: appFont(
                    color: AppTheme.primaryColor,
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFFBD38D)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'ค้างชำระ',
                      style: appFont(
                        color: const Color(0xFF92400E),
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  money(balance),
                  style: appFont(
                    color: const Color(0xFFD97706),
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'ภายใน $dueDateText',
                  style: appFont(
                    color: const Color(0xFF92400E),
                    fontSize: AppText.sizeMicro,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallmentBar extends StatelessWidget {
  final List<dynamic> installments;
  final num paid;
  final num total;

  const _InstallmentBar({
    required this.installments,
    required this.paid,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final paidCount = installments
        .map(asMap)
        .where((i) => textOf(i['status']) == 'paid')
        .length;
    final totalCount = installments.length;
    final progress = totalCount > 0
        ? (paidCount / totalCount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: AppTheme.primaryColor,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                'ผ่อนชำระ',
                style: appFont(
                  color: AppTheme.mutedText(context),
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$paidCount/$totalCount งวด',
                style: appFont(
                  color: paidCount == totalCount
                      ? AppTheme.primaryColor
                      : AppTheme.onSurface(context),
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.border(context),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'ชำระแล้ว ${money(paid)}',
                style: appFont(
                  color: AppTheme.primaryColor,
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'รวม ${money(total)}',
                style: appFont(
                  color: AppTheme.mutedText(context),
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleStatusBar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _SimpleStatusBar({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: appFont(
              color: color,
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payment Type Badge ───────────────────────────────────────────────────────

class _PaymentTypeBadge extends StatelessWidget {
  final String type;

  const _PaymentTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (type) {
      'deposit' => ('มัดจำ', const Color(0xFFD97706)),
      'installment' => ('ผ่อนชำระ', const Color(0xFF7C3AED)),
      _ => ('ชำระเต็ม', AppTheme.primaryColor),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: appFont(
          color: color,
          fontSize: AppText.sizeMicro,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─── Compact Check-In Row ─────────────────────────────────────────────────────

class _CompactCheckInRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  const _CompactCheckInRow({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bookingRef = textOf(booking['booking_ref'], '-');
    final checkInCode = textOf(booking['qr_code']).trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.verified_rounded,
              color: AppTheme.primaryColor,
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'พร้อมเช็คอิน',
                    style: appFont(
                      color: AppTheme.primaryColor,
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  Text(
                    bookingRef,
                    style: appFont(
                      color: AppTheme.primaryColor.withValues(alpha: 0.72),
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (checkInCode.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'แสดง QR',
                      style: appFont(
                        color: Colors.white,
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
