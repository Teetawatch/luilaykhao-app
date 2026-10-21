import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'chat_rest_stop.dart'
    show RestStopSheetFrame, RestStopSheetLabel, restStopFieldDecoration;
import 'confirm_dialog.dart';
import 'travel_widgets.dart';

// จุดลงขากลับ
//
// payload (dropoff) มาจาก ChatDropoffService::present() — ส่วนสาธารณะมีแค่จำนวน
// (จุดที่ปักเองอาจเป็นหน้าบ้าน) "mine" = จุดลงของคนที่ฉันดูแล มาตอนโหลดห้อง/ตอบ
// กลับการกด ส่วน "detail" (จุดเรียงตามทาง + ใครลงไหน + ตำแหน่งรถ) มาเฉพาะ GET
// ของทีมงาน — broadcast ไม่มีทั้งคู่ ห้องแชทคงค่าเดิมไว้

List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

int _int(dynamic v) => int.tryParse('$v') ?? 0;

double? _num(dynamic v) => double.tryParse('${v ?? ''}');

/// การ์ดในบับเบิลแชท — จุดลงของฉัน + ส่งไปแล้วกี่จุด
class ChatDropoffCard extends StatelessWidget {
  final Map<String, dynamic> dropoff;
  final bool canManage;
  final VoidCallback onChoose;
  final VoidCallback onOpenStaff;

  const ChatDropoffCard({
    super.key,
    required this.dropoff,
    required this.canManage,
    required this.onChoose,
    required this.onOpenStaff,
  });

  @override
  Widget build(BuildContext context) {
    final d = dropoff;
    final closed = d['is_closed'] == true;
    final mine = _maps(d['mine']);
    final hasMine = d['mine'] is List;
    final muted = AppTheme.mutedText(context);
    final waiting = mine.where((p) => p['dropped'] != true).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.airport_shuttle_rounded,
              size: 17,
              color: closed ? muted : AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'ขากลับลงที่ไหน',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          [
            'ส่งแล้ว ${_int(d['stops_done'])}/${_int(d['stop_count'])} จุด',
            '${_int(d['dropped_count'])}/${_int(d['total'])} คน',
            if (closed) 'ปิดแล้ว',
          ].join(' · '),
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final p in mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    p['dropped'] == true
                        ? Icons.check_circle_rounded
                        : Icons.place_rounded,
                    size: 16,
                    color: p['dropped'] == true
                        ? AppTheme.primaryColor
                        : AppTheme.accentColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${mine.length > 1 ? '${p['name']}: ' : 'จุดลงของคุณ: '}'
                      '${p['label']}'
                      '${p['is_default'] == true ? ' (จุดรับเดิม)' : ''}'
                      '${p['dropped'] == true ? ' · ลงแล้ว' : ''}',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface(context),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            if (!closed &&
                (waiting.isNotEmpty || (!hasMine && !canManage))) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onChoose();
                  },
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 17),
                  label: Text(
                    'เปลี่ยนจุดลง',
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
              if (canManage) const SizedBox(width: 8),
            ],
            if (canManage)
              Expanded(
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
                    'รายการจุดส่ง',
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

/// ผลจากชีตเลือกจุดลง — [reset] = กลับไปใช้จุดรับขาไป
class DropoffDraft {
  final List<int> passengerIds;
  final int? pickupPointId;
  final String? label;
  final double? lat;
  final double? lng;
  final String? note;

  const DropoffDraft({
    required this.passengerIds,
    this.pickupPointId,
    this.label,
    this.lat,
    this.lng,
    this.note,
  });

  bool get reset => pickupPointId == null && (label ?? '').isEmpty;
}

/// เลือกจุดลง: จุดรับเดิม / จุดรับอื่นของรอบ / ปักหมุดเอง
class DropoffChooseSheet extends StatefulWidget {
  final List<Map<String, dynamic>> mine;
  final List<Map<String, dynamic>> options;

  /// เปิดแผนที่ปักหมุด — คืน {label, lat, lng, note} หรือ null เมื่อยกเลิก
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic>? initial)
  onPickOnMap;

  const DropoffChooseSheet({
    super.key,
    required this.mine,
    required this.options,
    required this.onPickOnMap,
  });

  @override
  State<DropoffChooseSheet> createState() => _DropoffChooseSheetState();
}

