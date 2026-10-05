import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import 'chat_food_bill.dart'
    show FoodPaySheet, baht, staffPayeePrefKey, staffPromptPayPrefKey;
import 'chat_rest_stop.dart'
    show RestStopSheetFrame, RestStopSheetLabel, restStopFieldDecoration;
import 'travel_widgets.dart';

// เก็บเงินหน้างาน — ค่าใช้จ่ายนอกแพ็กเกจ (ค่าเข้าอุทยานต่างชาติ ค่าลูกหาบ ทิปไกด์)
//
// payload (collection) มาจาก ChatCollectionService::present() — ยอดเป็นรายผู้โดยสาร
// แต่ละคนมี user_id ของบัญชีที่ดูแล (คนจองจ่ายแทนทั้งกลุ่ม) และ QR ของยอดค้าง
// รวมต่อบัญชีอยู่ใน payloads[user_id]

List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

int _int(dynamic v) => int.tryParse('$v') ?? 0;

double _num(dynamic v) => double.tryParse('$v') ?? 0;

/// ยอดของคนที่บัญชีนี้ดูแล
List<Map<String, dynamic>> myCollectionDues(
  Map<String, dynamic> collection,
  int? myUserId,
) {
  if (myUserId == null) return const [];
  return _maps(
    collection['dues'],
  ).where((d) => int.tryParse('${d['user_id']}') == myUserId).toList();
}

/// สถานะรวมของฉัน: paid (ครบ) / claimed (แจ้งโอนครบทุกคนที่ค้าง) / unpaid
String myCollectionStatus(List<Map<String, dynamic>> mine) {
  final open = mine.where((d) => d['status'] != 'paid').toList();
  if (open.isEmpty) return 'paid';
  return open.every((d) => d['status'] == 'claimed') ? 'claimed' : 'unpaid';
}

({String label, Color color}) _statusBadge(BuildContext context, String s) =>
    switch (s) {
      'paid' => (label: 'จ่ายแล้ว', color: AppTheme.primaryColor),
      'claimed' => (label: 'แจ้งโอนแล้ว', color: AppTheme.accentColor),
      _ => (label: 'ยังไม่จ่าย', color: AppTheme.warningColor),
    };

/// การ์ดในบับเบิลแชท
class ChatCollectionCard extends StatelessWidget {
  final Map<String, dynamic> collection;
  final int? myUserId;
  final bool canManage;
  final VoidCallback onPay;
  final VoidCallback onOpenList;

  const ChatCollectionCard({
    super.key,
    required this.collection,
    required this.myUserId,
    required this.canManage,
    required this.onPay,
    required this.onOpenList,
  });

