import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';

/// ยอดค้างชำระของรอบเดินทาง — สำหรับสตาฟใช้หน้างาน
///
/// ลูกค้าที่ผ่อนชำระบางคนลืมจ่ายงวดที่เหลือ สตาฟเปิดหน้านี้เพื่อดูว่าใครค้าง
/// งวดไหนบ้าง เท่าไหร่ แล้วให้ลูกค้า "สแกน QR ด้วยกล้องมือถือตัวเอง" — QR ชี้ไป
/// หน้า /pay/{token} ซึ่งมี QR PromptPay ยอดถูกต้อง + ช่องแนบสลิปอยู่แล้ว
///
/// เหตุผลที่ไม่แสดง QR PromptPay บนจอสตาฟโดยตรง: สลิปโอนเงินอยู่ในแอปธนาคาร
/// ของลูกค้า ถ้าลูกค้าสแกนจากจอสตาฟ สลิปก็ยังต้องเดินทางกลับมาที่สตาฟอยู่ดี
/// การพาลูกค้าไปหน้าจ่ายเงินบนเครื่องตัวเองทำให้จบได้ในเครื่องเดียว
class StaffOutstandingScreen extends StatefulWidget {
  final int scheduleId;
  final String title;

  const StaffOutstandingScreen({
    super.key,
    required this.scheduleId,
    this.title = '',
  });

  @override
  State<StaffOutstandingScreen> createState() => _StaffOutstandingScreenState();
}

