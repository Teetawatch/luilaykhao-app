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
      padding: const EdgeInsets.only(top: 14),
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

class _ReservationMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReservationMetaPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 142, maxWidth: 310),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.onSurface(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class BookingQuickActions extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onDetail;

  const BookingQuickActions({
    super.key,
    required this.booking,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final status = textOf(booking['status']);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'pending')
          _ActionChipButton(
            icon: Icons.payments_rounded,
            label: 'ชำระเงินต่อ',
            filled: true,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PaymentScreen(bookingRef: textOf(booking['booking_ref'])),
              ),
            ),
          ),
        if (status != 'pending')
          _ActionChipButton(
            icon: Icons.confirmation_number_rounded,
            label: 'ดู Voucher',
            onPressed: onDetail,
          ),
        _ActionChipButton(
          icon: Icons.support_agent_rounded,
          label: 'ติดต่อทีมงานลุยเลเขา',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactUsScreen()),
          ),
        ),
        _ActionChipButton(
          icon: Icons.download_rounded,
          label: 'ดาวน์โหลดใบยืนยัน',
          onPressed: onDetail,
        ),
      ],
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final filledBg = AppTheme.onSurface(context);
    final outlinedBg = AppTheme.surface(context);
    final outlinedFg = AppTheme.onSurface(context);
    return ActionChip(
      avatar: Icon(
        icon,
        size: 17,
        color: filled ? AppTheme.surface(context) : outlinedFg,
      ),
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: filled ? filledBg : outlinedBg,
      side: BorderSide(
        color: filled
            ? filledBg
            : AppTheme.border(context),
      ),
      labelStyle: TextStyle(
        color: filled ? AppTheme.surface(context) : outlinedFg,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
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

