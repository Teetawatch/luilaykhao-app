import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import 'app_snack.dart';
import 'travel_widgets.dart';

// หารบิลค่าอาหาร — ต่อจากรอบรับออเดอร์ (chat_food_round.dart)
//
// สตาฟจ่ายร้านรวมทีเดียว ใส่ราคาต่อเมนู แต่ละคนเห็นยอดของตัวเองบนการ์ด
// แล้วสแกน QR พร้อมเพย์ของสตาฟจ่ายคืน ยอด/สถานะ/QR คำนวณที่เซิร์ฟเวอร์ทั้งหมด
// (ChatFoodOrderService::presentBill) — ฝั่งนี้แค่วาด

/// พร้อมเพย์/ชื่อบัญชีของสตาฟที่จำไว้ในเครื่อง — หารบิลค่าอาหารกับเก็บเงินหน้างาน
/// ใช้ชุดเดียวกัน สตาฟพิมพ์ครั้งเดียวพอ
const staffPromptPayPrefKey = 'food_bill.promptpay_id';
const staffPayeePrefKey = 'food_bill.payee_name';

int _int(dynamic v) => int.tryParse('$v') ?? 0;

double _num(dynamic v) => double.tryParse('$v') ?? 0;

/// ฿1,250 / ฿62.50 — ไม่มีสตางค์ก็ไม่ต้องโชว์ .00
String baht(dynamic amount) {
  final v = _num(amount);
  final whole = v == v.roundToDouble();
  final fixed = whole ? v.round().toString() : v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '฿$digits${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// ป้ายสถานะการจ่ายของออเดอร์หนึ่ง (null = ไม่ต้องโชว์)
({String label, Color color})? foodPayStatus(
  BuildContext context,
  Map<String, dynamic> order,
) {
  return switch (order['pay_status']) {
    'unpaid' => (label: 'ยังไม่จ่าย', color: AppTheme.warningColor),
    'claimed' => (label: 'แจ้งโอนแล้ว', color: AppTheme.accentColor),
    'paid' => (label: 'จ่ายแล้ว', color: AppTheme.primaryColor),
    'short' => (
      label: 'ขาดอีก ${baht(order['balance'])}',
      color: AppTheme.errorColor,
    ),
    'unpriced' => (label: 'รอราคา', color: AppTheme.mutedText(context)),
    _ => null,
  };
}

/// แถวยอดของฉันบนการ์ด — ยอด + สถานะ + ปุ่มจ่าย
class MyFoodBillRow extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onPay;

  const MyFoodBillRow({super.key, required this.order, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final status = order['pay_status']?.toString();
    final badge = foodPayStatus(context, order);
    if (badge == null) return const SizedBox.shrink();
    final canPay =
        order['promptpay_payload'] != null &&
        (status == 'unpaid' || status == 'short' || status == 'claimed');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.payments_rounded, size: 16, color: badge.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: status == 'unpriced'
                        ? 'ยอดของคุณ: รอทีมงานใส่ราคา'
                        : 'ยอดของคุณ ${baht(order['amount'])}  ',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  if (status != 'unpriced')
                    TextSpan(
                      text: badge.label,
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w800,
                        color: badge.color,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (canPay)
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onPay();
              },
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(
                status == 'claimed' ? 'ดู QR' : 'จ่ายเงิน',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// QR พร้อมเพย์ของยอดที่ค้าง + ปุ่ม "โอนแล้ว" — คืน true/false เมื่อกดแจ้ง/ถอน
///
/// ใช้ร่วมกับ "เก็บเงินหน้างาน" ด้วย — ส่ง [what] เป็นชื่อรายการแทนคำว่าค่าอาหาร
class FoodPaySheet extends StatelessWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> billing;
  final String what;

  const FoodPaySheet({
    super.key,
    required this.order,
    required this.billing,
    this.what = 'ค่าอาหาร',
  });

  @override
  Widget build(BuildContext context) {
    final payload = order['promptpay_payload']?.toString() ?? '';
    final claimed = order['pay_status'] == 'claimed';
    final payee = billing['payee_name']?.toString() ?? '';
    final id = billing['promptpay_id']?.toString() ?? '';

    return BillSheetFrame(
      icon: Icons.qr_code_2_rounded,
      title: 'จ่าย$what ${baht(order['balance'])}',
      subtitle: 'สแกนด้วยแอปธนาคาร ยอดใส่ไว้ให้แล้ว',
      footer: claimed
          ? OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: Text(
                'ยังไม่ได้โอน (ถอนการแจ้ง)',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : PrimaryCTAButton(
              label: 'โอนแล้ว แจ้งทีมงาน',
              icon: Icons.check_rounded,
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, true);
              },
            ),
      children: [
        if (payload.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            [
              if (payee.isNotEmpty) payee,
              if (id.isNotEmpty) 'พร้อมเพย์ $id',
            ].join(' · '),
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
            ),
          ),
        ),
        if (id.isNotEmpty)
          Center(
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: id));
                AppSnack.show(context, 'คัดลอกเลขพร้อมเพย์แล้ว');
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(
                'คัดลอกเลขพร้อมเพย์',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (claimed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'แจ้งโอนแล้ว รอทีมงานเช็กยอดเข้า',
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }
}

/// ผลจากชีตใส่ราคา
class FoodBillDraft {
  final List<Map<String, dynamic>> prices;
  final String? promptPayId;
  final String? payeeName;
  final bool notify;

  const FoodBillDraft({
    required this.prices,
    required this.promptPayId,
    required this.payeeName,
    required this.notify,
  });
}

/// ทีมงานใส่ราคาต่อเมนู + พร้อมเพย์ของตัวเอง ยอดรวมคำนวณสดระหว่างพิมพ์
/// พร้อมเพย์/ชื่อจำไว้ในเครื่อง รอบหน้าไม่ต้องพิมพ์ใหม่
class FoodBillSheet extends StatefulWidget {
  final Map<String, dynamic> round;

  const FoodBillSheet({super.key, required this.round});

  @override
  State<FoodBillSheet> createState() => _FoodBillSheetState();
}

class _FoodBillSheetState extends State<FoodBillSheet> {
  static const _prefId = staffPromptPayPrefKey;
  static const _prefName = staffPayeePrefKey;

  late final List<Map<String, dynamic>> _lines;
  late final List<TextEditingController> _prices;
  final _promptPay = TextEditingController();
  final _payee = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lines = (widget.round['summary'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _prices = [
      for (final l in _lines)
        TextEditingController(
          text: l['price'] == null ? '' : _plain(_num(l['price'])),
        ),
    ];

    final billing = widget.round['billing'] is Map
        ? Map<String, dynamic>.from(widget.round['billing'] as Map)
        : null;
    _promptPay.text = billing?['promptpay_id']?.toString() ?? '';
    _payee.text = billing?['payee_name']?.toString() ?? '';
    if (_promptPay.text.isEmpty) _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        if (_promptPay.text.isEmpty) {
          _promptPay.text = prefs.getString(_prefId) ?? '';
        }
        if (_payee.text.isEmpty) {
          _payee.text = prefs.getString(_prefName) ?? '';
        }
      });
    } catch (_) {
      // ไม่มีค่าจำไว้ก็พิมพ์ใหม่ได้
    }
  }

  Future<void> _remember() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefId, _promptPay.text.trim());
      await prefs.setString(_prefName, _payee.text.trim());
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in _prices) {
      c.dispose();
    }
    _promptPay.dispose();
    _payee.dispose();
    super.dispose();
  }

  String _plain(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

  double get _total {
    var sum = 0.0;
    for (var i = 0; i < _lines.length; i++) {
      final p = double.tryParse(_prices[i].text.trim());
      if (p != null) sum += p * _int(_lines[i]['qty']);
    }
    return sum;
  }

  String get _digits => _promptPay.text.replaceAll(RegExp(r'\D'), '');

  bool get _promptPayValid =>
      _digits.isEmpty ||
      _digits.length == 13 ||
      (_digits.length == 10 && _digits.startsWith('0'));

  bool get _allPriced =>
      _prices.every((c) => double.tryParse(c.text.trim()) != null);

  void _submit(bool notify) {
    HapticFeedback.mediumImpact();
    _remember();
    Navigator.pop(
      context,
      FoodBillDraft(
        prices: [
          for (var i = 0; i < _lines.length; i++)
            if (double.tryParse(_prices[i].text.trim()) != null)
              {
                'name': _lines[i]['name'],
                'price': double.parse(_prices[i].text.trim()),
              },
        ],
        promptPayId: _digits.isEmpty ? null : _digits,
        payeeName: _payee.text.trim().isEmpty ? null : _payee.text.trim(),
        notify: notify,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canNotify = _allPriced && _digits.isNotEmpty && _promptPayValid;

    return BillSheetFrame(
      icon: Icons.receipt_long_rounded,
      title: 'หารบิลค่าอาหาร',
      subtitle: 'ใส่ราคาต่อจาน แต่ละคนเห็นยอดของตัวเองและสแกนจ่ายคืนคุณได้เลย',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryCTAButton(
            label: 'ส่งยอดให้ทุกคน · รวม ${baht(_total)}',
            icon: Icons.send_rounded,
            onPressed: canNotify ? () => _submit(true) : null,
          ),
          TextButton(
            onPressed: _promptPayValid ? () => _submit(false) : null,
            child: Text(
              'บันทึกราคาไว้ก่อน (ยังไม่แจ้ง)',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      children: [
        for (var i = 0; i < _lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_lines[i]['name']}  ×${_lines[i]['qty']}',
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface(context),
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _prices[i],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    textAlign: TextAlign.end,
                    onChanged: (_) => setState(() {}),
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: billFieldDecoration(context, 'บาท/จาน'),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const BillSheetLabel('รับเงินคืนทาง'),
        TextField(
          controller: _promptPay,
          keyboardType: TextInputType.phone,
          maxLength: 20,
          onChanged: (_) => setState(() {}),
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w700,
          ),
          decoration:
              billFieldDecoration(
                context,
                'พร้อมเพย์ (เบอร์มือถือ / เลข 13 หลัก)',
              ).copyWith(
                errorText: _promptPayValid
                    ? null
                    : 'เบอร์ 10 หลัก หรือเลข 13 หลัก',
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _payee,
          maxLength: 80,
          style: appFont(fontSize: AppText.sizeBody),
          decoration: billFieldDecoration(
            context,
            'ชื่อบัญชี (ให้ลูกทริปเช็กก่อนโอน)',
          ),
        ),
        if (!_allPriced)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'ใส่ราคาให้ครบทุกเมนูก่อนส่งยอด — คนที่มีเมนูไม่มีราคาจะยังจ่ายไม่ได้',
              style: appFont(
                fontSize: AppText.sizeCaption,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
      ],
    );
  }
}

// ── ชิ้นส่วนร่วม ───────────────────────────────────────────────────────────

InputDecoration billFieldDecoration(BuildContext context, String hint) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
    borderSide: BorderSide(color: AppTheme.border(context)),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: appFont(
      fontSize: AppText.sizeLabel,
      fontWeight: FontWeight.w500,
      color: AppTheme.mutedText(context),
    ),
    isDense: true,
    filled: true,
    fillColor: AppTheme.subtleSurface(context),
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: border,
    enabledBorder: border,
  );
}

class BillSheetLabel extends StatelessWidget {
  final String label;

  const BillSheetLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w800,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}

class BillSheetFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  const BillSheetFrame({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.mutedText(context).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: appFont(
                          fontSize: AppText.sizeSubtitle,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    subtitle!,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                      height: 1.4,
                    ),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  children: children,
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