class _StaffOutstandingScreenState extends State<StaffOutstandingScreen> {
  List<Map<String, dynamic>> _items = const [];
  double _totalDue = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppProvider>().loadStaffOutstanding(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          (data['items'] as List? ?? const []).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        _totalDue = _num(data['total_due']);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'โหลดยอดค้างชำระไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPaySheet(Map<String, dynamic> row) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaySheet(scheduleId: widget.scheduleId, row: row),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(
          widget.title.isEmpty ? 'ยอดค้างชำระ' : widget.title,
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _centeredMessage(Icons.error_outline_rounded, _error!);
    }
    if (_items.isEmpty) {
      return _centeredMessage(
        Icons.verified_rounded,
        'ไม่มีใครค้างชำระในรอบนี้',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: _items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        if (i == 0) return _summaryBar();
        final row = _items[i - 1];
        return _OutstandingCard(row: row, onPay: () => _openPaySheet(row));
      },
    );
  }

  Widget _summaryBar() {
    final overdue = _items.where((e) => e['overdue'] == true).length;
    final awaiting = _items.where((e) => e['slip_pending'] == true).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'ค้างชำระ',
                  value: '${_items.length} คน',
                ),
              ),
              _StatBlock(
                label: 'ยอดที่ต้องเก็บรอบนี้',
                value: '฿${_money(_totalDue)}',
                valueColor: AppTheme.primaryColor,
                alignEnd: true,
              ),
            ],
          ),
          if (overdue > 0 || awaiting > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (overdue > 0)
                  _Pill(
                    text: 'เลยกำหนด $overdue คน',
                    color: AppTheme.errorColor,
                  ),
                if (awaiting > 0)
                  _Pill(
                    text: 'รอตรวจสลิป $awaiting คน',
                    color: AppTheme.warningColor,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            // ยอดรวมนับเฉพาะ "งวดที่ถึงกำหนดถัดไป" ของแต่ละคน ไม่ใช่หนี้ทั้งก้อน
            // ต้องบอกให้ชัด ไม่งั้นยอดที่สตาฟเห็นกับที่ลูกค้าค้างจริงจะไม่ตรงกัน
            'นับเฉพาะงวดที่ถึงกำหนดถัดไปของแต่ละคน',
            style: appFont(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centeredMessage(IconData icon, String message) {
    return ListView(
      children: [
        const SizedBox(height: 96),
        Icon(icon, size: 48, color: AppTheme.mutedText(context)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
      ],
    );
  }
}

double _num(dynamic value) => (value as num?)?.toDouble() ?? 0;

String _money(num value) {
  final whole = value.round();
  final digits = whole.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${whole < 0 ? '-' : ''}$buffer';
}

String _dateLabel(dynamic value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return '';
  final parsed = DateTime.tryParse(text);
  return parsed == null ? text : thaiDateShort(parsed.toLocal());
}

List<Map<String, dynamic>> _scheduleOf(Map<String, dynamic> row) {
  final raw = row['schedule'] as List? ?? const [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;

  const _StatBlock({
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: appFont(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.mutedText(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: appFont(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppTheme.onSurface(context),
          ),
        ),
      ],
    );
  }
}

/// การ์ดลูกค้าหนึ่งคน — ยอดงวดถัดไปเด่นที่สุด แล้วกางดูทุกงวดได้
class _OutstandingCard extends StatefulWidget {
  final Map<String, dynamic> row;
  final VoidCallback onPay;

  const _OutstandingCard({required this.row, required this.onPay});

  @override
  State<_OutstandingCard> createState() => _OutstandingCardState();
}

class _OutstandingCardState extends State<_OutstandingCard> {
  bool _expanded = false;

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final overdue = row['overdue'] == true;
    final slipPending = row['slip_pending'] == true;
    final name = (row['customer_name'] ?? '-').toString();
    final phone = (row['phone'] ?? '').toString();
    final bookingRef = (row['booking_ref'] ?? '').toString();
    final label = (row['label'] ?? '').toString();
    final amountDue = _num(row['amount_due']);
    final paidTotal = _num(row['paid_total']);
    final remainingTotal = _num(row['remaining_total']);
    final totalAmount = _num(row['total_amount']);
    final paidCount = (row['paid_count'] as num?)?.toInt() ?? 0;
    final stepCount = (row['installment_count'] as num?)?.toInt() ?? 0;
    final schedule = _scheduleOf(row);
    final dueDate = _dateLabel(row['due_date']);

    final progress = totalAmount > 0
        ? (paidTotal / totalAmount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: AppTheme.cardDecoration(
        context,
        borderColor: overdue && !slipPending
            ? AppTheme.errorColor.withValues(alpha: 0.4)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ชื่อลูกค้า + รหัสจอง ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: appFont(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bookingRef,
                            style: appFont(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (phone.isNotEmpty)
                      IconButton(
                        onPressed: () => _call(phone),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.call_outlined,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                        tooltip: 'โทรหา $phone',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── ยอดที่ต้องเก็บตอนนี้ (ตัวเลขที่สตาฟใช้จริง) ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (slipPending
                            ? AppTheme.warningColor
                            : overdue
                            ? AppTheme.errorColor
                            : AppTheme.primaryColor)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ต้องเก็บตอนนี้ · $label',
                              style: appFont(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.mutedText(context),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '฿${_money(amountDue)}',
                              style: appFont(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.onSurface(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (slipPending)
                        const _Pill(
                          text: 'รอตรวจสลิป',
                          color: AppTheme.warningColor,
                        )
                      else if (overdue)
                        const _Pill(
                          text: 'เลยกำหนด',
                          color: AppTheme.errorColor,
                        )
                      else if (dueDate.isNotEmpty)
                        _Pill(
                          text: 'ครบกำหนด $dueDate',
                          color: AppTheme.mutedText(context),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── ความคืบหน้าการชำระทั้งก้อน ──
                Row(
                  children: [
                    Text(
                      'ชำระแล้ว $paidCount/$stepCount งวด',
                      style: appFont(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '฿${_money(paidTotal)} / ฿${_money(totalAmount)}',
                      style: appFont(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppTheme.mutedText(
                      context,
                    ).withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(
                      AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ยังค้างทั้งหมด ฿${_money(remainingTotal)}',
                  style: appFont(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
          // ── ไทม์ไลน์ทุกงวด (กางเก็บได้) ──
          if (schedule.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                onExpansionChanged: (v) => setState(() => _expanded = v),
                title: Text(
                  _expanded ? 'ซ่อนรายละเอียดงวด' : 'ดูรายละเอียดทุกงวด',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
                iconColor: AppTheme.primaryColor,
                collapsedIconColor: AppTheme.primaryColor,
                children: [
                  for (var i = 0; i < schedule.length; i++)
                    _InstallmentRow(
                      step: schedule[i],
                      isLast: i == schedule.length - 1,
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onPay,
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: Text(
                  'ให้ลูกค้าสแกนจ่าย',
                  style: appFont(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// หนึ่งงวดในไทม์ไลน์ — จุดสถานะ + เส้นเชื่อม + ยอด/กำหนด/วันที่จ่าย
class _InstallmentRow extends StatelessWidget {
  final Map<String, dynamic> step;
  final bool isLast;

  const _InstallmentRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final paid = step['status'] == 'paid';
    final slipPending = step['slip_pending'] == true;
    final overdue = step['overdue'] == true;
    final label = (step['label'] ?? '').toString();
    final amount = _num(step['amount']);
    final dueDate = _dateLabel(step['due_date']);
    final paidAt = _dateLabel(step['paid_at']);

    final (Color color, IconData icon, String status) = paid
        ? (AppTheme.primaryColor, Icons.check_circle_rounded, 'ชำระแล้ว')
        : slipPending
        ? (AppTheme.warningColor, Icons.schedule_rounded, 'แนบสลิปแล้ว รอตรวจ')
        : overdue
        ? (AppTheme.errorColor, Icons.error_rounded, 'เลยกำหนด')
        : (AppTheme.mutedText(context), Icons.circle_outlined, 'ยังไม่ชำระ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, size: 18, color: color),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: AppTheme.mutedText(context).withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: appFont(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                      ),
                      Text(
                        '฿${_money(amount)}',
                        style: appFont(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: paid
                              ? AppTheme.mutedText(context)
                              : AppTheme.onSurface(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      status,
                      if (paid && paidAt.isNotEmpty)
                        'เมื่อ $paidAt'
                      else if (dueDate.isNotEmpty)
                        'ครบกำหนด $dueDate',
                    ].join(' · '),
                    style: appFont(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: color,
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

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// QR เต็มจอให้ลูกค้ายกกล้องสแกน + สรุปงวดที่กำลังจะจ่าย
class _PaySheet extends StatefulWidget {
  final int scheduleId;
  final Map<String, dynamic> row;

  const _PaySheet({required this.scheduleId, required this.row});

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  bool _sending = false;

  Future<void> _sendLink() async {
    if (_sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppProvider>().sendStaffPaymentLink(
        widget.scheduleId,
        widget.row['booking_ref'].toString(),
      );
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        const SnackBar(content: Text('ส่งลิงก์ชำระเงินให้ลูกค้าแล้ว')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ส่งลิงก์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _call() async {
    final phone = (widget.row['phone'] ?? '').toString();
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final payUrl = (row['pay_url'] ?? '').toString();
    final name = (row['customer_name'] ?? '-').toString();
    final label = (row['label'] ?? '').toString();
    final phone = (row['phone'] ?? '').toString();
    final amount = _num(row['amount_due']);
    final remainingTotal = _num(row['remaining_total']);
    final dueDate = _dateLabel(row['due_date']);
    final unpaid = _scheduleOf(row).where((e) => e['status'] != 'paid').toList();

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.mutedText(context).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  name,
                  style: appFont(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Center(
                child: Text(
                  dueDate.isEmpty ? label : '$label · ครบกำหนด $dueDate',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '฿${_money(amount)}',
                  style: appFont(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              if (remainingTotal > amount) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'ยังค้างทั้งหมด ฿${_money(remainingTotal)}',
                    style: appFont(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (payUrl.isEmpty)
                Center(
                  child: Text(
                    'ไม่พบลิงก์ชำระเงินของรายการนี้',
                    style: appFont(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.errorColor,
                    ),
                  ),
                )
              else ...[
                // QR สีขาวเสมอ ไม่ตามธีมมืด — กล้องอ่าน QR ที่ inverted ไม่ออก
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: payUrl,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0F172A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ให้ลูกค้าเปิดกล้องมือถือสแกน QR นี้\nแล้วจ่ายพร้อมแนบสลิปในเครื่องตัวเองได้เลย',
                  textAlign: TextAlign.center,
                  style: appFont(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
              if (unpaid.length > 1) ...[
                const SizedBox(height: 24),
                Text(
                  'งวดที่ยังค้าง',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < unpaid.length; i++)
                  _InstallmentRow(
                    step: unpaid[i],
                    isLast: i == unpaid.length - 1,
                  ),
                Text(
                  // หน้า /pay รับทีละงวดตามลำดับ กันสตาฟบอกลูกค้าผิดว่าจ่ายรวดเดียวได้
                  'ลูกค้าจ่ายได้ทีละงวดตามลำดับ หากต้องการจ่ายหลายงวด ให้สแกนซ้ำอีกครั้ง',
                  style: appFont(
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  if (phone.isNotEmpty) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _call,
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: Text(
                          'โทรหา',
                          style: appFont(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _sendLink,
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        'ส่งลิงก์',
                        style: appFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
