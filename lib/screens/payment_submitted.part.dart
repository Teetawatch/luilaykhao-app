part of 'payment_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// หน้าแจ้งชำระเงินสำเร็จ — เต็มจอแทน dialog เดิม เพราะจังหวะนี้ลูกค้าเพิ่งโอนเงิน
// ออกไปแล้วอยากรู้ว่า "แล้วยังไงต่อ" มากกว่าคำว่าสำเร็จเฉย ๆ
// ─────────────────────────────────────────────────────────────────────────────

/// ชนิดของการแจ้งชำระ — ใช้เลือกคำอธิบายและขั้นตอนถัดไปให้ตรงกับสิ่งที่เพิ่งจ่าย
enum PaymentSubmissionKind { initial, deposit, balance, installment, share }

class PaymentSubmittedScreen extends StatefulWidget {
  final String bookingRef;
  final num amount;
  final PaymentSubmissionKind kind;
  final String paymentMethod;
  final DateTime transferredAt;
  final String? slipPath;

  /// เลขงวด — ใช้เฉพาะ [PaymentSubmissionKind.installment]
  final int? installmentNo;

  const PaymentSubmittedScreen({
    super.key,
    required this.bookingRef,
    required this.amount,
    required this.kind,
    required this.paymentMethod,
    required this.transferredAt,
    this.slipPath,
    this.installmentNo,
  });

  @override
  State<PaymentSubmittedScreen> createState() => _PaymentSubmittedScreenState();
}

