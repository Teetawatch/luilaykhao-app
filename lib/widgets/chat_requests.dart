import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'chat_rest_stop.dart'
    show RestStopSheetFrame, RestStopSheetLabel, restStopFieldDecoration;
import 'travel_widgets.dart';

// คำขอจากลูกทริปถึงทีมงานบนรถ
//
// - ไม่บอกชื่อ (ChatStopRequest): ขอแวะห้องน้ำ แอร์หนาว/ร้อน ขับเร็วไป เบาเพลง
//   ทีมงานเห็นแค่จำนวนต่อเรื่อง
// - บอกชื่อ (ChatSupplyRequest): ขอยา/ของจำเป็น ส่งถึงที่นั่ง — ไม่กระจายเข้าห้องรวม
//
// รายการเรื่อง/ของมาจากเซิร์ฟเวอร์ (room.stop_request_kinds / room.supply_items)
// ฝั่งนี้แค่วาด

List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

int _int(dynamic v) => int.tryParse('$v') ?? 0;

/// รายการเรื่องตั้งต้นถ้าเซิร์ฟเวอร์รุ่นเก่ายังไม่ส่ง stop_request_kinds มา
const fallbackStopKinds = [
  {'key': 'toilet', 'label': 'ขอแวะห้องน้ำ', 'emoji': '🚻'},
];

// ── ไม่บอกชื่อ (ลูกทริป) ────────────────────────────────────────────────────

/// สิ่งที่ลูกทริปเลือกในชีต: ส่งเรื่อง [kind] (ห้องน้ำด่วนได้) หรือถอนเรื่องเดิม
class AnonRequestAction {
  final String kind;
  final bool urgent;
  final bool cancel;

  const AnonRequestAction(
    this.kind, {
    this.urgent = false,
    this.cancel = false,
  });
}

class AnonRequestSheet extends StatelessWidget {
  final List<Map<String, dynamic>> kinds;

  /// เรื่องที่ฉันส่งค้างไว้
  final Set<String> mine;

