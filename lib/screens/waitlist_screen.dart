import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';
import 'trip_detail_screen.dart';

/// "คิวรอที่นั่ง" — the customer-facing surface for the waitlist the backend
/// already manages. Shows every active (waiting/offered) entry, the queue
/// position while waiting, and a live countdown + book CTA once a seat is
/// offered (offers expire after 15 minutes server-side).
class WaitlistScreen extends StatefulWidget {
  const WaitlistScreen({super.key});

  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _entries = const [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await context.read<AppProvider>().myWaitlistEntries();
      final entries = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      // Anchor each offer's countdown to a device-local deadline derived from
      // the server's RELATIVE expires_in_seconds, so it stays immune to
      // device/server clock skew (same approach as the seat-lock overlay).
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final entry in entries) {
        final secs = int.tryParse('${entry['expires_in_seconds'] ?? ''}');
        if (secs != null && secs > 0) {
          entry['_deadline_ms'] = nowMs + secs * 1000;
        }
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _error = null;
      });
      _syncTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'โหลดคิวรอที่นั่งไม่สำเร็จ';
      });
    }
  }

  /// Run a 1-second ticker only while there is at least one live offer to
  /// count down; otherwise leave it stopped to avoid needless rebuilds.
  void _syncTicker() {
    final hasLiveOffer = _entries.any(
      (e) => e['status'] == 'offered' && _remainingSeconds(e) > 0,
    );
    if (hasLiveOffer && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!hasLiveOffer) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  int _remainingSeconds(Map<String, dynamic> entry) {
    final deadline = entry['_deadline_ms'];
    if (deadline is! int) return 0;
    final diff = deadline - DateTime.now().millisecondsSinceEpoch;
    return diff > 0 ? (diff / 1000).ceil() : 0;
  }

  Future<void> _leave(Map<String, dynamic> entry) async {
    final scheduleId = int.tryParse('${entry['schedule_id']}') ?? 0;
    if (scheduleId == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ออกจากคิวรอ?',
          style: appFont(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'คุณจะเสียลำดับคิวปัจจุบัน หากต้องการกลับเข้าคิวภายหลังจะต้องเริ่มต่อท้ายใหม่',
          style: appFont(fontSize: 14, color: AppTheme.mutedText(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยกเลิก', style: appFont(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'ออกจากคิว',
              style: appFont(
                fontWeight: FontWeight.w800,
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    try {
      await context.read<AppProvider>().leaveWaitlist(scheduleId);
      if (!mounted) return;
      setState(() {
        _entries = _entries
            .where((e) => '${e['schedule_id']}' != '$scheduleId')
            .toList();
      });
      _syncTicker();
      _toast('ออกจากคิวรอแล้ว');
    } catch (e) {
      if (!mounted) return;
      _toast(e is ApiException ? e.message : 'ออกจากคิวไม่สำเร็จ');
    }
  }

  Future<void> _book(Map<String, dynamic> entry) async {
    final schedule = asMap(entry['schedule']);
    final trip = asMap(schedule['trip']);
    final slug = '${trip['slug'] ?? ''}'.trim();
    if (slug.isEmpty) return;

    final scheduleId = int.tryParse('${entry['schedule_id']}') ?? 0;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(
          slug: slug,
          initialScheduleId: scheduleId > 0 ? scheduleId : null,
        ),
      ),
    );
    if (mounted) _load();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: appFont(color: Colors.white))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        title: Text(
          'คิวรอที่นั่ง',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'เกิดข้อผิดพลาด',
            body: _error!,
          ),
        ],
      );
    }
    if (_entries.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.hourglass_empty_rounded,
            title: 'ยังไม่มีคิวรอ',
            body: 'เมื่อทริปที่คุณสนใจเต็ม กด"ลงทะเบียนรอที่นั่งว่าง" '
                'เราจะแจ้งเตือนทันทีที่มีที่นั่งว่าง',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _WaitlistCard(
          entry: entry,
          remainingSeconds: _remainingSeconds(entry),
          onLeave: () => _leave(entry),
          onBook: () => _book(entry),
        );
      },
    );
  }
}

