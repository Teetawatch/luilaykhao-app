import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../providers/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/rally_card.dart';
import '../widgets/sos_button.dart';
import '../widgets/travel_widgets.dart';
import '../widgets/right_now_card.dart';
import '../widgets/trek_recorder_card.dart';
import '../widgets/trip_progress_card.dart';
import '../widgets/weather_card.dart';
import 'chat_screen.dart';
import 'pre_trip_checklist_screen.dart';
import 'schedule_itinerary_screen.dart';
import 'tracking_screen.dart' show TrackingMapPage;

/// "วันเดินทาง" — a single, focused day-of hub for one confirmed booking that
/// pulls together the things a traveller reaches for on the trip itself:
/// vehicle ETA, today's itinerary, group chat, the pre-trip checklist, the
/// departure weather, staff contacts, and an always-visible SOS. It composes
/// existing screens/widgets rather than duplicating them.
class TripDayScreen extends StatelessWidget {
  final Map<String, dynamic> booking;

  const TripDayScreen({super.key, required this.booking});

  Map<String, dynamic> get _schedule => asMap(booking['schedule']);
  Map<String, dynamic> get _trip => asMap(_schedule['trip']);
  int get _scheduleId => int.tryParse(textOf(_schedule['id'])) ?? 0;

  DateTime? get _departure {
    final raw = textOf(_schedule['departure_date']);
    return raw.isEmpty ? null : DateTime.tryParse(raw);
  }

  DateTime? get _return {
    final raw = textOf(_schedule['return_date']);
    return raw.isEmpty ? _departure : DateTime.tryParse(raw);
  }

