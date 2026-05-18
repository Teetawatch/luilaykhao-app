part of 'customer_app_screen.dart';

class BookingDetailSheet extends StatefulWidget {
  final String bookingRef;

  const BookingDetailSheet({super.key, required this.bookingRef});

  @override
  State<BookingDetailSheet> createState() => _BookingDetailSheetState();
}

class _BookingDetailSheetState extends State<BookingDetailSheet> {
  late Future<Map<String, dynamic>> _future;
  String _paymentType = 'full';

  @override
  void initState() {
    super.initState();
    _future = context.read<AppProvider>().booking(widget.bookingRef);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      builder: (_, controller) => FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final booking = snapshot.data!;
          final schedule = asMap(booking['schedule']);
          final trip = asMap(schedule['trip']);
          final passengers = asList(booking['passengers']);
          final installments = asList(booking['installment_payments']);
          final installmentAvailable = _scheduleInstallmentAvailable(schedule);
          final depositAvailable = _scheduleDepositAvailable(schedule) &&
              !_asBool(booking['is_join_trip']);
          final paymentType = () {
            if (_paymentType == 'installment' && installmentAvailable) {
              return 'installment';
            }
            if (_paymentType == 'deposit' && depositAvailable) {
              return 'deposit';
            }
            return 'full';
          }();
          final bookingPaymentType = textOf(booking['payment_type']);
          final balanceUnpaid = bookingPaymentType == 'deposit' &&
              textOf(booking['balance_paid_at']).isEmpty &&
              (num.tryParse(booking['balance_amount']?.toString() ?? '0') ?? 0) >
                  0;
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.background(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Check-in card (confirmed only)
                if (textOf(booking['status']) == 'confirmed') ...[
                  _BookingCheckInCard(booking: booking),
                  const SizedBox(height: 20),
                ],

                // SOS button — confirmed bookings, only during the trip window
                if (textOf(booking['status']) == 'confirmed' &&
                    _isWithinTripWindow(schedule)) ...[
                  _SosButton(
                    scheduleId:
                        int.tryParse(textOf(schedule['id'])) ?? 0,
                  ),
                  const SizedBox(height: 20),
                ],

                // Trip title + booking ref
                Text(
                  textOf(trip['title'], 'รายละเอียดการจอง'),
                  style: GoogleFonts.anuphan(
                    color: AppTheme.primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  textOf(booking['booking_ref']),
                  style: GoogleFonts.anuphan(
                    color: AppTheme.mutedText(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                // Status chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(status: textOf(booking['status'])),
                    _Chip('เดินทาง ${dateText(schedule['departure_date'])}'),
                    _Chip(money(booking['total_amount'])),
                  ],
                ),
                const SizedBox(height: 20),

                // Passengers section
                const _SheetSectionTitle(
                  icon: Icons.people_alt_rounded,
                  title: 'ผู้เดินทาง',
                ),
                const SizedBox(height: 10),
                ...passengers.map((item) {
                  final p = asMap(item);
                  final name =
                      '${textOf(p['title'])} ${textOf(p['name'])}'.trim();
                  final phone = textOf(p['phone'], 'ไม่มีเบอร์โทร');
                  final seat = textOf(p['seat_id']);
                  final halal = p['halal_food'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.subtleSurface(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.border(context).withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primaryColor.withValues(
                              alpha: 0.10,
                            ),
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
                                  name.isEmpty ? '-' : name,
                                  style: GoogleFonts.anuphan(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppTheme.onSurface(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  phone,
                                  style: GoogleFonts.anuphan(
                                    fontSize: 12,
                                    color: AppTheme.mutedText(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (seat.isNotEmpty || halal) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      if (seat.isNotEmpty)
                                        _InlineBadge('ที่นั่ง $seat'),
                                      if (halal)
                                        const _InlineBadge('อาหารฮาลาล'),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Installments section
                if (installments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _SheetSectionTitle(
                    icon: Icons.receipt_long_rounded,
                    title: 'งวดชำระ',
                  ),
                  const SizedBox(height: 10),
                  ...installments.map((item) {
                    final inst = asMap(item);
                    final instStatus = textOf(inst['status']);
                    final isPaid = instStatus == 'paid';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? AppTheme.primaryColor.withValues(alpha: 0.06)
                              : AppTheme.subtleSurface(context),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isPaid
                                ? AppTheme.primaryColor.withValues(alpha: 0.16)
                                : AppTheme.border(context).withValues(
                                    alpha: 0.6,
                                  ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPaid
                                  ? Icons.check_circle_rounded
                                  : Icons.schedule_rounded,
                              color: isPaid
                                  ? AppTheme.primaryColor
                                  : AppTheme.warningColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'งวดที่ ${textOf(inst['installment_no'])}  ·  ${money(inst['amount'])}',
                                    style: GoogleFonts.anuphan(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: AppTheme.onSurface(context),
                                    ),
                                  ),
                                  Text(
                                    'ครบกำหนด ${dateText(inst['due_date'])}',
                                    style: GoogleFonts.anuphan(
                                      fontSize: 12,
                                      color: AppTheme.mutedText(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _StatusChip(status: instStatus),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 20),

                // Deposit balance summary (confirmed booking with unpaid balance)
                if (balanceUnpaid) ...[
                  _BookingDepositSummary(booking: booking),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(
                              bookingRef: widget.bookingRef,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('ชำระยอดส่วนที่เหลือ'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Payment actions (pending status)
                if (booking['status'] == 'pending') ...[
                  if (installmentAvailable || depositAvailable) ...[
                    DropdownButtonFormField<String>(
                      initialValue: paymentType,
                      decoration: const InputDecoration(
                        labelText: 'รูปแบบชำระเงิน',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'full',
                          child: Text('จ่ายเต็ม'),
                        ),
                        if (depositAvailable)
                          const DropdownMenuItem(
                            value: 'deposit',
                            child: Text('จ่ายมัดจำ'),
                          ),
                        if (installmentAvailable)
                          const DropdownMenuItem(
                            value: 'installment',
                            child: Text('ผ่อนชำระ'),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _paymentType = value ?? 'full'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(
                              bookingRef: widget.bookingRef,
                              initialPaymentType: paymentType,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('ไปหน้าชำระเงิน'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancel(context),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('ยกเลิกการจอง'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(
                          color: AppTheme.errorColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ],

                // Review CTA
                if (_asBool(booking['can_review'])) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _review(context, booking),
                      icon: const Icon(Icons.star_rounded),
                      label: const Text('รีวิวทริป'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final reason = await promptText(
      context,
      title: 'เหตุผลการยกเลิก',
      hint: 'ระบุเหตุผล',
    );
    if (reason == null) return;
    if (!context.mounted) return;
    final app = context.read<AppProvider>();
    try {
      await app.cancelBooking(widget.bookingRef, reason);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString());
    }
  }

  Future<void> _review(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => const _ReviewDialog(),
    );
    if (result == null) return;
    if (!context.mounted) return;
    final (rating, comment) = result;
    final app = context.read<AppProvider>();
    try {
      await app.submitReview(
        bookingId: int.parse(booking['id'].toString()),
        rating: rating,
        comment: comment,
      );
      if (context.mounted) {
        showSnack(context, 'ส่งรีวิวแล้ว ขอบคุณที่ช่วยแชร์ประสบการณ์');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString());
    }
  }
}

class _BookingDepositSummary extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingDepositSummary({required this.booking});

  @override
  Widget build(BuildContext context) {
    final total = booking['total_amount'];
    final deposit = booking['deposit_amount'];
    final balance = booking['balance_amount'];
    final dueRaw = booking['balance_due_at']?.toString() ?? '';
    final dueDate = DateTime.tryParse(dueRaw);
    final dueText = dueDate == null
        ? '-'
        : DateFormat('d MMM yyyy', 'th_TH').format(dueDate);
    const warning = AppTheme.warningColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning.withValues(
          alpha: AppTheme.isDark(context) ? 0.18 : 0.08,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: warning.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_rounded, color: warning, size: 20),
              const SizedBox(width: 8),
              Text(
                'จ่ายมัดจำแล้ว · มียอดส่วนที่เหลือต้องชำระ',
                style: GoogleFonts.anuphan(
                  color: warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _BookingDepositRow(label: 'ยอดรวมทั้งหมด', value: money(total)),
          const SizedBox(height: 6),
          _BookingDepositRow(label: 'มัดจำที่ชำระแล้ว', value: money(deposit)),
          const SizedBox(height: 6),
          _BookingDepositRow(
            label: 'ส่วนที่เหลือต้องชำระ',
            value: money(balance),
            highlight: true,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: warning.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: warning, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ครบกำหนดชำระภายใน $dueText',
                    style: GoogleFonts.anuphan(
                      color: AppTheme.onSurface(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
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

class _BookingDepositRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _BookingDepositRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.anuphan(
            color: highlight
                ? AppTheme.warningColor
                : AppTheme.onSurface(context),
            fontSize: highlight ? 15 : 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 5;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('รีวิวทริป'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คะแนน',
            style: GoogleFonts.anuphan(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = star),
                icon: Icon(
                  star <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: star <= _rating ? const Color(0xFFFFB020) : AppTheme.textSecondary,
                  size: 36,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'เล่าประสบการณ์ของคุณ',
              hintStyle: GoogleFonts.anuphan(color: AppTheme.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 4,
            style: GoogleFonts.anuphan(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () {
            final comment = _commentController.text.trim();
            if (comment.isEmpty) return;
            Navigator.pop(context, (_rating, comment));
          },
          child: const Text('ส่งรีวิว'),
        ),
      ],
    );
  }
}

/// True when today falls between the schedule's departure and return dates
/// (inclusive). The SOS button is only shown inside this window.
bool _isWithinTripWindow(Map<String, dynamic> schedule) {
  final dep = DateTime.tryParse(textOf(schedule['departure_date']));
  if (dep == null) return false;
  final ret = DateTime.tryParse(textOf(schedule['return_date'])) ?? dep;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(dep.year, dep.month, dep.day);
  final end = DateTime(ret.year, ret.month, ret.day);
  return !today.isBefore(start) && !today.isAfter(end);
}

class _SosButton extends StatefulWidget {
  final int scheduleId;

  const _SosButton({required this.scheduleId});

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton> {
  static const _sosRed = Color(0xFFE11D48);
  bool _sending = false;

  Future<void> _onPressed() async {
    if (_sending || widget.scheduleId == 0) return;

    final message = await _confirmDialog();
    if (message == null || !mounted) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AppProvider>();

    double? lat;
    double? lng;
    try {
      final pos = await _currentPosition();
      lat = pos?.latitude;
      lng = pos?.longitude;
    } catch (_) {}

    try {
      await provider.triggerSos(
        scheduleId: widget.scheduleId,
        latitude: lat,
        longitude: lng,
        message: message.isEmpty ? null : message,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
      await _successDialog(hasLocation: lat != null);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('ส่ง SOS ไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<String?> _confirmDialog() {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SosMessageSheet(),
    );
  }

  Future<void> _successDialog({required bool hasLocation}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'ส่ง SOS แล้ว',
              style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Text(
          hasLocation
              ? 'สตาฟและเพื่อนร่วมทริปได้รับการแจ้งเตือนพร้อมตำแหน่งของคุณแล้ว'
              : 'สตาฟและเพื่อนร่วมทริปได้รับการแจ้งเตือนแล้ว '
                  '(ไม่สามารถระบุตำแหน่ง GPS ได้)',
          style: GoogleFonts.anuphan(fontSize: 13, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Future<Position?> _currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _sending ? null : _onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _sosRed.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _sosRed.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _sosRed,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sos_rounded,
                        color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ขอความช่วยเหลือฉุกเฉิน',
                      style: GoogleFonts.anuphan(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _sosRed,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'แจ้งเตือนสตาฟและเพื่อนร่วมทริปทันที',
                      style: GoogleFonts.anuphan(
                        fontSize: 12,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: _sosRed.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SOS message bottom sheet ──────────────────────────────────────────────────

class _SosOption {
  final String value;
  final String label;
  final String emoji;
  const _SosOption(this.value, this.label, this.emoji);
}

class _SosMessageSheet extends StatefulWidget {
  const _SosMessageSheet();

  @override
  State<_SosMessageSheet> createState() => _SosMessageSheetState();
}

class _SosMessageSheetState extends State<_SosMessageSheet> {
  static const _sosRed = Color(0xFFE11D48);

  static const _options = [
    _SosOption('ช่วยด้วย', 'ช่วยด้วย', '🆘'),
    _SosOption('ฉันหลงทาง', 'ฉันหลงทาง', '🗺️'),
    _SosOption('ฉันกังวล', 'ฉันกังวล', '😟'),
    _SosOption('ฉันรู้สึกไม่ปลอดภัย', 'ฉันรู้สึกไม่ปลอดภัย', '⚠️'),
    _SosOption('other', 'อื่น ๆ', '💬'),
  ];

  String? _selected;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend {
    if (_selected == null) return false;
    if (_selected == 'other') return _controller.text.trim().isNotEmpty;
    return true;
  }

  String get _message =>
      _selected == 'other' ? _controller.text.trim() : (_selected ?? '');

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              const Icon(Icons.sos_rounded, color: _sosRed, size: 26),
              const SizedBox(width: 10),
              Text(
                'ขอความช่วยเหลือ SOS',
                style: GoogleFonts.anuphan(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _sosRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'เลือกข้อความที่ต้องการส่งให้สตาฟและผู้ร่วมทริป',
            style: GoogleFonts.anuphan(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Option grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: _options.map((opt) {
              final selected = _selected == opt.value;
              return GestureDetector(
                onTap: () => setState(() {
                  _selected = opt.value;
                  if (opt.value != 'other') _controller.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected
                        ? _sosRed.withValues(alpha: 0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? _sosRed
                          : Colors.grey.shade200,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Text(opt.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          opt.label,
                          style: GoogleFonts.anuphan(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected ? _sosRed : Colors.grey.shade800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Custom text field (shown when "อื่น ๆ" selected)
          if (_selected == 'other') ...[
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLength: 255,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.anuphan(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'อธิบายสถานการณ์โดยย่อ...',
                hintStyle: GoogleFonts.anuphan(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _sosRed, width: 2),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Info note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'สตาฟและผู้โดยสารในทริปจะได้รับการแจ้งเตือนพร้อมตำแหน่ง GPS ทันที',
                    style: GoogleFonts.anuphan(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'ยกเลิก',
                    style: GoogleFonts.anuphan(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _canSend
                      ? () => Navigator.pop(context, _message)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _sosRed,
                    disabledBackgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.sos_rounded, size: 20),
                  label: Text(
                    'ส่งสัญญาณ SOS',
                    style: GoogleFonts.anuphan(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

