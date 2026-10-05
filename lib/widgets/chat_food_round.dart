import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'app_snack.dart';
import 'chat_food_bill.dart';
import 'travel_widgets.dart';

// รับออเดอร์อาหารในห้องแชททริป — แวะร้านตามสั่งขากลับ แต่ละคนพิมพ์เมนูของตัวเอง
// ระหว่างนั่งรถ แล้วน้องสตาฟถือรายการรวมไปสั่งร้านทีเดียว
//
// payload ของรอบ (food_round) มาจาก ChatFoodOrderService::present() ฝั่งเซิร์ฟเวอร์
// และไม่ผูกกับผู้ดู — หา "ออเดอร์ของฉัน" จาก user_id เอง เหมือนการ์ดโพล

const _maxItems = 10;
const _maxQty = 20;

List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

int _int(dynamic v) => int.tryParse('$v') ?? 0;

/// ออเดอร์ของผู้ใช้คนนี้ในรอบ (null = ยังไม่ได้สั่ง)
Map<String, dynamic>? myFoodOrder(Map<String, dynamic> round, int? myUserId) {
  if (myUserId == null) return null;
  for (final o in _maps(round['orders'])) {
    if (int.tryParse('${o['user_id']}') == myUserId) return o;
  }
  return null;
}

String _itemsText(List<Map<String, dynamic>> items) => items
    .map(
      (i) => _int(i['qty']) > 1 ? '${i['name']} ×${i['qty']}' : '${i['name']}',
    )
    .join(', ');

/// ปิดรับแล้ว — รวมกรณีเลยเวลาปิดแต่ยังไม่ได้สัญญาณจากเซิร์ฟเวอร์ (socket หลุด)
bool _isClosed(Map<String, dynamic> round) {
  if (round['is_closed'] == true) return true;
  final at = DateTime.tryParse('${round['closes_at'] ?? ''}');
  return at != null && at.isBefore(DateTime.now());
}

/// "ปิดรับใน 12 นาที" — ให้คนที่ยังไม่สั่งรู้ว่าเหลือเวลาเท่าไร
String? _closesInLabel(Map<String, dynamic> round) {
  if (_isClosed(round)) return null;
  final at = DateTime.tryParse('${round['closes_at'] ?? ''}')?.toLocal();
  if (at == null) return null;
  final left = at.difference(DateTime.now());
  if (left.isNegative) return null;
  if (left.inHours >= 1) return 'ปิดรับใน ${left.inHours} ชม.';
  return 'ปิดรับใน ${left.inMinutes + 1} นาที';
}

/// ข้อความรายการรวมสำหรับวางในแชทร้าน / อ่านให้ร้านฟัง
String foodRoundShopText(Map<String, dynamic> round) {
  final lines = _maps(round['summary']);
  final buf = StringBuffer('🍜 ${round['title'] ?? 'ออเดอร์อาหาร'}\n');
  for (final l in lines) {
    buf.writeln('• ${l['name']} × ${l['qty']}');
  }
  buf.write('รวม ${_int(round['dish_count'])} จาน');
  return buf.toString();
}

/// การ์ดในบับเบิลแชท — สรุปสั้น ๆ + ปุ่มสั่ง/แก้ และเปิดรายการรวม
class ChatFoodRoundCard extends StatelessWidget {
  final Map<String, dynamic> round;
  final int? myUserId;
  final VoidCallback onOrder;
  final VoidCallback onOpenSummary;

  /// เปิด QR จ่ายค่าอาหาร (มีเมื่อทีมงานส่งยอดแล้ว)
  final VoidCallback? onPay;

