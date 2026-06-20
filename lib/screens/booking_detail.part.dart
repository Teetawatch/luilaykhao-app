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
          // Lowest unpaid installment the customer can still pay (no.1 is settled
          // at booking time, so the next payable is always >= 2).
          final nextInstallmentNo = () {
            final unpaid =
                installments
                    .map(asMap)
                    .where((i) => textOf(i['status']) != 'paid')
                    .map((i) => int.tryParse(textOf(i['installment_no'])) ?? 0)
                    .where((no) => no >= 2)
                    .toList()
                  ..sort();
            return unpaid.isEmpty ? null : unpaid.first;
          }();
          final installmentAvailable = _scheduleInstallmentAvailable(schedule);
          final depositAvailable =
              _scheduleDepositAvailable(schedule) &&
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
          final balanceUnpaid =
              bookingPaymentType == 'deposit' &&
              textOf(booking['balance_paid_at']).isEmpty &&
              (num.tryParse(booking['balance_amount']?.toString() ?? '0') ??
                      0) >
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

                // Pre-trip checklist — available the whole time the trip is
                // still ahead, so travellers can prepare well in advance.
                if (textOf(booking['status']) == 'confirmed' &&
                    !_isTripFinished(schedule)) ...[
                  _ChecklistEntryRow(booking: booking),
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
                    scheduleId: int.tryParse(textOf(schedule['id'])) ?? 0,
                  ),
                  const SizedBox(height: 20),
                ],

                // Trip title + booking ref
                Text(
                  textOf(trip['title'], 'รายละเอียดการจอง'),
                  style: appFont(
                    color: AppTheme.primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  textOf(booking['booking_ref']),
                  style: appFont(
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
                    _Chip('เดินทาง ${departureText(schedule)}'),
                    _Chip(money(booking['total_amount'])),
                  ],
                ),
                const SizedBox(height: 16),

                // Departure-day weather (only present when the backend resolved
                // a forecast for the trip's coordinates).
                if (asMap(schedule['weather']).isNotEmpty) ...[
                  _WeatherCard(weather: asMap(schedule['weather'])),
                  const SizedBox(height: 16),
                ],

                // Companion invites — เชิญเพื่อนเข้าการจองเดียวกัน
                if (textOf(booking['status']) == 'pending' ||
                    textOf(booking['status']) == 'confirmed') ...[
                  _BookingMembersSection(booking: booking),
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
                  final name = '${textOf(p['title'])} ${textOf(p['name'])}'
                      .trim();
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
                          color: AppTheme.border(
                            context,
                          ).withValues(alpha: 0.6),
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
                                  style: appFont(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppTheme.onSurface(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  phone,
                                  style: appFont(
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

                // Operator announcements (ประกาศจากผู้จัด) — self-loading,
                // renders nothing when the round has no announcements yet.
                if (textOf(booking['status']) != 'cancelled' &&
                    (int.tryParse(textOf(schedule['id'])) ?? 0) > 0) ...[
                  const SizedBox(height: 16),
                  _AnnouncementsEntry(
                    scheduleId: int.tryParse(textOf(schedule['id'])) ?? 0,
                    tripTitle: textOf(asMap(schedule['trip'])['title']),
                  ),
                ],

                // Vehicle & driver section
                if (textOf(booking['status']) != 'cancelled' &&
                    _hasVehicleInfo(asMap(schedule['vehicle']))) ...[
                  const SizedBox(height: 16),
                  const _SheetSectionTitle(
                    icon: Icons.directions_car_rounded,
                    title: 'รถและคนขับ',
                  ),
                  const SizedBox(height: 10),
                  _VehicleDriverCard(vehicle: asMap(schedule['vehicle'])),
                ],

                // Assigned staff section
                if (asList(booking['assigned_staff']).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _SheetSectionTitle(
                    icon: Icons.badge_rounded,
                    title: 'สตาฟ / ไกด์ประจำรอบ',
                  ),
                  const SizedBox(height: 10),
                  _AssignedStaffList(
                    staffList: asList(booking['assigned_staff']),
                  ),
                ],

                // Trip photos taken by staff (R2). Self-loading; returns
                // an empty widget when there are no photos yet.
                if (textOf(booking['status']) != 'cancelled')
                  BookingPhotosSection(bookingRef: widget.bookingRef),

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
                                : AppTheme.border(
                                    context,
                                  ).withValues(alpha: 0.6),
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
                                    style: appFont(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: AppTheme.onSurface(context),
                                    ),
                                  ),
                                  Text(
                                    'ครบกำหนด ${dateText(inst['due_date'])}',
                                    style: appFont(
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
                  if (nextInstallmentNo != null) ...[
                    const SizedBox(height: 4),
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
                                installmentNo: nextInstallmentNo,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.payments_outlined),
                        label: Text('ชำระงวดที่ $nextInstallmentNo'),
                      ),
                    ),
                  ],
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
                            builder: (_) =>
                                PaymentScreen(bookingRef: widget.bookingRef),
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

                // Review CTA — available once the trip is over (backend gates
                // via can_review: confirmed + after the last day, not yet reviewed).
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
                if (_asBool(booking['can_reschedule']) ||
                    _asBool(booking['can_modify']) ||
                    textOf(booking['rescheduled_at']).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 28),
                  const _SheetSectionTitle(
                    icon: Icons.edit_calendar_rounded,
                    title: 'แก้ไขการจอง',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'เปลี่ยนวันเดินทางได้ครั้งเดียว และต้องก่อนเดินทางอย่างน้อย 20 วัน · คงราคาเดิม',
                    style: appFont(
                      fontSize: 12,
                      color: AppTheme.mutedText(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_asBool(booking['can_reschedule']))
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openReschedule(context, booking),
                        icon: const Icon(Icons.event_repeat_rounded),
                        label: const Text('เปลี่ยนวันเดินทาง'),
                      ),
                    )
                  else if (textOf(booking['rescheduled_at']).isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: AppTheme.mutedText(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'เปลี่ยนวันเดินทางได้ครั้งเดียว · ใช้สิทธิ์ไปแล้ว',
                            style: appFont(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_asBool(booking['can_modify']) &&
                      asList(schedule['pickup_points']).isNotEmpty) ...[
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
    final trip = asMap(asMap(booking['schedule'])['trip']);
    final submitted = await ReviewSubmissionDialog.show(
      context,
      bookingId: int.parse(booking['id'].toString()),
      tripTitle: textOf(trip['title'], 'การจอง'),
    );
    if (!submitted || !context.mounted) return;
    showSnack(context, 'ส่งรีวิวแล้ว ขอบคุณที่ช่วยแชร์ประสบการณ์');
    _reload(); // refetch — can_review flips to false once reviewed
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

/// Departure-day weather forecast card. Reads the `schedule['weather']` payload
/// the backend attaches to a booking detail. Shows the condition, temperature
/// range and rain chance, plus a coloured advisory banner when the forecast is
/// rough — informational only; the trip still departs as scheduled.
class _WeatherCard extends StatelessWidget {
  final Map<String, dynamic> weather;

  const _WeatherCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final severity = textOf(weather['severity'], 'none');
    final desc = textOf(weather['description_th']);
    final pop = num.tryParse(weather['pop']?.toString() ?? '') ?? 0;
    final popPercent = (pop * 100).round();
    final tempMin = num.tryParse(weather['temp_min']?.toString() ?? '');
    final tempMax = num.tryParse(weather['temp_max']?.toString() ?? '');
    final code = textOf(weather['condition_code']);

    final gradient = _gradientFor(code);

    final note = switch (severity) {
      'warning' =>
        'อากาศไม่ค่อยดี เตรียมเสื้อกันฝน รองเท้ากันลื่น และกันน้ำให้อุปกรณ์',
      'advisory' => 'มีโอกาสฝน เตรียมเสื้อกันฝนติดไปเผื่อไว้',
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.36),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: label + condition on the left, weather glyph on the right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'พยากรณ์อากาศวันเดินทาง',
                          style: appFont(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        desc,
                        style: appFont(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(code), color: Colors.white, size: 30),
              ),
            ],
          ),

          // Temperature — Apple Weather daily style: the high is the headline
          // figure, with the low shown dimmed beside it (no redundant pill).
          if (tempMax != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${tempMax.round()}°',
                  style: appFont(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -1,
                    color: Colors.white,
                  ),
                ),
                if (tempMin != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    'ต่ำสุด ${tempMin.round()}°',
                    style: appFont(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Metric pills.
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(Icons.water_drop_rounded, 'โอกาสฝน $popPercent%'),
            ],
          ),

          // Advisory — frosted chip, only when the forecast is rough.
          if (note != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    severity == 'warning'
                        ? Icons.warning_amber_rounded
                        : Icons.cloudy_snowing,
                    size: 17,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: appFont(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: appFont(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Sky-condition gradient in the spirit of Apple Weather — the colour conveys
  /// the mood (clear/cloud/rain/storm) rather than a flat severity tint.
  List<Color> _gradientFor(String conditionCode) {
    final group = conditionCode.isNotEmpty ? conditionCode[0] : '';
    return switch (group) {
      '2' => const [Color(0xFF3E4C66), Color(0xFF232C3F)], // thunderstorm
      '3' => const [Color(0xFF5B7C9D), Color(0xFF3C566F)], // drizzle
      '5' => const [Color(0xFF4E6E8E), Color(0xFF2F4858)], // rain
      '6' => const [Color(0xFF7FA8C9), Color(0xFF587FA0)], // snow
      '7' => const [Color(0xFF8A93A0), Color(0xFF5E6672)], // fog / haze
      '8' => conditionCode == '800'
          ? const [Color(0xFF4A95D6), Color(0xFF2C6FB5)] // clear sky
          : const [Color(0xFF6E8AA8), Color(0xFF4C6582)], // clouds
      _ => const [Color(0xFF4A95D6), Color(0xFF2C6FB5)],
    };
  }

  IconData _iconFor(String conditionCode) {
    final group = conditionCode.isNotEmpty ? conditionCode[0] : '';
    return switch (group) {
      '2' => Icons.thunderstorm_rounded,
      '3' => Icons.grain_rounded,
      '5' => Icons.cloudy_snowing,
      '6' => Icons.ac_unit_rounded,
      '7' => Icons.foggy,
      '8' => conditionCode == '800'
          ? Icons.wb_sunny_rounded
          : Icons.cloud_rounded,
      _ => Icons.cloud_outlined,
    };
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
                style: appFont(
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
                    style: appFont(
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
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: appFont(
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

// ─── Pre-trip Briefing Card ───────────────────────────────────────────────────

/// วันออกเดินทางจริง (ตัดเวลา) — ใช้ departs_at ถ้ารอบนั้นรถออกคืนก่อนวันทริป
DateTime? _realDepartureDate(Map<String, dynamic> schedule) {
  final dep = scheduleDepartsAt(schedule) ??
      DateTime.tryParse(textOf(schedule['departure_date']));
  if (dep == null) return null;
  return DateTime(dep.year, dep.month, dep.day);
}

/// True when departure is 0-3 days away (today through departure day inclusive).
bool _isPreTripWindow(Map<String, dynamic> schedule) {
  final start = _realDepartureDate(schedule);
  if (start == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
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
    final customPickup = asMap(booking['custom_pickup']);
    final staffList = asList(booking['assigned_staff']);

    // จุดรับที่จะแสดงในหน้านี้ (พร้อมรูป) — เลือกจากแหล่งที่ครบที่สุด:
    // 1) จุดที่ booking เลือกไว้ (booking.pickup_point)
    // 2) จุดเดียวกันใน schedule.pickup_points (เผื่อ relation ฝั่ง booking ไม่มี image_url)
    // 3) ถ้า booking ไม่ได้ระบุจุด (เลือกแบบภูมิภาค) ใช้จุดของภูมิภาคนั้นใน schedule
    final schedulePickups =
        asList(schedule['pickup_points']).map(asMap).toList();
    final bookingPickup = asMap(booking['pickup_point']);
    final matchedById = schedulePickups.firstWhere(
      (p) =>
          bookingPickup.isNotEmpty &&
          p['id'].toString() == bookingPickup['id'].toString(),
      orElse: () => <String, dynamic>{},
    );
    var pickupPoint = bookingPickup;
    if (pickupPoint.isEmpty) {
      final region = textOf(booking['pickup_region']);
      if (region.isNotEmpty) {
        pickupPoint = schedulePickups.firstWhere(
          (p) => textOf(p['region']) == region,
          orElse: () => <String, dynamic>{},
        );
      }
    }
    final pickupImageUrl = ApiConfig.mediaUrl(
      textOf(pickupPoint['image_url']).isNotEmpty
          ? pickupPoint['image_url']
          : matchedById['image_url'],
    );
    final preparations = asList(trip['preparations']);
    final mustKnow = asList(trip['must_know']);

    final depDate = _realDepartureDate(schedule);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = depDate?.difference(today).inDays;

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
              ? [const Color(0xFF0F4C2A), const Color(0xFF0A2E1A)]
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
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
                    Icons.backpack_rounded,
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
                        style: appFont(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        countdownText,
                        style: appFont(
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
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    departureText(schedule),
                    style: appFont(
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
                          textOf(
                            pickupPoint['pickup_location'],
                            textOf(pickupPoint['region']),
                          ),
                          style: appFont(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface(context),
                            height: 1.4,
                          ),
                        ),
                        if (pickupImageUrl.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: pickupImageUrl,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                height: 150,
                                color: AppTheme.subtleSurface(context),
                                child: const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                              // อย่าซ่อนเงียบ — โชว์ placeholder ให้เห็นว่ามีรูปแต่โหลดไม่ได้
                              errorWidget: (_, _, _) => Container(
                                height: 150,
                                color: AppTheme.subtleSurface(context),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppTheme.mutedText(context),
                                        size: 26,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'โหลดรูปไม่สำเร็จ',
                                        style: appFont(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.mutedText(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (textOf(pickupPoint['notes']).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            textOf(pickupPoint['notes']),
                            style: appFont(
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
                                textOf(pickupPoint['map_url']),
                              );
                              if (await canLaunchUrl(uri)) {
                                launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
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
                                  style: appFont(
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

                // จุดรับที่ลูกค้าปักหมุดเอง (custom) พร้อมสถานะยืนยัน
                if (customPickup.isNotEmpty) ...[
                  _CustomPickupBriefing(customPickup: customPickup),
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
                                  final uri = Uri(scheme: 'tel', path: phone);
                                  if (await canLaunchUrl(uri)) {
                                    launchUrl(uri);
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surface(
                                context,
                              ).withValues(alpha: 0.80),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.20,
                                ),
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
                                  phone.isNotEmpty ? '$name  $phone' : name,
                                  style: appFont(
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
                                  style: appFont(
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
                    style: appFont(
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
                style: appFont(
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

/// จุดรับที่ลูกค้าปักหมุดเอง — แสดงสถานะ (รอยืนยัน / ยืนยันแล้ว + ค่าบริการ / ปฏิเสธ)
class _CustomPickupBriefing extends StatelessWidget {
  final Map<String, dynamic> customPickup;

  const _CustomPickupBriefing({required this.customPickup});

  @override
  Widget build(BuildContext context) {
    final status = textOf(customPickup['status']);
    final (Color color, String label, IconData icon) = switch (status) {
      'approved' => (
        const Color(0xFF15803D),
        'ยืนยันแล้ว',
        Icons.check_circle_rounded,
      ),
      'rejected' => (
        AppTheme.errorColor,
        'ไม่ผ่านการยืนยัน',
        Icons.cancel_rounded,
      ),
      _ => (
        const Color(0xFFB45309),
        'รอเจ้าหน้าที่ยืนยัน',
        Icons.hourglass_top_rounded,
      ),
    };

    return _BriefingSection(
      icon: Icons.add_location_alt_rounded,
      title: 'จุดรับที่ปักหมุดเอง',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            textOf(customPickup['label']),
            style: appFont(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
              height: 1.4,
            ),
          ),
          if (textOf(customPickup['note']).isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              textOf(customPickup['note']),
              style: appFont(
                fontSize: 12.5,
                color: AppTheme.mutedText(context),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  status == 'approved'
                      ? '$label · ค่าบริการ ${money(customPickup['price'])}'
                      : label,
                  style: appFont(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (status == 'rejected' &&
              textOf(customPickup['reject_reason']).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              textOf(customPickup['reject_reason']),
              style: appFont(
                fontSize: 12,
                color: AppTheme.errorColor,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Interactive pre-departure checklist. Items come from the trip's
/// `preparations`; the tick state is stored locally per booking in
/// SharedPreferences (no backend), keyed by item text so it survives reorder.
/// Tappable summary that opens the full pre-trip checklist. Shows live
/// progress (ticked / total, including the traveller's personal items) so the
/// row itself nudges them to finish packing.
class _ChecklistEntryRow extends StatefulWidget {
  final Map<String, dynamic> booking;

  const _ChecklistEntryRow({required this.booking});

  @override
  State<_ChecklistEntryRow> createState() => _ChecklistEntryRowState();
}

class _ChecklistEntryRowState extends State<_ChecklistEntryRow> {
  ChecklistState _state = ChecklistState.empty;

  String get _ref => textOf(widget.booking['booking_ref']);

  List<String> get _prep {
    final schedule = asMap(widget.booking['schedule']);
    final trip = asMap(schedule['trip']);
    return asList(trip['preparations'])
        .map(
          (item) => item is Map
              ? textOf(item['text'] ?? item['title'] ?? item['name'])
              : item.toString(),
        )
        .where((t) => t.trim().isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await ChecklistStorage.instance.read(_ref);
    if (mounted) setState(() => _state = state);
  }

  int get _total => _prep.length + _state.customItems.length;

  int get _done {
    final prepDone = _prep.where(_state.checkedPrep.contains).length;
    final customDone = _state.customItems.where((c) => c.checked).length;
    return prepDone + customDone;
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreTripChecklistScreen.fromBooking(widget.booking),
      ),
    );
    _load(); // refresh progress after returning
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final done = _done;
    final allDone = total > 0 && done == total;
    final progress = total == 0 ? 0.0 : done / total;

    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.border(context).withValues(alpha: 0.55),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.checklist_rounded,
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
                        'เช็กของก่อนเดินทาง',
                        style: appFont(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface(context),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        total == 0
                            ? 'แตะเพื่อเพิ่มของที่ต้องเตรียม'
                            : allDone
                                ? 'เตรียมของครบแล้ว 🎒'
                                : 'เตรียมแล้ว $done จาก $total รายการ',
                        style: appFont(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: allDone
                              ? AppTheme.primaryColor
                              : AppTheme.mutedText(context),
                        ),
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: AppTheme.primaryColor
                                .withValues(alpha: 0.10),
                            valueColor: const AlwaysStoppedAnimation(
                              AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.mutedText(context).withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// True once the trip is over (its return date — or departure date if there's
/// no return — is in the past). Used to hide the pre-trip checklist afterwards.
bool _isTripFinished(Map<String, dynamic> schedule) {
  final dep = DateTime.tryParse(textOf(schedule['departure_date']));
  if (dep == null) return false;
  final ret = DateTime.tryParse(textOf(schedule['return_date'])) ?? dep;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final end = DateTime(ret.year, ret.month, ret.day);
  return today.isAfter(end);
}

/// True when today falls within the SOS window: from one day before the
/// schedule's departure through the return date (inclusive). The SOS button is
/// shown a day early so travellers can reach help while heading to the pickup.
bool _isWithinTripWindow(Map<String, dynamic> schedule) {
  final dep = _realDepartureDate(schedule);
  if (dep == null) return false;
  final ret = DateTime.tryParse(textOf(schedule['return_date'])) ?? dep;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // เปิด SOS ตั้งแต่ 1 วันก่อนวันออกรถจริง
  final start = dep.subtract(const Duration(days: 1));
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
            const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'ส่ง SOS แล้ว',
              style: appFont(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Text(
          hasLocation
              ? 'สตาฟและเพื่อนร่วมทริปได้รับการแจ้งเตือนพร้อมตำแหน่งของคุณแล้ว'
              : 'สตาฟและเพื่อนร่วมทริปได้รับการแจ้งเตือนแล้ว '
                    '(ไม่สามารถระบุตำแหน่ง GPS ได้)',
          style: appFont(fontSize: 13, height: 1.5),
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
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
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
                    : const Icon(
                        Icons.sos_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ขอความช่วยเหลือฉุกเฉิน',
                      style: appFont(
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
                      style: appFont(
                        fontSize: 12,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _sosRed.withValues(alpha: 0.7),
              ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่สามารถเปิดรูปได้')));
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
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: _sosRed,
                ),
                title: Text(
                  'ถ่ายรูป',
                  style: appFont(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: _sosRed,
                ),
                title: Text(
                  'เลือกจากคลังภาพ',
                  style: appFont(fontWeight: FontWeight.w700),
                ),
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
                    style: appFont(
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
                style: appFont(
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
                          color: selected ? _sosRed : Colors.grey.shade200,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(opt.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              opt.label,
                              style: appFont(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? _sosRed
                                    : Colors.grey.shade800,
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
                  style: appFont(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'อธิบายสถานการณ์โดยย่อ...',
                    hintStyle: appFont(color: Colors.grey.shade400),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'สตาฟและผู้โดยสารในทริปจะได้รับการแจ้งเตือนพร้อมตำแหน่ง GPS ทันที',
                        style: appFont(
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
                      : Icon(
                          Icons.add_a_photo_outlined,
                          size: 19,
                          color: Colors.grey.shade700,
                        ),
                  label: Text(
                    'แนบรูปสถานที่ (ไม่บังคับ)',
                    style: appFont(
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
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
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
                        style: appFont(
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
                        style: appFont(
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

// ─── Announcements entry (ประกาศจากผู้จัด) ────────────────────────────────────

/// Self-loading entry card for a schedule's official announcements. Shows the
/// latest one as a teaser plus an unread badge, and opens the full Apple-style
/// feed on tap. Renders nothing until loaded / when the round has none, so it
/// never adds empty clutter to the booking sheet.
class _AnnouncementsEntry extends StatefulWidget {
  final int scheduleId;
  final String tripTitle;

  const _AnnouncementsEntry({required this.scheduleId, required this.tripTitle});

  @override
  State<_AnnouncementsEntry> createState() => _AnnouncementsEntryState();
}

class _AnnouncementsEntryState extends State<_AnnouncementsEntry> {
  bool _loaded = false;
  List<Map<String, dynamic>> _items = const [];
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context
          .read<AppProvider>()
          .scheduleAnnouncements(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _items = (data['announcements'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _unread = int.tryParse('${data['unread_count']}') ?? 0;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _open() async {
    HapticFeedback.selectionClick();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleAnnouncementsScreen(
          scheduleId: widget.scheduleId,
          tripTitle: widget.tripTitle,
        ),
      ),
    );
    _load(); // refresh unread badge after returning
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _items.isEmpty) return const SizedBox.shrink();

    final latest = _items.first;
    final title = textOf(latest['title']);
    final body = textOf(latest['body']);
    final isDark = AppTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetSectionTitle(
          icon: Icons.campaign_rounded,
          title: 'ประกาศจากผู้จัด',
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _open,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
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
                        title.isNotEmpty ? title : 'มีประกาศใหม่จากทีมงาน',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appFont(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _items.length > 1
                            ? 'ดูทั้งหมด ${_items.length} ประกาศ'
                            : 'ดูประกาศ',
                        style: appFont(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30), // systemRed unread badge
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    child: Text(
                      _unread > 9 ? '9+' : '$_unread',
                      style: appFont(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.mutedText(context),
                  ),
              ],
            ),
          ),
        ),
      ],
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
                              style: appFont(
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
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                nickname,
                                style: appFont(
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
                                style: appFont(
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

bool _hasVehicleInfo(Map<String, dynamic> vehicle) {
  return textOf(vehicle['license_plate']).trim().isNotEmpty ||
      textOf(vehicle['color']).trim().isNotEmpty ||
      textOf(vehicle['driver_name']).trim().isNotEmpty ||
      textOf(vehicle['driver_phone']).trim().isNotEmpty ||
      _vehicleImageUrls(vehicle).isNotEmpty;
}

/// Resolves a vehicle's photo list (stored paths or `{url}` maps) to full URLs.
List<String> _vehicleImageUrls(Map<String, dynamic> vehicle) {
  final raw = vehicle['images'];
  if (raw is! List) return const [];
  final urls = <String>[];
  for (final e in raw) {
    final url = e is Map
        ? ApiConfig.mediaUrl(e['url'] ?? e['path'] ?? e['image'])
        : ApiConfig.mediaUrl(e);
    if (url.trim().isNotEmpty) urls.add(url);
  }
  return urls;
}

class _VehicleDriverCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const _VehicleDriverCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final name = textOf(vehicle['name']).trim();
    final type = textOf(vehicle['type']).trim();
    final plate = textOf(vehicle['license_plate']).trim();
    final color = textOf(vehicle['color']).trim();
    final driverName = textOf(vehicle['driver_name']).trim();
    final driverPhone = textOf(vehicle['driver_phone']).trim();
    final hasDriver = driverName.isNotEmpty || driverPhone.isNotEmpty;
    final images = _vehicleImageUrls(vehicle);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle photos
          if (images.isNotEmpty) ...[
            _VehicleImages(images: images),
            const SizedBox(height: 12),
          ],
          // Vehicle row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.airport_shuttle_rounded,
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
                      name.isNotEmpty
                          ? name
                          : (type.isNotEmpty ? type : 'รถรับส่ง'),
                      style: appFont(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    if (plate.isNotEmpty || color.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (plate.isNotEmpty) _PlateChip(plate: plate),
                          if (color.isNotEmpty) _ColorChip(color: color),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Driver row
          if (hasDriver) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.border(context).withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: AppTheme.mutedText(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'คนขับ',
                        style: appFont(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                      Text(
                        driverName.isNotEmpty ? driverName : '-',
                        style: appFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (driverPhone.isNotEmpty)
                  _CallButton(phone: driverPhone),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Vehicle photo strip inside the booking detail's "รถและคนขับ" card. A single
/// photo shows as a wide banner; multiple scroll horizontally. Tap to view full
/// screen via the shared photo viewer.
class _VehicleImages extends StatelessWidget {
  final List<String> images;

  const _VehicleImages({required this.images});

  void _open(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _BookingPhotoViewer(urls: images, initialIndex: index),
      ),
    );
  }

  Widget _thumb(BuildContext context, String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: AppTheme.subtleSurface(context)),
      errorWidget: (_, _, _) => Container(
        color: AppTheme.subtleSurface(context),
        alignment: Alignment.center,
        child: Icon(
          Icons.directions_bus_rounded,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return GestureDetector(
        onTap: () => _open(context, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _thumb(context, images.first),
          ),
        ),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _open(context, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 190,
              child: _thumb(context, images[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlateChip extends StatelessWidget {
  final String plate;

  const _PlateChip({required this.plate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.border(context),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pin_rounded,
            size: 13,
            color: AppTheme.mutedText(context),
          ),
          const SizedBox(width: 5),
          Text(
            plate,
            style: appFont(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: AppTheme.onSurface(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String color;

  const _ColorChip({required this.color});

  @override
  Widget build(BuildContext context) {
    final swatch = _swatchFor(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: swatch,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.border(context),
                width: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            color,
            style: appFont(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
            ),
          ),
        ],
      ),
    );
  }

  // Best-effort mapping of common Thai/English colour names to a swatch.
  static Color? _swatchFor(String raw) {
    final c = raw.toLowerCase();
    bool has(List<String> keys) => keys.any(c.contains);
    if (has(['ขาว', 'white'])) return const Color(0xFFF8FAFC);
    if (has(['ดำ', 'black'])) return const Color(0xFF1F2937);
    if (has(['เทา', 'gray', 'grey', 'silver', 'เงิน'])) {
      return const Color(0xFF9CA3AF);
    }
    if (has(['แดง', 'red'])) return const Color(0xFFEF4444);
    if (has(['น้ำเงิน', 'ฟ้า', 'blue'])) return const Color(0xFF3B82F6);
    if (has(['เขียว', 'green'])) return const Color(0xFF10B981);
    if (has(['เหลือง', 'yellow'])) return const Color(0xFFF59E0B);
    if (has(['ส้ม', 'orange'])) return const Color(0xFFF97316);
    if (has(['น้ำตาล', 'brown'])) return const Color(0xFF92400E);
    if (has(['ทอง', 'gold', 'แชมเปญ', 'champagne', 'บรอนซ์', 'bronze'])) {
      return const Color(0xFFD4AF37);
    }
    return null;
  }
}

class _CallButton extends StatelessWidget {
  final String phone;

  const _CallButton({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final uri = Uri(scheme: 'tel', path: phone);
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'โทร',
                style: appFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
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
      final heroTag = 'staff-photo-${url.hashCode}-${name.hashCode}';
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => _StaffPhotoView(
                url: url,
                name: name,
                heroTag: heroTag,
              ),
            ),
          );
        },
        child: Hero(
          tag: heroTag,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorWidget: (context, e, s) => _fallback(context),
                ),
              ),
              // Subtle hint that the photo is tappable to enlarge.
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.zoom_out_map_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
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
          style: appFont(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom viewer for a staff/guide photo. Opened by tapping
/// the avatar in [_AssignedStaffList]; shares a [Hero] tag with the thumbnail
/// for a smooth zoom transition. Tap anywhere (or the close button) to dismiss.
class _StaffPhotoView extends StatelessWidget {
  final String url;
  final String name;
  final String heroTag;

  const _StaffPhotoView({
    required this.url,
    required this.name,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Hero(
                    tag: heroTag,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Close button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
          ),
          // Name caption
          if (name.isNotEmpty)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      name,
                      style: appFont(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
  String get _tripTitle => textOf(asMap(_schedule['trip'])['title'], 'ทริป');
  int get _currentScheduleId => int.tryParse(textOf(_schedule['id'])) ?? 0;
  String get _ref => textOf(widget.booking['booking_ref']);
  int get _passengerCount => asList(widget.booking['passengers']).length;
  bool get _isSeatBased => asList(widget.booking['seats']).isNotEmpty;

  /// ป้ายที่นั่งปัจจุบันของการจอง (เช่น A1, A2) เพื่อแสดงในสรุปรอบปัจจุบัน
  List<String> get _currentSeatLabels => asList(widget.booking['seats'])
      .map((e) => textOf(asMap(e)['seat_id']))
      .where((s) => s.isNotEmpty)
      .toList();

  /// เส้นตายเปลี่ยนวัน (20 วันก่อนเดินทาง) จาก backend — ใช้โชว์ให้ชัดเจน
  DateTime? get _deadline =>
      DateTime.tryParse(textOf(widget.booking['reschedule_deadline']))
          ?.toLocal();

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
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
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
            style: appFont(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tripTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              fontSize: 13,
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _currentBookingCard(),
                  const SizedBox(height: 10),
                  _rulesNotice(),
                  const SizedBox(height: 18),
                  _stepLabel('1', 'เลือกรอบเดินทางใหม่'),
                  const SizedBox(height: 10),
                  _scheduleList(),
                  if (_selected != null && _isSeatBased) ...[
                    const SizedBox(height: 20),
                    _stepLabel(
                      '2',
                      'เลือกที่นั่งใหม่  ${_selectedSeats.length}/$_passengerCount',
                    ),
                    const SizedBox(height: 12),
                    _seatSection(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _confirmBar(context),
        ],
      ),
    );
  }

  // ── Numbered step label, matching the booking flow's stepping ──────────────
  Widget _stepLabel(String step, String label) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            step,
            style: appFont(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: appFont(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
        ),
      ],
    );
  }

  // ── Summary of the booking being moved (current date / pax / seats) ────────
  Widget _currentBookingCard() {
    final seats = _currentSeatLabels;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รอบปัจจุบัน',
            style: appFont(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 8),
          _infoRow(Icons.event_rounded, departureText(_schedule)),
          const SizedBox(height: 6),
          _infoRow(Icons.groups_rounded, '$_passengerCount ผู้เดินทาง'),
          if (seats.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(Icons.event_seat_rounded, 'ที่นั่ง ${seats.join(', ')}'),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: appFont(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
            ),
          ),
        ),
      ],
    );
  }

  // ── The reschedule rules, stated plainly so there's no confusion ───────────
  Widget _rulesNotice() {
    final deadline = _deadline;
    final deadlineText = deadline != null
        ? DateFormat('d MMM yyyy', 'th_TH').format(deadline)
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bullet('เปลี่ยนได้ครั้งเดียวเท่านั้น'),
                _bullet(
                  'ต้องเปลี่ยนก่อนเดินทางอย่างน้อย 20 วัน'
                  '${deadlineText != null ? ' (ภายใน $deadlineText)' : ''}',
                ),
                _bullet('คงราคาเดิม · เปลี่ยนได้เฉพาะรอบของทริปนี้'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '• $text',
        style: appFont(
          fontSize: 12.5,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: AppTheme.onSurface(context).withValues(alpha: 0.8),
        ),
      ),
    );
  }

  // ── Step 1 — pick a new schedule of the same trip ──────────────────────────
  Widget _scheduleList() {
    return FutureBuilder<List<dynamic>>(
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
            .where(
              (s) =>
                  (int.tryParse(textOf(s['id'])) ?? 0) != _currentScheduleId,
            )
            .toList();
        if (options.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'ไม่มีรอบเดินทางอื่นให้เลือกในขณะนี้',
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
          );
        }
        return Column(children: options.map(_scheduleCard).toList());
      },
    );
  }

  Widget _scheduleCard(Map<String, dynamic> sched) {
    final id = textOf(sched['id']);
    final selected = id == textOf(_selected?['id']) && id.isNotEmpty;
    final avail = int.tryParse(textOf(sched['available_seats'])) ?? 0;
    final enough = avail >= _passengerCount;

    final dep = DateTime.tryParse(textOf(sched['departure_date']));
    final ret = DateTime.tryParse(textOf(sched['return_date']));
    final dateLine = dep != null
        ? DateFormat('EEE d MMM yyyy', 'th_TH').format(dep)
        : departureText(sched);
    String? nights;
    if (dep != null && ret != null) {
      final n = ret.difference(dep).inDays;
      if (n > 0) nights = '$n คืน';
    }

    final accent = enough ? AppTheme.primaryColor : AppTheme.warningColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enough ? () => _selectSchedule(sched) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : AppTheme.border(context).withValues(alpha: 0.6),
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
                            dateLine,
                            style: appFont(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                        ),
                        if (nights != null)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              nights,
                              style: appFont(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          enough
                              ? Icons.event_seat_rounded
                              : Icons.block_rounded,
                          size: 13,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            enough
                                ? 'ว่าง $avail ที่นั่ง'
                                : 'ที่นั่งไม่พอ (ว่าง $avail · ต้องการ $_passengerCount)',
                            style: appFont(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 2 — pick new seats, using the same seat map as the booking flow ───
  Widget _seatSection() {
    if (_loadingSeats) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final data = _seatsData;
    if (data == null) return const SizedBox.shrink();
    final hasSeatMap = data['has_seat_map'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 16),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          const VehicleSeatLegend(),
          const SizedBox(height: 16),
          if (hasSeatMap)
            VehicleSeatMap(
              seatMap: data,
              toneFor: (seat, id) {
                if (_selectedSeats.contains(id)) return SeatTone.picking;
                final status = textOf(seat['status'], 'available');
                if (status == 'booked') return SeatTone.booked;
                if (status == 'locked') return SeatTone.locked;
                return SeatTone.available;
              },
              selectableFor: (seat, id) {
                if (_selectedSeats.contains(id)) return true;
                if (textOf(seat['status'], 'available') != 'available') {
                  return false;
                }
                return _selectedSeats.length < _passengerCount;
              },
              onSeatTap: (seat, id) => _toggleSeat(id),
            )
          else
            _seatWrapFallback(data),
        ],
      ),
    );
  }

  /// Fallback for schedules that have no structured seat map: a plain grid of
  /// seat chips, capped at the passenger count.
  Widget _seatWrapFallback(Map<String, dynamic> data) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: asList(data['seats']).map((item) {
        final seat = asMap(item);
        final id = textOf(seat['id']);
        final label = textOf(seat['label'], id);
        final available = textOf(seat['status']) == 'available';
        final picked = _selectedSeats.contains(id);
        final canTap =
            available && (picked || _selectedSeats.length < _passengerCount);
        return GestureDetector(
          onTap: canTap ? () => _toggleSeat(id) : null,
          child: Container(
            width: 52,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: picked
                  ? AppTheme.primaryColor
                  : available
                  ? AppTheme.surface(context)
                  : AppTheme.border(context).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: picked ? AppTheme.primaryColor : AppTheme.border(context),
              ),
            ),
            child: Text(
              label,
              style: appFont(
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
    );
  }

  // ── Confirmation bar: echoes the target so the user knows what they'll get ─
  Widget _confirmBar(BuildContext context) {
    final target = _selected;
    final targetDate = target != null ? departureText(target) : null;
    final seatSummary = _isSeatBased && target != null
        ? '${_selectedSeats.length}/$_passengerCount ที่นั่ง'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (targetDate != null) ...[
          Row(
            children: [
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ย้ายไป: $targetDate'
                  '${seatSummary != null ? ' · $seatSummary' : ''}',
                  style: appFont(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
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
      await context.read<AppProvider>().changeBookingPickup(
        _ref,
        pickupPointId: id,
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
    final points = asList(_schedule['pickup_points']);
    final currentId = int.tryParse(
      textOf(asMap(widget.booking['pickup_point'])['id']),
    );
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
            style: appFont(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'เลือกจุดรับใหม่สำหรับรอบเดินทางนี้ · คงราคาเดิม',
            style: appFont(
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
                                : AppTheme.border(
                                    context,
                                  ).withValues(alpha: 0.6),
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
                            if (ApiConfig.mediaUrl(p['image_url']).isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: ApiConfig.mediaUrl(p['image_url']),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          textOf(
                                            p['pickup_location'],
                                            textOf(p['region_label']),
                                          ),
                                          style: appFont(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.onSurface(context),
                                          ),
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.mutedText(
                                              context,
                                            ).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            'ปัจจุบัน',
                                            style: appFont(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.mutedText(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (textOf(p['region_label']).isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      textOf(p['region_label']),
                                      style: appFont(
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
              onPressed:
                  (_selectedId == null ||
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
