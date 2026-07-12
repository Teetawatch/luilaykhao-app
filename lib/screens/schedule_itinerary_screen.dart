import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// กำหนดการรอบเดินทาง (itinerary) — สตาฟอ่านอย่างเดียวเพื่อเตรียมตัว/รู้ช่วงเวลา
/// แอดมินเป็นผู้สร้างข้อมูลจาก admin panel ส่วนหน้านี้แสดงเป็น timeline กรุ๊ปตามวัน
/// (วันที่ 1 / วันที่ 2 …) แต่ละรายการมีเวลา + หัวข้อ + รายละเอียด เรียงตามที่
/// backend ส่งมา (วัน → เวลา → ลำดับ)
class ScheduleItineraryScreen extends StatefulWidget {
  final int scheduleId;
  final String tripTitle;

  const ScheduleItineraryScreen({
    super.key,
    required this.scheduleId,
    this.tripTitle = '',
  });

  @override
  State<ScheduleItineraryScreen> createState() =>
      _ScheduleItineraryScreenState();
}

class _ScheduleItineraryScreenState extends State<ScheduleItineraryScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  int? _togglingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    try {
      final list = await app.scheduleItinerary(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// เช็คอิน/ยกเลิกเช็คอินจุดกำหนดการ — อัปเดต state ในเครื่องจากผลที่ backend ส่งกลับ
  Future<void> _toggleReached(Map<String, dynamic> item) async {
    final id = item['id'] as int?;
    if (id == null || _togglingId != null) return;
    final currentlyReached = (item['reached_at'] as String?) != null;

    HapticFeedback.selectionClick();
    setState(() => _togglingId = id);
    try {
      final updated = await context.read<AppProvider>().markItineraryReached(
        widget.scheduleId,
        id,
        reached: !currentlyReached,
      );
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((e) => e['id'] == id);
        if (idx != -1) _items[idx] = {..._items[idx], ...updated};
        _togglingId = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _togglingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกไม่สำเร็จ ลองอีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'กำหนดการเดินทาง',
              style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (widget.tripTitle.isNotEmpty)
              Text(
                widget.tripTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
          ],
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return const _MessageState(
        icon: Icons.wifi_off_rounded,
        title: 'โหลดกำหนดการไม่สำเร็จ',
        subtitle: 'ลองดึงหน้าจอลงเพื่อรีเฟรชอีกครั้ง',
      );
    }
    if (_items.isEmpty) {
      return const _MessageState(
        icon: Icons.event_note_outlined,
        title: 'ยังไม่มีกำหนดการ',
        subtitle: 'เมื่อทีมงานจัดทำกำหนดการของรอบนี้ จะแสดงที่นี่ให้คุณเตรียมตัว',
      );
    }

    // กรุ๊ปตามวันที่ (รายการที่ไม่ระบุวันรวมไว้กลุ่มเดียว "ไม่ระบุวัน")
    final groups = <String?, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final date = (item['item_date'] as String?)?.trim();
      final key = (date == null || date.isEmpty) ? null : date;
      (groups[key] ??= []).add(item);
    }
    final keys = groups.keys.toList();

    final reachedCount =
        _items.where((e) => (e['reached_at'] as String?) != null).length;
    // จุดถัดไป = รายการแรก (ตามลำดับแสดงผล) ที่ยังไม่เช็คอิน
    final next = _items.cast<Map<String, dynamic>?>().firstWhere(
      (e) => (e!['reached_at'] as String?) == null,
      orElse: () => null,
    );
    final nextId = next?['id'] as int?;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _ProgressHeader(
          reached: reachedCount,
          total: _items.length,
          nextTitle: next?['title'] as String?,
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < keys.length; i++) ...[
          _DayHeader(dateIso: keys[i], dayNumber: keys[i] == null ? null : i + 1),
          const SizedBox(height: 10),
          _DayTimeline(
            items: groups[keys[i]]!,
            nextId: nextId,
            togglingId: _togglingId,
            onToggle: _toggleReached,
          ),
          if (i < keys.length - 1) const SizedBox(height: 18),
        ],
      ],
    );
  }
}

/// สรุปความคืบหน้าเช็คอิน + บอกจุดถัดไป — ช่วยสตาฟไม่ลืม/ไม่ผิดแผน
class _ProgressHeader extends StatelessWidget {
  final int reached;
  final int total;
  final String? nextTitle;

