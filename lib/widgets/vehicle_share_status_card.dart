import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/trip_calendar.dart' show bangkokToday, parseCalendarDate;
import '../providers/app_provider.dart';
import '../services/vehicle_location_sharing.dart';
import '../theme/app_theme.dart';
import 'app_snack.dart';

/// การ์ด "แชร์ตำแหน่งรถ" บนหน้าแรกของแท็บงานสตาฟ
///
/// สวิตช์ตัวจริงอยู่ลึกในหน้ารายชื่อผู้โดยสาร (งานสตาฟ → รอบ → รายชื่อ) ซึ่ง
/// ตอนหน้างานวุ่น ๆ ไม่มีใครเข้าไปหา การ์ดนี้จึงบอกสถานะบนหน้าแรกที่สตาฟเปิด
/// และแก้ได้ในแตะเดียว:
///
/// - live      = เครื่องนี้กำลังแชร์อยู่ (แตะเพื่อจัดการในหน้ารายชื่อ)
/// - friend    = เพื่อนสตาฟกำลังเป็น GPS ของรถอยู่ เครื่องนี้ไม่ต้องเปิด
/// - due       = ถึงเวลาแล้วแต่ยังไม่มีใครแชร์ — สีส้ม พร้อมปุ่มเปิด
/// - prepare   = ยังไม่ถึงเวลา (วันนี้ก่อนรถออก หรือพรุ่งนี้) — เช็คสิทธิ์ตำแหน่ง
///               ไว้ก่อน จะได้ไม่ต้องมากดอนุญาตตอนกำลังเช็คอินลูกค้า
///
/// เวลาและ "ถึงเวลาหรือยัง" มาจากเซิร์ฟเวอร์ทั้งหมด (share_location_mode,
/// share_auto_starts_at, vehicle_sharer) แอปไม่คิดเวลาไทยเอง
class VehicleShareStatusCard extends StatefulWidget {
  final Map<String, dynamic> schedule;

  /// เปิดหน้ารายชื่อของรอบนี้ — ที่นั่นมีสวิตช์ปิด/เปิดตัวเต็ม
  final VoidCallback? onOpenManifest;

  const VehicleShareStatusCard({
    super.key,
    required this.schedule,
    this.onOpenManifest,
  });

  /// รอบนี้มีเรื่องแชร์ตำแหน่งรถให้พูดถึงไหม — ไม่มีรถก็ไม่มีอะไรให้แชร์
  static bool applies(Map<String, dynamic> schedule) {
    final vehicle = schedule['vehicle'];
    return vehicle is Map &&
        vehicle.isNotEmpty &&
        int.tryParse('${schedule['id']}') != null;
  }

  /// เลือกว่าการ์ดควรพูดถึงรอบไหน (active = กำลังเดินทาง/วันนี้, upcoming = รอบถัดไป)
  ///
  /// ลำดับ: รอบที่เครื่องนี้ส่งอยู่ → รอบที่ถึงเวลาแชร์แล้ว (เซิร์ฟเวอร์บอก) →
  /// รอบที่เพื่อนสตาฟเป็นคนส่ง → รอบของวันนี้ที่ยังไม่ถึงเวลา → รอบของพรุ่งนี้
  /// (เตรียมสิทธิ์ตำแหน่งไว้ก่อน) — ไม่มีสักรอบที่มีรถคืน null
  static Map<String, dynamic>? pickRound(
    List<Map<String, dynamic>> active,
    List<Map<String, dynamic>> upcoming, {
    required bool Function(int id) isSharingFor,
    DateTime? today,
  }) {
    final candidates = [...active, ...upcoming].where(applies).toList();
    if (candidates.isEmpty) return null;

    int idOf(Map<String, dynamic> s) => int.parse('${s['id']}');
    bool due(Map<String, dynamic> s) {
      final mode = '${s['share_location_mode'] ?? ''}'.trim();
      return mode.isNotEmpty && mode != 'null';
    }

    for (final s in candidates) {
      if (isSharingFor(idOf(s))) return s;
    }
    for (final s in candidates) {
      if (due(s)) return s;
    }
    for (final s in candidates) {
      if (s['vehicle_sharer'] is Map) return s;
    }
    for (final s in active) {
      if (applies(s)) return s;
    }
    final tomorrow = (today ?? bangkokToday()).add(const Duration(days: 1));
    for (final s in upcoming) {
      final date = parseCalendarDate(s['departure_date']);
      if (date != null &&
          date.year == tomorrow.year &&
          date.month == tomorrow.month &&
          date.day == tomorrow.day &&
          applies(s)) {
        return s;
      }
    }
    return null;
  }

