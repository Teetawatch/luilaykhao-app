import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
            style: GoogleFonts.anuphan(
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
                  style: GoogleFonts.anuphan(
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
            _PickupGroupCard(group: group),
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
                      style: GoogleFonts.anuphan(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: GoogleFonts.anuphan(
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
                    style: GoogleFonts.anuphan(
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
                    style: GoogleFonts.anuphan(
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
            style: GoogleFonts.anuphan(
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
          style: GoogleFonts.anuphan(
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

  const _PickupGroupCard({required this.group});

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
                        style: GoogleFonts.anuphan(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (region.isNotEmpty && region != label)
                        Text(
                          region,
                          style: GoogleFonts.anuphan(
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
                            style: GoogleFonts.anuphan(
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
                        style: GoogleFonts.anuphan(
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
                          style: GoogleFonts.anuphan(
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
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface(context),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: GoogleFonts.anuphan(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.mutedText(context),
              ),
            ),
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
                        style: GoogleFonts.anuphan(
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
                        style: GoogleFonts.anuphan(
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
            style: GoogleFonts.anuphan(
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
              style: GoogleFonts.anuphan(
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
