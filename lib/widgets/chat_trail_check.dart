import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'chat_rest_stop.dart'
    show RestStopSheetFrame, RestStopSheetLabel, restStopFieldDecoration;
import 'confirm_dialog.dart';
import 'travel_widgets.dart';

// เช็คพอยต์บนเส้นทางเดิน — "ใครถึงไหนแล้ว"
//
// payload (trail_check) มาจาก ChatTrailService::present() — passengers มีตำแหน่ง
// (index = จุดไกลสุดที่ถึง, null = ยังไม่ถึงจุดแรก) ของทุกคน แต่ใครขอพักบอกแค่
// help_count ส่วน my_help มีเฉพาะตอนโหลดห้อง/ตอบกลับการกด (broadcast ไม่มี)
// รายชื่อคนขอพัก + เบอร์ (needs_help/help_note/phone) มาเฉพาะ GET ของทีมงาน

List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

int _int(dynamic v) => int.tryParse('$v') ?? 0;

/// null = ยังไม่ถึงจุดแรก
int? _index(Map<String, dynamic> p) => int.tryParse('${p['index']}');

List<String> trailCheckpoints(Map<String, dynamic> trail) =>
    (trail['checkpoints'] as List? ?? const []).map((e) => '$e').toList();

/// ผู้เดินทางที่บัญชีนี้กดแทนได้
List<Map<String, dynamic>> myTrailPassengers(
  Map<String, dynamic> trail,
  int? myUserId,
) {
  if (myUserId == null) return const [];
  return _maps(
    trail['passengers'],
  ).where((p) => int.tryParse('${p['user_id']}') == myUserId).toList();
}

/// "ยังไม่ถึง ซำแฮก" / "ถึง หลังแป"
String trailWhere(List<String> names, int? index) {
  if (names.isEmpty) return '';
  if (index == null || index < 0) return 'ยังไม่ถึง ${names.first}';
  return 'ถึง ${names[index.clamp(0, names.length - 1)]}';
}

/// การ์ดในบับเบิลแชท — เส้นทาง ถึงแต่ละจุดกี่คน ใครอยู่ท้ายสุด และปุ่มของฉัน
class ChatTrailCheckCard extends StatelessWidget {
  final Map<String, dynamic> trail;
  final int? myUserId;
  final bool canManage;
  final void Function(List<int> passengerIds, int? index) onReach;
  final VoidCallback onHelp;
  final VoidCallback onCancelHelp;
  final VoidCallback onOpenBoard;

  const ChatTrailCheckCard({
    super.key,
    required this.trail,
    required this.myUserId,
    required this.canManage,
    required this.onReach,
    required this.onHelp,
    required this.onCancelHelp,
    required this.onOpenBoard,
  });

