import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/app_snack.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';
import 'staff_check_in_screen.dart' show asList, asMap, money, textOf;

/// สมุดบัญชีหน้างานของรอบเดินทาง
///
/// ปัญหาที่แก้: ระหว่างทริปสตาฟจ่ายเงินสดย่อยๆ ตลอดทาง (ข้าว น้ำมัน ค่าเข้า)
/// แล้วมาจำทีหลังไม่ไหว หน้านี้ให้จดทันทีตอนจ่าย พร้อมถ่ายสลิป/ใบเสร็จแนบไว้
/// ยอดที่จดจะไปโผล่ในหน้ากำไรของแอดมินเลย ไม่ต้องคีย์ซ้ำ
class StaffLedgerScreen extends StatefulWidget {
  final int scheduleId;
  final String title;

  const StaffLedgerScreen({
    super.key,
    required this.scheduleId,
    required this.title,
  });

  @override
  State<StaffLedgerScreen> createState() => _StaffLedgerScreenState();
}

class _StaffLedgerScreenState extends State<StaffLedgerScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  /// null = ทั้งหมด, 'expense' / 'income' = กรองเฉพาะฝั่งนั้น
  String? _filter;

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
      final data = await context.read<AppProvider>().loadStaffLedger(
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
        _error = 'โหลดสมุดบัญชีไม่สำเร็จ';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _items =>
      asList(_data?['items']).map(asMap).toList();

  Map<String, dynamic> get _summary => asMap(_data?['summary']);

  List<Map<String, dynamic>> _categoriesFor(String kind) =>
      asList(asMap(_data?['categories'])[kind]).map(asMap).toList();

  Future<void> _openForm({Map<String, dynamic>? entry}) async {
    HapticFeedback.selectionClick();
    final saved = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LedgerFormSheet(
        scheduleId: widget.scheduleId,
        entry: entry,
        expenseCategories: _categoriesFor('expense'),
        incomeCategories: _categoriesFor('income'),
      ),
    );
    if (saved != null && mounted) setState(() => _data = saved);
  }

  Future<void> _openDetail(Map<String, dynamic> entry) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LedgerDetailSheet(entry: entry),
    );
    if (!mounted || action == null) return;

    if (action == 'edit') {
      await _openForm(entry: entry);
    } else if (action == 'delete') {
      await _delete(entry);
    }
  }

  Future<void> _delete(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'ลบรายการนี้?',
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '${textOf(entry['name'], 'รายการนี้')} · ${money(entry['amount'])}',
          style: appFont(fontSize: AppText.sizeBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('ยกเลิก', style: appFont(fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text('ลบ', style: appFont(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final data = await context.read<AppProvider>().deleteStaffLedgerEntry(
        widget.scheduleId,
        (entry['id'] as num).toInt(),
      );
      if (!mounted) return;
      setState(() => _data = data);
      AppSnack.success(context, 'ลบรายการแล้ว');
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'ลบรายการไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        // งานสตาฟชิดซ้ายทุกหน้า (ธีมรวมตั้ง centerTitle: true ไว้)
        centerTitle: false,
        title: Text(
          'บัญชีหน้างาน',
          style: appFont(
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'โหลดใหม่',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'บันทึกรายการ',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _data == null) {
      return const SkeletonList(count: 5, padding: EdgeInsets.only(top: 8));
    }
    if (_error != null) {
      return ScrollableEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'โหลดสมุดบัญชีไม่สำเร็จ',
        body: _error!,
        actionLabel: 'ลองใหม่',
        onAction: _load,
        accent: AppTheme.errorColor,
      );
    }

    final all = _items;
    final rows = _filter == null
        ? all
        : all.where((e) => textOf(e['kind'], 'expense') == _filter).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        // เผื่อที่ให้ปุ่มลอยไม่ทับรายการสุดท้าย
        96 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _LedgerSummaryCard(summary: _summary, tripTitle: widget.title),
        const SizedBox(height: 14),
        if (all.isNotEmpty) ...[
          _FilterRow(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 12),
        ],
        if (all.isEmpty)
          _EmptyLedger(onAdd: () => _openForm())
        else if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              _filter == 'income'
                  ? 'รอบนี้ยังไม่มีรายรับที่บันทึกไว้'
                  : 'รอบนี้ยังไม่มีรายจ่ายที่บันทึกไว้',
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
          )
        else
          ..._buildGroupedRows(rows),
      ],
    );
  }

  /// จัดกลุ่มตามวันที่ใช้เงิน — ทริปหลายวันจะได้ไล่ดูเป็นวันๆ
  List<Widget> _buildGroupedRows(List<Map<String, dynamic>> rows) {
    final widgets = <Widget>[];
    String? currentDate;

    for (final row in rows) {
      final date = textOf(row['spent_at']);
      if (date != currentDate) {
        currentDate = date;
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));
        widgets.add(_DayHeader(date: date, rows: rows));
        widgets.add(const SizedBox(height: 8));
      }
      widgets.add(
        _LedgerRow(entry: row, onTap: () => _openDetail(row)),
      );
      widgets.add(const SizedBox(height: 8));
    }

    return widgets;
  }
}

