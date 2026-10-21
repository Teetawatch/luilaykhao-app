import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import 'chat_food_bill.dart'
    show baht, staffPayeePrefKey, staffPromptPayPrefKey;
import 'chat_rest_stop.dart'
    show RestStopSheetFrame, RestStopSheetLabel, restStopFieldDecoration;
import 'confirm_dialog.dart';
import 'travel_widgets.dart';

// ฝากของลูกหาบ
//
// payload (porter) มาจาก ChatPorterService::present() — กระเป๋าทุกใบพร้อมเลขป้าย
// น้ำหนัก ค่าฝาก และเจ้าของ (เปิดเผยได้ เหมือนรายการค่าอาหาร) ยอดเงินไปจบที่การ์ด
// "เก็บเงินหน้างาน" ใบที่ระบบสร้างให้ตอนทีมงานกดส่งยอด (collection_message_id)
// "mine" = คนที่ฉันฝากแทนได้ มาตอนโหลดห้อง/ตอบกลับการกด (broadcast ไม่มี)

List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

int _int(dynamic v) => int.tryParse('$v') ?? 0;

double? _num(dynamic v) => double.tryParse('${v ?? ''}');

/// "8 กก." / "6.5 กก." / "ยังไม่ชั่ง"
String porterKg(dynamic kg) {
  final v = _num(kg);
  if (v == null) return 'ยังไม่ชั่ง';
  return '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString()} กก.';
}

/// ฝากได้ไม่เกินกี่ใบต่อคน — ตรงกับ ChatPorterRound::MAX_BAGS_PER_PASSENGER
const porterMaxBagsPerPassenger = 5;

/// น้ำหนักสูงสุดต่อใบ — ตรงกับ ChatPorterRound::MAX_WEIGHT_KG
const porterMaxKg = 60.0;

/// การ์ดในบับเบิลแชท — เรต, ฝาก/ชั่ง/คืนแล้วกี่ใบ และกระเป๋าของฉัน
class ChatPorterCard extends StatelessWidget {
  final Map<String, dynamic> porter;
  final int? myUserId;
  final bool canManage;
  final VoidCallback onRegister;
  final VoidCallback onOpen;

