import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'travel_widgets.dart' show textOf;

/// "ช่วยกันเปิดรอบ" — ชวนคนที่จองแล้วให้หาเพื่อนมาเติมรอบที่ยังไม่การันตี
///
/// แสดงเฉพาะรอบที่ยังไม่ถึงเกณฑ์ออกเดินทางและใกล้ถึงวันจริง เพราะคนที่จองไปแล้ว
/// คือคนที่อยากให้รอบออกมากที่สุด — ถ้าไม่ครบ ทริปของเขาเองจะถูกยกเลิก
class RallyCard extends StatefulWidget {
  final int scheduleId;

  const RallyCard({super.key, required this.scheduleId});

  @override
  State<RallyCard> createState() => _RallyCardState();
}

class _RallyCardState extends State<RallyCard> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().scheduleRally(
            widget.scheduleId,
          );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      // ไม่มีสิทธิ์/ออฟไลน์ = ซ่อนไปเงียบ ๆ ไม่ใช่เรื่องที่ต้องแจ้งผู้ใช้
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    final message = textOf(_data?['share_message'], textOf(_data?['share_url']));
    if (message.isEmpty) return;

    HapticFeedback.selectionClick();
    try {
      await SharePlus.instance.share(
        ShareParams(text: message, subject: 'ชวนเพื่อนมาเที่ยวด้วยกัน'),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คัดลอกข้อความชวนเพื่อนแล้ว')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final data = _data;
    if (data == null || data['active'] != true) return const SizedBox.shrink();

    final seatsNeeded = int.tryParse(textOf(data['seats_needed'])) ?? 0;
    final booked = int.tryParse(textOf(data['booked_seats'])) ?? 0;
    final target = int.tryParse(textOf(data['guarantee_min_seats'])) ?? 8;
    final daysLeft = int.tryParse(textOf(data['days_left'])) ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_rounded,
                size: 20,
                color: AppTheme.warningColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ช่วยกันเปิดรอบนี้',
                  style: appFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              if (daysLeft > 0)
                Text(
                  'เหลือ $daysLeft วัน',
                  style: appFont(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warningColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            textOf(data['headline']),
            style: appFont(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          // แถบความคืบหน้าเทียบกับจำนวนที่การันตีออกเดินทาง
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: target > 0 ? (booked / target).clamp(0.0, 1.0) : 0,
                    minHeight: 7,
                    backgroundColor:
                        AppTheme.mutedText(context).withValues(alpha: 0.12),
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.warningColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$booked/$target',
                style: appFont(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(
                seatsNeeded == 1 ? 'ชวนเพื่อนอีก 1 คน' : 'ชวนเพื่อนอีก $seatsNeeded คน',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
