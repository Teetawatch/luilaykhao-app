import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/chat_food_bill.dart' show baht;
import '../widgets/confirm_dialog.dart';

// สรุปยอดหน้างานของรอบ (ทีมงาน) — payload จาก OnsiteMoneyService::summary()
//
// เงินอยู่กับใคร: เงินสด = คนที่กดรับ, เงินโอน = เจ้าของพร้อมเพย์ของการ์ดเก็บเงิน
// สตาฟกด "ยืนยันส่งเงิน" (แช่ยอดตอนนั้น) การเงินกด "ได้รับแล้ว" ในหลังบ้าน
// ค่าอาหารแสดงแยก ไม่นับในยอดส่งบริษัท (สตาฟสำรองจ่ายร้านแล้วเก็บคืน)

List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;

({String label, Color color}) onsiteStatus(dynamic status) => switch (status) {
  'received' => (label: 'การเงินรับแล้ว', color: AppTheme.primaryColor),
  'submitted' => (label: 'ส่งแล้ว รอตรวจรับ', color: AppTheme.accentColor),
  'changed' => (
    label: 'ยอดเปลี่ยนหลังส่ง ต้องส่งใหม่',
    color: AppTheme.errorColor,
  ),
  _ => (label: 'ยังไม่ได้ส่ง', color: AppTheme.warningColor),
};

class OnsiteMoneyScreen extends StatefulWidget {
  final int scheduleId;

  const OnsiteMoneyScreen({super.key, required this.scheduleId});

  @override
  State<OnsiteMoneyScreen> createState() => _OnsiteMoneyScreenState();
}

