import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'travel_widgets.dart';

// จุดพักระหว่างทาง — นัดเวลากลับรถ + เช็คชื่อขึ้นรถ และ "ขอแวะห้องน้ำ" แบบไม่บอกชื่อ
//
// payload ของการ์ด (rest_stop) มาจาก ChatRestStopService::present() — รายชื่อเป็น
// ระดับผู้โดยสาร แต่ละคนมี user_id ของบัญชีที่ดูแล (ตัวเอง หรือคนที่จองให้) ใช้หา
// "คนที่ฉันกดขึ้นรถแทนได้" ฝั่งแอป เบอร์โทรมีเฉพาะตอนทีมงานขอผ่าน GET

List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

int _int(dynamic v) => int.tryParse('$v') ?? 0;

DateTime? _time(dynamic raw) => DateTime.tryParse('${raw ?? ''}')?.toLocal();

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// ผู้โดยสารที่บัญชีนี้กดขึ้นรถแทนได้
List<Map<String, dynamic>> myRestStopPassengers(
  Map<String, dynamic> stop,
  int? myUserId,
) {
  if (myUserId == null) return const [];
  return _maps(
    stop['passengers'],
  ).where((p) => int.tryParse('${p['user_id']}') == myUserId).toList();
}

/// "อีก 12:34" / "เลยเวลา 3 นาที" — นับจากเวลานัด
({String text, bool late}) _countdown(DateTime returnAt) {
  final left = returnAt.difference(DateTime.now());
  if (left.isNegative) {
    final over = -left.inMinutes;
    return (text: over < 1 ? 'ถึงเวลาแล้ว' : 'เลยเวลา $over นาที', late: true);
  }
  final m = left.inMinutes;
  final s = left.inSeconds % 60;
  if (m >= 60) return (text: 'อีก ${m ~/ 60} ชม. ${m % 60} นาที', late: false);
  return (text: 'อีก $m:${s.toString().padLeft(2, '0')}', late: false);
}

