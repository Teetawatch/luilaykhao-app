part of 'customer_app_screen.dart';

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

    final isCompleted =
        status == 'refunded' ||
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
                  style: appFont(
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

  const BookingQuickActions({super.key, required this.booking});

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
    final fg = AppTheme.mutedText(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.border(context).withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    color: AppTheme.onSurface(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "สมาชิกในการจอง" — เจ้าของเชิญเพื่อนเข้าการจองเดียวกันเพื่อให้เพื่อนเข้า
/// กลุ่มแชทและติดตามรถได้จากบัญชีของตัวเอง โดยไม่ต้องแยกการจอง/แยกจ่ายเงิน
class _BookingMembersSection extends StatefulWidget {
  final Map<String, dynamic> booking;

  const _BookingMembersSection({required this.booking});

  @override
  State<_BookingMembersSection> createState() => _BookingMembersSectionState();
}

class _BookingMembersSectionState extends State<_BookingMembersSection> {
  bool _loading = true;
  bool _busy = false;
  Map<String, dynamic>? _roster;

  String get _ref => textOf(widget.booking['booking_ref']);
  bool get _isOwner => widget.booking['viewer_is_owner'] == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().bookingMembers(_ref);
      if (!mounted) return;
      setState(() {
        _roster = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    final label = await _askLabel();
    if (label == null || !mounted) return; // ยกเลิก
    setState(() => _busy = true);
    try {
      final data = await context.read<AppProvider>().createBookingInvite(
        _ref,
        label: label.isEmpty ? null : label,
      );
      await _shareInvite(data);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askLabel() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('เชิญเพื่อน', style: appFont(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ตั้งชื่อเล่นให้คำเชิญนี้ (ไม่บังคับ) แล้วส่งลิงก์ให้เพื่อน '
              'เพื่อนกดเข้าร่วมด้วยบัญชีของตัวเองได้ทุกวิธีล็อกอิน',
              style: appFont(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'เช่น บอม, พี่หนึ่ง',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('สร้างลิงก์เชิญ'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareInvite(Map<String, dynamic> data) async {
    final schedule = asMap(widget.booking['schedule']);
    final trip = asMap(schedule['trip']);
    final title = textOf(trip['title'], 'ทริป');
    final token = textOf(data['invite_token']);
    final url = textOf(data['invite_url']);
    final text =
        'มาลุยทริป "$title" ด้วยกัน! 🏞️\n'
        'เปิดแอปลุยเลเขา > การจองของฉัน > ปุ่มเข้าร่วม แล้ววางรหัสนี้:\n$token'
        '${url.isEmpty ? '' : '\n\nหรือลิงก์: $url'}';
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: title));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('คัดลอกลิงก์ชวนเพื่อนแล้ว')),
        );
      }
    }
  }

  Future<void> _revoke(int memberId) async {
    setState(() => _busy = true);
    try {
      await context.read<AppProvider>().revokeBookingMember(_ref, memberId);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roster = _roster;
    final members = roster == null ? const [] : asList(roster['members']);
    final canInviteMore = roster?['can_invite_more'] == true;
    final owner = roster == null ? null : asMap(roster['owner']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetSectionTitle(
          icon: Icons.diversity_3_rounded,
          title: 'สมาชิกในการจอง',
        ),
        const SizedBox(height: 6),
        Text(
          'เชิญเพื่อนร่วมเดินทางเข้าการจองนี้ เพื่อนจะเข้ากลุ่มแชทและติดตามรถ '
          'ได้จากบัญชีของตัวเอง (ใช้การจองและการชำระเงินใบเดียวกัน)',
          style: appFont(
            fontSize: 12.5,
            color: AppTheme.mutedText(context),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else ...[
          if (owner != null && owner.isNotEmpty)
            _MemberTile(
              name: textOf(owner['nickname']).isNotEmpty
                  ? textOf(owner['nickname'])
                  : textOf(owner['name'], 'เจ้าของการจอง'),
              subtitle: 'เจ้าของการจอง',
              statusColor: AppTheme.primaryColor,
            ),
          ...members.map((m) {
            final member = asMap(m);
            final user = asMap(member['user']);
            final isActive = textOf(member['status']) == 'active';
            final name = textOf(user['nickname']).isNotEmpty
                ? textOf(user['nickname'])
                : textOf(user['name']).isNotEmpty
                ? textOf(user['name'])
                : textOf(member['invite_label']).isNotEmpty
                ? textOf(member['invite_label'])
                : textOf(member['passenger_name'], 'เพื่อนที่ถูกเชิญ');
            return _MemberTile(
              name: name,
              subtitle: isActive ? 'เข้าร่วมแล้ว' : 'รอเข้าร่วม',
              statusColor: isActive ? Colors.green : Colors.orange,
              onRemove: _isOwner && !_busy
                  ? () => _revoke(int.tryParse(textOf(member['id'])) ?? 0)
                  : null,
            );
          }),
          if (_isOwner) ...[
            const SizedBox(height: 8),
            if (canInviteMore)
              OutlinedButton.icon(
                onPressed: _busy ? null : _invite,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('เชิญเพื่อน'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              )
            else
              Text(
                'เชิญสมาชิกครบตามจำนวนผู้เดินทางแล้ว',
                style: appFont(
                  fontSize: 12,
                  color: AppTheme.mutedText(context),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final Color statusColor;
  final VoidCallback? onRemove;

  const _MemberTile({
    required this.name,
    required this.subtitle,
    required this.statusColor,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: statusColor.withValues(alpha: 0.12),
              child: Icon(Icons.person_rounded, size: 17, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: appFont(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: appFont(
                      fontSize: 11.5,
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'นำออก',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppTheme.mutedText(context),
                ),
                onPressed: onRemove,
              ),
          ],
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
    final confirmed = status == 'confirmed';
    final showBriefing = confirmed && _isPreTripWindow(schedule);
    final showSos = confirmed && _isWithinTripWindow(schedule);
    final canModify = _asBool(booking['can_modify']);
    final canReschedule = _asBool(booking['can_reschedule']);
    final hasPickupPoints = asList(schedule['pickup_points']).isNotEmpty;

    final showTracking = confirmed && _isUpcomingBooking(booking);

    final items = <Widget>[
      if (showBriefing)
        _PreTripBriefingCard(booking: booking, schedule: schedule),
      if (showTracking) _TrackVehicleButton(booking: booking),
      if (showSos)
        SosButton(scheduleId: int.tryParse(textOf(schedule['id'])) ?? 0),
      if (_chipActions(
            context,
            confirmed,
            canModify,
            canReschedule,
            hasPickupPoints,
          )
          case final chips when chips.isNotEmpty)
        Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: chips[i]),
            ],
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

  /// Centered pill actions shown under a booking: add-to-calendar (confirmed
  /// upcoming) plus reschedule / change-pickup when still modifiable.
  List<Widget> _chipActions(
    BuildContext context,
    bool confirmed,
    bool canModify,
    bool canReschedule,
    bool hasPickupPoints,
  ) {
    return [
      if (confirmed && _isUpcomingBooking(booking))
        _ActionChipButton(
          icon: Icons.calendar_month_rounded,
          label: 'ปฏิทิน',
          onPressed: () => _addToCalendar(context),
        ),
      // เปลี่ยนวันได้เฉพาะเมื่อยังไม่เคยใช้สิทธิ์ และก่อนเดินทางอย่างน้อย 20 วัน
      if (canReschedule)
        _ActionChipButton(
          icon: Icons.event_repeat_rounded,
          label: 'เปลี่ยนวัน',
          onPressed: () => _openReschedule(context),
        ),
      if (canModify && hasPickupPoints)
        _ActionChipButton(
          icon: Icons.location_on_rounded,
          label: 'จุดรับ',
          onPressed: () => _openChangePickup(context),
        ),
    ];
  }

  Future<void> _addToCalendar(BuildContext context) async {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final start = bookingTravelDate(booking);
    if (start == null) {
      showSnack(context, 'ยังไม่มีวันเดินทาง');
      return;
    }
    // Google Calendar all-day events use an exclusive end date.
    final end = (_bookingReturnDate(booking) ?? start).add(
      const Duration(days: 1),
    );
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';

    final location = textOf(
      trip['departure_point'],
      textOf(trip['location']),
    ).trim();
    final details = [
      'รหัสการจอง ${textOf(booking['booking_ref'])}',
      if (location.isNotEmpty) 'จุดนัดพบ: $location',
    ].join('\n');

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': textOf(trip['title'], 'ทริปลุยลายเขา'),
      'dates': '${ymd(start)}/${ymd(end)}',
      'details': details,
      if (location.isNotEmpty) 'location': location,
    });

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      showSnack(context, 'ไม่สามารถเปิดปฏิทินได้');
    }
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

// ─── Track Vehicle Button ─────────────────────────────────────────────────────

class _TrackVehicleButton extends StatefulWidget {
  final Map<String, dynamic> booking;

  const _TrackVehicleButton({required this.booking});

  @override
  State<_TrackVehicleButton> createState() => _TrackVehicleButtonState();
}

class _TrackVehicleButtonState extends State<_TrackVehicleButton> {
  bool _isLoading = false;

  Future<void> _onTap() async {
    final ref = textOf(widget.booking['booking_ref']);
    if (ref.isEmpty || _isLoading) return;

    final app = context.read<AppProvider>();
    final provider = context.read<TrackingProvider>();

    setState(() => _isLoading = true);
    provider.stopTracking();
    await provider.startTracking(ref, authToken: app.token);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (provider.errorMessage.isNotEmpty || provider.booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage.isNotEmpty
                ? provider.errorMessage
                : 'ไม่พบข้อมูลติดตามรถ',
            style: appFont(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => const TrackingMapPage(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : _onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.30),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : const Icon(
                        Icons.near_me_rounded,
                        color: AppTheme.primaryColor,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ติดตามรถแบบเรียลไทม์',
                      style: appFont(
                        color: AppTheme.onSurface(context),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ดูตำแหน่งรถและเวลาถึงโดยประมาณ',
                      style: appFont(
                        color: AppTheme.mutedText(context),
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.primaryColor,
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
