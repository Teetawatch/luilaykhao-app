import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// ประกาศทางการจากผู้จัดต่อรอบเดินทาง — เปลี่ยนจุดนัดพบ / เลื่อนเวลา / ของที่ต้อง
/// เตรียม ฯลฯ ออกแบบสะอาดตามแนวทาง Apple: การ์ดมี SF-symbol-style glyph ในกล่อง
/// สีตามหมวด, ปักหมุดลอยขึ้นบนสุด, แสดงเวลาแบบสัมพัทธ์ และเปิดมาแล้วทำเครื่องหมาย
/// อ่านอัตโนมัติ พร้อมรับประกาศใหม่แบบเรียลไทม์ขณะเปิดหน้าอยู่
class ScheduleAnnouncementsScreen extends StatefulWidget {
  final int scheduleId;
  final String tripTitle;

  const ScheduleAnnouncementsScreen({
    super.key,
    required this.scheduleId,
    this.tripTitle = '',
  });

  @override
  State<ScheduleAnnouncementsScreen> createState() =>
      _ScheduleAnnouncementsScreenState();
}

class _ScheduleAnnouncementsScreenState
    extends State<ScheduleAnnouncementsScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  VoidCallback? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  Future<void> _subscribe() async {
    final app = context.read<AppProvider>();
    _unsubscribe = await app.subscribeAnnouncements(widget.scheduleId, (data) {
      if (!mounted) return;
      final incoming = Map<String, dynamic>.from(data);
      // กันซ้ำกับที่มีอยู่ แล้วจัดเรียงปักหมุดขึ้นก่อน / ใหม่สุดอยู่บน
      final id = incoming['id'];
      final next = [
        incoming,
        ..._items.where((a) => a['id'] != id),
      ]..sort(_sort);
      setState(() => _items = next);
      app.markAnnouncementsRead(widget.scheduleId);
    });
  }

  int _sort(Map<String, dynamic> a, Map<String, dynamic> b) {
    final pa = a['is_pinned'] == true ? 1 : 0;
    final pb = b['is_pinned'] == true ? 1 : 0;
    if (pa != pb) return pb - pa;
    return '${b['id']}'.compareTo('${a['id']}'); // newer id first
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    try {
      final data = await app.scheduleAnnouncements(widget.scheduleId);
      final list = (data['announcements'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
      // เปิดอ่านแล้ว → เคลียร์ unread ฝั่ง server
      app.markAnnouncementsRead(widget.scheduleId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
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
              'ประกาศจากผู้จัด',
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
        title: 'โหลดประกาศไม่สำเร็จ',
        subtitle: 'ลองดึงหน้าจอลงเพื่อรีเฟรชอีกครั้ง',
      );
    }
    if (_items.isEmpty) {
      return const _MessageState(
        icon: Icons.campaign_outlined,
        title: 'ยังไม่มีประกาศ',
        subtitle: 'เมื่อทีมงานมีอัปเดตของรอบนี้ จะแสดงที่นี่และแจ้งเตือนคุณ',
      );
    }

    final pinned = _items.where((a) => a['is_pinned'] == true).toList();
    final rest = _items.where((a) => a['is_pinned'] != true).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (pinned.isNotEmpty) ...[
          const _SectionHeader(icon: Icons.push_pin_rounded, label: 'ปักหมุด'),
          const SizedBox(height: 8),
          for (final a in pinned) ...[
            _AnnouncementCard(data: a),
            const SizedBox(height: 10),
          ],
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 8),
            const _SectionHeader(
              icon: Icons.campaign_rounded,
              label: 'ทั้งหมด',
            ),
            const SizedBox(height: 8),
          ],
        ],
        for (final a in rest) ...[
          _AnnouncementCard(data: a),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ─── Category styling (Apple system palette) ──────────────────────────────────

class _CategoryStyle {
  final IconData icon;
  final Color color;
  final String label;
  const _CategoryStyle(this.icon, this.color, this.label);
}

_CategoryStyle _styleFor(String category) {
  switch (category) {
    case 'meeting_point':
      return const _CategoryStyle(
        Icons.location_on_rounded,
        Color(0xFF5856D6), // systemIndigo
        'จุดนัดพบ',
      );
    case 'schedule_change':
      return const _CategoryStyle(
        Icons.schedule_rounded,
        Color(0xFFFF9500), // systemOrange
        'เปลี่ยนเวลา',
      );
    case 'packing':
      return const _CategoryStyle(
        Icons.backpack_rounded,
        Color(0xFF34C759), // systemGreen
        'ของที่ต้องเตรียม',
      );
    case 'weather':
      return const _CategoryStyle(
        Icons.cloud_rounded,
        Color(0xFF32ADE6), // systemCyan
        'สภาพอากาศ',
      );
    case 'urgent':
      return const _CategoryStyle(
        Icons.priority_high_rounded,
        Color(0xFFFF3B30), // systemRed
        'ด่วน',
      );
    default:
      return const _CategoryStyle(
        Icons.campaign_rounded,
        Color(0xFF007AFF), // systemBlue
        'ประกาศ',
      );
  }
}

// ─── Announcement card ────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AnnouncementCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final category = (data['category'] ?? 'general').toString();
    final style = _styleFor(category);
    final title = (data['title'] ?? '').toString();
    final body = (data['body'] ?? '').toString();
    final author = (data['author_name'] ?? 'ทีมงาน').toString();
    final pinned = data['is_pinned'] == true;
    final when = _relativeTime(data['created_at']?.toString());
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: pinned
              ? style.color.withValues(alpha: 0.45)
              : AppTheme.border(context).withValues(alpha: 0.5),
          width: pinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category glyph tile (SF-symbol style)
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(style.icon, size: 20, color: style.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          style.label,
                          style: appFont(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: style.color,
                          ),
                        ),
                        if (pinned) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.push_pin_rounded,
                            size: 12,
                            color: style.color,
                          ),
                        ],
                        const Spacer(),
                        if (when.isNotEmpty)
                          Text(
                            when,
                            style: appFont(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: appFont(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              body,
              style: appFont(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurface(context).withValues(alpha: 0.82),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 14,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 5),
              Text(
                author,
                style: appFont(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Small pieces ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 6),
        Text(
          label,
          style: appFont(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: muted,
          ),
        ),
      ],
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

/// เวลาแบบสัมพัทธ์ภาษาไทย — "เมื่อสักครู่ / N นาที / N ชม. / N วัน" ที่แล้ว,
/// เกิน 7 วันแสดงเป็นวันที่จริง
String _relativeTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'เมื่อสักครู่';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
  if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
  return DateFormat('d MMM yyyy', 'th_TH').format(t);
}
