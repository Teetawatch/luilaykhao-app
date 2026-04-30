part of 'customer_app_screen.dart';

enum _ReservationSegment { all, upcoming, past, cancelled }

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  _ReservationSegment _segment = _ReservationSegment.all;
  String _query = '';
  String _sort = 'upcoming';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.isLoggedIn) return const AuthScreen();

    final allBookings = app.bookings.map(asMap).toList();
    final filtered = _filteredBookings(allBookings);
    final upcoming = filtered.where(_isUpcomingBooking).toList();
    final past = filtered.where(_isPastBooking).toList();
    final cancelled = filtered.where(_isCancelledBooking).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: RefreshIndicator(
        onRefresh: app.loadAccountData,
        color: AppTheme.primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: const Color(0xFFF8F8F8).withValues(alpha: 0.95),
              surfaceTintColor: Colors.transparent,
              title: const Text(
                'การจองของฉัน',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _BookingsHeader(
                    totalCount: allBookings.length,
                    upcomingCount: allBookings.where(_isUpcomingBooking).length,
                  ),
                  const SizedBox(height: 24),
                  ReservationSegmentTabs(
                    selected: _segment,
                    counts: {
                      _ReservationSegment.all: allBookings.length,
                      _ReservationSegment.upcoming: allBookings
                          .where(_isUpcomingBooking)
                          .length,
                      _ReservationSegment.past: allBookings
                          .where(_isPastBooking)
                          .length,
                      _ReservationSegment.cancelled: allBookings
                          .where(_isCancelledBooking)
                          .length,
                    },
                    onChanged: (value) => setState(() => _segment = value),
                  ),
                  const SizedBox(height: 16),
                  _BookingUtilityBar(
                    query: _query,
                    sort: _sort,
                    statusFilter: _statusFilter,
                    onQueryChanged: (value) => setState(() => _query = value),
                    onSortChanged: (value) => setState(() => _sort = value),
                    onStatusFilterChanged: (value) =>
                        setState(() => _statusFilter = value),
                  ),
                  const SizedBox(height: 24),
                  if (app.bookings.isEmpty)
                    const EmptyStateWidget()
                  else if (filtered.isEmpty)
                    const _FilteredEmptyState()
                  else ...[
                    if (_segment == _ReservationSegment.all) ...[
                      UpcomingSection(
                        bookings: upcoming,
                        onCancel: _cancelBooking,
                      ),
                      if (upcoming.isNotEmpty) const SizedBox(height: 28),
                      PastTripsSection(bookings: past),
                      if (past.isNotEmpty) const SizedBox(height: 28),
                      BookingSection(
                        eyebrow: 'รายการที่ปิดแล้ว',
                        title: 'ยกเลิก',
                        bookings: cancelled,
                        onCancel: _cancelBooking,
                      ),
                    ] else
                      BookingSection(
                        eyebrow: _segmentEyebrow,
                        title: _segmentTitle,
                        bookings: filtered,
                        onCancel: _cancelBooking,
                      ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _segmentTitle => switch (_segment) {
    _ReservationSegment.all => 'ทั้งหมด',
    _ReservationSegment.upcoming => 'กำลังจะถึง',
    _ReservationSegment.past => 'เดินทางแล้ว',
    _ReservationSegment.cancelled => 'ยกเลิก',
  };

  String get _segmentEyebrow => switch (_segment) {
    _ReservationSegment.all => 'ภาพรวมการเดินทาง',
    _ReservationSegment.upcoming => 'ทริปถัดไปของคุณ',
    _ReservationSegment.past => 'ความทรงจำที่ผ่านมา',
    _ReservationSegment.cancelled => 'รายการที่ปิดแล้ว',
  };

  List<Map<String, dynamic>> _filteredBookings(
    List<Map<String, dynamic>> bookings,
  ) {
    final query = _query.trim().toLowerCase();
    final result = bookings.where((booking) {
      final matchesSegment = switch (_segment) {
        _ReservationSegment.all => true,
        _ReservationSegment.upcoming => _isUpcomingBooking(booking),
        _ReservationSegment.past => _isPastBooking(booking),
        _ReservationSegment.cancelled => _isCancelledBooking(booking),
      };
      if (!matchesSegment) return false;

      final status = textOf(booking['status']);
      if (_statusFilter != 'all' && status != _statusFilter) return false;

      if (query.isEmpty) return true;
      final schedule = asMap(booking['schedule']);
      final trip = asMap(schedule['trip']);
      final searchable = [
        booking['booking_ref'],
        booking['status'],
        trip['title'],
        trip['location'],
        schedule['departure_date'],
      ].map((item) => textOf(item).toLowerCase()).join(' ');
      return searchable.contains(query);
    }).toList();

    result.sort((a, b) {
      final aDate = bookingTravelDate(a) ?? DateTime(1900);
      final bDate = bookingTravelDate(b) ?? DateTime(1900);
      if (_sort == 'latest') {
        final aCreated = DateTime.tryParse(textOf(a['created_at'])) ?? aDate;
        final bCreated = DateTime.tryParse(textOf(b['created_at'])) ?? bDate;
        return bCreated.compareTo(aCreated);
      }
      return aDate.compareTo(bDate);
    });
    return result;
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final reason = await promptText(
      context,
      title: 'เหตุผลการยกเลิก',
      hint: 'ระบุเหตุผล',
    );
    if (reason == null) return;

    try {
      await context.read<AppProvider>().cancelBooking(
        textOf(booking['booking_ref']),
        reason,
      );
      if (mounted) showSnack(context, 'ยกเลิกการจองสำเร็จ');
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    }
  }
}

class _BookingCheckInCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool compact;

  const _BookingCheckInCard({required this.booking, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (textOf(booking['status']) != 'confirmed') {
      return const SizedBox.shrink();
    }

    final bookingRef = textOf(booking['booking_ref'], '-');
    final checkInCode = textOf(booking['qr_code']).trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF2FBF8),
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.14),
        ),
      ),
      child: compact
          ? Row(
              children: [
                _CheckInQrBox(code: checkInCode, size: 74, padding: 7),
                const SizedBox(width: 12),
                Expanded(child: _CheckInTextBlock(bookingRef: bookingRef)),
              ],
            )
          : Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE7F7F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.primaryColor,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                const _CheckInTextBlock(bookingRef: null),
                if (checkInCode.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _CheckInQrBox(code: checkInCode, size: 172, padding: 12),
                ],
                const SizedBox(height: 16),
                _BookingReferencePanel(bookingRef: bookingRef),
              ],
            ),
    );
  }
}

class _CheckInTextBlock extends StatelessWidget {
  final String? bookingRef;

  const _CheckInTextBlock({required this.bookingRef});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: bookingRef == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          'พร้อมสำหรับเช็คอิน',
          textAlign: bookingRef == null ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: Color(0xFF111313),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'โปรดแสดงรหัสนี้แก่เจ้าหน้าที่เมื่อถึงจุดนัดหมาย',
          textAlign: bookingRef == null ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: Color(0xFF687272),
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (bookingRef != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            bookingRef!,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _CheckInQrBox extends StatelessWidget {
  final String code;
  final double size;
  final double padding;

  const _CheckInQrBox({
    required this.code,
    required this.size,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (code.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAEDED)),
        ),
        child: const Icon(
          Icons.qr_code_2_rounded,
          color: AppTheme.textSecondary,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEDED)),
      ),
      child: QrImageView(
        data: code,
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ),
    );
  }
}

class _BookingReferencePanel extends StatelessWidget {
  final String bookingRef;

  const _BookingReferencePanel({required this.bookingRef});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'รหัสการจอง',
            style: TextStyle(
              color: Color(0xFF687272),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            bookingRef,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
