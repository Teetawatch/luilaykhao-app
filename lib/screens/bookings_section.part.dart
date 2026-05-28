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
  final Map<String, dynamic>? nextTrip;

  const _BookingsHeader({
    required this.totalCount,
    required this.upcomingCount,
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
                icon: Icons.luggage_rounded,
                label: 'การจองทั้งหมด',
                value: '$totalCount',
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
      padding: const EdgeInsets.all(14),
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.onSurface(context),
                    fontSize: 21,
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
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 11.5,
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
                  // Past, completed trips: a gentle farewell instead of a
                  // review prompt — these trips can no longer be reviewed.
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
                  const SizedBox(height: 12),

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

                  // Action deck (chat, SOS, pre-trip briefing, reschedule)
                  _BookingActionDeck(booking: booking),

                  // Refund CTA (past trips are no longer reviewable)
                  _RefundStatusCallToAction(booking: booking),
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
