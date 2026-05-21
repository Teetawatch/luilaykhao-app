part of 'customer_app_screen.dart';

BoxDecoration _ecoCardDecoration(BuildContext context) {
  return AppTheme.cardDecoration(
    context,
    radius: 32,
    borderColor: AppTheme.border(context).withValues(alpha: 0.45),
    shadowOpacity: 0.05,
  );
}

class _BookingsHeader extends StatelessWidget {
  final int totalCount;
  final int upcomingCount;

  const _BookingsHeader({
    required this.totalCount,
    required this.upcomingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.18 : 0.06,
            ),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.luggage_rounded,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ติดตามและจัดการการเดินทางของคุณ',
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: 24,
              height: 1.18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ดูสถานะทริป รายละเอียดการชำระเงิน และเอกสารยืนยันได้ครบในที่เดียว',
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryPill(
                  label: 'ทริปที่กำลังจะถึง',
                  value: '$upcomingCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryPill(
                  label: 'การจองทั้งหมด',
                  value: '$totalCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

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
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border(context)),
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
                    size: 17,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
            decoration: InputDecoration(
              hintText: 'ค้นหาการจอง',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppTheme.surface(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppTheme.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppTheme.border(context)),
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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Icon(icon, color: AppTheme.onSurface(context)),
    );
  }
}

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
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.onSurface(context),
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Text(
                '${bookings.length} รายการ',
                style: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
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

class ReservationCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const ReservationCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final bookingRef = textOf(booking['booking_ref'], '-');
    final isCancelled = _isCancelledBooking(booking);
    final image = ApiConfig.mediaUrl(
      textOf(
        trip['thumbnail_image'],
        textOf(trip['cover_image'], '/images/landscape.webp'),
      ),
    );

    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            BookingDetailSheet(bookingRef: booking['booking_ref'].toString()),
      ),
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppTheme.isDark(context) ? 0.20 : 0.06,
              ),
              blurRadius: 34,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: Stack(
                children: [
                  SizedBox(
                    height: 178,
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
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.46),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: _DateBadge(date: bookingTravelDate(booking)),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      children: [
                        Expanded(child: _CountdownPill(booking: booking)),
                        const SizedBox(width: 8),
                        BookingStatusChip(booking: booking),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          textOf(trip['title'], 'การจอง'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.onSurface(context),
                            fontSize: 20,
                            height: 1.22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'เมนูเพิ่มเติม',
                        onSelected: (value) {
                          if (value == 'detail') {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) =>
                                  BookingDetailSheet(bookingRef: bookingRef),
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'detail',
                            child: Text('ดูรายละเอียด'),
                          ),
                        ],
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.subtleSurface(context),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.more_horiz_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'หมายเลขการจอง $bookingRef',
                    style: TextStyle(
                      color: AppTheme.mutedText(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (textOf(booking['status']) == 'confirmed') ...[
                    const SizedBox(height: 14),
                    _BookingCheckInCard(booking: booking, compact: true),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ReservationMetaPill(
                        icon: Icons.calendar_month_rounded,
                        label: 'วันเดินทาง',
                        value: _travelDateText(booking),
                      ),
                      _ReservationMetaPill(
                        icon: Icons.groups_rounded,
                        label: 'ผู้เดินทาง',
                        value: _travelerText(booking),
                      ),
                      _ReservationMetaPill(
                        icon: Icons.location_on_rounded,
                        label: 'จุดรับ',
                        value: _pickupText(booking),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ยอดรวม',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              money(booking['total_amount']),
                              style: TextStyle(
                                color: AppTheme.onSurface(context),
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) =>
                              BookingDetailSheet(bookingRef: bookingRef),
                        ),
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('ดูรายละเอียด'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BookingActionDeck(booking: booking),
                  BookingQuickActions(
                    booking: booking,
                    onDetail: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          BookingDetailSheet(bookingRef: bookingRef),
                    ),
                  ),
                  _ReviewCallToAction(booking: booking),
                  _RefundStatusCallToAction(booking: booking),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