  const ChatPorterCard({
    super.key,
    required this.porter,
    required this.myUserId,
    required this.canManage,
    required this.onRegister,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = porter;
    final closed = p['is_closed'] == true;
    final bags = _maps(p['bags']);
    final myBags = bags
        .where((b) => int.tryParse('${b['user_id']}') == myUserId)
        .toList();
    final mine = _maps(p['mine']);
    final hasMine = p['mine'] is List;
    final muted = AppTheme.mutedText(context);
    final min = _num(p['min_charge']) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.luggage_rounded,
              size: 17,
              color: closed ? muted : AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p['title']?.toString() ?? 'ฝากของลูกหาบ',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          [
            'กก.ละ ${baht(p['rate_per_kg'])}',
            if (min > 0) 'ขั้นต่ำใบละ ${baht(min)}',
            if (p['round_up'] == true) 'ปัดขึ้นเป็นกิโลเต็ม',
          ].join(' · '),
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          [
            'ฝาก ${_int(p['bag_count'])} ใบ',
            'ชั่งแล้ว ${_int(p['weighed_count'])}',
            if (_int(p['returned_count']) > 0)
              'คืนแล้ว ${_int(p['returned_count'])}',
            if (p['is_billed'] == true) 'ส่งยอดเก็บเงินแล้ว',
            if (closed) 'ปิดรับฝาก',
          ].join(' · '),
          style: appFont(
            fontSize: AppText.sizeLabel,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface(context),
          ),
        ),
        if (myBags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in myBags)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      [
                        '#${b['tag_no']}',
                        if (myBags
                                .map((x) => x['passenger_id'])
                                .toSet()
                                .length >
                            1)
                          '${b['name']}',
                        porterKg(b['weight_kg']),
                        if (b['fee'] != null) baht(b['fee']),
                        if (b['returned'] == true) 'ได้คืนแล้ว',
                      ].join(' · '),
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                        color: b['returned'] == true
                            ? AppTheme.primaryColor
                            : AppTheme.onSurface(context),
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  'เลขป้ายอยู่ที่กระเป๋า เก็บไว้รับคืนนะครับ',
                  style: appFont(fontSize: AppText.sizeCaption, color: muted),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            if (!closed && !canManage && (mine.isNotEmpty || !hasMine)) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onRegister();
                  },
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: Text(
                    'ฝากกระเป๋า',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onOpen();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: AppTheme.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                child: Text(
                  canManage ? 'ชั่ง & รับคืน' : 'ดูกระเป๋า',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── ทีมงานเปิดรับฝาก ──────────────────────────────────────────────────────

class PorterDraft {
  final String? title;
  final double ratePerKg;
  final double minCharge;
  final bool roundUp;
  final String? promptPayId;
  final String? payeeName;

  const PorterDraft({
    this.title,
    required this.ratePerKg,
    required this.minCharge,
    required this.roundUp,
    this.promptPayId,
    this.payeeName,
  });
}

class OpenPorterSheet extends StatefulWidget {
  const OpenPorterSheet({super.key});

  @override
  State<OpenPorterSheet> createState() => _OpenPorterSheetState();
}

class _OpenPorterSheetState extends State<OpenPorterSheet> {
  final _title = TextEditingController();
  final _rate = TextEditingController();
  final _min = TextEditingController();
  final _promptPay = TextEditingController();
  final _payee = TextEditingController();
  bool _roundUp = true;

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _promptPay.text = prefs.getString(staffPromptPayPrefKey) ?? '';
        _payee.text = prefs.getString(staffPayeePrefKey) ?? '';
      });
    } catch (_) {}
  }

  Future<void> _remember() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(staffPromptPayPrefKey, _promptPay.text.trim());
      await prefs.setString(staffPayeePrefKey, _payee.text.trim());
    } catch (_) {}
  }

  @override
  void dispose() {
    _title.dispose();
    _rate.dispose();
    _min.dispose();
    _promptPay.dispose();
    _payee.dispose();
    super.dispose();
  }

  double? get _rateValue => double.tryParse(_rate.text.trim());

  double get _minValue => double.tryParse(_min.text.trim()) ?? 0;

  String get _digits => _promptPay.text.replaceAll(RegExp(r'\D'), '');

  bool get _promptPayValid =>
      _digits.isEmpty ||
      _digits.length == 13 ||
      (_digits.length == 10 && _digits.startsWith('0'));

  bool get _canSubmit =>
      (_rateValue ?? 0) >= 1 &&
      (_rateValue ?? 0) <= 1000 &&
      _minValue >= 0 &&
      _minValue <= 1000 &&
      _promptPayValid;

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.luggage_rounded,
      title: 'ฝากของลูกหาบ',
      subtitle:
          'ลูกทริปกด "ฝากกระเป๋า" คุณชั่งแล้วได้เลขป้ายต่อใบ ระบบคิดยอดให้ '
          'ชั่งครบแล้วกดส่งยอดเข้าการ์ดเก็บเงิน (QR + แนบสลิป) ได้ทันที',
      footer: PrimaryCTAButton(
        label: _canSubmit
            ? 'เปิดรับฝาก · กก.ละ ${baht(_rateValue)}'
            : (_promptPayValid ? 'ใส่ราคาต่อกิโล' : 'พร้อมเพย์ไม่ถูกต้อง'),
        icon: Icons.campaign_rounded,
        onPressed: !_canSubmit
            ? null
            : () {
                HapticFeedback.mediumImpact();
                _remember();
                Navigator.pop(
                  context,
                  PorterDraft(
                    title: _title.text.trim().isEmpty
                        ? null
                        : _title.text.trim(),
                    ratePerKg: _rateValue!,
                    minCharge: _minValue,
                    roundUp: _roundUp,
                    promptPayId: _digits.isEmpty ? null : _digits,
                    payeeName: _payee.text.trim().isEmpty
                        ? null
                        : _payee.text.trim(),
                  ),
                );
              },
      ),
      children: [
        const RestStopSheetLabel('ชื่อรายการ (ไม่บังคับ)'),
        TextField(
          controller: _title,
          maxLength: 120,
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w600,
          ),
          decoration: restStopFieldDecoration(
            context,
            'เช่น ลูกหาบขึ้นภูกระดึง',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RestStopSheetLabel('บาทต่อกิโล'),
                  TextField(
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: restStopFieldDecoration(context, 'เช่น 30'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RestStopSheetLabel('ขั้นต่ำต่อใบ'),
                  TextField(
                    controller: _min,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: restStopFieldDecoration(context, 'ไม่มี = 0'),
                  ),
                ],
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _roundUp,
          onChanged: (v) => setState(() => _roundUp = v),
          title: Text(
            'ปัดน้ำหนักขึ้นเป็นกิโลเต็มต่อใบ',
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            'เช่น 6.2 กก. คิด 7 กก. ตามที่ลูกหาบคิดจริง',
            style: appFont(
              fontSize: AppText.sizeCaption,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
        const RestStopSheetLabel('พร้อมเพย์รับเงิน (ไม่ใส่ = เก็บเงินสด)'),
        TextField(
          controller: _promptPay,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w600,
          ),
          decoration: restStopFieldDecoration(
            context,
            'เบอร์มือถือหรือเลขบัตร 13 หลัก',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _payee,
          maxLength: 80,
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w600,
          ),
          decoration: restStopFieldDecoration(context, 'ชื่อบัญชี (ไม่บังคับ)'),
        ),
      ],
    );
  }
}

