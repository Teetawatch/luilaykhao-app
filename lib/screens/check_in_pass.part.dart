part of 'customer_app_screen.dart';

/// แผ่น "QR เช็คอิน" ที่เปิดจากปุ่มกลมกลางแถบเมนูล่าง
///
/// เดิม QR อยู่ลึกสามชั้น (แท็บการจอง → ใบจอง → แสดง QR) ซึ่งเป็นสิ่งเดียวที่ต้อง
/// หยิบออกมาไว ๆ หน้ารถตอนเช้ามืด — แผ่นนี้โชว์ QR ของทริปที่ใกล้ที่สุดทันที
/// ใช้ข้อมูลการจองที่แอปแคชไว้ จึงเปิดได้แม้ไม่มีสัญญาณ แล้วค่อยถามเซิร์ฟเวอร์
/// เงียบ ๆ อีกรอบว่าถูกสแกนไปหรือยัง (มีเน็ตเมื่อไหร่สถานะก็ตรง)
///
/// ตัว QR และการ์ด "เช็คอินแล้ว" เป็นวิดเจ็ตชุดเดียวกับในใบจอง หน้าตาจึงตรงกัน
class CheckInPassSheet extends StatefulWidget {
  /// สลับแท็บของหน้าหลัก (ใช้ตอนปุ่มในหน้าว่างพาไปหน้าอื่น)
  final ValueChanged<int> onSelectTab;

  /// เปิดใบจองเต็ม — ต้องใช้ context ของหน้าหลัก เพราะแผ่นนี้ปิดตัวเองก่อน
  final ValueChanged<String> onOpenBooking;

  const CheckInPassSheet({
    super.key,
    required this.onSelectTab,
    required this.onOpenBooking,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<int> onSelectTab,
    required ValueChanged<String> onOpenBooking,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckInPassSheet(
        onSelectTab: onSelectTab,
        onOpenBooking: onOpenBooking,
      ),
    );
  }

  @override
  State<CheckInPassSheet> createState() => _CheckInPassSheetState();
}

class _CheckInPassSheetState extends State<CheckInPassSheet> {
  // แท็บของหน้าหลัก — ต้องตรงกับลำดับ pages ใน CustomerAppScreen
  static const _tripsTabIndex = 1;
  static const _bookingsTabIndex = 2;

  // ถามสถานะล่าสุดเฉพาะไม่กี่ใบแรก — คนส่วนใหญ่มีทริปที่จะถึงแค่ใบสองใบ
  static const _refreshLimit = 3;

  /// ใบจองที่ดึงสดจากเซิร์ฟเวอร์หลังเปิดแผ่น (key = booking_ref)
  final Map<String, Map<String, dynamic>> _fresh = {};
  String? _selectedRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final app = context.read<AppProvider>();
    if (!app.isLoggedIn) return;
    final refs = checkInPassBookings(app.bookings)
        .take(_refreshLimit)
        .map((b) => textOf(b['booking_ref']))
        .where((ref) => ref.isNotEmpty)
        .toList();

