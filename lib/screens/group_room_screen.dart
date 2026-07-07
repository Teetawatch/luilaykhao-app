import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/group_plan.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/vehicle_seat_map.dart';
import 'payment_screen.dart';

/// Live "group room" for the Group Trip Invite feature. The host shares the
/// invite code; friends join, claim a seat and fill their details, and everyone
/// sees the roster update in real time. The host pays once for the whole group.
class GroupRoomScreen extends StatefulWidget {
  final GroupPlan? initialPlan;
  final String? inviteCode;

  const GroupRoomScreen({super.key, this.initialPlan, this.inviteCode})
      : assert(initialPlan != null || inviteCode != null);

  /// Host entry point: ask for group size + name, create the plan, and open
  /// the room. Used from the trip detail screen once a schedule is chosen.
  static Future<void> startFlow(BuildContext context, int scheduleId) async {
    final app = context.read<AppProvider>();
    if (!app.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบเพื่อสร้างกลุ่ม')),
      );
      return;
    }

    final setup = await showDialog<_GroupSetup>(
      context: context,
      builder: (_) => const _GroupSetupDialog(),
    );
    if (setup == null || !context.mounted) return;

    try {
      final data = await app.createGroupPlan(scheduleId, setup.size, setup.name);
      final plan = GroupPlan.fromJson(data);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupRoomScreen(initialPlan: plan)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'สร้างกลุ่มไม่สำเร็จ'),
        ),
      );
    }
  }

  @override
  State<GroupRoomScreen> createState() => _GroupRoomScreenState();
}

class _GroupSetup {
  final int size;
  final String? name;
  const _GroupSetup(this.size, this.name);
}

class _GroupSetupDialog extends StatefulWidget {
  const _GroupSetupDialog();

  @override
  State<_GroupSetupDialog> createState() => _GroupSetupDialogState();
}

class _GroupSetupDialogState extends State<_GroupSetupDialog> {
  int _size = 2;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'ชวนเพื่อนมาเป็นกลุ่ม',
        style: appFont(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'จองที่นั่งสำหรับกี่คน? (รวมคุณ)',
            style: appFont(
              fontSize: 13,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _size > 2 ? () => setState(() => _size--) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '$_size',
                  style: appFont(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _size < 20 ? () => setState(() => _size++) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'ชื่อกลุ่ม (ไม่บังคับ)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _GroupSetup(
              _size,
              _name.text.trim().isEmpty ? null : _name.text.trim(),
            ),
          ),
          child: const Text('สร้างกลุ่ม'),
        ),
      ],
    );
  }
}

class _GroupRoomScreenState extends State<GroupRoomScreen> {
  GroupPlan? _plan;
  Map<String, dynamic>? _seatMap;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  VoidCallback? _realtimeDisposer;

  // Host's pickup choice for the whole group booking.
  String? _selectedRegion;
  int? _selectedPickupPointId;

  AppProvider get _app => context.read<AppProvider>();

  String get _code => _plan?.inviteCode ?? widget.inviteCode ?? '';

  int get _myUserId => int.tryParse('${_app.user?['id']}') ?? 0;

  GroupPlanMember? get _myMember => _plan?.memberFor(_myUserId);

