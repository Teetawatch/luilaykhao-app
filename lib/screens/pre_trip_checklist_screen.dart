import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/checklist_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';

/// Personal, tickable pre-trip checklist for a confirmed booking.
///
/// Items come from the trip's `preparations` (shared) plus any personal items
/// the traveller adds. Tick state is persisted on-device per booking via
/// [ChecklistStorage]; the server independently pushes a reminder the day
/// before departure.
class PreTripChecklistScreen extends StatefulWidget {
  final String bookingRef;
  final String tripTitle;
  final List<String> preparations;
  final DateTime? departureDate;

  const PreTripChecklistScreen({
    super.key,
    required this.bookingRef,
    required this.tripTitle,
    required this.preparations,
    this.departureDate,
  });

  /// Convenience constructor that extracts everything from a booking map.
  factory PreTripChecklistScreen.fromBooking(Map<String, dynamic> booking) {
    final schedule = booking['schedule'] is Map
        ? Map<String, dynamic>.from(booking['schedule'] as Map)
        : <String, dynamic>{};
    final trip = schedule['trip'] is Map
        ? Map<String, dynamic>.from(schedule['trip'] as Map)
        : <String, dynamic>{};
    // นับถอยหลังถึงวันออกรถจริง (departs_at) ถ้ารอบนั้นกำหนดไว้
    final dep = scheduleDepartsAt(schedule) ??
        DateTime.tryParse((schedule['departure_date'] ?? '').toString());
    return PreTripChecklistScreen(
      bookingRef: (booking['booking_ref'] ?? '').toString(),
      tripTitle: (trip['title'] ?? 'ทริปของคุณ').toString(),
      preparations: _parsePreparations(trip['preparations']),
      departureDate: dep,
    );
  }

