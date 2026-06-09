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

    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final horizontalPadding = screenWidth < 380
        ? 16.0
        : screenWidth >= 700
        ? 32.0
        : 20.0;
    final contentMaxWidth = screenWidth >= 700 ? 760.0 : double.infinity;
    final bottomPadding = 132.0 + media.viewPadding.bottom;

    final allBookings = app.bookings.map(asMap).toList();
    final filtered = _filteredBookings(allBookings);
    final upcoming = filtered.where(_isUpcomingBooking).toList();
    final past = filtered.where(_isPastBooking).toList();
    final cancelled = filtered.where(_isCancelledBooking).toList();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        onRefresh: app.loadAccountData,
        color: AppTheme.primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: AppTheme.background(
                context,
              ).withValues(alpha: 0.95),
              surfaceTintColor: Colors.transparent,
              title: const Text(
                'การจองของฉัน',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'เข้าร่วมการจองของเพื่อน',
                  icon: const Icon(Icons.group_add_rounded),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const JoinBookingScreen(),
                    ),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                bottomPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BookingsHeader(
                          totalCount: allBookings.length,
                          upcomingCount: allBookings
                              .where(_isUpcomingBooking)
                              .length,
                          completedCount: allBookings
                              .where(_isPastBooking)
                              .length,
                          provinceCount: _provincesVisited(allBookings),
                          nextTrip: upcoming.firstOrNull,
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
                          onChanged: (value) =>
                              setState(() => _segment = value),
                        ),
                        const SizedBox(height: 16),
                        _BookingUtilityBar(
                          query: _query,
                          sort: _sort,
                          statusFilter: _statusFilter,
                          onQueryChanged: (value) =>
                              setState(() => _query = value),
                          onSortChanged: (value) =>
                              setState(() => _sort = value),
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
                            UpcomingSection(bookings: upcoming),
                            if (upcoming.isNotEmpty) const SizedBox(height: 28),
                            PastTripsSection(bookings: past),
                            if (past.isNotEmpty) const SizedBox(height: 28),
                            BookingSection(
                              eyebrow: 'รายการที่ปิดแล้ว',
                              title: 'ยกเลิก',
                              bookings: cancelled,
                            ),
                          ] else
                            BookingSection(
                              eyebrow: _segmentEyebrow,
                              title: _segmentTitle,
                              bookings: filtered,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
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

  /// Distinct provinces/destinations across trips the user has already
  /// travelled — drives the "จังหวัดที่ไป" stat in the header.
  int _provincesVisited(List<Map<String, dynamic>> bookings) {
    return bookings
        .where(_isPastBooking)
        .map((b) => textOf(asMap(asMap(b['schedule'])['trip'])['location']).trim())
        .where((location) => location.isNotEmpty)
        .toSet()
        .length;
  }

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

}

// ─────────────────────────────────────────────────────────────────────────────
// Check-in Card (shown inside ReservationCard & BookingDetailSheet)
// ─────────────────────────────────────────────────────────────────────────────

class _BookingCheckInCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingCheckInCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    if (textOf(booking['status']) != 'confirmed') {
      return const SizedBox.shrink();
    }

    final bookingRef = textOf(booking['booking_ref'], '-');
    final checkInCode = textOf(booking['qr_code']).trim();
    final isDark = AppTheme.isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.primaryColor.withValues(alpha: 0.14)
            : AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.how_to_reg_rounded,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const _CheckInTextBlock(bookingRef: null),
          if (checkInCode.isNotEmpty) ...[
            const SizedBox(height: 20),
            _CheckInQrBox(code: checkInCode, size: 180, padding: 14),
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
    final centered = bookingRef == null;
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              centered ? MainAxisAlignment.center : MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 16,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              'พร้อมสำหรับเช็คอิน',
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: GoogleFonts.anuphan(
                color: AppTheme.onSurface(context),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'โปรดแสดงรหัสนี้แก่เจ้าหน้าที่เมื่อถึงจุดนัดหมาย',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.anuphan(
            color: AppTheme.mutedText(context),
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (bookingRef != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            bookingRef!,
            style: GoogleFonts.anuphan(
              color: AppTheme.primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
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
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Icon(
          Icons.qr_code_2_rounded,
          color: AppTheme.mutedText(context),
          size: size * 0.45,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        children: [
          Text(
            'รหัสการจอง',
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            bookingRef,
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              color: AppTheme.primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