  bool get _isHost => _plan != null && _plan!.hostUserId == _myUserId;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _realtimeDisposer?.call();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      // Friends who arrive via an invite link auto-join before viewing.
      if (widget.initialPlan == null && widget.inviteCode != null) {
        final data = await _app.joinGroupPlan(widget.inviteCode!);
        _plan = GroupPlan.fromJson(data);
      } else if (_plan != null) {
        // Refresh with viewer-aware data.
        final data = await _app.fetchGroupPlan(_plan!.inviteCode);
        _plan = GroupPlan.fromJson(data);
      }
      if (!mounted) return;
      setState(() => _loading = false);
      await _subscribe();
      await _loadSeatMap();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'เข้าร่วมกลุ่มไม่สำเร็จ';
      });
    }
  }

  Future<void> _subscribe() async {
    if (_code.isEmpty) return;
    _realtimeDisposer = await _app.subscribeGroup(_code, (payload) {
      if (!mounted) return;
      try {
        setState(() => _plan = GroupPlan.fromJson(payload));
      } catch (_) {}
    });
  }

  Future<void> _loadSeatMap() async {
    final scheduleId = _plan?.schedule?.id;
    if (scheduleId == null) return;
    try {
      final map = await _app.seats(scheduleId);
      if (mounted) setState(() => _seatMap = map);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    if (_code.isEmpty) return;
    try {
      final data = await _app.fetchGroupPlan(_code);
      if (mounted) setState(() => _plan = GroupPlan.fromJson(data));
      await _loadSeatMap();
    } catch (_) {}
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _share() async {
    final plan = _plan;
    if (plan == null) return;
    final title = plan.trip?.title ?? 'ทริปของเรา';
    final link = 'luilaykhao://group/${plan.inviteCode}';
    final text =
        'มาเที่ยว "$title" ไปด้วยกัน! 🏞️\nเข้าร่วมกลุ่มของเราในแอปลุยเลเขา:\n$link\n(รหัสกลุ่ม: ${plan.inviteCode})';
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: title));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      _toast('คัดลอกลิงก์ชวนเพื่อนแล้ว');
    }
  }

  Future<void> _openSeatPicker() async {
    if (_seatMap == null) {
      await _loadSeatMap();
    }
    if (!mounted || _seatMap == null) {
      _toast('กำลังโหลดผังที่นั่ง');
      return;
    }

    final result = await showModalBottomSheet<_SeatClaim>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeatPickerSheet(
        seatMap: _seatMap!,
        plan: _plan!,
        myUserId: _myUserId,
        defaultName: _myMember?.passengerName ?? '${_app.user?['name'] ?? ''}',
        defaultPhone: '${_app.user?['phone'] ?? ''}',
      ),
    );

    if (result == null) return;
    await _claimSeat(result);
  }

  Future<void> _claimSeat(_SeatClaim claim) async {
    setState(() => _busy = true);
    try {
      final data = await _app.claimGroupSeat(_code, {
        'seat_id': claim.seatId,
        'name': claim.name,
        if (claim.phone.isNotEmpty) 'phone': claim.phone,
      });
      if (!mounted) return;
      setState(() => _plan = GroupPlan.fromJson(data));
      _toast('เลือกที่นั่ง ${claim.seatId} แล้ว');
      await _loadSeatMap();
    } catch (e) {
      _toast(e is ApiException ? e.message : 'เลือกที่นั่งไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _releaseSeat() async {
    setState(() => _busy = true);
    try {
      final data = await _app.releaseGroupSeat(_code);
      if (!mounted) return;
      setState(() => _plan = GroupPlan.fromJson(data));
      await _loadSeatMap();
    } catch (e) {
      _toast(e is ApiException ? e.message : 'ปล่อยที่นั่งไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkout() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() => _busy = true);
    try {
      final booking = await _app.checkoutGroupPlan(
        _code,
        pickupPointId: _selectedPickupPointId,
        pickupRegion: _selectedRegion,
      );
      if (!mounted) return;
      final ref = booking['booking_ref']?.toString() ?? '';
      if (ref.isEmpty) {
        _toast('สร้างการจองไม่สำเร็จ');
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PaymentScreen(bookingRef: ref)),
      );
    } catch (e) {
      _toast(e is ApiException ? e.message : 'สร้างการจองกลุ่มไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leaveOrCancel() async {
    final plan = _plan;
    if (plan == null) return;
    final isHost = _isHost;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHost ? 'ยกเลิกกลุ่ม?' : 'ออกจากกลุ่ม?'),
        content: Text(isHost
            ? 'การยกเลิกจะปล่อยที่นั่งทั้งหมดและปิดกลุ่มนี้'
            : 'คุณจะออกจากกลุ่มและปล่อยที่นั่งที่เลือกไว้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHost ? 'ยกเลิกกลุ่ม' : 'ออกจากกลุ่ม'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (isHost) {
        await _app.cancelGroupPlan(_code);
      } else {
        await _app.leaveGroupPlan(_code);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast(e is ApiException ? e.message : 'ดำเนินการไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        title: Text(
          _plan?.name?.isNotEmpty == true ? _plan!.name! : 'ทริปแบบกลุ่ม',
          style: appFont(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_plan != null && _plan!.isOpen)
            IconButton(
              tooltip: 'แชร์ลิงก์',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _share,
            ),
          if (_plan != null && (_plan!.status == 'open'))
            IconButton(
              tooltip: _isHost ? 'ยกเลิกกลุ่ม' : 'ออกจากกลุ่ม',
              icon: const Icon(Icons.logout_rounded),
              onPressed: _leaveOrCancel,
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 15,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
      );
    }
    final plan = _plan;
    if (plan == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _TripCard(plan: plan),
          const SizedBox(height: 16),
          if (!plan.isOpen) _StatusBanner(plan: plan),
          if (plan.isOpen) ...[
            _InviteCard(plan: plan, onShare: _share),
            const SizedBox(height: 16),
          ],
          _GroupProgress(plan: plan),
          const SizedBox(height: 12),
          ...plan.members.map(
            (m) => _MemberTile(member: m, isMe: m.userId == _myUserId),
          ),
          const SizedBox(height: 16),
          if (plan.isOpen) _myActionCard(plan),
          if (plan.isOpen &&
              _isHost &&
              plan.schedule?.hasPickupPoints == true) ...[
            const SizedBox(height: 16),
            _buildPickupCard(plan.schedule!),
          ],
        ],
      ),
    );
  }

  void _ensurePickupDefaults(GroupSchedule schedule) {
    final regions = schedule.regionKeys;
    if (_selectedRegion == null || !regions.contains(_selectedRegion)) {
      _selectedRegion = regions.isNotEmpty ? regions.first : null;
    }
    final points = _selectedRegion == null
        ? const <GroupPickupPoint>[]
        : schedule.pointsInRegion(_selectedRegion!);
    if (_selectedPickupPointId != null &&
        !points.any((p) => p.id == _selectedPickupPointId)) {
      _selectedPickupPointId = null;
    }
    // Nothing to choose between — auto-select so the host isn't blocked.
    if (_selectedPickupPointId == null &&
        regions.length == 1 &&
        points.length == 1) {
      _selectedPickupPointId = points.first.id;
    }
  }

  Widget _buildPickupCard(GroupSchedule schedule) {
    _ensurePickupDefaults(schedule);
    return _PickupSelectionCard(
      schedule: schedule,
      selectedRegion: _selectedRegion,
      selectedPickupPointId: _selectedPickupPointId,
      onRegionChanged: (region) => setState(() {
        _selectedRegion = region;
        _selectedPickupPointId = null;
        _ensurePickupDefaults(schedule);
      }),
      onPickupChanged: (id) => setState(() => _selectedPickupPointId = id),
    );
  }

  Widget _myActionCard(GroupPlan plan) {
    final me = _myMember;
    if (me == null) return const SizedBox.shrink();

    if (me.seatId == null) {
      return _ActionCard(
        icon: Icons.event_seat_rounded,
        title: 'เลือกที่นั่งของคุณ',
        subtitle: 'เลือกที่นั่งและยืนยันชื่อผู้เดินทาง',
        buttonLabel: 'เลือกที่นั่ง',
        onPressed: _busy ? null : _openSeatPicker,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ที่นั่งของคุณ: ${me.seatId}',
              style: appFont(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _openSeatPicker,
            child: const Text('เปลี่ยน'),
          ),
          TextButton(
            onPressed: _busy ? null : _releaseSeat,
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('ปล่อย'),
          ),
        ],
      ),
    );
  }

  Widget? _buildFooter() {
    final plan = _plan;
    if (plan == null || _loading) return null;

    if (plan.isBooked && plan.bookingRef != null) {
      return _FooterBar(
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PaymentScreen(bookingRef: plan.bookingRef!),
            ),
          ),
          icon: const Icon(Icons.payment_rounded),
          label: const Text('ไปหน้าชำระเงิน'),
        ),
      );
    }

    if (!plan.isOpen) return null;

    if (!_isHost) {
      return _FooterBar(
        child: Text(
          'รอหัวหน้ากลุ่มชำระเงินเมื่อทุกคนพร้อม',
          textAlign: TextAlign.center,
          style: appFont(
            color: AppTheme.mutedText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final schedule = plan.schedule;
    final claimed = plan.claimedSeatIds.length;
    final needsPickup =
        schedule?.hasPickupPoints == true && _selectedPickupPointId == null;
    final price = schedule?.priceForPickup(_selectedPickupPointId) ?? 0;
    final total = price * claimed;
    final fmt = NumberFormat('#,###');

    final String label;
    if (claimed == 0) {
      label = 'รอสมาชิกเลือกที่นั่ง';
    } else if (needsPickup) {
      label = 'เลือกจุดขึ้นรถก่อนชำระเงิน';
    } else {
      label = 'ชำระเงินสำหรับกลุ่ม ($claimed ที่นั่ง) • ฿${fmt.format(total)}';
    }

    return _FooterBar(
      child: FilledButton(
        onPressed: (_busy || claimed == 0 || needsPickup) ? null : _checkout,
        child: Text(label),
      ),
    );
  }
}

class _SeatClaim {
  final String seatId;
  final String name;
  final String phone;
  const _SeatClaim(this.seatId, this.name, this.phone);
}

class _FooterBar extends StatelessWidget {
  final Widget child;
  const _FooterBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border(top: BorderSide(color: AppTheme.border(context))),
        ),
        child: SizedBox(width: double.infinity, height: 52, child: Center(child: child)),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final GroupPlan plan;
  const _TripCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final trip = plan.trip;
    final schedule = plan.schedule;
    final image = trip?.image ?? '';
    final dateLabel = schedule?.departureDate != null
        ? thaiDateShort(DateTime.parse(schedule!.departureDate!))
        : '';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          if (image.isNotEmpty)
            CachedNetworkImage(
              imageUrl: image,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                width: 96,
                height: 96,
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
                  Text(
                    trip?.title ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (dateLabel.isNotEmpty)
                    Text(
                      dateLabel,
                      style: appFont(
                        fontSize: 13,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _priceLabel(schedule),
                    style: appFont(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  if (schedule?.hasPickupPoints == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: AppTheme.mutedText(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${schedule!.regionKeys.length} ภาค · ${schedule.pickupPoints.length} จุดขึ้นรถ',
                            style: appFont(
                              fontSize: 12,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _priceLabel(GroupSchedule? schedule) {
    if (schedule == null) return '';
    final fmt = NumberFormat('#,###');
    if (schedule.hasVariedPrices) {
      final (min, max) = schedule.priceRange;
      return '฿${fmt.format(min)} - ฿${fmt.format(max)} / คน';
    }
    return '฿${fmt.format(schedule.effectivePrice)} / คน';
  }
}

/// Host-only picker for the group's pickup point. Some trips have several
/// regions (ภาค) and pickup points, each with its own per-person price, so the
/// host must choose one for the whole booking before checkout.
class _PickupSelectionCard extends StatelessWidget {
  final GroupSchedule schedule;
  final String? selectedRegion;
  final int? selectedPickupPointId;
  final ValueChanged<String?> onRegionChanged;
  final ValueChanged<int?> onPickupChanged;

  const _PickupSelectionCard({
    required this.schedule,
    required this.selectedRegion,
    required this.selectedPickupPointId,
    required this.onRegionChanged,
    required this.onPickupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final regions = schedule.regionKeys;
    final points = selectedRegion == null
        ? const <GroupPickupPoint>[]
        : schedule.pointsInRegion(selectedRegion!);
    final selectedPoint = schedule.pointById(selectedPickupPointId);
    final fmt = NumberFormat('#,###');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus_filled_rounded,
                  color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'จุดขึ้นรถของกลุ่ม',
                style: appFont(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'เลือกภาคและจุดขึ้นรถสำหรับทั้งกลุ่ม ราคาต่อคนจะอิงตามจุดที่เลือก',
            style: appFont(
              fontSize: 12.5,
              color: AppTheme.mutedText(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (regions.length > 1) ...[
            DropdownButtonFormField<String>(
              initialValue: selectedRegion,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'ภาคที่จะขึ้นรถ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.travel_explore_rounded),
              ),
              items: regions.map((key) {
                return DropdownMenuItem<String>(
                  value: key,
                  child: Text(
                    schedule.regionLabelFor(key),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onRegionChanged,
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<int>(
            initialValue: selectedPickupPointId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'จุดขึ้นรถ',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.place_rounded),
            ),
            hint: Text(
              'เลือกจุดขึ้นรถ',
              style: appFont(color: AppTheme.mutedText(context)),
            ),
            selectedItemBuilder: (context) => points
                .map((p) => Text(
                      p.locationLabel,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ))
                .toList(),
            items: points.map((point) {
              final price = schedule.priceForPickup(point.id);
              final notes = (point.notes ?? '').trim();
              final priceText = '฿${fmt.format(price)} / คน';
              return DropdownMenuItem<int>(
                value: point.id,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.locationLabel,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: appFont(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      notes.isEmpty ? priceText : '$notes · $priceText',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: appFont(
                        fontSize: 12,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: onPickupChanged,
          ),
          const SizedBox(height: 12),
          if (selectedPoint != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sell_rounded,
                      color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ราคาต่อคนสำหรับจุดนี้ ฿${fmt.format(schedule.priceForPickup(selectedPoint.id))}',
                      style: appFont(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: const Color(0xFF126B5B),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppTheme.warningColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'กรุณาเลือกจุดขึ้นรถก่อนชำระเงิน',
                      style: appFont(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: const Color(0xFF92400E),
                      ),
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

class _InviteCard extends StatelessWidget {
  final GroupPlan plan;
  final VoidCallback onShare;
  const _InviteCard({required this.plan, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รหัสกลุ่ม',
            style: appFont(
              fontSize: 13,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.inviteCode,
                  style: GoogleFonts.robotoMono(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: plan.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('คัดลอกรหัสแล้ว')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('แชร์ลิงก์ชวนเพื่อน'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupProgress extends StatelessWidget {
  final GroupPlan plan;
  const _GroupProgress({required this.plan});

  @override
  Widget build(BuildContext context) {
    final claimed = plan.claimedSeatIds.length;
    return Row(
      children: [
        Text(
          'สมาชิกในกลุ่ม',
          style: appFont(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        Text(
          'เลือกที่นั่งแล้ว $claimed / ${plan.seatCount}',
          style: appFont(
            fontSize: 13,
            color: AppTheme.mutedText(context),
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final GroupPlanMember member;
  final bool isMe;
  const _MemberTile({required this.member, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final ready = member.isReady;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.subtleSurface(context),
            backgroundImage: (member.avatarUrl?.isNotEmpty == true)
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: (member.avatarUrl?.isEmpty != false)
                ? Text(
                    member.displayName.characters.first,
                    style: appFont(fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${member.displayName}${isMe ? ' (คุณ)' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: appFont(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (member.isHost) ...[
                      const SizedBox(width: 6),
                      const _Badge(label: 'หัวหน้า', color: AppTheme.warningColor),
                    ],
                  ],
                ),
                Text(
                  ready ? 'พร้อมแล้ว • ที่นั่ง ${member.seatId}' : 'ยังไม่เลือกที่นั่ง',
                  style: appFont(
                    fontSize: 12.5,
                    color: ready
                        ? AppTheme.primaryColor
                        : AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            ready ? Icons.check_circle_rounded : Icons.schedule_rounded,
            color: ready ? AppTheme.primaryColor : AppTheme.mutedText(context),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: appFont(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final GroupPlan plan;
  const _StatusBanner({required this.plan});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (plan.status) {
      'booked' => ('จองสำเร็จแล้ว — ดำเนินการชำระเงินได้เลย', AppTheme.primaryColor),
      'expired' => ('กลุ่มนี้หมดเวลาจองร่วมกันแล้ว', AppTheme.warningColor),
      'cancelled' => ('กลุ่มนี้ถูกยกเลิกแล้ว', AppTheme.errorColor),
      _ => ('กลุ่มนี้ปิดรับแล้ว', AppTheme.mutedText(context)),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: appFont(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: appFont(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: appFont(
              fontSize: 13,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet seat picker: a simple grid honouring the schedule's seat
/// statuses, plus a passenger-name form. Returns the chosen seat + details.
class _SeatPickerSheet extends StatefulWidget {
  final Map<String, dynamic> seatMap;
  final GroupPlan plan;
  final int myUserId;
  final String defaultName;
  final String defaultPhone;

  const _SeatPickerSheet({
    required this.seatMap,
    required this.plan,
    required this.myUserId,
    required this.defaultName,
    required this.defaultPhone,
  });

  @override
  State<_SeatPickerSheet> createState() => _SeatPickerSheetState();
}

class _SeatPickerSheetState extends State<_SeatPickerSheet> {
  String? _selected;
  late final TextEditingController _name =
      TextEditingController(text: widget.defaultName);
  late final TextEditingController _phone =
      TextEditingController(text: widget.defaultPhone);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSeatMap = widget.seatMap['has_seat_map'] == true;
    final myMember = widget.plan.memberFor(widget.myUserId);
    final mySeat = myMember?.seatId;
    final groupSeats = widget.plan.claimedSeatIds.toSet();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'เลือกที่นั่ง',
                  style: appFont(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const VehicleSeatLegend(),
                      const SizedBox(height: 18),
                      hasSeatMap
                          ? VehicleSeatMap(
                              seatMap: widget.seatMap,
                              toneFor: (seat, id) {
                                final status =
                                    seat['status']?.toString() ?? 'available';
                                if (id == mySeat) return SeatTone.mine;
                                if (_selected == id) return SeatTone.picking;
                                if (groupSeats.contains(id)) {
                                  return SeatTone.group;
                                }
                                if (status == 'booked') return SeatTone.booked;
                                if (status == 'locked') return SeatTone.locked;
                                return SeatTone.available;
                              },
                              selectableFor: (seat, id) {
                                final status =
                                    seat['status']?.toString() ?? 'available';
                                final booked = status == 'booked';
                                final lockedOutside = status == 'locked' &&
                                    !groupSeats.contains(id);
                                final isGroup =
                                    groupSeats.contains(id) && id != mySeat;
                                return !booked && !lockedOutside && !isGroup;
                              },
                              onSeatTap: (seat, id) =>
                                  setState(() => _selected = id),
                            )
                          : _SeatGridFallback(
                              seatMap: widget.seatMap,
                              selected: _selected,
                              mySeat: mySeat,
                              groupSeats: groupSeats,
                              onSelect: (id) =>
                                  setState(() => _selected = id),
                            ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อผู้เดินทาง',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'เบอร์โทร (ไม่บังคับ)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: (_selected == null ||
                                  _name.text.trim().isEmpty)
                              ? null
                              : () => Navigator.pop(
                                    context,
                                    _SeatClaim(
                                      _selected!,
                                      _name.text.trim(),
                                      _phone.text.trim(),
                                    ),
                                  ),
                          child: Text(
                            _selected == null
                                ? 'เลือกที่นั่ง'
                                : 'ยืนยันที่นั่ง $_selected',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Fallback for schedules without a vehicle layout: a simple labelled grid so
/// members can still claim a seat by number.
class _SeatGridFallback extends StatelessWidget {
  final Map<String, dynamic> seatMap;
  final String? selected;
  final String? mySeat;
  final Set<String> groupSeats;
  final ValueChanged<String> onSelect;

  const _SeatGridFallback({
    required this.seatMap,
    required this.selected,
    required this.mySeat,
    required this.groupSeats,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final seats = (seatMap['seats'] as List?) ?? const [];
    if (seats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'ทริปนี้ยังไม่มีผังที่นั่ง',
          textAlign: TextAlign.center,
          style: appFont(
            color: AppTheme.mutedText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: seats.length,
      itemBuilder: (context, index) {
        final seat = Map<String, dynamic>.from(seats[index] as Map);
        final id = seat['id']?.toString() ?? '';
        final status = seat['status']?.toString() ?? 'available';
        final isMine = id == mySeat;
        final isGroup = groupSeats.contains(id) && !isMine;
        final booked = status == 'booked';
        final lockedOutside = status == 'locked' && !groupSeats.contains(id);
        final selectable = !booked && !lockedOutside && !isGroup;
        final isSelected = selected == id;

        Color bg;
        Color fg = AppTheme.onSurface(context);
        if (isMine) {
          bg = AppTheme.primaryColor;
          fg = Colors.white;
        } else if (isSelected) {
          bg = AppTheme.accentColor;
          fg = Colors.white;
        } else if (isGroup) {
          bg = AppTheme.warningColor.withValues(alpha: 0.25);
        } else if (booked || lockedOutside) {
          bg = AppTheme.subtleSurface(context);
          fg = AppTheme.mutedText(context);
        } else {
          bg = AppTheme.subtleSurface(context);
        }

        return GestureDetector(
          onTap: selectable ? () => onSelect(id) : null,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accentColor
                    : AppTheme.border(context),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              id,
              style: appFont(fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        );
      },
    );
  }
}

/// Banner shown above the trip list when the traveller arrived there to start a
/// group — a group must be created from a specific trip + departure, so this
/// guides them to pick one first.
class GroupCreateTripHint extends StatelessWidget {
  const GroupCreateTripHint({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = AppTheme.primaryColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups_2_rounded, color: primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เริ่มสร้างกลุ่ม',
                  style: appFont(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "เลือกทริปและวันเดินทาง แล้วกด 'ชวนเพื่อนมาเป็นกลุ่ม'",
                  style: appFont(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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
