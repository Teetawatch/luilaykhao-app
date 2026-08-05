import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/trip_day_pack.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';

/// สถานะชุดข้อมูลออฟไลน์ของรอบนี้ บนหน้า "วันเดินทาง"
///
/// แอปเตรียมของให้เองอยู่แล้วตั้งแต่ 2 วันก่อนเดินทาง (ดู [TripDayPack]) การ์ดนี้
/// ทำสองอย่าง: บอกว่ามีของติดเครื่องแล้วจริง ๆ ณ เวลาไหน — คนที่กำลังจะขึ้นดอย
/// อยากรู้ก่อนออกจากที่มีสัญญาณ — และให้กดสั่งเก็บใหม่เองได้ก่อนออกเดินทาง
class OfflinePackCard extends StatefulWidget {
  final Map<String, dynamic> booking;

  const OfflinePackCard({super.key, required this.booking});

  @override
  State<OfflinePackCard> createState() => _OfflinePackCardState();
}

class _OfflinePackCardState extends State<OfflinePackCard> {
  bool _saving = false;
  DateTime? _savedAt;

  int get _scheduleId {
    final schedule = widget.booking['schedule'];
    if (schedule is! Map) return 0;
    return int.tryParse('${schedule['id']}') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _savedAt = TripDayPack.savedAt(_scheduleId);
  }

  Future<void> _save() async {
    if (_saving) return;
    HapticFeedback.selectionClick();
    setState(() => _saving = true);

    final ok = await TripDayPack.packOne(
      context.read<AppProvider>(),
      widget.booking,
    );
    if (!mounted) return;

    setState(() {
      _saving = false;
      if (ok) _savedAt = TripDayPack.savedAt(_scheduleId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'เก็บข้อมูลทริปไว้ในเครื่องแล้ว เปิดดูได้แม้ไม่มีสัญญาณ'
              : 'ยังเก็บไม่สำเร็จ — ลองอีกครั้งตอนสัญญาณกลับมาครับ',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_scheduleId <= 0) return const SizedBox.shrink();

    final savedAt = _savedAt;
    final ready = savedAt != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready
                    ? Icons.offline_pin_rounded
                    : Icons.cloud_download_outlined,
                size: 20,
                color: ready
                    ? AppTheme.primaryColor
                    : AppTheme.mutedText(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ready ? 'พร้อมใช้ตอนไม่มีสัญญาณ' : 'เก็บข้อมูลไว้ใช้ออฟไลน์',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ready
                ? 'กำหนดการ ประกาศ จุดขึ้นรถ และเบอร์สตาฟ ถูกเก็บไว้ในเครื่องแล้ว '
                      'เมื่อ ${thaiDateTimeShort(savedAt)}'
                : 'เก็บกำหนดการ ประกาศ จุดขึ้นรถ และเบอร์สตาฟไว้ในเครื่อง '
                      'เผื่อขึ้นไปแล้วไม่มีสัญญาณ',
            style: appFont(
              fontSize: AppText.sizeLabel,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(
                _saving
                    ? 'กำลังเก็บ...'
                    : ready
                    ? 'อัปเดตข้อมูลที่เก็บไว้'
                    : 'เก็บไว้ตอนนี้',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
