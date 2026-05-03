import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/tracking_model.dart';
import '../providers/app_provider.dart';
import '../providers/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';
import 'login_screen.dart';
import 'tracking_screen.dart';

enum _TrackEntryState { notStarted, ready, invalid, expired }

class BookingLookupScreen extends StatelessWidget {
  final bool embedded;
  final VoidCallback? onOpenBookings;

  const BookingLookupScreen({
    super.key,
    this.embedded = false,
    this.onOpenBookings,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.isLoggedIn) {
      return const LoginScreen(popOnSuccess: false);
    }

    return TrackVehiclePage(embedded: embedded, onOpenBookings: onOpenBookings);
  }
}

class TrackVehiclePage extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenBookings;

  const TrackVehiclePage({
    super.key,
    this.embedded = false,
    this.onOpenBookings,
  });

  @override
  State<TrackVehiclePage> createState() => _TrackVehiclePageState();
}

class _TrackVehiclePageState extends State<TrackVehiclePage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<Uri>? _linkSubscription;
  bool _isLoading = false;
  bool _hasText = false;
  String? _error;
  _TrackEntryState? _state;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _controller
      ..removeListener(_onInputChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    if (_error != null || _state == _TrackEntryState.invalid) {
      setState(() {
        _error = null;
        _state = _validFormat(_controller.text) ? _TrackEntryState.ready : null;
      });
    } else if (_validFormat(_controller.text) && _state == null) {
      setState(() => _state = _TrackEntryState.ready);
    }
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleIncomingUri(initial, autoStart: true);
        });
      }
    } catch (_) {
      // Deep links are opportunistic; the manual entry remains the fallback.
    }

    _linkSubscription = appLinks.uriLinkStream.listen((uri) {
      if (mounted) _handleIncomingUri(uri, autoStart: true);
    });
  }

  void _handleIncomingUri(Uri uri, {required bool autoStart}) {
    final code = _extractBookingRef(uri.toString());
    if (code == null) return;
    _controller.text = code;
    _focusNode.unfocus();
    if (autoStart) _onTrack();
  }

  Future<void> _onTrack([String? code]) async {
    final app = context.read<AppProvider>();
    if (!app.isLoggedIn || app.token == null) {
      return;
    }

    final raw = (code ?? _controller.text).trim().toUpperCase();
    final ref = _extractBookingRef(raw) ?? raw;

    if (ref.isEmpty) {
      setState(() {
        _state = _TrackEntryState.invalid;
        _error = 'กรุณากรอกรหัสการจอง';
      });
      return;
    }

    if (!_validFormat(ref)) {
      setState(() {
        _state = _TrackEntryState.invalid;
        _error = 'รูปแบบรหัสไม่ถูกต้อง เช่น LLK-20250409-0001';
      });
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _controller.text = ref;
      _isLoading = true;
      _error = null;
      _state = _TrackEntryState.ready;
    });

    final provider = context.read<TrackingProvider>();
    await provider.startTracking(ref, authToken: app.token);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (provider.errorMessage.isNotEmpty) {
      setState(() {
        _state = _TrackEntryState.invalid;
        _error = provider.errorMessage;
      });
      return;
    }

    final gate = _stateForBooking(provider.booking);
    if (gate == _TrackEntryState.notStarted ||
        gate == _TrackEntryState.expired) {
      provider.stopTracking();
      setState(() => _state = gate);
      return;
    }

    HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: const TrackingMapPage()),
      ),
    );
  }

  Future<void> _scanQr() async {
    final scanned = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _QrScanScreen()));
    final code = scanned == null ? null : _extractBookingRef(scanned);
    if (code == null || !mounted) return;
    _controller.text = code;
    _focusNode.unfocus();
    await _onTrack(code);
  }

  void _openBookings() {
    HapticFeedback.selectionClick();
    if (widget.onOpenBookings != null) {
      widget.onOpenBookings!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิดหน้าการจองของฉันจากแท็บการจอง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.background(
                context,
              ).withValues(alpha: 0.92),
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              title: Text(
                'ติดตามรถ',
                style: GoogleFonts.anuphan(
                  color: AppTheme.onSurface(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              leading: !widget.embedded && Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 120 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HeroTrackingHeader(),
                    const SizedBox(height: 24),
                    BookingCodeField(
                      controller: _controller,
                      focusNode: _focusNode,
                      error: _error,
                      onSubmitted: _onTrack,
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _state == null
                          ? const SizedBox.shrink()
                          : EntryTrackingStatusBanner(
                              key: ValueKey(_state),
                              state: _state!,
                              onAction: _state == _TrackEntryState.invalid
                                  ? () {
                                      _controller.clear();
                                      _focusNode.requestFocus();
                                    }
                                  : _openBookings,
                            ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryTrackButton(
                      isLoading: _isLoading,
                      enabled: _hasText && !_isLoading,
                      onPressed: _onTrack,
                    ),
                    const SizedBox(height: 16),
                    SmartEntryOptions(
                      onScanQr: _scanQr,
                      onOpenBookings: _openBookings,
                      onPaste: () async {
                        final data = await Clipboard.getData('text/plain');
                        final code = _extractBookingRef(data?.text ?? '');
                        if (code == null) return;
                        _controller.text = code;
                      },
                    ),
                    const SizedBox(height: 32),
                    RecentBookingsSection(onTrack: _onTrack),
                    const SizedBox(height: 24),
                    HelpSection(onOpenBookings: _openBookings),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validFormat(String value) {
    return RegExp(
      r'^LLK-\d{8}-\d{4}$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  String? _extractBookingRef(String raw) {
    final match = RegExp(
      r'LLK-\d{8}-\d{4}',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match != null) return match.group(0)!.toUpperCase();

    final compact = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final compactMatch = RegExp(r'^LLK(\d{8})(\d{4})$').firstMatch(compact);
    if (compactMatch == null) return null;
    return 'LLK-${compactMatch.group(1)}-${compactMatch.group(2)}';
  }

  _TrackEntryState _stateForBooking(BookingInfo? booking) {
    if (booking == null) return _TrackEntryState.invalid;
    final status = booking.status.toLowerCase();
    if (status == 'completed' ||
        status == 'cancelled' ||
        status == 'refunded') {
      return _TrackEntryState.expired;
    }

    final tripDate = DateTime.tryParse(booking.departureDate);
    if (tripDate == null) return _TrackEntryState.ready;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(tripDate.year, tripDate.month, tripDate.day);
    if (date.isAfter(today)) return _TrackEntryState.notStarted;
    if (date.isBefore(today)) return _TrackEntryState.expired;
    return _TrackEntryState.ready;
  }
}

class HeroTrackingHeader extends StatelessWidget {
  const HeroTrackingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MiniMapPreview(),
          const SizedBox(height: 20),
          Text(
            'ติดตามรถของคุณแบบเรียลไทม์',
            style: GoogleFonts.anuphan(
              fontSize: 26,
              height: 1.16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ดูตำแหน่งรถและเวลาถึงโดยประมาณ',
            style: GoogleFonts.anuphan(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMapPreview extends StatelessWidget {
  const _MiniMapPreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 136,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFFEFF3F1)),
            CustomPaint(painter: _MapPreviewPainter()),
            Positioned(
              left: 26,
              bottom: 28,
              child: _PreviewPin(
                color: AppTheme.primaryColor,
                icon: Icons.location_on_rounded,
              ),
            ),
            Positioned(
              right: 30,
              top: 24,
              child: _PreviewPin(
                color: const Color(0xFF111111),
                icon: Icons.flag_rounded,
              ),
            ),
            Positioned(
              left: 118,
              top: 52,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_bus_filled_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final routePaint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final gridPaint = Paint()
      ..color = const Color(0xFFD9E2DD)
      ..strokeWidth = 1;

    for (var x = -20.0; x < size.width; x += 54) {
      canvas.drawLine(Offset(x, 0), Offset(x + 56, size.height), gridPaint);
    }
    for (var y = 20.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 20), gridPaint);
    }

    final path = Path()
      ..moveTo(28, size.height - 28)
      ..cubicTo(90, size.height - 42, 76, 42, 142, 66)
      ..cubicTo(188, 82, 198, 28, size.width - 36, 34);
    canvas.drawPath(path, roadPaint);
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PreviewPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _PreviewPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class BookingCodeField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final VoidCallback onSubmitted;

  const BookingCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รหัสการจอง',
          style: GoogleFonts.anuphan(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasError ? AppTheme.errorColor : AppTheme.border(context),
              width: hasError ? 1.4 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.characters,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [_BookingCodeFormatter()],
            textInputAction: TextInputAction.go,
            style: GoogleFonts.anuphan(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: 0.4,
            ),
            decoration: InputDecoration(
              hintText: 'LLK-20250409-0001',
              hintStyle: GoogleFonts.anuphan(
                color: const Color(0xFF98A2B3),
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.confirmation_number_outlined,
                color: AppTheme.primaryColor,
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: controller.clear,
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: GoogleFonts.anuphan(
              color: AppTheme.errorColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class PrimaryTrackButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const PrimaryTrackButton({
    super.key,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isLoading ? 0.99 : 1,
      duration: const Duration(milliseconds: 140),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: enabled ? AppTheme.primaryColor : const Color(0xFFD0D5DD),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.82),
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.near_me_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'ติดตามรถของฉัน',
                        style: GoogleFonts.anuphan(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class SmartEntryOptions extends StatelessWidget {
  final VoidCallback onScanQr;
  final VoidCallback onOpenBookings;
  final VoidCallback onPaste;

  const SmartEntryOptions({
    super.key,
    required this.onScanQr,
    required this.onOpenBookings,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SmartOption(
            icon: Icons.qr_code_scanner_rounded,
            label: 'สแกน QR',
            onTap: onScanQr,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SmartOption(
            icon: Icons.event_available_rounded,
            label: 'จากการจอง',
            onTap: onOpenBookings,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SmartOption(
            icon: Icons.content_paste_rounded,
            label: 'วางรหัส',
            onTap: onPaste,
          ),
        ),
      ],
    );
  }
}

class _SmartOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmartOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentBookingsSection extends StatelessWidget {
  final Future<void> Function(String code) onTrack;

  const RecentBookingsSection({super.key, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final bookings = app.bookings
        .map(asMap)
        .where(
          (booking) =>
              textOf(booking['booking_ref']).isNotEmpty &&
              textOf(booking['status']).toLowerCase() == 'confirmed',
        )
        .take(3)
        .toList();

    if (bookings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'การจองที่สำเร็จ',
          style: GoogleFonts.anuphan(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 12),
        ...bookings.map(
          (booking) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RecentBookingCard(
              booking: booking,
              onTrack: () => onTrack(textOf(booking['booking_ref'])),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTrack;

  const _RecentBookingCard({required this.booking, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final title = textOf(
      trip['title'],
      textOf(booking['trip_title'], 'ทริปของคุณ'),
    );
    final date = _shortThaiDate(schedule['departure_date']);

    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTrack,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$title • $date',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: onTrack,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  'ติดตาม',
                  style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortThaiDate(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return 'รอระบุวัน';
    return DateFormat('d MMM', 'th_TH').format(date);
  }
}

class HelpSection extends StatelessWidget {
  final VoidCallback onOpenBookings;

  const HelpSection({super.key, required this.onOpenBookings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'หารหัสการจองไม่เจอ?',
                style: GoogleFonts.anuphan(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AppTheme.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'รหัสอยู่ในรายละเอียดการจอง หรืออีเมลยืนยันการจองของคุณ',
            style: GoogleFonts.anuphan(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenBookings,
            icon: const Icon(Icons.event_note_rounded, size: 18),
            label: Text(
              'ไปที่การจองของฉัน',
              style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EntryTrackingStatusBanner extends StatelessWidget {
  final _TrackEntryState state;
  final VoidCallback onAction;

  const EntryTrackingStatusBanner({
    super.key,
    required this.state,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final spec = switch (state) {
      _TrackEntryState.ready => (
        icon: Icons.check_circle_rounded,
        title: 'พร้อมติดตาม',
        body: 'ระบบจะพาคุณไปยังแผนที่ติดตามรถแบบเรียลไทม์',
        action: 'เริ่มเลย',
        color: AppTheme.primaryColor,
      ),
      _TrackEntryState.notStarted => (
        icon: Icons.schedule_rounded,
        title: 'ทริปยังไม่เริ่ม',
        body: 'คุณสามารถกลับมาติดตามรถได้เมื่อถึงวันเดินทาง',
        action: 'ไปที่การจอง',
        color: AppTheme.warningColor,
      ),
      _TrackEntryState.invalid => (
        icon: Icons.error_rounded,
        title: 'รหัสไม่ถูกต้อง',
        body: 'ตรวจสอบรหัสการจองหรือสแกน QR จากรายละเอียดการจอง',
        action: 'ล้างรหัส',
        color: AppTheme.errorColor,
      ),
      _TrackEntryState.expired => (
        icon: Icons.history_rounded,
        title: 'ทริปหมดแล้ว',
        body: 'ทริปนี้สิ้นสุดแล้ว คุณยังดูรายละเอียดได้จากการจองของฉัน',
        action: 'ไปที่การจอง',
        color: const Color(0xFF667085),
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: spec.color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(spec.icon, color: spec.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.title,
                  style: GoogleFonts.anuphan(
                    color: AppTheme.textMain,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spec.body,
                  style: GoogleFonts.anuphan(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (state != _TrackEntryState.ready)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: spec.color,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                spec.action,
                style: GoogleFonts.anuphan(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
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
              if (value == null || value.isEmpty) return;
              _handled = true;
              Navigator.pop(context, value);
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
                      'สแกน QR เพื่อติดตามรถ',
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
              'วาง QR ให้อยู่ในกรอบ ระบบจะเปิดแผนที่ให้อัตโนมัติ',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final compact = newValue.text
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    final limited = compact.length > 15 ? compact.substring(0, 15) : compact;
    final parts = <String>[];
    if (limited.isNotEmpty)
      parts.add(limited.substring(0, limited.length.clamp(0, 3)));
    if (limited.length > 3)
      parts.add(limited.substring(3, limited.length.clamp(3, 11)));
    if (limited.length > 11) parts.add(limited.substring(11));
    final text = parts.join('-');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
