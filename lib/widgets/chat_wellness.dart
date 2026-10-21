import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'chat_rest_stop.dart'
    show RestStopSheetFrame, RestStopSheetLabel, restStopFieldDecoration;
import 'confirm_dialog.dart';
import 'travel_widgets.dart';

// เช็คอาการ "ยังไหวไหม"
//
// payload (wellness) มาจาก ChatWellnessService::present() — ส่วนสาธารณะมีแค่
// total/answered_count (คำตอบของใครเป็นข้อมูลสุขภาพ) "mine" (คำตอบของคนที่ฉัน
// ดูแล) มาตอนโหลดห้อง/ตอบกลับการกด ส่วน "detail" (ทุกคน + หมายเหตุ + เบอร์) มา
// เฉพาะ GET ของทีมงาน — broadcast ไม่มีทั้งคู่ ห้องแชทคงค่าเดิมไว้

List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

int _int(dynamic v) => int.tryParse('$v') ?? 0;

/// คำตอบสามแบบ — ค่าตรงกับ ChatWellnessCheck::STATUSES
const wellnessChoices = [
  (status: 'ok', emoji: '👍', label: 'สบาย'),
  (status: 'tired', emoji: '😮‍💨', label: 'เหนื่อย'),
  (status: 'unwell', emoji: '🤕', label: 'ไม่ค่อยไหว'),
];

({String status, String emoji, String label})? wellnessChoice(dynamic status) {
  for (final c in wellnessChoices) {
    if (c.status == status) return c;
  }
  return null;
}

Color wellnessColor(BuildContext context, dynamic status) => switch (status) {
  'ok' => AppTheme.primaryColor,
  'tired' => AppTheme.warningColor,
  'unwell' => AppTheme.errorColor,
  _ => AppTheme.mutedText(context),
};

class WellnessAnswer {
  final List<int> passengerIds;
  final String status;
  final String? note;

  const WellnessAnswer({
    required this.passengerIds,
    required this.status,
    this.note,
  });
}

/// การ์ดในบับเบิลแชท — ปุ่มตอบสามปุ่มสำหรับคนเดียว, ตอบให้กลุ่มผ่านชีต
class ChatWellnessCard extends StatelessWidget {
  final Map<String, dynamic> wellness;
  final bool canManage;
  final ValueChanged<WellnessAnswer> onAnswer;

  /// ตอบแทนกลุ่ม (หลายคน) หรือแก้คำตอบพร้อมหมายเหตุ — [status] = ปุ่มที่เพิ่งแตะ
  final ValueChanged<String?> onOpenAnswer;

  /// ทีมงานดูอาการทุกคน
  final VoidCallback onOpenStaff;

  const ChatWellnessCard({
    super.key,
    required this.wellness,
    required this.canManage,
    required this.onAnswer,
    required this.onOpenAnswer,
    required this.onOpenStaff,
  });

