import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class StaffCheckInScreen extends StatefulWidget {
  const StaffCheckInScreen({super.key});

  @override
  State<StaffCheckInScreen> createState() => _StaffCheckInScreenState();
}

class _StaffCheckInScreenState extends State<StaffCheckInScreen> {
  final TextEditingController _manualController = TextEditingController();
  Map<String, dynamic>? _booking;
  String? _currentCode;
  String? _error;
  String? _success;
  bool _loading = false;
  bool _confirming = false;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _StaffQrScannerScreen()),
    );
    if (value == null || value.trim().isEmpty || !mounted) return;
    await _lookup(value.trim());
  }

  Future<void> _lookup(String code) async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
      _booking = null;
      _currentCode = code;
    });

    try {
      final booking = await context.read<AppProvider>().lookupStaffCheckIn(
        code,
      );
      if (!mounted) return;
      setState(() => _booking = booking);
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

  Future<void> _confirm() async {
    final code = _currentCode;
    if (code == null || code.isEmpty) return;

    setState(() {
      _confirming = true;
      _error = null;
      _success = null;
    });

    try {
      final booking = await context.read<AppProvider>().confirmStaffCheckIn(
        code,
      );
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _success = 'เช็คอินสำเร็จ';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.isLoggedIn) {
      return const LoginScreen(popOnSuccess: false);
    }

    if (!app.canUseStaffCheckIn) {
      return Scaffold(
        backgroundColor: AppTheme.background(context),
        appBar: AppBar(title: const Text('Staff Check-in')),
        body: const Center(child: Text('บัญชีนี้ไม่มีสิทธิ์เช็คอินลูกค้า')),
      );
    }

    final booking = _booking;
    final canConfirm =
        booking != null &&
        textOf(booking['status']).toLowerCase() == 'confirmed' &&
        booking['checked_in'] != true &&
        !_confirming;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(title: const Text('เช็คอินลูกค้า')),
      body: RefreshIndicator(
        onRefresh: () async {
          final code = _currentCode;
          if (code != null && code.isNotEmpty) await _lookup(code);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            120 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            _ScannerPanel(
              controller: _manualController,
              loading: _loading,
              onScan: _openScanner,
              onLookup: () {
                final code = _manualController.text.trim();
                if (code.isNotEmpty) _lookup(code);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _MessageBanner(
                icon: Icons.error_outline_rounded,
                text: _error!,
                color: AppTheme.errorColor,
              ),
            ],
            if (_success != null) ...[
              const SizedBox(height: 12),
              _MessageBanner(
                icon: Icons.verified_rounded,
                text: _success!,
                color: AppTheme.primaryColor,
              ),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (booking == null)
              const _EmptyState()
            else
              _BookingDetail(booking: booking),
            if (booking != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: canConfirm ? _confirm : null,
                  icon: _confirming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.how_to_reg_rounded),
                  label: Text(
                    booking['checked_in'] == true
                        ? 'เช็คอินแล้ว'
                        : 'ยืนยันเช็คอิน',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScannerPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onScan;
  final VoidCallback onLookup;

  const _ScannerPanel({
    required this.controller,
    required this.loading,
    required this.onScan,
    required this.onLookup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context, radius: 22),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'สแกน QR สำหรับเช็คอิน',
                  style: GoogleFonts.anuphan(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: loading ? null : onScan,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('เปิดกล้องสแกน QR'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => onLookup(),
            decoration: InputDecoration(
              hintText: 'กรอก QR Code หรือเลขการจอง',
              suffixIcon: IconButton(
                onPressed: loading ? null : onLookup,
                icon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingDetail extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingDetail({required this.booking});

  @override
  Widget build(BuildContext context) {
    final user = asMap(booking['user']);
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final vehicle = asMap(schedule['vehicle']);
    final pickup = asMap(booking['pickup_point']);
    final passengers = asList(booking['passengers']).map(asMap).toList();
    final seats = asList(booking['seats']).map(asMap).toList();
    final staff = asList(booking['assigned_staff']).map(asMap).toList();
    final checkedIn = booking['checked_in'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: AppTheme.cardDecoration(context, radius: 22),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      textOf(booking['booking_ref'], '-'),
                      style: GoogleFonts.anuphan(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ),
                  _StatusChip(
                    label: checkedIn
                        ? 'เช็คอินแล้ว'
                        : statusLabel(booking['status']),
                    color: checkedIn
                        ? AppTheme.primaryColor
                        : statusColor(booking['status']),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.person_rounded,
                label: 'ลูกค้า',
                value: textOf(user['name'], '-'),
              ),
              _InfoRow(
                icon: Icons.phone_rounded,
                label: 'โทร',
                value: textOf(user['phone'], '-'),
              ),
              _InfoRow(
                icon: Icons.mail_rounded,
                label: 'อีเมล',
                value: textOf(user['email'], '-'),
              ),
              if (checkedIn)
                _InfoRow(
                  icon: Icons.event_available_rounded,
                  label: 'เวลาเช็คอิน',
                  value: dateTimeText(booking['checked_in_at']),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'รายละเอียดทริป',
          children: [
            _InfoRow(
              icon: Icons.landscape_rounded,
              label: 'ทริป',
              value: textOf(trip['title'], '-'),
            ),
            _InfoRow(
              icon: Icons.place_rounded,
              label: 'สถานที่',
              value: textOf(trip['location'], '-'),
            ),
            _InfoRow(
              icon: Icons.calendar_month_rounded,
              label: 'วันเดินทาง',
              value: dateText(schedule['departure_date']),
            ),
            _InfoRow(
              icon: Icons.flag_rounded,
              label: 'วันกลับ',
              value: dateText(schedule['return_date']),
            ),
            _InfoRow(
              icon: Icons.location_on_rounded,
              label: 'จุดรับ',
              value: pickup.isNotEmpty
                  ? textOf(pickup['pickup_location'], '-')
                  : textOf(booking['pickup_region'], '-'),
            ),
            if (vehicle.isNotEmpty)
              _InfoRow(
                icon: Icons.directions_bus_rounded,
                label: 'รถ',
                value: [
                  textOf(vehicle['name']),
                  textOf(vehicle['license_plate']),
                ].where((value) => value.isNotEmpty).join(' · '),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'การชำระเงิน',
          children: [
            _InfoRow(
              icon: Icons.payments_rounded,
              label: 'ยอดรวม',
              value: money(booking['total_amount']),
            ),
            _InfoRow(
              icon: Icons.verified_rounded,
              label: 'ชำระแล้ว',
              value: money(booking['paid_amount']),
            ),
            _InfoRow(
              icon: Icons.receipt_long_rounded,
              label: 'รูปแบบ',
              value: paymentTypeLabel(booking['payment_type']),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'ผู้เดินทาง (${passengers.length})',
          children: passengers.isEmpty
              ? [const _MutedText('ไม่มีข้อมูลผู้เดินทาง')]
              : passengers
                    .map(
                      (passenger) => _PassengerTile(
                        passenger: passenger,
                        seat: seats.firstWhere(
                          (seat) =>
                              textOf(seat['passenger_name']) ==
                              textOf(passenger['name']),
                          orElse: () => <String, dynamic>{},
                        ),
                      ),
                    )
                    .toList(),
        ),
        if (staff.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'สตาฟประจำรอบ',
            children: staff
                .map(
                  (item) => _InfoRow(
                    icon: Icons.badge_rounded,
                    label: textOf(item['name'], '-'),
                    value: textOf(item['phone'], textOf(item['email'], '-')),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _StaffQrScannerScreen extends StatefulWidget {
  const _StaffQrScannerScreen();

  @override
  State<_StaffQrScannerScreen> createState() => _StaffQrScannerScreenState();
}

class _StaffQrScannerScreenState extends State<_StaffQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_handled || capture.barcodes.isEmpty) return;
              final value = capture.barcodes.first.rawValue;
              if (value == null || value.trim().isEmpty) return;
              _handled = true;
              Navigator.pop(context, value.trim());
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton.filled(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'สแกน QR เช็คอินลูกค้า',
                      style: GoogleFonts.anuphan(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 248,
              height: 248,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              'วาง QR ให้อยู่ในกรอบ ระบบจะแสดงข้อมูลการจองก่อนยืนยัน',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context, radius: 22),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.anuphan(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _PassengerTile extends StatelessWidget {
  final Map<String, dynamic> passenger;
  final Map<String, dynamic> seat;

  const _PassengerTile({required this.passenger, required this.seat});

  @override
  Widget build(BuildContext context) {
    final notes = [
      if (textOf(passenger['phone']).isNotEmpty)
        'โทร ${textOf(passenger['phone'])}',
      if (textOf(seat['seat_id']).isNotEmpty)
        'ที่นั่ง ${textOf(seat['seat_id'])}',
      if (passenger['halal_food'] == true) 'อาหารฮาลาล',
      if (textOf(passenger['allergies']).isNotEmpty)
        'แพ้ ${textOf(passenger['allergies'])}',
      if (textOf(passenger['health_notes']).isNotEmpty)
        textOf(passenger['health_notes']),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textOf(passenger['name'], '-'),
                  style: GoogleFonts.anuphan(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                if (notes.isNotEmpty)
                  Text(
                    notes.join(' · '),
                    style: GoogleFonts.anuphan(
                      fontSize: 12,
                      height: 1.45,
                      color: AppTheme.mutedText(context),
                      fontWeight: FontWeight.w600,
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.mutedText(context)),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: GoogleFonts.anuphan(
                fontSize: 12,
                color: AppTheme.mutedText(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: GoogleFonts.anuphan(
                fontSize: 13,
                color: AppTheme.onSurface(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.anuphan(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MessageBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.anuphan(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context, radius: 22),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            size: 54,
            color: AppTheme.primaryColor.withValues(alpha: 0.75),
          ),
          const SizedBox(height: 10),
          Text(
            'ยังไม่มีข้อมูลการจอง',
            style: GoogleFonts.anuphan(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'สแกน QR หรือกรอกเลขการจองเพื่อดูรายละเอียดก่อนเช็คอิน',
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  final String text;

  const _MutedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.anuphan(
        color: AppTheme.mutedText(context),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}

String textOf(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String money(dynamic value) {
  final number = num.tryParse(value?.toString() ?? '');
  return NumberFormat.currency(
    locale: 'th_TH',
    symbol: '฿',
  ).format(number ?? 0);
}

String dateText(dynamic value) {
  final raw = textOf(value);
  final date = DateTime.tryParse(raw);
  if (date == null) return raw.isEmpty ? '-' : raw;
  return DateFormat('d MMM y', 'th_TH').format(date.toLocal());
}

String dateTimeText(dynamic value) {
  final raw = textOf(value);
  final date = DateTime.tryParse(raw);
  if (date == null) return raw.isEmpty ? '-' : raw;
  return DateFormat('d MMM y HH:mm', 'th_TH').format(date.toLocal());
}

String statusLabel(dynamic value) {
  return switch (textOf(value).toLowerCase()) {
    'confirmed' => 'ยืนยันแล้ว',
    'pending' => 'รอชำระ',
    'cancelled' => 'ยกเลิก',
    'completed' => 'เสร็จสิ้น',
    _ => textOf(value, '-'),
  };
}

Color statusColor(dynamic value) {
  return switch (textOf(value).toLowerCase()) {
    'confirmed' => AppTheme.primaryColor,
    'pending' => AppTheme.warningColor,
    'cancelled' => AppTheme.errorColor,
    _ => AppTheme.textSecondary,
  };
}

String paymentTypeLabel(dynamic value) {
  return textOf(value).toLowerCase() == 'installment'
      ? 'ผ่อนชำระ'
      : 'ชำระเต็มจำนวน';
}
