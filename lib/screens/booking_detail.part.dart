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

                // Pre-trip Briefing Card — confirmed, 0-3 days before departure
                if (textOf(booking['status']) == 'confirmed' &&
                    _isPreTripWindow(schedule)) ...[
                  _PreTripBriefingCard(booking: booking, schedule: schedule),
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
                const SizedBox(height: 16),

                // Group chat — available to members of active bookings
                if (textOf(booking['status']) == 'pending' ||
                    textOf(booking['status']) == 'confirmed') ...[
                  _TripChatButton(booking: booking),
                  const SizedBox(height: 16),
                ],

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

                // Assigned staff section
                if (asList(booking['assigned_staff']).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _SheetSectionTitle(
                    icon: Icons.badge_rounded,
                    title: 'สตาฟ / ไกด์ประจำรอบ',
                  ),
                  const SizedBox(height: 10),
                  _AssignedStaffList(staffList: asList(booking['assigned_staff'])),
                ],

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

                // Booking modification — เปลี่ยนวันเดินทาง / จุดรับ (ในช่วงที่อนุญาต)
                if (_asBool(booking['can_modify'])) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 28),
                  const _SheetSectionTitle(
                    icon: Icons.edit_calendar_rounded,
                    title: 'แก้ไขการจอง',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'เปลี่ยนได้ถึงก่อนวันเดินทาง 1 วัน · คงราคาเดิม',
                    style: GoogleFonts.anuphan(
                      fontSize: 12,
                      color: AppTheme.mutedText(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openReschedule(context, booking),
                      icon: const Icon(Icons.event_repeat_rounded),
                      label: const Text('เปลี่ยนวันเดินทาง'),
                    ),
                  ),
                  if (asList(schedule['pickup_points']).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openChangePickup(context, booking),
                        icon: const Icon(Icons.location_on_rounded),
                        label: const Text('เปลี่ยนจุดรับ'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
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

  void _reload() {
    setState(() {
      _future = context.read<AppProvider>().booking(widget.bookingRef);
    });
  }

  Future<void> _openReschedule(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RescheduleSheet(booking: booking),
    );
    if (changed == true && mounted) {
      _reload();
      if (context.mounted) showSnack(context, 'เปลี่ยนวันเดินทางสำเร็จ');
    }
  }

  Future<void> _openChangePickup(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePickupSheet(booking: booking),
    );
    if (changed == true && mounted) {
      _reload();
      if (context.mounted) showSnack(context, 'เปลี่ยนจุดรับสำเร็จ');
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

// ─── Pre-trip Briefing Card ───────────────────────────────────────────────────

/// True when departure is 0-3 days away (today through departure day inclusive).
bool _isPreTripWindow(Map<String, dynamic> schedule) {
  final dep = DateTime.tryParse(textOf(schedule['departure_date']));
  if (dep == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(dep.year, dep.month, dep.day);
  final diff = start.difference(today).inDays;
  return diff >= 0 && diff <= 3;
}

class _PreTripBriefingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> schedule;

  const _PreTripBriefingCard({required this.booking, required this.schedule});

  @override
  Widget build(BuildContext context) {
    final trip = asMap(schedule['trip']);
    final pickupPoint = asMap(booking['pickup_point']);
    final staffList = asList(booking['assigned_staff']);
    final preparations = asList(trip['preparations']);
    final mustKnow = asList(trip['must_know']);

    final depDate = DateTime.tryParse(textOf(schedule['departure_date']));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = depDate != null
        ? DateTime(depDate.year, depDate.month, depDate.day)
            .difference(today)
            .inDays
        : null;

    final countdownText = switch (daysLeft) {
      0 => 'วันนี้วันเดินทาง!',
      1 => 'พรุ่งนี้วันเดินทาง',
      _ => 'อีก $daysLeft วัน',
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.isDark(context)
              ? [
                  const Color(0xFF0F4C2A),
                  const Color(0xFF0A2E1A),
                ]
              : [
                  const Color(0xFFECFDF5),
                  const Color(0xFFD1FAE5),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff_rounded,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เตรียมพร้อมก่อนเดินทาง',
                        style: GoogleFonts.anuphan(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        countdownText,
                        style: GoogleFonts.anuphan(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    dateText(schedule['departure_date']),
                    style: GoogleFonts.anuphan(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pickup location
                if (pickupPoint.isNotEmpty) ...[
                  _BriefingSection(
                    icon: Icons.location_on_rounded,
                    title: 'จุดรับ',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textOf(pickupPoint['pickup_location'],
                              textOf(pickupPoint['region'])),
                          style: GoogleFonts.anuphan(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface(context),
                            height: 1.4,
                          ),
                        ),
                        if (textOf(pickupPoint['notes']).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            textOf(pickupPoint['notes']),
                            style: GoogleFonts.anuphan(
                              fontSize: 12.5,
                              color: AppTheme.mutedText(context),
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (textOf(pickupPoint['map_url']).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(
                                  textOf(pickupPoint['map_url']));
                              if (await canLaunchUrl(uri)) {
                                launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 14,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'เปิดแผนที่',
                                  style: GoogleFonts.anuphan(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryColor,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Staff/guide contacts
                if (staffList.isNotEmpty) ...[
                  _BriefingSection(
                    icon: Icons.badge_rounded,
                    title: 'ไกด์ / สตาฟ',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: staffList.map((item) {
                        final s = asMap(item);
                        final name = textOf(s['nickname']).isNotEmpty
                            ? textOf(s['nickname'])
                            : textOf(s['name']);
                        final phone = textOf(s['phone']);
                        return GestureDetector(
                          onTap: phone.isEmpty
                              ? null
                              : () async {
                                  final uri =
                                      Uri(scheme: 'tel', path: phone);
                                  if (await canLaunchUrl(uri)) {
                                    launchUrl(uri);
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.surface(context).withValues(
                                alpha: 0.80,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.20),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (phone.isNotEmpty) ...[
                                  Icon(
                                    Icons.call_rounded,
                                    size: 13,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  phone.isNotEmpty
                                      ? '$name  $phone'
                                      : name,
                                  style: GoogleFonts.anuphan(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: phone.isNotEmpty
                                        ? AppTheme.primaryColor
                                        : AppTheme.onSurface(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Preparations checklist
                if (preparations.isNotEmpty) ...[
                  _BriefingSection(
                    icon: Icons.checklist_rounded,
                    title: 'สิ่งที่ต้องเตรียม',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: preparations.map((item) {
                        final text = item is Map
                            ? textOf(item['text'] ?? item['title'] ?? item)
                            : item.toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  text,
                                  style: GoogleFonts.anuphan(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.onSurface(context),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (mustKnow.isNotEmpty) const SizedBox(height: 14),
                ],

                // Must know
                if (mustKnow.isNotEmpty) ...[
                  _BriefingSection(
                    icon: Icons.info_outline_rounded,
                    title: 'ข้อควรทราบ',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: mustKnow.map((item) {
                        final text = item is Map
                            ? textOf(item['text'] ?? item['title'] ?? item)
                            : item.toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: AppTheme.mutedText(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  text,
                                  style: GoogleFonts.anuphan(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.mutedText(context),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // Fallback when no content is available yet
                if (pickupPoint.isEmpty &&
                    staffList.isEmpty &&
                    preparations.isEmpty &&
                    mustKnow.isEmpty)
                  Text(
                    'ข้อมูลจะถูกอัปเดตโดยทีมงานก่อนวันเดินทาง',
                    style: GoogleFonts.anuphan(
                      fontSize: 13,
                      color: AppTheme.mutedText(context),
                      fontStyle: FontStyle.italic,
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

class _BriefingSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _BriefingSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppTheme.primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.anuphan(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.mutedText(context),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              child,
            ],
          ),
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

    final result = await _confirmDialog();
    if (result == null || !mounted) return;

    await _dispatchSos(result.message, result.photoPath);
  }

  Future<void> _dispatchSos(String message, String? photoPath) async {
    if (_sending) return;

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
        photoPath: photoPath,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
      await _successDialog(hasLocation: lat != null);
    } catch (e) {
      // triggerSos already retried with backoff; offer a manual retry too.
      messenger.showSnackBar(
        SnackBar(
          content: Text('ส่ง SOS ไม่สำเร็จ: $e'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'ลองอีกครั้ง',
            onPressed: () => _dispatchSos(message, photoPath),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<_SosSheetResult?> _confirmDialog() {
    return showModalBottomSheet<_SosSheetResult>(
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
                      _sending
                          ? 'กำลังส่งสัญญาณ SOS...'
                          : 'แจ้งเตือนสตาฟและเพื่อนร่วมทริปทันที',
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

/// What the SOS sheet returns when the user confirms: the chosen message plus
/// an optional photo (a local file path) to attach.
class _SosSheetResult {
  final String message;
  final String? photoPath;
  const _SosSheetResult({required this.message, this.photoPath});
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
  final _picker = ImagePicker();
  String? _photoPath;
  bool _pickingPhoto = false;

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

  Future<void> _pickPhoto(ImageSource source) async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      // Keep the file small so it uploads on a weak (3G) connection — the photo
      // only needs to show the surroundings, not be print-quality.
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 45,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image == null || !mounted) return;
      setState(() => _photoPath = image.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปิดรูปได้')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: _sosRed),
                title: Text('ถ่ายรูป',
                    style: GoogleFonts.anuphan(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: _sosRed),
                title: Text('เลือกจากคลังภาพ',
                    style: GoogleFonts.anuphan(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      // Lift the whole sheet above the keyboard so the send button stays
      // reachable when the "อื่น ๆ" text field is focused.
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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

          const SizedBox(height: 14),

          // Optional photo attachment — helps responders see the surroundings.
          if (_photoPath == null)
            OutlinedButton.icon(
              onPressed: _pickingPhoto ? null : _choosePhotoSource,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size.fromHeight(0),
              ),
              icon: _pickingPhoto
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.add_a_photo_outlined,
                      size: 19, color: Colors.grey.shade700),
              label: Text(
                'แนบรูปสถานที่ (ไม่บังคับ)',
                style: GoogleFonts.anuphan(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.file(
                    File(_photoPath!),
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _photoPath = null),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: Colors.white),
                        ),
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
                      ? () => Navigator.pop(
                            context,
                            _SosSheetResult(
                              message: _message,
                              photoPath: _photoPath,
                            ),
                          )
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
        ),
      ),
    );
  }
}

// ─── Assigned Staff List ─────────────────────────────────────────────────────

class _AssignedStaffList extends StatelessWidget {
  final List<dynamic> staffList;

  const _AssignedStaffList({required this.staffList});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: staffList.map((item) {
        final staff = asMap(item);
        final name = textOf(staff['name']);
        final nickname = textOf(staff['nickname']);
        final phone = textOf(staff['phone']);
        final avatarUrl = textOf(staff['avatar_url']);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                _StaffAvatar(url: avatarUrl, name: name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.isEmpty ? '-' : name,
                              style: GoogleFonts.anuphan(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: AppTheme.onSurface(context),
                              ),
                            ),
                          ),
                          if (nickname.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                nickname,
                                style: GoogleFonts.anuphan(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri(scheme: 'tel', path: phone);
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.call_rounded,
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: GoogleFonts.anuphan(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppTheme.primaryColor,
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
          ),
        );
      }).toList(),
    );
  }
}

class _StaffAvatar extends StatelessWidget {
  final String url;
  final String name;

  const _StaffAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorWidget: (context, e, s) => _fallback(context),
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.anuphan(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Reschedule sheet (เปลี่ยนวันเดินทาง) ──────────────────────────────────────

class _RescheduleSheet extends StatefulWidget {
  final Map<String, dynamic> booking;

  const _RescheduleSheet({required this.booking});

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  late Future<List<dynamic>> _schedulesFuture;
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _seatsData;
  bool _loadingSeats = false;
  bool _submitting = false;
  final Set<String> _selectedSeats = {};

  Map<String, dynamic> get _schedule => asMap(widget.booking['schedule']);
  String get _tripSlug => textOf(asMap(_schedule['trip'])['slug']);
  int get _currentScheduleId => int.tryParse(textOf(_schedule['id'])) ?? 0;
  String get _ref => textOf(widget.booking['booking_ref']);
  int get _passengerCount => asList(widget.booking['passengers']).length;
  bool get _isSeatBased => asList(widget.booking['seats']).isNotEmpty;

  @override
  void initState() {
    super.initState();
    _schedulesFuture = context.read<AppProvider>().schedules(_tripSlug);
  }

  bool get _canSubmit {
    if (_submitting || _selected == null) return false;
    if (_isSeatBased) return _selectedSeats.length == _passengerCount;
    return true;
  }

  Future<void> _selectSchedule(Map<String, dynamic> sched) async {
    setState(() {
      _selected = sched;
      _seatsData = null;
      _selectedSeats.clear();
    });
    if (_isSeatBased) {
      final id = int.tryParse(textOf(sched['id'])) ?? 0;
      setState(() => _loadingSeats = true);
      try {
        final data = await context.read<AppProvider>().seats(id);
        if (mounted) setState(() => _seatsData = data);
      } catch (e) {
        if (mounted) showSnack(context, e.toString());
      } finally {
        if (mounted) setState(() => _loadingSeats = false);
      }
    }
  }

  void _toggleSeat(String id) {
    setState(() {
      if (_selectedSeats.contains(id)) {
        _selectedSeats.remove(id);
      } else if (_selectedSeats.length < _passengerCount) {
        _selectedSeats.add(id);
      }
    });
  }

  Future<void> _submit() async {
    final target = _selected;
    if (target == null) return;
    setState(() => _submitting = true);
    try {
      await context.read<AppProvider>().rescheduleBooking(
            _ref,
            targetScheduleId: int.tryParse(textOf(target['id'])) ?? 0,
            seatIds: _selectedSeats.toList(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showSnack(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 16),
          Text(
            'เปลี่ยนวันเดินทาง',
            style: GoogleFonts.anuphan(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'เลือกรอบเดินทางใหม่ของทริปเดียวกัน · คงราคาเดิม',
            style: GoogleFonts.anuphan(
              fontSize: 12.5,
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<List<dynamic>>(
                    future: _schedulesFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final options = snapshot.data!
                          .map((e) => asMap(e))
                          .where((s) =>
                              (int.tryParse(textOf(s['id'])) ?? 0) !=
                              _currentScheduleId)
                          .toList();
                      if (options.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'ไม่มีรอบเดินทางอื่นให้เลือกในขณะนี้',
                            style: GoogleFonts.anuphan(
                              fontSize: 13,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: options.map((sched) {
                          final id = textOf(sched['id']);
                          final selectedId = textOf(_selected?['id']);
                          final selected = id == selectedId && id.isNotEmpty;
                          final avail =
                              int.tryParse(textOf(sched['available_seats'])) ??
                                  0;
                          final enough = avail >= _passengerCount;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: enough
                                  ? () => _selectSchedule(sched)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppTheme.primaryColor
                                          .withValues(alpha: 0.08)
                                      : AppTheme.subtleSurface(context),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? AppTheme.primaryColor
                                        : AppTheme.border(context)
                                            .withValues(alpha: 0.6),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons
                                              .radio_button_unchecked_rounded,
                                      size: 20,
                                      color: selected
                                          ? AppTheme.primaryColor
                                          : AppTheme.mutedText(context),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dateText(sched['departure_date']),
                                            style: GoogleFonts.anuphan(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color:
                                                  AppTheme.onSurface(context),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            enough
                                                ? 'ว่าง $avail ที่นั่ง'
                                                : 'ที่นั่งไม่พอ (ว่าง $avail)',
                                            style: GoogleFonts.anuphan(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: enough
                                                  ? AppTheme.mutedText(context)
                                                  : AppTheme.warningColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  if (_selected != null && _isSeatBased) ...[
                    const SizedBox(height: 8),
                    Text(
                      'เลือกที่นั่งใหม่ (${_selectedSeats.length}/$_passengerCount)',
                      style: GoogleFonts.anuphan(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_loadingSeats)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: asList(_seatsData?['seats']).map((item) {
                          final seat = asMap(item);
                          final id = textOf(seat['id']);
                          final label = textOf(seat['label'], id);
                          final available =
                              textOf(seat['status']) == 'available';
                          final picked = _selectedSeats.contains(id);
                          return GestureDetector(
                            onTap: available ? () => _toggleSeat(id) : null,
                            child: Container(
                              width: 52,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: picked
                                    ? AppTheme.primaryColor
                                    : available
                                        ? AppTheme.surface(context)
                                        : AppTheme.border(context)
                                            .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: picked
                                      ? AppTheme.primaryColor
                                      : AppTheme.border(context),
                                ),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.anuphan(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: picked
                                      ? Colors.white
                                      : available
                                          ? AppTheme.onSurface(context)
                                          : AppTheme.mutedText(context),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _canSubmit ? _submit : null,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('ยืนยันเปลี่ยนวันเดินทาง'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Change pickup sheet (เปลี่ยนจุดรับ) ───────────────────────────────────────

class _ChangePickupSheet extends StatefulWidget {
  final Map<String, dynamic> booking;

  const _ChangePickupSheet({required this.booking});

  @override
  State<_ChangePickupSheet> createState() => _ChangePickupSheetState();
}

class _ChangePickupSheetState extends State<_ChangePickupSheet> {
  int? _selectedId;
  bool _submitting = false;

  Map<String, dynamic> get _schedule => asMap(widget.booking['schedule']);
  String get _ref => textOf(widget.booking['booking_ref']);

  @override
  void initState() {
    super.initState();
    final current = asMap(widget.booking['pickup_point']);
    _selectedId = int.tryParse(textOf(current['id']));
  }

  Future<void> _submit() async {
    final id = _selectedId;
    if (id == null) return;
    setState(() => _submitting = true);
    try {
      await context
          .read<AppProvider>()
          .changeBookingPickup(_ref, pickupPointId: id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showSnack(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final points = asList(_schedule['pickup_points']);
    final currentId = int.tryParse(textOf(asMap(widget.booking['pickup_point'])['id']));
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 16),
          Text(
            'เปลี่ยนจุดรับ',
            style: GoogleFonts.anuphan(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'เลือกจุดรับใหม่สำหรับรอบเดินทางนี้ · คงราคาเดิม',
            style: GoogleFonts.anuphan(
              fontSize: 12.5,
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: points.map((item) {
                  final p = asMap(item);
                  final id = int.tryParse(textOf(p['id']));
                  final selected = id == _selectedId;
                  final isCurrent = id == currentId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: id == null
                          ? null
                          : () => setState(() => _selectedId = id),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryColor.withValues(alpha: 0.08)
                              : AppTheme.subtleSurface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primaryColor
                                : AppTheme.border(context)
                                    .withValues(alpha: 0.6),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: selected
                                  ? AppTheme.primaryColor
                                  : AppTheme.mutedText(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          textOf(p['pickup_location'],
                                              textOf(p['region_label'])),
                                          style: GoogleFonts.anuphan(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.onSurface(context),
                                          ),
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.mutedText(context)
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'ปัจจุบัน',
                                            style: GoogleFonts.anuphan(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.mutedText(context),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (textOf(p['region_label']).isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      textOf(p['region_label']),
                                      style: GoogleFonts.anuphan(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.mutedText(context),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_selectedId == null ||
                      _selectedId == currentId ||
                      _submitting)
                  ? null
                  : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('ยืนยันเปลี่ยนจุดรับ'),
            ),
          ),
        ],
      ),
    );
  }
}