  const _ProgressHeader({
    required this.reached,
    required this.total,
    this.nextTitle,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = total > 0 && reached >= total;
    final progress = total == 0 ? 0.0 : reached / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context).withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allDone
                    ? Icons.verified_rounded
                    : Icons.route_rounded,
                size: 20,
                color: allDone ? const Color(0xFF16A34A) : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'เช็คอินแล้ว $reached/$total จุด',
                style: appFont(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppTheme.border(context).withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation(
                allDone ? const Color(0xFF16A34A) : AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                allDone ? Icons.celebration_rounded : Icons.arrow_forward_rounded,
                size: 15,
                color: AppTheme.mutedText(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  allDone
                      ? 'เช็คอินครบทุกจุดแล้ว เยี่ยมมาก!'
                      : 'จุดถัดไป: ${nextTitle ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
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

/// หัวข้อของแต่ละวัน — "วันที่ 1 · 22 มิ.ย. 2569" (หรือ "ไม่ระบุวัน")
class _DayHeader extends StatelessWidget {
  final String? dateIso;
  final int? dayNumber;

  const _DayHeader({required this.dateIso, this.dayNumber});

  @override
  Widget build(BuildContext context) {
    final dateText = _formatThaiDate(dateIso);
    final label = dayNumber != null ? 'วันที่ $dayNumber' : 'ไม่ระบุวัน';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: appFont(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
              letterSpacing: -0.1,
            ),
          ),
        ),
        if (dateText.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dateText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Timeline ของรายการภายในหนึ่งวัน — เส้นต่อแนวตั้ง + จุด, badge เวลา, หัวข้อ +
/// รายละเอียด
class _DayTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int? nextId;
  final int? togglingId;
  final Future<void> Function(Map<String, dynamic>) onToggle;

  const _DayTimeline({
    required this.items,
    required this.nextId,
    required this.togglingId,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _TimelineRow(
            item: items[i],
            isFirst: i == 0,
            isLast: i == items.length - 1,
            isNext: items[i]['id'] == nextId,
            isToggling: items[i]['id'] == togglingId,
            onToggle: onToggle,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isFirst;
  final bool isLast;
  final bool isNext;
  final bool isToggling;
  final Future<void> Function(Map<String, dynamic>) onToggle;

  const _TimelineRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.isNext,
    required this.isToggling,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final time = (item['time'] as String?)?.trim() ?? '';
    final title = (item['title'] as String?)?.trim() ?? '';
    final detail = (item['detail'] as String?)?.trim() ?? '';
    final link = (item['link'] as String?)?.trim() ?? '';
    final reachedAt = (item['reached_at'] as String?)?.trim() ?? '';
    final reachedBy = (item['reached_by_name'] as String?)?.trim() ?? '';
    final reached = reachedAt.isNotEmpty;
    final lineColor = AppTheme.border(context).withValues(alpha: 0.8);

    const green = Color(0xFF16A34A);
    final dotColor = reached
        ? green
        : (isNext ? AppTheme.primaryColor : AppTheme.surface(context));
    final dotBorder = reached
        ? green
        : (isNext ? AppTheme.primaryColor : AppTheme.border(context));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // เส้น timeline + จุด (เช็คอินแล้ว = เขียวพร้อมเครื่องหมายถูก)
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 6,
                  color: isFirst ? Colors.transparent : lineColor,
                ),
                Container(
                  width: reached || isNext ? 18 : 14,
                  height: reached || isNext ? 18 : 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotBorder, width: 2.5),
                  ),
                  child: reached
                      ? const Icon(Icons.check_rounded,
                          size: 11, color: Colors.white)
                      : null,
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : lineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // เนื้อหา
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: reached
                      ? green.withValues(alpha: 0.05)
                      : AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isNext
                        ? AppTheme.primaryColor.withValues(alpha: 0.55)
                        : (reached
                              ? green.withValues(alpha: 0.30)
                              : AppTheme.border(context).withValues(alpha: 0.55)),
                    width: isNext ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (time.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  time,
                                  style: appFont(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryColor,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        if (isNext && !reached)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'จุดถัดไป',
                              style: appFont(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (time.isNotEmpty || (isNext && !reached))
                      const SizedBox(height: 8),
                    Text(
                      title.isEmpty ? 'ไม่ระบุหัวข้อ' : title,
                      style: appFont(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: AppTheme.onSurface(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        detail,
                        style: appFont(
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onSurface(
                            context,
                          ).withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                    if (link.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _ItineraryLinkButton(link: link),
                    ],
                    const SizedBox(height: 12),
                    _CheckInButton(
                      reached: reached,
                      reachedAt: reachedAt,
                      reachedBy: reachedBy,
                      loading: isToggling,
                      onTap: () => onToggle(item),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ปุ่มเช็คอิน/สถานะ "มาถึงแล้ว" ของแต่ละจุด
class _CheckInButton extends StatelessWidget {
  final bool reached;
  final String reachedAt;
  final String reachedBy;
  final bool loading;
  final VoidCallback onTap;

  const _CheckInButton({
    required this.reached,
    required this.reachedAt,
    required this.reachedBy,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);

    if (reached) {
      final at = _formatTime(reachedAt);
      final who = reachedBy.isNotEmpty ? ' · โดย $reachedBy' : '';
      return Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 17, color: green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'มาถึงแล้ว${at.isNotEmpty ? ' · $at' : ''}$who',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: loading ? null : onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'ยกเลิก',
                    style: appFont(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: loading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.where_to_vote_rounded, size: 18),
        label: Text(
          'เช็คอินจุดนี้',
          style: appFont(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m น.';
  }
}

/// ปุ่มเปิดลิงก์แนบของรายการ (เช่น Google Maps) — เปิดด้วยแอปภายนอก
class _ItineraryLinkButton extends StatelessWidget {
  final String link;

  const _ItineraryLinkButton({required this.link});

  bool get _isMap {
    final l = link.toLowerCase();
    return l.contains('google.com/maps') ||
        l.contains('maps.app.goo.gl') ||
        l.contains('goo.gl/maps') ||
        l.contains('maps.google');
  }

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    final ok = await canLaunchUrl(uri);
    if (ok) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิดลิงก์ไม่สำเร็จ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMap = _isMap;
    final color = isMap ? const Color(0xFF2563EB) : AppTheme.primaryColor;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMap ? Icons.map_outlined : Icons.link_rounded,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  isMap ? 'เปิดแผนที่' : 'เปิดลิงก์',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // ListView so RefreshIndicator can still be pulled when empty.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Icon(icon, size: 52, color: AppTheme.mutedText(context)),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: appFont(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface(context),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// แปลง ISO date → "22 มิ.ย. 2569" (พ.ศ.) — รูปแบบเดียวกับหน้าสตาฟ
String _formatThaiDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  const months = [
    '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];
  return '${date.day} ${months[date.month]} ${date.year + 543}';
}