class _PaymentSubmittedScreenState extends State<PaymentSubmittedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _badgeScale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _badgeScale = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0, 0.7, curve: Curves.elasticOut),
    );
    _fade = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.25, 1, curve: Curves.easeOut),
    );
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  String get _kindLabel => switch (widget.kind) {
    PaymentSubmissionKind.initial => 'ชำระเต็มจำนวน',
    PaymentSubmissionKind.deposit => 'ชำระมัดจำ',
    PaymentSubmissionKind.balance => 'ชำระยอดคงเหลือ',
    PaymentSubmissionKind.installment => 'ชำระงวดที่ ${widget.installmentNo}',
    PaymentSubmissionKind.share => 'ชำระส่วนของคุณ (แบ่งจ่ายกลุ่ม)',
  };

  /// ขั้นสุดท้ายต่างกันตามชนิด — จองใหม่ต้องรอ "ยืนยันการจอง" ส่วนยอดที่จ่าย
  /// เพิ่มบนใบจองที่ยืนยันแล้วแค่รออัปเดตยอด
  String get _finalStepTitle => switch (widget.kind) {
    PaymentSubmissionKind.initial ||
    PaymentSubmissionKind.deposit => 'ยืนยันการจอง',
    PaymentSubmissionKind.balance => 'ปิดยอดคงเหลือ',
    PaymentSubmissionKind.installment => 'บันทึกงวดที่ ${widget.installmentNo}',
    PaymentSubmissionKind.share => 'บันทึกส่วนของคุณ',
  };

  String get _finalStepSubtitle => switch (widget.kind) {
    PaymentSubmissionKind.initial ||
    PaymentSubmissionKind.deposit =>
      'ที่นั่งของคุณจะถูกยืนยัน และได้รับ QR สำหรับเช็คอิน',
    PaymentSubmissionKind.balance => 'ใบจองจะขึ้นว่าชำระครบแล้ว',
    PaymentSubmissionKind.installment => 'ยอดคงเหลือจะลดลงตามงวดที่จ่าย',
    PaymentSubmissionKind.share => 'เพื่อนในกลุ่มจะเห็นว่าคุณจ่ายแล้ว',
  };

  String get _methodLabel =>
      widget.paymentMethod == 'promptpay' ? 'QR PromptPay' : 'โอนผ่านธนาคาร';

  void _goToMyBookings() {
    HapticFeedback.selectionClick();
    Navigator.of(context).popUntil((route) => route.isFirst);
    NotificationNavigator.goToBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScaleTransition(scale: _badgeScale, child: const _SuccessBadge()),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _fade,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'แจ้งชำระเงินแล้ว',
                            textAlign: TextAlign.center,
                            style: appFont(
                              color: AppTheme.onSurface(context),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'เราได้รับสลิปของคุณเรียบร้อยแล้ว\nไม่ต้องส่งซ้ำและไม่ต้องเฝ้าหน้านี้',
                            textAlign: TextAlign.center,
                            style: appFont(
                              color: AppTheme.mutedText(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _SubmittedSummaryCard(
                            amount: widget.amount,
                            bookingRef: widget.bookingRef,
                            kindLabel: _kindLabel,
                            methodLabel: _methodLabel,
                            transferredAt: widget.transferredAt,
                            slipPath: widget.slipPath,
                          ),
                          const SizedBox(height: 14),
                          _NextStepsCard(
                            finalStepTitle: _finalStepTitle,
                            finalStepSubtitle: _finalStepSubtitle,
                          ),
                          const SizedBox(height: 14),
                          const _NotifyNote(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _SubmittedActions(
              onPrimary: _goToMyBookings,
              onSecondary: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: _accent.withValues(
            alpha: AppTheme.isDark(context) ? 0.20 : 0.12,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: _accent.withValues(alpha: 0.3), width: 2),
        ),
        child: const Icon(Icons.check_rounded, color: _accent, size: 48),
      ),
    );
  }
}

/// สรุปสิ่งที่เพิ่งแจ้งไป — ยอด เลขที่จอง ช่องทาง เวลาโอน และรูปสลิปที่แนบ
class _SubmittedSummaryCard extends StatelessWidget {
  final num amount;
  final String bookingRef;
  final String kindLabel;
  final String methodLabel;
  final DateTime transferredAt;
  final String? slipPath;

  const _SubmittedSummaryCard({
    required this.amount,
    required this.bookingRef,
    required this.kindLabel,
    required this.methodLabel,
    required this.transferredAt,
    this.slipPath,
  });

  @override
  Widget build(BuildContext context) {
    final path = slipPath;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ยอดที่แจ้งชำระ',
            textAlign: TextAlign.center,
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            money(amount),
            textAlign: TextAlign.center,
            style: appFont(
              color: _accent,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Center(child: _KindPill(label: kindLabel)),
          const SizedBox(height: 16),
          const _Divider(),
          const SizedBox(height: 14),
          _SubmittedRow(
            icon: Icons.confirmation_number_rounded,
            label: 'เลขที่จอง',
            value: bookingRef,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: bookingRef));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('คัดลอกเลขที่จองแล้ว')),
              );
            },
          ),
          const SizedBox(height: 12),
          _SubmittedRow(
            icon: Icons.account_balance_wallet_rounded,
            label: 'ช่องทาง',
            value: methodLabel,
          ),
          const SizedBox(height: 12),
          _SubmittedRow(
            icon: Icons.schedule_rounded,
            label: 'เวลาที่โอน',
            value: thaiDateTimeShort(transferredAt),
          ),
          if (path != null && path.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SlipThumb(path: path),
          ],
        ],
      ),
    );
  }
}

/// ป้ายบอกว่าเป็นการชำระแบบไหน — ข้อความยาว ("ชำระส่วนของคุณ (แบ่งจ่ายกลุ่ม)")
/// ต้องขึ้นบรรทัดใหม่บนจอแคบแทนที่จะล้นออกนอกการ์ด
class _KindPill extends StatelessWidget {
  final String label;

  const _KindPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 14,
            color: AppTheme.mutedText(context),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: appFont(
                color: AppTheme.mutedText(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmittedRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _SubmittedRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  /// ความกว้างคงที่ของช่องไอคอนหน้าแถวและช่องปุ่มคัดลอกท้ายแถว — ทุกแถวจึงเริ่ม
  /// และจบที่เส้นเดียวกัน ไม่ว่าแถวนั้นจะมีปุ่มคัดลอกหรือไม่
  static const double _iconSlot = 22;
  static const double _copySlot = 22;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _iconSlot,
          child: Icon(icon, size: 17, color: AppTheme.mutedText(context)),
        ),
        const SizedBox(width: 8),
        // แบ่งพื้นที่ป้าย/ค่าเป็นสัดส่วนคงที่ ป้ายทุกแถวจึงเริ่มที่เส้นเดียวกัน
        // และค่าทุกแถวชิดขวาที่เส้นเดียวกัน ไม่ขยับตามความยาวข้อความ
        Expanded(
          flex: 4,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              color: AppTheme.onSurface(context),
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          width: _copySlot,
          child: onCopy == null
              ? null
              : GestureDetector(
                  onTap: onCopy,
                  behavior: HitTestBehavior.opaque,
                  child: const Icon(
                    Icons.content_copy_rounded,
                    size: 15,
                    color: _accent,
                  ),
                ),
        ),
      ],
    );
  }
}