  /// True from one day before departure through the return date — the window in
  /// which the emergency SOS is meaningful (mirrors the booking detail rule).
  bool get _withinTripWindow {
    final dep = _departure;
    if (dep == null) return false;
    final ret = _return ?? dep;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(dep.year, dep.month, dep.day)
        .subtract(const Duration(days: 1));
    final end = DateTime(ret.year, ret.month, ret.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        title: Text(
          'วันเดินทาง',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _CountdownHeader(
            tripTitle: textOf(_trip['title'], 'ทริปของคุณ'),
            departure: _departure,
            returnDate: _return,
          ),
          const SizedBox(height: 16),

          // "ตอนนี้ต้องทำอะไร" — บรรทัดเดียวที่ตอบคำถามของคนที่ยืนรอรถอยู่
          // ซ่อนตัวเองเมื่อยังไม่มีอะไรจะบอก
          if (_withinTripWindow &&
              textOf(booking['booking_ref']).isNotEmpty) ...[
            RightNowCard(bookingRef: textOf(booking['booking_ref'])),
            const SizedBox(height: 16),
          ],

          // SOS first while on/near the trip — it's the one action that must be
          // immediate rather than tucked behind a tile.
          if (_withinTripWindow && _scheduleId > 0) ...[
            SosButton(scheduleId: _scheduleId),
            const SizedBox(height: 16),
          ],

          // ชวนเพื่อนเติมรอบที่ยังไม่การันตีออกเดินทาง — ซ่อนตัวเองเมื่อรอบ
          // ครบแล้ว/ยังไกล/เต็มแล้ว
          if (_scheduleId > 0) ...[
            RallyCard(scheduleId: _scheduleId),
            const SizedBox(height: 16),
          ],

          // "ตอนนี้ถึงไหนแล้ว" — ซ่อนตัวเองเมื่อรอบยังไม่มีกำหนดการ
          // อ่านจากแคชได้เมื่อไม่มีสัญญาณ ซึ่งเป็นสถานการณ์ปกติบนดอย
          if (textOf(booking['booking_ref']).isNotEmpty) ...[
            TripProgressCard(bookingRef: textOf(booking['booking_ref'])),
            const SizedBox(height: 16),
          ],

          // บันทึกเส้นทางที่เดินเองด้วย GPS — เปิดเมื่ออยู่ในช่วงทริปเท่านั้น
          // เพราะไม่มีเหตุผลให้เปิด GPS ค้างก่อนถึงวันเดินทาง
          if (_withinTripWindow &&
              textOf(booking['booking_ref']).isNotEmpty) ...[
            TrekRecorderCard(bookingRef: textOf(booking['booking_ref'])),
            const SizedBox(height: 16),
          ],

          const _SectionLabel('สิ่งที่ต้องใช้วันนี้'),
          const SizedBox(height: 10),
          _TrackVehicleTile(booking: booking),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.route_rounded,
            color: const Color(0xFF2563EB),
            title: 'กำหนดการวันนี้',
            subtitle: 'ดูแผนการเดินทางและจุดแวะแต่ละช่วง',
            onTap: _scheduleId == 0
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduleItineraryScreen(
                          scheduleId: _scheduleId,
                          tripTitle: textOf(_trip['title']),
                        ),
                      ),
                    ),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.forum_rounded,
            color: const Color(0xFF7C3AED),
            title: 'แชทกลุ่มทริป',
            subtitle: 'คุยกับสตาฟและเพื่อนร่วมทริป',
            onTap: _scheduleId == 0
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          scheduleId: _scheduleId,
                          title: textOf(_trip['title']),
                        ),
                      ),
                    ),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.checklist_rounded,
            color: AppTheme.accentColor,
            title: 'เช็คลิสต์ก่อนเดินทาง',
            subtitle: 'ของที่ต้องเตรียมก่อนออกเดินทาง',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PreTripChecklistScreen.fromBooking(booking),
              ),
            ),
          ),

          // Departure-day weather, when the backend resolved a forecast.
          if (asMap(_schedule['weather']).isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionLabel('อากาศวันเดินทาง'),
            const SizedBox(height: 10),
            WeatherCard(weather: asMap(_schedule['weather']), compact: true),
          ],

          // Staff / guide contacts for the round.
          if (asList(booking['assigned_staff']).isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionLabel('ติดต่อสตาฟประจำรอบ'),
            const SizedBox(height: 10),
            ...asList(booking['assigned_staff']).map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StaffContactCard(staff: asMap(s)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountdownHeader extends StatelessWidget {
  final String tripTitle;
  final DateTime? departure;
  final DateTime? returnDate;

  const _CountdownHeader({
    required this.tripTitle,
    required this.departure,
    required this.returnDate,
  });

  ({String label, IconData icon}) _countdown() {
    final dep = departure;
    if (dep == null) return (label: 'วันเดินทางของคุณ', icon: Icons.event_rounded);
    final ret = returnDate ?? dep;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final depDay = DateTime(dep.year, dep.month, dep.day);
    final retDay = DateTime(ret.year, ret.month, ret.day);
    final days = depDay.difference(today).inDays;

    if (days > 1) {
      return (label: 'อีก $days วันจะถึงวันเดินทาง', icon: Icons.hourglass_top_rounded);
    }
    if (days == 1) {
      return (label: 'พรุ่งนี้เดินทางแล้ว!', icon: Icons.luggage_rounded);
    }
    if (!today.isBefore(depDay) && !today.isAfter(retDay)) {
      return (label: 'วันนี้คือวันเดินทาง 🎒', icon: Icons.directions_walk_rounded);
    }
    return (label: 'ทริปของคุณ', icon: Icons.event_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final cd = _countdown();
    final dateLabel = _dateRange();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cd.icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cd.label,
                  style: appFont(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tripTitle,
            style: appFont(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.event_rounded,
                  color: Colors.white70,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  dateLabel,
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _dateRange() {
    final dep = departure;
    if (dep == null) return '';
    final ret = returnDate;
    if (ret == null || _sameDay(dep, ret)) return thaiDateShort(dep);
    return '${DateFormat('d MMM', 'th_TH').format(dep)} - ${thaiDateShort(ret)}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedText(context),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: appFont(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: appFont(
                          fontSize: 12.5,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.mutedText(context),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vehicle ETA / live tracking tile. Boots the tracking session for the booking
/// (same flow as the bookings list) and opens the live map.
class _TrackVehicleTile extends StatefulWidget {
  final Map<String, dynamic> booking;
  const _TrackVehicleTile({required this.booking});

  @override
  State<_TrackVehicleTile> createState() => _TrackVehicleTileState();
}

class _TrackVehicleTileState extends State<_TrackVehicleTile> {
  bool _loading = false;

  Future<void> _open() async {
    final ref = textOf(widget.booking['booking_ref']);
    if (ref.isEmpty || _loading) return;

    final app = context.read<AppProvider>();
    final provider = context.read<TrackingProvider>();

    setState(() => _loading = true);
    provider.stopTracking();
    await provider.startTracking(ref, authToken: app.token);
    if (!mounted) return;
    setState(() => _loading = false);

    if (provider.errorMessage.isNotEmpty || provider.booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage.isNotEmpty
                ? provider.errorMessage
                : 'ยังไม่มีข้อมูลติดตามรถสำหรับรอบนี้',
            style: appFont(fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrackingMapPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      icon: Icons.directions_bus_rounded,
      color: const Color(0xFFEA580C),
      title: 'ติดตามรถ & เวลาถึง (ETA)',
      subtitle: 'ดูตำแหน่งรถแบบเรียลไทม์และเวลาถึงจุดรับ',
      onTap: _loading ? null : _open,
      trailing: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}

class _StaffContactCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  const _StaffContactCard({required this.staff});

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = textOf(staff['nickname']).isNotEmpty
        ? textOf(staff['nickname'])
        : textOf(staff['name'], 'สตาฟ');
    final role = textOf(staff['role']);
    final phone = textOf(staff['phone']).trim();
    final avatar = ApiConfig.mediaUrl(staff['avatar_url']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            backgroundImage:
                avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
            child: avatar.isEmpty
                ? const Icon(Icons.badge_rounded, color: AppTheme.primaryColor)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: appFont(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    role,
                    style: appFont(
                      fontSize: 12.5,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (phone.isNotEmpty)
            IconButton(
              onPressed: () => _call(phone),
              tooltip: 'โทรหา $name',
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_rounded,
                  color: AppTheme.accentColor,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