// ── ลูกทริปฝากกระเป๋า ────────────────────────────────────────────────────

class PorterRegisterDraft {
  final int passengerId;
  final int count;
  final String? note;
  final double? weightKg;

  const PorterRegisterDraft({
    required this.passengerId,
    required this.count,
    this.note,
    this.weightKg,
  });
}

/// ฝากกี่ใบ ของใคร — [people] = [{id, name}] คนที่ฉันฝากแทนได้ (ทีมงาน = ทุกคน)
/// [withWeight] = ทีมงานชั่งไปพร้อมกัน (ใบเดียว)
class PorterRegisterSheet extends StatefulWidget {
  final List<Map<String, dynamic>> people;
  final Map<int, int> existingBags;
  final bool withWeight;

  const PorterRegisterSheet({
    super.key,
    required this.people,
    this.existingBags = const {},
    this.withWeight = false,
  });

  @override
  State<PorterRegisterSheet> createState() => _PorterRegisterSheetState();
}

class _PorterRegisterSheetState extends State<PorterRegisterSheet> {
  late int? _who = widget.people.length == 1
      ? _int(widget.people.first['id'])
      : null;
  int _count = 1;
  final _note = TextEditingController();
  final _kg = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    _kg.dispose();
    super.dispose();
  }

  int get _room =>
      porterMaxBagsPerPassenger - (widget.existingBags[_who ?? 0] ?? 0);

  double? get _kgValue => double.tryParse(_kg.text.trim());

  bool get _valid =>
      _who != null &&
      _room >= _count &&
      _count >= 1 &&
      (!widget.withWeight ||
          ((_kgValue ?? 0) > 0 && (_kgValue ?? 0) <= porterMaxKg));

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.luggage_rounded,
      title: widget.withWeight ? 'เพิ่มกระเป๋า (ชั่งแล้ว)' : 'ฝากกระเป๋า',
      subtitle: widget.withWeight
          ? 'ใส่น้ำหนักแล้วได้เลขป้ายทันที'
          : 'ลงชื่อไว้ก่อน ทีมงานชั่งแล้วเลขป้ายจะขึ้นในการ์ด',
      footer: PrimaryCTAButton(
        label: _who != null && _room < _count
            ? 'ฝากได้อีก $_room ใบ'
            : (widget.withWeight ? 'เพิ่มกระเป๋า' : 'ฝาก $_count ใบ'),
        icon: Icons.check_rounded,
        onPressed: !_valid
            ? null
            : () {
                HapticFeedback.mediumImpact();
                Navigator.pop(
                  context,
                  PorterRegisterDraft(
                    passengerId: _who!,
                    count: widget.withWeight ? 1 : _count,
                    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                    weightKg: widget.withWeight ? _kgValue : null,
                  ),
                );
              },
      ),
      children: [
        if (widget.people.length > 1) ...[
          const RestStopSheetLabel('ของใคร'),
          for (final p in widget.people)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                _who == _int(p['id'])
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: AppTheme.primaryColor,
              ),
              title: Text(
                p['name']?.toString() ?? '',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () => setState(() => _who = _int(p['id'])),
            ),
          const SizedBox(height: 8),
        ],
        if (widget.withWeight) ...[
          const RestStopSheetLabel('น้ำหนัก (กก.)'),
          TextField(
            controller: _kg,
            autofocus: widget.people.length == 1,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
            ),
            decoration: restStopFieldDecoration(context, 'เช่น 7.5'),
          ),
          const SizedBox(height: 10),
        ] else ...[
          const RestStopSheetLabel('กี่ใบ'),
          Row(
            children: [
              IconButton.outlined(
                onPressed: _count > 1 ? () => setState(() => _count--) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '$_count',
                  style: appFont(
                    fontSize: AppText.sizeH1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton.outlined(
                onPressed: _count < porterMaxBagsPerPassenger
                    ? () => setState(() => _count++)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        const RestStopSheetLabel('จุดสังเกต (ไม่บังคับ)'),
        TextField(
          controller: _note,
          maxLength: 80,
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w600,
          ),
          decoration: restStopFieldDecoration(
            context,
            'เช่น เป้สีแดง / ถุงนอนสีเทา',
          ),
        ),
      ],
    );
  }
}

// ── รายการกระเป๋า ────────────────────────────────────────────────────────

/// กระเป๋าทุกใบตามเลขป้าย — ทีมงานแตะเพื่อชั่ง/เอาออก, ติ๊กรับคืน, ส่งยอดเก็บเงิน
/// ลูกทริปเห็นทั้งหมด ติ๊กรับคืน/เอาใบที่ยังไม่ชั่งของตัวเองออกได้
class PorterManageSheet extends StatelessWidget {
  final ValueListenable<Map<String, dynamic>?> porter;
  final bool canManage;
  final int? myUserId;
  final Future<void> Function(int bagId, double? kg) onWeigh;
  final Future<void> Function(int bagId) onRemove;
  final Future<void> Function(List<int> bagIds, bool returned) onReturned;
  final Future<void> Function() onAddForSomeone;
  final Future<void> Function() onBill;
  final Future<void> Function(bool closed) onSetClosed;
  final VoidCallback onOpenCollection;

  const PorterManageSheet({
    super.key,
    required this.porter,
    required this.canManage,
    required this.myUserId,
    required this.onWeigh,
    required this.onRemove,
    required this.onReturned,
    required this.onAddForSomeone,
    required this.onBill,
    required this.onSetClosed,
    required this.onOpenCollection,
  });

  Future<void> _editBag(
    BuildContext context,
    Map<String, dynamic> bag,
    bool paid,
  ) async {
    final controller = TextEditingController(
      text: _num(bag['weight_kg'])?.toString() ?? '',
    );
    final result = await showDialog<({bool remove, double? kg})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '#${bag['tag_no']} · ${bag['name']}',
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: paid
            ? Text(
                'คนนี้จ่ายค่าลูกหาบแล้ว — ยกเลิกสถานะจ่ายในการ์ดเก็บเงินก่อนแก้กระเป๋า',
                style: appFont(fontSize: AppText.sizeBody),
              )
            : TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                ),
                decoration: restStopFieldDecoration(
                  dialogContext,
                  'น้ำหนัก (กก.)',
                ),
              ),
        actions: [
          if (!paid && bag['returned'] != true)
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (remove: true, kg: null)),
              child: Text(
                'เอาออก',
                style: appFont(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('ปิด', style: appFont(fontWeight: FontWeight.w700)),
          ),
          if (!paid)
            FilledButton(
              onPressed: () {
                final kg = double.tryParse(controller.text.trim());
                if (kg == null || kg <= 0 || kg > porterMaxKg) return;
                Navigator.pop(dialogContext, (remove: false, kg: kg));
              },
              child: Text(
                'บันทึก',
                style: appFont(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    if (result.remove) {
      if (!context.mounted) return;
      final ok = await showConfirmDialog(
        context,
        title: 'เอากระเป๋า #${bag['tag_no']} ออก?',
        tone: ConfirmTone.danger,
        icon: Icons.delete_outline_rounded,
        confirmLabel: 'เอาออก',
      );
      if (ok) await onRemove(_int(bag['id']));
      return;
    }
    await onWeigh(_int(bag['id']), result.kg);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: porter,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        return _buildFor(context, data);
      },
    );
  }

  Widget _buildFor(BuildContext context, Map<String, dynamic> p) {
    final closed = p['is_closed'] == true;
    final billed = p['is_billed'] == true;
    final bags = _maps(p['bags']);
    final paidIds = (p['paid_passenger_ids'] as List? ?? const [])
        .map(_int)
        .toSet();
    final unweighed = bags.where((b) => b['weight_kg'] == null).length;
    final muted = AppTheme.mutedText(context);

    bool isMine(Map<String, dynamic> b) =>
        int.tryParse('${b['user_id']}') == myUserId;

    return RestStopSheetFrame(
      icon: Icons.luggage_rounded,
      title: p['title']?.toString() ?? 'ฝากของลูกหาบ',
      subtitle: [
        '${bags.length} ใบ',
        'รวม ${porterKg(p['total_kg'])}',
        baht(p['total_fee']),
        'คืนแล้ว ${_int(p['returned_count'])}/${bags.length}',
      ].join(' · '),
      footer: canManage
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (billed)
                  OutlinedButton.icon(
                    onPressed: onOpenCollection,
                    icon: const Icon(Icons.savings_rounded, size: 18),
                    label: Text(
                      'ดูการ์ดเก็บเงิน',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                  )
                else
                  PrimaryCTAButton(
                    label: bags.isEmpty
                        ? 'ยังไม่มีกระเป๋า'
                        : (unweighed > 0
                              ? 'ชั่งให้ครบก่อน (เหลือ $unweighed ใบ)'
                              : 'ส่งยอดเก็บเงิน · ${baht(p['total_fee'])}'),
                    icon: Icons.savings_rounded,
                    onPressed: bags.isEmpty || unweighed > 0
                        ? null
                        : () async {
                            final ok = await showConfirmDialog(
                              context,
                              title: 'ส่งยอดเข้าการ์ดเก็บเงิน?',
                              message:
                                  'ทุกคนจะได้การ์ดเก็บเงินพร้อม QR ยอดของตัวเอง ชั่งเพิ่มทีหลังยอดอัปเดตเอง',
                              icon: Icons.savings_outlined,
                              confirmLabel: 'ส่งยอด',
                            );
                            if (ok) await onBill();
                          },
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onAddForSomeone,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'เพิ่มกระเป๋า',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onSetClosed(!closed),
                        icon: Icon(
                          closed ? Icons.lock_open_rounded : Icons.lock_rounded,
                          size: 18,
                        ),
                        label: Text(
                          closed ? 'เปิดรับฝาก' : 'ปิดรับฝาก',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      children: [
        if (bags.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'ยังไม่มีใครฝากกระเป๋า',
              style: appFont(fontSize: AppText.sizeBody, color: muted),
            ),
          ),
        if (canManage && unweighed > 0)
          RestStopSheetLabel(
            'ยังไม่ชั่ง $unweighed ใบ — แตะกระเป๋าเพื่อใส่น้ำหนัก',
          ),
        for (final b in bags)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            onTap: canManage
                ? () => _editBag(
                    context,
                    b,
                    paidIds.contains(_int(b['passenger_id'])),
                  )
                : null,
            leading: Container(
              width: 42,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              ),
              child: Text(
                '#${b['tag_no']}',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            title: Text(
              [
                b['name']?.toString() ?? '',
                if ((b['note']?.toString() ?? '').isNotEmpty)
                  b['note'].toString(),
              ].join(' · '),
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
            subtitle: Text(
              [
                porterKg(b['weight_kg']),
                if (b['fee'] != null) baht(b['fee']),
                if (paidIds.contains(_int(b['passenger_id']))) 'จ่ายแล้ว',
              ].join(' · '),
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: b['weight_kg'] == null ? AppTheme.warningColor : muted,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!canManage &&
                    isMine(b) &&
                    b['weight_kg'] == null &&
                    !closed)
                  IconButton(
                    tooltip: 'เอาออก',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => onRemove(_int(b['id'])),
                  ),
                if (canManage || isMine(b))
                  Checkbox(
                    value: b['returned'] == true,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      onReturned([_int(b['id'])], v == true);
                    },
                  ),
              ],
            ),
          ),
        if (bags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'ช่องติ๊กขวามือ = ได้กระเป๋าคืนแล้ว',
              style: appFont(fontSize: AppText.sizeCaption, color: muted),
            ),
          ),
      ],
    );
  }
}