  const AnonRequestSheet({super.key, required this.kinds, required this.mine});

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.record_voice_over_rounded,
      title: 'บอกทีมงานแบบไม่บอกชื่อ',
      subtitle:
          'ทีมงานเห็นแค่ว่ามีกี่คนขอเรื่องนี้ ไม่เห็นชื่อคุณ และไม่ขึ้นในแชทรวม',
      children: [
        for (final k in kinds) _tile(context, k),
        const SizedBox(height: 4),
        Text(
          'แอร์/ความเร็ว/เพลง นับแค่ 1 ชั่วโมง ถ้ายังเป็นอยู่กดใหม่ได้เลย',
          style: appFont(
            fontSize: AppText.sizeCaption,
            color: AppTheme.mutedText(context),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> k) {
    final key = k['key']?.toString() ?? '';
    final sent = mine.contains(key);
    final toilet = key == 'toilet';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: sent
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context, AnonRequestAction(key, cancel: sent));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(
                  '${k['emoji'] ?? ''}',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${k['label'] ?? key}',
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      if (sent)
                        Text(
                          'ส่งแล้ว · แตะเพื่อถอน',
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
                if (toilet)
                  TextButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(
                        context,
                        AnonRequestAction(key, urgent: true),
                      );
                    },
                    child: Text(
                      sent ? 'เร่งเป็นด่วน' : 'ด่วน',
                      style: appFont(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  )
                else if (sent)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.primaryColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── แถบทีมงาน ─────────────────────────────────────────────────────────────

/// แถบบนห้องแชท (เฉพาะทีมงาน) — แต่ละเรื่องที่มีคนขอ + คิวขอยา/ของ
class StaffRequestBanner extends StatelessWidget {
  final List<Map<String, dynamic>> kinds;
  final Map<String, int> counts;
  final int urgentToilet;
  final int supplyPending;
  final ValueChanged<String> onKind;
  final VoidCallback onSupplies;

  const StaffRequestBanner({
    super.key,
    required this.kinds,
    required this.counts,
    required this.urgentToilet,
    required this.supplyPending,
    required this.onKind,
    required this.onSupplies,
  });

  bool get isEmpty => supplyPending == 0 && counts.values.every((c) => c <= 0);

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    final urgent = urgentToilet > 0 || supplyPending > 0;
    final color = urgent ? AppTheme.errorColor : AppTheme.warningColor;

    Widget chip(String text, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        backgroundColor: AppTheme.surface(context),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        label: Text(
          text,
          style: appFont(
            fontSize: AppText.sizeLabel,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface(context),
          ),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );

    return Material(
      color: color.withValues(alpha: 0.10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          children: [
            if (supplyPending > 0)
              chip('📦 ขอยา/ของ $supplyPending', onSupplies),
            for (final k in kinds)
              if ((counts[k['key']] ?? 0) > 0)
                chip(
                  '${k['emoji']} ${k['label']} ${counts[k['key']]}'
                  '${k['key'] == 'toilet' && urgentToilet > 0 ? ' · ด่วน $urgentToilet' : ''}',
                  () => onKind('${k['key']}'),
                ),
          ],
        ),
      ),
    );
  }
}

// ── ขอยา / ของจำเป็น (ลูกทริป) ──────────────────────────────────────────────

/// ชีตขอของ — เลือกของ, ขอให้ใคร (ถ้าจองให้หลายคน), หมายเหตุ แล้วดูสถานะคำขอของฉัน
class SupplyRequestSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  /// {requests, passengers} ของฉัน — ชีตเรียกซ้ำหลังส่ง/ยกเลิก
  final Future<Map<String, dynamic>> Function() load;
  final Future<void> Function(String item, int? passengerId, String? note)
  onSend;
  final Future<void> Function(int requestId) onCancel;

  const SupplyRequestSheet({
    super.key,
    required this.items,
    required this.load,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<SupplyRequestSheet> createState() => _SupplyRequestSheetState();
}

class _SupplyRequestSheetState extends State<SupplyRequestSheet> {
  Map<String, dynamic>? _data;
  String? _item;
  int? _passengerId;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        final people = _maps(data['passengers']);
        if (_passengerId == null && people.isNotEmpty) {
          _passengerId = _int(people.first['passenger_id']);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _data ??= const {});
    }
  }

  bool get _canSend =>
      _item != null &&
      !_busy &&
      (_item != 'other' || _note.text.trim().isNotEmpty);

  Future<void> _send() async {
    final item = _item;
    if (item == null) return;
    setState(() => _busy = true);
    try {
      await widget.onSend(
        item,
        _passengerId,
        _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _item = null;
        _note.clear();
      });
      await _reload();
    } catch (_) {
      // ข้อความผิดพลาดแสดงโดยผู้เรียก
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = _maps(_data?['passengers']);
    final requests = _maps(_data?['requests']);
    final muted = AppTheme.mutedText(context);

    return RestStopSheetFrame(
      icon: Icons.medical_services_rounded,
      title: 'ขอยา / ของจำเป็น',
      subtitle:
          'ทีมงานจะนำไปให้ที่นั่งของคุณ (เห็นเฉพาะทีมงาน ไม่ขึ้นในแชทรวม)',
      footer: PrimaryCTAButton(
        label: _item == null ? 'เลือกของที่ต้องการ' : 'ส่งคำขอ',
        icon: Icons.send_rounded,
        loading: _busy,
        onPressed: _canSend ? _send : null,
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final it in widget.items)
              ChoiceChip(
                label: Text(
                  '${it['emoji']} ${it['label']}',
                  style: appFont(fontWeight: FontWeight.w700),
                ),
                selected: _item == it['key'],
                onSelected: (_) => setState(() => _item = '${it['key']}'),
              ),
          ],
        ),
        if (people.length > 1) ...[
          const SizedBox(height: 14),
          const RestStopSheetLabel('ขอให้ใคร'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in people)
                ChoiceChip(
                  label: Text(
                    '${p['name']}'
                    '${(p['seat_label'] ?? '').toString().isNotEmpty ? ' · ${p['seat_label']}' : ''}',
                    style: appFont(fontWeight: FontWeight.w700),
                  ),
                  selected: _passengerId == _int(p['passenger_id']),
                  onSelected: (_) =>
                      setState(() => _passengerId = _int(p['passenger_id'])),
                ),
            ],
          ),
        ] else if (people.length == 1 &&
            (people.first['seat_label'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'ส่งถึงที่นั่ง ${people.first['seat_label']}',
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: 200,
          onChanged: (_) => setState(() {}),
          decoration: restStopFieldDecoration(
            context,
            _item == 'other'
                ? 'ต้องการอะไร (จำเป็น)'
                : 'หมายเหตุ (ไม่บังคับ) เช่น แพ้ยาพารา',
          ),
        ),
        if (requests.isNotEmpty) ...[
          const SizedBox(height: 8),
          const RestStopSheetLabel('คำขอของฉัน'),
          for (final r in requests)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Text(
                '${r['emoji'] ?? '📦'}',
                style: const TextStyle(fontSize: 20),
              ),
              title: Text(
                '${r['label']}'
                '${(r['for_name'] ?? '').toString().isNotEmpty ? ' · ${r['for_name']}' : ''}',
                style: appFont(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                switch (r['status']) {
                  'delivered' => 'ทีมงานส่งให้แล้ว',
                  'declined' =>
                    'ทีมงานไม่มีของนี้${(r['decline_note'] ?? '').toString().isNotEmpty ? ' — ${r['decline_note']}' : ''}',
                  _ => 'รอทีมงานนำไปให้',
                },
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  color: r['status'] == 'declined'
                      ? AppTheme.errorColor
                      : (r['status'] == 'delivered'
                            ? AppTheme.primaryColor
                            : muted),
                ),
              ),
              trailing: r['status'] == 'pending'
                  ? TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await widget.onCancel(_int(r['id']));
                                await _reload();
                              } catch (_) {
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      child: Text(
                        'ยกเลิก',
                        style: appFont(fontWeight: FontWeight.w700),
                      ),
                    )
                  : null,
            ),
        ],
      ],
    );
  }
}

