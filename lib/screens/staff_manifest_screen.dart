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
    final bookings = asList(_data?['bookings']).map(asMap).toList();

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
        child: _buildBody(summary, bookings),
      ),
    );
  }

  Widget _buildBody(
    Map<String, dynamic> summary,
    List<Map<String, dynamic>> bookings,
  ) {
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

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _ManifestSummary(summary: summary),
        const SizedBox(height: 16),
        if (bookings.isEmpty)
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
          for (final booking in bookings) ...[
            _ManifestBookingCard(booking: booking),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _ManifestSummary extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _ManifestSummary({required this.summary});

  int _intOf(dynamic v) => int.tryParse(textOf(v, '0')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final bookings = _intOf(summary['bookings']);
    final checkedIn = _intOf(summary['checked_in']);
    final passengers = _intOf(summary['passengers']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: 20),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              icon: Icons.confirmation_number_outlined,
              value: bookings.toString(),
              label: 'การจอง',
              color: const Color(0xFF2563EB),
            ),
          ),
          _divider(context),
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

class _ManifestBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _ManifestBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ref = textOf(booking['booking_ref'], '-');
    final contactName = textOf(booking['contact_name'], '-');
    final contactPhone = textOf(booking['contact_phone']);
    final isGroup = booking['is_group'] == true;
    final groupName = textOf(booking['group_name']);
    final checkedIn = booking['checked_in'] == true;
    final pickupLocation = textOf(booking['pickup_location']);
    final pickupRegion = textOf(
      booking['pickup_region_label'],
      textOf(booking['pickup_region']),
    );
    final pickupMapUrl = textOf(booking['pickup_map_url']);
    final pickupNotes = textOf(booking['pickup_notes']);
    final passengers = asList(booking['passengers']).map(asMap).toList();

    final pickupLabel = pickupLocation.isNotEmpty
        ? pickupLocation
        : (pickupRegion.isNotEmpty ? pickupRegion : 'ไม่ระบุจุดรับ');

    return Container(
      decoration: AppTheme.cardDecoration(context, radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ref + check-in badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        ref,
                        style: GoogleFonts.anuphan(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.onSurface(context),
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (isGroup) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'กรุ๊ป',
                            style: GoogleFonts.anuphan(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _CheckInPill(checkedIn: checkedIn),
              ],
            ),
          ),

          // Contact name + phone
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryColor.withValues(
                    alpha: 0.10,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName.isNotEmpty ? groupName : contactName,
                        style: GoogleFonts.anuphan(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      if (groupName.isNotEmpty && contactName != '-')
                        Text(
                          'ผู้ติดต่อ: $contactName',
                          style: GoogleFonts.anuphan(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                    ],
                  ),
                ),
                if (contactPhone.isNotEmpty)
                  _CallButton(phone: contactPhone),
              ],
            ),
          ),

          // Pickup
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 16,
                        color: Color(0xFF0D9488),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickupLabel,
                              style: GoogleFonts.anuphan(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onSurface(context),
                              ),
                            ),
                            if (pickupRegion.isNotEmpty &&
                                pickupRegion != pickupLabel)
                              Text(
                                pickupRegion,
                                style: GoogleFonts.anuphan(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.mutedText(context),
                                ),
                              ),
                            if (pickupNotes.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                pickupNotes,
                                style: GoogleFonts.anuphan(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (pickupMapUrl.isNotEmpty)
                        IconButton(
                          tooltip: 'เปิดแผนที่',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => launchUrl(
                            Uri.parse(pickupMapUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(
                            Icons.map_rounded,
                            size: 20,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Passengers
          if (passengers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ผู้เดินทาง ${passengers.length} คน',
                    style: GoogleFonts.anuphan(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final p in passengers) _PassengerRow(passenger: p),
                ],
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _PassengerRow extends StatelessWidget {
  final Map<String, dynamic> passenger;

  const _PassengerRow({required this.passenger});

  @override
  Widget build(BuildContext context) {
    final name = textOf(passenger['name'], '-');
    final nickname = textOf(passenger['nickname']);
    final phone = textOf(passenger['phone']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 15,
            color: AppTheme.mutedText(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: name,
                    style: GoogleFonts.anuphan(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  if (nickname.isNotEmpty)
                    TextSpan(
                      text: '  ($nickname)',
                      style: GoogleFonts.anuphan(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (phone.isNotEmpty) _CallButton(phone: phone, compact: true),
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