  const ChatFoodRoundCard({
    super.key,
    required this.round,
    required this.myUserId,
    required this.onOrder,
    required this.onOpenSummary,
    this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final closed = _isClosed(round);
    final mine = myFoodOrder(round, myUserId);
    final summary = _maps(round['summary']);
    final orderCount = _int(round['order_count']);
    final dishCount = _int(round['dish_count']);
    final note = round['note']?.toString() ?? '';
    final closesIn = _closesInLabel(round);
    final billing = round['billing'] is Map
        ? Map<String, dynamic>.from(round['billing'] as Map)
        : null;

    final meta = <String>[
      orderCount > 0
          ? 'สั่งแล้ว $orderCount คน · $dishCount จาน'
          : 'ยังไม่มีใครสั่ง',
      if (billing != null)
        'เก็บเงินแล้ว ${baht(billing['collected'])}/${baht(billing['total'])}'
      else if (closed)
        'ปิดรับแล้ว'
      else
        ?closesIn,
    ];

    final muted = AppTheme.mutedText(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.ramen_dining_rounded,
              size: 17,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                round['title']?.toString() ?? 'รับออเดอร์อาหาร',
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
          meta.join(' · '),
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w600,
            color: closed ? AppTheme.warningColor : muted,
          ),
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            note,
            style: appFont(
              fontSize: AppText.sizeLabel,
              color: AppTheme.onSurface(context),
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 10),
        // ออเดอร์ของฉัน — สิ่งแรกที่คนเปิดการ์ดอยากรู้คือ "ฉันสั่งไปหรือยัง สั่งอะไร"
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: mine != null
                  ? AppTheme.primaryColor.withValues(alpha: 0.55)
                  : AppTheme.border(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                mine == null
                    ? Icons.edit_note_rounded
                    : (mine['skipped'] == true
                          ? Icons.do_not_disturb_on_outlined
                          : Icons.check_circle_rounded),
                size: 16,
                color: mine == null ? muted : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mine == null
                      ? (closed ? 'คุณไม่ได้สั่งรอบนี้' : 'ยังไม่ได้สั่ง')
                      : (mine['skipped'] == true
                            ? 'รอบนี้ไม่สั่ง'
                            : _itemsText(_maps(mine['items']))),
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: mine == null
                        ? FontWeight.w600
                        : FontWeight.w700,
                    color: mine == null ? muted : AppTheme.onSurface(context),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (billing != null && mine != null && mine['skipped'] != true)
          MyFoodBillRow(order: mine, onPay: onPay ?? () {}),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final line in summary.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line['name']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: muted,
                      ),
                    ),
                  ),
                  Text(
                    '× ${line['qty']}',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w800,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
          if (summary.length > 3)
            Text(
              'และอีก ${summary.length - 3} เมนู',
              style: appFont(fontSize: AppText.sizeCaption, color: muted),
            ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            if (!closed)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onOrder();
                  },
                  icon: Icon(
                    mine == null ? Icons.add_rounded : Icons.edit_rounded,
                    size: 17,
                  ),
                  label: Text(
                    mine == null ? 'สั่งอาหาร' : 'แก้ออเดอร์',
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
            if (!closed) const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onOpenSummary();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: AppTheme.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                child: Text(
                  'ดูรายการรวม',
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

// ── ชีตเปิดรอบ (สตาฟ) ──────────────────────────────────────────────────────

class FoodRoundDraft {
  final String title;
  final String? note;
  final int? minutes;

  const FoodRoundDraft({required this.title, this.note, this.minutes});
}

class OpenFoodRoundSheet extends StatefulWidget {
  const OpenFoodRoundSheet({super.key});

  @override
  State<OpenFoodRoundSheet> createState() => _OpenFoodRoundSheetState();
}

class _OpenFoodRoundSheetState extends State<OpenFoodRoundSheet> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  int? _minutes = 30;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      icon: Icons.ramen_dining_rounded,
      title: 'รับออเดอร์อาหาร',
      subtitle:
          'ลูกทริปพิมพ์เมนูของตัวเองในแชทระหว่างนั่งรถ '
          'คุณได้รายการรวมไว้สั่งร้านทีเดียว',
      footer: PrimaryCTAButton(
        label: 'เปิดรับออเดอร์',
        icon: Icons.send_rounded,
        onPressed: _title.text.trim().isEmpty
            ? null
            : () {
                HapticFeedback.mediumImpact();
                Navigator.pop(
                  context,
                  FoodRoundDraft(
                    title: _title.text.trim(),
                    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                    minutes: _minutes,
                  ),
                );
              },
      ),
      children: [
        TextField(
          controller: _title,
          autofocus: true,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface(context),
          ),
          decoration: _fieldDecoration(
            context,
            'ชื่อมื้อ/ร้าน เช่น มื้อเย็นขากลับ ร้านป้าแดง',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLength: 300,
          maxLines: 3,
          minLines: 2,
          style: appFont(
            fontSize: AppText.sizeBody,
            color: AppTheme.onSurface(context),
          ),
          decoration: _fieldDecoration(
            context,
            'หมายเหตุ (ไม่บังคับ) เช่น ร้านอาหารตามสั่ง จ่ายเองที่ร้าน '
            'บอกระดับเผ็ดในเมนูได้เลย',
          ),
        ),
        const SizedBox(height: 14),
        const _Label('ปิดรับอัตโนมัติ'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in const [
              (null, 'ปิดเอง'),
              (15, '15 นาที'),
              (30, '30 นาที'),
              (60, '1 ชม.'),
            ])
              ChoiceChip(
                label: Text(
                  option.$2,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selected: _minutes == option.$1,
                onSelected: (_) => setState(() => _minutes = option.$1),
              ),
          ],
        ),
      ],
    );
  }
}

