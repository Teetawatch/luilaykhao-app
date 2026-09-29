import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';
import '../widgets/travel_widgets.dart' show PrimaryCTAButton;
import 'staff_check_in_screen.dart' show asList, asMap, money, textOf;

/// ใบซื้อของก่อนออกทริป
///
/// ปัญหาที่แก้: ทุกรอบสตาฟต้องแวะซื้อน้ำ น้ำแข็ง ของกิน ฯลฯ แต่คนที่ไม่เคยไป
/// ทริปนั้นไม่รู้ว่าต้องซื้ออะไร รายการมาจาก "รายการประจำทริป" ที่แอดมินตั้งไว้
/// ของที่คิด "ต่อคน" เซิร์ฟเวอร์คูณจำนวนคนของรอบมาให้แล้ว
///
/// ติ๊กเป็นของทั้งทีม — เพื่อนสตาฟเปิดดูจะเห็นว่าอะไรซื้อแล้ว จะได้ไม่ซื้อซ้ำ
/// จบด้วยการส่งรายงานที่บังคับแนบรูป แล้วใบจะล็อกจนกว่าแอดมินจะตีกลับ
class StaffShoppingScreen extends StatefulWidget {
  final int scheduleId;
  final String title;

  const StaffShoppingScreen({
    super.key,
    required this.scheduleId,
    required this.title,
  });

  @override
  State<StaffShoppingScreen> createState() => _StaffShoppingScreenState();
}