class _OnsiteMoneyScreenState extends State<OnsiteMoneyScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().getOnsiteMoney(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _submit(Map<String, dynamic> mine) async {
    final ok = await showConfirmDialog(
      context,
      title: 'ยืนยันส่งเงิน ${baht(mine['total'])}?',
      message:
          'เงินสด ${baht(mine['cash'])} · เงินโอนเข้าพร้อมเพย์คุณ ${baht(mine['transfer'])}\n'
          'กดเมื่อโอน/ส่งเงินให้บริษัทแล้ว การเงินจะตรวจรับในหลังบ้าน',
      icon: Icons.payments_outlined,
      confirmLabel: 'ส่งเงินแล้ว',
      cancelLabel: 'ยังก่อน',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final data = await context.read<AppProvider>().submitOnsiteMoney(
        widget.scheduleId,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _data = data);
      AppSnack.show(context, 'ยืนยันส่งเงินแล้ว รอการเงินตรวจรับ');
    } catch (e) {
      if (mounted) AppSnack.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'สรุปยอดหน้างาน',
          style: appFont(
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: data == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: appFont(fontSize: AppText.sizeBody),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _load,
                            child: Text(
                              'ลองใหม่',
                              style: appFont(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: OnsiteMoneyView(
                data: data,
                busy: _busy,
                onSubmit: _submit,
              ),
            ),
    );
  }
}

/// เนื้อหาสรุป — แยกจากหน้าจอเพื่อให้เทสวาดได้โดยไม่ต้องมี provider
class OnsiteMoneyView extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool busy;
  final ValueChanged<Map<String, dynamic>> onSubmit;

  const OnsiteMoneyView({
    super.key,
    required this.data,
    required this.onSubmit,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final totals = data['totals'] is Map
        ? Map<String, dynamic>.from(data['totals'] as Map)
        : const <String, dynamic>{};
    final mine = data['mine'] is Map
        ? Map<String, dynamic>.from(data['mine'] as Map)
        : null;
    final holders = _maps(data['holders']);
    final collections = _maps(data['collections']);
    final food = _maps(data['food']);
    final schedule = data['schedule'] is Map
        ? Map<String, dynamic>.from(data['schedule'] as Map)
        : const <String, dynamic>{};
    final muted = AppTheme.mutedText(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if ((schedule['trip_title']?.toString() ?? '').isNotEmpty)
          Text(
            schedule['trip_title'].toString(),
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        if (data['is_frozen'] == true) ...[
          const SizedBox(height: 8),
          const _Note(
            icon: Icons.inventory_rounded,
            text:
                'ห้องแชทของรอบนี้ถูกล้างแล้ว — ยอดนี้คือยอดที่ระบบบันทึกไว้ก่อนล้าง',
          ),
        ],
        const SizedBox(height: 12),
        if (mine != null && _num(mine['total']) > 0)
          _MineCard(mine: mine, busy: busy, onSubmit: () => onSubmit(mine))
        else
          const _Note(
            icon: Icons.check_circle_outline_rounded,
            text: 'คุณไม่ได้ถือเงินหน้างานของรอบนี้',
          ),
        const SizedBox(height: 20),
        const _Heading('ยอดรวมรอบนี้'),
        _Panel(
          child: Column(
            children: [
              _Row('เก็บได้', baht(totals['collected']), bold: true),
              _Row('เงินสด', baht(totals['cash'])),
              _Row('เงินโอน', baht(totals['transfer'])),
              _Row(
                'ยังค้าง',
                baht(totals['outstanding']),
                color: _num(totals['outstanding']) > 0
                    ? AppTheme.warningColor
                    : null,
              ),
            ],
          ),
        ),
        if (holders.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _Heading('เงินอยู่กับใคร'),
          _Panel(
            child: Column(
              children: [
                for (final h in holders)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h['name']?.toString() ?? '',
                                style: appFont(
                                  fontSize: AppText.sizeBody,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.onSurface(context),
                                ),
                              ),
                              Text(
                                [
                                  if (_num(h['cash']) > 0)
                                    'เงินสด ${baht(h['cash'])}',
                                  if (_num(h['transfer']) > 0)
                                    'โอน ${baht(h['transfer'])}'
                                        '${h['promptpay'] == null ? '' : ' (${h['promptpay']})'}',
                                ].join(' · '),
                                style: appFont(
                                  fontSize: AppText.sizeCaption,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              baht(h['total']),
                              style: appFont(
                                fontSize: AppText.sizeBody,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.onSurface(context),
                              ),
                            ),
                            Text(
                              onsiteStatus(h['status']).label,
                              style: appFont(
                                fontSize: AppText.sizeCaption,
                                fontWeight: FontWeight.w700,
                                color: onsiteStatus(h['status']).color,
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
        ],
        if (collections.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _Heading('รายการเก็บเงิน'),
          for (final c in collections)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c['title']?.toString() ?? '',
                            style: appFont(
                              fontSize: AppText.sizeBody,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                        ),
                        Text(
                          '${baht(c['collected'])}/${baht(c['total'])}',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      [
                        if ((c['receiver']?.toString() ?? '').isNotEmpty)
                          'โอนเข้า ${c['receiver']}',
                        'เงินสด ${baht(c['cash'])}',
                        'โอน ${baht(c['transfer'])}',
                      ].join(' · '),
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: muted,
                      ),
                    ),
                    if (_maps(c['unpaid']).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'ยังไม่จ่าย: ${_maps(c['unpaid']).map((u) => '${u['name']} ${baht(u['amount'])}${u['claimed'] == true ? ' (แนบสลิปแล้ว)' : ''}').join(', ')}',
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warningColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
        if (food.isNotEmpty) ...[
          const SizedBox(height: 10),
          const _Heading('ค่าอาหาร (ไม่นับในยอดส่งบริษัท)'),
          _Panel(
            child: Column(
              children: [
                for (final f in food)
                  _Row(
                    f['title']?.toString() ?? 'ค่าอาหาร',
                    '${baht(f['collected'])}/${baht(f['total'])}'
                    '${(f['owing_count'] ?? 0) > 0 ? ' · ค้าง ${f['owing_count']} คน' : ''}',
                  ),
              ],
            ),
          ),
        ],
        if (collections.isEmpty && food.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'รอบนี้ไม่มีการเก็บเงินหน้างาน',
              textAlign: TextAlign.center,
              style: appFont(fontSize: AppText.sizeBody, color: muted),
            ),
          ),
      ],
    );
  }
}

class _MineCard extends StatelessWidget {
  final Map<String, dynamic> mine;
  final bool busy;
  final VoidCallback onSubmit;

  const _MineCard({
    required this.mine,
    required this.busy,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final status = onsiteStatus(mine['status']);
    final handover = mine['handover'] is Map
        ? Map<String, dynamic>.from(mine['handover'] as Map)
        : null;
    final canSend = mine['status'] == 'pending' || mine['status'] == 'changed';
    final muted = AppTheme.mutedText(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: status.color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'เงินที่คุณถือ',
            style: appFont(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            baht(mine['total']),
            style: appFont(
              fontSize: AppText.sizeH1,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              'เงินสด ${baht(mine['cash'])}',
              'โอนเข้าพร้อมเพย์คุณ ${baht(mine['transfer'])}'
                  '${mine['promptpay'] == null ? '' : ' (${mine['promptpay']})'}',
            ].join(' · '),
            style: appFont(fontSize: AppText.sizeLabel, color: muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: status.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [
                    status.label,
                    if (mine['status'] == 'received' &&
                        (handover?['received_by']?.toString() ?? '').isNotEmpty)
                      'โดย ${handover!['received_by']}',
                    if (mine['status'] == 'changed' && handover != null)
                      'ส่งไว้ ${baht(handover['total'])}',
                  ].join(' · '),
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    color: status.color,
                  ),
                ),
              ),
            ],
          ),
          if (canSend) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onSubmit,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  mine['status'] == 'changed'
                      ? 'ส่งยอดใหม่ ${baht(mine['total'])}'
                      : 'ยืนยันส่งเงินให้บริษัท',
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
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: appFont(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedText(context),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: child,
  );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _Row(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: AppTheme.onSurface(context),
            ),
          ),
        ),
        Text(
          value,
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: color ?? AppTheme.onSurface(context),
          ),
        ),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.subtleSurface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.mutedText(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: appFont(
              fontSize: AppText.sizeLabel,
              color: AppTheme.onSurface(context),
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
