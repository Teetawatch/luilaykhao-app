part of 'payment_screen.dart';

/// แอปธนาคารที่ Beam รองรับ — โชว์เฉพาะตัวที่หลังบ้านเปิดรับ (payment_gateway.methods)
const List<({String type, String label, String bank})> _beamBankApps = [
  (type: 'KPLUS', label: 'K PLUS', bank: 'กสิกรไทย'),
  (type: 'SCB_EASY', label: 'SCB EASY', bank: 'ไทยพาณิชย์'),
  (type: 'KRUNGSRI_APP', label: 'Krungsri', bank: 'กรุงศรีอยุธยา'),
  (type: 'BANGKOK_BANK_APP', label: 'Bualuang', bank: 'กรุงเทพ'),
];

/// เครื่องหมายประจำแอปธนาคาร: สีแบรนด์ + อักษรย่อ
///
/// ไม่ใช่โลโก้จริงของธนาคาร — ไฟล์โลโก้เป็นเครื่องหมายการค้าที่ต้องได้รับอนุญาต
/// ก่อนนำมาแนบในแอป ถ้าวันหนึ่งได้ไฟล์มาแล้ว เปลี่ยนเฉพาะ [_BankMark] จุดเดียว
({Color color, Color onColor, String initials}) _bankMark(String type) {
  return switch (type) {
    'KPLUS' => (
      color: const Color(0xFF138F2D),
      onColor: Colors.white,
      initials: 'K+',
    ),
    'SCB_EASY' => (
      color: const Color(0xFF4E2A84),
      onColor: Colors.white,
      initials: 'SCB',
    ),
    'KRUNGSRI_APP' => (
      color: const Color(0xFFFEC10E),
      onColor: const Color(0xFF4A3000),
      initials: 'KS',
    ),
    'BANGKOK_BANK_APP' => (
      color: const Color(0xFF1E4598),
      onColor: Colors.white,
      initials: 'BBL',
    ),
    _ => (
      color: AppTheme.accentColor,
      onColor: Colors.white,
      initials: '฿',
    ),
  };
}

class _BankMark extends StatelessWidget {
  final String type;

  const _BankMark({required this.type});