// ── ชีตสั่ง/แก้ออเดอร์ ─────────────────────────────────────────────────────

/// ผลจากชีตสั่งอาหาร — withdraw = ยกเลิกออเดอร์เดิมทั้งหมด
class FoodOrderDraft {
  final List<Map<String, dynamic>> items;
  final bool skipped;
  final bool withdraw;
  final String? name;

  const FoodOrderDraft({
    this.items = const [],
    this.skipped = false,
    this.withdraw = false,
    this.name,
  });
}

class _ItemRow {
  final TextEditingController name;
  int qty;

  _ItemRow(String text, this.qty) : name = TextEditingController(text: text);
}

/// พิมพ์เมนูของตัวเอง หนึ่งแถวต่อหนึ่งเมนู (ใส่ "ไม่เผ็ด / ไข่ดาว" ต่อท้ายชื่อได้เลย)
/// ชิป "เหมือนเพื่อน" ดึงเมนูที่คนอื่นสั่งแล้วมาเติมได้ในแตะเดียว
///
/// [onBehalf] = สตาฟจดแทนคนที่ไม่ได้ใช้แอป → มีช่องชื่อ และไม่มีปุ่มไม่สั่ง/ยกเลิก
class FoodOrderSheet extends StatefulWidget {
  final Map<String, dynamic> round;
  final Map<String, dynamic>? existing;
  final bool onBehalf;

  const FoodOrderSheet({
    super.key,
    required this.round,
    this.existing,
    this.onBehalf = false,
  });

  @override
  State<FoodOrderSheet> createState() => _FoodOrderSheetState();
}

class _FoodOrderSheetState extends State<FoodOrderSheet> {
  final _guestName = TextEditingController();
  late final List<_ItemRow> _rows;

  @override
  void initState() {
    super.initState();
    final current = widget.existing?['skipped'] == true
        ? const <Map<String, dynamic>>[]
        : _maps(widget.existing?['items']);
    _rows = current.isEmpty
        ? [_ItemRow('', 1)]
        : current
              .map(
                (i) =>
                    _ItemRow('${i['name']}', _int(i['qty']).clamp(1, _maxQty)),
              )
              .toList();
  }