  @override
  State<VehicleShareStatusCard> createState() => _VehicleShareStatusCardState();
}

enum _CardState { live, friend, due, prepare }

class _VehicleShareStatusCardState extends State<VehicleShareStatusCard>
    with WidgetsBindingObserver {
  VehicleLocationSharing get _sharing => VehicleLocationSharing.instance;

  /// ผลเช็คสิทธิ์ล่าสุด — null = ยังเช็คไม่เสร็จ (ยังไม่วาดสถานะ "พร้อม/ไม่พร้อม"
  /// จะได้ไม่กระพริบจากสีส้มเป็นสีเขียวตอนเปิดหน้า)
  LocationAccess? _access;
  bool _working = false;

  int get _scheduleId => int.parse('${widget.schedule['id']}');

  String get _plate {
    final vehicle = widget.schedule['vehicle'];
    return vehicle is Map ? '${vehicle['license_plate'] ?? ''}'.trim() : '';
  }

  String? get _dueMode {
    final mode = '${widget.schedule['share_location_mode'] ?? ''}'.trim();
    return mode.isEmpty || mode == 'null' ? null : mode;
  }

  String? get _friendName {
    final sharer = widget.schedule['vehicle_sharer'];
    if (sharer is! Map) return null;
    final name = '${sharer['name'] ?? ''}'.trim();
    return name.isEmpty ? 'เพื่อนสตาฟ' : name;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// กลับมาจากหน้าการตั้งค่า — สิทธิ์อาจเพิ่งถูกเปิด
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final access = await _sharing.checkAccess();
      if (mounted) setState(() => _access = access);
    } catch (e) {
      debugPrint('[VehicleShareStatusCard] access check failed: $e');
    }
  }

  _CardState _state() {
    if (_sharing.isSharingFor(_scheduleId)) return _CardState.live;
    if (_friendName != null) return _CardState.friend;
    if (_dueMode != null) return _CardState.due;
    return _CardState.prepare;
  }

  /// เปิดแชร์ด้วยมือ — ถ้าปัญหาคือ GPS ปิด/ปฏิเสธถาวร กล่องขอสิทธิ์ขึ้นไม่ได้แล้ว
  /// จึงพาไปหน้าการตั้งค่าแทน (กลับมาแล้วแอปจะเปิดแชร์ให้เองตอนกลับเข้าแอป)
  Future<void> _turnOn() async {
    if (_working) return;
    HapticFeedback.mediumImpact();
    setState(() => _working = true);
    try {
      final access = await _sharing.checkAccess();
      if (access == LocationAccess.serviceOff ||
          access == LocationAccess.deniedForever) {
        await _sharing.requestAccess();
        return;
      }

      if (!mounted) return;
      final ok = await _sharing.startManually(
        api: context.read<AppProvider>().api,
        scheduleId: _scheduleId,
        plate: _plate.isEmpty ? null : _plate,
        mode: _dueMode ?? VehicleLocationSharing.modePickup,
      );
      if (!mounted) return;
      if (ok) {
        AppSnack.success(context, 'เปิดแชร์ตำแหน่งรถแล้ว ลูกค้าเห็นรถแล้ว');
      } else {
        AppSnack.error(
          context,
          _sharing.error ?? 'เปิดแชร์ตำแหน่งรถไม่สำเร็จ ลองอีกครั้ง',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
        _checkAccess();
      }
    }
  }

  Future<void> _allow() async {
    if (_working) return;
    HapticFeedback.selectionClick();
    setState(() => _working = true);
    try {
      final access = await _sharing.requestAccess();
      if (mounted) setState(() => _access = access);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sharing,
      builder: (context, _) {
        final state = _state();
        final access = _access;

        switch (state) {
          case _CardState.live:
            return _Shell(
              tone: _Tone.good,
              icon: Icons.my_location_rounded,
              title: 'กำลังแชร์ตำแหน่งรถให้ลูกค้า',
              body: _liveBody(),
              onTap: widget.onOpenManifest,
              trailing: widget.onOpenManifest == null
                  ? null
                  : Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.mutedText(context),
                    ),
            );
          case _CardState.friend:
            final name = _friendName!;
            return _Shell(
              tone: _Tone.calm,
              icon: Icons.share_location_rounded,
              title: '$name กำลังแชร์ตำแหน่งรถอยู่',
              body:
                  'เครื่องนี้ไม่ต้องเปิด — ถ้า$nameไม่ได้นั่งรถคันนี้ '
                  'ให้เครื่องนี้แชร์แทนได้',
              action: _ActionButton(
                label: 'แชร์แทน',
                busy: _working || _sharing.busy,
                outlined: true,
                onPressed: _turnOn,
              ),
            );
          case _CardState.due:
            final problem = access == null || access == LocationAccess.ready
                ? null
                : access;
            return _Shell(
              tone: _Tone.warn,
              icon: Icons.location_off_rounded,
              title: 'ยังไม่ได้แชร์ตำแหน่งรถ',
              body: problem != null
                  ? VehicleLocationSharing.accessMessage(problem)
                  : 'ลูกค้ายังไม่เห็นว่ารถถึงไหน แตะเปิดแชร์ได้เลย',
              action: _ActionButton(
                label: switch (problem) {
                  LocationAccess.serviceOff => 'เปิด GPS',
                  LocationAccess.deniedForever => 'ตั้งค่า',
                  _ => 'เปิดแชร์',
                },
                busy: _working || _sharing.busy,
                onPressed: _turnOn,
              ),
            );
          case _CardState.prepare:
            // ยังไม่รู้ผลเช็คสิทธิ์ — ไม่วาดอะไรดีกว่าวาดผิดแล้วเปลี่ยนสี
            if (access == null) return const SizedBox.shrink();
            final when = _startsLabel();
            if (access == LocationAccess.ready) {
              return _Shell(
                tone: _Tone.calm,
                icon: Icons.check_circle_rounded,
                title: 'พร้อมแชร์ตำแหน่งรถแล้ว',
                body: when == null
                    ? 'เครื่องนี้จะเริ่มแชร์ตำแหน่งรถเองก่อนรถออก ไม่ต้องกดอะไร'
                    : 'เครื่องนี้จะเริ่มแชร์ตำแหน่งรถเอง $when ไม่ต้องกดอะไร',
              );
            }
            return _Shell(
              tone: _Tone.warn,
              icon: Icons.location_searching_rounded,
              title: 'อนุญาตตำแหน่งไว้ก่อนวันเดินทาง',
              body: access == LocationAccess.denied
                  ? 'มือถือเครื่องนี้จะเป็น GPS ของรถ${when == null ? '' : ' ($when)'} '
                        'อนุญาตตอนนี้ จะได้ไม่ต้องมากดตอนวุ่นหน้างาน'
                  : VehicleLocationSharing.accessMessage(access),
              action: _ActionButton(
                label: switch (access) {
                  LocationAccess.serviceOff => 'เปิด GPS',
                  LocationAccess.deniedForever => 'ตั้งค่า',
                  _ => 'อนุญาต',
                },
                busy: _working,
                onPressed: _allow,
              ),
            );
        }
      },
    );
  }

  String _liveBody() {
    final sentAt = _sharing.lastSentAt;
    final mode = _sharing.isSaving
        ? 'รับครบแล้ว · โหมดประหยัดแบต'
        : 'ลูกค้าเห็นรถอยู่';
    if (sentAt == null) return 'กำลังส่งตำแหน่งแรก...';
    final hh = sentAt.hour.toString().padLeft(2, '0');
    final mm = sentAt.minute.toString().padLeft(2, '0');
    return '$mode · ส่งล่าสุด $hh:$mm น.';
  }

  /// "วันนี้ 04:30 น." / "พรุ่งนี้ 04:30 น." จาก share_auto_starts_at (นาฬิกาไทย
  /// "Y-m-d H:i:s" ตรง ๆ) — ไม่แปลงโซน อ่านตัวเลขตามที่เซิร์ฟเวอร์ส่งมา
  String? _startsLabel() {
    final raw = '${widget.schedule['share_auto_starts_at'] ?? ''}'.trim();
    final match = RegExp(
      r'^(\d{4}-\d{2}-\d{2})[ T](\d{2}):(\d{2})',
    ).firstMatch(raw);
    if (match == null) return null;
    final date = parseCalendarDate(match.group(1));
    if (date == null) return null;
    final time = '${match.group(2)}:${match.group(3)} น.';
    final days = date.difference(bangkokToday()).inDays;
    return switch (days) {
      0 => 'วันนี้ $time',
      1 => 'พรุ่งนี้ $time',
      // เปิดคืนก่อนวันเดินทาง (รถออกหลังเที่ยงคืน) หรือไกลกว่านั้น
      _ => 'วันที่ ${date.day}/${date.month} $time',
    };
  }
}