  @override
  Widget build(BuildContext context) {
    final mark = _bankMark(type);

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: mark.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        mark.initials,
        style: appFont(
          color: mark.onColor,
          fontSize: AppText.sizeCaption,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// จ่ายผ่านเกตเวย์ (Beam) — QR ที่เงินเข้าแล้วระบบรู้เอง ไม่ต้องแนบสลิป
///
/// แทนที่ทั้งชุด _PaymentMethodSection + _SlipUploadSection + _TransferTimeSection
/// + _SubmitButton ของโหมดโอนเอง เพราะในโหมดนี้ไม่มีอะไรให้ลูกค้า "ยืนยัน" — คน
/// ยืนยันคือ webhook ที่เข้าหลังบ้าน หน้าจอนี้แค่โชว์ QR แล้วรอ
///
/// วิดเจ็ตนี้เป็นเจ้าของ timer สองตัว (นับถอยหลัง + poll) และเคลียร์ทั้งคู่ใน
/// dispose() — ตั้ง Timer.periodic ใน State แล้วลืม cancel คือ leak ที่เงียบที่สุด
class _BeamPaymentSection extends StatefulWidget {
  final String bookingRef;

  /// full / deposit / split / installment / installment_due / balance / split_share
  final String purpose;
  final num amount;

  /// แถวปลายทางของ purpose ที่ชี้เฉพาะเจาะจง (ส่วนแบ่งเพื่อน หรือ งวดที่ 2+)
  final int? shareId;
  final int? installmentId;
  final int? installmentCount;

  /// ช่องทางที่หลังบ้านเปิดรับ (จาก booking.payment_gateway.methods)
  final List<String> methods;

  /// เงินเข้าแล้ว
  final ValueChanged<Map<String, dynamic>> onPaid;

  const _BeamPaymentSection({
    super.key,
    required this.bookingRef,
    required this.purpose,
    required this.amount,
    required this.methods,
    required this.onPaid,
    this.shareId,
    this.installmentId,
    this.installmentCount,
  });

  @override
  State<_BeamPaymentSection> createState() => _BeamPaymentSectionState();
}

class _BeamPaymentSectionState extends State<_BeamPaymentSection>
    with WidgetsBindingObserver {
  /// ถามถี่แค่ไหน — ตอนยังไม่จ่าย กับ ตอนจ่ายแล้วและนั่งรออยู่หน้าจอ
  static const _pollIdle = Duration(seconds: 3);
  static const _pollSettling = Duration(seconds: 2);

  /// รอเกินกี่วินาทีถึงจะเปลี่ยนคำพูดเป็น "ช้ากว่าปกติ" แทนที่จะปล่อยให้ลูกค้าเดาเอง
  static const _slowAfterSeconds = 45;

  Map<String, dynamic>? _payment;
  Uint8List? _qrBytes;
  bool _loading = false;
  String? _error;
  DateTime? _expiresAt;
  Duration _timeLeft = Duration.zero;

  /// จ่ายไปแล้วแต่ webhook ยังไม่มา — ช่วงที่หน้าจอเคยนิ่งสนิทจนลูกค้าไม่แน่ใจว่า
  /// ต้องจ่ายซ้ำไหม จับแยกไว้เพื่อให้มีอะไรให้ดู และเพื่อเร่งจังหวะถาม
  bool _settling = false;
  int _settlingSeconds = 0;

  Timer? _tickTimer;
  Timer? _pollTimer;

  // ระหว่างรอผล ไม่นับว่าหมดอายุ — เงินที่จ่ายวินาทีสุดท้ายก็ยังเข้าได้ ถ้าสลับเป็น
  // "QR หมดอายุแล้ว" ตอนนั้น คนที่จ่ายไปแล้วจะกดออกใบใหม่แล้วจ่ายซ้ำ
  bool get _expired =>
      _payment != null && _timeLeft <= Duration.zero && !_settling;

  bool get _slow => _settling && _settlingSeconds >= _slowAfterSeconds;

  List<({String type, String label, String bank})> get _availableBankApps =>
      _beamBankApps.where((a) => widget.methods.contains(a.type)).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createCharge('QR_PROMPT_PAY');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    super.dispose();
  }

  /// กลับเข้าแอปมา = เพิ่งออกจากแอปธนาคาร/แอปสแกน QR — ถามผลทันที ไม่ต้องรอครบรอบ
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _payment != null) {
      _pollStatus();
    }
  }