/// รูปสลิปที่เพิ่งส่ง — ยืนยันสายตาว่าแนบไฟล์ถูกใบ
class _SlipThumb extends StatelessWidget {
  final String path;

  const _SlipThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(path),
              width: 46,
              height: 46,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 46,
                height: 46,
                color: AppTheme.border(context),
                child: Icon(
                  Icons.receipt_rounded,
                  size: 20,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'แนบสลิปเรียบร้อย',
              style: appFont(
                color: AppTheme.onSurface(context),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(Icons.check_circle_rounded, size: 18, color: _accent),
        ],
      ),
    );
  }
}

/// ขั้นตอนถัดไป — บอกว่าตอนนี้อยู่ตรงไหนของกระบวนการและเหลืออะไรอีก
class _NextStepsCard extends StatelessWidget {
  final String finalStepTitle;
  final String finalStepSubtitle;

  const _NextStepsCard({
    required this.finalStepTitle,
    required this.finalStepSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final steps = <_SubmittedStep>[
      _SubmittedStep(
        title: 'แจ้งชำระเงิน',
        subtitle: 'ส่งเมื่อ ${thaiDateTimeShort(DateTime.now())}',
        done: true,
      ),
      const _SubmittedStep(
        title: 'ทีมงานตรวจสอบสลิป',
        subtitle: 'ปกติไม่เกิน 1 ชั่วโมงในเวลาทำการ (09:00–20:00)',
        active: true,
      ),
      _SubmittedStep(title: finalStepTitle, subtitle: finalStepSubtitle),
    ];

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            icon: Icons.timeline_rounded,
            title: 'ขั้นตอนถัดไป',
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            _SubmittedStepRow(step: steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _SubmittedStep {
  final String title;
  final String subtitle;
  final bool done;
  final bool active;

  const _SubmittedStep({
    required this.title,
    required this.subtitle,
    this.done = false,
    this.active = false,
  });
}

class _SubmittedStepRow extends StatelessWidget {
  final _SubmittedStep step;
  final bool isLast;

  const _SubmittedStepRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = step.done
        ? _accent
        : step.active
        ? const Color(0xFFD97706)
        : AppTheme.border(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: step.done ? color : color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: step.done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color.withValues(alpha: 0.28),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        step.title,
                        style: appFont(
                          color: step.done || step.active
                              ? AppTheme.onSurface(context)
                              : AppTheme.mutedText(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (step.active)
                        const _StatusBadge(
                          label: 'กำลังดำเนินการ',
                          color: Color(0xFFD97706),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: appFont(
                      color: AppTheme.mutedText(context),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// บอกว่าไม่ต้องรอหน้านี้ — เดี๋ยวมีแจ้งเตือนตามไป
class _NotifyNote extends StatelessWidget {
  const _NotifyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: AppTheme.isDark(context) ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // จัดไอคอนให้อยู่กลางบรรทัดหัวข้อพอดี ไม่ลอยสูงกว่าตัวหนังสือ
          const SizedBox(
            width: 22,
            height: 21,
            child: Center(
              child: Icon(
                Icons.notifications_active_rounded,
                size: 20,
                color: _accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เราจะแจ้งให้ทราบเอง',
                  style: appFont(
                    color: AppTheme.onSurface(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'เมื่อตรวจสอบเสร็จ คุณจะได้รับการแจ้งเตือนในแอปและอีเมล '
                  'ปิดแอปไปทำอย่างอื่นได้เลย',
                  style: appFont(
                    color: AppTheme.mutedText(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
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

class _SubmittedActions extends StatelessWidget {
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _SubmittedActions({required this.onPrimary, required this.onSecondary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              icon: const Icon(Icons.confirmation_number_rounded, size: 20),
              label: Text(
                'ดูการจองของฉัน',
                style: appFont(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.mutedText(context),
              ),
              child: Text(
                'กลับไปหน้าชำระเงิน',
                style: appFont(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
