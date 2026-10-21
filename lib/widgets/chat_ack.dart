import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import 'chat_rest_stop.dart' show RestStopSheetFrame, RestStopSheetLabel;
import 'confirm_dialog.dart';

// "รับทราบ" ใต้ประกาศของทีมงาน — แทนการพิมพ์ "รับทราบครับ" ตามกันทั้งห้อง
//
// payload (ack) มาจาก ChatAckService::present(): count/total ของทั้งห้อง
// acked_by_me มาตอนโหลดห้อง/ตอบกลับการกด ส่วน broadcast (chat.ack) ส่ง null
// ห้องแชทคงค่าเดิมของเครื่องนี้ไว้ · nudged_at ใช้ปิดปุ่มสะกิดช่วงพัก 15 นาที

/// ตรงกับ ChatAckService::NUDGE_COOLDOWN_MINUTES
const kAckNudgeCooldown = Duration(minutes: 15);

int _int(dynamic v) => int.tryParse('$v') ?? 0;

/// รวม payload ใหม่เข้ากับของเดิม — ค่า acked_by_me ที่เป็น null (จาก broadcast)
/// ไม่ทับค่าที่เครื่องนี้รู้อยู่แล้ว
Map<String, dynamic>? mergeAck(dynamic previous, dynamic next) {
  if (next is! Map) return null;
  final merged = Map<String, dynamic>.from(next);
  if (merged['acked_by_me'] == null && previous is Map) {
    merged['acked_by_me'] = previous['acked_by_me'];
  }
  return merged;
}

/// แถบใต้ประกาศ — ลูกทริปเห็นปุ่ม "รับทราบ" ทีมงานเห็นตัวนับ + ดูรายชื่อ
class ChatAckBar extends StatelessWidget {
  final Map<String, dynamic> ack;
  final bool canManage;
  final bool busy;
  final VoidCallback onAck;
  final VoidCallback onOpenDetail;