class _DropoffChooseSheetState extends State<DropoffChooseSheet> {
  late final List<Map<String, dynamic>> _open = widget.mine
      .where((p) => p['dropped'] != true)
      .toList();
  late final Set<int> _who = {for (final p in _open) _int(p['id'])};

  /// 'default' / 'pp:{id}' / 'custom'
  late String _pick = _initialPick();
  Map<String, dynamic>? _custom;
  late final _note = TextEditingController(
    text: _open.isEmpty ? '' : (_open.first['note']?.toString() ?? ''),
  );

  String _initialPick() {
    if (_open.isEmpty) return 'default';
    final first = _open.first;
    if (first['is_default'] == true) return 'default';
    final pointId = int.tryParse('${first['pickup_point_id']}');
    if (pointId != null) return 'pp:$pointId';
    _custom = {
      'label': first['label'],
      'lat': first['lat'],
      'lng': first['lng'],
    };
    return 'custom';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final result = await widget.onPickOnMap(_custom);
    if (result == null || !mounted) return;
    setState(() {
      _custom = result;
      _pick = 'custom';
      final note = result['note']?.toString() ?? '';
      if (note.isNotEmpty) _note.text = note;
    });
  }

  DropoffDraft? get _draft {
    if (_who.isEmpty) return null;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    if (_pick == 'default') return DropoffDraft(passengerIds: _who.toList());
    if (_pick.startsWith('pp:')) {
      return DropoffDraft(
        passengerIds: _who.toList(),
        pickupPointId: int.tryParse(_pick.substring(3)),
        note: note,
      );
    }
    final label = _custom?['label']?.toString() ?? '';
    if (label.isEmpty) return null;
    return DropoffDraft(
      passengerIds: _who.toList(),
      label: label,
      lat: _num(_custom?['lat']),
      lng: _num(_custom?['lng']),
      note: note,
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final muted = AppTheme.mutedText(context);

    Widget option(
      String value,
      String title, {
      String? subtitle,
      VoidCallback? onTap,
    }) {
      final selected = _pick == value;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(
          selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          color: AppTheme.primaryColor,
        ),
        title: Text(
          title,
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface(context),
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: appFont(fontSize: AppText.sizeCaption, color: muted),
              ),
        onTap: onTap ?? () => setState(() => _pick = value),
      );
    }

    return RestStopSheetFrame(
      icon: Icons.edit_location_alt_rounded,
      title: 'ขากลับลงที่ไหน',
      subtitle:
          'ใกล้ถึงจุดลงแล้วระบบเตือนให้เตรียมของ จุดที่ปักเองเห็นแค่ทีมงาน',
      footer: PrimaryCTAButton(
        label: draft == null ? 'เลือกจุดลง' : 'บันทึกจุดลง',
        icon: Icons.check_rounded,
        onPressed: draft == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, draft);
              },
      ),
      children: [
        if (_open.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'ทุกคนในกลุ่มของคุณลงรถแล้ว',
              style: appFont(fontSize: AppText.sizeBody, color: muted),
            ),
          ),
        if (_open.length > 1) ...[
          const RestStopSheetLabel('ใครลงจุดนี้'),
          for (final p in _open)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
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
        if (_open.isNotEmpty) ...[
          const RestStopSheetLabel('จุดลง'),
          option('default', 'ลงที่จุดรับเดิม', subtitle: 'จุดที่ขึ้นรถตอนขาไป'),
          for (final o in widget.options)
            option(
              'pp:${_int(o['id'])}',
              o['label']?.toString() ?? '',
              subtitle: o['region']?.toString(),
            ),
          option(
            'custom',
            _pick == 'custom' &&
                    (_custom?['label']?.toString() ?? '').isNotEmpty
                ? _custom!['label'].toString()
                : 'ปักหมุดจุดอื่นระหว่างทาง',
            subtitle: 'เช่น ปั๊มก่อนเข้าเมือง แยกใกล้บ้าน สถานี BTS',
            onTap: _pickOnMap,
          ),
          const SizedBox(height: 8),
          if (_pick != 'default') ...[
            const RestStopSheetLabel('บอกคนขับ (ไม่บังคับ)'),
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
                'เช่น จอดฝั่งตรงข้ามเซเว่น',
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// ทีมงาน/คนขับ: จุดส่งเรียงตามทางจากตำแหน่งรถ — นำทาง, ส่งถึงแล้วทีละจุด
/// อัปเดตสดผ่าน [dropoff] (ห้องแชทดึง GET ใหม่เมื่อมีการเปลี่ยน)
class DropoffStaffSheet extends StatelessWidget {
  final ValueListenable<Map<String, dynamic>?> dropoff;
  final Future<void> Function(List<int> passengerIds, bool dropped) onDrop;
  final Future<void> Function() onClose;

  const DropoffStaffSheet({
    super.key,
    required this.dropoff,
    required this.onDrop,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: dropoff,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        return _buildFor(context, data);
      },
    );
  }

  Widget _buildFor(BuildContext context, Map<String, dynamic> d) {
    final closed = d['is_closed'] == true;
    final detail = d['detail'] is Map
        ? Map<String, dynamic>.from(d['detail'] as Map)
        : null;
    final stops = _maps(detail?['stops']);
    final muted = AppTheme.mutedText(context);
    final hasVan = detail?['van'] is Map;
    var order = 0;

    return RestStopSheetFrame(
      icon: Icons.airport_shuttle_rounded,
      title: 'จุดส่งขากลับ',
      subtitle: detail == null
          ? 'กำลังโหลด…'
          : [
              'ส่งแล้ว ${_int(d['stops_done'])}/${_int(d['stop_count'])} จุด',
              hasVan
                  ? 'เรียงจากตำแหน่งรถตอนนี้'
                  : 'ยังไม่มีพิกัดรถ เรียงตามจุดรับ',
              if (closed) 'ปิดแล้ว',
            ].join(' · '),
      footer: closed
          ? null
          : OutlinedButton.icon(
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'ปิดการ์ดจุดลง?',
                  message:
                      'ปิดแล้วลูกทริปเปลี่ยนจุดลงไม่ได้ และระบบหยุดเตือนใกล้ถึง',
                  icon: Icons.airport_shuttle_outlined,
                  confirmLabel: 'ปิดเลย',
                );
                if (!ok) return;
                await onClose();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text(
                'ปิดการ์ด',
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
        for (final s in stops)
          Builder(
            builder: (context) {
              final dropped = s['dropped'] == true;
              if (!dropped) order++;
              final people = _maps(s['passengers']);
              final lat = _num(s['lat']);
              final lng = _num(s['lng']);
              final km = _num(s['distance_km']);
              final ids = [for (final p in people) _int(p['id'])];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: dropped
                      ? AppTheme.subtleSurface(context)
                      : AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: dropped
                              ? muted
                              : AppTheme.primaryColor,
                          child: dropped
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : Text(
                                  '$order',
                                  style: appFont(
                                    fontSize: AppText.sizeCaption,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s['label']?.toString() ?? '',
                            style: appFont(
                              fontSize: AppText.sizeBody,
                              fontWeight: FontWeight.w800,
                              color: dropped
                                  ? muted
                                  : AppTheme.onSurface(context),
                            ),
                          ),
                        ),
                        Text(
                          [
                            'ลง ${people.length} คน',
                            if (km != null && !dropped)
                              '${km.toStringAsFixed(km < 10 ? 1 : 0)} กม.',
                          ].join(' · '),
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final p in people)
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 2),
                        child: Text(
                          [
                            p['name']?.toString() ?? '',
                            if ((p['note']?.toString() ?? '').isNotEmpty)
                              '"${p['note']}"',
                          ].join(' · '),
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (lat != null && lng != null && !dropped)
                          TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(
                                'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                              ),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(
                              Icons.navigation_rounded,
                              size: 16,
                            ),
                            label: Text(
                              'นำทาง',
                              style: appFont(
                                fontSize: AppText.sizeLabel,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (!closed || dropped)
                          dropped
                              ? TextButton(
                                  onPressed: () => onDrop(ids, false),
                                  child: Text(
                                    'ยกเลิก',
                                    style: appFont(
                                      fontSize: AppText.sizeLabel,
                                      fontWeight: FontWeight.w700,
                                      color: muted,
                                    ),
                                  ),
                                )
                              : FilledButton(
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    onDrop(ids, true);
                                  },
                                  child: Text(
                                    'ส่งถึงแล้ว',
                                    style: appFont(
                                      fontSize: AppText.sizeLabel,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
