import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'app_snack.dart';

/// "ตอนนี้คุณอยู่ตรงไหน" — ปุ่มสามปุ่มที่ลูกค้ากดบอกทีมงานเองที่จุดนัด
///
/// เช้าวันเดินทางมีคำถามเดียวที่วิ่งไปมาสองทาง: ทีมงานอยากรู้ว่าครบหรือยัง
/// ลูกค้าอยากบอกว่ากำลังมาแต่ติดไฟแดง ทั้งสองฝั่งลงเอยด้วยการโทรหากันในเวลา
/// ที่ต่างคนต่างไม่ว่าง การ์ดนี้ตัดสายนั้นทิ้ง — กดหนึ่งครั้ง รายชื่อของทีมงาน
/// เปลี่ยนทันที และถ้าแจ้งว่าสาย ทีมงานได้แจ้งเตือนพร้อมตัวเลขนาทีไปเลย
///
/// สิ่งที่การ์ดนี้ไม่ทำ: มันไม่ใช่การเช็คอิน กด "ถึงแล้ว" ไม่ได้แปลว่าขึ้นรถแล้ว
/// คนยืนยันว่าใครอยู่บนรถยังเป็นทีมงานเสมอ — ข้อความบนการ์ดจึงต้องไม่ทำให้
/// เข้าใจว่ากดแล้วจบ
class PickupStatusCard extends StatefulWidget {
  final Map<String, dynamic> booking;

  const PickupStatusCard({super.key, required this.booking});

  @override
  State<PickupStatusCard> createState() => _PickupStatusCardState();
}

class _PickupStatusCardState extends State<PickupStatusCard> {
  String? _status;
  int? _etaMinutes;
  bool _sending = false;

  /// เซิร์ฟเวอร์ปฏิเสธเพราะนอกช่วงเวลา/เช็คอินไปแล้ว — เก็บการ์ดไปเลย ไม่ต้อง
  /// ให้ผู้ใช้กดแล้วเจอข้อความเดิมซ้ำ ๆ
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.booking['pickup_status'];
    _status = raw is String && raw.isNotEmpty ? raw : null;
    _etaMinutes = int.tryParse('${widget.booking['pickup_status_eta_minutes']}');
  }

  String get _ref => '${widget.booking['booking_ref'] ?? ''}';

  Future<void> _send(String status, {int? etaMinutes}) async {
    if (_sending || _ref.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _sending = true);

    try {
      final result = await context.read<AppProvider>().reportPickupStatus(
        _ref,
        status: status,
        etaMinutes: etaMinutes,
      );
      if (!mounted) return;
      setState(() {
        _status = '${result['pickup_status']}';
        _etaMinutes = int.tryParse('${result['pickup_status_eta_minutes']}');
      });
      // อัปเดตสำเนาในหน่วยความจำด้วย เพื่อให้กลับเข้าหน้านี้ใหม่แล้วยังเห็นสถานะเดิม
      widget.booking['pickup_status'] = _status;
      widget.booking['pickup_status_eta_minutes'] = _etaMinutes;
      HapticFeedback.mediumImpact();
      AppSnack.success(context, 'บอกทีมงานแล้ว');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 422) {
        setState(() => _closed = true);
        AppSnack.error(context, e.message);
        return;
      }
      AppSnack.error(
        context,
        e.isNetworkError
            ? 'ส่งไม่สำเร็จ — ไม่มีสัญญาณ ลองอีกครั้งเมื่อสัญญาณกลับมา'
            : e.message,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, 'ส่งไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// ถามว่า "สายประมาณเท่าไหร่" — ตัวเลขคือสิ่งเดียวที่ทำให้ทีมงานตัดสินใจได้ว่า
  /// จะรอต่อหรือให้ไปขึ้นจุดถัดไป การแจ้งสายโดยไม่มีตัวเลขแทบไม่ช่วยอะไร
  Future<void> _askHowLate() async {
    HapticFeedback.selectionClick();

    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สายประมาณเท่าไหร่',
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(ctx),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'บอกคร่าว ๆ ได้เลย ทีมงานจะได้วางแผนรอถูก',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText(ctx),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in const [5, 10, 15, 30, 45, 60])
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, m),
                      child: Text(
                        '$m นาที',
                        style: appFont(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (minutes != null) await _send('late', etaMinutes: minutes);
  }

  @override
  Widget build(BuildContext context) {
    if (_closed || _ref.isEmpty || widget.booking['checked_in'] == true) {
      return const SizedBox.shrink();
    }

    final reported = _status != null && _status!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.record_voice_over_rounded,
                size: 18,
                color: AppTheme.mutedText(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reported ? 'บอกทีมงานไว้ว่า' : 'บอกทีมงานว่าคุณอยู่ตรงไหน',
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reported
                ? _statusLine
                : 'กดบอกได้เลย ทีมงานจะได้ไม่ต้องโทรตาม และรู้ว่าต้องรอใครอยู่',
            style: appFont(
              fontSize: AppText.sizeLabel,
              height: 1.45,
              fontWeight: reported ? FontWeight.w800 : FontWeight.w500,
              color: reported
                  ? _statusColor(context)
                  : AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatusButton(
                  label: 'กำลังไป',
                  icon: Icons.directions_walk_rounded,
                  selected: _status == 'on_the_way',
                  onTap: _sending ? null : () => _send('on_the_way'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusButton(
                  label: 'ถึงแล้ว',
                  icon: Icons.where_to_vote_rounded,
                  selected: _status == 'arrived',
                  onTap: _sending ? null : () => _send('arrived'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusButton(
                  label: 'อาจสาย',
                  icon: Icons.running_with_errors_rounded,
                  selected: _status == 'late',
                  onTap: _sending ? null : _askHowLate,
                ),
              ),
            ],
          ),
          if (reported) ...[
            const SizedBox(height: 8),
            Text(
              'สถานะนี้ไม่ใช่การเช็คอิน — ทีมงานยังเป็นคนยืนยันตอนขึ้นรถ',
              style: appFont(
                fontSize: AppText.sizeCaption,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _statusLine => switch (_status) {
    'on_the_way' => 'กำลังไปจุดนัด',
    'arrived' => 'ถึงจุดนัดแล้ว',
    'late' => _etaMinutes != null
        ? 'อาจสายประมาณ $_etaMinutes นาที'
        : 'อาจมาสาย',
    _ => '',
  };

  Color _statusColor(BuildContext context) => switch (_status) {
    'arrived' => AppTheme.primaryColor,
    'late' => AppTheme.warningColor,
    _ => AppTheme.onSurface(context),
  };
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppTheme.primaryColor
        : AppTheme.mutedText(context);

    return Material(
      color: selected
          ? AppTheme.selectedTint(context)
          : AppTheme.background(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor.withValues(alpha: 0.45)
                  : AppTheme.border(context),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppTheme.primaryColor : AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
