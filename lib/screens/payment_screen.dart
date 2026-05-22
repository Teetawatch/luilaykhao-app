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

part 'payment_status.part.dart';
part 'payment_sections.part.dart';
part 'payment_completed.part.dart';
part 'payment_widgets.part.dart';
part 'payment_helpers.part.dart';

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

  /// When set, the screen collects payment for this specific installment
  /// (an already-confirmed installment booking) instead of an initial payment.
  final int? installmentNo;

  const PaymentScreen({
    super.key,
    required this.bookingRef,
    this.initialPaymentType = 'full',
    this.installmentNo,
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
    _paymentType = switch (widget.initialPaymentType) {
      'installment' => 'installment',
      'deposit' => 'deposit',
      _ => 'full',
    };
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
    // If booking already has a confirmed payment_type, respect it.
    // Otherwise keep the user-selected choice and let normalize fall back to 'full' if unsupported.
    final preferred = (currentType == 'installment' || currentType == 'deposit')
        ? currentType
        : _paymentType;
    _paymentType = _normalizePaymentType(booking, preferred);
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

  Future<void> _submit(
    Map<String, dynamic> booking, {
    bool payingBalance = false,
    int? installmentNo,
  }) async {
    final payingInstallment = installmentNo != null;
    if (!payingBalance && !payingInstallment &&
        textOf(booking['status']) != 'pending') {
      return;
    }
    if (payingBalance && !_balanceUnpaid(booking)) return;
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
      final transferDateStr = DateFormat('yyyy-MM-dd').format(_transferDate!);
      final transferTimeStr =
          '${_transferTime!.hour.toString().padLeft(2, '0')}:${_transferTime!.minute.toString().padLeft(2, '0')}';
      final num amount;
      if (payingBalance) {
        amount = _balanceAmount(booking);
        await context.read<AppProvider>().chargeBalance(
          bookingRef: widget.bookingRef,
          paymentMethod: _paymentMethod,
          transferDate: transferDateStr,
          transferTime: transferTimeStr,
          slipImagePath: _slipImage!.path,
        );
      } else if (payingInstallment) {
        amount = _asNum(_installmentRecord(booking, installmentNo)['amount']);
        await context.read<AppProvider>().chargeInstallment(
          bookingRef: widget.bookingRef,
          installmentNo: installmentNo,
          paymentMethod: _paymentMethod,
          transferDate: transferDateStr,
          transferTime: transferTimeStr,
          slipImagePath: _slipImage!.path,
        );
      } else {
        final paymentType = _normalizePaymentType(booking, _paymentType);
        amount = _amountDue(booking, paymentType);
        await context.read<AppProvider>().confirmPayment(
          bookingRef: widget.bookingRef,
          amount: amount,
          paymentType: paymentType,
          paymentMethod: _paymentMethod,
          transferDate: transferDateStr,
          transferTime: transferTimeStr,
          slipImagePath: _slipImage!.path,
        );
      }
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await showDialog<void>(
        context: context,
        builder: (_) => _SuccessDialog(amount: amount),
      );
      // Reset form fields between submissions so a follow-up balance payment
      // does not reuse the previous slip.
      setState(() {
        _slipImage = null;
        _transferDate = null;
        _transferTime = null;
      });
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
          final balanceUnpaid = _balanceUnpaid(booking);
          // When the booking is on a deposit plan with an unpaid balance, we
          // collect the balance from this screen even though status is "confirmed".
          final collectingBalance = status == 'confirmed' && balanceUnpaid;
          // Paying one installment of an already-confirmed installment booking.
          final payingInstallment = widget.installmentNo != null;
          final installmentRecord = payingInstallment
              ? _installmentRecord(booking, widget.installmentNo!)
              : const <String, dynamic>{};
          final installmentPaid =
              payingInstallment && textOf(installmentRecord['status']) == 'paid';
          final collectingInstallment =
              payingInstallment && !installmentPaid && installmentRecord.isNotEmpty;
          final checkInReady = status == 'confirmed' &&
              !balanceUnpaid &&
              !payingInstallment;
          final paymentType = collectingBalance
              ? 'balance'
              : _normalizePaymentType(booking, _paymentType);
          final amountDue = collectingBalance
              ? _balanceAmount(booking)
              : payingInstallment
                  ? _asNum(installmentRecord['amount'])
                  : _amountDue(booking, paymentType);
          final qrPayload = _buildPromptPayPayload(_promptPayId, amountDue);
          final pendingFormVisible =
              status == 'pending' || collectingBalance || collectingInstallment;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _PaymentProgress(status: status),
              const SizedBox(height: 20),
              if (status == 'pending') ...[
                const _PaymentNotice(),
                const SizedBox(height: 10),
                _PaymentCountdownBanner(booking: booking),
                const SizedBox(height: 16),
              ],
              if (collectingBalance) ...[
                _BalanceDueBanner(booking: booking),
                const SizedBox(height: 16),
              ],
              if (payingInstallment) ...[
                _InstallmentBanner(
                  no: widget.installmentNo!,
                  dueDate: textOf(installmentRecord['due_date']),
                  amount: _asNum(installmentRecord['amount']),
                  paid: installmentPaid,
                ),
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
              if (pendingFormVisible) ...[
                if (!collectingBalance &&
                    !payingInstallment &&
                    (_installmentAvailable(booking) ||
                        _depositAvailable(booking))) ...[
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
                  label: collectingBalance
                      ? 'ชำระยอดส่วนที่เหลือ'
                      : collectingInstallment
                          ? 'ชำระงวดที่ ${widget.installmentNo}'
                          : null,
                  onPressed: () => _submit(
                    booking,
                    payingBalance: collectingBalance,
                    installmentNo:
                        collectingInstallment ? widget.installmentNo : null,
                  ),
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