  @override
  Widget build(BuildContext context) {
    final w = wellness;
    final closed = w['is_closed'] == true;
    final label = w['label']?.toString() ?? '';
    final total = _int(w['total']);
    final answered = _int(w['answered_count']);
    final hasMine = w['mine'] is List;
    final mine = _maps(w['mine']);
    final muted = AppTheme.mutedText(context);
    final single = mine.length == 1 ? mine.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.favorite_rounded,
              size: 17,
              color: closed ? muted : AppTheme.errorColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label.isEmpty ? 'ยังไหวไหม?' : 'ยังไหวไหม? · $label',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          [
            'ตอบแล้ว $answered/$total คน',
            if (closed) 'ปิดแล้ว' else 'คำตอบเห็นแค่ทีมงาน',
          ].join(' · '),
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 10),
        if (!closed && single != null)
          Row(
            children: [
              for (final c in wellnessChoices) ...[
                Expanded(
                  child: _ChoiceButton(
                    emoji: c.emoji,
                    label: c.label,
                    selected: single['status'] == c.status,
                    color: wellnessColor(context, c.status),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      // สบาย = ตอบเลย, เหนื่อย/ไม่ไหว = เปิดชีตให้บอกอาการได้
                      c.status == 'ok'
                          ? onAnswer(
                              WellnessAnswer(
                                passengerIds: [_int(single['id'])],
                                status: 'ok',
                              ),
                            )
                          : onOpenAnswer(c.status);
                    },
                  ),
                ),
                if (c != wellnessChoices.last) const SizedBox(width: 6),
              ],
            ],
          ),
        if (!closed && single != null && single['handled'] == true)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'ทีมงานรับทราบแล้ว กำลังไปดูแลนะครับ',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        if (!closed && mine.length > 1)
          _MineSummary(mine: mine, onTap: () => onOpenAnswer(null)),
        if (closed && mine.isNotEmpty) _MineSummary(mine: mine, onTap: null),
        if (!closed && !hasMine && !canManage)
          // การ์ดเพิ่งมาทาง realtime ยังไม่รู้ว่าฉันดูแลใคร — ชีตจะโหลดให้
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => onOpenAnswer(null),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              child: Text(
                'ตอบ',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        if (canManage) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onOpenStaff();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(color: AppTheme.border(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              child: Text(
                'ดูอาการทุกคน',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? color.withValues(alpha: 0.14)
          : AppTheme.surface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: selected ? color : AppTheme.border(context),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w800,
                  color: selected ? color : AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MineSummary extends StatelessWidget {
  final List<Map<String, dynamic>> mine;
  final VoidCallback? onTap;

  const _MineSummary({required this.mine, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final waiting = mine.where((p) => p['status'] == null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in mine)
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  '${wellnessChoice(p['status'])?.emoji ?? '…'} ${p['name']}',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    color: wellnessColor(context, p['status']),
                  ),
                ),
              ),
          ],
        ),
        if (onTap != null) ...[
          const SizedBox(height: 6),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            child: Text(
              waiting > 0
                  ? 'ตอบให้กลุ่ม (ยังไม่ตอบ $waiting คน)'
                  : 'แก้คำตอบของกลุ่ม',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// ตอบให้ตัวเองพร้อมหมายเหตุ หรือให้ทั้งกลุ่มทีละคน — คืนคำตอบที่เปลี่ยน
/// (จัดกลุ่มตามสถานะ ส่งทีละสถานะได้ในครั้งเดียว)
class WellnessAnswerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> mine;

  /// ปุ่มที่แตะมาจากการ์ด (ตอบคนเดียว) — เลือกไว้ให้เลย
  final String? initialStatus;

  const WellnessAnswerSheet({
    super.key,
    required this.mine,
    this.initialStatus,
  });

  @override
  State<WellnessAnswerSheet> createState() => _WellnessAnswerSheetState();
}

class _WellnessAnswerSheetState extends State<WellnessAnswerSheet> {
  late final Map<int, String?> _status = {
    for (final p in widget.mine)
      _int(p['id']): widget.mine.length == 1 && widget.initialStatus != null
          ? widget.initialStatus
          : p['status']?.toString(),
  };
  late final _note = TextEditingController(
    text: widget.mine
        .map((p) => p['note']?.toString() ?? '')
        .firstWhere((n) => n.isNotEmpty, orElse: () => ''),
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _needsNote =>
      _status.values.any((s) => s == 'tired' || s == 'unwell');

  List<WellnessAnswer> _answers() {
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final byStatus = <String, List<int>>{};
    for (final p in widget.mine) {
      final id = _int(p['id']);
      final s = _status[id];
      if (s == null) continue;
      final changed = s != p['status'] || (s != 'ok' && note != p['note']);
      if (changed) byStatus.putIfAbsent(s, () => []).add(id);
    }
    return [
      for (final e in byStatus.entries)
        WellnessAnswer(
          passengerIds: e.value,
          status: e.key,
          note: e.key == 'ok' ? null : note,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final answers = _answers();
    return RestStopSheetFrame(
      icon: Icons.favorite_rounded,
      title: 'ยังไหวไหม?',
      subtitle:
          'คำตอบเห็นแค่ทีมงาน — เหนื่อยหรือไม่สบายบอกได้เลย ไม่ต้องเกรงใจ',
      footer: PrimaryCTAButton(
        label: answers.isEmpty ? 'เลือกคำตอบ' : 'ส่งคำตอบ',
        icon: Icons.send_rounded,
        onPressed: answers.isEmpty
            ? null
            : () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, answers);
              },
      ),
      children: [
        for (final p in widget.mine) ...[
          if (widget.mine.length > 1)
            RestStopSheetLabel(p['name']?.toString() ?? ''),
          Row(
            children: [
              for (final c in wellnessChoices) ...[
                Expanded(
                  child: _ChoiceButton(
                    emoji: c.emoji,
                    label: c.label,
                    selected: _status[_int(p['id'])] == c.status,
                    color: wellnessColor(context, c.status),
                    onTap: () =>
                        setState(() => _status[_int(p['id'])] = c.status),
                  ),
                ),
                if (c != wellnessChoices.last) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (_needsNote) ...[
          const RestStopSheetLabel('อาการ (ไม่บังคับ)'),
          TextField(
            controller: _note,
            maxLength: 200,
            onChanged: (_) => setState(() {}),
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface(context),
            ),
            decoration: restStopFieldDecoration(
              context,
              'เช่น เวียนหัว ปวดเข่า หายใจไม่ทัน',
            ),
          ),
        ],
      ],
    );
  }
}

/// ทีมงาน: อาการทุกคน (ไม่ไหวขึ้นก่อน) — โทรหา, กด "ไปดูแลแล้ว", ปิดเช็คอาการ
/// อัปเดตสดผ่าน [wellness] (ห้องแชทดึง GET ใหม่เมื่อมีคนตอบ)
class WellnessStaffSheet extends StatelessWidget {
  final ValueListenable<Map<String, dynamic>?> wellness;
  final Future<void> Function(int passengerId) onHandled;
  final Future<void> Function() onClose;

  const WellnessStaffSheet({
    super.key,
    required this.wellness,
    required this.onHandled,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: wellness,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        return _buildFor(context, data);
      },
    );
  }

  Widget _buildFor(BuildContext context, Map<String, dynamic> w) {
    final closed = w['is_closed'] == true;
    final detail = w['detail'] is Map
        ? Map<String, dynamic>.from(w['detail'] as Map)
        : null;
    final counts = detail?['counts'] is Map
        ? Map<String, dynamic>.from(detail!['counts'] as Map)
        : const <String, dynamic>{};
    final people = _maps(detail?['passengers']);
    final muted = AppTheme.mutedText(context);

    return RestStopSheetFrame(
      icon: Icons.favorite_rounded,
      title: 'อาการทุกคน',
      subtitle: detail == null
          ? 'กำลังโหลด…'
          : [
              '👍 ${_int(counts['ok'])}',
              '😮‍💨 ${_int(counts['tired'])}',
              '🤕 ${_int(counts['unwell'])}',
              'ยังไม่ตอบ ${_int(counts['none'])}',
              if (closed) 'ปิดแล้ว',
            ].join(' · '),
      footer: closed
          ? null
          : OutlinedButton.icon(
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'ปิดเช็คอาการ?',
                  message: 'ปิดแล้วตอบไม่ได้อีก ระบบขอบคุณทุกคนในแชท',
                  icon: Icons.favorite_outline_rounded,
                  confirmLabel: 'ปิดเลย',
                );
                if (!ok) return;
                await onClose();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text(
                'ปิดเช็คอาการ',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
      children: [
        if (detail == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        for (final p in people)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Text(
              wellnessChoice(p['status'])?.emoji ?? '…',
              style: const TextStyle(fontSize: 22),
            ),
            title: Text(
              p['name']?.toString() ?? '',
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            subtitle: Text(
              [
                wellnessChoice(p['status'])?.label ?? 'ยังไม่ตอบ',
                if ((p['note']?.toString() ?? '').isNotEmpty) '"${p['note']}"',
                if (p['handled'] == true) 'ไปดูแลแล้ว',
              ].join(' · '),
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: p['handled'] == true
                    ? muted
                    : wellnessColor(context, p['status']),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((p['phone']?.toString() ?? '').isNotEmpty)
                  IconButton(
                    tooltip: 'โทรหา',
                    icon: const Icon(
                      Icons.call_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: () => launchUrl(
                      Uri(scheme: 'tel', path: p['phone'].toString()),
                    ),
                  ),
                if (!closed &&
                    (p['status'] == 'tired' || p['status'] == 'unwell') &&
                    p['handled'] != true)
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onHandled(_int(p['id']));
                    },
                    child: Text(
                      'ไปดูแลแล้ว',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// ทีมงานส่งเช็คอาการ — ใส่ช่วงของทริป (ไม่บังคับ) คืน '' เมื่อไม่ใส่, null = ยกเลิก
class OpenWellnessSheet extends StatefulWidget {
  const OpenWellnessSheet({super.key});

  @override
  State<OpenWellnessSheet> createState() => _OpenWellnessSheetState();
}

class _OpenWellnessSheetState extends State<OpenWellnessSheet> {
  static const _quick = [
    'ก่อนขึ้นช่วงชัน',
    'ครึ่งทางแล้ว',
    'ถึงยอดแล้ว',
    'หลังลงเขา',
    'ก่อนนอน',
  ];

  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.favorite_rounded,
      title: 'เช็คอาการ "ยังไหวไหม"',
      subtitle:
          'ทุกคนตอบ สบาย / เหนื่อย / ไม่ค่อยไหว — คำตอบเห็นแค่ทีมงาน '
          'ใครไม่ไหวคุณรู้ทันที ใครเงียบ 10 นาทีระบบถามซ้ำและบอกคุณ',
      footer: PrimaryCTAButton(
        label: 'ส่งเช็คอาการ',
        icon: Icons.send_rounded,
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(context, _label.text.trim());
        },
      ),
      children: [
        const RestStopSheetLabel('ช่วงไหนของทริป (ไม่บังคับ)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in _quick)
              ChoiceChip(
                label: Text(
                  q,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selected: _label.text == q,
                onSelected: (_) => setState(() => _label.text = q),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _label,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface(context),
          ),
          decoration: restStopFieldDecoration(context, 'หรือพิมพ์เอง'),
        ),
      ],
    );
  }
}
