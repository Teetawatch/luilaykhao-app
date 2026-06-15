part of 'profile_screen.dart';

class ProfileBookingsScreen extends StatefulWidget {
  final String title;
  final BookingFilter filter;

  const ProfileBookingsScreen({
    super.key,
    required this.title,
    this.filter = BookingFilter.all,
  });

  @override
  State<ProfileBookingsScreen> createState() => _ProfileBookingsScreenState();
}

class _ProfileBookingsScreenState extends State<ProfileBookingsScreen> {
  Future<void> _refresh() => context.read<AppProvider>().loadAccountData();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final bookings = app.bookings.map(asMap).where((booking) {
      return switch (widget.filter) {
        BookingFilter.upcoming => _isUpcomingBooking(booking),
        BookingFilter.past => _isPastBooking(booking),
        BookingFilter.all => true,
      };
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            TravelSliverAppBar(title: widget.title),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: bookings.isEmpty
                    ? const _EmptyProfileState(
                        icon: Icons.confirmation_number_outlined,
                        title: 'ยังไม่มีรายการ',
                        body:
                            'เมื่อคุณจองทริป รายการจะแสดงที่หน้านี้',
                      )
                    : Column(
                        children: [
                          for (final booking in bookings) ...[
                            _BookingSummaryCard(
                              booking: booking,
                              onRefresh: _refresh,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingSummaryCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Future<void> Function() onRefresh;

  const _BookingSummaryCard({required this.booking, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final ref = _cleanText(booking['booking_ref'], fallback: '-');
    final status = _cleanText(booking['status']);
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final title = _cleanText(trip['title'], fallback: 'ทริปของคุณ');
    final date = _travelDateText(booking);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _sectionDecoration(context: context, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(icon: Icons.confirmation_number_outlined, text: ref),
          const SizedBox(height: 8),
          _InfoLine(icon: Icons.event_outlined, text: date),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.payments_outlined,
            text: 'ยอดรวม ${money(booking['total_amount'])}',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == 'pending')
                _SmallActionButton(
                  icon: Icons.payment_outlined,
                  label: 'ชำระเงิน',
                  onTap: () =>
                      _pushPremium(context, PaymentScreen(bookingRef: ref)),
                ),
              if (_isTripToday(booking))
                _SmallActionButton(
                  icon: Icons.route_outlined,
                  label: 'ติดตามรถ',
                  onTap: () => _openTrackingForBooking(context, booking),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