  static List<String> _parsePreparations(dynamic raw) {
    if (raw is String) {
      return raw
          .split(RegExp(r'[\r\n]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is List) {
      return raw
          .map((item) {
            if (item is String) return item.trim();
            if (item is Map) {
              final m = Map<String, dynamic>.from(item);
              return (m['title'] ??
                      m['name'] ??
                      m['label'] ??
                      m['description'] ??
                      m['desc'] ??
                      m['text'] ??
                      '')
                  .toString()
                  .trim();
            }
            return '';
          })
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  @override
  State<PreTripChecklistScreen> createState() => _PreTripChecklistScreenState();
}

class _PreTripChecklistScreenState extends State<PreTripChecklistScreen> {
  ChecklistState _state = ChecklistState.empty;
  bool _loading = true;
  final _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = await ChecklistStorage.instance.read(widget.bookingRef);
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  void _persist() {
    ChecklistStorage.instance.write(widget.bookingRef, _state);
  }

  int get _total => widget.preparations.length + _state.customItems.length;

  int get _done {
    final prepDone = widget.preparations
        .where((p) => _state.checkedPrep.contains(p))
        .length;
    final customDone = _state.customItems.where((c) => c.checked).length;
    return prepDone + customDone;
  }

  void _togglePrep(String label) {
    HapticFeedback.selectionClick();
    final next = Set<String>.from(_state.checkedPrep);
    if (!next.add(label)) next.remove(label);
    setState(() => _state = _state.copyWith(checkedPrep: next));
    _persist();
  }

  void _toggleCustom(String id) {
    HapticFeedback.selectionClick();
    final items = _state.customItems
        .map((c) => c.id == id ? c.copyWith(checked: !c.checked) : c)
        .toList();
    setState(() => _state = _state.copyWith(customItems: items));
    _persist();
  }

  void _addCustom() {
    final label = _addController.text.trim();
    if (label.isEmpty) return;
    HapticFeedback.lightImpact();
    final item = ChecklistCustomItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: label,
    );
    setState(() {
      _state = _state.copyWith(customItems: [..._state.customItems, item]);
      _addController.clear();
    });
    _persist();
  }

  void _removeCustom(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _state = _state.copyWith(
        customItems:
            _state.customItems.where((c) => c.id != id).toList(),
      );
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          const TravelSliverAppBar(title: 'เช็กของก่อนเดินทาง'),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else
            SliverToBoxAdapter(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ChecklistHeader(
                        tripTitle: widget.tripTitle,
                        departureDate: widget.departureDate,
                        done: _done,
                        total: _total,
                      ),
                      if (widget.preparations.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SectionLabel(
                          'ของที่ทริปแนะนำ',
                          count: widget.preparations.length,
                        ),
                        const SizedBox(height: 8),
                        _ChecklistCard(
                          children: [
                            for (var i = 0;
                                i < widget.preparations.length;
                                i++) ...[
                              _ChecklistRow(
                                label: widget.preparations[i],
                                checked: _state.checkedPrep
                                    .contains(widget.preparations[i]),
                                onTap: () =>
                                    _togglePrep(widget.preparations[i]),
                              ),
                              if (i < widget.preparations.length - 1)
                                const _RowDivider(),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      _SectionLabel(
                        'ของส่วนตัว',
                        count: _state.customItems.length,
                      ),
                      const SizedBox(height: 8),
                      _ChecklistCard(
                        children: [
                          for (var i = 0;
                              i < _state.customItems.length;
                              i++) ...[
                            _ChecklistRow(
                              label: _state.customItems[i].label,
                              checked: _state.customItems[i].checked,
                              onTap: () =>
                                  _toggleCustom(_state.customItems[i].id),
                              onDelete: () =>
                                  _removeCustom(_state.customItems[i].id),
                            ),
                            const _RowDivider(),
                          ],
                          _AddItemRow(
                            controller: _addController,
                            onSubmit: _addCustom,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ReminderNote(departureDate: widget.departureDate),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String? _thaiDate(DateTime? d) {
  if (d == null) return null;
  const months = [
    '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];
  return '${d.day} ${months[d.month]} ${d.year + 543}';
}

// ─── Header with progress ──────────────────────────────────────────────────

class _ChecklistHeader extends StatelessWidget {
  final String tripTitle;
  final DateTime? departureDate;
  final int done;
  final int total;

  const _ChecklistHeader({
    required this.tripTitle,
    required this.departureDate,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final allDone = total > 0 && done == total;
    final dateText = _thaiDate(departureDate);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _ProgressRing(progress: progress, allDone: allDone),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tripTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allDone
                      ? 'เตรียมของครบแล้ว พร้อมออกเดินทาง 🎒'
                      : total == 0
                          ? 'เพิ่มของที่ต้องเตรียมไว้กันลืม'
                          : 'เตรียมแล้ว $done จาก $total รายการ',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: allDone
                        ? AppTheme.primaryColor
                        : AppTheme.mutedText(context),
                    height: 1.35,
                  ),
                ),
                if (dateText != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 14,
                        color: AppTheme.mutedText(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'เดินทาง $dateText',
                        style: appFont(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double progress;
  final bool allDone;

  const _ProgressRing({required this.progress, required this.allDone});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 5,
                backgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          allDone
              ? const Icon(
                  Icons.check_rounded,
                  size: 24,
                  color: AppTheme.primaryColor,
                )
              : Text(
                  '${(progress * 100).round()}%',
                  style: appFont(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                    letterSpacing: -0.4,
                  ),
                ),
        ],
      ),
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;

  const _SectionLabel(this.label, {required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 2),
      child: Row(
        children: [
          Text(
            label,
            style: appFont(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
              letterSpacing: -0.1,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: appFont(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context).withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Grouped card ────────────────────────────────────────────────────────────

class _ChecklistCard extends StatelessWidget {
  final List<Widget> children;

  const _ChecklistCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 52,
      endIndent: 14,
      color: AppTheme.border(context).withValues(alpha: 0.45),
    );
  }
}

// ─── Checklist row ───────────────────────────────────────────────────────────

class _ChecklistRow extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ChecklistRow({
    required this.label,
    required this.checked,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              // iOS-style circular tick
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: checked
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: checked
                        ? AppTheme.primaryColor
                        : AppTheme.border(context),
                    width: 2,
                  ),
                ),
                child: checked
                    ? const Icon(Icons.check_rounded,
                        size: 15, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: appFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: checked
                        ? AppTheme.mutedText(context)
                        : AppTheme.onSurface(context),
                    decoration: checked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppTheme.mutedText(context),
                  ),
                  child: Text(label),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 20,
                    color: AppTheme.mutedText(context).withValues(alpha: 0.6),
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

// ─── Add personal item ───────────────────────────────────────────────────────

class _AddItemRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _AddItemRow({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.add_circle_outline_rounded,
            size: 24,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              style: appFont(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurface(context),
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'เพิ่มของส่วนตัว...',
                hintStyle: appFont(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText(context),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reminder note ───────────────────────────────────────────────────────────

class _ReminderNote extends StatelessWidget {
  final DateTime? departureDate;

  const _ReminderNote({required this.departureDate});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.notifications_active_outlined,
          size: 16,
          color: AppTheme.mutedText(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'เราจะส่งการแจ้งเตือนเตือนคุณเตรียมของ 1 วันก่อนเดินทาง',
            style: appFont(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
      ],
    );
  }
}
