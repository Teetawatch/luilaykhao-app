import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/chat_rest_stop.dart'
    show RestStopSheetFrame, RestStopSheetLabel, restStopFieldDecoration;
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';
import '../widgets/travel_widgets.dart';

/// ห้องพักของรอบ — ลูกทริปเห็นห้องของตัวเอง (และห้องทั้งหมด) ทีมงานจัดคนเข้าห้อง
///
/// payload มาจาก ScheduleRoomService::present() ทั้งก้อนทุกครั้งที่แก้ จึงไม่ต้อง
/// ประกอบสถานะเองฝั่งนี้ — แก้อะไรก็แทนทั้งก้อนด้วยของที่เซิร์ฟเวอร์ตอบ
class TripRoomsScreen extends StatefulWidget {
  final int scheduleId;
  final bool canManage;

  const TripRoomsScreen({
    super.key,
    required this.scheduleId,
    required this.canManage,
  });

  @override
  State<TripRoomsScreen> createState() => _TripRoomsScreenState();
}

List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

int _int(dynamic v) => int.tryParse('$v') ?? 0;

class _TripRoomsScreenState extends State<TripRoomsScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  AppProvider get _app => context.read<AppProvider>();

  Future<void> _load() async {
    try {
      final data = await _app.loadScheduleRooms(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  /// เรียก API ที่คืน payload ทั้งก้อน แล้วแทนที่หน้าจอ
  Future<void> _run(
    Future<Map<String, dynamic>> Function() call, {
    String? done,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = await call();
      if (!mounted) return;
      setState(() => _data = data);
      if (done != null) AppSnack.show(context, done);
    } catch (e) {
      if (mounted) {
        AppSnack.show(context, e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<T?> _sheet<T>(Widget child) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusLg),
      ),
    ),
    builder: (_) => child,
  );

  List<Map<String, dynamic>> get _rooms => _maps(_data?['rooms']);

  List<String?> get _stays {
    final raw = (_data?['stays'] as List? ?? const [])
        .map((s) => s?.toString())
        .toList();
    return raw.isEmpty ? [null] : raw;
  }

  List<Map<String, dynamic>> _unassignedFor(String? stay) {
    for (final u in _maps(_data?['unassigned'])) {
      if (u['stay_label']?.toString() == stay) return _maps(u['passengers']);
    }
    return const [];
  }

  // ── การกระทำของทีมงาน ────────────────────────────────────────────────────

  Future<void> _autoAssign() async {
    final draft = await _sheet<_AutoDraft>(
      _AutoAssignSheet(stays: _stays.whereType<String>().toList()),
    );
    if (draft == null) return;
    await _run(
      () => _app.autoAssignScheduleRooms(
        widget.scheduleId,
        roomSize: draft.roomSize,
        stayLabel: draft.stayLabel,
        prefix: draft.prefix,
      ),
      done: 'จัดห้องให้แล้ว ปรับเองต่อได้',
    );
  }

  Future<void> _addRoom({String? stay}) async {
    final draft = await _sheet<_RoomDraft>(
      _RoomEditSheet(
        stays: _stays.whereType<String>().toList(),
        stayLabel: stay,
      ),
    );
    if (draft == null) return;
    await _run(
      () => _app.createScheduleRoom(
        widget.scheduleId,
        name: draft.name,
        stayLabel: draft.stayLabel,
        note: draft.note,
      ),
    );
  }

  Future<void> _editRoom(Map<String, dynamic> room) async {
    final draft = await _sheet<_RoomDraft>(
      _RoomEditSheet(
        name: room['name']?.toString(),
        note: room['note']?.toString(),
        editing: true,
      ),
    );
    if (draft == null) return;
    if (draft.delete) {
      await _run(
        () => _app.deleteScheduleRoom(widget.scheduleId, _int(room['id'])),
        done: 'ลบ${room['name']}แล้ว',
      );
      return;
    }
    await _run(
      () => _app.updateScheduleRoom(
        widget.scheduleId,
        _int(room['id']),
        name: draft.name,
        note: draft.note,
      ),
    );
  }

  /// เลือกคนเข้าห้อง — คนในห้องนี้ + คนที่ยังไม่มีห้องในที่พักเดียวกัน
  Future<void> _pickGuests(Map<String, dynamic> room) async {
    final current = _maps(room['guests']);
    final candidates = [
      ...current,
      ..._unassignedFor(room['stay_label']?.toString()),
    ];
    final picked = await _sheet<List<int>>(
      _GuestPickerSheet(
        roomName: room['name']?.toString() ?? '',
        candidates: candidates,
        selected: current.map((g) => _int(g['passenger_id'])).toSet(),
      ),
    );
    if (picked == null) return;
    await _run(
      () => _app.setScheduleRoomGuests(
        widget.scheduleId,
        _int(room['id']),
        picked,
      ),
    );
  }

  Future<void> _removeGuest(Map<String, dynamic> room, int passengerId) async {
    final ids = _maps(room['guests'])
        .map((g) => _int(g['passenger_id']))
        .where((id) => id != passengerId)
        .toList();
    await _run(
      () =>
          _app.setScheduleRoomGuests(widget.scheduleId, _int(room['id']), ids),
    );
  }

  /// แตะคนที่ยังไม่มีห้อง → เลือกห้องให้
  Future<void> _placeGuest(String? stay, Map<String, dynamic> passenger) async {
    final rooms = _rooms
        .where((r) => r['stay_label']?.toString() == stay)
        .toList();
    if (rooms.isEmpty) {
      AppSnack.show(context, 'เพิ่มห้องก่อน แล้วค่อยจัดคนเข้า');
      return;
    }
    final room = await _sheet<Map<String, dynamic>>(
      RestStopSheetFrame(
        icon: Icons.bed_rounded,
        title: 'ให้ ${passenger['name']} พักห้องไหน',
        children: [
          for (final r in rooms)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.meeting_room_outlined),
              title: Text(
                r['name']?.toString() ?? '',
                style: appFont(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _maps(r['guests']).isEmpty
                    ? 'ยังว่าง'
                    : _maps(r['guests']).map((g) => g['name']).join(', '),
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  color: AppTheme.mutedText(context),
                ),
              ),
              onTap: () => Navigator.pop(context, r),
            ),
        ],
      ),
    );
    if (room == null) return;
    final ids = [
      ..._maps(room['guests']).map((g) => _int(g['passenger_id'])),
      _int(passenger['passenger_id']),
    ];
    await _run(
      () =>
          _app.setScheduleRoomGuests(widget.scheduleId, _int(room['id']), ids),
    );
  }

  Future<void> _announce() async {
    final stays = _stays;
    String? stay = stays.first;
    if (stays.length > 1) {
      final picked = await _sheet<String>(
        RestStopSheetFrame(
          icon: Icons.campaign_rounded,
          title: 'ประกาศห้องพักของที่ไหน',
          children: [
            for (final s in stays)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  s ?? 'ห้องที่ไม่ได้ระบุที่พัก',
                  style: appFont(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(context, s ?? ''),
              ),
          ],
        ),
      );
      if (picked == null) return;
      stay = picked.isEmpty ? null : picked;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'ประกาศห้องพักในแชท?',
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'รายชื่อทุกห้องจะขึ้นในห้องแชท และทุกคนได้แจ้งเตือนว่าพักห้องไหนกับใคร',
            style: appFont(fontSize: AppText.sizeBody),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'ยังก่อน',
                style: appFont(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'ประกาศ',
                style: appFont(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    HapticFeedback.mediumImpact();
    await _run(
      () => _app.announceScheduleRooms(widget.scheduleId, stayLabel: stay),
      done: 'ประกาศในแชทแล้ว',
    );
  }

  // ── หน้าจอ ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final manage = widget.canManage;
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          manage ? 'จัดห้องพัก' : 'ห้องพัก',
          style: appFont(
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (manage && _data != null)
            PopupMenuButton<String>(
              tooltip: 'เมนู',
              onSelected: (v) => switch (v) {
                'auto' => _autoAssign(),
                'add' => _addRoom(),
                'announce' => _announce(),
                _ => null,
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'auto',
                  child: Text('จัดอัตโนมัติ', style: appFont()),
                ),
                PopupMenuItem(
                  value: 'add',
                  child: Text('เพิ่มห้อง', style: appFont()),
                ),
                PopupMenuItem(
                  value: 'announce',
                  child: Text('ประกาศในแชท', style: appFont()),
                ),
              ],
            ),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_data == null && _error == null) {
      return const SkeletonList(count: 4, padding: EdgeInsets.only(top: 8));
    }
    if (_data == null) {
      return ScrollableEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'โหลดห้องพักไม่สำเร็จ',
        body: _error,
        actionLabel: 'ลองใหม่',
        onAction: _load,
      );
    }

    final rooms = _rooms;
    final manage = widget.canManage;
    if (rooms.isEmpty && !manage) {
      return const ScrollableEmptyState(
        icon: Icons.bed_rounded,
        title: 'ทีมงานยังไม่ได้จัดห้องพัก',
        body: 'จัดเสร็จเมื่อไรจะแจ้งในแชทว่าคุณพักห้องไหนกับใครครับ',
      );
    }

    final myIds = (_data?['my_room_ids'] as List? ?? const [])
        .map(_int)
        .toSet();
    final myRooms = rooms.where((r) => myIds.contains(_int(r['id']))).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (myRooms.isNotEmpty) ...[
          const _SectionLabel('ห้องของคุณ'),
          for (final r in myRooms) _MyRoomCard(room: r),
          const SizedBox(height: 12),
        ],
        if (manage && rooms.isEmpty)
          _ManageIntro(onAuto: _autoAssign, onAdd: _addRoom),
        if (manage)
          _ProgressLine(
            total: _int(_data?['total_passengers']),
            unassigned: _maps(
              _data?['unassigned'],
            ).fold<int>(0, (n, u) => n + _maps(u['passengers']).length),
            stays: _stays.length,
          ),
        for (final stay in _stays) ...[
          if (_stays.length > 1 || stay != null)
            _SectionLabel(stay ?? 'ไม่ระบุที่พัก'),
          for (final r in rooms.where(
            (r) => r['stay_label']?.toString() == stay,
          ))
            _RoomCard(
              room: r,
              manage: manage,
              onEdit: () => _editRoom(r),
              onPick: () => _pickGuests(r),
              onRemove: (id) => _removeGuest(r, id),
            ),
          if (manage && _unassignedFor(stay).isNotEmpty)
            _UnassignedCard(
              passengers: _unassignedFor(stay),
              onTap: (p) => _placeGuest(stay, p),
            ),
          if (manage && rooms.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addRoom(stay: stay),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'เพิ่มห้อง',
                  style: appFont(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (manage && rooms.isNotEmpty) ...[
          const SizedBox(height: 8),
          PrimaryCTAButton(
            label: 'ประกาศห้องพักในแชท',
            icon: Icons.campaign_rounded,
            onPressed: _busy ? null : _announce,
          ),
        ],
      ],
    );
  }
}

// ── ชิ้นส่วนของหน้า ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
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

class _MyRoomCard extends StatelessWidget {
  final Map<String, dynamic> room;

  const _MyRoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final guests = _maps(room['guests']);
    final others = guests.where((g) => g['is_mine'] != true).toList();
    final note = room['note']?.toString() ?? '';
    final stay = room['stay_label']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bed_rounded, color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stay.isNotEmpty)
                  Text(
                    stay,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                Text(
                  room['name']?.toString() ?? '',
                  style: appFont(
                    fontSize: AppText.sizeH2,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                Text(
                  others.isEmpty
                      ? 'พักกันเองในกลุ่ม'
                      : 'พักกับ ${others.map((g) => g['name']).join(', ')}',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
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
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final bool manage;
  final VoidCallback onEdit;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;

  const _RoomCard({
    required this.room,
    required this.manage,
    required this.onEdit,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final guests = _maps(room['guests']);
    final note = room['note']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.meeting_room_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: room['name']?.toString() ?? '',
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      if (note.isNotEmpty)
                        TextSpan(
                          text: '  $note',
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Text(
                '${guests.length} คน',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedText(context),
                ),
              ),
              if (manage)
                IconButton(
                  tooltip: 'แก้ไขห้อง',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in guests)
                manage
                    ? InputChip(
                        label: Text(
                          g['name']?.toString() ?? '',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onDeleted: () => onRemove(_int(g['passenger_id'])),
                        deleteButtonTooltipMessage: 'เอาออกจากห้อง',
                      )
                    : Chip(
                        label: Text(
                          g['name']?.toString() ?? '',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: g['is_mine'] == true
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: g['is_mine'] == true
                                ? AppTheme.primaryColor
                                : null,
                          ),
                        ),
                      ),
              if (manage)
                ActionChip(
                  avatar: const Icon(Icons.person_add_alt_rounded, size: 16),
                  label: Text(
                    'จัดคนเข้า',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: onPick,
                ),
              if (!manage && guests.isEmpty)
                Text(
                  'ยังว่าง',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
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

class _UnassignedCard extends StatelessWidget {
  final List<Map<String, dynamic>> passengers;
  final ValueChanged<Map<String, dynamic>> onTap;

  const _UnassignedCard({required this.passengers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ยังไม่มีห้อง ${passengers.length} คน — แตะชื่อเพื่อเลือกห้อง',
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in passengers)
                ActionChip(
                  label: Text(
                    '${p['name']}${_genderMark(p['gender'])}',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => onTap(p),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _genderMark(dynamic g) => switch (g) {
    'male' => ' (ช)',
    'female' => ' (ญ)',
    _ => '',
  };
}

class _ProgressLine extends StatelessWidget {
  final int total;
  final int unassigned;
  final int stays;

  const _ProgressLine({
    required this.total,
    required this.unassigned,
    required this.stays,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'ยังไม่มีผู้เดินทางที่ยืนยันแล้วในรอบนี้',
          style: appFont(
            fontSize: AppText.sizeLabel,
            color: AppTheme.mutedText(context),
          ),
        ),
      );
    }
    final done = unassigned == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Text(
        done
            ? 'ทุกคนมีห้องแล้ว ($total คน)'
            : 'ยังไม่มีห้อง $unassigned คน จาก $total คน'
                  '${stays > 1 ? ' (นับทุกที่พัก)' : ''}',
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w700,
          color: done ? AppTheme.primaryColor : AppTheme.warningColor,
        ),
      ),
    );
  }
}

class _ManageIntro extends StatelessWidget {
  final VoidCallback onAuto;
  final VoidCallback onAdd;

  const _ManageIntro({required this.onAuto, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'จัดห้องพักให้ลูกทริป',
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'กด "จัดอัตโนมัติ" ให้คนที่จองมาด้วยกันอยู่ห้องเดียวกัน และคนที่มาคนเดียว'
            'จับคู่กับเพศเดียวกัน แล้วค่อยปรับเอง เสร็จแล้วประกาศในแชท ทุกคนจะรู้ว่าพักห้องไหนกับใคร',
            style: appFont(
              fontSize: AppText.sizeLabel,
              color: AppTheme.mutedText(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          PrimaryCTAButton(
            label: 'จัดอัตโนมัติ',
            icon: Icons.auto_awesome_rounded,
            onPressed: onAuto,
          ),
          TextButton(
            onPressed: onAdd,
            child: Text(
              'เพิ่มห้องเอง',
              style: appFont(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ชีต ───────────────────────────────────────────────────────────────────

class _AutoDraft {
  final int roomSize;
  final String? stayLabel;
  final String prefix;

  const _AutoDraft(this.roomSize, this.stayLabel, this.prefix);
}

class _AutoAssignSheet extends StatefulWidget {
  final List<String> stays;

  const _AutoAssignSheet({required this.stays});

  @override
  State<_AutoAssignSheet> createState() => _AutoAssignSheetState();
}

class _AutoAssignSheetState extends State<_AutoAssignSheet> {
  int _size = 2;
  late final _stay = TextEditingController(
    text: widget.stays.length == 1 ? widget.stays.first : '',
  );
  final _prefix = TextEditingController(text: 'ห้อง');

  @override
  void dispose() {
    _stay.dispose();
    _prefix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.auto_awesome_rounded,
      title: 'จัดห้องอัตโนมัติ',
      subtitle: 'จัดเฉพาะคนที่ยังไม่มีห้อง ห้องที่จัดไว้แล้วไม่ถูกแตะ',
      footer: PrimaryCTAButton(
        label: 'จัดห้อง',
        icon: Icons.check_rounded,
        onPressed: () => Navigator.pop(
          context,
          _AutoDraft(
            _size,
            _stay.text.trim().isEmpty ? null : _stay.text.trim(),
            _prefix.text.trim().isEmpty ? 'ห้อง' : _prefix.text.trim(),
          ),
        ),
      ),
      children: [
        const RestStopSheetLabel('ห้องละกี่คน'),
        Wrap(
          spacing: 8,
          children: [
            for (final n in const [2, 3, 4, 6])
              ChoiceChip(
                label: Text(
                  '$n คน',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selected: _size == n,
                onSelected: (_) => setState(() => _size = n),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const RestStopSheetLabel('ชื่อห้องขึ้นต้นด้วย'),
        TextField(
          controller: _prefix,
          maxLength: 40,
          decoration: restStopFieldDecoration(context, 'ห้อง / บ้าน / เต็นท์'),
        ),
        const SizedBox(height: 10),
        const RestStopSheetLabel('ที่พัก (ไม่บังคับ — ค้างหลายที่ค่อยใส่)'),
        TextField(
          controller: _stay,
          maxLength: 80,
          decoration: restStopFieldDecoration(
            context,
            'เช่น คืนแรก · ภูชี้ฟ้า',
          ),
        ),
      ],
    );
  }
}

class _RoomDraft {
  final String name;
  final String? note;
  final String? stayLabel;
  final bool delete;

  const _RoomDraft({
    this.name = '',
    this.note,
    this.stayLabel,
    this.delete = false,
  });
}

class _RoomEditSheet extends StatefulWidget {
  final String? name;
  final String? note;
  final String? stayLabel;
  final List<String> stays;
  final bool editing;

  const _RoomEditSheet({
    this.name,
    this.note,
    this.stayLabel,
    this.stays = const [],
    this.editing = false,
  });

  @override
  State<_RoomEditSheet> createState() => _RoomEditSheetState();
}

class _RoomEditSheetState extends State<_RoomEditSheet> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _note = TextEditingController(text: widget.note ?? '');
  late final _stay = TextEditingController(
    text:
        widget.stayLabel ??
        (widget.stays.length == 1 ? widget.stays.first : ''),
  );

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _stay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _name.text.trim();
    return RestStopSheetFrame(
      icon: Icons.meeting_room_outlined,
      title: widget.editing ? 'แก้ไขห้อง' : 'เพิ่มห้อง',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryCTAButton(
            label: 'บันทึก',
            icon: Icons.check_rounded,
            onPressed: trimmed.isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    _RoomDraft(
                      name: trimmed,
                      note: _note.text.trim().isEmpty
                          ? null
                          : _note.text.trim(),
                      stayLabel: _stay.text.trim().isEmpty
                          ? null
                          : _stay.text.trim(),
                    ),
                  ),
          ),
          if (widget.editing)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, const _RoomDraft(delete: true)),
              child: Text(
                'ลบห้องนี้',
                style: appFont(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
        ],
      ),
      children: [
        TextField(
          controller: _name,
          autofocus: !widget.editing,
          maxLength: 60,
          onChanged: (_) => setState(() {}),
          decoration: restStopFieldDecoration(
            context,
            'ชื่อห้อง เช่น ห้อง 204',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLength: 200,
          decoration: restStopFieldDecoration(
            context,
            'หมายเหตุ เช่น ชั้น 2 / เตียงคู่',
          ),
        ),
        if (!widget.editing) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _stay,
            maxLength: 80,
            decoration: restStopFieldDecoration(
              context,
              'ที่พัก (ไม่บังคับ) เช่น คืนแรก · ภูชี้ฟ้า',
            ),
          ),
        ],
      ],
    );
  }
}

class _GuestPickerSheet extends StatefulWidget {
  final String roomName;
  final List<Map<String, dynamic>> candidates;
  final Set<int> selected;

  const _GuestPickerSheet({
    required this.roomName,
    required this.candidates,
    required this.selected,
  });

  @override
  State<_GuestPickerSheet> createState() => _GuestPickerSheetState();
}

class _GuestPickerSheetState extends State<_GuestPickerSheet> {
  late final Set<int> _picked = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.person_add_alt_rounded,
      title: 'ใครพัก${widget.roomName}',
      subtitle: 'เลือกจากคนในห้องนี้และคนที่ยังไม่มีห้อง',
      footer: PrimaryCTAButton(
        label: 'บันทึก (${_picked.length} คน)',
        icon: Icons.check_rounded,
        onPressed: () => Navigator.pop(context, _picked.toList()),
      ),
      children: [
        if (widget.candidates.isEmpty)
          Text(
            'ทุกคนมีห้องแล้ว — ย้ายคนจากห้องอื่นได้โดยเอาออกจากห้องเดิมก่อน',
            style: appFont(color: AppTheme.mutedText(context)),
          ),
        for (final p in widget.candidates)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _picked.contains(_int(p['passenger_id'])),
            onChanged: (v) => setState(() {
              final id = _int(p['passenger_id']);
              v == true ? _picked.add(id) : _picked.remove(id);
            }),
            title: Text(
              p['name']?.toString() ?? '',
              style: appFont(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
