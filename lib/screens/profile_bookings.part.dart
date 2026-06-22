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

/// Apple Wallet–style booking card: a trip cover-image header with the status
/// pill and title overlaid, then the key details and contextual actions below.
/// Tapping anywhere opens the full booking detail sheet.
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
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );

    final actions = <Widget>[
      if (status == 'pending')
        _SmallActionButton(
          icon: Icons.payment_outlined,
          label: 'ชำระเงิน',
          onTap: () => _pushPremium(context, PaymentScreen(bookingRef: ref)),
        ),
      if (_isTripToday(booking))
        _SmallActionButton(
          icon: Icons.route_outlined,
          label: 'ติดตามรถ',
          onTap: () => _openTrackingForBooking(context, booking),
        ),
    ];

    void openDetail() {
      if (ref.isEmpty || ref == '-') return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BookingDetailSheet(bookingRef: ref),
      );
    }

    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: openDetail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover header: image + scrim + status pill + title ──
            SizedBox(
              height: 132,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const _BookingCoverFallback(),
                      errorWidget: (_, _, _) => const _BookingCoverFallback(),
                    )
                  else
                    const _BookingCoverFallback(),
                  // Legibility scrim under the title.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xCC000000),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _BookingStatusPill(status: status),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                        height: 1.2,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Body: details + amount + actions ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoLine(
                    icon: Icons.confirmation_number_outlined,
                    text: ref,
                  ),
                  const SizedBox(height: 8),
                  _InfoLine(icon: Icons.event_outlined, text: date),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppTheme.border(context).withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ยอดรวม',
                              style: appFont(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              money(booking['total_amount']),
                              style: appFont(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textMain,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ดูรายละเอียด',
                            style: appFont(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: actions),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient placeholder for booking cards whose trip has no cover image.
class _BookingCoverFallback extends StatelessWidget {
  const _BookingCoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E7490), Color(0xFF059669)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          color: Colors.white24,
          size: 44,
        ),
      ),
    );
  }
}

/// Status pill overlaid on the cover image — solid white for legibility, with a
/// status-coloured dot and label.
class _BookingStatusPill extends StatelessWidget {
  final String status;

  const _BookingStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' => AppTheme.primaryColor,
      'pending' => AppTheme.warningColor,
      'cancelled' || 'refunded' => AppTheme.errorColor,
      'completed' => const Color(0xFF2563EB),
      _ => AppTheme.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status),
            style: appFont(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