  @override
  Widget build(BuildContext context) {
    final c = collection;
    final closed = c['is_closed'] == true;
    final mine = myCollectionDues(c, myUserId);
    final myStatus = myCollectionStatus(mine);
    final myOwed = mine
        .where((d) => d['status'] != 'paid')
        .fold<double>(0, (sum, d) => sum + _num(d['amount']));
    final myTotal = mine.fold<double>(0, (sum, d) => sum + _num(d['amount']));
    final hasQr =
        (c['payloads'] is Map) &&
        (c['payloads'] as Map).containsKey('$myUserId');
    final note = c['note']?.toString() ?? '';
    final muted = AppTheme.mutedText(context);
    final badge = _statusBadge(context, myStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.savings_rounded,
              size: 17,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                c['title']?.toString() ?? 'เก็บเงิน',
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
            'คนละ ${baht(c['amount'])}',
            'เก็บแล้ว ${baht(c['collected'])}/${baht(c['total'])}',
            if (closed) 'ปิดยอดแล้ว',
          ].join(' · '),
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
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: badge.color.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.payments_rounded, size: 16, color: badge.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              'ยอดของคุณ ${baht(myStatus == 'paid' ? myTotal : myOwed)}'
                              '${mine.length > 1 ? ' (${mine.length} คน)' : ''}  ',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
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
              ],
            ),
          ),
          if (myStatus != 'paid' && !closed && !hasQr)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'จ่ายเงินสดกับน้องสตาฟได้เลย',
                style: appFont(fontSize: AppText.sizeCaption, color: muted),
              ),
            ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            if (mine.isNotEmpty && myStatus != 'paid' && !closed && hasQr) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onPay();
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                  label: Text(
                    myStatus == 'claimed' ? 'ดู QR' : 'จ่ายเงิน',
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
                  onOpenList();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: AppTheme.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                child: Text(
                  canManage ? 'เช็คยอด' : 'ดูรายชื่อ',
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

/// เปิด QR จ่ายของฉัน — คืน true/false เมื่อแจ้งโอน/ถอน (ใช้ชีตเดียวกับค่าอาหาร)
Future<bool?> showCollectionPaySheet(
  BuildContext context,
  Map<String, dynamic> collection,
  int? myUserId,
) {
  final mine = myCollectionDues(collection, myUserId);
  final owed = mine
      .where((d) => d['status'] != 'paid')
      .fold<double>(0, (sum, d) => sum + _num(d['amount']));
  final payload = (collection['payloads'] is Map)
      ? (collection['payloads'] as Map)['$myUserId']?.toString()
      : null;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusLg),
      ),
    ),
    builder: (_) => FoodPaySheet(
      what: collection['title']?.toString() ?? 'เงิน',
      order: {
        'promptpay_payload': payload,
        'balance': owed,
        'pay_status': myCollectionStatus(mine),
      },
      billing: {
        'payee_name': collection['payee_name'],
        'promptpay_id': collection['promptpay_id'],
      },
    ),
  );
}

// ── สร้างรายการเก็บเงิน (ทีมงาน) ──────────────────────────────────────────

class CollectionDraft {
  final String title;
  final String? note;
  final double amount;

  /// null = ทุกคนในรอบ
  final List<int>? passengerIds;
  final String? promptPayId;
  final String? payeeName;

  const CollectionDraft({
    required this.title,
    required this.note,
    required this.amount,
    required this.passengerIds,
    required this.promptPayId,
    required this.payeeName,
  });
}

class OpenCollectionSheet extends StatefulWidget {
  /// รายชื่อผู้เดินทางของรอบ [{passenger_id, name, ...}] — ไว้เลือกเก็บเฉพาะบางคน
  final List<Map<String, dynamic>> roster;

  const OpenCollectionSheet({super.key, required this.roster});

  @override
  State<OpenCollectionSheet> createState() => _OpenCollectionSheetState();
}

