part of 'customer_app_screen.dart';

class _ReviewCallToAction extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _ReviewCallToAction({required this.booking});

  @override
  Widget build(BuildContext context) {
    if (!_isPastBooking(booking)) return const SizedBox.shrink();
    if (_isCancelledBooking(booking)) return const SizedBox.shrink();

    final app = context.watch<AppProvider>();
    if (!bookingNeedsReview(booking, app.myReviews)) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 16,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              'คุณได้รีวิวทริปนี้แล้ว',
              style: GoogleFonts.anuphan(
                color: AppTheme.mutedText(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    final bookingId = int.tryParse(booking['id']?.toString() ?? '');
    if (bookingId == null) return const SizedBox.shrink();
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final tripTitle = textOf(trip['title'], 'ทริป');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.rate_review_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'รีวิวประสบการณ์ของคุณ',
                    style: GoogleFonts.anuphan(
                      color: AppTheme.onSurface(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'ใช้เวลาไม่กี่วินาที ช่วยให้นักเดินทางคนต่อไปตัดสินใจง่ายขึ้น',
                    style: GoogleFonts.anuphan(
                      color: AppTheme.mutedText(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final ok = await ReviewSubmissionDialog.show(
                  context,
                  bookingId: bookingId,
                  tripTitle: tripTitle,
                );
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ขอบคุณสำหรับรีวิว')),
                  );
                }
              },
              child: Text(
                'รีวิว',
                style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefundStatusCallToAction extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _RefundStatusCallToAction({required this.booking});

  @override
  Widget build(BuildContext context) {
    final status = textOf(booking['status']).toLowerCase();
    if (status != 'cancelled' && status != 'refunded') {
      return const SizedBox.shrink();
    }
    final paid = booking['paid_amount'];
    final paidValue = paid is num
        ? paid
        : num.tryParse(paid?.toString() ?? '') ?? 0;
    if (paidValue <= 0) return const SizedBox.shrink();

    final ref = textOf(booking['booking_ref']);
    if (ref.isEmpty) return const SizedBox.shrink();

    final isCompleted = status == 'refunded' ||
        textOf(booking['refund_status']).toLowerCase() == 'completed';
    final label = isCompleted ? 'ดูใบสรุปการคืนเงิน' : 'ติดตามสถานะการคืนเงิน';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RefundStatusScreen(bookingRef: ref),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            children: [
              Icon(
                isCompleted
                    ? Icons.receipt_long_rounded
                    : Icons.payments_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.anuphan(
                    color: AppTheme.onSurface(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.mutedText(context),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingStatusChip extends StatelessWidget {
  final Map<String, dynamic> booking;

  const BookingStatusChip({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final key = _statusKey(booking);
    final color = switch (key) {
      'pending' => const Color(0xFFD97706),
      'near' => const Color(0xFF006565),
      'completed' => const Color(0xFF315A9D),
      'cancelled' => const Color(0xFF687272),
      _ => AppTheme.primaryColor,
    };
    final label = switch (key) {
      'pending' => 'รอชำระเงิน',
      'near' => 'ใกล้เดินทาง',
      'completed' => 'เสร็จสิ้น',
      'cancelled' => 'ยกเลิก',
      _ => 'ยืนยันแล้ว',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime? date;

  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            date == null ? '--' : DateFormat('MMM', 'th_TH').format(date!),
            style: const TextStyle(
              color: Color(0xFF687272),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            date == null ? '--' : DateFormat('d', 'th_TH').format(date!),
            style: const TextStyle(
              color: Color(0xFF111313),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _CountdownPill({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _countdownText(booking),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF111313),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}


class BookingQuickActions extends StatelessWidget {
  final Map<String, dynamic> booking;

  const BookingQuickActions({
    super.key,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _ActionChipButton(
        icon: Icons.support_agent_rounded,
        label: 'ติดต่อทีมงานลุยเลเขา',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ContactUsScreen()),
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.surface(context);
    final fg = AppTheme.onSurface(context);
    return ActionChip(
      avatar: Icon(icon, size: 17, color: fg),
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: bg,
      side: BorderSide(color: AppTheme.border(context)),
      labelStyle: TextStyle(
        color: fg,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

/// Prominent, eye-catching entry point into a trip's group chat. Surfaced on
/// the reservation card and inside the detail sheet.
class _TripChatButton extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _TripChatButton({required this.booking});

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final id = int.tryParse(textOf(schedule['id'])) ?? 0;
    if (id == 0) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              scheduleId: id,
              title: textOf(trip['title'], 'แชทกลุ่มทริป'),
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryColor, AppTheme.accentColor],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'แชทกลุ่มทริป',
                      style: GoogleFonts.anuphan(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'พูดคุยกับเพื่อนร่วมทริปและทีมงาน',
                      style: GoogleFonts.anuphan(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Surfaces a booking's key actions directly on the reservation card so the
/// most-used flows are reachable without opening the detail sheet. Each item
/// is gated by booking status / trip-time window.
class _BookingActionDeck extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingActionDeck({required this.booking});

  @override
  Widget build(BuildContext context) {
    final status = textOf(booking['status']);
    final schedule = asMap(booking['schedule']);
    final isActive = status == 'pending' || status == 'confirmed';
    final confirmed = status == 'confirmed';
    final showBriefing = confirmed && _isPreTripWindow(schedule);
    final showSos = confirmed && _isWithinTripWindow(schedule);
    final canModify = _asBool(booking['can_modify']);
    final hasPickupPoints = asList(schedule['pickup_points']).isNotEmpty;

    final items = <Widget>[
      if (showBriefing)
        _PreTripBriefingCard(booking: booking, schedule: schedule),
      if (showSos)
        _SosButton(scheduleId: int.tryParse(textOf(schedule['id'])) ?? 0),
      if (isActive) _TripChatButton(booking: booking),
      if (canModify)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChipButton(
              icon: Icons.event_repeat_rounded,
              label: 'เปลี่ยนวันเดินทาง',
              onPressed: () => _openReschedule(context),
            ),
            if (hasPickupPoints)
              _ActionChipButton(
                icon: Icons.location_on_rounded,
                label: 'เปลี่ยนจุดรับ',
                onPressed: () => _openChangePickup(context),
              ),
          ],
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            items[i],
          ],
        ],
      ),
    );
  }

  Future<void> _openReschedule(BuildContext context) async {
    final app = context.read<AppProvider>();
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RescheduleSheet(booking: booking),
    );
    if (changed == true && context.mounted) {
      await app.loadAccountData();
      if (context.mounted) showSnack(context, 'เปลี่ยนวันเดินทางสำเร็จ');
    }
  }

  Future<void> _openChangePickup(BuildContext context) async {
    final app = context.read<AppProvider>();
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePickupSheet(booking: booking),
    );
    if (changed == true && context.mounted) {
      await app.loadAccountData();
      if (context.mounted) showSnack(context, 'เปลี่ยนจุดรับสำเร็จ');
    }
  }
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.18 : 0.05,
            ),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              color: AppTheme.primaryColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'ยังไม่มีการจอง',
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'เริ่มออกผจญภัยครั้งใหม่กันเลย',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              final state = context
                  .findAncestorStateOfType<_CustomerAppScreenState>();
              state?.selectTab(0);
            },
            icon: const Icon(Icons.search_rounded),
            label: const Text('ค้นหาทริป'),
          ),
        ],
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.search_off_rounded,
      title: 'ไม่พบการจอง',
      body: 'ลองเปลี่ยนคำค้นหา ตัวกรอง หรือแท็บสถานะอีกครั้ง',
    );
  }
}

