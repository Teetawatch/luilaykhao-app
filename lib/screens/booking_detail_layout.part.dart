part of 'customer_app_screen.dart';

// ─── โครงหน้า "ดูตั๋ว & รายละเอียด" ─────────────────────────────────────────────
//
// หน้าเดียวเลื่อนยาว แต่เรียงเป็นหมวดตายตัว ลูกค้าจะรู้ว่าต้องเลื่อนไปหาอะไรตรงไหน:
//
//   หัวตั๋ว (ทริป · วัน · กี่คน · ยอด · รหัส · สถานะ)
//   ต้องทำ   — สิ่งที่ค้างอยู่กับลูกค้า (จ่ายเงิน, เอกสาร, รอบถูกเลื่อน …)
//   วันเดินทาง — โหมดวันเดินทาง / SOS เฉพาะช่วงทริป
//   ตั๋วเดินทาง · การเดินทาง · ผู้เดินทาง · การชำระเงิน · ความทรงจำ · จัดการการจอง
//
// การ์ดย่อยหลายใบซ่อนตัวเองเมื่อไม่มีข้อมูล และเว้นระยะด้านบนของตัวเอง (16)
// การ์ดที่ไม่ได้เว้นเองจึงต้องใส่ `_detailGap` ไว้ข้างหน้า — ระยะห่างจะเท่ากันทั้งหน้า
// และไม่เหลือช่องว่างลอยเมื่อการ์ดไหนหายไป

const _detailGap = SizedBox(height: 16);