  @override
  void dispose() {
    _guestName.dispose();
    for (final r in _rows) {
      r.name.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> get _items => _rows
      .where((r) => r.name.text.trim().isNotEmpty)
      .map((r) => {'name': r.name.text.trim(), 'qty': r.qty})
      .toList();

  bool get _canSubmit =>
      _items.isNotEmpty &&
      (!widget.onBehalf || _guestName.text.trim().isNotEmpty);

  void _addSuggestion(String name) {
    HapticFeedback.selectionClick();
    setState(() {
      final blank = _rows.where((r) => r.name.text.trim().isEmpty).firstOrNull;
      if (blank != null) {
        blank.name.text = name;
      } else if (_rows.length < _maxItems) {
        _rows.add(_ItemRow(name, 1));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mineNames = _rows.map((r) => r.name.text.trim()).toSet();
    final suggestions = _maps(widget.round['summary'])
        .map((l) => l['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty && !mineNames.contains(n))
        .take(8)
        .toList();
    final hasExisting = widget.existing != null;

    return _SheetFrame(
      icon: Icons.ramen_dining_rounded,
      title: widget.onBehalf
          ? 'จดออเดอร์แทน'
          : (hasExisting ? 'แก้ออเดอร์' : 'สั่งอาหาร'),
      subtitle: widget.round['title']?.toString(),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryCTAButton(
            label: widget.onBehalf ? 'บันทึกออเดอร์' : 'ส่งออเดอร์',
            icon: Icons.check_rounded,
            onPressed: _canSubmit
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(
                      context,
                      FoodOrderDraft(
                        items: _items,
                        name: widget.onBehalf ? _guestName.text.trim() : null,
                      ),
                    );
                  }
                : null,
          ),
          if (!widget.onBehalf)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.existing?['skipped'] != true)
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const FoodOrderDraft(skipped: true),
                    ),
                    child: Text(
                      'รอบนี้ไม่สั่ง',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ),
                if (hasExisting)
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const FoodOrderDraft(withdraw: true),
                    ),
                    child: Text(
                      'ลบออเดอร์ของฉัน',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      children: [
        if ((widget.round['note']?.toString() ?? '').isNotEmpty) ...[
          Text(
            widget.round['note'].toString(),
            style: appFont(
              fontSize: AppText.sizeLabel,
              color: AppTheme.onSurface(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.onBehalf) ...[
          TextField(
            controller: _guestName,
            autofocus: true,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
            ),
            decoration: _fieldDecoration(context, 'ชื่อคนสั่ง'),
          ),
          const SizedBox(height: 10),
        ],
        const _Label('เมนู (1 แถว = 1 เมนู ใส่รายละเอียดต่อท้ายได้)'),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rows[i].name,
                    autofocus:
                        !widget.onBehalf &&
                        i == 0 &&
                        _rows[i].name.text.isEmpty,
                    maxLength: 120,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface(context),
                    ),
                    decoration: _fieldDecoration(
                      context,
                      i == 0 ? 'เช่น กะเพราหมูสับ ไข่ดาว ไม่เผ็ด' : 'เมนูถัดไป',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _QtyStepper(
                  qty: _rows[i].qty,
                  onChanged: (q) => setState(() => _rows[i].qty = q),
                ),
                if (_rows.length > 1)
                  IconButton(
                    tooltip: 'ลบเมนูนี้',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        setState(() => _rows.removeAt(i).name.dispose()),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
              ],
            ),
          ),
        if (_rows.length < _maxItems)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _rows.add(_ItemRow('', 1))),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'เพิ่มเมนู',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          const _Label('เหมือนเพื่อน — แตะเพื่อเพิ่ม'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in suggestions)
                ActionChip(
                  label: Text(
                    s,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _addSuggestion(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;

  const _QtyStepper({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, int next, bool enabled) => InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onChanged(next);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? AppTheme.primaryColor
              : AppTheme.mutedText(context).withValues(alpha: 0.4),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, qty - 1, qty > 1),
          SizedBox(
            width: 20,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
          button(Icons.add_rounded, qty + 1, qty < _maxQty),
        ],
      ),
    );
  }
}

// ── ชีตรายการรวม ──────────────────────────────────────────────────────────

/// รายการรวมสำหรับสั่งร้าน + รายคน + ใครยังไม่สั่ง
///
/// อัปเดตสดผ่าน [round] (ValueListenable ที่ห้องแชทป้อนจาก realtime) — สตาฟเปิดค้าง
/// ไว้ระหว่างรอคนสั่งได้ เห็นออเดอร์ไหลเข้ามาเอง
class FoodRoundSummarySheet extends StatelessWidget {
  final ValueListenable<Map<String, dynamic>?> round;

  /// ลูกทริปในห้อง [{id, name}] — ใช้หาว่าใครยังไม่สั่ง
  final List<Map<String, dynamic>> travellers;
  final bool canManage;
  final int? myUserId;
  final Future<void> Function(int orderId) onDeleteOrder;
  final Future<void> Function() onAddOnBehalf;
  final Future<void> Function(bool close) onSetClosed;

  /// ทีมงานเปิดชีตใส่ราคา/หารบิล
  final Future<void> Function()? onOpenBill;

  /// ทีมงานยืนยัน/ยกเลิกว่าได้รับเงินของออเดอร์นี้แล้ว
  final Future<void> Function(int orderId, bool paid)? onSetPaid;

  const FoodRoundSummarySheet({
    super.key,
    required this.round,
    required this.travellers,
    required this.canManage,
    required this.myUserId,
    required this.onDeleteOrder,
    required this.onAddOnBehalf,
    required this.onSetClosed,
    this.onOpenBill,
    this.onSetPaid,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: round,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        return _buildFor(context, data);
      },
    );
  }

  Widget _buildFor(BuildContext context, Map<String, dynamic> data) {
    final closed = _isClosed(data);
    final summary = _maps(data['summary']);
    final orders = _maps(data['orders']);
    final orderedIds = orders
        .map((o) => int.tryParse('${o['user_id']}'))
        .whereType<int>()
        .toSet();
    final pending = travellers
        .where((t) => !orderedIds.contains(_int(t['id'])))
        .map((t) => t['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    final muted = AppTheme.mutedText(context);
    final closesIn = _closesInLabel(data);

    return _SheetFrame(
      icon: Icons.receipt_long_rounded,
      title: data['title']?.toString() ?? 'รายการรวม',
      subtitle: [
        'สั่งแล้ว ${_int(data['order_count'])} คน · ${_int(data['dish_count'])} จาน',
        if (closed) 'ปิดรับแล้ว' else ?closesIn,
      ].join(' · '),
      footer: canManage
          ? Row(
              children: [
                if (!closed) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAddOnBehalf,
                      icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                      label: Text(
                        'จดแทน',
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onSetClosed(!closed);
                    },
                    icon: Icon(
                      closed ? Icons.lock_open_rounded : Icons.lock_rounded,
                      size: 18,
                    ),
                    label: Text(
                      closed ? 'เปิดรับต่อ' : 'ปิดรับ แล้วไปสั่ง',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
      children: [
        Row(
          children: [
            const Expanded(child: _Label('รายการรวมสำหรับสั่งร้าน')),
            if (summary.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: foodRoundShopText(data)),
                  );
                  HapticFeedback.selectionClick();
                  AppSnack.show(context, 'คัดลอกรายการแล้ว');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(
                  'คัดลอก',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        if (summary.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'ยังไม่มีใครสั่ง',
              style: appFont(fontSize: AppText.sizeBody, color: muted),
            ),
          )
        else
          Container(
            decoration: AppTheme.cardDecoration(
              context,
              radius: AppTheme.radiusSm,
            ),
            child: Column(
              children: [
                for (var i = 0; i < summary.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: AppTheme.border(context)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            '×${summary[i]['qty']}',
                            style: appFont(
                              fontSize: AppText.sizeSubtitle,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary[i]['name']?.toString() ?? '',
                                style: appFont(
                                  fontSize: AppText.sizeBody,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onSurface(context),
                                  height: 1.35,
                                ),
                              ),
                              Text(
                                (summary[i]['people'] as List? ?? const [])
                                    .join(', '),
                                style: appFont(
                                  fontSize: AppText.sizeCaption,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (canManage || data['billing'] is Map) ...[
          const SizedBox(height: 16),
          _BillingPanel(
            data: data,
            canManage: canManage,
            onOpenBill: onOpenBill,
          ),
        ],
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Label('ยังไม่สั่ง ${pending.length} คน'),
          Text(
            pending.join(', '),
            style: appFont(
              fontSize: AppText.sizeLabel,
              color: AppTheme.onSurface(context),
              height: 1.4,
            ),
          ),
        ],
        if (orders.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _Label('รายคน'),
          for (final o in orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${o['name']}'
                                '${o['is_guest'] == true ? ' (จดแทน)' : ''}  ',
                            style: appFont(
                              fontSize: AppText.sizeLabel,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                          TextSpan(
                            text: o['skipped'] == true
                                ? 'ไม่สั่ง'
                                : _itemsText(_maps(o['items'])),
                            style: appFont(
                              fontSize: AppText.sizeLabel,
                              color: o['skipped'] == true
                                  ? muted
                                  : AppTheme.onSurface(context),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (data['billing'] is Map && o['skipped'] != true)
                    _PayChip(
                      order: o,
                      // ทีมงานแตะเพื่อยืนยันว่าได้เงินแล้ว / แตะอีกครั้งเพื่อยกเลิก
                      onTap: canManage && onSetPaid != null
                          ? () => _confirmPaid(context, o)
                          : null,
                    ),
                  if (canManage && !closed)
                    InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      onTap: () => _confirmDelete(context, o),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _confirmPaid(
    BuildContext context,
    Map<String, dynamic> order,
  ) async {
    final paid =
        order['pay_status'] == 'paid' || order['pay_status'] == 'short';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          paid
              ? 'ยกเลิกสถานะจ่ายแล้วของ ${order['name']}?'
              : '${order['name']} จ่าย ${baht(order['balance'] ?? order['amount'])} แล้ว?',
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: paid
            ? null
            : Text(
                'เช็กยอดเข้าในแอปธนาคาร (หรือรับเงินสด) แล้วค่อยยืนยันนะครับ',
                style: appFont(fontSize: AppText.sizeBody),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยังก่อน', style: appFont(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              paid ? 'ยกเลิก' : 'ได้รับแล้ว',
              style: appFont(
                fontWeight: FontWeight.w800,
                color: paid ? AppTheme.errorColor : AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
    // ขาดเพราะราคาขึ้นทีหลัง = ยืนยันยอดใหม่ทับ ไม่ใช่ยกเลิก
    if (ok == true) {
      await onSetPaid!(
        _int(order['id']),
        order['pay_status'] == 'short' ? true : !paid,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Map<String, dynamic> order,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ลบออเดอร์ของ ${order['name']}?',
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ไม่ลบ', style: appFont(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'ลบ',
              style: appFont(
                fontWeight: FontWeight.w800,
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await onDeleteOrder(_int(order['id']));
  }
}

/// สรุปการเก็บเงินในชีตรายการรวม + ปุ่มใส่ราคาของทีมงาน
class _BillingPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool canManage;
  final Future<void> Function()? onOpenBill;

  const _BillingPanel({
    required this.data,
    required this.canManage,
    required this.onOpenBill,
  });

  @override
  Widget build(BuildContext context) {
    final billing = data['billing'] is Map
        ? Map<String, dynamic>.from(data['billing'] as Map)
        : null;
    final hasDishes = _maps(data['summary']).isNotEmpty;
    final muted = AppTheme.mutedText(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  billing == null
                      ? 'ค่าอาหาร'
                      : 'เก็บแล้ว ${baht(billing['collected'])} จาก ${baht(billing['total'])}',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              if (canManage && hasDishes && onOpenBill != null)
                TextButton(
                  onPressed: onOpenBill,
                  child: Text(
                    billing == null ? 'หารบิล' : 'แก้ราคา',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            billing == null
                ? 'จ่ายร้านรวมทีเดียว แล้วใส่ราคาต่อจาน ทุกคนจะเห็นยอดของตัวเองและสแกนจ่ายคืนได้'
                : [
                    'ค้าง ${baht(billing['outstanding'])}',
                    'จ่ายครบ ${_int(billing['paid_count'])} คน',
                    if (_int(billing['owing_count']) > 0)
                      'ยังค้าง ${_int(billing['owing_count'])} คน',
                    if ((billing['payee_name']?.toString() ?? '').isNotEmpty)
                      'โอนให้ ${billing['payee_name']}',
                  ].join(' · '),
            style: appFont(
              fontSize: AppText.sizeCaption,
              color: muted,
              height: 1.4,
            ),
          ),
          if (billing != null &&
              (billing['unpriced'] as List? ?? const []).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'ยังไม่มีราคา: ${(billing['unpriced'] as List).join(', ')}',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.warningColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ยอด + สถานะจ่ายของแต่ละคนในรายชื่อ
class _PayChip extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onTap;

  const _PayChip({required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final badge = foodPayStatus(context, order);
    if (badge == null) return const SizedBox.shrink();
    final priced = order['pay_status'] != 'unpriced';

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      onTap: priced ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: badge.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          priced ? '${baht(order['amount'])} · ${badge.label}' : badge.label,
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w800,
            color: badge.color,
          ),
        ),
      ),
    );
  }
}

// ── ชิ้นส่วนร่วม ───────────────────────────────────────────────────────────

InputDecoration _fieldDecoration(BuildContext context, String hint) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
    borderSide: BorderSide(color: AppTheme.border(context)),
  );
  return InputDecoration(
    hintText: hint,
    hintMaxLines: 2,
    hintStyle: appFont(
      fontSize: AppText.sizeBody,
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

class _Label extends StatelessWidget {
  final String label;

  const _Label(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

/// โครงชีตล่างที่ใช้ร่วมกัน: ที่จับ + หัวเรื่อง + เนื้อหาเลื่อนได้ + ปุ่มท้ายชีต
class _SheetFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  const _SheetFrame({
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
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
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