// ── คิวขอยา/ของ (ทีมงาน) ────────────────────────────────────────────────────

/// คิวของทีมงาน — ที่รอก่อน (เลขที่นั่งตัวใหญ่ เดินไปหาง่าย) แล้วตามด้วยที่จัดการแล้ว
/// อัปเดตสดผ่าน [data] ที่ห้องแชทดึงใหม่ทุกครั้งที่มีสัญญาณ chat.supplies
class SupplyQueueSheet extends StatelessWidget {
  final ValueListenable<Map<String, dynamic>?> data;
  final Future<void> Function(int requestId) onDeliver;
  final Future<void> Function(int requestId, String? note) onDecline;

  const SupplyQueueSheet({
    super.key,
    required this.data,
    required this.onDeliver,
    required this.onDecline,
  });

  Future<void> _decline(BuildContext context, Map<String, dynamic> r) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ไม่มี${r['label']}?',
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'บอกผู้ขอ (ไม่บังคับ) เช่น จะแวะร้านยาจุดหน้า',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ยกเลิก', style: appFont(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              'แจ้งผู้ขอ',
              style: appFont(
                fontWeight: FontWeight.w800,
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    await onDecline(_int(r['id']), note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: data,
      builder: (context, d, _) {
        final requests = _maps(d?['requests']);
        final pending = requests
            .where((r) => r['status'] == 'pending')
            .toList();
        final handled = requests
            .where((r) => r['status'] != 'pending')
            .toList();
        final muted = AppTheme.mutedText(context);

        return RestStopSheetFrame(
          icon: Icons.medical_services_rounded,
          title: 'คิวขอยา / ของ',
          subtitle: d == null
              ? 'กำลังโหลด...'
              : (pending.isEmpty
                    ? 'ไม่มีคำขอที่รออยู่'
                    : 'รออยู่ ${pending.length} รายการ — เก่าสุดอยู่บน'),
          children: [
            for (final r in pending)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.cardDecoration(
                  context,
                  radius: AppTheme.radiusSm,
                ),
                child: Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        (r['seat_label'] ?? '').toString().isEmpty
                            ? '—'
                            : '${r['seat_label']}',
                        textAlign: TextAlign.center,
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r['emoji']} ${r['label']}',
                            style: appFont(
                              fontSize: AppText.sizeBody,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                          Text(
                            '${r['for_name'] ?? ''}'
                            '${(r['note'] ?? '').toString().isNotEmpty ? ' · ${r['note']}' : ''}',
                            style: appFont(
                              fontSize: AppText.sizeCaption,
                              color: muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'ไม่มีของนี้',
                      onPressed: () => _decline(context, r),
                      icon: Icon(Icons.block_rounded, color: muted),
                    ),
                    FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        onDeliver(_int(r['id']));
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                      ),
                      child: Text(
                        'ส่งแล้ว',
                        style: appFont(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            if (handled.isNotEmpty) ...[
              const SizedBox(height: 8),
              const RestStopSheetLabel('จัดการแล้ว (24 ชม.)'),
              for (final r in handled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${r['status'] == 'delivered' ? '✅' : '🚫'} '
                    '${(r['seat_label'] ?? '').toString().isEmpty ? '' : '${r['seat_label']} '}'
                    '${r['for_name'] ?? ''} — ${r['label']}',
                    style: appFont(fontSize: AppText.sizeLabel, color: muted),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