class _OpenCollectionSheetState extends State<OpenCollectionSheet> {
  static const _suggestions = [
    'ค่าเข้าอุทยาน (ต่างชาติ)',
    'ค่าลูกหาบ',
    'ค่าเช่าเต็นท์เพิ่ม',
    'ทิปไกด์ท้องถิ่น',
  ];

  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _promptPay = TextEditingController();
  final _payee = TextEditingController();
  bool _everyone = true;
  late final Set<int> _picked = {
    for (final p in widget.roster) _int(p['passenger_id']),
  };

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
    _amount.dispose();
    _note.dispose();
    _promptPay.dispose();
    _payee.dispose();
    super.dispose();
  }

  double? get _amountValue => double.tryParse(_amount.text.trim());

  String get _digits => _promptPay.text.replaceAll(RegExp(r'\D'), '');

  bool get _promptPayValid =>
      _digits.isEmpty ||
      _digits.length == 13 ||
      (_digits.length == 10 && _digits.startsWith('0'));

  int get _count => _everyone ? widget.roster.length : _picked.length;

  bool get _canSubmit =>
      _title.text.trim().isNotEmpty &&
      (_amountValue ?? 0) > 0 &&
      _promptPayValid &&
      _count > 0;

  @override
  Widget build(BuildContext context) {
    final amount = _amountValue ?? 0;

    return RestStopSheetFrame(
      icon: Icons.savings_rounded,
      title: 'เก็บเงินหน้างาน',
      subtitle:
          'แต่ละคนเห็นยอดของตัวเองและสแกน QR จ่ายคุณได้ คนที่จองให้ทั้งกลุ่มจ่ายรวมทีเดียว '
          'คุณติ๊กได้ว่าใครจ่ายแล้ว (โอนหรือเงินสด)',
      footer: PrimaryCTAButton(
        label: _canSubmit
            ? 'เริ่มเก็บ · $_count คน รวม ${baht(amount * _count)}'
            : 'เริ่มเก็บเงิน',
        icon: Icons.send_rounded,
        onPressed: _canSubmit
            ? () {
                HapticFeedback.mediumImpact();
                _remember();
                Navigator.pop(
                  context,
                  CollectionDraft(
                    title: _title.text.trim(),
                    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                    amount: amount,
                    passengerIds: _everyone ? null : _picked.toList(),
                    promptPayId: _digits.isEmpty ? null : _digits,
                    payeeName: _payee.text.trim().isEmpty
                        ? null
                        : _payee.text.trim(),
                  ),
                );
              }
            : null,
      ),
      children: [
        TextField(
          controller: _title,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface(context),
          ),
          decoration: restStopFieldDecoration(context, 'เก็บค่าอะไร'),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(
                  s,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => setState(() => _title.text = s),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const RestStopSheetLabel('คนละกี่บาท'),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (_) => setState(() {}),
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w800,
          ),
          decoration: restStopFieldDecoration(context, 'เช่น 200'),
        ),
        const SizedBox(height: 12),
        const RestStopSheetLabel('เก็บจากใคร'),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(
                'ทุกคน (${widget.roster.length})',
                style: appFont(fontWeight: FontWeight.w700),
              ),
              selected: _everyone,
              onSelected: (_) => setState(() => _everyone = true),
            ),
            ChoiceChip(
              label: Text(
                'เลือกเอง',
                style: appFont(fontWeight: FontWeight.w700),
              ),
              selected: !_everyone,
              onSelected: (_) => setState(() => _everyone = false),
            ),
          ],
        ),
        if (!_everyone)
          for (final p in widget.roster)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _picked.contains(_int(p['passenger_id'])),
              onChanged: (v) => setState(() {
                final id = _int(p['passenger_id']);
                v == true ? _picked.add(id) : _picked.remove(id);
              }),
              title: Text(
                '${p['full_name'] ?? p['name']}',
                style: appFont(fontWeight: FontWeight.w700),
              ),
            ),
        const SizedBox(height: 12),
        const RestStopSheetLabel('รับเงินทาง (เว้นว่าง = เก็บเงินสด)'),
        TextField(
          controller: _promptPay,
          keyboardType: TextInputType.phone,
          maxLength: 20,
          onChanged: (_) => setState(() {}),
          style: appFont(fontWeight: FontWeight.w700),
          decoration:
              restStopFieldDecoration(
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
          decoration: restStopFieldDecoration(context, 'ชื่อบัญชี'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          maxLength: 300,
          maxLines: 2,
          decoration: restStopFieldDecoration(
            context,
            'หมายเหตุ (ไม่บังคับ) เช่น จ่ายก่อนขึ้นเรือ',
          ),
        ),
      ],
    );
  }
}

// ── เช็คยอด ───────────────────────────────────────────────────────────────

/// รายชื่อพร้อมสถานะจ่าย — ทีมงานแตะชื่อเพื่อยืนยัน/ยกเลิก, ปิดยอด, แก้รายชื่อ
/// อัปเดตสดผ่าน [collection] ที่ห้องแชทป้อนจาก realtime
class CollectionListSheet extends StatelessWidget {
  final ValueListenable<Map<String, dynamic>?> collection;
  final bool canManage;
  final Future<void> Function(List<int> passengerIds, bool paid) onSetPaid;
  final Future<void> Function(bool close) onSetClosed;
  final Future<void> Function() onEditPayers;

  const CollectionListSheet({
    super.key,
    required this.collection,
    required this.canManage,
    required this.onSetPaid,
    required this.onSetClosed,
    required this.onEditPayers,
  });