class _WaitlistCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int remainingSeconds;
  final VoidCallback onLeave;
  final VoidCallback onBook;

  const _WaitlistCard({
    required this.entry,
    required this.remainingSeconds,
    required this.onLeave,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(entry['schedule']);
    final trip = asMap(schedule['trip']);
    final status = '${entry['status']}';
    final isOffered = status == 'offered';
    final seatCount = int.tryParse('${entry['seat_count'] ?? 1}') ?? 1;
    final position = int.tryParse('${entry['position'] ?? 0}') ?? 0;
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final dateLabel = _dateLabel(schedule['departure_date']);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOffered
              ? AppTheme.accentColor.withValues(alpha: 0.5)
              : AppTheme.border(context),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (image.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: image,
                  width: 92,
                  height: 104,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: 92,
                    color: AppTheme.subtleSurface(context),
                    child: const Icon(Icons.landscape_rounded),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${trip['title'] ?? 'ทริป'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _WaitlistStatusChip(status: status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _MetaRow(
                        icon: Icons.event_rounded,
                        text: dateLabel.isEmpty ? '-' : dateLabel,
                      ),
                      const SizedBox(height: 4),
                      _MetaRow(
                        icon: Icons.event_seat_rounded,
                        text: 'รอ $seatCount ที่นั่ง',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // ── status footer ──────────────────────────────────────────────
          if (isOffered)
            _OfferFooter(
              remainingSeconds: remainingSeconds,
              onBook: onBook,
              onLeave: onLeave,
            )
          else
            _WaitingFooter(position: position, onLeave: onLeave),
        ],
      ),
    );
  }

  String _dateLabel(dynamic raw) {
    final value = '${raw ?? ''}';
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('d MMM yyyy', 'th_TH').format(parsed);
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.mutedText(context)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appFont(fontSize: 12.5, color: AppTheme.mutedText(context)),
          ),
        ),
      ],
    );
  }
}

class _WaitingFooter extends StatelessWidget {
  final int position;
  final VoidCallback onLeave;

  const _WaitingFooter({required this.position, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: Row(
        children: [
          Icon(
            Icons.format_list_numbered_rounded,
            size: 16,
            color: AppTheme.mutedText(context),
          ),
          const SizedBox(width: 6),
          Text(
            position > 0 ? 'คิวที่ $position ในรายการรอ' : 'อยู่ในคิวรอ',
            style: appFont(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onLeave,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.mutedText(context),
            ),
            child: Text(
              'ออกจากคิว',
              style: appFont(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferFooter extends StatelessWidget {
  final int remainingSeconds;
  final VoidCallback onBook;
  final VoidCallback onLeave;

  const _OfferFooter({
    required this.remainingSeconds,
    required this.onBook,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final expired = remainingSeconds <= 0;
    final mm = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (remainingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.08),
        border: Border(
          top: BorderSide(
            color: AppTheme.accentColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                expired
                    ? Icons.timer_off_rounded
                    : Icons.celebration_rounded,
                size: 18,
                color: expired
                    ? AppTheme.mutedText(context)
                    : AppTheme.accentColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  expired
                      ? 'สิทธิ์การจองหมดเวลาแล้ว'
                      : 'มีที่นั่งว่างแล้ว! จองภายใน $mm:$ss',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: expired
                        ? AppTheme.mutedText(context)
                        : AppTheme.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: expired ? null : onBook,
                  icon: const Icon(Icons.hiking_rounded, size: 18),
                  label: Text(
                    'จองเลย',
                    style: appFont(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onLeave,
                tooltip: 'ออกจากคิว',
                icon: Icon(
                  Icons.close_rounded,
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

class _WaitlistStatusChip extends StatelessWidget {
  final String status;

  const _WaitlistStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'offered' => ('มีที่นั่งว่าง', AppTheme.accentColor),
      'waiting' => ('กำลังรอคิว', AppTheme.primaryColor),
      _ => (status, AppTheme.mutedText(context)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: appFont(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