/// ติ๊กทุกวินาทีเฉพาะตอนการ์ดยังเปิดอยู่ — ออกรถแล้วหยุดนับ
mixin _Ticker<T extends StatefulWidget> on State<T> {
  Timer? _timer;

  bool get ticking;

  void syncTicker() {
    if (ticking && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!ticking) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// การ์ดในบับเบิลแชท — เวลากลับรถตัวใหญ่ นับถอยหลัง ขึ้นแล้วกี่คน และปุ่มของฉัน
class ChatRestStopCard extends StatefulWidget {
  final Map<String, dynamic> stop;
  final int? myUserId;
  final bool canManage;

  /// ฉัน (และกลุ่มที่ฉันจองให้) ขึ้นรถ/ยังไม่ขึ้น
  final void Function(List<int> passengerIds, bool boarded) onBoard;

  /// เปิดรายชื่อเช็คชื่อ (ทีมงานจัดการได้ ลูกทริปดูได้)
  final VoidCallback onOpenRoll;

  const ChatRestStopCard({
    super.key,
    required this.stop,
    required this.myUserId,
    required this.canManage,
    required this.onBoard,
    required this.onOpenRoll,
  });

  @override
  State<ChatRestStopCard> createState() => _ChatRestStopCardState();
}

class _ChatRestStopCardState extends State<ChatRestStopCard>
    with _Ticker<ChatRestStopCard> {
  @override
  bool get ticking => widget.stop['is_departed'] != true;

  @override
  void initState() {
    super.initState();
    syncTicker();
  }

  @override
  void didUpdateWidget(covariant ChatRestStopCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncTicker();
  }

  Future<void> _pickMine(List<Map<String, dynamic>> mine) async {
    final result = await showModalBottomSheet<Map<int, bool>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (_) => _MyBoardingSheet(passengers: mine),
    );
    if (result == null || result.isEmpty) return;
    final on = [
      for (final e in result.entries)
        if (e.value) e.key,
    ];
    final off = [
      for (final e in result.entries)
        if (!e.value) e.key,
    ];
    if (on.isNotEmpty) widget.onBoard(on, true);
    if (off.isNotEmpty) widget.onBoard(off, false);
  }

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    final departed = stop['is_departed'] == true;
    final returnAt = _time(stop['return_at']);
    final total = _int(stop['total']);
    final boarded = _int(stop['boarded_count']);
    final place = stop['place']?.toString() ?? '';
    final mine = myRestStopPassengers(stop, widget.myUserId);
    final mineWaiting = mine.where((p) => p['boarded'] != true).toList();
    final muted = AppTheme.mutedText(context);
    final countdown = returnAt == null ? null : _countdown(returnAt);
    final accent = departed
        ? muted
        : (countdown?.late == true
              ? AppTheme.errorColor
              : AppTheme.primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_parking_rounded, size: 17, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                place.isEmpty ? 'จุดพัก' : place,
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
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              departed
                  ? 'ออกรถแล้ว'
                  : (returnAt == null ? '--:--' : _clock(returnAt)),
              style: appFont(
                fontSize: AppText.sizeH1,
                fontWeight: FontWeight.w800,
                color: accent,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 8),
            if (!departed && countdown != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'กลับขึ้นรถ · ${countdown.text}',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: countdown.late ? AppTheme.errorColor : muted,
                  ),
                ),
              ),
          ],
        ),
        if (total > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : boarded / total,
              minHeight: 6,
              backgroundColor: AppTheme.border(context),
              color: boarded >= total
                  ? AppTheme.primaryColor
                  : AppTheme.warningColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            boarded >= total
                ? 'ขึ้นรถครบ $total คนแล้ว'
                : 'ขึ้นรถแล้ว $boarded/$total คน',
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            if (!departed && mine.isNotEmpty)
              Expanded(
                child: mineWaiting.isEmpty
                    ? OutlinedButton.icon(
                        onPressed: () => mine.length == 1
                            ? widget.onBoard([_int(mine.first['id'])], false)
                            : _pickMine(mine),
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          size: 17,
                          color: AppTheme.primaryColor,
                        ),
                        label: Text(
                          mine.length == 1
                              ? 'ขึ้นรถแล้ว'
                              : 'ขึ้นครบ ${mine.length} คน',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          if (mine.length == 1 ||
                              mineWaiting.length == mine.length) {
                            // กดทีเดียวขึ้นครบทั้งกลุ่ม — ปกติกลับมาพร้อมกัน
                            widget.onBoard([
                              for (final p in mineWaiting) _int(p['id']),
                            ], true);
                          } else {
                            _pickMine(mine);
                          }
                        },
                        icon: const Icon(
                          Icons.directions_bus_rounded,
                          size: 17,
                        ),
                        label: Text(
                          mine.length == 1
                              ? 'ฉันขึ้นรถแล้ว'
                              : 'ขึ้นรถแล้ว (${mineWaiting.length} คน)',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                        ),
                      ),
              ),
            if (!departed && mine.isNotEmpty) const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.onOpenRoll();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: AppTheme.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                child: Text(
                  widget.canManage && !departed ? 'เช็คชื่อ' : 'ดูรายชื่อ',
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

/// เลือกว่าใครในกลุ่มขึ้นรถแล้ว — คืน {passengerId: boarded} เฉพาะที่เปลี่ยน
class _MyBoardingSheet extends StatefulWidget {
  final List<Map<String, dynamic>> passengers;

  const _MyBoardingSheet({required this.passengers});

  @override
  State<_MyBoardingSheet> createState() => _MyBoardingSheetState();
}

class _MyBoardingSheetState extends State<_MyBoardingSheet> {
  late final Map<int, bool> _state = {
    for (final p in widget.passengers) _int(p['id']): p['boarded'] == true,
  };

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.directions_bus_rounded,
      title: 'ใครขึ้นรถแล้วบ้าง',
      subtitle: 'ติ๊กให้คนในกลุ่มที่คุณจองให้ได้เลย',
      footer: PrimaryCTAButton(
        label: 'บันทึก',
        icon: Icons.check_rounded,
        onPressed: () {
          final changed = <int, bool>{
            for (final p in widget.passengers)
              if ((p['boarded'] == true) != _state[_int(p['id'])])
                _int(p['id']): _state[_int(p['id'])]!,
          };
          Navigator.pop(context, changed);
        },
      ),
      children: [
        for (final p in widget.passengers)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _state[_int(p['id'])],
            onChanged: (v) => setState(() => _state[_int(p['id'])] = v == true),
            title: Text(
              p['name']?.toString() ?? '',
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

// ── ทีมงานประกาศพัก ─────────────────────────────────────────────────────

class RestStopDraft {
  final int minutes;
  final String? place;

  const RestStopDraft({required this.minutes, this.place});
}

class OpenRestStopSheet extends StatefulWidget {
  const OpenRestStopSheet({super.key});

  @override
  State<OpenRestStopSheet> createState() => _OpenRestStopSheetState();
}

class _OpenRestStopSheetState extends State<OpenRestStopSheet> {
  static const _choices = [10, 15, 20, 30, 45, 60];

  final _place = TextEditingController();
  int _minutes = 20;

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final returnAt = DateTime.now().add(Duration(minutes: _minutes));
    return RestStopSheetFrame(
      icon: Icons.local_parking_rounded,
      title: 'พักรถ / นัดเวลากลับรถ',
      subtitle:
          'ทุกคนเห็นเวลากลับรถในแชท ระบบเตือนคนที่ยังไม่ขึ้นก่อน 5 นาที '
          'และบอกคุณว่าขาดใครเมื่อถึงเวลา',
      footer: PrimaryCTAButton(
        label: 'ประกาศพัก · กลับรถ ${_clock(returnAt)}',
        icon: Icons.campaign_rounded,
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(
            context,
            RestStopDraft(
              minutes: _minutes,
              place: _place.text.trim().isEmpty ? null : _place.text.trim(),
            ),
          );
        },
      ),
      children: [
        const RestStopSheetLabel('พักกี่นาที'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _choices)
              ChoiceChip(
                label: Text(
                  '$m นาที',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selected: _minutes == m,
                onSelected: (_) => setState(() => _minutes = m),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const RestStopSheetLabel('ที่ไหน (ไม่บังคับ)'),
        TextField(
          controller: _place,
          maxLength: 120,
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface(context),
          ),
          decoration: restStopFieldDecoration(
            context,
            'เช่น ปั๊ม ปตท. วังน้อย / คาเฟ่ริมทาง',
          ),
        ),
      ],
    );
  }
}

// ── รายชื่อเช็คชื่อ ───────────────────────────────────────────────────────

/// รายชื่อขึ้นรถ — ยังไม่ขึ้นอยู่บนสุด ทีมงานแตะเพื่อติ๊กแทน กดโทรตามได้
/// อัปเดตสดผ่าน [stop] ที่ห้องแชทป้อนจาก realtime
class RestStopRollSheet extends StatefulWidget {
  final ValueListenable<Map<String, dynamic>?> stop;
  final bool canManage;
  final Future<void> Function(int passengerId, bool boarded) onToggle;
  final Future<void> Function(int minutes) onExtend;
  final Future<void> Function() onDepart;

  const RestStopRollSheet({
    super.key,
    required this.stop,
    required this.canManage,
    required this.onToggle,
    required this.onExtend,
    required this.onDepart,
  });

  @override
  State<RestStopRollSheet> createState() => _RestStopRollSheetState();
}

class _RestStopRollSheetState extends State<RestStopRollSheet>
    with _Ticker<RestStopRollSheet> {
  // เบอร์โทรมากับ payload ของทีมงานเท่านั้น — realtime ที่ตามมาไม่มีเบอร์
  // จึงจำไว้ตั้งแต่ครั้งแรกที่เห็น
  final Map<int, String> _phones = {};

  @override
  bool get ticking => widget.stop.value?['is_departed'] != true;

  @override
  void initState() {
    super.initState();
    syncTicker();
  }

  void _rememberPhones(Map<String, dynamic> data) {
    for (final p in _maps(data['passengers'])) {
      final phone = p['phone']?.toString() ?? '';
      if (phone.isNotEmpty) _phones[_int(p['id'])] = phone;
    }
  }

  Future<void> _confirmDepart(int missing) async {
    if (missing > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'ยังขาด $missing คน ออกรถเลยไหม?',
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'บางคนอาจขึ้นรถแล้วแต่ลืมกด ลองนับหัวบนรถอีกรอบก่อนนะครับ',
            style: appFont(fontSize: AppText.sizeBody),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'รอก่อน',
                style: appFont(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'ออกรถ',
                style: appFont(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    HapticFeedback.mediumImpact();
    await widget.onDepart();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: widget.stop,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        _rememberPhones(data);
        syncTicker();
        return _buildFor(context, data);
      },
    );
  }

  Widget _buildFor(BuildContext context, Map<String, dynamic> data) {
    final departed = data['is_departed'] == true;
    final passengers = _maps(data['passengers']);
    final waiting = passengers.where((p) => p['boarded'] != true).toList();
    final boarded = passengers.where((p) => p['boarded'] == true).toList();
    final returnAt = _time(data['return_at']);
    final countdown = returnAt == null ? null : _countdown(returnAt);
    final manage = widget.canManage && !departed;

    Widget row(Map<String, dynamic> p) {
      final id = _int(p['id']);
      final isOn = p['boarded'] == true;
      final phone = _phones[id];
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        onTap: manage
            ? () {
                HapticFeedback.selectionClick();
                widget.onToggle(id, !isOn);
              }
            : null,
        leading: Icon(
          isOn ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: isOn ? AppTheme.primaryColor : AppTheme.mutedText(context),
        ),
        title: Text(
          p['name']?.toString() ?? '',
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface(context),
          ),
        ),
        trailing: (widget.canManage && !isOn && phone != null)
            ? IconButton(
                tooltip: 'โทรหา',
                icon: const Icon(
                  Icons.call_rounded,
                  color: AppTheme.primaryColor,
                ),
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
              )
            : null,
      );
    }

    return RestStopSheetFrame(
      icon: Icons.fact_check_rounded,
      title: departed
          ? 'ออกรถแล้ว'
          : 'กลับขึ้นรถ ${returnAt == null ? '' : _clock(returnAt)}',
      subtitle: [
        'ขึ้นแล้ว ${boarded.length}/${passengers.length} คน',
        if (!departed && countdown != null) countdown.text,
      ].join(' · '),
      footer: manage
          ? Row(
              children: [
                for (final m in const [5, 10]) ...[
                  OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      widget.onExtend(m);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: Text(
                      '+$m นาที',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _confirmDepart(waiting.length),
                    icon: const Icon(Icons.directions_bus_rounded, size: 18),
                    label: Text(
                      'ออกรถ',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
      children: [
        if (passengers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'ยังไม่มีรายชื่อผู้โดยสารในรอบนี้',
              style: appFont(
                fontSize: AppText.sizeBody,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
        if (waiting.isNotEmpty) ...[
          RestStopSheetLabel(
            manage
                ? 'ยังไม่ขึ้น ${waiting.length} คน — แตะเพื่อติ๊กแทน'
                : 'ยังไม่ขึ้น ${waiting.length} คน',
          ),
          for (final p in waiting) row(p),
          const SizedBox(height: 8),
        ],
        if (boarded.isNotEmpty) ...[
          RestStopSheetLabel('ขึ้นรถแล้ว ${boarded.length} คน'),
          for (final p in boarded) row(p),
        ],
      ],
    );
  }
}

// ── ขอแวะห้องน้ำ ─────────────────────────────────────────────────────────

/// ผลจากชีตขอแวะ: true/false = ส่งคำขอ (ด่วนไหม), null = ปิดชีตเฉย ๆ
/// [StopRequestAction.cancel] = ถอนคำขอเดิม
enum StopRequestAction { normal, urgent, cancel }

class StopRequestSheet extends StatelessWidget {
  final bool hasPending;

  const StopRequestSheet({super.key, required this.hasPending});

  @override
  Widget build(BuildContext context) {
    Widget option(
      StopRequestAction action,
      IconData icon,
      String title,
      String sub,
      Color color,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context, action);
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: appFont(
                            fontSize: AppText.sizeBody,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                        Text(
                          sub,
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RestStopSheetFrame(
      icon: Icons.wc_rounded,
      title: 'ขอแวะห้องน้ำ',
      subtitle:
          'ทีมงานเห็นแค่ว่า "มีคนขอแวะ" กี่คน ไม่เห็นชื่อคุณ และไม่ขึ้นในแชทรวม',
      children: [
        if (hasPending) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'คุณส่งคำขอไว้แล้ว ทีมงานกำลังหาจุดแวะให้ครับ',
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          option(
            StopRequestAction.urgent,
            Icons.priority_high_rounded,
            'เปลี่ยนเป็นด่วน',
            'ทีมงานจะได้แจ้งเตือนอีกครั้ง',
            AppTheme.errorColor,
          ),
          option(
            StopRequestAction.cancel,
            Icons.undo_rounded,
            'ไม่เป็นไรแล้ว',
            'ถอนคำขอของฉัน',
            AppTheme.mutedText(context),
          ),
        ] else ...[
          option(
            StopRequestAction.normal,
            Icons.wc_rounded,
            'ขอแวะเมื่อสะดวก',
            'แวะปั๊มหรือจุดพักถัดไปได้',
            AppTheme.primaryColor,
          ),
          option(
            StopRequestAction.urgent,
            Icons.priority_high_rounded,
            'ด่วน',
            'ขอแวะเร็วที่สุดที่ทำได้',
            AppTheme.errorColor,
          ),
        ],
      ],
    );
  }
}

/// แถบบนห้องแชท (เฉพาะทีมงาน) — มีคนขอแวะห้องน้ำกี่คน + ปุ่มรับทราบ
class StopRequestBanner extends StatelessWidget {
  final int pending;
  final int urgent;
  final VoidCallback onAcknowledge;

  const StopRequestBanner({
    super.key,
    required this.pending,
    required this.urgent,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final color = urgent > 0 ? AppTheme.errorColor : AppTheme.warningColor;
    return Material(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.wc_rounded, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'มีคนขอแวะห้องน้ำ $pending คน'
                '${urgent > 0 ? ' · ด่วน $urgent' : ''}',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
            TextButton(
              onPressed: onAcknowledge,
              child: Text(
                'รับทราบ',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ทีมงานเลือกว่าจะแวะเมื่อไร — คืนนาที (0 = แวะเลย) หรือ -1 = "เร็ว ๆ นี้"
class AcknowledgeStopSheet extends StatelessWidget {
  const AcknowledgeStopSheet({super.key});

  @override
  Widget build(BuildContext context) {
    const choices = [
      (0, 'แวะเลย'),
      (5, '5 นาที'),
      (10, '10 นาที'),
      (15, '15 นาที'),
      (30, '30 นาที'),
      (-1, 'เร็ว ๆ นี้'),
    ];
    return RestStopSheetFrame(
      icon: Icons.wc_rounded,
      title: 'จะแวะห้องน้ำเมื่อไร',
      subtitle: 'ระบบบอกทุกคนในห้อง และแจ้งคนที่ขอเป็นรายคน',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in choices)
              ActionChip(
                label: Text(
                  c.$2,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => Navigator.pop(context, c.$1),
              ),
          ],
        ),
      ],
    );
  }
}

// ── ชิ้นส่วนร่วม ───────────────────────────────────────────────────────────

InputDecoration restStopFieldDecoration(BuildContext context, String hint) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
    borderSide: BorderSide(color: AppTheme.border(context)),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: appFont(
      fontSize: AppText.sizeBody,
      fontWeight: FontWeight.w500,
      color: AppTheme.mutedText(context),
    ),
    isDense: true,
    filled: true,
    fillColor: AppTheme.subtleSurface(context),
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: border,
    enabledBorder: border,
  );
}

class RestStopSheetLabel extends StatelessWidget {
  final String label;

  const RestStopSheetLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        label,
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w800,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}

/// โครงชีตล่างที่ใช้ร่วมกัน: ที่จับ + หัวเรื่อง + เนื้อหาเลื่อนได้ + ปุ่มท้ายชีต
class RestStopSheetFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  const RestStopSheetFrame({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.mutedText(context).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: appFont(
                          fontSize: AppText.sizeSubtitle,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    subtitle!,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                      height: 1.4,
                    ),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  children: children,
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