  @override
  Widget build(BuildContext context) {
    final names = trailCheckpoints(trail);
    final counts = (trail['counts'] as List? ?? const []).map(_int).toList();
    final total = _int(trail['total']);
    final closed = trail['is_closed'] == true;
    final title = trail['title']?.toString() ?? '';
    final tailNames = (trail['tail_names'] as List? ?? const [])
        .map((e) => '$e')
        .toList();
    final tailIndex = int.tryParse('${trail['tail_index']}');
    final helpCount = _int(trail['help_count']);
    final myHelp = trail['my_help'] == true;
    final mine = myTrailPassengers(trail, myUserId);
    final muted = AppTheme.mutedText(context);
    final last = names.length - 1;

    // กลุ่มของฉันเดินไปด้วยกัน — ปุ่มพาคนที่ยังอยู่ข้างหลังไปจุดถัดไป
    final myLowest = mine.isEmpty
        ? null
        : mine.map((p) => _index(p) ?? -1).reduce((a, b) => a < b ? a : b);
    final next = myLowest == null ? null : myLowest + 1;
    final behind = (next == null || next > last)
        ? const <Map<String, dynamic>>[]
        : mine.where((p) => (_index(p) ?? -1) < next).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.terrain_rounded,
              size: 17,
              color: closed ? muted : AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title.isEmpty ? 'เช็คพอยต์' : title,
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
            if (closed)
              Text(
                'ปิดแล้ว',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < names.length; i++)
          _CheckpointRow(
            name: names[i],
            reached: i < counts.length ? counts[i] : 0,
            total: total,
            isLast: i == last,
          ),
        if (tailNames.isNotEmpty && !closed) ...[
          const SizedBox(height: 4),
          Text(
            'ท้ายสุด: ${tailNames.take(5).join(', ')}'
            '${tailNames.length > 5 ? ' +${tailNames.length - 5}' : ''}'
            ' (${trailWhere(names, tailIndex)})',
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
        if (canManage && helpCount > 0 && !closed) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: onOpenBoard,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.back_hand_rounded,
                    size: 16,
                    color: AppTheme.warningColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ขอพัก $helpCount คน — แตะเพื่อดูว่าใคร',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (myHelp && !closed) ...[
          const SizedBox(height: 6),
          Text(
            'แจ้งทีมงานแล้วว่าขอพัก — พักให้หายเหนื่อยก่อนนะครับ',
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              color: AppTheme.warningColor,
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (!closed && behind.isNotEmpty && next != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onReach([for (final p in behind) _int(p['id'])], next);
              },
              icon: const Icon(Icons.flag_rounded, size: 17),
              label: Text(
                'ถึง ${names[next]} แล้ว'
                '${behind.length > 1 ? ' (${behind.length} คน)' : ''}',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ),
        if (!closed && mine.isNotEmpty && behind.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'ถึง ${names.isEmpty ? '' : names[last]} แล้ว',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        if (!closed) const SizedBox(height: 8),
        Row(
          children: [
            if (!closed && mine.isNotEmpty && !canManage) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    myHelp ? onCancelHelp() : onHelp();
                  },
                  icon: Icon(
                    myHelp
                        ? Icons.directions_walk_rounded
                        : Icons.back_hand_rounded,
                    size: 16,
                    color: AppTheme.warningColor,
                  ),
                  label: Text(
                    myHelp ? 'ตามทันแล้ว' : 'ขอพัก',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.warningColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                      color: AppTheme.warningColor.withValues(alpha: 0.6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onOpenBoard();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: AppTheme.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                child: Text(
                  canManage && !closed ? 'เช็คพอยต์' : 'ดูทั้งกลุ่ม',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckpointRow extends StatelessWidget {
  final String name;
  final int reached;
  final int total;
  final bool isLast;

  const _CheckpointRow({
    required this.name,
    required this.reached,
    required this.total,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final done = total > 0 && reached >= total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isLast ? Icons.flag_rounded : Icons.circle,
            size: isLast ? 15 : 9,
            color: done ? AppTheme.primaryColor : AppTheme.mutedText(context),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : reached / total,
                minHeight: 6,
                backgroundColor: AppTheme.border(context),
                color: done ? AppTheme.primaryColor : AppTheme.warningColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$reached/$total',
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w800,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ทีมงานตั้งเช็คพอยต์ ─────────────────────────────────────────────────

class TrailDraft {
  final String? title;
  final List<String> checkpoints;

  const TrailDraft({this.title, required this.checkpoints});
}

/// สูงสุดกี่จุด — ตรงกับ ChatTrailCheck::MAX_CHECKPOINTS
const trailMaxCheckpoints = 8;

class OpenTrailCheckSheet extends StatefulWidget {
  const OpenTrailCheckSheet({super.key});

  @override
  State<OpenTrailCheckSheet> createState() => _OpenTrailCheckSheetState();
}

class _OpenTrailCheckSheetState extends State<OpenTrailCheckSheet> {
  static const _hints = ['เช่น ซำแฮก', 'เช่น หลังแป', 'เช่น ยอด'];

  final _title = TextEditingController();
  final List<TextEditingController> _points = [
    for (var i = 0; i < 3; i++) TextEditingController(),
  ];

  @override
  void dispose() {
    _title.dispose();
    for (final c in _points) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _names =>
      _points.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

  String? get _problem {
    final names = _names;
    if (names.isEmpty) return 'ใส่ชื่อจุดอย่างน้อย 1 จุด';
    if (names.toSet().length != names.length) return 'ชื่อจุดซ้ำกัน';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return RestStopSheetFrame(
      icon: Icons.terrain_rounded,
      title: 'เช็คพอยต์เส้นทางเดิน',
      subtitle:
          'ตั้งจุดตามลำดับเดิน ทุกคนกด "ถึงแล้ว" ที่แต่ละจุด คุณเห็นว่าใครอยู่ท้ายสุด '
          'ใครตามไม่ทันกด "ขอพัก" ถึงคุณคนเดียว',
      footer: PrimaryCTAButton(
        label: problem ?? 'ประกาศเช็คพอยต์ · ${_names.length} จุด',
        icon: Icons.campaign_rounded,
        onPressed: problem != null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                Navigator.pop(
                  context,
                  TrailDraft(
                    title: _title.text.trim().isEmpty
                        ? null
                        : _title.text.trim(),
                    checkpoints: _names,
                  ),
                );
              },
      ),
      children: [
        const RestStopSheetLabel('ชื่อเส้นทาง (ไม่บังคับ)'),
        TextField(
          controller: _title,
          maxLength: 120,
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface(context),
          ),
          decoration: restStopFieldDecoration(context, 'เช่น ขึ้นยอดภูกระดึง'),
        ),
        const SizedBox(height: 14),
        const RestStopSheetLabel('จุดตามลำดับ (จุดสุดท้าย = ปลายทาง)'),
        for (var i = 0; i < _points.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _points[i],
                    maxLength: 40,
                    onChanged: (_) => setState(() {}),
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface(context),
                    ),
                    decoration: restStopFieldDecoration(
                      context,
                      i < _hints.length ? _hints[i] : 'ชื่อจุด',
                    ),
                  ),
                ),
                if (_points.length > 1)
                  IconButton(
                    tooltip: 'ลบจุดนี้',
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    onPressed: () => setState(() {
                      _points.removeAt(i).dispose();
                    }),
                  ),
              ],
            ),
          ),
        if (_points.length < trailMaxCheckpoints)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _points.add(TextEditingController())),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'เพิ่มจุด',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── ขอพัก ─────────────────────────────────────────────────────────────────

class TrailHelpDraft {
  final List<int> passengerIds;
  final String? note;

  const TrailHelpDraft({required this.passengerIds, this.note});
}

/// "ตามไม่ทัน ขอพัก" — เลือกว่าใครในกลุ่ม (ถ้ามีหลายคน) + บอกอาการสั้น ๆ
class TrailHelpSheet extends StatefulWidget {
  final List<Map<String, dynamic>> mine;

  const TrailHelpSheet({super.key, required this.mine});

  @override
  State<TrailHelpSheet> createState() => _TrailHelpSheetState();
}

class _TrailHelpSheetState extends State<TrailHelpSheet> {
  static const _quick = ['ขอพักสักครู่', 'ปวดเข่า', 'ตะคริว', 'หายใจไม่ทัน'];

  final _note = TextEditingController();
  late final Set<int> _who = widget.mine.length == 1
      ? {_int(widget.mine.first['id'])}
      : <int>{};

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.back_hand_rounded,
      title: 'ตามไม่ทัน ขอพัก',
      subtitle: 'ทีมงานเห็นคนเดียว ไม่ขึ้นในห้องรวม — พักได้เลย ไม่ต้องเกรงใจ',
      footer: PrimaryCTAButton(
        label: _who.isEmpty ? 'เลือกว่าใครขอพัก' : 'แจ้งทีมงาน',
        icon: Icons.send_rounded,
        color: AppTheme.warningColor,
        onPressed: _who.isEmpty
            ? null
            : () {
                HapticFeedback.mediumImpact();
                Navigator.pop(
                  context,
                  TrailHelpDraft(
                    passengerIds: _who.toList(),
                    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                  ),
                );
              },
      ),
      children: [
        if (widget.mine.length > 1) ...[
          const RestStopSheetLabel('ใครขอพัก'),
          for (final p in widget.mine)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _who.contains(_int(p['id'])),
              onChanged: (v) => setState(() {
                v == true
                    ? _who.add(_int(p['id']))
                    : _who.remove(_int(p['id']));
              }),
              title: Text(
                p['name']?.toString() ?? '',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        const RestStopSheetLabel('บอกทีมงานสั้น ๆ (ไม่บังคับ)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in _quick)
              ActionChip(
                label: Text(
                  q,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => setState(() => _note.text = q),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLength: 200,
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface(context),
          ),
          decoration: restStopFieldDecoration(
            context,
            'เช่น เดินช้าลงหน่อย ขาเริ่มล้า',
          ),
        ),
      ],
    );
  }
}

// ── กระดานเช็คพอยต์ ─────────────────────────────────────────────────────

/// ทุกคนแยกตามจุดที่ถึง — ทีมงานแตะชื่อเพื่อย้ายจุดแทน เห็นคนที่ขอพัก (พร้อมเบอร์)
/// ลูกทริปแตะชื่อคนในกลุ่มตัวเองเพื่อแก้จุดที่กดผิดได้ อัปเดตสดผ่าน [trail]
class TrailBoardSheet extends StatelessWidget {
  final ValueListenable<Map<String, dynamic>?> trail;
  final bool canManage;
  final int? myUserId;
  final Future<void> Function(List<int> passengerIds, int? index) onReach;
  final Future<void> Function(List<int> passengerIds) onAckHelp;
  final Future<void> Function() onClose;

  const TrailBoardSheet({
    super.key,
    required this.trail,
    required this.canManage,
    required this.myUserId,
    required this.onReach,
    required this.onAckHelp,
    required this.onClose,
  });

  Future<void> _move(
    BuildContext context,
    Map<String, dynamic> p,
    List<String> names,
  ) async {
    final current = _index(p);
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (sheetContext) => RestStopSheetFrame(
        icon: Icons.flag_rounded,
        title: '${p['name']} ถึงไหนแล้ว',
        children: [
          for (var i = names.length - 1; i >= -1; i--)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                (current ?? -1) == i
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: AppTheme.primaryColor,
              ),
              title: Text(
                i < 0 ? 'ยังไม่ถึง ${names.first}' : 'ถึง ${names[i]}',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // -2 แทน null เพราะ pop(null) = ปิดชีตเฉย ๆ
              onTap: () => Navigator.pop(sheetContext, i < 0 ? -2 : i),
            ),
        ],
      ),
    );
    if (picked == null) return;
    final index = picked == -2 ? null : picked;
    if (index == current) return;
    await onReach([_int(p['id'])], index);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: trail,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        return _buildFor(context, data);
      },
    );
  }

  Widget _buildFor(BuildContext context, Map<String, dynamic> t) {
    final names = trailCheckpoints(t);
    final closed = t['is_closed'] == true;
    final passengers = _maps(t['passengers']);
    final helpers = passengers.where((p) => p['needs_help'] == true).toList();
    final total = _int(t['total']);
    final lastCount = names.isEmpty
        ? 0
        : _int(
            (t['counts'] as List? ?? const []).elementAtOrNull(
              names.length - 1,
            ),
          );

    bool canTouch(Map<String, dynamic> p) =>
        !closed && (canManage || int.tryParse('${p['user_id']}') == myUserId);

    Widget person(Map<String, dynamic> p) {
      final phone = p['phone']?.toString() ?? '';
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        onTap: canTouch(p) ? () => _move(context, p, names) : null,
        title: Text(
          p['name']?.toString() ?? '',
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface(context),
          ),
        ),
        trailing: canTouch(p)
            ? Icon(
                Icons.edit_location_alt_rounded,
                size: 18,
                color: AppTheme.mutedText(context),
              )
            : (canManage && phone.isNotEmpty
                  ? IconButton(
                      tooltip: 'โทรหา',
                      icon: const Icon(
                        Icons.call_rounded,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: () =>
                          launchUrl(Uri(scheme: 'tel', path: phone)),
                    )
                  : null),
      );
    }

    // ไกลสุดอยู่บน — สตาฟปิดท้ายเลื่อนลงไปเจอคนที่อยู่ท้ายสุด
    final groups = <({String label, List<Map<String, dynamic>> people})>[
      for (var i = names.length - 1; i >= -1; i--)
        (
          label: i < 0
              ? 'ยังไม่ถึง ${names.isEmpty ? '' : names.first}'
              : 'ถึง ${names[i]}',
          people: passengers.where((p) => (_index(p) ?? -1) == i).toList(),
        ),
    ];

    return RestStopSheetFrame(
      icon: Icons.terrain_rounded,
      title: (t['title']?.toString() ?? '').isEmpty
          ? 'เช็คพอยต์'
          : t['title'].toString(),
      subtitle: [
        'ถึง${names.isEmpty ? '' : names.last} $lastCount/$total คน',
        if (closed) 'ปิดแล้ว',
      ].join(' · '),
      footer: (canManage && !closed)
          ? OutlinedButton.icon(
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'ปิดเช็คพอยต์?',
                  message: lastCount < total
                      ? 'ยังไม่ถึง${names.last}อีก ${total - lastCount} คน ปิดแล้วกดถึงไม่ได้อีก'
                      : 'ทุกคนถึงแล้ว ระบบสรุปให้ในแชท',
                  icon: Icons.flag_rounded,
                  confirmLabel: 'ปิดเลย',
                );
                if (!ok) return;
                await onClose();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text(
                'ปิดเช็คพอยต์',
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
            )
          : null,
      children: [
        if (canManage && helpers.isNotEmpty) ...[
          RestStopSheetLabel('ขอพัก ${helpers.length} คน'),
          for (final p in helpers)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['name']} · ${trailWhere(names, _index(p))}',
                          style: appFont(
                            fontSize: AppText.sizeBody,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                        if ((p['help_note']?.toString() ?? '').isNotEmpty)
                          Text(
                            '"${p['help_note']}"',
                            style: appFont(
                              fontSize: AppText.sizeLabel,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                      ],
                    ),
                  ),
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
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onAckHelp([_int(p['id'])]);
                    },
                    child: Text(
                      'รับทราบ',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
        if (passengers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'ยังไม่มีรายชื่อผู้เดินทางในรอบนี้',
              style: appFont(
                fontSize: AppText.sizeBody,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
        for (final g in groups)
          if (g.people.isNotEmpty) ...[
            RestStopSheetLabel('${g.label} · ${g.people.length} คน'),
            for (final p in g.people) person(p),
            const SizedBox(height: 6),
          ],
      ],
    );
  }
}
