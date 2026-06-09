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
        Row(
          children: [
            Expanded(
              child: _SummaryPill(
                icon: Icons.event_available_rounded,
                label: 'กำลังจะถึง',
                value: '$upcomingCount',
                accent: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryPill(
                icon: Icons.backpack_rounded,
                label: 'เดินทางแล้ว',
                value: '$completedCount',
                accent: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryPill(
                icon: Icons.terrain_rounded,
                label: 'จังหวัดที่ไป',
                value: '$provinceCount',
                accent: const Color(0xFF6366F1),
              ),
            ),
          ],
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
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0B3D42),
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
                          style: GoogleFonts.anuphan(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.anuphan(
                            color: Colors.white,
                            fontSize: 17,
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
                                style: GoogleFonts.anuphan(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  fontSize: 11.5,
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
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: badgeColor.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.anuphan(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'กดดูรายละเอียด',
                        style: GoogleFonts.anuphan(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 10,
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

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.12 : 0.03,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppTheme.isDark(context) ? 0.12 : 0.03,
              ),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
  final String query;
  final String sort;
  final String statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onStatusFilterChanged;

  const _BookingUtilityBar({
    required this.query,
    required this.sort,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onStatusFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onQueryChanged,
            style: GoogleFonts.anuphan(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface(context),
            ),
            decoration: InputDecoration(
              hintText: 'ค้นหาการจอง',
              hintStyle: GoogleFonts.anuphan(
                color: AppTheme.mutedText(context),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppTheme.mutedText(context),
                size: 18,
              ),
              filled: true,
              fillColor: AppTheme.surface(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppTheme.border(context).withValues(alpha: 0.55),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppTheme.border(context).withValues(alpha: 0.55),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
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
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'กรองการจอง',
          initialValue: statusFilter,
          onSelected: onStatusFilterChanged,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'all', child: Text('ทุกสถานะ')),
            PopupMenuItem(value: 'confirmed', child: Text('ยืนยันแล้ว')),
            PopupMenuItem(value: 'pending', child: Text('รอชำระเงิน')),
            PopupMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
            PopupMenuItem(value: 'completed', child: Text('เสร็จสิ้น')),
          ],
          child: _UtilityIconButton(
            icon: statusFilter == 'all'
                ? Icons.tune_rounded
                : Icons.filter_alt_rounded,
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(14),
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
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.onSurface(context),
                      fontSize: 20,
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
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${bookings.length} รายการ',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 11.5,
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
    final paymentType = textOf(booking['payment_type'], 'full');
    final image = ApiConfig.mediaUrl(
      textOf(
        trip['thumbnail_image'],
        textOf(trip['cover_image'], '/images/landscape.webp'),
      ),
    );

    return InkWell(
      onTap: () => _openDetail(context, bookingRef),
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppTheme.isDark(context) ? 0.16 : 0.05,
              ),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero image ──
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
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
                          Container(color: const Color(0xFFEDEFEF)),
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFFEDEFEF),
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
                  // Past, completed trips: a gentle farewell banner over the
                  // header image. Reviewing is offered via the CTA in the body.
                  if (isPast && !isCancelled)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.42),
                        alignment: Alignment.center,
                        child: Text(
                          'ยินดีที่ได้พบกันครับ',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.anuphan(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
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
                      fontSize: 18,
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
                            fontSize: 12,
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

                  // Who's travelling — overlapping passenger avatars
                  if (!isCancelled) _TravelerAvatars(booking: booking),
                  const SizedBox(height: 12),

                  // Vehicle & driver strip (when assigned and still active)
                  if (!isCancelled &&
                      _hasVehicleInfo(asMap(schedule['vehicle']))) ...[
                    _VehicleDriverStrip(vehicle: asMap(schedule['vehicle'])),
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

                  // Trip readiness checklist (upcoming bookings only)
                  if (_isUpcomingBooking(booking)) ...[
                    const SizedBox(height: 12),
                    _TripReadinessBar(
                      booking: booking,
                      onTap: () => _openDetail(context, bookingRef),
                    ),
                  ],

                  // Action deck (chat, SOS, pre-trip briefing, reschedule)
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
            borderRadius: BorderRadius.circular(14),
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
              style: GoogleFonts.anuphan(
                fontSize: 14,
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

// ─── Trip Readiness Bar ───────────────────────────────────────────────────────

/// A small "get ready" checklist surfaced on upcoming bookings: payment,
/// traveller details, and pickup selection. Tapping opens the detail sheet so
/// the customer can finish whatever's outstanding.
class _TripReadinessBar extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  const _TripReadinessBar({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = _readinessItems(booking);
    if (items.isEmpty) return const SizedBox.shrink();

    final doneCount = items.where((i) => i.$2).length;
    final allDone = doneCount == items.length;
    final accent = allDone ? AppTheme.primaryColor : const Color(0xFFD97706);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allDone
                      ? Icons.verified_rounded
                      : Icons.checklist_rounded,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  allDone ? 'พร้อมเดินทางแล้ว' : 'เตรียมความพร้อม',
                  style: GoogleFonts.anuphan(
                    color: accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
                const Spacer(),
                Text(
                  '$doneCount/${items.length}',
                  style: GoogleFonts.anuphan(
                    color: accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!allDone) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: accent),
                ],
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: items
                  .map((i) => _ReadinessChip(label: i.$1, done: i.$2))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessChip extends StatelessWidget {
  final String label;
  final bool done;

  const _ReadinessChip({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done ? const Color(0xFF16A34A) : AppTheme.mutedText(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.anuphan(
              color: done ? AppTheme.onSurface(context) : color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds the (label, done) readiness checklist for a booking. Pickup is only
/// included when the schedule actually offers pickup points to choose from.
List<(String, bool)> _readinessItems(Map<String, dynamic> booking) {
  final status = textOf(booking['status']);
  final passengers = asList(booking['passengers']).map(asMap).toList();
  final schedule = asMap(booking['schedule']);
  final hasPickupOptions = asList(schedule['pickup_points']).isNotEmpty;

  final paymentDone = status != 'pending';

  final detailsDone =
      passengers.isNotEmpty &&
      passengers.every(
        (p) =>
            textOf(p['name']).trim().isNotEmpty &&
            textOf(p['id_card']).trim().isNotEmpty,
      );

  final items = <(String, bool)>[
    ('ชำระเงิน', paymentDone),
    ('ข้อมูลผู้เดินทาง', detailsDone),
  ];

  if (hasPickupOptions) {
    final bookingPickup = asMap(booking['pickup_point']).isNotEmpty;
    final everyPassengerPickup =
        passengers.isNotEmpty &&
        passengers.every(
          (p) => textOf(p['pickup_point_id']).trim().isNotEmpty,
        );
    items.add(('เลือกจุดรับ', bookingPickup || everyPassengerPickup));
  }

  return items;
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
        borderRadius: BorderRadius.circular(16),
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
              fontSize: 11.5,
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
            colors: const [Color(0xFF94A3B8), Color(0xFFCBD5E1)],
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
                fontSize: 12,
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
        style: GoogleFonts.anuphan(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: initial.length > 1 ? 11 : 13,
        ),
      ),
    );
  }
}

// ─── Vehicle & Driver Strip (card) ────────────────────────────────────────────

class _VehicleDriverStrip extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const _VehicleDriverStrip({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final plate = textOf(vehicle['license_plate']).trim();
    final color = textOf(vehicle['color']).trim();
    final driverName = textOf(vehicle['driver_name']).trim();
    final driverPhone = textOf(vehicle['driver_phone']).trim();

    final parts = <String>[
      if (plate.isNotEmpty) plate,
      if (color.isNotEmpty) color,
      if (driverName.isNotEmpty) 'คนขับ $driverName',
    ];
    final summary = parts.join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.airport_shuttle_rounded,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary.isEmpty ? 'รถรับส่งประจำรอบ' : summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.onSurface(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (driverPhone.isNotEmpty) ...[
            const SizedBox(width: 6),
            _CallButton(phone: driverPhone),
          ],
        ],
      ),
    );
  }
}

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
      return _PendingPaymentBar(total: total, onPay: onPayPressed);
    }

    if (status == 'cancelled' || status == 'refunded') {
      if (paid <= 0) return const SizedBox.shrink();
      return _SimpleStatusBar(
        icon: Icons.cancel_outlined,
        color: const Color(0xFF6B7280),
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

class _PendingPaymentBar extends StatelessWidget {
  final num total;
  final VoidCallback onPay;

  const _PendingPaymentBar({required this.total, required this.onPay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
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
                  style: GoogleFonts.anuphan(
                    color: const Color(0xFF92400E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  money(total),
                  style: GoogleFonts.anuphan(
                    color: const Color(0xFFD97706),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onPay,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'ชำระเงิน',
              style: GoogleFonts.anuphan(
                fontSize: 13,
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
        borderRadius: BorderRadius.circular(16),
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
            style: GoogleFonts.anuphan(
              color: AppTheme.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            money(total),
            style: GoogleFonts.anuphan(
              color: AppTheme.primaryColor,
              fontSize: 14,
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
        borderRadius: BorderRadius.circular(16),
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
                  style: GoogleFonts.anuphan(
                    color: const Color(0xFF065F46),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  money(deposit),
                  style: GoogleFonts.anuphan(
                    color: AppTheme.primaryColor,
                    fontSize: 15,
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
                      style: GoogleFonts.anuphan(
                        color: const Color(0xFF92400E),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  money(balance),
                  style: GoogleFonts.anuphan(
                    color: const Color(0xFFD97706),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'ภายใน $dueDateText',
                  style: GoogleFonts.anuphan(
                    color: const Color(0xFF92400E),
                    fontSize: 10.5,
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
        borderRadius: BorderRadius.circular(16),
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
                style: GoogleFonts.anuphan(
                  color: AppTheme.mutedText(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$paidCount/$totalCount งวด',
                style: GoogleFonts.anuphan(
                  color: paidCount == totalCount
                      ? AppTheme.primaryColor
                      : AppTheme.onSurface(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
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
                style: GoogleFonts.anuphan(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'รวม ${money(total)}',
                style: GoogleFonts.anuphan(
                  color: AppTheme.mutedText(context),
                  fontSize: 12,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.anuphan(
              color: color,
              fontSize: 13,
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.anuphan(
          color: color,
          fontSize: 10.5,
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
          borderRadius: BorderRadius.circular(16),
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
                    style: GoogleFonts.anuphan(
                      color: AppTheme.primaryColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  Text(
                    bookingRef,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.primaryColor.withValues(alpha: 0.72),
                      fontSize: 11,
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
                  borderRadius: BorderRadius.circular(10),
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
                      style: GoogleFonts.anuphan(
                        color: Colors.white,
                        fontSize: 12,
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
