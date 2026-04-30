import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';

const Color _pageBackground = Color(0xFFF8F8F8);
const Color _text = Color(0xFF111827);
const Color _muted = Color(0xFF6B7280);
const Color _accent = Color(0xFF0F8F75);
const Color _border = Color(0xFFEAEAEA);
const Color _field = Color(0xFFF7F8F7);
const String _promptPayId = '004999239362071';
const String _displayPromptPayId = '004-99923936-2071';
const String _bankAccount = '230-139095-8';

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

  @override
  void initState() {
    super.initState();
    _paymentType = widget.initialPaymentType == 'installment'
        ? 'installment'
        : 'full';
    _future = _loadBooking();
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(
                  'เลือกรูปจากเครื่อง',
                  style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: Text(
                  'ถ่ายรูปสลิป',
                  style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
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
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'แจ้งชำระเงินสำเร็จ',
            style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'ระบบบันทึกข้อมูลการชำระเงินและยืนยันการจองแล้ว',
            style: GoogleFonts.anuphan(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ตกลง',
                style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
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
    _showSnack(message);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _text,
        title: Text(
          'ชำระเงิน',
          style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              const _PaymentProgress(),
              const SizedBox(height: 16),
              if (status == 'pending') const _PaymentNotice(),
              if (status == 'pending') const SizedBox(height: 16),
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
              if (status == 'pending') ...[
                if (_installmentAvailable(booking)) ...[
                  _PaymentTypeSection(
                    booking: booking,
                    value: paymentType,
                    onChanged: (value) => setState(() => _paymentType = value),
                  ),
                  const SizedBox(height: 16),
                ],
                _PaymentMethodSection(
                  value: _paymentMethod,
                  amount: amountDue,
                  qrPayload: qrPayload,
                  onChanged: (value) => setState(() => _paymentMethod = value),
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
                const SizedBox(height: 20),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _paying ? null : () => _submit(booking),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFC8D5D1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    icon: _paying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_user_rounded),
                    label: Text(
                      _paying
                          ? 'กำลังบันทึก...'
                          : 'ยืนยันการชำระ ${money(amountDue)}',
                      style: GoogleFonts.anuphan(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PaymentProgress extends StatelessWidget {
  const _PaymentProgress();

  @override
  Widget build(BuildContext context) {
    const steps = ['เลือกทริป', 'รายละเอียด', 'ชำระเงิน'];
    return Row(
      children: List.generate(steps.length, (index) {
        final active = index == 2;
        final done = index < 2;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: active || done
                            ? _accent
                            : _accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        done ? Icons.check_rounded : Icons.payments_rounded,
                        color: active || done ? Colors.white : _accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        color: active ? _accent : _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (index != steps.length - 1)
                Container(
                  width: 24,
                  height: 2,
                  color: done ? _accent : _border,
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _PaymentNotice extends StatelessWidget {
  const _PaymentNotice();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.priority_high_rounded,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'กรุณาชำระเงินและระบุเวลาโอนตามสลิป เพื่อยืนยันสิทธิ์การเดินทาง',
              style: GoogleFonts.anuphan(
                color: const Color(0xFF92400E),
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final pickupPoint = asMap(booking['pickup_point']);
    final pickupText = textOf(
      pickupPoint['pickup_location'] ??
          pickupPoint['region_label'] ??
          booking['pickup_region'],
      'ระบุก่อนเดินทาง',
    );

    return _SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: AspectRatio(
              aspectRatio: 16 / 8,
              child: image.isEmpty
                  ? Container(
                      color: _field,
                      child: const Icon(
                        Icons.landscape_rounded,
                        color: _accent,
                        size: 42,
                      ),
                    )
                  : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textOf(trip['title'], 'รายละเอียดการจอง'),
                  style: GoogleFonts.anuphan(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      Icons.confirmation_number_outlined,
                      textOf(booking['booking_ref']),
                    ),
                    _InfoPill(
                      Icons.calendar_today_rounded,
                      dateText(schedule['departure_date']),
                    ),
                    _InfoPill(Icons.group_rounded, '${passengers.length} ท่าน'),
                    if (seats.isNotEmpty)
                      _InfoPill(
                        Icons.airline_seat_recline_extra_rounded,
                        seats
                            .map((seat) => textOf(asMap(seat)['seat_id']))
                            .join(', '),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  icon: Icons.location_on_outlined,
                  label: 'จุดขึ้นรถ',
                  value: pickupText,
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'ยอดรวมทั้งหมด',
                  value: money(booking['total_amount']),
                  valueColor: _accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
            ..._installmentSchedule(
              booking,
            ).map((row) => _InstallmentRow(row: row)),
          ],
        ],
      ),
    );
  }
}

class _PaymentMethodSection extends StatelessWidget {
  final String value;
  final num amount;
  final String qrPayload;
  final ValueChanged<String> onChanged;
  final VoidCallback onCopyAmount;
  final VoidCallback onCopyAccount;

  const _PaymentMethodSection({
    required this.value,
    required this.amount,
    required this.qrPayload,
    required this.onChanged,
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
          const SizedBox(height: 16),
          if (value == 'promptpay')
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'พร้อมเพย์ / e-Wallet $_displayPromptPayId',
                    style: GoogleFonts.anuphan(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                _BankInfoRow(label: 'ธนาคาร', value: 'กสิกรไทย (KBANK)'),
                const SizedBox(height: 8),
                _BankInfoRow(
                  label: 'ชื่อบัญชี',
                  value: 'นายธีร์ธวัช พิพัฒน์เดชธน',
                ),
                const SizedBox(height: 8),
                _BankInfoRow(label: 'เลขที่บัญชี', value: _bankAccount),
              ],
            ),
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
                  onTap: onPickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  icon: Icons.schedule_rounded,
                  label: 'เวลาที่โอน',
                  value: time == null ? 'เลือกเวลา' : time!.format(context),
                  onTap: onPickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'กรอกวันและเวลาตามสลิปโอนเงิน เพื่อให้ทีมงานตรวจสอบได้รวดเร็ว',
            style: GoogleFonts.anuphan(
              color: _muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

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
              const Expanded(
                child: _SectionTitle(
                  icon: Icons.upload_file_rounded,
                  title: 'แนบรูปภาพสลิป',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: hasImage
                      ? _accent.withValues(alpha: 0.10)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: hasImage
                        ? _accent.withValues(alpha: 0.18)
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Text(
                  hasImage ? 'แนบแล้ว' : 'จำเป็น',
                  style: GoogleFonts.anuphan(
                    color: hasImage ? _accent : const Color(0xFF92400E),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onPick,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: hasImage ? 260 : 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: hasImage ? Colors.black : _field,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: hasImage ? _accent : _border,
                  width: hasImage ? 1.4 : 1,
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
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _border),
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
                            color: _text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ต้องแนบทุกครั้งก่อนยืนยันการชำระเงิน',
                          style: GoogleFonts.anuphan(
                            color: _muted,
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

class _PaymentCompletedCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _PaymentCompletedCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final bookingRef = textOf(booking['booking_ref'], '-');
    final checkInCode = textOf(booking['qr_code']).trim();

    return _SectionCard(
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFE7F7F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _accent,
              size: 34,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'พร้อมสำหรับเช็คอิน',
            style: GoogleFonts.anuphan(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'โปรดแสดงรหัสนี้แก่เจ้าหน้าที่เมื่อถึงจุดนัดหมาย',
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              color: _muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (checkInCode.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border),
              ),
              child: QrImageView(
                data: checkInCode,
                version: QrVersions.auto,
                size: 176,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2FBF8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _accent.withValues(alpha: 0.14)),
            ),
            child: Column(
              children: [
                Text(
                  'รหัสการจอง',
                  style: GoogleFonts.anuphan(
                    color: _muted,
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
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
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

class _PaymentEmptyState extends StatelessWidget {
  final VoidCallback onRetry;

  const _PaymentEmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 54, color: _muted),
            const SizedBox(height: 10),
            Text(
              'ไม่พบข้อมูลการจอง',
              style: GoogleFonts.anuphan(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
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
        Icon(icon, color: _accent, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.anuphan(
              color: _text,
              fontSize: 17,
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
          color: selected ? _accent.withValues(alpha: 0.08) : _field,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _accent : _border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _accent : _muted, size: 22),
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
                      color: selected ? _accent : _text,
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
                      color: _muted,
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

  const _InfoPill(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _muted),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.anuphan(
              color: _muted,
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
        Icon(icon, color: _muted, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.anuphan(
              color: _muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(
              color: valueColor ?? _text,
              fontWeight: FontWeight.w900,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: row.no == 1 ? const Color(0xFFFFFBEB) : _field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: row.no == 1 ? const Color(0xFFFDE68A) : _border,
        ),
      ),
      child: Row(
        children: [
          Text(
            'งวด ${row.no}',
            style: GoogleFonts.anuphan(
              color: _text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dateText(row.dueDate),
              style: GoogleFonts.anuphan(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            money(row.amount),
            style: GoogleFonts.anuphan(
              color: row.no == 1 ? AppTheme.warningColor : _text,
              fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.anuphan(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.anuphan(
              color: _text,
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
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _field,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, color: _accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.anuphan(
                      color: _muted,
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
                      color: _text,
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
  final enabled = _asBool(schedule['installment_enabled']);
  return enabled && _installmentCount(booking) > 1;
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
