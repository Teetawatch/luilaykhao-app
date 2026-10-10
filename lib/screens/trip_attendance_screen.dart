import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/travel_widgets.dart';
import 'seat_handover_screen.dart';

/// "ไปครบไหม" — บอกทีมงานล่วงหน้าว่าใครในใบจองไม่ไป
///
/// ใบจอง 4 คนที่มาจริง 3 คน สตาฟเคยรู้ตอนยืนรอคนที่สี่อยู่ที่จุดรับ หน้านี้ให้
/// คนจองติ๊กทั้งใบแล้วกดยืนยัน (เพื่อนในใบจองเปลี่ยนได้เฉพาะของตัวเอง ทันทีที่กด)
/// กติกาทั้งหมด — ใครแก้อะไรได้ ถึงเมื่อไหร่ — มาจาก TripAttendanceService
///
/// แจ้งไม่ไปไม่ใช่การยกเลิก ถ้ามีคนไปแทน ทางที่ถูกคือส่งต่อที่นั่ง (ชื่อในประกัน
/// ต้องตรงตัวคน) หน้านี้จึงมีทางลัดไปที่นั่นด้วย
class TripAttendanceScreen extends StatefulWidget {
  final String bookingRef;

  const TripAttendanceScreen({super.key, required this.bookingRef});

  @override
  State<TripAttendanceScreen> createState() => _TripAttendanceScreenState();
}