enum _Tone { good, calm, warn }

class _Shell extends StatelessWidget {
  final _Tone tone;
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Shell({
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      _Tone.good => AppTheme.primaryColor,
      _Tone.calm => AppTheme.primaryColor,
      _Tone.warn => AppTheme.warningColor,
    };
    final radius = BorderRadius.circular(AppTheme.radiusMd);

    return Semantics(
      container: true,
      child: Material(
        color: tone == _Tone.warn
            ? AppTheme.tintOf(context, AppTheme.warningColor)
            : AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: tone == _Tone.warn
                ? AppTheme.warningColor.withValues(alpha: 0.45)
                : AppTheme.border(context).withValues(alpha: 0.55),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            // ปุ่มอยู่ท้ายแถวเดียวกับข้อความ — การ์ดเตี้ยลง ไม่ต้องมีบรรทัดปุ่มแยก
            // ไอคอนยังเกาะบรรทัดหัวข้อ ส่วนปุ่มอยู่กึ่งกลางแนวตั้งของทั้งแถว
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(icon, size: 20, color: accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: appFont(
                                fontSize: AppText.sizeLabel,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.onSurface(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              body,
                              style: appFont(
                                fontSize: AppText.sizeCaption,
                                height: 1.4,
                                color: AppTheme.mutedText(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 10), action!],
                if (trailing != null) ...[const SizedBox(width: 6), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool busy;
  final bool outlined;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            label,
            maxLines: 1,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w800,
            ),
          );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
    );
    // ปุ่มเล็กท้ายแถว — ตัวปุ่มสูง 32 แต่พื้นที่แตะยังเต็ม 48 ตามค่าเริ่มต้นของ
    // Material (materialTapTargetSize แบบ padded) แตะพลาดยากเหมือนเดิม
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    const minimumSize = Size(0, 32);

    if (outlined) {
      return OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
          padding: padding,
          minimumSize: minimumSize,
          shape: shape,
        ),
        child: child,
      );
    }
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.warningColor,
        foregroundColor: Colors.white,
        padding: padding,
        minimumSize: minimumSize,
        shape: shape,
      ),
      child: child,
    );
  }
}
