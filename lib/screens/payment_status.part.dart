part of 'payment_screen.dart';

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _accent),
          const SizedBox(height: 16),
          Text(
            'กำลังโหลดข้อมูลการจอง...',
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentEmptyState extends StatelessWidget {
  final VoidCallback onRetry;

  const _PaymentEmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 38,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่พบข้อมูลการจอง',
              style: GoogleFonts.anuphan(
                color: AppTheme.onSurface(context),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'กรุณาลองใหม่อีกครั้ง',
              style: GoogleFonts.anuphan(
                color: AppTheme.mutedText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'ลองใหม่',
                style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress stepper
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentProgress extends StatelessWidget {
  final String status;

  const _PaymentProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (icon: Icons.search_rounded, label: 'เลือกทริป', done: true),
      (icon: Icons.edit_note_rounded, label: 'รายละเอียด', done: true),
      (
        icon: Icons.payments_rounded,
        label: 'ชำระเงิน',
        done: status == 'confirmed',
      ),
    ];

    return Row(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isActive = i == 2;
        final isDone = step.done;
        final color = isDone || isActive ? _accent : AppTheme.border(context);

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDone || isActive
                            ? _accent
                            : AppTheme.subtleSurface(context),
                        shape: BoxShape.circle,
                        boxShadow: isDone || isActive
                            ? [
                                BoxShadow(
                                  color: _accent.withValues(alpha: 0.30),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : step.icon,
                        color: isDone || isActive
                            ? Colors.white
                            : AppTheme.mutedText(context),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        color: isActive
                            ? _accent
                            : AppTheme.mutedText(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (i != steps.length - 1)
                Container(
                  width: 28,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment notice banner
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentNotice extends StatelessWidget {
  const _PaymentNotice();

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningTint(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.priority_high_rounded,
              color: AppTheme.warningColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'กรุณาชำระเงินและระบุเวลาโอนตามสลิป เพื่อยืนยันสิทธิ์การเดินทาง',
              style: GoogleFonts.anuphan(
                color: isDark
                    ? const Color(0xFFFCD34D)
                    : const Color(0xFF92400E),
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Balance-due banner (shown after deposit is paid, while balance is unpaid)
// ─────────────────────────────────────────────────────────────────────────────

class _BalanceDueBanner extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BalanceDueBanner({required this.booking});

  @override
  Widget build(BuildContext context) {
    final balance = _balanceAmount(booking);
    final dueText = _balanceDueDateText(booking);
    final dueDate = _balanceDueDate(booking);
    final daysLeft = dueDate
        ?.difference(DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        ))
        .inDays;
    final isOverdue = daysLeft != null && daysLeft < 0;
    const warn = AppTheme.warningColor;
    const danger = AppTheme.errorColor;
    final color = isOverdue ? danger : warn;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: AppTheme.isDark(context) ? 0.22 : 0.10),
            color.withValues(alpha: AppTheme.isDark(context) ? 0.10 : 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isOverdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverdue ? 'เลยกำหนดชำระยอดส่วนที่เหลือ' : 'ครบกำหนดชำระยอดส่วนที่เหลือ',
                  style: GoogleFonts.anuphan(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  daysLeft == null
                      ? 'กรุณาชำระ ${money(balance)} ภายในวันที่ $dueText'
                      : (isOverdue
                            ? 'กรุณาชำระ ${money(balance)} โดยด่วน (เกินกำหนด ${-daysLeft} วัน)'
                            : 'กรุณาชำระ ${money(balance)} ภายในวันที่ $dueText (อีก $daysLeft วัน)'),
                  style: GoogleFonts.anuphan(
                    color: AppTheme.onSurface(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
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

class _InstallmentBanner extends StatelessWidget {
  final int no;
  final String dueDate;
  final num amount;
  final bool paid;

  const _InstallmentBanner({
    required this.no,
    required this.dueDate,
    required this.amount,
    required this.paid,
  });

  @override
  Widget build(BuildContext context) {
    final color = paid ? _accent : AppTheme.warningColor;
    final due = DateTime.tryParse(dueDate);
    final dueText =
        due == null ? '-' : DateFormat('d MMM yyyy', 'th_TH').format(due);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: AppTheme.isDark(context) ? 0.22 : 0.10),
            color.withValues(alpha: AppTheme.isDark(context) ? 0.10 : 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              paid ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paid ? 'ชำระงวดที่ $no แล้ว' : 'ชำระงวดที่ $no',
                  style: GoogleFonts.anuphan(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paid
                      ? 'รับชำระ ${money(amount)} เรียบร้อยแล้ว'
                      : 'ยอดชำระ ${money(amount)} · ครบกำหนด $dueText',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.onSurface(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
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

// ─────────────────────────────────────────────────────────────────────────────
// Countdown banner
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentCountdownBanner extends StatelessWidget {
  final Map<String, dynamic> booking;

  static const _kDeadlineMinutes = 10;

  const _PaymentCountdownBanner({required this.booking});

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(
      textOf(booking['created_at']),
    )?.toLocal();
    if (createdAt == null) return const SizedBox.shrink();

    final deadline = createdAt.add(const Duration(minutes: _kDeadlineMinutes));
    final remaining = deadline.difference(DateTime.now());
    final expired = remaining.isNegative || remaining.inSeconds <= 0;
    final isUrgent = !expired && remaining.inSeconds <= 120;

    final color = expired || isUrgent ? AppTheme.errorColor : _accent;
    final bgColor = color.withValues(
      alpha: AppTheme.isDark(context) ? 0.15 : 0.08,
    );

    final String timeText;
    if (expired) {
      timeText = 'หมดเวลาแล้ว';
    } else {
      final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      timeText = '$m:$s';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              expired ? Icons.timer_off_rounded : Icons.timer_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expired ? 'หมดเวลาชำระเงิน' : 'เหลือเวลาชำระเงิน',
                  style: GoogleFonts.anuphan(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expired
                      ? 'กรุณาติดต่อเจ้าหน้าที่หากต้องการจองใหม่'
                      : 'การจองจะถูกยกเลิกอัตโนมัติหากไม่ชำระภายใน $_kDeadlineMinutes นาทีจากการจอง',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.mutedText(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            timeText,
            style: GoogleFonts.anuphan(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: expired ? 13 : 22,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seat lock section
// ─────────────────────────────────────────────────────────────────────────────

class _SeatLockSection extends StatefulWidget {
  const _SeatLockSection();

  @override
  State<_SeatLockSection> createState() => _SeatLockSectionState();
}

class _SeatLockSectionState extends State<_SeatLockSection> {
  Timer? _ticker;
  int? _busyScheduleId;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool _isActive(Map<String, dynamic> lock) {
    final lockedUntil = DateTime.tryParse(textOf(lock['locked_until']));
    if (lockedUntil != null) {
      return lockedUntil.difference(DateTime.now()).inSeconds > 0;
    }
    return (int.tryParse(textOf(lock['locked_ttl_seconds'])) ?? 0) > 0;
  }

  Future<void> _continueBooking(Map<String, dynamic> lock) async {
    final app = context.read<AppProvider>();
    final trip = asMap(lock['trip']);
    final slug = textOf(trip['slug']);
    final scheduleId = int.tryParse(textOf(lock['schedule_id']));
    if (slug.isEmpty || scheduleId == null) return;

    setState(() => _busyScheduleId = scheduleId);
    try {
      final results = await Future.wait([app.trip(slug), app.schedules(slug)]);
      if (!mounted) return;
      final seatIds = asList(lock['seat_ids'])
          .map((item) => item?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final pickupPointId = int.tryParse(textOf(lock['pickup_point_id']));
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingFlowScreen(
            trip: Map<String, dynamic>.from(results[0] as Map),
            schedules: List<dynamic>.from(results[1] as List),
            initialScheduleId: scheduleId,
            initialPickupPointId: pickupPointId,
            initialSeatIds: seatIds,
            resumeLockedSeats: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busyScheduleId = null);
    }
  }

  Future<void> _cancelLock(Map<String, dynamic> lock) async {
    final app = context.read<AppProvider>();
    final trip = asMap(lock['trip']);
    final slug = textOf(trip['slug']);
    final scheduleId = int.tryParse(textOf(lock['schedule_id']));
    if (slug.isEmpty || scheduleId == null) return;
    final seatIds = asList(lock['seat_ids'])
        .map((item) => item?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final pickupPointId = int.tryParse(textOf(lock['pickup_point_id']));

    setState(() => _busyScheduleId = scheduleId);
    try {
      final results = await Future.wait([app.trip(slug), app.schedules(slug)]);
      await app.cancelActiveSeatLock(scheduleId, seatIds: seatIds);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('ยกเลิกการจองแล้ว เลือกที่นั่งใหม่ได้เลย')),
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingFlowScreen(
            trip: Map<String, dynamic>.from(results[0] as Map),
            schedules: List<dynamic>.from(results[1] as List),
            initialScheduleId: scheduleId,
            initialPickupPointId: pickupPointId,
            startAtSeatSelection: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busyScheduleId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locks = context
        .watch<AppProvider>()
        .activeSeatLocks
        .map(asMap)
        .where(_isActive)
        .toList();

    if (locks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'ที่นั่งที่รอการจอง',
            style: GoogleFonts.anuphan(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
        ),
        ...locks.map((lock) {
          final scheduleId = int.tryParse(textOf(lock['schedule_id']));
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ActiveSeatLockBanner(
              lock: lock,
              extraCount: 0,
              busy: _busyScheduleId == scheduleId,
              onContinue: () => _continueBooking(lock),
              onCancel: () => _cancelLock(lock),
            ),
          );
        }),
        const SizedBox(height: 6),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking summary card
// ─────────────────────────────────────────────────────────────────────────────