class _TripAttendanceScreenState extends State<TripAttendanceScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  /// คนที่คนจองติ๊กว่า "ไม่ไป" (ยังไม่ได้กดยืนยัน)
  Set<int> _notGoing = {};

  /// id ที่เพื่อนกำลังเปลี่ยนสถานะของตัวเองอยู่
  final Set<int> _updating = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppProvider>().bookingAttendance(
        widget.bookingRef,
      );
      if (!mounted) return;
      _apply(data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(Map<String, dynamic> data) {
    setState(() {
      _data = data;
      _notGoing = _people(data)
          .where((p) => p['not_going'] == true)
          .map((p) => (p['id'] as num).toInt())
          .toSet();
    });
  }

  List<Map<String, dynamic>> _people(Map<String, dynamic>? data) =>
      asList(data?['passengers']).map(asMap).toList();

  bool get _isOwner => _data?['viewer_is_owner'] == true;
  bool get _open => _data?['open'] == true;

  Future<void> _confirmAll() async {
    if (_saving) return;
    final people = _people(_data);
    final going = people.length - _notGoing.length;

    if (going == 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'ไม่มีใครไปเลย?',
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'การแจ้งไม่ไปไม่ใช่การยกเลิกการจอง และไม่ได้คืนเงินอัตโนมัติ '
            'ถ้าต้องการยกเลิกหรือเลื่อนรอบ ทักทีมงานในแชทได้เลย',
            style: appFont(fontSize: AppText.sizeBody, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('กลับไปแก้'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final result = await context.read<AppProvider>().confirmBookingAttendance(
        widget.bookingRef,
        _notGoing.toList(),
      );
      if (!mounted) return;
      _apply(result.data);
      AppSnack.success(context, result.message);
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// เพื่อนเปลี่ยนสถานะของตัวเอง — บันทึกทันที ไม่ต้องกดยืนยันอีกรอบ
  Future<void> _toggleSelf(int id, bool notGoing) async {
    if (_updating.contains(id)) return;
    setState(() => _updating.add(id));
    HapticFeedback.selectionClick();
    try {
      final result = await context.read<AppProvider>().setPassengerNotGoing(
        widget.bookingRef,
        id,
        notGoing: notGoing,
      );
      if (!mounted) return;
      _apply(result.data);
      AppSnack.success(context, result.message);
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  Future<void> _openHandover() async {
    try {
      final booking = await context.read<AppProvider>().booking(
        widget.bookingRef,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SeatHandoverScreen(booking: booking)),
      );
      if (mounted) _load();
    } catch (_) {
      if (mounted) AppSnack.error(context, 'เปิดหน้าส่งต่อที่นั่งไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final people = _people(data);
    final total = people.length;
    final going = total - _notGoing.length;
    final confirmedAt = textOf(data?['confirmed_at']);

    Widget body;
    if (_loading && data == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && data == null) {
      body = _Message(
        icon: Icons.cloud_off_rounded,
        text: _error!,
        action: TextButton(onPressed: _load, child: const Text('ลองใหม่')),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(context, radius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    going == total ? 'ไปครบ $total คน' : 'ไป $going จาก $total คน',
                    style: appFont(
                      fontSize: AppText.sizeH2,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    !_open
                        ? textOf(data?['closed_reason'], 'แก้ไขไม่ได้แล้ว')
                        : _isOwner
                        ? (confirmedAt.isEmpty
                              ? 'ติ๊กออกคนที่ไปไม่ได้ แล้วกดยืนยัน — ทีมงานจะได้ไม่ต้องรอที่จุดขึ้นรถ'
                              : 'ยืนยันแล้ว แก้ได้จนถึงเวลารถออก')
                        : 'เปลี่ยนได้เฉพาะชื่อของคุณ — คนจองดูแลคนอื่นในใบนี้',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      color: AppTheme.mutedText(context),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final person in people) ...[
              _PersonRow(
                person: person,
                going: !_notGoing.contains((person['id'] as num).toInt()),
                editable: _open && person['can_edit'] == true,
                busy: _updating.contains((person['id'] as num).toInt()),
                onChanged: (value) {
                  final id = (person['id'] as num).toInt();
                  if (_isOwner) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      value ? _notGoing.remove(id) : _notGoing.add(id);
                    });
                  } else {
                    _toggleSelf(id, !value);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'มีคนไปแทนได้ไหม?',
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'แจ้งไม่ไปไม่ใช่การยกเลิก และไม่ได้คืนเงินอัตโนมัติ ถ้ามีเพื่อนไปแทน '
                    'ให้ส่งต่อที่นั่ง ชื่อในประกันจะได้ตรงตัวคน',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      color: AppTheme.mutedText(context),
                      height: 1.45,
                    ),
                  ),
                  if (_open) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: _openHandover,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('ส่งต่อที่นั่งให้คนอื่นไปแทน'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(
          'ไปครบไหม',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: body,
      bottomNavigationBar: data != null && _open && _isOwner
          ? Container(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                10 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                border: Border(top: BorderSide(color: AppTheme.border(context))),
              ),
              child: PrimaryCTAButton(
                label: 'ยืนยัน ไป $going จาก $total คน',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _confirmAll,
              ),
            )
          : null,
    );
  }
}

class _PersonRow extends StatelessWidget {
  final Map<String, dynamic> person;
  final bool going;
  final bool editable;
  final bool busy;
  final ValueChanged<bool> onChanged;

  const _PersonRow({
    required this.person,
    required this.going,
    required this.editable,
    required this.busy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final name = textOf(person['name'], '-');
    final fullName = textOf(person['full_name']);
    final checkedIn = person['checked_in'] == true;
    final mine = person['is_mine'] == true;

    final status = checkedIn
        ? 'ขึ้นรถแล้ว'
        : going
        ? 'ไป'
        : 'ไม่ไป';
    final statusColor = checkedIn || going
        ? AppTheme.primaryColor
        : AppTheme.warningColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mine ? '$name (คุณ)' : name,
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                if (fullName.isNotEmpty && fullName != name)
                  Text(
                    fullName,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                Text(
                  status,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Switch.adaptive(
              value: checkedIn || going,
              onChanged: editable && !checkedIn ? onChanged : null,
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.mutedText(context)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeBody,
                color: AppTheme.mutedText(context),
                height: 1.45,
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