/// หัวตั๋ว — สิ่งแรกที่เห็น ตอบว่าใบนี้คือทริปอะไร ไปวันไหน กี่คน เท่าไร
class _BookingDetailHeader extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool awaitingNewRound;

  const _BookingDetailHeader({
    required this.booking,
    required this.awaitingNewRound,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final image = ApiConfig.mediaUrl(
      textOf(trip['thumbnail_image'], textOf(trip['cover_image'])),
    );
    final location = textOf(trip['location']).trim();
    final ref = textOf(booking['booking_ref']);
    final voucher = num.tryParse('${booking['voucher_amount'] ?? ''}') ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: image.isEmpty
                      ? _thumbPlaceholder(context)
                      : CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          memCacheWidth: 180,
                          placeholder: (_, _) => _thumbPlaceholder(context),
                          errorWidget: (_, _, _) => _thumbPlaceholder(context),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textOf(trip['title'], 'รายละเอียดการจอง'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        color: AppTheme.onSurface(context),
                        fontSize: AppText.sizeTitle,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 14,
                            color: AppTheme.mutedText(context),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                fontSize: AppText.sizeCaption,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.mutedText(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _TicketPerforation(),
          const SizedBox(height: 14),
          _HeaderFact(
            icon: Icons.calendar_month_rounded,
            label: 'วันเดินทาง',
            value: _travelDateText(booking),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeaderFact(
                  icon: Icons.groups_rounded,
                  label: 'ผู้เดินทาง',
                  value: _travelerText(booking),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeaderFact(
                  icon: Icons.payments_rounded,
                  label: 'ยอดชำระ',
                  value: money(booking['total_amount']),
                  // จ่ายด้วยบัตรของขวัญ — total_amount คือยอดที่เหลือต้องจ่ายเป็นเงิน
                  note: voucher > 0 ? 'ใช้บัตรของขวัญ ${money(voucher)}' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _BookingRefCopy(bookingRef: ref)),
              const SizedBox(width: 8),
              _StatusChip(
                status: awaitingNewRound
                    ? 'awaiting_new_round'
                    : textOf(booking['status']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder(BuildContext context) => Container(
    color: AppTheme.selectedTint(context),
    child: const Icon(
      Icons.landscape_rounded,
      color: AppTheme.primaryColor,
      size: 26,
    ),
  );
}

class _HeaderFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? note;

  const _HeaderFact({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
              Text(
                value,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                  height: 1.35,
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// รหัสการจอง + แตะเพื่อคัดลอก — ลูกค้าต้องส่งรหัสนี้ให้ทีมงานทางแชทบ่อยที่สุด
class _BookingRefCopy extends StatelessWidget {
  final String bookingRef;

  const _BookingRefCopy({required this.bookingRef});

  @override
  Widget build(BuildContext context) {
    if (bookingRef.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: () async {
            HapticFeedback.selectionClick();
            await Clipboard.setData(ClipboardData(text: bookingRef));
            if (context.mounted) showSnack(context, 'คัดลอกรหัสการจองแล้ว');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    bookingRef,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: AppTheme.mutedText(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// เส้นปรุแบบตั๋ว — แบ่งหัวตั๋วออกจากรายละเอียด
class _TicketPerforation extends StatelessWidget {
  const _TicketPerforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashPainter(color: AppTheme.border(context)),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;

  const _DashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

/// หัวหมวดของหน้า — ตัวเล็กสีจาง + เส้นยาว ให้ต่างจากหัวข้อย่อย
/// (`_SheetSectionTitle`) ที่อยู่ข้างในหมวด ระยะด้านบนเว้นมาในตัว
class _DetailChapter extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;

  const _DetailChapter({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Row(
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 6),
          Text(
            title,
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.2,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(
              '· $trailing',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Divider(height: 1, thickness: 1, color: AppTheme.border(context)),
          ),
        ],
      ),
    );
  }
}

/// สรุปยอดของใบจอง — รูปแบบการจ่าย ยอดที่รวมไว้แล้ว และสถานะการชำระ
///
/// ใบที่จ่ายมัดจำแล้วยังค้างยอดส่วนที่เหลือใช้ `_BookingDepositSummary` แทน
/// (ซึ่งแจกแจงมัดจำ/คงเหลือ/วันครบกำหนดอยู่แล้ว)
class _BookingPaymentSummary extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingPaymentSummary({required this.booking});

  static num _num(dynamic value) => num.tryParse('${value ?? ''}') ?? 0;

  String _typeLabel() {
    final split = asMap(booking['split']);
    if (split['enabled'] == true) return 'แบ่งจ่ายกับเพื่อน';
    return switch (textOf(booking['payment_type'], 'full')) {
      'deposit' => 'จ่ายมัดจำ',
      'installment' =>
        _num(booking['installment_count']) > 0
            ? 'ผ่อนชำระ ${_num(booking['installment_count'])} งวด'
            : 'ผ่อนชำระ',
      _ => 'จ่ายเต็มจำนวน',
    };
  }

  /// สถานะการชำระเป็นคำเดียว + สี — ไม่เดาจาก paid_amount ตรง ๆ เพราะใบที่
  /// ผ่อน/มัดจำ ยอดนั้นยังไม่ใช่ยอดสุดท้าย
  ({String label, Color color, IconData icon}) _status(BuildContext context) {
    final status = textOf(booking['status']);
    final installments = asList(booking['installment_payments']).map(asMap);
    final paidInstallments = installments
        .where((i) => textOf(i['status']) == 'paid')
        .length;

    if (status == 'cancelled' || status == 'refunded') {
      final paid = _num(booking['paid_amount']);
      return (
        label: paid > 0 ? 'ยกเลิก · ชำระไปแล้ว ${money(paid)}' : 'ยกเลิก',
        color: AppTheme.mutedText(context),
        icon: Icons.cancel_outlined,
      );
    }
    if (status == 'pending') {
      return textOf(booking['slip_ocr_status']).isNotEmpty
          ? (
              label: 'ได้รับสลิปแล้ว · รอทีมงานตรวจสอบ',
              color: AppTheme.accentColor,
              icon: Icons.hourglass_top_rounded,
            )
          : (
              label: 'รอชำระเงิน',
              color: AppTheme.warningColor,
              icon: Icons.schedule_rounded,
            );
    }
    final extraDue = _num(asMap(booking['extra_due'])['amount']);
    if (extraDue > 0) {
      return (
        label: 'ต้องชำระเพิ่ม ${money(extraDue)}',
        color: AppTheme.warningColor,
        icon: Icons.add_card_rounded,
      );
    }
    if (installments.isNotEmpty && paidInstallments < installments.length) {
      return (
        label: 'จ่ายแล้ว $paidInstallments จาก ${installments.length} งวด',
        color: AppTheme.warningColor,
        icon: Icons.timelapse_rounded,
      );
    }
    final paidAt = DateTime.tryParse(
      textOf(booking['balance_paid_at'], textOf(booking['paid_at'])),
    );
    return (
      label: paidAt != null
          ? 'ชำระครบแล้ว · ${thaiDateShort(paidAt.toLocal())}'
          : 'ชำระครบแล้ว',
      color: AppTheme.primaryColor,
      icon: Icons.check_circle_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final addons = _num(booking['addons_total']);
    final rentals = _num(booking['rentals_total']);
    final voucher = _num(booking['voucher_amount']);
    final waived = _num(booking['waived_amount']);
    final status = _status(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BookingDepositRow(label: 'รูปแบบการชำระ', value: _typeLabel()),
          if (addons > 0) ...[
            const SizedBox(height: 6),
            _BookingDepositRow(label: 'รวมบริการเสริม', value: money(addons)),
          ],
          if (rentals > 0) ...[
            const SizedBox(height: 6),
            _BookingDepositRow(label: 'รวมค่าเช่าอุปกรณ์', value: money(rentals)),
          ],
          if (voucher > 0) ...[
            const SizedBox(height: 6),
            _BookingDepositRow(
              label: 'บัตรของขวัญ',
              value: '−${money(voucher)}',
            ),
          ],
          if (waived > 0) ...[
            const SizedBox(height: 6),
            _BookingDepositRow(label: 'ยกเว้นให้', value: '−${money(waived)}'),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: AppTheme.border(context)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ยอดชำระ',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              Text(
                money(booking['total_amount']),
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(status.icon, size: 15, color: status.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  status.label,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    color: status.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ตัวเลือกรูปแบบชำระของใบที่ยังไม่จ่าย — ชิปแทน dropdown เพราะมีแค่ 2–4 ทาง
/// และลูกค้าควรเห็นทุกทางพร้อมกันโดยไม่ต้องกดเปิด
class _PaymentTypePicker extends StatelessWidget {
  final String value;
  final bool deposit;
  final bool installment;
  final bool split;
  final ValueChanged<String> onChanged;

  const _PaymentTypePicker({
    required this.value,
    required this.deposit,
    required this.installment,
    required this.split,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = <(String, String)>[
      ('full', 'จ่ายเต็ม'),
      if (deposit) ('deposit', 'จ่ายมัดจำ'),
      if (installment) ('installment', 'ผ่อนชำระ'),
      if (split) ('split', 'แบ่งจ่ายกับเพื่อน'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รูปแบบชำระเงิน',
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w700,
            color: AppTheme.mutedText(context),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (key, label) in options)
              ChoiceChip(
                label: Text(label),
                selected: value == key,
                showCheckmark: false,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onChanged(key);
                },
                labelStyle: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  color: value == key
                      ? AppTheme.primaryColor
                      : AppTheme.onSurface(context),
                ),
                backgroundColor: AppTheme.surface(context),
                selectedColor: AppTheme.selectedTint(context),
                side: BorderSide(
                  color: value == key
                      ? AppTheme.primaryColor
                      : AppTheme.border(context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
