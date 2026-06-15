import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'staff_check_in_screen.dart'
    show StaffCheckInScreen, asMap, asList, textOf;

/// Full passenger manifest for one schedule — shows every confirmed booking
/// with contact name, callable phone and pickup point so staff can coordinate
/// pickups and roll-calls in the field. Backed by [AppProvider.loadStaffManifest].
class StaffManifestScreen extends StatefulWidget {
  final int scheduleId;
  final String title;

  const StaffManifestScreen({
    super.key,
    required this.scheduleId,
    required this.title,
  });

  @override
  State<StaffManifestScreen> createState() => _StaffManifestScreenState();
}

class _StaffManifestScreenState extends State<StaffManifestScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  final Set<int> _completingPoints = {};

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
      final data = await context.read<AppProvider>().loadStaffManifest(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePickupComplete(
    Map<String, dynamic> group,
    bool complete,
  ) async {
    final pointId = group['id'];
    if (pointId is! int || _completingPoints.contains(pointId)) return;

    setState(() => _completingPoints.add(pointId));
    try {
      final result = await context.read<AppProvider>().setPickupCompleted(
        widget.scheduleId,
        pointId,
        complete,
      );
      if (!mounted) return;
      setState(() => group['completed_at'] = result['completed_at']);
      final notified = int.tryParse(textOf(result['notified'], '0')) ?? 0;
      final next = asMap(result['next_point']);
      if (complete) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryColor,
            content: Text(
              next.isNotEmpty
                  ? 'แจ้งจุดถัดไป "${textOf(next['label'])}" แล้ว ($notified คน)'
                  : 'รับครบทุกจุดแล้ว',
              style: appFont(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.errorColor,
          content: Text(
            e is ApiException ? e.message : 'อัปเดตไม่สำเร็จ',
            style: appFont(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _completingPoints.remove(pointId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = asMap(_data?['summary']);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(widget.title.isEmpty ? 'รายชื่อผู้โดยสาร' : widget.title),
        actions: [
          IconButton(
            tooltip: 'เช็คอินด้วย QR',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StaffCheckInScreen()),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: _buildBody(summary),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> summary) {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _data == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองใหม่'),
            ),
          ),
        ],
      );
    }

    final schedule = asMap(_data?['schedule']);
    final vehicle = asMap(schedule['vehicle']);
    final groups = asList(_data?['pickup_groups']).map(asMap).toList();
    final seatMap = asMap(_data?['seat_map']);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        if (vehicle.isNotEmpty) ...[
          _VehicleCard(vehicle: vehicle),
          const SizedBox(height: 12),
        ],
        _ManifestSummary(summary: summary, pickupGroupCount: groups.length),
        const SizedBox(height: 16),
        if (seatMap.isNotEmpty && asList(seatMap['seats']).isNotEmpty) ...[
          _StaffSeatMap(seatMap: seatMap),
          const SizedBox(height: 16),
        ],
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  Icons.group_off_outlined,
                  size: 44,
                  color: AppTheme.mutedText(context),
                ),
                const SizedBox(height: 12),
                Text(
                  'ยังไม่มีผู้โดยสารที่ยืนยันแล้ว',
                  style: appFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          )
        else
          for (final group in groups) ...[
            _PickupGroupCard(
              group: group,
              busy: _completingPoints.contains(group['id']),
              onToggleComplete: (group['id'] is int)
                  ? (complete) => _togglePickupComplete(group, complete)
                  : null,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final name = textOf(vehicle['name']);
    final plate = textOf(vehicle['license_plate']);
    final type = textOf(vehicle['type']);
    final capacity = textOf(vehicle['capacity']);
    final color = textOf(vehicle['color']);
    final driverName = textOf(vehicle['driver_name']);
    final driverPhone = textOf(vehicle['driver_phone']);

    final meta = <String>[
      if (type.isNotEmpty) type,
      if (color.isNotEmpty) color,
      if (capacity.isNotEmpty) '$capacity ที่นั่ง',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D9488).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF0D9488).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: Color(0xFF0D9488),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'รถประจำรอบ' : name,
                      style: appFont(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: appFont(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (plate.isNotEmpty) ...[
            const SizedBox(height: 12),
            // License plate, shown like an actual plate so it stands out.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pin_outlined,
                      size: 16, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Text(
                    plate,
                    style: appFont(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.onSurface(context),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (driverName.isNotEmpty || driverPhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_pin_circle_outlined,
                    size: 18, color: AppTheme.mutedText(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    driverName.isEmpty ? 'คนขับ' : 'คนขับ: $driverName',
                    style: appFont(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ),
                if (driverPhone.isNotEmpty) _CallButton(phone: driverPhone),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ManifestSummary extends StatelessWidget {
  final Map<String, dynamic> summary;
  final int pickupGroupCount;

  const _ManifestSummary({
    required this.summary,
    required this.pickupGroupCount,
  });

  int _intOf(dynamic v) => int.tryParse(textOf(v, '0')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final passengers = _intOf(summary['passengers']);
    // Prefer passenger-based check-in; fall back to booking-based for safety.
    final checkedIn = summary['checked_in_passengers'] != null
        ? _intOf(summary['checked_in_passengers'])
        : _intOf(summary['checked_in']);
    final careAlerts = _intOf(summary['care_alerts']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: 20),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              icon: Icons.groups_outlined,
              value: passengers.toString(),
              label: 'ผู้โดยสาร',
              color: const Color(0xFF0D9488),
            ),
          ),
          _divider(context),
          Expanded(
            child: _SummaryStat(
              icon: Icons.place_outlined,
              value: pickupGroupCount.toString(),
              label: 'จุดรับ',
              color: const Color(0xFF2563EB),
            ),
          ),
          _divider(context),
          Expanded(
            child: _SummaryStat(
              icon: Icons.how_to_reg_outlined,
              value: '$checkedIn/$passengers',
              label: 'เช็คอินแล้ว',
              color: AppTheme.primaryColor,
            ),
          ),
          if (careAlerts > 0) ...[
            _divider(context),
            Expanded(
              child: _SummaryStat(
                icon: Icons.health_and_safety_outlined,
                value: careAlerts.toString(),
                label: 'ต้องดูแล',
                color: AppTheme.errorColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Container(
    width: 1,
    height: 36,
    color: AppTheme.border(context).withValues(alpha: 0.5),
  );
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: appFont(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: appFont(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.mutedText(context),
          ),
        ),
      ],
    );
  }
}

/// One pickup point with every passenger picked up there — full name, nickname,
/// callable phone and per-passenger check-in status.
class _PickupGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool busy;

  /// Called with the desired completed state. Null when the pickup point has no
  /// id (e.g. the "ไม่ระบุจุดรับ" group), in which case no action is shown.
  final void Function(bool completed)? onToggleComplete;

  const _PickupGroupCard({
    required this.group,
    this.busy = false,
    this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    final label = textOf(group['label'], 'จุดรับ');
    final region = textOf(group['region_label']);
    final mapUrl = textOf(group['map_url']);
    final notes = textOf(group['notes']);
    final total = int.tryParse(textOf(group['passenger_count'], '0')) ?? 0;
    final checkedIn = int.tryParse(textOf(group['checked_in_count'], '0')) ?? 0;
    final passengers = asList(group['passengers']).map(asMap).toList();
    final allIn = total > 0 && checkedIn >= total;
    final isCompleted = textOf(group['completed_at']).isNotEmpty;

    return Container(
      decoration: AppTheme.cardDecoration(context, radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            color: const Color(0xFF0D9488).withValues(alpha: 0.06),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_rounded,
                    size: 18, color: Color(0xFF0D9488)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: appFont(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (region.isNotEmpty && region != label)
                        Text(
                          region,
                          style: appFont(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      if (notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            notes,
                            style: appFont(
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: allIn
                            ? AppTheme.primaryColor.withValues(alpha: 0.12)
                            : const Color(0xFF0D9488).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'เช็คอิน $checkedIn/$total',
                        style: appFont(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: allIn
                              ? AppTheme.primaryColor
                              : const Color(0xFF0D9488),
                        ),
                      ),
                    ),
                    if (mapUrl.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(mapUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.map_rounded, size: 15),
                        label: Text(
                          'แผนที่',
                          style: appFont(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Passengers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < passengers.length; i++) ...[
                  _ManifestPassengerRow(
                    passenger: passengers[i],
                    index: i + 1,
                  ),
                  if (i < passengers.length - 1)
                    Divider(
                      height: 1,
                      color: AppTheme.border(context).withValues(alpha: 0.45),
                    ),
                ],
              ],
            ),
          ),
          if (onToggleComplete != null)
            _PickupCompleteFooter(
              completed: isCompleted,
              busy: busy,
              onToggle: onToggleComplete!,
            ),
        ],
      ),
    );
  }
}

/// Footer action on a pickup group: mark the point picked-up (notifying the
/// next stop) or undo it.
class _PickupCompleteFooter extends StatelessWidget {
  final bool completed;
  final bool busy;
  final void Function(bool completed) onToggle;

  const _PickupCompleteFooter({
    required this.completed,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.45),
          ),
        ),
      ),
      child: completed
          ? Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(
                  'รับครบจุดนี้แล้ว',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: busy ? null : () => onToggle(false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'ยกเลิก',
                    style: appFont(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => onToggle(true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.task_alt_rounded, size: 18),
                label: Text(
                  busy ? 'กำลังอัปเดต...' : 'รับครบแล้ว • แจ้งจุดถัดไป',
                  style: appFont(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
    );
  }
}

class _ManifestPassengerRow extends StatelessWidget {
  final Map<String, dynamic> passenger;
  final int index;

  const _ManifestPassengerRow({required this.passenger, required this.index});

  @override
  Widget build(BuildContext context) {
    final fullName = textOf(
      passenger['full_name'],
      textOf(passenger['name'], '-'),
    );
    final nickname = textOf(passenger['nickname']);
    final phone = textOf(passenger['phone']);
    final checkedIn = passenger['checked_in'] == true;
    final avatarUrl = ApiConfig.mediaUrl(passenger['avatar_url']);

    final allergies = textOf(passenger['allergies']);
    final healthNotes = textOf(passenger['health_notes']);
    final bloodGroup = textOf(passenger['blood_group']);
    final halal = passenger['halal_food'] == true;
    final emergencyContact = textOf(passenger['emergency_contact']);
    final emergencyPhone = textOf(passenger['emergency_phone']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PassengerAvatar(
            url: avatarUrl,
            name: fullName,
            index: index,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        fullName,
                        style: appFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (nickname.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '($nickname)',
                        style: appFont(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                    ],
                  ],
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _CallButton(phone: phone, compact: true),
                ],
                _SafetyBadges(
                  allergies: allergies,
                  healthNotes: healthNotes,
                  bloodGroup: bloodGroup,
                  halal: halal,
                  emergencyContact: emergencyContact,
                  emergencyPhone: emergencyPhone,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CheckInPill(checkedIn: checkedIn),
        ],
      ),
    );
  }
}

class _CheckInPill extends StatelessWidget {
  final bool checkedIn;

  const _CheckInPill({required this.checkedIn});

  @override
  Widget build(BuildContext context) {
    final color = checkedIn ? AppTheme.primaryColor : AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            checkedIn
                ? Icons.check_circle_rounded
                : Icons.schedule_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            checkedIn ? 'เช็คอินแล้ว' : 'ยังไม่เช็คอิน',
            style: appFont(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Care/safety badges for a manifest passenger: allergies, health notes, halal
/// meal, blood group, and a quick-dial emergency contact. Renders nothing when
/// the passenger has no flags, so ordinary rows stay clean.
class _SafetyBadges extends StatelessWidget {
  final String allergies;
  final String healthNotes;
  final String bloodGroup;
  final bool halal;
  final String emergencyContact;
  final String emergencyPhone;

  const _SafetyBadges({
    required this.allergies,
    required this.healthNotes,
    required this.bloodGroup,
    required this.halal,
    required this.emergencyContact,
    required this.emergencyPhone,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (allergies.isNotEmpty)
        _CareChip(
          icon: Icons.warning_amber_rounded,
          label: 'แพ้ $allergies',
          color: AppTheme.errorColor,
        ),
      if (healthNotes.isNotEmpty)
        _CareChip(
          icon: Icons.medical_services_rounded,
          label: healthNotes,
          color: AppTheme.warningColor,
        ),
      if (halal)
        const _CareChip(
          icon: Icons.restaurant_rounded,
          label: 'ฮาลาล',
          color: AppTheme.primaryColor,
        ),
      if (bloodGroup.isNotEmpty)
        _CareChip(
          icon: Icons.bloodtype_rounded,
          label: 'กรุ๊ปเลือด $bloodGroup',
          color: AppTheme.errorColor,
        ),
    ];

    final hasEmergency = emergencyPhone.isNotEmpty || emergencyContact.isNotEmpty;
    if (chips.isEmpty && !hasEmergency) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          if (hasEmergency) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.emergency_rounded,
                  size: 13,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    emergencyContact.isNotEmpty
                        ? 'ฉุกเฉิน: $emergencyContact'
                        : 'ติดต่อฉุกเฉิน',
                    style: appFont(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
                if (emergencyPhone.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _CallButton(phone: emergencyPhone, compact: true),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CareChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CareChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: appFont(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Passenger profile photo (the booker's avatar). Tappable to view full-screen
/// and zoom when a real photo exists; otherwise shows an initials circle.
class _PassengerAvatar extends StatelessWidget {
  final String url;
  final String name;
  final int index;

  const _PassengerAvatar({
    required this.url,
    required this.name,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    const size = 40.0;

    if (url.isEmpty) {
      final initial = name.trim().isEmpty ? '$index' : name.trim().characters.first;
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.subtleSurface(context),
          shape: BoxShape.circle,
        ),
        child: Text(
          initial,
          style: appFont(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.mutedText(context),
          ),
        ),
      );
    }

    final tag = 'pax-avatar-$index-$url';
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _PassengerPhotoView(url: url, name: name, tag: tag),
        ),
      ),
      child: Hero(
        tag: tag,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              width: size,
              height: size,
              color: AppTheme.subtleSurface(context),
            ),
            errorWidget: (_, _, _) => Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              color: AppTheme.subtleSurface(context),
              child: Icon(
                Icons.person_rounded,
                size: 20,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom viewer for a passenger photo. Tap anywhere or the
/// close button to dismiss.
class _PassengerPhotoView extends StatelessWidget {
  final String url;
  final String name;
  final String tag;

  const _PassengerPhotoView({
    required this.url,
    required this.name,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: name.trim().isEmpty
            ? null
            : Text(name, style: appFont(fontWeight: FontWeight.w700)),
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: Hero(
            tag: tag,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, _, _) => const Icon(
                  Icons.broken_image_rounded,
                  size: 48,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Staff Seat Map ───────────────────────────────────────────────────────────

/// Visual vehicle seat map for staff — mirrors the customer booking layout but
/// labels each booked seat with its occupant (nickname / name), so staff can
/// see at a glance who sits where. Tap a seat for the full details.
class _StaffSeatMap extends StatelessWidget {
  final Map<String, dynamic> seatMap;

  const _StaffSeatMap({required this.seatMap});

  @override
  Widget build(BuildContext context) {
    final occupied = int.tryParse(textOf(seatMap['occupied'])) ?? 0;
    final total = int.tryParse(textOf(seatMap['total'])) ?? 0;
    final frontSeatId = textOf(seatMap['front_seat']);
    final frontSeat = frontSeatId.isEmpty
        ? null
        : _staffSeatById(seatMap, frontSeatId);
    final rows = _staffSeatRows(seatMap);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.airline_seat_recline_normal_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'แผนผังที่นั่ง',
                style: appFont(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.onSurface(context),
                ),
              ),
              const Spacer(),
              Text(
                'นั่งแล้ว $occupied/$total',
                style: appFont(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        frontSeat == null
                            ? const SizedBox(width: 64)
                            : _StaffSeatTile(seat: frontSeat),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            textOf(seatMap['front_label'], 'หน้ารถ'),
                            style: appFont(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ),
                        if (seatMap['show_driver'] != false)
                          const _DriverBlock()
                        else
                          const SizedBox(width: 64),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        width: 300,
                        child: Divider(height: 1),
                      ),
                    ),
                    ...rows.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StaffSeatRow(row: row, seatMap: seatMap),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverBlock extends StatelessWidget {
  const _DriverBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.mutedText(context).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.airline_seat_recline_extra_rounded,
            size: 18,
            color: AppTheme.mutedText(context),
          ),
          const SizedBox(height: 2),
          Text(
            'คนขับ',
            style: appFont(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffSeatRow extends StatelessWidget {
  final _StaffSeatRowData row;
  final Map<String, dynamic> seatMap;

  const _StaffSeatRow({required this.row, required this.seatMap});

  @override
  Widget build(BuildContext context) {
    Widget seats(List<String> ids) => Row(
      mainAxisSize: MainAxisSize.min,
      children: ids.map((id) {
        final seat = _staffSeatById(seatMap, id);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: seat == null
              ? const SizedBox(width: 64, height: 54)
              : _StaffSeatTile(seat: seat),
        );
      }).toList(),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        seats(row.left),
        if (row.center.isNotEmpty) ...[
          const SizedBox(width: 6),
          seats(row.center),
        ],
        SizedBox(
          width: 36,
          child: Center(
            child: row.hasAisle
                ? Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                : null,
          ),
        ),
        seats(row.right),
      ],
    );
  }
}

class _StaffSeatTile extends StatelessWidget {
  final Map<String, dynamic> seat;

  const _StaffSeatTile({required this.seat});

  @override
  Widget build(BuildContext context) {
    final label = textOf(seat['label'], textOf(seat['id']));
    final occupant = asMap(seat['occupant']);
    final occupied = occupant.isNotEmpty;
    final checkedIn = occupant['checked_in'] == true;
    final display = textOf(
      occupant['nickname'],
      _firstWord(textOf(occupant['name'])),
    );

    final accent = checkedIn ? const Color(0xFF16A34A) : AppTheme.primaryColor;

    return GestureDetector(
      onTap: occupied ? () => _showSeatDetail(context, label, occupant) : null,
      child: Container(
        width: 64,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: occupied
              ? accent.withValues(alpha: 0.10)
              : AppTheme.mutedText(context).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: occupied
                ? accent.withValues(alpha: 0.45)
                : AppTheme.border(context),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: appFont(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: occupied ? accent : AppTheme.mutedText(context),
                  ),
                ),
                if (checkedIn) ...[
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 10,
                    color: Color(0xFF16A34A),
                  ),
                ],
              ],
            ),
            if (occupied)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  display.isEmpty ? '—' : display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSeatDetail(
    BuildContext context,
    String label,
    Map<String, dynamic> occupant,
  ) {
    final name = textOf(occupant['name'], '-');
    final nickname = textOf(occupant['nickname']);
    final ref = textOf(occupant['booking_ref']);
    final checkedIn = occupant['checked_in'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ที่นั่ง $label',
                    style: appFont(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (checkedIn)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'เช็คอินแล้ว',
                        style: appFont(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'ยังไม่เช็คอิน',
                    style: appFont(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              nickname.isEmpty ? name : '$name ($nickname)',
              style: appFont(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppTheme.onSurface(context),
              ),
            ),
            if (ref.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                ref,
                style: appFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _firstWord(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).first;
}

/// Per-row seat arrangement, derived from the layout's columns + aisle markers.
class _StaffSeatRowData {
  final List<String> left;
  final List<String> right;
  final List<String> center;
  final bool hasAisle;

  const _StaffSeatRowData({
    required this.left,
    required this.right,
    required this.center,
    required this.hasAisle,
  });
}

Map<String, dynamic>? _staffSeatById(Map<String, dynamic> seatMap, String id) {
  for (final item in asList(seatMap['seats'])) {
    final seat = asMap(item);
    if (textOf(seat['id']) == id) return seat;
  }
  return null;
}

List<_StaffSeatRowData> _staffSeatRows(Map<String, dynamic> seatMap) {
  final rows = int.tryParse(textOf(seatMap['rows'])) ?? 0;
  final columns = asList(
    seatMap['columns'],
  ).map((item) => item?.toString() ?? '').toList();
  final frontSeatId = textOf(seatMap['front_seat']);
  final centerSeatIds = asList(
    seatMap['last_row_center'],
  ).map((item) => item?.toString() ?? '').toSet();
  final result = <_StaffSeatRowData>[];

  for (var rowIndex = 1; rowIndex <= rows; rowIndex++) {
    final left = <String>[];
    final right = <String>[];
    final center = <String>[];
    var hasAisle = false;
    var inRight = false;

    for (final column in columns) {
      if (column.isEmpty) {
        hasAisle = true;
        inRight = true;
        continue;
      }

      final seatId = '$column$rowIndex';
      if (seatId == frontSeatId) continue;
      if (_staffSeatById(seatMap, seatId) == null) continue;

      if (centerSeatIds.contains(seatId)) {
        center.add(seatId);
      } else if (inRight) {
        right.add(seatId);
      } else {
        left.add(seatId);
      }
    }

    if (left.isEmpty && right.isEmpty && center.isEmpty) continue;

    result.add(
      _StaffSeatRowData(
        left: left,
        right: right,
        center: center,
        hasAisle: hasAisle && right.isNotEmpty,
      ),
    );
  }

  return result;
}

class _CallButton extends StatelessWidget {
  final String phone;
  final bool compact;

  const _CallButton({required this.phone, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse('tel:$phone')),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 5 : 8,
        ),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.phone_rounded,
              size: compact ? 13 : 15,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 5),
            Text(
              compact ? 'โทร' : phone,
              style: appFont(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