    await Future.wait(
      refs.map((ref) async {
        try {
          final fresh = await app
              .booking(ref)
              .timeout(const Duration(seconds: 8));
          if (!mounted) return;
          setState(() => _fresh[ref] = fresh);
        } catch (_) {
          // ไม่มีสัญญาณ/เซิร์ฟเวอร์ช้า — ใช้ข้อมูลที่แคชไว้ต่อ QR ยังสแกนได้
        }
      }),
    );
  }

  /// ข้อมูลในแคชทับด้วยค่าสดที่เพิ่งดึงมา แล้วกรองใหม่อีกรอบ — ใบที่เพิ่งถูกยกเลิก
  /// ระหว่างนั้นจะหลุดออกไปเอง
  List<Map<String, dynamic>> _passes(AppProvider app) {
    final merged = [
      for (final raw in app.bookings)
        () {
          final booking = asMap(raw);
          final fresh = _fresh[textOf(booking['booking_ref'])];
          return fresh == null ? booking : {...booking, ...fresh};
        }(),
    ];
    return checkInPassBookings(merged);
  }

  void _close() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _goToTab(int index) {
    _close();
    widget.onSelectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final passes = app.isLoggedIn
        ? _passes(app)
        : const <Map<String, dynamic>>[];

    Map<String, dynamic>? selected;
    for (final pass in passes) {
      if (textOf(pass['booking_ref']) == _selectedRef) selected = pass;
    }
    selected ??= passes.isEmpty ? null : passes.first;

    final Widget body;
    if (!app.isLoggedIn) {
      body = _CheckInPassEmpty(
        icon: Icons.lock_outline_rounded,
        title: 'เข้าสู่ระบบเพื่อดู QR เช็คอิน',
        message:
            'QR สำหรับเช็คอินวันเดินทางจะอยู่ตรงนี้ '
            'หลังการจองได้รับการยืนยัน',
        actionLabel: 'เข้าสู่ระบบ',
        onAction: () => _goToTab(_bookingsTabIndex),
      );
    } else if (passes.isEmpty && !app.accountLoaded && app.bookings.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (selected == null) {
      body = hasPendingUpcomingBooking(app.bookings)
          ? _CheckInPassEmpty(
              icon: Icons.hourglass_top_rounded,
              title: 'รอยืนยันการจอง',
              message:
                  'QR เช็คอินจะขึ้นที่นี่ทันทีที่การจองได้รับการยืนยัน '
                  'ตรวจสถานะการชำระเงินได้ที่หน้าการจอง',
              actionLabel: 'ดูการจองของฉัน',
              onAction: () => _goToTab(_bookingsTabIndex),
            )
          : _CheckInPassEmpty(
              icon: Icons.qr_code_2_rounded,
              title: 'ยังไม่มีทริปที่ต้องเช็คอิน',
              message:
                  'เมื่อจองทริปแล้ว QR เช็คอินจะอยู่ตรงนี้ '
                  'กดปุ่มเดียวก็โชว์ทีมงานได้ แม้ไม่มีสัญญาณ',
              actionLabel: 'ดูทริปทั้งหมด',
              onAction: () => _goToTab(_tripsTabIndex),
            );
    } else {
      final current = selected;
      final currentRef = textOf(current['booking_ref']);
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (passes.length > 1) ...[
            _CheckInPassPicker(
              passes: passes,
              selectedRef: currentRef,
              onSelect: (ref) {
                HapticFeedback.selectionClick();
                setState(() => _selectedRef = ref);
              },
            ),
            const SizedBox(height: 14),
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _CheckInPassCard(
              key: ValueKey(currentRef),
              booking: current,
              onChanged: _refresh,
              onOpenBooking: () {
                _close();
                widget.onOpenBooking(currentRef);
              },
            ),
          ),
        ],
      );
    }

    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'QR เช็คอิน',
            style: appFont(
              fontSize: AppText.sizeH2,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'แสดง QR นี้ให้ทีมงานสแกนที่จุดนัดหมาย',
            style: appFont(
              fontSize: AppText.sizeLabel,
              color: AppTheme.mutedText(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(child: SingleChildScrollView(child: body)),
        ],
      ),
    );
  }
}

/// เลือกใบจองเมื่อมีทริปที่จะถึงมากกว่าหนึ่งทริป — ชิปแนวนอน เลื่อนได้
class _CheckInPassPicker extends StatelessWidget {
  final List<Map<String, dynamic>> passes;
  final String selectedRef;
  final ValueChanged<String> onSelect;

