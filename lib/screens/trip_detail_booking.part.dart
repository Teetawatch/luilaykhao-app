part of 'trip_detail_screen.dart';

class StickyBookingBar extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> schedules;
  final int? selectedScheduleId;
  final int? selectedPickupPointId;

  const StickyBookingBar({
    super.key,
    required this.trip,
    required this.schedules,
    this.selectedScheduleId,
    this.selectedPickupPointId,
  });

  @override
  Widget build(BuildContext context) {
    final selectedSchedule = _selectedScheduleFor(
      schedules,
      selectedScheduleId,
    );
    final selectedPickupPoint = _selectedPickupPointFor(
      selectedSchedule,
      selectedPickupPointId,
    );
    final joinTripEnabled = _asBool(selectedSchedule['join_trip_enabled']);
    final joinTripPrice = _asNum(selectedSchedule['join_trip_price']);
    final selectedRegionLabel = _pickupRegionLabel(selectedPickupPoint);
    final priceLabel = selectedRegionLabel.isEmpty
        ? 'ราคาเริ่มต้น'
        : 'ราคาสำหรับ $selectedRegionLabel';

    void openBooking({bool joinTrip = false}) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingFlowScreen(
            trip: trip,
            schedules: schedules,
            initialScheduleId: selectedScheduleId,
            initialPickupPointId: selectedPickupPointId,
            initialJoinTrip: joinTrip,
          ),
        ),
      );
    }

    void handleBookingTap({bool joinTrip = false}) {
      final app = context.read<AppProvider>();
      if (app.isLoggedIn) {
        openBooking(joinTrip: joinTrip);
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            onLoginSuccess: () {
              if (context.mounted) openBooking(joinTrip: joinTrip);
            },
          ),
        ),
      );
    }

    final isCharter = _asBool(selectedSchedule['is_charter']);
    final hasSchedule = schedules.isNotEmpty && selectedSchedule.isNotEmpty;
    final isBookable = hasSchedule && _scheduleIsBookable(selectedSchedule);
    // "เต็ม" (eligible for waitlist) = a real, future, non-charter departure
    // with no seats left — distinct from a past/closed one which can't be queued.
    final isFull = hasSchedule &&
        !isCharter &&
        !_isSchedulePast(selectedSchedule) &&
        _scheduleAvailableSeats(selectedSchedule) <= 0;

    // ป้ายปุ่มสะท้อนสถานะของรอบที่เลือกจริง ไม่ใช่ขึ้น "จองเลย" ตลอด
    final String bookLabel;
    final IconData bookIcon;
    if (isBookable || !hasSchedule || isCharter) {
      // charter มีป้าย "รอบเหมา" อยู่แล้วในส่วนราคา ปุ่มจึงคงข้อความปกติไว้
      bookLabel = 'จองเลย';
      bookIcon = Icons.hiking_rounded;
    } else if (_isSchedulePast(selectedSchedule)) {
      bookLabel = 'ปิดรับจอง';
      bookIcon = Icons.event_busy_rounded;
    } else {
      bookLabel = 'เต็มแล้ว';
      bookIcon = Icons.do_not_disturb_on_rounded;
    }

    final isDark = AppTheme.isDark(context);
    final priceValue = _priceText(
      trip,
      schedule: selectedSchedule,
      pickupPoint: selectedPickupPoint,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.surfaceDark.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? AppTheme.outlineDark.withValues(alpha: 0.5)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : const Color(0xFF0F172A).withValues(alpha: 0.10),
                    blurRadius: 32,
                    offset: const Offset(0, -6),
                  ),
                  if (!isDark)
                    BoxShadow(
                      color: _softAccent.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── price + book row ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // price section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: _softAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    priceLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: appFont(
                                      fontSize: 11.5,
                                      color: AppTheme.mutedText(context),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              if (isCharter)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.lock_rounded,
                                      size: 13,
                                      color: Color(0xFF7C3AED),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'รอบเหมา',
                                      style: appFont(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Text(
                                priceValue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: appFont(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : _premiumText,
                                  height: 1.1,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              if (!isCharter && joinTripEnabled) ...[
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _softAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Join Trip ${_priceText(trip, schedule: selectedSchedule, isJoinTrip: true)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: appFont(
                                      fontSize: 11,
                                      color: _softAccent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // book button — or, when the chosen round is full, a
                        // waitlist CTA so demand isn't lost at a sold-out round
                        if (isFull)
                          _WaitlistButton(
                            scheduleId:
                                int.tryParse('${selectedSchedule['id']}') ?? 0,
                          )
                        else
                          _BookingButton(
                            enabled: isBookable,
                            label: bookLabel,
                            icon: bookIcon,
                            onPressed: handleBookingTap,
                          ),
                      ],
                    ),
                  ),
                  // ── join trip button ──────────────────────────────
                  if (!isCharter && joinTripEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _softAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _softAccent.withValues(alpha: 0.20),
                            ),
                          ),
                          child: TextButton.icon(
                            onPressed: !isBookable
                                ? null
                                : () => handleBookingTap(joinTrip: true),
                            style: TextButton.styleFrom(
                              foregroundColor: _softAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.groups_rounded, size: 19),
                            label: Text(
                              joinTripPrice > 0
                                  ? 'จอยทริป · ${money(joinTripPrice)} / คน'
                                  : 'จอยทริป',
                              style: appFont(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sold-out CTA: lets a signed-in customer queue for a seat on a full round,
/// or jump to "คิวรอที่นั่ง" when they're already in line. Mirrors the booking
/// button's footprint so the bar layout stays identical between states.
class _WaitlistButton extends StatefulWidget {
  final int scheduleId;

  const _WaitlistButton({required this.scheduleId});

  @override
  State<_WaitlistButton> createState() => _WaitlistButtonState();
}

class _WaitlistButtonState extends State<_WaitlistButton> {
  bool _checking = true;
  bool _busy = false;
  bool _inQueue = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void didUpdateWidget(covariant _WaitlistButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduleId != widget.scheduleId) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final app = context.read<AppProvider>();
    if (!app.isLoggedIn || widget.scheduleId == 0) {
      if (mounted) setState(() => _checking = false);
      return;
    }
    setState(() => _checking = true);
    try {
      final status = await app.waitlistStatus(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _inQueue = status['in_waitlist'] == true;
        _checking = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _openWaitlist() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaitlistScreen()),
    );
  }

  Future<void> _join() async {
    final app = context.read<AppProvider>();
    if (!app.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            onLoginSuccess: () {
              if (mounted) _refreshStatus();
            },
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await app.joinWaitlist(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _inQueue = true;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'เพิ่มเข้าคิวรอแล้ว — เราจะแจ้งเตือนทันทีที่มีที่นั่งว่าง',
            style: appFont(color: Colors.white),
          ),
          action: SnackBarAction(
            label: 'ดูคิว',
            textColor: Colors.white,
            onPressed: _openWaitlist,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'เพิ่มเข้าคิวไม่สำเร็จ',
            style: appFont(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inQueue = _inQueue;
    final color = inQueue ? AppTheme.accentColor : AppTheme.primaryColor;
    final label = inQueue ? 'ดูคิวรอ' : 'รอที่นั่งว่าง';
    final icon = inQueue
        ? Icons.checklist_rtl_rounded
        : Icons.hourglass_bottom_rounded;

    return GestureDetector(
      onTap: _checking || _busy ? null : (inQueue ? _openWaitlist : _join),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_checking || _busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else
              Icon(icon, size: 19, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: appFont(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingButton extends StatefulWidget {
  final bool enabled;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _BookingButton({
    required this.enabled,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_BookingButton> createState() => _BookingButtonState();
}

class _BookingButtonState extends State<_BookingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (widget.enabled) widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: widget.enabled
                ? AppTheme.primaryColor
                : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 19, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: appFont(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