// ─── ส่วนหัว: ยอดสรุป ──────────────────────────────────────────

class _LedgerSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final String tripTitle;

  const _LedgerSummaryCard({required this.summary, required this.tripTitle});

  @override
  Widget build(BuildContext context) {
    final income = (summary['income_total'] as num?)?.toDouble() ?? 0;
    final expense = (summary['expense_total'] as num?)?.toDouble() ?? 0;
    final net = (summary['net'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tripTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AmountBlock(
                  label: 'รายรับหน้างาน',
                  value: money(income),
                  color: AppTheme.successColor,
                ),
              ),
              Expanded(
                child: _AmountBlock(
                  label: 'รายจ่ายหน้างาน',
                  value: money(expense),
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              children: [
                Text(
                  net < 0 ? 'จ่ายมากกว่ารับ' : 'รับมากกว่าจ่าย',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
                const Spacer(),
                Text(
                  money(net.abs()),
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    color: net < 0
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ยอดนี้ไม่รวมเงินค่าทริปที่ลูกค้าจ่ายผ่านระบบ — นับเฉพาะเงินที่เกิดขึ้นหน้างาน',
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

class _AmountBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AmountBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w700,
            color: AppTheme.mutedText(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: appFont(
            fontSize: AppText.sizeH2,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _FilterRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String? kind) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: value == kind,
        onSelected: (_) => onChanged(kind),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        label: Text(
          label,
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return Row(
      children: [
        chip('ทั้งหมด', null),
        chip('รายจ่าย', 'expense'),
        chip('รายรับ', 'income'),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String date;
  final List<Map<String, dynamic>> rows;

  const _DayHeader({required this.date, required this.rows});

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date);
    final sameDay = rows.where((e) => textOf(e['spent_at']) == date);
    final expense = sameDay
        .where((e) => textOf(e['kind'], 'expense') != 'income')
        .fold<double>(0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));

    return Row(
      children: [
        Text(
          parsed == null ? 'ไม่ระบุวันที่' : thaiDateShort(parsed),
          style: appFont(
            fontSize: AppText.sizeLabel,
            fontWeight: FontWeight.w700,
            color: AppTheme.mutedText(context),
          ),
        ),
        const Spacer(),
        if (expense > 0)
          Text(
            'จ่ายวันนี้ ${money(expense)}',
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
      ],
    );
  }
}

// ─── แถวรายการ ────────────────────────────────────────────────

/// ไอคอนประจำหมวด — หน้างานกวาดตาหาบรรทัดที่ต้องการได้เร็วกว่าอ่านตัวหนังสือ
IconData _categoryIcon(String kind, String? category) {
  if (kind == 'income') {
    return switch (category) {
      'rental' => Icons.backpack_outlined,
      'onsite_payment' => Icons.payments_outlined,
      'refund_back' => Icons.undo_rounded,
      _ => Icons.south_west_rounded,
    };
  }
  return switch (category) {
    'food' => Icons.restaurant_rounded,
    'fuel' => Icons.local_gas_station_rounded,
    'transport' => Icons.directions_bus_filled_rounded,
    'accommodation' => Icons.hotel_rounded,
    'ticket' => Icons.confirmation_number_rounded,
    'equipment' => Icons.handyman_rounded,
    'staff' => Icons.badge_outlined,
    _ => Icons.north_east_rounded,
  };
}

class _LedgerRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;

  const _LedgerRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final kind = textOf(entry['kind'], 'expense');
    final isIncome = kind == 'income';
    final color = isIncome ? AppTheme.successColor : AppTheme.errorColor;
    final category = entry['category']?.toString();
    final hasSlip = textOf(entry['slip_url']).isNotEmpty;
    final note = textOf(entry['note']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(context),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.tintOf(context, color),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(_categoryIcon(kind, category), size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textOf(entry['name'], 'ไม่มีชื่อรายการ'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              textOf(entry['category_label']),
                              textOf(entry['created_by_name']),
                              if (note.isNotEmpty) note,
                            ].where((e) => e.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(
                              fontSize: AppText.sizeCaption,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ),
                        if (hasSlip) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 14,
                            color: AppTheme.mutedText(context),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${isIncome ? '+' : '−'}${money(entry['amount'])}',
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyLedger({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 40,
            color: AppTheme.mutedText(context),
          ),
          const SizedBox(height: 12),
          Text(
            'ยังไม่มีรายการในรอบนี้',
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'จ่ายอะไรระหว่างทางก็กดบันทึกทันที ถ่ายสลิปแนบไว้ได้เลย\nจบทริปแล้วไม่ต้องมานั่งนึกว่าใช้อะไรไปบ้าง',
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: Text(
              'บันทึกรายการแรก',
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── แผ่นรายละเอียด ────────────────────────────────────────────

class _LedgerDetailSheet extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _LedgerDetailSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    final kind = textOf(entry['kind'], 'expense');
    final isIncome = kind == 'income';
    final color = isIncome ? AppTheme.successColor : AppTheme.errorColor;
    final slipUrl = textOf(entry['slip_url']);
    final note = textOf(entry['note']);
    final canEdit = entry['can_edit'] == true;
    final spentAt = DateTime.tryParse(textOf(entry['spent_at']));

    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  textOf(entry['name'], 'ไม่มีชื่อรายการ'),
                  style: appFont(
                    fontSize: AppText.sizeTitle,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${isIncome ? '+' : '−'}${money(entry['amount'])}',
                style: appFont(
                  fontSize: AppText.sizeH2,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailLine(
            label: 'ประเภท',
            value: isIncome ? 'รายรับหน้างาน' : 'รายจ่ายหน้างาน',
          ),
          if (textOf(entry['category_label']).isNotEmpty)
            _DetailLine(label: 'หมวด', value: textOf(entry['category_label'])),
          _DetailLine(
            label: 'วันที่ใช้เงิน',
            value: spentAt == null ? '-' : thaiDateShort(spentAt),
          ),
          _DetailLine(
            label: 'ผู้บันทึก',
            value: textOf(entry['created_by_name'], '-'),
          ),
          if (note.isNotEmpty) _DetailLine(label: 'โน้ต', value: note),
          if (slipUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Image.network(
                slipUrl,
                width: double.infinity,
                height: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 96,
                  alignment: Alignment.center,
                  color: AppTheme.subtleSurface(context),
                  child: Text(
                    'เปิดรูปสลิปไม่สำเร็จ ลองโหลดหน้านี้ใหม่',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (canEdit)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop('edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: Text(
                      'แก้ไข',
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop('delete'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppTheme.errorColor,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(
                      'ลบ',
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              'รายการนี้บันทึกโดยคนอื่น แก้ไขได้เฉพาะเจ้าของรายการหรือแอดมิน',
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

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── แผ่นฟอร์มบันทึก/แก้ไข ──────────────────────────────────────

class _LedgerFormSheet extends StatefulWidget {
  final int scheduleId;
  final Map<String, dynamic>? entry;
  final List<Map<String, dynamic>> expenseCategories;
  final List<Map<String, dynamic>> incomeCategories;

  const _LedgerFormSheet({
    required this.scheduleId,
    required this.entry,
    required this.expenseCategories,
    required this.incomeCategories,
  });

  @override
  State<_LedgerFormSheet> createState() => _LedgerFormSheetState();
}

class _LedgerFormSheetState extends State<_LedgerFormSheet> {
  late String _kind;
  late final TextEditingController _amountController;
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  String? _category;
  late DateTime _spentAt;
  String? _slipPath;

  /// สลิปเดิมบนเซิร์ฟเวอร์ (ตอนแก้ไข) — กดถังขยะคือสั่งลบทิ้ง
  String? _existingSlipUrl;
  bool _removeSlip = false;
  bool _saving = false;

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _kind = textOf(entry?['kind'], 'expense');
    _category = entry?['category']?.toString();
    _amountController = TextEditingController(
      text: entry == null
          ? ''
          // ตัด .0 ท้ายออกให้พิมพ์ต่อง่าย แต่คงทศนิยมจริงไว้
          : _trimAmount((entry['amount'] as num?)?.toDouble() ?? 0),
    );
    _nameController = TextEditingController(text: textOf(entry?['name']));
    _noteController = TextEditingController(text: textOf(entry?['note']));
    _existingSlipUrl = entry == null ? null : textOf(entry['slip_url']);
    _spentAt =
        DateTime.tryParse(textOf(entry?['spent_at'])) ?? DateTime.now();
  }

  static String _trimAmount(double value) {
    final text = value.toStringAsFixed(2);
    return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _categories =>
      _kind == 'income' ? widget.incomeCategories : widget.expenseCategories;

  Future<void> _pickSlip(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file != null && mounted) {
      setState(() {
        _slipPath = file.path;
        _removeSlip = false;
      });
    }
  }

  void _openSlipSource() {
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
                'ถ่ายรูปสลิป/ใบเสร็จ',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickSlip(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(
                'เลือกจากคลังรูป',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickSlip(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      // ทริปยาวสุดไม่กี่วัน — เผื่อช่วงกว้างๆ ไว้พอจดย้อนหลังได้
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null && mounted) setState(() => _spentAt = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', ''));

    if (amount == null || amount <= 0) {
      AppSnack.error(context, 'กรอกจำนวนเงินให้ถูกต้อง');
      return;
    }
    if (name.isEmpty) {
      AppSnack.error(
        context,
        _kind == 'income' ? 'ระบุว่ารับเงินจากอะไร' : 'ระบุว่าจ่ายค่าอะไร',
      );
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.selectionClick();
    try {
      final ledger = await context.read<AppProvider>().saveStaffLedgerEntry(
        widget.scheduleId,
        entryId: _isEdit ? (widget.entry!['id'] as num).toInt() : null,
        kind: _kind,
        name: name,
        amount: amount,
        category: _category,
        note: _noteController.text.trim(),
        spentAt: _dateParam(_spentAt),
        slipPath: _slipPath,
        removeSlip: _removeSlip,
      );
      if (!mounted) return;
      Navigator.of(context).pop(ledger);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
      }
    }
  }

  static String _dateParam(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isIncome = _kind == 'income';
    final accent = isIncome ? AppTheme.successColor : AppTheme.errorColor;
    final showExistingSlip =
        !_removeSlip && _slipPath == null && (_existingSlipUrl ?? '').isNotEmpty;

    return _SheetShell(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'แก้ไขรายการ' : 'บันทึกรายการ',
              style: appFont(
                fontSize: AppText.sizeTitle,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'expense',
                  icon: const Icon(Icons.north_east_rounded, size: 17),
                  label: Text(
                    'รายจ่าย',
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ButtonSegment(
                  value: 'income',
                  icon: const Icon(Icons.south_west_rounded, size: 17),
                  label: Text(
                    'รายรับ',
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (selected) => setState(() {
                _kind = selected.first;
                // หมวดคนละชุดกัน — สลับประเภทแล้วหมวดเดิมใช้ไม่ได้
                _category = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              autofocus: !_isEdit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: appFont(
                fontSize: AppText.sizeHero,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: -0.6,
              ),
              decoration: InputDecoration(
                labelText: 'จำนวนเงิน (บาท)',
                prefixText: '฿ ',
                prefixStyle: appFont(
                  fontSize: AppText.sizeH2,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: isIncome ? 'รับเงินจากอะไร' : 'จ่ายค่าอะไร',
                hintText: isIncome ? 'เช่น เก็บค่าเช่าเต็นท์' : 'เช่น ข้าวเช้าทีมงาน',
                hintStyle: appFont(
                  fontSize: AppText.sizeBody,
                  color: AppTheme.mutedText(context),
                ),
              ),
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'หมวด',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _categories)
                  ChoiceChip(
                    selected: _category == option['value'],
                    onSelected: (selected) => setState(
                      () => _category = selected
                          ? option['value']?.toString()
                          : null,
                    ),
                    showCheckmark: false,
                    label: Text(
                      textOf(option['label']),
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(
                      thaiDateShort(_spentAt),
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SlipField(
              localPath: _slipPath,
              existingUrl: showExistingSlip ? _existingSlipUrl : null,
              onPick: _openSlipSource,
              onRemove: () => setState(() {
                if (_slipPath != null) {
                  _slipPath = null;
                } else {
                  _removeSlip = true;
                }
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'โน้ต (ถ้ามี)',
                hintText: 'เช่น จ่ายสดไปก่อน ขอเบิกคืน',
                hintStyle: appFont(
                  fontSize: AppText.sizeBody,
                  color: AppTheme.mutedText(context),
                ),
              ),
              style: appFont(fontSize: AppText.sizeBody),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? 'บันทึกการแก้ไข' : 'บันทึกรายการ',
                        style: appFont(
                          fontSize: AppText.sizeSubtitle,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlipField extends StatelessWidget {
  final String? localPath;
  final String? existingUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _SlipField({
    required this.localPath,
    required this.existingUrl,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasSlip = localPath != null || (existingUrl ?? '').isNotEmpty;

    if (!hasSlip) {
      return OutlinedButton.icon(
        onPressed: onPick,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.receipt_long_rounded, size: 18),
        label: Text(
          'ถ่ายสลิป/ใบเสร็จ (ถ้ามี)',
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: localPath != null
                ? Image.file(
                    File(localPath!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    existingUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 56,
                      height: 56,
                      color: AppTheme.subtleSurface(context),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        size: 20,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              localPath != null ? 'แนบสลิปแล้ว' : 'มีสลิปอยู่แล้ว',
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
          IconButton(
            tooltip: 'เปลี่ยนรูป',
            onPressed: onPick,
            icon: const Icon(Icons.autorenew_rounded),
          ),
          IconButton(
            tooltip: 'เอาออก',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

/// กรอบแผ่นล่างที่ทุก sheet ในหน้านี้ใช้ร่วมกัน — มุมมน พื้นทึบ ไม่มีเงา
class _SheetShell extends StatelessWidget {
  final Widget child;

  const _SheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLg),
          ),
        ),
        child: child,
      ),
    );
  }
}