  Future<void> _toggle(BuildContext context, Map<String, dynamic> due) async {
    final paid = due['status'] == 'paid';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          paid
              ? 'ยกเลิกสถานะจ่ายแล้วของ ${due['name']}?'
              : '${due['name']} จ่าย ${baht(due['amount'])} แล้ว?',
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: paid
            ? null
            : Text(
                'เช็กยอดเข้าในแอปธนาคาร หรือรับเงินสดแล้วค่อยยืนยันนะครับ',
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
    if (ok == true) await onSetPaid([_int(due['passenger_id'])], !paid);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: collection,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        return _buildFor(context, data);
      },
    );
  }

  Widget _buildFor(BuildContext context, Map<String, dynamic> c) {
    final closed = c['is_closed'] == true;
    final dues = _maps(c['dues']);
    final open = dues.where((d) => d['status'] != 'paid').toList();
    final done = dues.where((d) => d['status'] == 'paid').toList();

    Widget row(Map<String, dynamic> d) {
      final badge = _statusBadge(context, d['status']?.toString() ?? '');
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        onTap: canManage ? () => _toggle(context, d) : null,
        leading: Icon(
          d['status'] == 'paid'
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked,
          color: d['status'] == 'paid'
              ? AppTheme.primaryColor
              : AppTheme.mutedText(context),
        ),
        title: Text(
          '${d['name']}',
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface(context),
          ),
        ),
        trailing: Text(
          '${baht(d['amount'])} · ${badge.label}',
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w800,
            color: badge.color,
          ),
        ),
      );
    }

    return RestStopSheetFrame(
      icon: Icons.savings_rounded,
      title: c['title']?.toString() ?? 'เก็บเงิน',
      subtitle: [
        'เก็บแล้ว ${baht(c['collected'])} จาก ${baht(c['total'])}',
        'ค้าง ${_int(c['unpaid_count'])} คน',
        if (closed) 'ปิดยอดแล้ว',
      ].join(' · '),
      footer: canManage
          ? Row(
              children: [
                if (!closed) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEditPayers,
                      icon: const Icon(Icons.group_rounded, size: 18),
                      label: Text(
                        'แก้รายชื่อ',
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
                      closed ? 'เปิดเก็บต่อ' : 'ปิดยอด',
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
        if (open.isNotEmpty) ...[
          RestStopSheetLabel(
            canManage
                ? 'ยังไม่ได้ยืนยัน ${open.length} คน — แตะเมื่อได้รับเงิน'
                : 'ยังไม่ได้ยืนยัน ${open.length} คน',
          ),
          for (final d in open) row(d),
          const SizedBox(height: 8),
        ],
        if (done.isNotEmpty) ...[
          RestStopSheetLabel('จ่ายแล้ว ${done.length} คน'),
          for (final d in done) row(d),
        ],
      ],
    );
  }
}

/// เลือกใหม่ว่าใครต้องจ่าย — คืนรายการ passenger_id
class CollectionPayersSheet extends StatefulWidget {
  final List<Map<String, dynamic>> roster;
  final Set<int> selected;

  const CollectionPayersSheet({
    super.key,
    required this.roster,
    required this.selected,
  });

  @override
  State<CollectionPayersSheet> createState() => _CollectionPayersSheetState();
}

class _CollectionPayersSheetState extends State<CollectionPayersSheet> {
  late final Set<int> _picked = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.group_rounded,
      title: 'เก็บจากใครบ้าง',
      subtitle: 'คนที่จ่ายแล้วเอาออกไม่ได้ ต้องยกเลิกสถานะจ่ายก่อน',
      footer: PrimaryCTAButton(
        label: 'บันทึก (${_picked.length} คน)',
        icon: Icons.check_rounded,
        onPressed: _picked.isEmpty
            ? null
            : () => Navigator.pop(context, _picked.toList()),
      ),
      children: [
        for (final p in widget.roster)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _picked.contains(_int(p['passenger_id'])),
            onChanged: (v) => setState(() {
              final id = _int(p['passenger_id']);
              v == true ? _picked.add(id) : _picked.remove(id);
            }),
            title: Text(
              '${p['full_name'] ?? p['name']}',
              style: appFont(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
