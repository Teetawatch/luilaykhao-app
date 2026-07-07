part of 'customer_app_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Split payment (แบ่งจ่ายกลุ่ม) — เจ้าของแบ่งยอดคงเหลือให้เพื่อนช่วยจ่าย
// แสดงใน BookingDetailSheet เมื่อการจองแบบมัดจำยังมียอดคงเหลือ
// ─────────────────────────────────────────────────────────────────────────────

class _BookingSplitSection extends StatefulWidget {
  final Map<String, dynamic> booking;

  /// เรียกเมื่อสถานะการแบ่งจ่ายเปลี่ยน เพื่อให้ sheet แม่รีโหลดยอดคงเหลือ
  final VoidCallback? onChanged;

  const _BookingSplitSection({required this.booking, this.onChanged});

  @override
  State<_BookingSplitSection> createState() => _BookingSplitSectionState();
}

class _BookingSplitSectionState extends State<_BookingSplitSection> {
  bool _loading = true;
  bool _busy = false;
  Map<String, dynamic>? _split;

  String get _ref => textOf(widget.booking['booking_ref']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().bookingSplit(_ref);
      if (!mounted) return;
      setState(() {
        _split = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startSplit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'แบ่งจ่ายกับเพื่อน',
          style: appFont(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'ระบบจะหารยอดคงเหลือเท่ากันตามจำนวนผู้เดินทาง '
          'เพื่อนจ่ายส่วนของตัวเองผ่านแอปหรือลิงก์ได้เลย '
          'และคุณแก้ยอดของแต่ละคนภายหลังได้',
          style: appFont(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('เริ่มแบ่งจ่าย'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticFeedback.mediumImpact();
    await _run(() => context.read<AppProvider>().setupBookingSplit(_ref));
  }

  Future<void> _cancelSplit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ยกเลิกการแบ่งจ่าย?',
          style: appFont(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'ส่วนที่เพื่อนจ่ายแล้วยังคงอยู่ ยอดที่เหลือกลับไปชำระรวมตามปกติ',
          style: appFont(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ไม่ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยกเลิกการแบ่งจ่าย'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => context.read<AppProvider>().cancelBookingSplit(_ref));
  }

  Future<void> _shareLink(Map<String, dynamic> share) async {
    final schedule = asMap(widget.booking['schedule']);
    final trip = asMap(schedule['trip']);
    final title = textOf(trip['title'], 'ทริป');
    final url = textOf(share['pay_url']);
    if (url.isEmpty) return;
    final name = textOf(share['name'], 'เพื่อน');
    final amount = money(share['amount']);
    final text =
        'ช่วยจ่ายส่วนของคุณสำหรับทริป "$title" หน่อยนะ 🙏\n'
        'ส่วนของ $name: $amount\n'
        'สแกนจ่าย + แนบสลิปได้ที่ลิงก์นี้เลย:\n$url';
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: title));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('คัดลอกลิงก์ชำระเงินแล้ว')),
        );
      }
    }
  }