  const ChatAckBar({
    super.key,
    required this.ack,
    required this.canManage,
    required this.onAck,
    required this.onOpenDetail,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final count = _int(ack['count']);
    final total = _int(ack['total']);
    final mine = ack['acked_by_me'] == true;
    final done = total > 0 && count >= total;
    final tally = total > 0 ? 'รับทราบแล้ว $count/$total คน' : 'รับทราบแล้ว $count คน';

    if (canManage) {
      return InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        onTap: () {
          HapticFeedback.selectionClick();
          onOpenDetail();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                done ? Icons.task_alt_rounded : Icons.pending_actions_rounded,
                size: 16,
                color: done ? AppTheme.primaryColor : AppTheme.warningColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  done ? '$tally · ครบแล้ว' : '$tally · ดูว่าใครยังไม่กด',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w800,
                    color: done ? AppTheme.primaryColor : AppTheme.onSurface(context),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppTheme.mutedText(context),
              ),
            ],
          ),
        ),
      );
    }

    if (mine) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'คุณรับทราบแล้ว · $count/$total คน',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: busy
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onAck();
                },
          icon: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.thumb_up_alt_rounded, size: 16),
          label: Text(
            'รับทราบ',
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppTheme.primaryColor.withValues(alpha: 0.7),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            '$count/$total คน',
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// ทีมงาน: ใครกดแล้ว / ใครยังไม่กด + สะกิด + ยกเลิกการขอ
class ChatAckDetailSheet extends StatefulWidget {
  /// โหลดรายชื่อ — {ack, acked:[{id,name,avatar_url,acked_at}], pending:[...]}
  final Future<Map<String, dynamic>> Function() load;

  /// สะกิดคนที่ยังไม่กด — คืน payload ใหม่ (มี ack.nudged_at)
  final Future<Map<String, dynamic>> Function() onNudge;
  final Future<void> Function() onCancel;

  /// เวลาตอนนี้ — เทสตรึงได้
  final DateTime Function() now;

  const ChatAckDetailSheet({
    super.key,
    required this.load,
    required this.onNudge,
    required this.onCancel,
    this.now = DateTime.now,
  });

  @override
  State<ChatAckDetailSheet> createState() => _ChatAckDetailSheetState();
}

class _ChatAckDetailSheetState extends State<ChatAckDetailSheet> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  List<Map<String, dynamic>> _list(String key) => (_data?[key] as List? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  DateTime? get _nudgeReadyAt {
    final ack = _data?['ack'];
    final raw = ack is Map ? ack['nudged_at']?.toString() : null;
    final at = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    return at?.add(kAckNudgeCooldown);
  }

  Future<void> _nudge() async {
    setState(() => _busy = true);
    try {
      final res = await widget.onNudge();
      if (!mounted) return;
      final nudged = _int(res['nudged']);
      setState(() {
        if (res['ack'] is Map) {
          _data = {...?_data, 'ack': res['ack']};
        }
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('สะกิดแล้ว $nudged คน')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showConfirmDialog(
      context,
      title: 'ยกเลิกการขอรับทราบ?',
      message: 'ปุ่มรับทราบใต้ประกาศนี้จะหายไป และรายชื่อคนที่กดแล้วจะถูกล้าง',
      confirmLabel: 'ยกเลิกการขอ',
      tone: ConfirmTone.danger,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onCancel();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final acked = _list('acked');
    final pending = _list('pending');
    final readyAt = _nudgeReadyAt;
    final now = widget.now();
    final cooling = readyAt != null && readyAt.isAfter(now);
    final waitMinutes = cooling ? (readyAt.difference(now).inSeconds / 60).ceil() : 0;

    return RestStopSheetFrame(
      icon: Icons.task_alt_rounded,
      title: 'ใครรับทราบแล้วบ้าง',
      subtitle: _data == null
          ? null
          : 'รับทราบ ${acked.length}/${acked.length + pending.length} คน',
      footer: _data == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pending.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _busy || cooling ? null : _nudge,
                    icon: const Icon(Icons.notifications_active_rounded, size: 18),
                    label: Text(
                      cooling
                          ? 'สะกิดได้อีกครั้งใน $waitMinutes นาที'
                          : 'สะกิดคนที่ยังไม่กด (${pending.length})',
                      style: appFont(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: _busy ? null : _cancel,
                  child: Text(
                    'ยกเลิกการขอรับทราบ',
                    style: appFont(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
      children: [
        if (_data == null && _error == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          )
        else if (_data == null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'โหลดรายชื่อไม่สำเร็จ',
                  style: appFont(fontWeight: FontWeight.w700),
                ),
                TextButton(onPressed: _reload, child: const Text('ลองอีกครั้ง')),
              ],
            ),
          )
        else ...[
          RestStopSheetLabel(
            pending.isEmpty ? 'ทุกคนรับทราบแล้ว 🎉' : 'ยังไม่กด (${pending.length})',
          ),
          for (final p in pending) _PersonRow(person: p),
          if (acked.isNotEmpty) ...[
            const SizedBox(height: 8),
            RestStopSheetLabel('รับทราบแล้ว (${acked.length})'),
            for (final p in acked) _PersonRow(person: p, acked: true),
          ],
        ],
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  final Map<String, dynamic> person;
  final bool acked;

  const _PersonRow({required this.person, this.acked = false});

  String _time() {
    final at = DateTime.tryParse(person['acked_at']?.toString() ?? '')?.toLocal();
    if (at == null) return '';
    return '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final name = person['name']?.toString() ?? '';
    final avatar = ApiConfig.mediaUrl(person['avatar_url']);
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 32,
              height: 32,
              child: avatar.isEmpty
                  ? ColoredBox(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      child: Center(
                        child: Text(
                          initial,
                          style: appFont(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    )
                  : CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
          if (acked) ...[
            Text(
              _time(),
              style: appFont(
                fontSize: AppText.sizeCaption,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppTheme.primaryColor,
            ),
          ] else
            Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppTheme.mutedText(context),
            ),
        ],
      ),
    );
  }
}

/// สวิตช์ในช่องพิมพ์ของทีมงาน — ส่งข้อความนี้เป็นประกาศที่ทุกคนต้องกดรับทราบ
class AckRequestToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const AckRequestToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value
          ? AppTheme.primaryColor.withValues(alpha: 0.08)
          : AppTheme.surface(context),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Icon(
                Icons.campaign_rounded,
                size: 18,
                color: value ? AppTheme.primaryColor : AppTheme.mutedText(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value
                      ? 'ประกาศ — ทุกคนต้องกดรับทราบ (เด้งเตือนทุกคน)'
                      : 'ให้ทุกคนกดรับทราบข้อความนี้',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: value
                        ? AppTheme.primaryColor
                        : AppTheme.onSurface(context),
                  ),
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
