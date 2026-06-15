import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';

class RefundStatusScreen extends StatefulWidget {
  final String bookingRef;

  const RefundStatusScreen({super.key, required this.bookingRef});

  @override
  State<RefundStatusScreen> createState() => _RefundStatusScreenState();
}

class _RefundStatusScreenState extends State<RefundStatusScreen> {
  Map<String, dynamic>? _booking;
  String? _error;
  bool _loading = true;

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
      final booking = await context.read<AppProvider>().booking(
        widget.bookingRef,
      );
      if (!mounted) return;
      setState(() => _booking = booking);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'สถานะการคืนเงิน',
          style: appFont(
            color: AppTheme.onSurface(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: _loading && _booking == null
              ? const Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _RefundBody(booking: _booking ?? const <String, dynamic>{}),
        ),
      ),
    );
  }
}

class _RefundBody extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _RefundBody({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ref = textOf(booking['booking_ref'], '-');
    final status = textOf(booking['status']);
    final refundStatus = _refundStatus(booking);
    final paid = _toNum(booking['paid_amount']);
    final refundAmount = _toNum(booking['refund_amount']) ?? paid ?? 0;
    final cancelledAt = _toDate(booking['cancelled_at']);
    final refundedAt = _toDate(booking['refunded_at']);
    final reason = textOf(booking['cancellation_reason']).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RefundStatusHeader(
          refundStatus: refundStatus,
          bookingStatus: status,
          amount: refundAmount,
        ),
        const SizedBox(height: 20),
        _MetaCard(
          rows: [
            _MetaRow('หมายเลขการจอง', ref),
            _MetaRow('ยอดชำระ', _money(paid)),
            _MetaRow('ยอดคืน', _money(refundAmount)),
            _MetaRow('วันที่ยกเลิก', _formatDate(cancelledAt) ?? 'รอข้อมูล'),
            if (refundedAt != null)
              _MetaRow('วันที่คืนเงิน', _formatDate(refundedAt) ?? '-'),
            if (reason.isNotEmpty) _MetaRow('เหตุผล', reason),
          ],
        ),
        const SizedBox(height: 20),
        _RefundTimeline(
          status: refundStatus,
          cancelledAt: cancelledAt,
          refundedAt: refundedAt,
        ),
        const SizedBox(height: 24),
        _PolicyCard(),
      ],
    );
  }
}

class _RefundStatusHeader extends StatelessWidget {
  final String refundStatus;
  final String bookingStatus;
  final num amount;