  Future<void> _remind(Map<String, dynamic> share) async {
    final id = int.tryParse(textOf(share['id'])) ?? 0;
    if (id == 0) return;
    HapticFeedback.selectionClick();
    await _run(() async {
      await context.read<AppProvider>().remindSplitShare(_ref, id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งเตือน ${textOf(share['name'])} แล้ว')),
        );
      }
    });
  }

  void _payShare(Map<String, dynamic> share) {
    final id = int.tryParse(textOf(share['id'])) ?? 0;
    if (id == 0) return;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(bookingRef: _ref, splitShareId: id),
      ),
    );
  }

  Future<void> _editShares() async {
    final split = _split;
    if (split == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _SplitEditSheet(bookingRef: _ref, split: split),
    );
    if (updated == true && mounted) {
      await _load();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final split = _split;
    final enabled = split?['enabled'] == true;
    final isOwner = split?['is_owner'] == true;
    final shares = split == null ? const [] : asList(split['shares']);
    final paidCount = int.tryParse(textOf(split?['paid_shares'])) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetSectionTitle(
          icon: Icons.call_split_rounded,
          title: 'แบ่งจ่ายกับเพื่อน',
        ),
        const SizedBox(height: 6),
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
        else if (!enabled) ...[
          Text(
            'แบ่งยอดคงเหลือให้เพื่อนร่วมทริปช่วยจ่าย แต่ละคนจ่ายส่วนของตัวเอง '
            'ผ่านแอปหรือลิงก์ ไม่ต้องออกเงินก้อนเดียว',
            style: appFont(
              fontSize: 12.5,
              color: AppTheme.mutedText(context),
              height: 1.45,
            ),
          ),
          if (isOwner) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _startSplit,
              icon: const Icon(Icons.call_split_rounded, size: 18),
              label: const Text('แบ่งจ่ายกับเพื่อน'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ] else ...[
          Text(
            'จ่ายแล้ว $paidCount จาก ${shares.length} คน · '
            'ยอดคงเหลือ ${money(split?['outstanding_amount'])}',
            style: appFont(
              fontSize: 12.5,
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...shares.map((item) {
            final share = asMap(item);
            return _SplitShareTile(
              share: share,
              isOwner: isOwner,
              busy: _busy,
              onPay: () => _payShare(share),
              onShareLink: () => _shareLink(share),
              onRemind: () => _remind(share),
            );
          }),
          if (isOwner) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _editShares,
                    icon: const Icon(Icons.tune_rounded, size: 17),
                    label: const Text('แก้ไขยอด'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _cancelSplit,
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('ยกเลิก'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _SplitShareTile extends StatelessWidget {
  final Map<String, dynamic> share;
  final bool isOwner;
  final bool busy;
  final VoidCallback onPay;
  final VoidCallback onShareLink;
  final VoidCallback onRemind;

  const _SplitShareTile({
    required this.share,
    required this.isOwner,
    required this.busy,
    required this.onPay,
    required this.onShareLink,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    final paid = textOf(share['status']) == 'paid';
    final isMine = share['is_mine'] == true;
    final hasMember = textOf(share['member_id']).isNotEmpty;
    final statusColor = paid ? Colors.green : AppTheme.warningColor;
    final name = textOf(share['name'], 'ผู้ร่วมทริป');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMine && !paid
                ? AppTheme.primaryColor.withValues(alpha: 0.55)
                : AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: statusColor.withValues(alpha: 0.12),
              child: Icon(
                paid ? Icons.check_rounded : Icons.hourglass_bottom_rounded,
                size: 17,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMine ? '$name (คุณ)' : name,
                    style: appFont(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${money(share['amount'])} · ${paid ? 'จ่ายแล้ว' : 'รอจ่าย'}',
                    style: appFont(
                      fontSize: 11.5,
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (!paid) ...[
              if (isOwner) ...[
                IconButton(
                  tooltip: 'ส่งลิงก์จ่าย',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.ios_share_rounded,
                    size: 18,
                    color: AppTheme.mutedText(context),
                  ),
                  onPressed: busy ? null : onShareLink,
                ),
                if (hasMember)
                  IconButton(
                    tooltip: 'เตือน',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.notifications_active_rounded,
                      size: 18,
                      color: AppTheme.mutedText(context),
                    ),
                    onPressed: busy ? null : onRemind,
                  ),
              ],
              if (isMine || isOwner)
                FilledButton(
                  onPressed: busy ? null : onPay,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text('จ่าย', style: appFont(fontSize: 12.5)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet ให้เจ้าของแก้ยอดของส่วนที่ยัง pending —
/// ผลรวมของส่วนที่แก้ได้ต้องเท่ากับยอดคงเหลือหลังหักส่วนที่จ่ายแล้ว
class _SplitEditSheet extends StatefulWidget {
  final String bookingRef;
  final Map<String, dynamic> split;

  const _SplitEditSheet({required this.bookingRef, required this.split});

  @override
  State<_SplitEditSheet> createState() => _SplitEditSheetState();
}

class _SplitEditSheetState extends State<_SplitEditSheet> {
  late final List<Map<String, dynamic>> _pending;
  late final List<TextEditingController> _controllers;
  late final num _target;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final shares = asList(widget.split['shares']).map(asMap).toList();
    _pending = shares.where((s) => textOf(s['status']) != 'paid').toList();
    _controllers = _pending
        .map(
          (s) => TextEditingController(
            text: (num.tryParse(textOf(s['amount'])) ?? 0).toStringAsFixed(0),
          ),
        )
        .toList();
    // ยอดคงเหลือใน API คือยอดที่ยังไม่จ่ายอยู่แล้ว — ส่วน pending ต้องรวมเท่านี้
    _target = num.tryParse(textOf(widget.split['outstanding_amount'])) ?? 0;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  num get _sum => _controllers.fold<num>(
    0,
    (sum, c) => sum + (num.tryParse(c.text.trim()) ?? 0),
  );

  Future<void> _save() async {
    if ((_sum - _target).abs() > 0.01) return;
    setState(() => _saving = true);
    try {
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < _pending.length; i++) {
        rows.add({
          'id': int.tryParse(textOf(_pending[i]['id'])),
          'passenger_id': int.tryParse(textOf(_pending[i]['passenger_id'])),
          'member_id': int.tryParse(textOf(_pending[i]['member_id'])),
          'label': textOf(_pending[i]['label']).isEmpty
              ? null
              : textOf(_pending[i]['label']),
          'amount': num.tryParse(_controllers[i].text.trim()) ?? 0,
        });
      }
      await context.read<AppProvider>().updateBookingSplit(
        widget.bookingRef,
        rows,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matched = (_sum - _target).abs() <= 0.01;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'แก้ไขยอดของแต่ละคน',
            style: appFont(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ผลรวมต้องเท่ากับยอดคงเหลือ ${money(_target)}',
            style: appFont(
              fontSize: 12.5,
              color: matched ? Colors.green : AppTheme.errorColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(_pending.length, (i) {
            final share = _pending[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      textOf(share['name'], 'ผู้ร่วมทริป'),
                      style: appFont(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _controllers[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.right,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isDense: true,
                        suffixText: '฿',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'รวม ${money(_sum)}',
                  style: appFont(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: matched ? Colors.green : AppTheme.errorColor,
                  ),
                ),
              ),
              FilledButton(
                onPressed: _saving || !matched ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('บันทึก'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
