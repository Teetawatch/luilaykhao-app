import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'travel_widgets.dart' show asList, asMap, textOf;

/// ความคืบหน้าระหว่างทริป — "ตอนนี้ถึงไหนแล้ว"
///
/// ข้อมูลมาจากกำหนดการที่ทีมงานกดยืนยันว่าถึงแล้ว ไม่ได้ใช้ GPS ของลูกค้า
/// จึงไม่กินแบตและไม่ต้องขอสิทธิ์ตำแหน่ง
///
/// แคชคำตอบล่าสุดไว้เสมอ เพราะหน้านี้ถูกเปิดตอนอยู่บนดอยที่มักไม่มีสัญญาณ —
/// เห็นข้อมูลเก่าพร้อมป้ายบอกเวลา ดีกว่าเห็นจอเปล่า
class TripProgressCard extends StatefulWidget {
  final String bookingRef;

  const TripProgressCard({super.key, required this.bookingRef});

  @override
  State<TripProgressCard> createState() => _TripProgressCardState();
}

class _TripProgressCardState extends State<TripProgressCard> {
  Map<String, dynamic>? _progress;
  DateTime? _fetchedAt;
  bool _loading = true;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();

    // อ่านแคชขึ้นมาก่อน ให้มีอะไรแสดงทันทีแม้เน็ตจะไม่มา
    final cached = app.cachedTripProgress(widget.bookingRef);
    if (cached != null && mounted) {
      setState(() {
        _progress = asMap(cached['progress']);
        _fetchedAt = DateTime.tryParse(textOf(cached['cached_at']));
        _fromCache = true;
        _loading = false;
      });
    }

    try {
      final data = await app.tripProgress(widget.bookingRef);
      if (!mounted) return;
      setState(() {
        _progress = asMap(data['progress']);
        _fetchedAt = DateTime.now();
        _fromCache = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // ออฟไลน์ + ไม่มีแคช = ซ่อนไปเลย ไม่ต้องขึ้น error ให้กังวลเปล่า ๆ
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final progress = _progress;
    if (progress == null || progress['has_itinerary'] != true) {
      return const SizedBox.shrink();
    }

    final items = asList(progress['items']);
    if (items.isEmpty) return const SizedBox.shrink();

    final reached = int.tryParse(textOf(progress['reached_count'])) ?? 0;
    final total = int.tryParse(textOf(progress['total'])) ?? items.length;
    final percent = (int.tryParse(textOf(progress['percent'])) ?? 0).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hiking_rounded,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ตอนนี้ถึงไหนแล้ว',
                  style: appFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              Text(
                '$reached/$total',
                style: appFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 7,
              backgroundColor:
                  AppTheme.mutedText(context).withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((raw) => _MilestoneRow(item: asMap(raw))),
          if (_fetchedAt != null && _fromCache) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 13,
                  color: AppTheme.mutedText(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ข้อมูลออฟไลน์ • อัปเดตล่าสุด ${_relativeTime(_fetchedAt!)}',
                    style: appFont(
                      fontSize: 11,
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
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
    return '${diff.inDays} วันที่แล้ว';
  }
}

/// หนึ่งหมุดในกำหนดการ พร้อมเส้นเชื่อมแบบ timeline
class _MilestoneRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _MilestoneRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final reached = item['reached'] == true;
    final isCurrent = item['is_current'] == true;
    final time = textOf(item['time']);

    final color = isCurrent
        ? AppTheme.primaryColor
        : reached
            ? AppTheme.primaryColor.withValues(alpha: 0.55)
            : AppTheme.mutedText(context).withValues(alpha: 0.45);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                isCurrent
                    ? Icons.radio_button_checked_rounded
                    : reached
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                size: 18,
                color: color,
              ),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: reached
                      ? AppTheme.primaryColor.withValues(alpha: 0.35)
                      : AppTheme.mutedText(context).withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textOf(item['title']),
                    style: appFont(
                      fontSize: 13.5,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      color: reached || isCurrent
                          ? AppTheme.onSurface(context)
                          : AppTheme.mutedText(context),
                    ),
                  ),
                  if (time.isNotEmpty || isCurrent) ...[
                    const SizedBox(height: 2),
                    Text(
                      isCurrent ? '$time • อยู่ที่นี่' : time,
                      style: appFont(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isCurrent
                            ? AppTheme.primaryColor
                            : AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