class _StaffShoppingScreenState extends State<StaffShoppingScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  /// id ของรายการที่กำลังบันทึก — กันกดรัวและหมุนเฉพาะแถวนั้น
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppProvider>().loadStaffShopping(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _locked => _data?['locked'] == true;

  int _id(Map<String, dynamic> item) =>
      int.tryParse(textOf(item['id'], '0')) ?? 0;

  Future<void> _toggle(Map<String, dynamic> item) async {
    final id = _id(item);
    if (id <= 0 || _busy.contains(id) || _locked) return;

    final bought = item['bought'] != true;
    HapticFeedback.selectionClick();
    setState(() => _busy.add(id));
    try {
      final data = await context.read<AppProvider>().markStaffShoppingItem(
        widget.scheduleId,
        id,
        bought: bought,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppSnack.error(context, message);
  }

  Future<void> _addItem() async {
    HapticFeedback.selectionClick();
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(scheduleId: widget.scheduleId),
    );
    if (data != null && mounted) setState(() => _data = data);
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'ลบ "${textOf(item['name'])}"?',
          style: appFont(fontSize: AppText.sizeTitle, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'ลบออกจากใบซื้อของของรอบนี้เท่านั้น',
          style: appFont(fontSize: AppText.sizeBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final data = await context.read<AppProvider>().deleteStaffShoppingItem(
        widget.scheduleId,
        _id(item),
      );
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _openSubmit() async {
    HapticFeedback.selectionClick();
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmitReportSheet(
        scheduleId: widget.scheduleId,
        shopping: _data ?? const {},
      ),
    );
    if (data != null && mounted) {
      setState(() => _data = data);
      AppSnack.success(context, 'ส่งรายงานให้แอดมินแล้ว');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSubmit = _data != null && !_locked && _error == null;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'ของที่ต้องซื้อ',
          style: appFont(fontSize: AppText.sizeTitle, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'โหลดใหม่',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
      bottomNavigationBar: showSubmit
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  border: Border(
                    top: BorderSide(color: AppTheme.border(context)),
                  ),
                ),
                child: PrimaryCTAButton(
                  label: 'ถ่ายรูปและส่งรายงาน',
                  icon: Icons.photo_camera_rounded,
                  onPressed: _openSubmit,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading && _data == null) {
      return const SkeletonList(count: 6, padding: EdgeInsets.only(top: 8));
    }
    if (_error != null) {
      return ScrollableEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'โหลดใบซื้อของไม่สำเร็จ',
        body: _error!,
        actionLabel: 'ลองใหม่',
        onAction: _load,
        accent: AppTheme.errorColor,
      );
    }

    final items = asList(_data?['items']).map(asMap).toList();
    final report = asMap(_data?['report']);
    final hasReport = report.isNotEmpty;
    final submitted = report['submitted'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _ProgressCard(data: _data ?? const {}),
        if (hasReport && submitted) ...[
          const SizedBox(height: 12),
          _ReportCard(report: report),
        ] else if (hasReport && textOf(report['reopen_reason']).isNotEmpty) ...[
          const SizedBox(height: 12),
          _ReopenedCard(report: report),
        ],
        const SizedBox(height: 16),
        if (items.isEmpty)
          _EmptyList(hasTemplate: _data?['has_template'] == true)
        else ...[
          Text(
            'รายการ',
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: AppTheme.cardDecoration(context),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppTheme.border(context).withValues(alpha: 0.5),
                    ),
                  _ItemRow(
                    item: items[i],
                    busy: _busy.contains(_id(items[i])),
                    locked: _locked,
                    onToggle: () => _toggle(items[i]),
                    onDelete: items[i]['can_delete'] == true
                        ? () => _deleteItem(items[i])
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (!_locked) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              'เพิ่มของที่ต้องซื้อ',
              style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ของที่เพิ่มตรงนี้ใช้เฉพาะรอบนี้ ถ้าควรซื้อทุกรอบ บอกแอดมินให้เพิ่มในรายการประจำทริป',
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeCaption,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// ซื้อไปแล้วกี่อย่าง + คิดจากกี่คน
class _ProgressCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ProgressCard({required this.data});

  int _int(dynamic v) => int.tryParse(textOf(v, '0')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final summary = asMap(data['summary']);
    final headcount = asMap(data['headcount']);
    final schedule = asMap(data['schedule']);
    final total = _int(summary['total_items']);
    final bought = _int(summary['bought_items']);
    final done = total > 0 && bought >= total;
    final ratio = total == 0 ? 0.0 : (bought / total).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            textOf(schedule['trip_title'], 'ทริป'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.shopping_cart_rounded,
                size: 18,
                color: done ? AppTheme.successColor : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                total == 0 ? 'ยังไม่มีรายการ' : 'ซื้อแล้ว $bought / $total รายการ',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppTheme.border(context),
                valueColor: AlwaysStoppedAnimation(
                  done ? AppTheme.successColor : AppTheme.primaryColor,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            // ของ "ต่อคน" คูณจากตัวเลขนี้ — บอกไว้ให้สตาฟเช็กได้ว่าคิดถูกคน
            'คิดจาก ${_int(headcount['used'])} คน · ลูกค้า ${_int(headcount['travellers'])} + ทีมงาน ${_int(headcount['staff'])}',
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// ของหนึ่งอย่าง — แตะทั้งแถวเพื่อติ๊ก ปุ่มลบมีเฉพาะของที่ตัวเองเพิ่ม
class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool busy;
  final bool locked;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  const _ItemRow({
    required this.item,
    required this.busy,
    required this.locked,
    required this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bought = item['bought'] == true;
    final rule = textOf(item['rule_label']);
    final note = textOf(item['note']);
    final boughtBy = textOf(item['bought_by_name']);
    final addedBy = textOf(item['added_by_name']);
    final isExtra = textOf(item['source']) == 'extra';
    final muted = AppTheme.mutedText(context);

    final sub = <String>[
      if (rule.isNotEmpty) rule,
      if (note.isNotEmpty) note,
      if (bought && boughtBy.isNotEmpty) 'ซื้อแล้ว · $boughtBy',
      if (!bought && isExtra) 'เพิ่มเฉพาะรอบนี้${addedBy.isNotEmpty ? ' โดย $addedBy' : ''}',
    ];

    return InkWell(
      onTap: locked || busy ? null : onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bought ? AppTheme.successColor : Colors.transparent,
                        border: Border.all(
                          color: bought ? AppTheme.successColor : AppTheme.border(context),
                          width: 2,
                        ),
                      ),
                      child: bought
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : null,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          textOf(item['name']),
                          style: appFont(
                            fontSize: AppText.sizeBody,
                            fontWeight: FontWeight.w700,
                            color: bought ? muted : AppTheme.onSurface(context),
                          ).copyWith(
                            decoration: bought ? TextDecoration.lineThrough : null,
                            decorationColor: muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        textOf(item['total_label']),
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w800,
                          color: bought ? muted : AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  for (final line in sub)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        line,
                        style: appFont(fontSize: AppText.sizeCaption, color: muted),
                      ),
                    ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'ลบ',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: Icon(Icons.close_rounded, size: 18, color: muted),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  final bool hasTemplate;

  const _EmptyList({required this.hasTemplate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          Icon(Icons.shopping_basket_outlined, size: 36, color: AppTheme.mutedText(context)),
          const SizedBox(height: 10),
          Text(
            hasTemplate ? 'รอบนี้ไม่มีของต้องซื้อ' : 'ทริปนี้ยังไม่มีรายการประจำ',
            style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'เพิ่มของที่ซื้อเองได้ด้านล่าง แล้วถ่ายรูปส่งรายงานตามปกติ',
            textAlign: TextAlign.center,
            style: appFont(fontSize: AppText.sizeCaption, color: AppTheme.mutedText(context)),
          ),
        ],
      ),
    );
  }
}

/// ส่งรายงานแล้ว — รูป ยอด โน้ต และสถานะว่าแอดมินเปิดดูหรือยัง
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final photos = asList(report['photos']).map((p) => textOf(p)).where((p) => p.isNotEmpty).toList();
    final reviewed = textOf(report['reviewed_at']).isNotEmpty;
    final note = textOf(report['note']);
    final amount = report['total_amount'];
    final unbought = asList(report['unbought']).map((n) => textOf(n)).toList();
    final muted = AppTheme.mutedText(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(
        context,
        color: AppTheme.successColor.withValues(alpha: 0.06),
        borderColor: AppTheme.successColor.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt_rounded, size: 18, color: AppTheme.successColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ส่งรายงานแล้ว',
                  style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (reviewed ? AppTheme.successColor : AppTheme.warningColor)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  reviewed ? 'แอดมินรับทราบแล้ว' : 'รอแอดมินดู',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    color: reviewed ? AppTheme.successColor : AppTheme.warningColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${textOf(report['submitted_at_label'])} น. · ${textOf(report['submitted_by_name'], 'สตาฟ')}',
            style: appFont(fontSize: AppText.sizeCaption, color: muted),
          ),
          if (amount != null) ...[
            const SizedBox(height: 8),
            Text(
              'ยอดซื้อ ${money(amount)}${report['in_ledger'] == true ? ' · ลงบัญชีหน้างานแล้ว' : ''}',
              style: appFont(fontSize: AppText.sizeLabel, fontWeight: FontWeight.w700),
            ),
          ],
          if (unbought.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'ไม่ได้ซื้อ: ${unbought.join(', ')}',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: AppTheme.warningColor,
              ),
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note, style: appFont(fontSize: AppText.sizeLabel)),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _NetworkThumb(url: photos[i]),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'ถ้าต้องแก้อะไร ให้แอดมินกด "ตีกลับ" ที่หลังบ้าน ใบนี้จะกลับมาติ๊กได้อีกครั้ง',
            style: appFont(fontSize: AppText.sizeCaption, color: muted),
          ),
        ],
      ),
    );
  }
}

/// แอดมินตีกลับให้แก้ — บอกเหตุผลไว้บนสุด
class _ReopenedCard extends StatelessWidget {
  final Map<String, dynamic> report;

  const _ReopenedCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(
        context,
        color: AppTheme.warningColor.withValues(alpha: 0.08),
        borderColor: AppTheme.warningColor.withValues(alpha: 0.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.undo_rounded, size: 18, color: AppTheme.warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'แอดมินขอให้แก้แล้วส่งใหม่',
                  style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  textOf(report['reopen_reason']),
                  style: appFont(fontSize: AppText.sizeLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkThumb extends StatelessWidget {
  final String url;

  const _NetworkThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        builder: (dialogContext) => GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: InteractiveViewer(
            child: Center(child: Image.network(url, fit: BoxFit.contain)),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Image.network(
          url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          // ภาพจากกล้องใหญ่ ถอดรหัสเต็มขนาดหลายรูปแอปโดน OOM-kill
          cacheWidth: 216,
          errorBuilder: (_, _, _) => Container(
            width: 72,
            height: 72,
            color: AppTheme.border(context),
            child: const Icon(Icons.broken_image_outlined, size: 20),
          ),
        ),
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final Widget child;

  const _SheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
        ),
        child: child,
      ),
    );
  }
}

InputDecoration _fieldDecoration(String label, {String? hint, String? suffix}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
  );
}

/// เพิ่มของเฉพาะรอบนี้
class _AddItemSheet extends StatefulWidget {
  final int scheduleId;

  const _AddItemSheet({required this.scheduleId});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unit = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppSnack.error(context, 'ใส่ชื่อของก่อน');
      return;
    }
    final quantity = double.tryParse(_quantity.text.trim());
    if (quantity != null && quantity <= 0) {
      AppSnack.error(context, 'จำนวนต้องมากกว่า 0');
      return;
    }

    setState(() => _saving = true);
    try {
      final data = await context.read<AppProvider>().addStaffShoppingItem(
        widget.scheduleId,
        name: name,
        quantity: quantity,
        unit: _unit.text.trim(),
        note: _note.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'เพิ่มของที่ต้องซื้อ',
              style: appFont(fontSize: AppText.sizeTitle, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration('ชื่อของ', hint: 'เช่น ถ่านไฟฉาย'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDecoration('จำนวน'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unit,
                    decoration: _fieldDecoration('หน่วย', hint: 'ก้อน / ถุง / แพ็ค'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: _fieldDecoration('หมายเหตุ (ถ้ามี)', hint: 'เช่น ซื้อที่ 7-11 ปากทาง'),
            ),
            const SizedBox(height: 18),
            PrimaryCTAButton(
              label: 'เพิ่มรายการ',
              icon: Icons.add_rounded,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// ขั้นสุดท้าย — ถ่ายรูป (บังคับ) + ยอดเงิน + หมายเหตุ แล้วส่งให้แอดมิน
class _SubmitReportSheet extends StatefulWidget {
  final int scheduleId;
  final Map<String, dynamic> shopping;

  const _SubmitReportSheet({required this.scheduleId, required this.shopping});

  @override
  State<_SubmitReportSheet> createState() => _SubmitReportSheetState();
}

class _SubmitReportSheetState extends State<_SubmitReportSheet> {
  final List<String> _photos = [];
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _toLedger = true;
  bool _sending = false;

  int get _maxPhotos => int.tryParse(textOf(widget.shopping['max_photos'], '6')) ?? 6;

  bool get _financeClosed => asMap(widget.shopping['ledger'])['finance_closed'] == true;

  List<String> get _unbought => asList(widget.shopping['items'])
      .map(asMap)
      .where((i) => i['bought'] != true)
      .map((i) => textOf(i['name']))
      .toList();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    if (source == ImageSource.gallery) {
      final files = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 80);
      if (!mounted || files.isEmpty) return;
      setState(() {
        for (final f in files) {
          if (_photos.length < _maxPhotos) _photos.add(f.path);
        }
      });
      return;
    }
    final file = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (file != null && mounted && _photos.length < _maxPhotos) {
      setState(() => _photos.add(file.path));
    }
  }

  void _chooseSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SheetShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(
                'ถ่ายรูป',
                style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(
                'เลือกจากคลังรูป',
                style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (_photos.isEmpty) {
      AppSnack.error(context, 'ต้องถ่ายรูปของที่ซื้อหรือใบเสร็จอย่างน้อย 1 รูป');
      return;
    }
    final note = _note.text.trim();
    if (_unbought.isNotEmpty && note.isEmpty) {
      AppSnack.error(context, 'ยังมีของที่ไม่ได้ติ๊ก ช่วยเขียนหมายเหตุบอกแอดมินด้วย');
      return;
    }
    final amountText = _amount.text.trim().replaceAll(',', '');
    final amount = amountText.isEmpty ? null : double.tryParse(amountText);
    if (amountText.isNotEmpty && (amount == null || amount < 0)) {
      AppSnack.error(context, 'กรอกยอดเงินให้ถูกต้อง');
      return;
    }

    setState(() => _sending = true);
    try {
      final data = await context.read<AppProvider>().submitStaffShoppingReport(
        widget.scheduleId,
        photoPaths: _photos,
        totalAmount: amount,
        note: note,
        addToLedger: _toLedger && !_financeClosed && (amount ?? 0) > 0,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppSnack.error(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppSnack.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final unbought = _unbought;
    final muted = AppTheme.mutedText(context);

    return _SheetShell(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ส่งรายงานซื้อของ',
              style: appFont(fontSize: AppText.sizeTitle, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'ถ่ายรูปของที่ซื้อมาหรือใบเสร็จ แอดมินจะได้เห็นว่าซื้อครบ',
              style: appFont(fontSize: AppText.sizeLabel, color: muted),
            ),
            const SizedBox(height: 14),
            _PhotoGrid(
              photos: _photos,
              max: _maxPhotos,
              onAdd: _chooseSource,
              onRemove: (i) => setState(() => _photos.removeAt(i)),
            ),
            const SizedBox(height: 14),
            if (unbought.isEmpty)
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.successColor),
                  const SizedBox(width: 6),
                  Text(
                    'ติ๊กครบทุกรายการแล้ว',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  'ยังไม่ได้ติ๊ก ${unbought.length} รายการ: ${unbought.join(', ')}\nเขียนหมายเหตุบอกแอดมินด้วยว่าเพราะอะไร',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningColor,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              decoration: _fieldDecoration(
                unbought.isEmpty ? 'หมายเหตุ (ถ้ามี)' : 'หมายเหตุ (ต้องกรอก)',
                hint: 'เช่น น้ำแข็งหมด ไปซื้อที่ปั๊มแทน',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration('ยอดที่จ่ายไป (ถ้ามี)', suffix: 'บาท'),
            ),
            if (!_financeClosed && _amount.text.trim().isNotEmpty)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _toLedger,
                onChanged: (v) => setState(() => _toLedger = v),
                title: Text(
                  'ลงบัญชีหน้างานให้ด้วย',
                  style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  // กันลงซ้ำ — คนที่จดในบัญชีหน้างานไปแล้วต้องปิดสวิตช์นี้
                  'ใช้รูปแรกเป็นสลิป ถ้าจดในบัญชีหน้างานไปแล้วให้ปิดไว้ จะได้ไม่ซ้ำ',
                  style: appFont(fontSize: AppText.sizeCaption, color: muted),
                ),
              ),
            const SizedBox(height: 16),
            PrimaryCTAButton(
              label: _photos.isEmpty ? 'ต้องมีรูปอย่างน้อย 1 รูป' : 'ส่งรายงานให้แอดมิน',
              icon: Icons.send_rounded,
              loading: _sending,
              onPressed: _photos.isEmpty ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<String> photos;
  final int max;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _PhotoGrid({
    required this.photos,
    required this.max,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    const size = 84.0;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < photos.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Image.file(
                  File(photos[i]),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheWidth: 252,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        if (photos.length < max)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: photos.isEmpty
                      ? AppTheme.primaryColor
                      : AppTheme.border(context),
                  width: photos.isEmpty ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, size: 22, color: AppTheme.primaryColor),
                  const SizedBox(height: 4),
                  Text(
                    photos.isEmpty ? 'ถ่ายรูป' : 'เพิ่มรูป',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
