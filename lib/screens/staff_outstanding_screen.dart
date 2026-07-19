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
/// เท่าไหร่ แล้วให้ลูกค้า "สแกน QR ด้วยกล้องมือถือตัวเอง" — QR ชี้ไปหน้า
/// /pay/{token} ซึ่งมี QR PromptPay ยอดถูกต้อง + ช่องแนบสลิปอยู่แล้ว
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
        _totalDue = (data['total_due'] as num?)?.toDouble() ?? 0;
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
        return _OutstandingCard(row: row, onTap: () => _openPaySheet(row));
      },
    );
  }

  Widget _summaryBar() {
    final overdue = _items.where((e) => e['overdue'] == true).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ค้างชำระ',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_items.length} คน',
                  style: appFont(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                if (overdue > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'เลยกำหนด $overdue คน',
                    style: appFont(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ยอดรวม',
                style: appFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedText(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '฿${_money(_totalDue)}',
                style: appFont(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
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

String _dueLabel(String? date) {
  if (date == null || date.isEmpty) return '';
  final parsed = DateTime.tryParse(date);
  return parsed == null ? date : thaiDateShort(parsed);
}

class _OutstandingCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  const _OutstandingCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final overdue = row['overdue'] == true;
    final slipPending = row['slip_pending'] == true;
    final name = (row['customer_name'] ?? '-').toString();
    final phone = (row['phone'] ?? '').toString();
    final label = (row['label'] ?? '').toString();
    final amount = (row['amount_due'] as num?)?.toDouble() ?? 0;
    final dueDate = _dueLabel(row['due_date']?.toString());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(
            context,
            borderColor: overdue && !slipPending
                ? AppTheme.errorColor.withValues(alpha: 0.4)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phone.isEmpty ? label : '$label · $phone',
                          style: appFont(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '฿${_money(amount)}',
                    style: appFont(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (slipPending)
                    // สลิปแนบแล้วแต่ VerifySlipJob ยังตรวจไม่เสร็จ — บอกสตาฟไว้
                    // ไม่งั้นจะไปทวงคนที่เพิ่งจ่ายไปเมื่อกี้
                    const _Pill(
                      text: 'แนบสลิปแล้ว รอตรวจ',
                      color: AppTheme.warningColor,
                    )
                  else if (overdue)
                    const _Pill(text: 'เลยกำหนด', color: AppTheme.errorColor)
                  else if (dueDate.isNotEmpty)
                    _Pill(
                      text: 'ครบกำหนด $dueDate',
                      color: AppTheme.mutedText(context),
                    ),
                  const Spacer(),
                  const Icon(
                    Icons.qr_code_2_rounded,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ให้ลูกค้าสแกน',
                    style: appFont(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
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

/// QR เต็มจอให้ลูกค้ายกกล้องสแกน + ทางออกสำรอง (ส่งลิงก์ / โทรหา)
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
    final amount = (row['amount_due'] as num?)?.toDouble() ?? 0;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.mutedText(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: appFont(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: appFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '฿${_money(amount)}',
                style: appFont(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              if (payUrl.isEmpty)
                Text(
                  'ไม่พบลิงก์ชำระเงินของรายการนี้',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.errorColor,
                  ),
                )
              else ...[
                // QR สีขาวเสมอ ไม่ตามธีมมืด — กล้องอ่าน QR ที่ inverted ไม่ออก
                Container(
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