  const _RefundStatusHeader({
    required this.refundStatus,
    required this.bookingStatus,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(refundStatus);
    final label = _labelFor(refundStatus, bookingStatus);
    final hint = _hintFor(refundStatus);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(refundStatus), color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สถานะการคืนเงิน',
                      style: appFont(
                        color: AppTheme.mutedText(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: appFont(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hint,
            style: appFont(
              color: AppTheme.onSurface(context),
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              children: [
                Text(
                  'ยอดคืน',
                  style: appFont(
                    color: AppTheme.mutedText(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  _money(amount),
                  style: appFont(
                    color: AppTheme.onSurface(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
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

class _RefundTimeline extends StatelessWidget {
  final String status;
  final DateTime? cancelledAt;
  final DateTime? refundedAt;

  const _RefundTimeline({
    required this.status,
    required this.cancelledAt,
    required this.refundedAt,
  });

  @override
  Widget build(BuildContext context) {
    final steps = <_TimelineStep>[
      _TimelineStep(
        title: 'รับคำขอยกเลิก',
        subtitle: _formatDate(cancelledAt) ?? 'รอข้อมูล',
        done: cancelledAt != null,
      ),
      _TimelineStep(
        title: 'อยู่ระหว่างตรวจสอบ',
        subtitle: 'เจ้าหน้าที่ตรวจสอบเงื่อนไขและคำนวณยอดคืน',
        done: status == 'processing' || status == 'completed',
        active: status == 'processing',
      ),
      _TimelineStep(
        title: 'คืนเงินสำเร็จ',
        subtitle: refundedAt != null
            ? (_formatDate(refundedAt) ?? '-')
            : 'รอการดำเนินการ',
        done: status == 'completed',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ไทม์ไลน์',
            style: appFont(
              color: AppTheme.onSurface(context),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              step: steps[i],
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final bool done;
  final bool active;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    this.done = false,
    this.active = false,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;

  const _TimelineRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = step.done
        ? AppTheme.primaryColor
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
                  color: step.done
                      ? color
                      : color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: step.done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: color.withValues(alpha: 0.3)),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: appFont(
                      color: AppTheme.onSurface(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: appFont(
                      color: AppTheme.mutedText(context),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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

class _PolicyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      'ยกเลิกก่อน 7 วัน คืน 80% (หักค่าดำเนินการ 20%)',
      'ยกเลิกก่อน 3 วัน คืน 50%',
      'ยกเลิกก่อน 24 ชั่วโมง ไม่สามารถคืนเงินได้',
      'หากผู้จัดทริปยกเลิก คืน 100% อัตโนมัติ',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'นโยบายการคืนเงิน',
                style: appFont(
                  color: AppTheme.onSurface(context),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: appFont(
                        color: AppTheme.onSurface(context),
                        fontSize: 12.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
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

class _MetaCard extends StatelessWidget {
  final List<_MetaRow> rows;
  const _MetaCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      rows[i].label,
                      style: appFont(
                        color: AppTheme.mutedText(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      style: appFont(
                        color: AppTheme.onSurface(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              Divider(height: 1, color: AppTheme.border(context)),
          ],
        ],
      ),
    );
  }
}

class _MetaRow {
  final String label;
  final String value;
  const _MetaRow(this.label, this.value);
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: appFont(
              color: AppTheme.onSurface(context),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onRetry,
            child: const Text('ลองอีกครั้ง'),
          ),
        ],
      ),
    );
  }
}

String _refundStatus(Map<String, dynamic> booking) {
  final explicit = textOf(booking['refund_status']).toLowerCase();
  if (explicit.isNotEmpty) return explicit;
  final status = textOf(booking['status']).toLowerCase();
  if (status == 'refunded') return 'completed';
  if (status == 'cancelled') return 'processing';
  return 'pending';
}

Color _colorFor(String status) {
  return switch (status) {
    'completed' => AppTheme.primaryColor,
    'processing' => const Color(0xFFD97706),
    'rejected' => AppTheme.errorColor,
    _ => AppTheme.primaryColor,
  };
}

IconData _iconFor(String status) {
  return switch (status) {
    'completed' => Icons.check_circle_rounded,
    'processing' => Icons.hourglass_top_rounded,
    'rejected' => Icons.cancel_rounded,
    _ => Icons.info_outline_rounded,
  };
}

String _labelFor(String status, String bookingStatus) {
  return switch (status) {
    'completed' => 'คืนเงินสำเร็จ',
    'processing' => 'กำลังดำเนินการ',
    'rejected' => 'ไม่อนุมัติ',
    _ => bookingStatus == 'cancelled' ? 'รอตรวจสอบ' : 'รอดำเนินการ',
  };
}

String _hintFor(String status) {
  return switch (status) {
    'completed' => 'ยอดเงินได้ถูกคืนเข้าช่องทางเดิมเรียบร้อยแล้ว ใช้เวลา 3–7 วันทำการตามธนาคาร',
    'processing' => 'เจ้าหน้าที่กำลังตรวจสอบและดำเนินการคืนเงินภายใน 3–7 วันทำการ',
    'rejected' => 'คำขอคืนเงินไม่ผ่านเงื่อนไข กรุณาติดต่อเจ้าหน้าที่เพื่อขอรายละเอียดเพิ่มเติม',
    _ => 'ระบบได้รับคำขอแล้ว และจะเริ่มดำเนินการเร็วๆ นี้',
  };
}

num? _toNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String? _formatDate(DateTime? date) {
  if (date == null) return null;
  return DateFormat('d MMM y · HH:mm', 'th_TH').format(date.toLocal());
}

String _money(num? value) {
  final formatter = NumberFormat.currency(
    locale: 'th_TH',
    symbol: '฿',
    decimalDigits: 0,
  );
  return formatter.format(value ?? 0);
}