  void _stopTimers() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _createCharge(String methodType) async {
    if (_loading) return;

    _stopTimers();
    setState(() {
      _loading = true;
      _error = null;
      _payment = null;
      _qrBytes = null;
      _settling = false;
      _settlingSeconds = 0;
    });

    try {
      final payment = await context.read<AppProvider>().createBeamCharge(
        bookingRef: widget.bookingRef,
        purpose: widget.purpose,
        paymentMethodType: methodType,
        installmentCount: widget.installmentCount,
        shareId: widget.shareId,
        installmentId: widget.installmentId,
        deviceType: Platform.isIOS ? 'IOS' : 'ANDROID',
      );
      if (!mounted) return;

      final qr = textOf(payment['qr_image_base64']);
      setState(() {
        _payment = payment;
        _qrBytes = qr.isEmpty ? null : base64Decode(qr);
        _expiresAt = DateTime.tryParse(
          textOf(payment['expires_at']),
        )?.toLocal();
        _loading = false;
      });

      _startWatching();

      // แอปธนาคารตอบเป็นลิงก์ ไม่ใช่ QR — เปิดออกไปเลย แล้วกลับมาผ่าน returnUrl
      //
      // ใบแบบนี้ไม่มี QR ให้แสดง ถ้าไม่เข้าโหมดรอผลตรงนี้ คนที่กลับเข้าแอปมาจะเจอ
      // กล่องเปล่าที่เขียนว่า "ยังสร้าง QR ไม่ได้" ทั้งที่เพิ่งจ่ายเงินสำเร็จมาหมาดๆ
      final redirect = textOf(payment['redirect_url']);
      if (redirect.isNotEmpty) {
        _markSettling();
        await launchUrl(
          Uri.parse(redirect),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _startWatching() {
    _tick();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _restartPolling(_settling ? _pollSettling : _pollIdle);
  }

  void _restartPolling(Duration every) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(every, (_) => _pollStatus());
  }

  /// ลูกค้าจ่ายแล้ว (กดปุ่มบอกเอง หรือถูกส่งออกไปแอปธนาคาร) — เปลี่ยนเป็นโหมดรอผล
  void _markSettling() {
    if (_settling || _payment == null) return;

    setState(() {
      _settling = true;
      _settlingSeconds = 0;
    });
    _restartPolling(_pollSettling);
    _pollStatus();
  }

  /// "ยังไม่ได้จ่าย" — กดปุ่มไปก่อนเวลา พากลับไปหน้า QR ตามเดิม
  void _resumeWaiting() {
    if (!_settling) return;

    setState(() {
      _settling = false;
      _settlingSeconds = 0;
    });
    _restartPolling(_pollIdle);
  }

  void _tick() {
    if (!mounted) return;
    final expiry = _expiresAt;
    final left = expiry == null
        ? Duration.zero
        : expiry.difference(DateTime.now());
    setState(() {
      _timeLeft = left.isNegative ? Duration.zero : left;
      if (_settling) _settlingSeconds++;
    });
    // QR ตายแล้วก็ไม่ต้องถามต่อ ลูกค้าต้องกดออกใบใหม่อยู่ดี — ยกเว้นตอนที่ลูกค้า
    // บอกว่าจ่ายไปแล้ว ตอนนั้นยังต้องรอคำตอบว่าเงินใบนั้นเข้าหรือไม่
    if (_timeLeft <= Duration.zero && !_settling) _stopTimers();
  }

  Future<void> _pollStatus() async {
    final id = int.tryParse(textOf(_payment?['payment_id']));
    if (id == null) return;

    try {
      final fresh = await context.read<AppProvider>().beamPaymentStatus(
        id,
        // จ่ายแล้วและกำลังนั่งรอ — ให้เซิร์ฟเวอร์ถาม Beam ตรงๆ ไม่ใช่รอแต่ webhook
        sync: _settling,
      );
      if (!mounted) return;

      final status = textOf(fresh['status']);
      // เชื่อสถานะของ "ใบชำระเงินใบนี้" เท่านั้น — ห้ามดูสถานะการจอง เพราะยอดคงเหลือ
      // งวดที่ 2+ และส่วนแบ่งกลุ่ม จ่ายบนการจองที่ confirmed ไปตั้งแต่ก่อนเปิดหน้านี้
      // แล้ว ถ้าดูจากตรงนั้นหน้าจอจะเด้งว่า "จ่ายสำเร็จ" ตั้งแต่ poll รอบแรกทั้งที่ยัง
      // ไม่มีเงินเข้า (webhook เป็นคนตั้ง status = succeeded ก่อนแตะการจองเสมอ)
      if (status == 'succeeded') {
        _stopTimers();
        widget.onPaid(fresh);
      } else if (status == 'failed' || status == 'expired') {
        _stopTimers();
        setState(() {
          _expiresAt = DateTime.now();
          _settling = false;
        });
      }
    } catch (_) {
      // เน็ตสะดุดรอบเดียวไม่ใช่เรื่องต้องแจ้งลูกค้า รอบหน้าอีก 3 วิค่อยถามใหม่
    }
  }

  String get _countdownText {
    final m = _timeLeft.inMinutes.toString().padLeft(2, '0');
    final s = (_timeLeft.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // ระหว่างรอผล เก็บ QR และปุ่มแอปธนาคารไปให้หมด เหลือแค่สถานะเดียวบนหน้าจอ —
    // เปิดทางให้กดจ่ายใบใหม่ตอนที่ใบเก่ากำลังจะเข้า คือวิธีทำให้ลูกค้าจ่ายซ้ำ
    if (_settling) {
      return _SectionCard(
        child: _BeamSettlingView(
          seconds: _settlingSeconds,
          slow: _slow,
          amount: widget.amount,
          onNotPaidYet: _resumeWaiting,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionTitle(
                icon: Icons.qr_code_2_rounded,
                title: 'สแกนจ่ายด้วยแอปธนาคาร',
              ),
              const SizedBox(height: 6),
              Text(
                'จ่ายแล้วระบบยืนยันให้อัตโนมัติ ไม่ต้องแนบสลิปและไม่ต้องรอเจ้าหน้าที่ตรวจ',
                style: appFont(
                  color: AppTheme.mutedText(context),
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Center(child: _buildQrArea(context)),
              const SizedBox(height: 14),
              _buildAmountRow(context),
              // เราไม่มีทางรู้เองว่าลูกค้าสแกนไปแล้วหรือยัง ปุ่มนี้คือสัญญาณเดียวที่บอกได้
              if (_payment != null && !_expired) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _markSettling();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.task_alt_rounded, size: 18),
                  label: Text(
                    'จ่ายเงินแล้ว · ตรวจสอบให้ฉัน',
                    style: appFont(
                      color: Colors.white,
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: appFont(
                    color: AppTheme.dangerColor,
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_availableBankApps.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildBankApps(context),
        ],
      ],
    );
  }

  Widget _buildQrArea(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: switch (true) {
        _ when _loading => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.4, color: _accent),
        ),
        _ when _expired => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              size: 44,
              color: Colors.black.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 10),
            Text(
              'QR หมดอายุแล้ว',
              style: appFont(
                color: Colors.black87,
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _createCharge('QR_PROMPT_PAY');
              },
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              child: Text(
                'สร้าง QR ใหม่',
                style: appFont(
                  color: Colors.white,
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        _ when _qrBytes != null => Image.memory(
          _qrBytes!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
        _ => Center(
          child: Text(
            'ยังสร้าง QR ไม่ได้',
            style: appFont(
              color: Colors.black54,
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      },
    );
  }

  Widget _buildAmountRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ยอดที่ต้องชำระ',
                  style: appFont(
                    color: AppTheme.mutedText(context),
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  money(widget.amount),
                  style: appFont(
                    color: _accent,
                    fontSize: AppText.sizeTitle,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (_payment != null && !_expired)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'รอชำระ · $_countdownText',
                  style: appFont(
                    color: AppTheme.onSurface(context),
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBankApps(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            icon: Icons.smartphone_rounded,
            title: 'หรือเปิดแอปธนาคารโดยตรง',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _availableBankApps.map((app) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 32 - 36 - 10) / 2,
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          _createCharge(app.type);
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    side: BorderSide(color: AppTheme.border(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Row(
                    children: [
                      _BankMark(type: app.type),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                color: AppTheme.onSurface(context),
                                fontSize: AppText.sizeBody,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              app.bank,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                color: AppTheme.mutedText(context),
                                fontSize: AppText.sizeCaption,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// หน้าจอช่วง "จ่ายแล้ว กำลังรอผล"
///
/// ช่วงนี้ระบบทำงานอยู่จริงแต่ไม่มีอะไรให้ลูกค้าเห็นเลย — คนที่เพิ่งโอนเงินหลักพัน
/// แล้วเจอหน้าจอนิ่งสนิทจะสรุปเองว่าจ่ายไม่ผ่าน แล้วไปจ่ายซ้ำอีกใบ ทุกอย่างในนี้จึงมี
/// หน้าที่เดียว: ทำให้เห็นว่ายังทำงานอยู่ และย้ำว่าไม่ต้องจ่ายซ้ำ
class _BeamSettlingView extends StatelessWidget {
  final int seconds;
  final bool slow;
  final num amount;
  final VoidCallback onNotPaidYet;

  const _BeamSettlingView({
    required this.seconds,
    required this.slow,
    required this.amount,
    required this.onNotPaidYet,
  });

  String get _elapsedText => seconds < 60
      ? '$seconds วินาที'
      : '${seconds ~/ 60} นาที ${(seconds % 60).toString().padLeft(2, '0')} วินาที';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _SettlingOrb()),
        const SizedBox(height: 16),
        Text(
          slow
              ? 'ยังตรวจสอบอยู่ ใช้เวลานานกว่าปกติเล็กน้อย'
              : 'กำลังตรวจสอบการชำระเงิน',
          textAlign: TextAlign.center,
          style: appFont(
            color: AppTheme.onSurface(context),
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          slow
              ? 'ธนาคารบางแห่งส่งผลช้ากว่าปกติ ระบบยังตามผลให้อยู่ หากเงินถูกตัดไปแล้วเราจะยืนยันให้เองเมื่อได้รับผล ไม่ต้องจ่ายซ้ำ'
              : 'ระบบกำลังรอผลจากธนาคาร ปกติใช้เวลาไม่เกินครึ่งนาที อย่าเพิ่งปิดหน้านี้และไม่ต้องจ่ายซ้ำ',
          textAlign: TextAlign.center,
          style: appFont(
            color: AppTheme.mutedText(context),
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),

        // "ตอนนี้อยู่ตรงไหนของกระบวนการ" — สิ่งที่ลูกค้าไม่เคยเห็นมาก่อนในช่วงนี้
        const _SettlingStep(
          state: _StepState.done,
          label: 'ส่งรายการชำระเงินให้ธนาคารแล้ว',
        ),
        const SizedBox(height: 8),
        const _SettlingStep(
          state: _StepState.now,
          label: 'รอธนาคารยืนยันว่าเงินเข้า',
        ),
        const SizedBox(height: 8),
        const _SettlingStep(
          state: _StepState.todo,
          label: 'บันทึกยอดที่ชำระให้อัตโนมัติ',
        ),

        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ยอดที่รอการยืนยัน',
                  style: appFont(
                    color: AppTheme.mutedText(context),
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                money(amount),
                style: appFont(
                  color: _accent,
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        Text(
          'รอมาแล้ว $_elapsedText',
          textAlign: TextAlign.center,
          style: appFont(
            color: AppTheme.mutedText(context),
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            onNotPaidYet();
          },
          child: Text(
            'ยังไม่ได้จ่าย · กลับไปสแกน QR',
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// วงคลื่นสองชั้นเหลื่อมเวลากัน + วงหมุน — บอกว่า "ยังทำงานอยู่" โดยไม่ต้องมีข้อความ
class _SettlingOrb extends StatefulWidget {
  const _SettlingOrb();

  @override
  State<_SettlingOrb> createState() => _SettlingOrbState();
}

class _SettlingOrbState extends State<_SettlingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              _wave(_controller.value),
              _wave((_controller.value + 0.5) % 1),
              child!,
            ],
          );
        },
        child: const SizedBox(
          width: 62,
          height: 62,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 3, color: _accent),
              Icon(Icons.account_balance_rounded, color: _accent, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wave(double t) {
    return Container(
      width: 62 + (34 * t),
      height: 62 + (34 * t),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _accent.withValues(alpha: 0.14 * (1 - t)),
      ),
    );
  }
}

enum _StepState { done, now, todo }

class _SettlingStep extends StatelessWidget {
  final _StepState state;
  final String label;

  const _SettlingStep({required this.state, required this.label});

  @override
  Widget build(BuildContext context) {
    final done = state == _StepState.done;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: done
            ? _accent.withValues(alpha: AppTheme.isDark(context) ? 0.16 : 0.08)
            : AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: switch (state) {
              _StepState.done => Container(
                decoration: const BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              _StepState.now => const Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: _accent,
                ),
              ),
              _StepState.todo => Container(
                decoration: BoxDecoration(
                  color: AppTheme.border(context),
                  shape: BoxShape.circle,
                ),
              ),
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: appFont(
                color: state == _StepState.todo
                    ? AppTheme.mutedText(context)
                    : AppTheme.onSurface(context),
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
