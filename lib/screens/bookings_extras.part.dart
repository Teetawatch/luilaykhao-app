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
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RefundStatusScreen(bookingRef: ref),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
                    fontSize: AppText.sizeBody,
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

/// ยกเลิกการจองที่ยังไม่ได้ชำระ — backend รองรับมาตลอด แต่แอปไม่เคยมีทางเข้า
/// ลูกค้าที่เปลี่ยนใจจึงต้องนั่งรอให้ระบบตัดทิ้งเอง
class _CancelPendingButton extends StatefulWidget {
  final Map<String, dynamic> booking;

  const _CancelPendingButton({required this.booking});

  @override
  State<_CancelPendingButton> createState() => _CancelPendingButtonState();
}

class _CancelPendingButtonState extends State<_CancelPendingButton> {
  bool _busy = false;

  Future<void> _cancel() async {
    final ref = textOf(widget.booking['booking_ref']);
    if (ref.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ยกเลิกการจองนี้?',
          style: appFont(fontSize: AppText.sizeTitle, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'ที่นั่งจะถูกคืนให้คนอื่นทันที และการจองนี้จะกู้กลับมาไม่ได้',
          style: appFont(fontSize: AppText.sizeBody, color: AppTheme.mutedText(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('เก็บไว้ก่อน', style: appFont(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'ยกเลิกการจอง',
              style: appFont(
                fontWeight: FontWeight.w800,
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    final app = context.read<AppProvider>();
    try {
      await app.cancelBooking(ref, 'ลูกค้ายกเลิกเอง');
      await app.loadAccountData();
      if (mounted) showSnack(context, 'ยกเลิกการจองแล้ว');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ActionChipButton(
      icon: _busy ? Icons.hourglass_empty_rounded : Icons.close_rounded,
      label: _busy ? 'กำลังยกเลิก...' : 'ยกเลิกการจอง',
      onPressed: _busy ? () {} : _cancel,
    );
  }
}

/// สถานะจุดรับที่ลูกค้าปักหมุดขอเอง — รออนุมัติ / ไม่อนุมัติ (พร้อมเหตุผล)
/// จุดที่อนุมัติแล้วไม่ต้องแจ้งซ้ำ เพราะไปโผล่เป็นจุดรับปกติในสรุปอยู่แล้ว
class _CustomPickupStatusNote extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _CustomPickupStatusNote({required this.booking});

  @override
  Widget build(BuildContext context) {
    final custom = asMap(booking['custom_pickup']);
    final status = textOf(custom['status']);
    if (status.isEmpty || status == 'approved') return const SizedBox.shrink();

    final rejected = status == 'rejected';
    final label = textOf(custom['label']);
    final reason = textOf(custom['reject_reason']);

    final color = rejected ? AppTheme.errorColor : const Color(0xFFD97706);
    final body = rejected
        ? (reason.isNotEmpty
              ? 'จุดรับที่ขอไว้ไม่ผ่านการอนุมัติ · $reason'
              : 'จุดรับที่ขอไว้ไม่ผ่านการอนุมัติ กรุณาเลือกจุดรับอื่น')
        : 'ทีมงานกำลังตรวจสอบจุดรับที่คุณปักหมุดไว้ จะแจ้งผลให้ทราบ';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              rejected
                  ? Icons.wrong_location_rounded
                  : Icons.pin_drop_outlined,
              size: 17,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rejected ? 'จุดรับที่ขอไว้ถูกปฏิเสธ' : 'จุดรับพิเศษ · รออนุมัติ',
                    style: appFont(
                      color: color,
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (label.isNotEmpty)
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        color: AppTheme.onSurface(context),
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: appFont(
                      color: AppTheme.mutedText(context),
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// สิ่งที่ผูกกับการจองแต่เดิมมองไม่เห็นเลยจากหน้ารายการ — แบ่งจ่ายกลุ่ม,
/// ส่วนต่างที่ต้องจ่ายวันเดินทาง, อุปกรณ์ที่เช่า, ตัวเลือกเสริม, ของขวัญ
class _BookingExtrasChips extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingExtrasChips({required this.booking});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    final split = asMap(booking['split']);
    if (_asBool(split['enabled'])) {
      final paid = int.tryParse(textOf(split['paid_shares'])) ?? 0;
      final total = int.tryParse(textOf(split['total_shares'])) ?? 0;
      chips.add(
        _ExtraChip(
          icon: Icons.groups_2_rounded,
          label: 'แบ่งจ่าย $paid/$total คน',
          color: paid >= total && total > 0
              ? AppTheme.primaryColor
              : const Color(0xFFD97706),
        ),
      );
    }

    final flexi = num.tryParse(textOf(booking['flexi_surcharge'])) ?? 0;
    if (flexi > 0) {
      chips.add(
        _ExtraChip(
          icon: Icons.savings_rounded,
          label: 'จ่ายเพิ่มวันเดินทาง ${money(flexi)}',
          color: const Color(0xFFD97706),
        ),
      );
    }

    final rentals = asList(booking['selected_rentals']);
    if (rentals.isNotEmpty) {
      chips.add(
        _ExtraChip(
          icon: Icons.backpack_rounded,
          label: 'เช่าอุปกรณ์ ${rentals.length} รายการ',
          color: const Color(0xFF6366F1),
        ),
      );
    }

    final addons = asList(booking['selected_addons']);
    if (addons.isNotEmpty) {
      chips.add(
        _ExtraChip(
          icon: Icons.add_circle_outline_rounded,
          label: 'ตัวเลือกเสริม ${addons.length} รายการ',
          color: const Color(0xFF6366F1),
        ),
      );
    }

    if (_asBool(booking['is_gift'])) {
      final gift = asMap(booking['gift']);
      final claimed = _asBool(gift['claimed']);
      chips.add(
        _ExtraChip(
          icon: Icons.card_giftcard_rounded,
          label: claimed ? 'ของขวัญ · รับแล้ว' : 'ของขวัญ · รอผู้รับกดรับ',
          color: const Color(0xFFDB2777),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }
}

class _ExtraChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ExtraChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: appFont(
              color: color,
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
      'near' => const Color(0xFF047857),
      'completed' => const Color(0xFF315A9D),
      'cancelled' => AppTheme.mutedText(context),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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
              fontSize: AppText.sizeCaption,
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
        color: AppTheme.surface(context).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          Text(
            date == null ? '--' : DateFormat('MMM', 'th_TH').format(date!),
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: AppText.sizeMicro,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            date == null ? '--' : DateFormat('d', 'th_TH').format(date!),
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: AppText.sizeH2,
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
        color: AppTheme.surface(context).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        _countdownText(booking),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.onSurface(context),
          fontSize: AppText.sizeCaption,
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
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
                    fontSize: AppText.sizeCaption,
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

/// "เพื่อนร่วมเดินทาง" — ใครอยู่ในการจองนี้บ้าง พร้อมทางเข้าหน้าเชิญเพื่อน
/// (การสร้าง/ส่งซ้ำ/ยกเลิกคำเชิญอยู่ใน [InviteFriendsScreen] ที่เดียว)
class _BookingMembersSection extends StatefulWidget {
  final Map<String, dynamic> booking;

  const _BookingMembersSection({required this.booking});

  @override
  State<_BookingMembersSection> createState() => _BookingMembersSectionState();
}

class _BookingMembersSectionState extends State<_BookingMembersSection> {
  bool _loading = true;
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

  /// จัดการคำเชิญทั้งหมดอยู่ในหน้า "เชิญเพื่อนร่วมทริป" ที่เดียว — ชีตนี้แค่บอก
  /// ว่าตอนนี้ใครอยู่ในการจองบ้าง แล้วพาไปหน้านั้น
  Future<void> _openInviteScreen() async {
    HapticFeedback.selectionClick();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InviteFriendsScreen(booking: widget.booking),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final roster = _roster;
    final members = roster == null ? const [] : asList(roster['members']);
    final canInviteMore = roster?['can_invite_more'] == true;
    final owner = roster == null ? null : asMap(roster['owner']);
    final joined = members
        .where((m) => textOf(asMap(m)['status']) == 'active')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetSectionTitle(
          icon: Icons.diversity_3_rounded,
          title: 'เพื่อนร่วมเดินทาง',
        ),
        const SizedBox(height: 6),
        Text(
          'เชิญเพื่อนเข้าการจองใบเดียวกันได้ เพื่อนจะเข้ากลุ่มแชท ดูกำหนดการ '
          'และติดตามรถได้จากบัญชีของตัวเอง โดยไม่ต้องจองใหม่หรือจ่ายเพิ่ม',
          style: appFont(
            fontSize: AppText.sizeLabel,
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
              subtitle: isActive ? 'เข้าร่วมแล้ว' : 'รอเพื่อนกดเข้าร่วม',
              statusColor: isActive
                  ? AppTheme.successColor
                  : AppTheme.warningColor,
            );
          }),
          if (_isOwner) ...[
            const SizedBox(height: 8),
            _InviteFriendsEntryCard(
              onTap: _openInviteScreen,
              subtitle: canInviteMore
                  ? (members.isEmpty
                        ? 'สร้างลิงก์คำเชิญแล้วส่งให้เพื่อนได้เลย'
                        : 'ส่งลิงก์ซ้ำ จัดการสมาชิก หรือเชิญเพิ่ม')
                  : 'เชิญครบแล้ว ($joined คนเข้าร่วม) — แตะเพื่อจัดการสมาชิก',
            ),
          ],
        ],
      ],
    );
  }
}

/// ทางเข้าหน้าเชิญเพื่อน — วางไว้ทั้งในชีตรายละเอียดและบนการ์ดการจอง เพราะเดิม
/// เป็นแค่ปุ่มเล็ก ๆ ท้ายชีต คนส่วนใหญ่จึงไม่รู้ว่าเชิญเพื่อนเข้าการจองได้
class _InviteFriendsEntryCard extends StatelessWidget {
  final VoidCallback onTap;
  final String subtitle;

  const _InviteFriendsEntryCard({required this.onTap, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.30),
            ),
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
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
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
                      'เชิญเพื่อนร่วมทริป',
                      style: appFont(
                        color: AppTheme.onSurface(context),
                        fontSize: AppText.sizeSubtitle,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: appFont(
                        color: AppTheme.mutedText(context),
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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

class _MemberTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final Color statusColor;

  const _MemberTile({
    required this.name,
    required this.subtitle,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
                      fontSize: AppText.sizeBody,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
    final showSos = confirmed && _isWithinTripWindow(schedule);
    final canModify = _asBool(booking['can_modify']);
    final canReschedule = _asBool(booking['can_reschedule']);
    final hasPickupPoints = asList(schedule['pickup_points']).isNotEmpty;

    final showTracking = confirmed && _isUpcomingBooking(booking);

    // เชิญเพื่อน — เฉพาะเจ้าของการจองที่ยังเดินทางไม่ถึง และมีที่นั่งมากกว่าหนึ่ง
    // (การจองคนเดียวเชิญใครไม่ได้ เพราะโควตาสมาชิก = จำนวนผู้เดินทาง)
    final showInvite =
        booking['viewer_is_owner'] == true &&
        (status == 'pending' || status == 'confirmed') &&
        _isUpcomingBooking(booking) &&
        asList(booking['passengers']).length > 1;

    final items = <Widget>[
      if (showTracking) _TrackVehicleButton(booking: booking),
      if (showInvite)
        _InviteFriendsEntryCard(
          subtitle: 'ให้เพื่อนเข้าแชทกลุ่มและติดตามรถได้ ไม่ต้องจองใหม่',
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InviteFriendsScreen(booking: booking),
              ),
            );
          },
        ),
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

  /// Centered pill actions shown under a booking. Add-to-calendar และเปลี่ยนจุดรับ
  /// ย้ายไปอยู่ในหน้า "ดูตั๋ว/รายละเอียด" แล้ว เหลือเฉพาะเปลี่ยนวันเป็นทางลัดในการ์ด.
  List<Widget> _chipActions(
    BuildContext context,
    bool confirmed,
    bool canModify,
    bool canReschedule,
    bool hasPickupPoints,
  ) {
    return [
      // ยังไม่ได้ชำระ = ถอนตัวได้เอง ไม่ต้องรอระบบตัดทิ้งหรือทักหาแอดมิน
      if (textOf(booking['status']) == 'pending' &&
          textOf(booking['slip_ocr_status']).isEmpty)
        _CancelPendingButton(booking: booking),
      // เปลี่ยนวันได้เฉพาะเมื่อยังไม่เคยใช้สิทธิ์ และก่อนเดินทางอย่างน้อย 20 วัน
      if (canReschedule)
        _ActionChipButton(
          icon: Icons.event_repeat_rounded,
          label: 'เปลี่ยนวัน',
          onPressed: () => _openReschedule(context),
        ),
    ];
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

}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
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
              fontSize: AppText.sizeH1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'เริ่มออกผจญภัยครั้งใหม่กันเลย',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontSize: AppText.sizeBody,
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
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.30),
            ),
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
                        fontSize: AppText.sizeSubtitle,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ดูตำแหน่งรถและเวลาถึงโดยประมาณ',
                      style: appFont(
                        color: AppTheme.mutedText(context),
                        fontSize: AppText.sizeCaption,
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