  const _CheckInPassPicker({
    required this.passes,
    required this.selectedRef,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final pass in passes)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CheckInPassChip(
                booking: pass,
                selected: textOf(pass['booking_ref']) == selectedRef,
                onTap: () => onSelect(textOf(pass['booking_ref'])),
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckInPassChip extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool selected;
  final VoidCallback onTap;

  const _CheckInPassChip({
    required this.booking,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trip = asMap(asMap(booking['schedule'])['trip']);
    final title = textOf(trip['title'], textOf(booking['booking_ref']));
    final when = checkInPassWhenLabel(booking);
    final fg = selected ? Colors.white : AppTheme.onSurface(context);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220, minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : AppTheme.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              if (when.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  when,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppTheme.mutedText(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// บัตรเช็คอินหนึ่งใบ: ทริป · วันเดินทาง · จุดรับ แล้ว QR (หรือสถานะเช็คอินแล้ว)
class _CheckInPassCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onOpenBooking;

  /// เพื่อนเพิ่งเลือกชื่อตัวเอง — ดึงใบจองสดใหม่ ไม่งั้นสำเนาที่ดึงไว้ตอนเปิดแผ่น
  /// จะทับบัตรใบใหม่ด้วยข้อมูลก่อนเลือก
  final VoidCallback? onChanged;

  const _CheckInPassCard({
    super.key,
    required this.booking,
    required this.onOpenBooking,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final bookingRef = textOf(booking['booking_ref'], '-');
    final title = textOf(trip['title'], 'ทริปของคุณ');
    final when = checkInPassWhenLabel(booking);
    final pickup = asMap(booking['pickup_point']);
    final pickupName = textOf(
      pickup['pickup_location'],
      textOf(pickup['region_label']),
    ).trim();
    final pickupTime = textOf(pickup['pickup_time']).trim();
    final passengerCount = asList(booking['passengers']).length;
    final code = textOf(booking['qr_code']).trim();
    final checkedIn = booking['checked_in'] == true;

    final details = <String>[
      departureText(schedule),
      if (passengerCount > 0) 'ผู้เดินทาง $passengerCount คน',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                    height: 1.35,
                  ),
                ),
              ),
              if (when.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    when,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            details.join(' · '),
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText(context),
              height: 1.45,
            ),
          ),
          if (pickupName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: AppTheme.mutedText(context),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pickupTime.isEmpty
                        ? pickupName
                        : '$pickupName · $pickupTime น.',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mutedText(context),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // บัตรรายคนจากเซิร์ฟเวอร์ — ข้อมูลที่แคชจากแอปรุ่นก่อนยังไม่มี ใช้ QR ใบจองเดิม
          if (_BoardingPasses.available(booking))
            _BoardingPasses(booking: booking, onChanged: onChanged)
          else if (checkedIn)
            _CheckedInCard(
              bookingRef: bookingRef,
              checkedInAt: booking['checked_in_at'],
            )
          else if (code.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                // QR ใหญ่ที่สุดเท่าที่จอพอ (สแกนง่ายกว่ากลางแดด) แต่ไม่เกิน 240
                // กรอบขาวกินขอบข้างละ 14 + เส้นขอบ 1
                final size = (constraints.maxWidth - 30).clamp(120.0, 240.0);
                return Column(
                  children: [
                    Semantics(
                      label: 'QR เช็คอิน ใบจอง $bookingRef',
                      image: true,
                      child: _CheckInQrBox(code: code, size: size, padding: 14),
                    ),
                    const SizedBox(height: 14),
                    _BookingReferencePanel(bookingRef: bookingRef),
                  ],
                );
              },
            )
          else
            Column(
              children: [
                Text(
                  'ใบจองนี้ยังไม่มี QR แจ้งรหัสการจองกับทีมงานได้เลย',
                  textAlign: TextAlign.center,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    color: AppTheme.mutedText(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                _BookingReferencePanel(bookingRef: bookingRef),
              ],
            ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onOpenBooking,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('ดูรายละเอียดการจอง'),
          ),
        ],
      ),
    );
  }
}

class _CheckInPassEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _CheckInPassEmpty({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeTitle,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeLabel,
              color: AppTheme.mutedText(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}
