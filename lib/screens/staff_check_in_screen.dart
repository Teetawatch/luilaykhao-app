import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _StaffCheckInScreenState extends State<StaffCheckInScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _manualController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Map<String, dynamic>? _booking;
  String? _currentCode;
  String? _error;
  String? _success;
  bool _loading = false;
  bool _confirming = false;
  late final AnimationController _successAnimController;
  late final Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _successScale = CurvedAnimation(
      parent: _successAnimController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _manualController.dispose();
    _focusNode.dispose();
    _successAnimController.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    _focusNode.unfocus();
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _StaffQrScannerScreen()),
    );
    if (value == null || value.trim().isEmpty || !mounted) return;
    await _lookup(value.trim());
  }

  Future<void> _lookup(String code) async {
    _focusNode.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
      _booking = null;
      _currentCode = code;
    });
    _successAnimController.reset();

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
      HapticFeedback.heavyImpact();
      setState(() {
        _booking = booking;
        _success = 'เช็คอินสำเร็จแล้ว';
      });
      _successAnimController.forward(from: 0);
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _reset() {
    setState(() {
      _booking = null;
      _currentCode = null;
      _error = null;
      _success = null;
    });
    _manualController.clear();
    _successAnimController.reset();
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 56,
                  color: AppTheme.mutedText(context),
                ),
                const SizedBox(height: 16),
                Text(
                  'ไม่มีสิทธิ์เข้าถึง',
                  style: GoogleFonts.anuphan(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'บัญชีนี้ไม่มีสิทธิ์เช็คอินลูกค้า กรุณาติดต่อผู้ดูแลระบบ',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anuphan(
                    color: AppTheme.mutedText(context),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final booking = _booking;
    final checkedIn = booking?['checked_in'] == true;
    final canConfirm =
        booking != null &&
        textOf(booking['status']).toLowerCase() == 'confirmed' &&
        !checkedIn &&
        !_confirming;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: const Text('เช็คอินลูกค้า'),
        actions: [
          if (booking != null)
            IconButton(
              tooltip: 'ค้นหาใหม่',
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final code = _currentCode;
          if (code != null && code.isNotEmpty) await _lookup(code);
        },
        color: AppTheme.primaryColor,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            120 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            // ── Scanner panel ──────────────────────────────────────
            _ScannerPanel(
              controller: _manualController,
              focusNode: _focusNode,
              loading: _loading,
              onScan: _openScanner,
              onLookup: () {
                final code = _manualController.text.trim();
                if (code.isNotEmpty) _lookup(code);
              },
            ),

            // ── Message banners ────────────────────────────────────
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
              ScaleTransition(
                scale: _successScale,
                child: _MessageBanner(
                  icon: Icons.verified_rounded,
                  text: _success!,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // ── Body ───────────────────────────────────────────────
            if (_loading)
              _LoadingCard()
            else if (booking == null)
              const _EmptyState()
            else ...[
              _BookingDetail(booking: booking),
              const SizedBox(height: 16),

              // ── Check-in button ──────────────────────────────────
              _CheckInButton(
                checkedIn: checkedIn,
                canConfirm: canConfirm,
                confirming: _confirming,
                booking: booking,
                onConfirm: _confirm,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scanner Panel
// ─────────────────────────────────────────────────────────────────────────────

class _ScannerPanel extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final VoidCallback onScan;
  final VoidCallback onLookup;

  const _ScannerPanel({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.onScan,
    required this.onLookup,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      decoration: AppTheme.cardDecoration(context, radius: 24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header gradient strip
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppTheme.primaryColor.withValues(alpha: 0.24),
                        AppTheme.accentColor.withValues(alpha: 0.10),
                      ]
                    : [
                        AppTheme.primaryColor.withValues(alpha: 0.08),
                        AppTheme.accentColor.withValues(alpha: 0.04),
                      ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สแกน QR เช็คอิน',
                        style: GoogleFonts.anuphan(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      Text(
                        'สแกน QR หรือกรอกรหัสการจองด้วยตนเอง',
                        style: GoogleFonts.anuphan(
                          fontSize: 12,
                          color: AppTheme.mutedText(context),
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: loading ? null : onScan,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: Text(
                    loading ? 'กำลังโหลด...' : 'เปิดกล้องสแกน QR',
                    style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.border(context))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'หรือกรอกรหัส',
                        style: GoogleFonts.anuphan(
                          fontSize: 12,
                          color: AppTheme.mutedText(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppTheme.border(context))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => onLookup(),
                  style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: 'กรอก QR Code หรือเลขการจอง',
                    prefixIcon: Icon(
                      Icons.confirmation_number_outlined,
                      color: AppTheme.mutedText(context),
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      onPressed: loading ? null : onLookup,
                      icon: Icon(
                        Icons.search_rounded,
                        color: loading
                            ? AppTheme.mutedText(context)
                            : AppTheme.primaryColor,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Check-in Button
// ─────────────────────────────────────────────────────────────────────────────

class _CheckInButton extends StatelessWidget {
  final bool checkedIn;
  final bool canConfirm;
  final bool confirming;
  final Map<String, dynamic> booking;
  final VoidCallback onConfirm;

  const _CheckInButton({
    required this.checkedIn,
    required this.canConfirm,
    required this.confirming,
    required this.booking,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    if (checkedIn) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'เช็คอินเรียบร้อยแล้ว',
              style: GoogleFonts.anuphan(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    final isPending =
        textOf(booking['status']).toLowerCase() != 'confirmed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPending) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.warningColor.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warningColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'การจองนี้ยังไม่ได้รับการยืนยัน ไม่สามารถเช็คอินได้',
                    style: GoogleFonts.anuphan(
                      fontSize: 13,
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 58,
          child: ElevatedButton(
            onPressed: canConfirm ? onConfirm : null,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: confirming
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'กำลังเช็คอิน...',
                        style: GoogleFonts.anuphan(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.how_to_reg_rounded, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'ยืนยันเช็คอิน',
                        style: GoogleFonts.anuphan(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking Detail
// ─────────────────────────────────────────────────────────────────────────────

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
    final status = textOf(booking['status']).toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Booking header card ──────────────────────────────────
        _BookingHeaderCard(
          booking: booking,
          user: user,
          checkedIn: checkedIn,
          status: status,
        ),
        const SizedBox(height: 12),

        // ── Trip card ────────────────────────────────────────────
        _SectionCard(
          icon: Icons.landscape_rounded,
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
                ].where((v) => v.isNotEmpty).join(' · '),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Payment card ─────────────────────────────────────────
        _SectionCard(
          icon: Icons.payments_rounded,
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

        // ── Passengers card ──────────────────────────────────────
        _SectionCard(
          icon: Icons.group_rounded,
          title: 'ผู้เดินทาง',
          trailingBadge: passengers.length.toString(),
          children: passengers.isEmpty
              ? [const _MutedText('ไม่มีข้อมูลผู้เดินทาง')]
              : passengers.map((passenger) {
                  return _PassengerTile(
                    passenger: passenger,
                    seat: seats.firstWhere(
                      (seat) =>
                          textOf(seat['passenger_name']) ==
                          textOf(passenger['name']),
                      orElse: () => <String, dynamic>{},
                    ),
                  );
                }).toList(),
        ),

        // ── Staff card ───────────────────────────────────────────
        if (staff.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.badge_rounded,
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

class _BookingHeaderCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> user;
  final bool checkedIn;
  final String status;

  const _BookingHeaderCard({
    required this.booking,
    required this.user,
    required this.checkedIn,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final chipColor = checkedIn ? AppTheme.primaryColor : statusColor(status);
    final chipLabel = checkedIn ? 'เช็คอินแล้ว' : statusLabel(status);

    return Container(
      decoration: AppTheme.cardDecoration(context, radius: 24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colored top bar
          Container(
            height: 5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: checkedIn
                    ? [AppTheme.primaryColor, AppTheme.accentColor]
                    : [chipColor, chipColor.withValues(alpha: 0.6)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ref + status chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เลขการจอง',
                            style: GoogleFonts.anuphan(
                              fontSize: 11,
                              color: AppTheme.mutedText(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            textOf(booking['booking_ref'], '-'),
                            style: GoogleFonts.anuphan(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.onSurface(context),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(label: chipLabel, color: chipColor),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  color: AppTheme.border(context).withValues(alpha: 0.5),
                  height: 1,
                ),
                const SizedBox(height: 14),

                // Customer info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isDark
                          ? AppTheme.primaryColor.withValues(alpha: 0.18)
                          : AppTheme.primaryColor.withValues(alpha: 0.12),
                      child: Text(
                        _initials(textOf(user['name'])),
                        style: GoogleFonts.anuphan(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            textOf(user['name'], '-'),
                            style: GoogleFonts.anuphan(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                          if (textOf(user['phone']).isNotEmpty)
                            Text(
                              textOf(user['phone']),
                              style: GoogleFonts.anuphan(
                                fontSize: 13,
                                color: AppTheme.mutedText(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (textOf(user['email']).isNotEmpty)
                            Text(
                              textOf(user['email']),
                              style: GoogleFonts.anuphan(
                                fontSize: 12,
                                color: AppTheme.mutedText(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (checkedIn) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'เช็คอินเมื่อ ${dateTimeText(booking['checked_in_at'])}',
                          style: GoogleFonts.anuphan(
                            fontSize: 13,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR Scanner Screen
// ─────────────────────────────────────────────────────────────────────────────

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
          // Camera
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_handled || capture.barcodes.isEmpty) return;
              final value = capture.barcodes.first.rawValue;
              if (value == null || value.trim().isEmpty) return;
              _handled = true;
              HapticFeedback.mediumImpact();
              Navigator.pop(context, value.trim());
            },
          ),

          // Overlay dimming except center
          _ScannerOverlay(),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _GlassButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
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
                  _GlassButton(
                    onPressed: () => _controller.toggleTorch(),
                    child: const Icon(
                      Icons.flashlight_on_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scan frame
          Center(
            child: _ScanFrame(size: 248),
          ),

          // Bottom hint
          Positioned(
            left: 32,
            right: 32,
            bottom: 56,
            child: Text(
              'วาง QR ให้อยู่ในกรอบสีขาว\nระบบจะดึงข้อมูลการจองโดยอัตโนมัติ',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const frameSize = 248.0;
    const cornerRadius = 28.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: frameSize,
      height: frameSize,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(cornerRadius)),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanFrame extends StatelessWidget {
  final double size;

  const _ScanFrame({required this.size});

  @override
  Widget build(BuildContext context) {
    const stroke = 3.5;
    const cornerLength = 32.0;
    const radius = 28.0;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          stroke: stroke,
          cornerLength: cornerLength,
          radius: radius,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double stroke;
  final double cornerLength;
  final double radius;

  const _CornerPainter({
    required this.stroke,
    required this.cornerLength,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = radius;
    final cl = cornerLength;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, cl + r)
        ..lineTo(0, r)
        ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
        ..lineTo(cl + r, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - cl - r, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
        ..lineTo(w, cl + r),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w, h - cl - r)
        ..lineTo(w, h - r)
        ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
        ..lineTo(w - cl - r, h),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(cl + r, h)
        ..lineTo(r, h)
        ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
        ..lineTo(0, h - cl - r),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _GlassButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.20),
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingBadge;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context, radius: 22),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.anuphan(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              if (trailingBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trailingBadge!,
                    style: GoogleFonts.anuphan(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            color: AppTheme.border(context).withValues(alpha: 0.5),
            height: 1,
          ),
          const SizedBox(height: 4),
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
    final notes = <String>[];
    final phone = textOf(passenger['phone']);
    final seatId = textOf(seat['seat_id']);
    if (phone.isNotEmpty) notes.add('โทร $phone');
    if (seatId.isNotEmpty) notes.add('ที่นั่ง $seatId');
    if (passenger['halal_food'] == true) notes.add('อาหารฮาลาล');
    final allergies = textOf(passenger['allergies']);
    final healthNotes = textOf(passenger['health_notes']);
    if (allergies.isNotEmpty) notes.add('แพ้ $allergies');
    if (healthNotes.isNotEmpty) notes.add(healthNotes);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.10),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.primaryColor,
              size: 18,
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
                    fontSize: 14,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: notes
                        .map(
                          (note) => _NoteChip(note),
                        )
                        .toList(),
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

class _NoteChip extends StatelessWidget {
  final String text;

  const _NoteChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.anuphan(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.mutedText(context),
        ),
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
          Icon(icon, size: 16, color: AppTheme.mutedText(context)),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.anuphan(
          fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.anuphan(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context, radius: 22),
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'กำลังดึงข้อมูลการจอง...',
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.qr_code_2_rounded,
              size: 44,
              color: AppTheme.primaryColor.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีข้อมูลการจอง',
            style: GoogleFonts.anuphan(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'สแกน QR หรือกรอกเลขการจอง\nเพื่อดูรายละเอียดก่อนยืนยันเช็คอิน',
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              fontSize: 14,
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w600,
              height: 1.55,
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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: GoogleFonts.anuphan(
          color: AppTheme.mutedText(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilities
// ─────────────────────────────────────────────────────────────────────────────

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
  return NumberFormat.currency(locale: 'th_TH', symbol: '฿').format(
    number ?? 0,
  );
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
