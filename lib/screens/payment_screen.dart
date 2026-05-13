import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/active_seat_lock_overlay.dart';
import '../widgets/travel_widgets.dart';
import 'booking_flow_screen.dart';

const Color _accent = Color(0xFF059669);
const String _promptPayId = '004999239362071';
const String _displayPromptPayId = '004-99923936-2071';
const String _bankAccount = '230-139095-8';

// ─────────────────────────────────────────────────────────────────────────────
// PaymentScreen
// ─────────────────────────────────────────────────────────────────────────────

class PaymentScreen extends StatefulWidget {
  final String bookingRef;
  final String initialPaymentType;

  const PaymentScreen({
    super.key,
    required this.bookingRef,
    this.initialPaymentType = 'full',
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Future<Map<String, dynamic>> _future;
  String _paymentType = 'full';
  String _paymentMethod = 'promptpay';
  DateTime? _transferDate;
  TimeOfDay? _transferTime;
  XFile? _slipImage;
  bool _paying = false;
  bool _downloadingQr = false;
  final GlobalKey _promptPayQrKey = GlobalKey();
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _paymentType = widget.initialPaymentType == 'installment'
        ? 'installment'
        : 'full';
    _future = _loadBooking();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppProvider>().loadActiveSeatLocks(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadBooking() async {
    final booking = await context.read<AppProvider>().booking(
      widget.bookingRef,
    );
    final currentType = textOf(booking['payment_type'], 'full');
    _paymentType = _normalizePaymentType(
      booking,
      currentType == 'installment' ? 'installment' : _paymentType,
    );
    return booking;
  }

  void _reload() {
    setState(() {
      _future = _loadBooking();
    });
  }

  Future<void> _pickTransferDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _transferDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 1)),
      helpText: 'วันที่โอนเงิน',
    );
    if (picked != null) setState(() => _transferDate = picked);
  }

  Future<void> _pickTransferTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _transferTime ?? TimeOfDay.now(),
      helpText: 'เวลาที่โอนเงิน',
    );
    if (picked != null) setState(() => _transferTime = picked);
  }

  Future<void> _pickSlip(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (image != null) setState(() => _slipImage = image);
    } catch (e) {
      if (mounted) _showSnack('ไม่สามารถเลือกรูปสลิปได้: $e');
    }
  }

  Future<void> _chooseSlipSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: 'เลือกรูปจากเครื่อง',
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
              _SourceTile(
                icon: Icons.photo_camera_rounded,
                label: 'ถ่ายรูปสลิป',
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickSlip(source);
  }

  Future<void> _submit(Map<String, dynamic> booking) async {
    if (textOf(booking['status']) != 'pending') return;
    if (_transferDate == null || _transferTime == null) {
      _showSnack('กรุณาระบุวันที่และเวลาที่โอนเงินตามสลิป');
      return;
    }
    if (_slipImage == null) {
      _showSnack('กรุณาแนบรูปภาพสลิปก่อนยืนยันการชำระเงิน');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _paying = true);
    try {
      final paymentType = _normalizePaymentType(booking, _paymentType);
      final amount = _amountDue(booking, paymentType);
      await context.read<AppProvider>().confirmPayment(
        bookingRef: widget.bookingRef,
        amount: amount,
        paymentType: paymentType,
        paymentMethod: _paymentMethod,
        transferDate: DateFormat('yyyy-MM-dd').format(_transferDate!),
        transferTime:
            '${_transferTime!.hour.toString().padLeft(2, '0')}:${_transferTime!.minute.toString().padLeft(2, '0')}',
        slipImagePath: _slipImage!.path,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await showDialog<void>(
        context: context,
        builder: (_) => _SuccessDialog(amount: amount),
      );
      _reload();
    } catch (e) {
      if (mounted) _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _copy(String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    _showSnack(message);
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _downloadPromptPayQr() async {
    if (_downloadingQr) return;
    setState(() => _downloadingQr = true);
    try {
      final renderObject = _promptPayQrKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw Exception('ไม่พบ QR CODE สำหรับดาวน์โหลด');
      }
      final image = await renderObject.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw Exception('ไม่สามารถสร้างรูป QR CODE ได้');
      final file = await _saveQrImage(byteData.buffer.asUint8List());
      if (!mounted) return;
      _showSnack('ดาวน์โหลด QR CODE แล้ว: ${file.path}');
    } catch (e) {
      if (mounted) _showSnack('ไม่สามารถดาวน์โหลด QR CODE ได้: $e');
    } finally {
      if (mounted) setState(() => _downloadingQr = false);
    }
  }

  Future<File> _saveQrImage(Uint8List bytes) async {
    final safeRef = widget.bookingRef.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final fileName = 'luilaykhao-payment-$safeRef-qr.png';
    final directories = <Directory>[];
    if (Platform.isAndroid) {
      directories.add(Directory('/storage/emulated/0/Download'));
    }
    final dl = await _safeDownloadsDirectory();
    if (dl != null) directories.add(dl);
    directories.add(await getApplicationDocumentsDirectory());
    directories.add(Directory.systemTemp);

    Object? lastError;
    for (final dir in directories) {
      try {
        if (!await dir.exists()) await dir.create(recursive: true);
        return File('${dir.path}${Platform.pathSeparator}$fileName')
            .writeAsBytes(bytes, flush: true);
      } catch (e) {
        lastError = e;
      }
    }
    throw FileSystemException(
      'ไม่สามารถบันทึกไฟล์ QR CODE ได้',
      lastError?.toString(),
    );
  }

  Future<Directory?> _safeDownloadsDirectory() async {
    try {
      return await getDownloadsDirectory();
    } catch (_) {
      return null;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context).withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.onSurface(context),
        title: Text(
          'ชำระเงิน',
          style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingState();
          }
          if (!snapshot.hasData) {
            return _PaymentEmptyState(onRetry: _reload);
          }

          final booking = snapshot.data!;
          final schedule = asMap(booking['schedule']);
          final trip = asMap(schedule['trip']);
          final status = textOf(booking['status']);
          final checkInReady = status == 'confirmed';
          final paymentType = _normalizePaymentType(booking, _paymentType);
          final amountDue = _amountDue(booking, paymentType);
          final qrPayload = _buildPromptPayPayload(_promptPayId, amountDue);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _PaymentProgress(status: status),
              const SizedBox(height: 20),
              if (status == 'pending') ...[
                _PaymentNotice(),
                const SizedBox(height: 10),
                _PaymentCountdownBanner(booking: booking),
                const SizedBox(height: 16),
              ],
              if (checkInReady) ...[
                _PaymentCompletedCard(booking: booking),
                const SizedBox(height: 16),
              ],
              _BookingSummaryCard(
                booking: booking,
                trip: trip,
                schedule: schedule,
              ),
              const SizedBox(height: 16),
              const _SeatLockSection(),
              if (status == 'pending') ...[
                if (_installmentAvailable(booking)) ...[
                  _PaymentTypeSection(
                    booking: booking,
                    value: paymentType,
                    onChanged: (v) => setState(() => _paymentType = v),
                  ),
                  const SizedBox(height: 16),
                ],
                _PaymentMethodSection(
                  value: _paymentMethod,
                  amount: amountDue,
                  qrPayload: qrPayload,
                  qrKey: _promptPayQrKey,
                  downloadingQr: _downloadingQr,
                  onChanged: (v) => setState(() => _paymentMethod = v),
                  onDownloadQr: _downloadPromptPayQr,
                  onCopyAmount: () =>
                      _copy(amountDue.toStringAsFixed(2), 'คัดลอกยอดชำระแล้ว'),
                  onCopyAccount: () => _copy(
                    _paymentMethod == 'promptpay'
                        ? _promptPayId
                        : _bankAccount.replaceAll('-', ''),
                    'คัดลอกเลขบัญชีแล้ว',
                  ),
                ),
                const SizedBox(height: 16),
                _SlipUploadSection(
                  image: _slipImage,
                  onPick: _chooseSlipSource,
                  onRemove: () => setState(() => _slipImage = null),
                ),
                const SizedBox(height: 16),
                _TransferTimeSection(
                  date: _transferDate,
                  time: _transferTime,
                  onPickDate: _pickTransferDate,
                  onPickTime: _pickTransferTime,
                ),
                const SizedBox(height: 24),
                _SubmitButton(
                  paying: _paying,
                  amount: amountDue,
                  onPressed: () => _submit(booking),
                ),
              ],
              const SizedBox(height: 12),
              _HomeButton(onPressed: _goHome),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / Empty states
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _accent),
          const SizedBox(height: 16),
          Text(
            'กำลังโหลดข้อมูลการจอง...',
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

class _PaymentEmptyState extends StatelessWidget {
  final VoidCallback onRetry;

  const _PaymentEmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 38,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่พบข้อมูลการจอง',
              style: GoogleFonts.anuphan(
                color: AppTheme.onSurface(context),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'กรุณาลองใหม่อีกครั้ง',
              style: GoogleFonts.anuphan(
                color: AppTheme.mutedText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'ลองใหม่',
                style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress stepper
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentProgress extends StatelessWidget {
  final String status;

  const _PaymentProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (icon: Icons.search_rounded, label: 'เลือกทริป', done: true),
      (icon: Icons.edit_note_rounded, label: 'รายละเอียด', done: true),
      (
        icon: Icons.payments_rounded,
        label: 'ชำระเงิน',
        done: status == 'confirmed',
      ),
    ];

    return Row(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isActive = i == 2;
        final isDone = step.done;
        final color = isDone || isActive ? _accent : AppTheme.border(context);

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDone || isActive
                            ? _accent
                            : AppTheme.subtleSurface(context),
                        shape: BoxShape.circle,
                        boxShadow: isDone || isActive
                            ? [
                                BoxShadow(
                                  color: _accent.withValues(alpha: 0.30),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : step.icon,
                        color: isDone || isActive
                            ? Colors.white
                            : AppTheme.mutedText(context),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        color: isActive
                            ? _accent
                            : AppTheme.mutedText(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (i != steps.length - 1)
                Container(
                  width: 28,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment notice banner
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentNotice extends StatelessWidget {
  const _PaymentNotice();

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningTint(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.priority_high_rounded,
              color: AppTheme.warningColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'กรุณาชำระเงินและระบุเวลาโอนตามสลิป เพื่อยืนยันสิทธิ์การเดินทาง',
              style: GoogleFonts.anuphan(
                color: isDark
                    ? const Color(0xFFFCD34D)
                    : const Color(0xFF92400E),
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Countdown banner
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentCountdownBanner extends StatelessWidget {
  final Map<String, dynamic> booking;

  static const _kDeadlineMinutes = 10;

  const _PaymentCountdownBanner({required this.booking});

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(
      textOf(booking['created_at']),
    )?.toLocal();
    if (createdAt == null) return const SizedBox.shrink();

    final deadline = createdAt.add(const Duration(minutes: _kDeadlineMinutes));
    final remaining = deadline.difference(DateTime.now());
    final expired = remaining.isNegative || remaining.inSeconds <= 0;
    final isUrgent = !expired && remaining.inSeconds <= 120;

    final color = expired || isUrgent ? AppTheme.errorColor : _accent;
    final bgColor = color.withValues(
      alpha: AppTheme.isDark(context) ? 0.15 : 0.08,
    );

    final String timeText;
    if (expired) {
      timeText = 'หมดเวลาแล้ว';
    } else {
      final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      timeText = '$m:$s';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              expired ? Icons.timer_off_rounded : Icons.timer_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expired ? 'หมดเวลาชำระเงิน' : 'เหลือเวลาชำระเงิน',
                  style: GoogleFonts.anuphan(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expired
                      ? 'กรุณาติดต่อเจ้าหน้าที่หากต้องการจองใหม่'
                      : 'การจองจะถูกยกเลิกอัตโนมัติหากไม่ชำระภายใน $_kDeadlineMinutes นาทีจากการจอง',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.mutedText(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            timeText,
            style: GoogleFonts.anuphan(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: expired ? 13 : 22,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seat lock section
// ─────────────────────────────────────────────────────────────────────────────

class _SeatLockSection extends StatefulWidget {
  const _SeatLockSection();

  @override
  State<_SeatLockSection> createState() => _SeatLockSectionState();
}

class _SeatLockSectionState extends State<_SeatLockSection> {
  Timer? _ticker;
  int? _busyScheduleId;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool _isActive(Map<String, dynamic> lock) {
    final lockedUntil = DateTime.tryParse(textOf(lock['locked_until']));
    if (lockedUntil != null) {
      return lockedUntil.difference(DateTime.now()).inSeconds > 0;
    }
    return (int.tryParse(textOf(lock['locked_ttl_seconds'])) ?? 0) > 0;
  }

  Future<void> _continueBooking(Map<String, dynamic> lock) async {
    final app = context.read<AppProvider>();
    final trip = asMap(lock['trip']);
    final slug = textOf(trip['slug']);
    final scheduleId = int.tryParse(textOf(lock['schedule_id']));
    if (slug.isEmpty || scheduleId == null) return;

    setState(() => _busyScheduleId = scheduleId);
    try {
      final results = await Future.wait([app.trip(slug), app.schedules(slug)]);
      if (!mounted) return;
      final seatIds = asList(lock['seat_ids'])
          .map((item) => item?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final pickupPointId = int.tryParse(textOf(lock['pickup_point_id']));
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingFlowScreen(
            trip: Map<String, dynamic>.from(results[0] as Map),
            schedules: List<dynamic>.from(results[1] as List),
            initialScheduleId: scheduleId,
            initialPickupPointId: pickupPointId,
            initialSeatIds: seatIds,
            resumeLockedSeats: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busyScheduleId = null);
    }
  }

  Future<void> _cancelLock(Map<String, dynamic> lock) async {
    final app = context.read<AppProvider>();
    final trip = asMap(lock['trip']);
    final slug = textOf(trip['slug']);
    final scheduleId = int.tryParse(textOf(lock['schedule_id']));
    if (slug.isEmpty || scheduleId == null) return;
    final seatIds = asList(lock['seat_ids'])
        .map((item) => item?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final pickupPointId = int.tryParse(textOf(lock['pickup_point_id']));

    setState(() => _busyScheduleId = scheduleId);
    try {
      final results = await Future.wait([app.trip(slug), app.schedules(slug)]);
      await app.cancelActiveSeatLock(scheduleId, seatIds: seatIds);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('ยกเลิกการจองแล้ว เลือกที่นั่งใหม่ได้เลย')),
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingFlowScreen(
            trip: Map<String, dynamic>.from(results[0] as Map),
            schedules: List<dynamic>.from(results[1] as List),
            initialScheduleId: scheduleId,
            initialPickupPointId: pickupPointId,
            startAtSeatSelection: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busyScheduleId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locks = context
        .watch<AppProvider>()
        .activeSeatLocks
        .map(asMap)
        .where(_isActive)
        .toList();

    if (locks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'ที่นั่งที่รอการจอง',
            style: GoogleFonts.anuphan(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
        ),
        ...locks.map((lock) {
          final scheduleId = int.tryParse(textOf(lock['schedule_id']));
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ActiveSeatLockBanner(
              lock: lock,
              extraCount: 0,
              busy: _busyScheduleId == scheduleId,
              onContinue: () => _continueBooking(lock),
              onCancel: () => _cancelLock(lock),
            ),
          );
        }),
        const SizedBox(height: 6),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking summary card
// ─────────────────────────────────────────────────────────────────────────────

class _BookingSummaryCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> trip;
  final Map<String, dynamic> schedule;

  const _BookingSummaryCard({
    required this.booking,
    required this.trip,
    required this.schedule,
  });

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final passengers = asList(booking['passengers']);
    final seats = asList(booking['seats']);
    final selectedAddons = asList(booking['selected_addons']).map(asMap).toList();
    final pickupPoint = asMap(booking['pickup_point']);
    final pickupText = textOf(
      pickupPoint['pickup_location'] ??
          pickupPoint['region_label'] ??
          booking['pickup_region'],
      'ระบุก่อนเดินทาง',
    );
    final statusText = _statusLabel(textOf(booking['status']));
    final statusColor = _statusColor(textOf(booking['status']));

    return _SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trip hero image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: AspectRatio(
              aspectRatio: 16 / 8,
              child: image.isEmpty
                  ? Container(
                      color: AppTheme.subtleSurface(context),
                      child: const Icon(
                        Icons.landscape_rounded,
                        color: _accent,
                        size: 48,
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                        // gradient overlay for status badge readability
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.90),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusText,
                                style: GoogleFonts.anuphan(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trip title + status (no image case)
                if (image.isEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _StatusBadge(
                      label: statusText,
                      color: statusColor,
                    ),
                  ),
                Text(
                  textOf(trip['title'], 'รายละเอียดการจอง'),
                  style: GoogleFonts.anuphan(
                    color: AppTheme.onSurface(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                // Info pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      context: context,
                      icon: Icons.confirmation_number_outlined,
                      text: textOf(booking['booking_ref']),
                    ),
                    _InfoPill(
                      context: context,
                      icon: Icons.calendar_today_rounded,
                      text: dateText(schedule['departure_date']),
                    ),
                    _InfoPill(
                      context: context,
                      icon: Icons.group_rounded,
                      text: '${passengers.length} ท่าน',
                    ),
                    if (seats.isNotEmpty)
                      _InfoPill(
                        context: context,
                        icon: Icons.airline_seat_recline_extra_rounded,
                        text: seats
                            .map((s) => textOf(asMap(s)['seat_id']))
                            .join(', '),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const _Divider(),
                const SizedBox(height: 12),
                _SummaryRow(
                  icon: Icons.location_on_outlined,
                  label: 'จุดขึ้นรถ',
                  value: pickupText,
                ),
                if (selectedAddons.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...selectedAddons.map((addon) {
                    final qty = textOf(addon['quantity'], '1');
                    final name = textOf(addon['name'], 'ตัวเลือกเสริม');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SummaryRow(
                        icon: Icons.add_task_rounded,
                        label: qty == '1' ? name : '$name ×$qty',
                        value: money(addon['total_price']),
                        valueColor: AppTheme.warningColor,
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(
                      alpha: AppTheme.isDark(context) ? 0.15 : 0.07,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        color: _accent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'ยอดรวมทั้งหมด',
                        style: GoogleFonts.anuphan(
                          color: AppTheme.mutedText(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        money(booking['total_amount']),
                        style: GoogleFonts.anuphan(
                          color: _accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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
// Payment type section
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentTypeSection extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String value;
  final ValueChanged<String> onChanged;

  const _PaymentTypeSection({
    required this.booking,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final count = _installmentCount(booking);
    final perInstallment = _installmentAmount(booking);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.credit_card_rounded,
            title: 'รูปแบบการชำระ',
          ),
          const SizedBox(height: 14),
          _ChoiceTile(
            selected: value == 'full',
            icon: Icons.payments_rounded,
            title: 'ชำระเต็มจำนวน',
            subtitle: 'ยอดชำระ ${money(booking['total_amount'])}',
            onTap: () => onChanged('full'),
          ),
          const SizedBox(height: 10),
          _ChoiceTile(
            selected: value == 'installment',
            icon: Icons.calendar_month_rounded,
            title: 'ผ่อนชำระ $count งวด',
            subtitle:
                'งวดแรก ${money(perInstallment)} · ทุก ${_installmentInterval(booking)} วัน',
            onTap: () => onChanged('installment'),
          ),
          if (value == 'installment') ...[
            const SizedBox(height: 14),
            ..._installmentSchedule(booking).map(
              (row) => _InstallmentRow(row: row),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment method section
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodSection extends StatelessWidget {
  final String value;
  final num amount;
  final String qrPayload;
  final GlobalKey qrKey;
  final bool downloadingQr;
  final ValueChanged<String> onChanged;
  final VoidCallback onDownloadQr;
  final VoidCallback onCopyAmount;
  final VoidCallback onCopyAccount;

  const _PaymentMethodSection({
    required this.value,
    required this.amount,
    required this.qrPayload,
    required this.qrKey,
    required this.downloadingQr,
    required this.onChanged,
    required this.onDownloadQr,
    required this.onCopyAmount,
    required this.onCopyAccount,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.account_balance_wallet_rounded,
            title: 'ช่องทางชำระเงิน',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ChoiceTile(
                  selected: value == 'promptpay',
                  icon: Icons.qr_code_2_rounded,
                  title: 'QR PromptPay',
                  subtitle: 'สแกนจ่ายผ่านแอปธนาคาร',
                  compact: true,
                  onTap: () => onChanged('promptpay'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceTile(
                  selected: value == 'mobile_banking',
                  icon: Icons.account_balance_rounded,
                  title: 'โอนธนาคาร',
                  subtitle: 'โอนและระบุเวลาโอน',
                  compact: true,
                  onTap: () => onChanged('mobile_banking'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (value == 'promptpay')
            _PromptPayPanel(
              qrPayload: qrPayload,
              qrKey: qrKey,
              downloadingQr: downloadingQr,
              onDownload: onDownloadQr,
            )
          else
            _BankTransferPanel(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CopyButton(
                  icon: Icons.content_copy_rounded,
                  label: 'คัดลอกยอด ${money(amount)}',
                  onPressed: onCopyAmount,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CopyButton(
                  icon: Icons.numbers_rounded,
                  label: value == 'promptpay'
                      ? 'คัดลอกพร้อมเพย์'
                      : 'คัดลอกบัญชี',
                  onPressed: onCopyAccount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromptPayPanel extends StatelessWidget {
  final String qrPayload;
  final GlobalKey qrKey;
  final bool downloadingQr;
  final VoidCallback onDownload;

  const _PromptPayPanel({
    required this.qrPayload,
    required this.qrKey,
    required this.downloadingQr,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          RepaintBoundary(
            key: qrKey,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'พร้อมเพย์ / e-Wallet',
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _displayPromptPayId,
            style: GoogleFonts.anuphan(
              color: AppTheme.onSurface(context),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 220,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: downloadingQr ? null : onDownload,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: BorderSide(color: _accent.withValues(alpha: 0.30)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              icon: downloadingQr
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accent,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(
                downloadingQr ? 'กำลังดาวน์โหลด' : 'ดาวน์โหลด QR CODE',
                style: GoogleFonts.anuphan(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankTransferPanel extends StatelessWidget {
  const _BankTransferPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BankInfoRow(label: 'ธนาคาร', value: 'กสิกรไทย (KBANK)'),
        const SizedBox(height: 8),
        _BankInfoRow(label: 'ชื่อบัญชี', value: 'นายธีร์ธวัช พิพัฒน์เดชธน'),
        const SizedBox(height: 8),
        _BankInfoRow(label: 'เลขที่บัญชี', value: _bankAccount),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transfer time section
// ─────────────────────────────────────────────────────────────────────────────

class _TransferTimeSection extends StatelessWidget {
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _TransferTimeSection({
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.receipt_long_rounded,
            title: 'ข้อมูลจากสลิป',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_today_rounded,
                  label: 'วันที่โอน',
                  value: date == null
                      ? 'เลือกวันที่'
                      : DateFormat('d MMM yyyy', 'th_TH').format(date!),
                  filled: date != null,
                  onTap: onPickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  icon: Icons.schedule_rounded,
                  label: 'เวลาที่โอน',
                  value: time == null ? 'เลือกเวลา' : time!.format(context),
                  filled: time != null,
                  onTap: onPickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'กรอกวันและเวลาตามสลิปโอนเงิน เพื่อให้ทีมงานตรวจสอบได้รวดเร็ว',
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slip upload section
// ─────────────────────────────────────────────────────────────────────────────

class _SlipUploadSection extends StatelessWidget {
  final XFile? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _SlipUploadSection({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionTitle(
                  icon: Icons.upload_file_rounded,
                  title: 'แนบรูปภาพสลิป',
                ),
              ),
              _RequiredBadge(done: hasImage),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onPick,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: hasImage ? 280 : 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: hasImage ? Colors.black : AppTheme.fieldSurface(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: hasImage
                      ? _accent
                      : AppTheme.border(context),
                  width: hasImage ? 1.5 : 1,
                ),
              ),
              child: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: Image.file(
                            File(image!.path),
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: IconButton.filled(
                            onPressed: onRemove,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.errorColor,
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'พร้อมส่งตรวจสอบ',
                                  style: GoogleFonts.anuphan(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _accent.withValues(alpha: 0.20),
                            ),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_rounded,
                            color: _accent,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'แตะเพื่อแนบรูปภาพสลิป',
                          style: GoogleFonts.anuphan(
                            color: AppTheme.onSurface(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ต้องแนบทุกครั้งก่อนยืนยันการชำระเงิน',
                          style: GoogleFonts.anuphan(
                            color: AppTheme.mutedText(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completed / check-in card
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentCompletedCard extends StatefulWidget {
  final Map<String, dynamic> booking;

  const _PaymentCompletedCard({required this.booking});

  @override
  State<_PaymentCompletedCard> createState() => _PaymentCompletedCardState();
}

class _PaymentCompletedCardState extends State<_PaymentCompletedCard>
    with SingleTickerProviderStateMixin {
  final GlobalKey _qrKey = GlobalKey();
  bool _downloadingQr = false;
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _downloadQr() async {
    if (_downloadingQr) return;
    setState(() => _downloadingQr = true);
    try {
      final ro = _qrKey.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) {
        throw Exception('ไม่พบ QR CODE สำหรับดาวน์โหลด');
      }
      final image = await ro.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw Exception('ไม่สามารถสร้างรูป QR CODE ได้');

      final safeRef = textOf(widget.booking['booking_ref'], 'checkin')
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final fileName = 'luilaykhao-checkin-$safeRef-qr.png';
      final bytes = byteData.buffer.asUint8List();

      final directories = <Directory>[];
      if (Platform.isAndroid) {
        directories.add(Directory('/storage/emulated/0/Download'));
      }
      try {
        final dl = await getDownloadsDirectory();
        if (dl != null) directories.add(dl);
      } catch (_) {}
      directories.add(await getApplicationDocumentsDirectory());
      directories.add(Directory.systemTemp);

      File? saved;
      for (final dir in directories) {
        try {
          if (!await dir.exists()) await dir.create(recursive: true);
          saved = await File(
            '${dir.path}${Platform.pathSeparator}$fileName',
          ).writeAsBytes(bytes, flush: true);
          break;
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved != null
                ? 'ดาวน์โหลด QR CODE แล้ว: ${saved.path}'
                : 'ไม่สามารถบันทึกไฟล์ได้',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถดาวน์โหลด QR CODE ได้: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingRef = textOf(widget.booking['booking_ref'], '-');
    final checkInCode = textOf(widget.booking['qr_code']).trim();
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  _accent.withValues(alpha: 0.22),
                  const Color(0xFF059669).withValues(alpha: 0.08),
                ]
              : [
                  _accent.withValues(alpha: 0.09),
                  _accent.withValues(alpha: 0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _accent.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _accent.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: _accent,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'พร้อมสำหรับเช็คอิน',
            style: GoogleFonts.anuphan(
              color: AppTheme.onSurface(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'โปรดแสดงรหัสนี้แก่เจ้าหน้าที่เมื่อถึงจุดนัดหมาย',
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (checkInCode.isNotEmpty) ...[
            const SizedBox(height: 20),
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _accent.withValues(alpha: 0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: checkInCode,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _downloadingQr ? null : _downloadQr,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: BorderSide(color: _accent.withValues(alpha: 0.30)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                icon: _downloadingQr
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _downloadingQr ? 'กำลังดาวน์โหลด' : 'ดาวน์โหลด QR CODE',
                  style: GoogleFonts.anuphan(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _accent.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: [
                Text(
                  'รหัสการจอง',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.mutedText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  bookingRef,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anuphan(
                    color: _accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
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
// Submit / home buttons
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  final bool paying;
  final num amount;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.paying,
    required this.amount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        onPressed: paying ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _accent.withValues(alpha: 0.40),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.70),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: paying ? 0 : 2,
          shadowColor: _accent.withValues(alpha: 0.40),
        ),
        icon: paying
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.verified_user_rounded, size: 22),
        label: Text(
          paying ? 'กำลังบันทึก...' : 'ยืนยันการชำระ ${money(amount)}',
          style: GoogleFonts.anuphan(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HomeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: BorderSide(color: _accent.withValues(alpha: 0.32)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        icon: const Icon(Icons.home_rounded),
        label: Text(
          'กลับหน้าหลัก',
          style: GoogleFonts.anuphan(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  final num amount;

  const _SuccessDialog({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppTheme.surface(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _accent,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'แจ้งชำระเงินสำเร็จ',
              style: GoogleFonts.anuphan(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ระบบบันทึกข้อมูลการชำระเงิน ${money(amount)} แล้ว\nทีมงานจะตรวจสอบและยืนยันการจองให้เร็วๆ นี้',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                color: AppTheme.mutedText(context),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'ตกลง',
                  style: GoogleFonts.anuphan(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: AppTheme.cardDecoration(
        context,
        radius: 24,
        borderColor: AppTheme.border(context).withValues(alpha: 0.65),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _accent.withValues(
              alpha: AppTheme.isDark(context) ? 0.18 : 0.10,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _accent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.anuphan(
              color: AppTheme.onSurface(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(
                  alpha: AppTheme.isDark(context) ? 0.18 : 0.08,
                )
              : AppTheme.fieldSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _accent : AppTheme.border(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? _accent : AppTheme.mutedText(context),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: selected
                          ? _accent
                          : AppTheme.onSurface(context),
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 12.5 : 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.mutedText(context),
                      fontSize: compact ? 10.5 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: _accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final BuildContext context;

  const _InfoPill({
    required this.context,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.mutedText(context)),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.mutedText(context), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(
              color: valueColor ?? AppTheme.onSurface(context),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final _InstallmentPreview row;

  const _InstallmentRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final isFirst = row.no == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isFirst
            ? AppTheme.warningTint(context)
            : AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFirst
              ? AppTheme.warningColor.withValues(alpha: 0.35)
              : AppTheme.border(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isFirst
                  ? AppTheme.warningColor.withValues(alpha: 0.15)
                  : AppTheme.subtleSurface(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${row.no}',
                style: GoogleFonts.anuphan(
                  color: isFirst
                      ? AppTheme.warningColor
                      : AppTheme.mutedText(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'งวดที่ ${row.no}',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.onSurface(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  dateText(row.dueDate),
                  style: GoogleFonts.anuphan(
                    color: AppTheme.mutedText(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            money(row.amount),
            style: GoogleFonts.anuphan(
              color: isFirst ? AppTheme.warningColor : _accent,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _BankInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.anuphan(
              color: AppTheme.onSurface(context),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CopyButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.anuphan(fontWeight: FontWeight.w800, fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _accent,
        side: BorderSide(color: AppTheme.border(context)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool filled;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: filled
              ? _accent.withValues(
                  alpha: AppTheme.isDark(context) ? 0.16 : 0.07,
                )
              : AppTheme.fieldSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: filled ? _accent : AppTheme.border(context),
            width: filled ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: filled ? _accent : AppTheme.mutedText(context),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.mutedText(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: filled ? _accent : AppTheme.onSurface(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.anuphan(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  final bool done;

  const _RequiredBadge({required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? _accent.withValues(alpha: 0.10)
            : AppTheme.warningTint(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: done
              ? _accent.withValues(alpha: 0.20)
              : AppTheme.warningColor.withValues(alpha: 0.30),
        ),
      ),
      child: Text(
        done ? 'แนบแล้ว' : 'จำเป็น',
        style: GoogleFonts.anuphan(
          color: done ? _accent : AppTheme.warningColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.fieldSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _accent, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.anuphan(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppTheme.onSurface(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.border(context).withValues(alpha: 0.50),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _InstallmentPreview {
  final int no;
  final String dueDate;
  final num amount;

  const _InstallmentPreview({
    required this.no,
    required this.dueDate,
    required this.amount,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Pure helper functions
// ─────────────────────────────────────────────────────────────────────────────

num _amountDue(Map<String, dynamic> booking, String paymentType) {
  if (_normalizePaymentType(booking, paymentType) == 'installment') {
    return _installmentAmount(booking);
  }
  return _asNum(booking['total_amount']);
}

String _normalizePaymentType(Map<String, dynamic> booking, String paymentType) {
  if (paymentType == 'installment' && _installmentAvailable(booking)) {
    return 'installment';
  }
  return 'full';
}

bool _installmentAvailable(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  return _asBool(schedule['installment_enabled']) &&
      _installmentCount(booking) > 1;
}

num _installmentAmount(Map<String, dynamic> booking) {
  final total = _asNum(booking['total_amount']);
  final count = _installmentCount(booking);
  if (count <= 1) return total;
  return ((total / count) * 100).round() / 100;
}

int _installmentCount(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  return int.tryParse(
        textOf(booking['installment_count'] ?? schedule['installment_count']),
      ) ??
      2;
}

int _installmentInterval(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  return int.tryParse(
        textOf(
          booking['installment_interval_days'] ??
              schedule['installment_interval_days'],
        ),
      ) ??
      30;
}

List<_InstallmentPreview> _installmentSchedule(Map<String, dynamic> booking) {
  final total = _asNum(booking['total_amount']);
  final count = _installmentCount(booking);
  final interval = _installmentInterval(booking);
  final per = _installmentAmount(booking);
  final today = DateTime.now();
  return List.generate(count, (index) {
    final no = index + 1;
    final dueDate = today.add(Duration(days: index * interval));
    final amount = no == count
        ? ((total - per * (count - 1)) * 100).round() / 100
        : per;
    return _InstallmentPreview(
      no: no,
      dueDate: DateFormat('yyyy-MM-dd').format(dueDate),
      amount: amount,
    );
  });
}

String _statusLabel(String status) => switch (status) {
  'pending' => 'รอชำระเงิน',
  'confirmed' => 'ยืนยันแล้ว',
  'cancelled' => 'ยกเลิกแล้ว',
  'pending_review' => 'รอตรวจสอบ',
  _ => status,
};

Color _statusColor(String status) => switch (status) {
  'confirmed' => _accent,
  'cancelled' => AppTheme.errorColor,
  'pending' => AppTheme.warningColor,
  _ => AppTheme.warningColor,
};

num _asNum(dynamic value) => num.tryParse(value?.toString() ?? '') ?? 0;

bool _asBool(dynamic value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String _buildPromptPayPayload(String identifier, num amount) {
  final cleanId = identifier.replaceAll(RegExp(r'\D'), '');
  var normalized = cleanId;
  var typeTag = '03';
  if (cleanId.length == 10 && cleanId.startsWith('0')) {
    normalized = '0066${cleanId.substring(1)}';
    typeTag = '01';
  } else if (cleanId.length == 13) {
    typeTag = '02';
  }

  String tag(String id, String value) =>
      '$id${value.length.toString().padLeft(2, '0')}$value';

  final merchantAccountInfo =
      tag('00', 'A000000677010111') + tag(typeTag, normalized);
  final payload =
      tag('00', '01') +
      tag('01', '12') +
      tag('29', merchantAccountInfo) +
      tag('53', '764') +
      tag('54', amount.toStringAsFixed(2)) +
      tag('58', 'TH') +
      tag('62', tag('07', 'LUILAYKHAO')) +
      '6304';
  return payload + _crc16(payload);
}

String _crc16(String value) {
  var crc = 0xFFFF;
  for (final codeUnit in value.codeUnits) {
    crc ^= codeUnit << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
    }
  }
  return (crc & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
}
