import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../models/trip_calendar.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';
import 'trip_detail_screen.dart' show TripDetailScreen;

/// "ปฏิทินทริป" — ดูทีเดียวว่าวันไหนมีทริปอะไรออกบ้าง ไม่ต้องกดเข้าไปทีละทริป
///
/// ตารางเดือนด้านบนบอกแค่ว่าวันไหนมีรอบ (จุดสีตามสถานะที่นั่ง) ส่วนชื่อทริป
/// ราคา และที่ว่างอยู่ในรายการด้านล่าง — จอมือถือแบ่ง 7 ช่องแล้วเหลือช่องละ
/// ราว 50pt ชื่อทริปภาษาไทยใส่ลงไปไม่ได้ แตะวันในตารางเพื่อดูเฉพาะวันนั้น
///
/// ข้อมูลทั้งหมดมาจาก GET /trips/calendar (TripCalendarService ชุดเดียวกับ
/// หน้าเว็บ /calendar) ไม่ต้องล็อกอิน
class TripCalendarScreen extends StatefulWidget {
  /// "YYYY-MM" — เว้นไว้ = เดือนนี้
  final String? initialMonth;

  const TripCalendarScreen({super.key, this.initialMonth});

  @override
  State<TripCalendarScreen> createState() => _TripCalendarScreenState();
}

class _TripCalendarScreenState extends State<TripCalendarScreen> {
  final _scrollController = ScrollController();
  final _monthStripController = ScrollController();
  final _agendaKey = GlobalKey();
  final Map<String, GlobalKey> _monthChipKeys = {};

  /// เดือนที่โหลดแล้วในรอบที่เปิดหน้านี้ — สลับเดือนไปมาไม่ต้องรอโหลดใหม่
  /// ดึงลงเพื่อรีเฟรชจะล้างทิ้งทั้งหมด เพราะที่นั่งเปลี่ยนได้ตลอด
  final Map<String, TripCalendarMonth> _cache = {};

  TripCalendarMonth? _data;

  /// เดือนที่ผู้ใช้เลือกล่าสุด (อาจยังโหลดไม่เสร็จ) — ชิปเดือนไฮไลต์ตามค่านี้
  String? _month;
  bool _loading = true;
  String? _error;
  DateTime? _selectedDay;
  CalendarDestination _destination = CalendarDestination.all;

  /// กันคำตอบเก่ามาทับ — กดเปลี่ยนเดือนรัว ๆ แล้วเดือนที่ขอไว้ก่อนตอบทีหลัง
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _month = parseCalendarMonth(widget.initialMonth) != null
        ? widget.initialMonth
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(_month));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _monthStripController.dispose();
    super.dispose();
  }

  ApiClient get _api => context.read<AppProvider>().api;

  Future<void> _load(String? month, {bool force = false}) async {
    final cached = month == null ? null : _cache[month];
    if (cached != null && !force) {
      _requestSeq++;
      setState(() {
        _data = cached;
        _month = cached.month;
        _loading = false;
        _error = null;
        _selectedDay = null;
      });
      _revealMonthChip();
      return;
    }

    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
      _selectedDay = null;
    });
    try {
      final res = await _api.get('trips/calendar', query: {'month': ?month});
      final data = TripCalendarMonth.fromJson(_api.data(res));
      if (!mounted || seq != _requestSeq) return;
      if (data == null) throw const FormatException('calendar payload');
      setState(() {
        _cache[data.month] = data;
        _data = data;
        // ขอเดือนที่ไกลเกินไป เซิร์ฟเวอร์ตอบเดือนสุดท้ายที่เปิดขายแทน
        _month = data.month;
        _loading = false;
      });
      _revealMonthChip();
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = e is ApiException && e.message.trim().isNotEmpty
            ? e.message
            : 'โหลดปฏิทินไม่สำเร็จ ลองอีกครั้ง';
      });
    }
  }

  Future<void> _refresh() async {
    _cache.clear();
    await _load(_month, force: true);
  }

  void _selectMonth(String month) {
    // เดือนเดิม — แสดงอยู่แล้วหรือกำลังโหลดอยู่ (แตะซ้ำได้เฉพาะตอนโหลดพลาด)
    if (month == _month && _error == null) return;
    HapticFeedback.selectionClick();
    setState(() => _month = month);
    _load(month);
  }

  void _stepMonth(int delta) {
    final data = _data;
    if (data == null) return;
    final index = data.months.indexWhere((m) => m.value == _month);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= data.months.length) return;
    _selectMonth(data.months[target].value);
  }

  void _setDestination(CalendarDestination value) {
    if (value == _destination) return;
    HapticFeedback.selectionClick();
    setState(() {
      _destination = value;
      // วันที่เลือกไว้ไม่เหลือรอบหลังกรอง — กลับไปดูทั้งเดือนแทนหน้าว่าง
      final selected = _selectedDay;
      if (selected != null &&
          !(_data
                  ?.daysFor(value)
                  .any((d) => isSameCalendarDay(d.date, selected)) ??
              false)) {
        _selectedDay = null;
      }
    });
  }

  void _selectDay(DateTime day) {
    HapticFeedback.selectionClick();
    final selected = _selectedDay;
    setState(() {
      _selectedDay = selected != null && isSameCalendarDay(selected, day)
          ? null
          : day;
    });
    if (_selectedDay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealAgenda());
    }
  }

  void _clearDay() {
    HapticFeedback.selectionClick();
    setState(() => _selectedDay = null);
  }

  /// เลื่อนลงแค่พอให้เห็นรอบของวันที่เพิ่งแตะ โดยตารางยังอยู่บนจอให้มากที่สุด —
  /// ถ้ารายการของวันนั้นยาวเกินจอ ให้หัวรายการชิดขอบบนแทน
  void _revealAgenda() {
    if (!mounted || !_scrollController.hasClients) return;
    final box = _agendaKey.currentContext?.findRenderObject();
    if (box == null || !box.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final position = _scrollController.position;
    final topAligned = viewport.getOffsetToReveal(box, 0).offset;
    final bottomAligned = viewport.getOffsetToReveal(box, 1).offset;
    final target = (topAligned < bottomAligned ? topAligned : bottomAligned)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target <= position.pixels + 1) return;
    if (MediaQuery.of(context).disableAnimations) {
      position.jumpTo(target);
      return;
    }
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// ชิปเดือนที่เลือกต้องอยู่บนจอ — เลือกเดือนท้าย ๆ ด้วยลูกศรแล้วชิปหลุดขอบขวา
  /// คำนวณเฉพาะแถบแนวนอน (ensureVisible จะไปเลื่อนหน้าแนวตั้งด้วย)
  void _revealMonthChip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_monthStripController.hasClients) return;
      final chip = _monthChipKeys[_month]?.currentContext?.findRenderObject();
      if (chip == null || !chip.attached) return;
      final viewport = RenderAbstractViewport.maybeOf(chip);
      if (viewport == null) return;
      final position = _monthStripController.position;
      final target = viewport
          .getOffsetToReveal(chip, 0.5)
          .offset
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((target - position.pixels).abs() < 1) return;
      if (MediaQuery.of(context).disableAnimations) {
        position.jumpTo(target);
      } else {
        position.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _openRound(TripCalendarRound round) {
    if (round.slug.isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TripDetailScreen(slug: round.slug, initialScheduleId: round.id),
      ),
    );
  }

  bool get _showDestinationChips {
    final data = _data;
    if (data == null) return false;
    // ฝั่งที่เลือกค้างไว้ต้องยังกดออกได้ แม้เดือนนี้จะมีแค่ฝั่งเดียว
    return data.hasBothDestinations || _destination != CalendarDestination.all;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
        title: Text('ปฏิทินทริป', style: AppTheme.appBarTitleStyle(context)),
      ),
      body: data == null
          ? (_error != null
                ? ScrollableEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: _error!,
                    actionLabel: 'ลองอีกครั้ง',
                    onAction: () => _load(_month, force: true),
                  )
                // อยู่ในลิสต์ที่เลื่อนไม่ได้ — โครงสูงกว่าจอเล็กก็แค่ถูกตัด ไม่ล้น
                : ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      _CalendarSkeleton(padding: EdgeInsets.all(16)),
                    ],
                  ))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _refresh,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  0,
                  4,
                  0,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                children: _buildContent(context, data),
              ),
            ),
    );
  }

  List<Widget> _buildContent(BuildContext context, TripCalendarMonth data) {
    final showingMonth = _month ?? data.month;
    final monthChips = _MonthStrip(
      controller: _monthStripController,
      months: data.months,
      selected: showingMonth,
      keyFor: (value) => _monthChipKeys.putIfAbsent(value, GlobalKey.new),
      onSelect: _selectMonth,
    );

    if (_loading) {
      return [
        monthChips,
        const _CalendarSkeleton(padding: EdgeInsets.fromLTRB(16, 12, 16, 0)),
      ];
    }
    if (_error != null) {
      return [
        monthChips,
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: EmptyStateView(
            icon: Icons.wifi_off_rounded,
            title: _error!,
            actionLabel: 'ลองอีกครั้ง',
            onAction: () => _load(_month, force: true),
          ),
        ),
      ];
    }

    final today = bangkokToday();
    final days = data.daysFor(_destination);
    final hot = data.isCurrentMonth
        ? data.hotFor(_destination)
        : const <TripCalendarRound>[];
    final selected = _selectedDay;
    final selectedDay = selected == null
        ? null
        : days.where((d) => isSameCalendarDay(d.date, selected)).firstOrNull;
    final monthIndex = data.months.indexWhere((m) => m.value == data.month);

    return [
      monthChips,
      if (_showDestinationChips)
        _DestinationChips(selected: _destination, onSelect: _setDestination),
      if (hot.isNotEmpty)
        _HotStrip(rounds: hot, hotDays: data.hotDays, onOpen: _openRound),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: _MonthGrid(
          year: data.year,
          month: data.monthNumber,
          monthLabel: data.monthLabel,
          days: days,
          today: today,
          selected: selectedDay?.date,
          onSelect: _selectDay,
          onPrevious: monthIndex > 0 ? () => _stepMonth(-1) : null,
          onNext: monthIndex >= 0 && monthIndex < data.months.length - 1
              ? () => _stepMonth(1)
              : null,
        ),
      ),
      KeyedSubtree(
        key: _agendaKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: days.isEmpty
              ? _EmptyMonth(
                  filtered:
                      _destination != CalendarDestination.all &&
                      data.days.isNotEmpty,
                  destination: _destination,
                  nextMonth: data.nextMonth,
                  onNextMonth: (value) => _selectMonth(value),
                  onClearFilter: () => _setDestination(CalendarDestination.all),
                )
              : selectedDay != null
              ? _DayAgenda(
                  days: [selectedDay],
                  today: today,
                  heading:
                      'ออกเดินทางวันที่เลือก · ${selectedDay.rounds.length} รอบ',
                  highlight: true,
                  onOpen: _openRound,
                  trailing: TextButton(
                    onPressed: _clearDay,
                    child: const Text('ดูทั้งเดือน'),
                  ),
                )
              : _DayAgenda(
                  days: days,
                  today: today,
                  heading: 'รอบเดินทางเดือน${data.monthLabel}',
                  summary: _summaryText(days),
                  onOpen: _openRound,
                ),
        ),
      ),
    ];
  }

  String _summaryText(List<TripCalendarDay> days) {
    final rounds = days.expand((d) => d.rounds).toList();
    final trips = rounds.map((r) => r.tripId).toSet().length;
    return '$trips ทริป · ${rounds.length} รอบ';
  }
}

// ── ชิปเดือน ────────────────────────────────────────────────────────────────

class _MonthStrip extends StatelessWidget {
  final ScrollController controller;
  final List<TripCalendarMonthOption> months;
  final String selected;
  final GlobalKey Function(String value) keyFor;
  final ValueChanged<String> onSelect;

  const _MonthStrip({
    required this.controller,
    required this.months,
    required this.selected,
    required this.keyFor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox(height: 4);
    return SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          for (final month in months)
            Padding(
              key: keyFor(month.value),
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(month.chipLabel),
                selected: month.value == selected,
                onSelected: (_) => onSelect(month.value),
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
  }
}

/// แถบแบ่งสามช่องเท่ากันแบบเดียวกับหน้าทริปทั้งหมด — ชิปเรียงแถวยาวเกินจอ
/// 390pt จน "ต่างประเทศ" หลุดขอบขวา
class _DestinationChips extends StatelessWidget {
  final CalendarDestination selected;
  final ValueChanged<CalendarDestination> onSelect;

  const _DestinationChips({required this.selected, required this.onSelect});

  static const _options = <(CalendarDestination, String, IconData)>[
    (CalendarDestination.all, 'ทั้งหมด', Icons.apps_rounded),
    (CalendarDestination.domestic, 'ในประเทศ', Icons.terrain_rounded),
    (
      CalendarDestination.international,
      'ต่างประเทศ',
      Icons.flight_takeoff_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            for (final (value, label, icon) in _options)
              Expanded(
                child: _DestinationSegment(
                  label: label,
                  icon: icon,
                  selected: value == selected,
                  onTap: () => onSelect(value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DestinationSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DestinationSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            // จางลงเป็นสีเดียวกันที่โปร่งใส ไม่ใช่ Colors.transparent (ดำโปร่งใส) —
            // ไม่งั้นระหว่างอนิเมชันช่องจะเป็นสีหม่นแวบหนึ่ง
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : AppTheme.mutedText(context),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    color: selected
                        ? Colors.white
                        : AppTheme.onSurface(context),
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ตารางเดือน ──────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final String monthLabel;
  final List<TripCalendarDay> days;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _MonthGrid({
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.days,
    required this.today,
    required this.selected,
    required this.onSelect,
    this.onPrevious,
    this.onNext,
  });

  static const _weekdays = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final d in days) d.date.day: d};
    final cells = monthGridCells(year, month);
    final muted = AppTheme.mutedText(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusLg),
      child: Column(
        children: [
          Row(
            children: [
              _MonthArrow(
                icon: Icons.chevron_left_rounded,
                tooltip: 'เดือนก่อนหน้า',
                onPressed: onPrevious,
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              _MonthArrow(
                icon: Icons.chevron_right_rounded,
                tooltip: 'เดือนถัดไป',
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final (i, label) in _weekdays.indexed)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                      // เสาร์–อาทิตย์สีเด่นกว่า — คนส่วนใหญ่หาทริปวันหยุด
                      color: i == 0 || i == 6 ? AppTheme.primaryColor : muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var row = 0; row < cells.length ~/ 7; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _DayCell(
                      date: cells[row * 7 + col],
                      day: cells[row * 7 + col] == null
                          ? null
                          : byDay[cells[row * 7 + col]!.day],
                      today: today,
                      selected: selected,
                      onSelect: onSelect,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          const _Legend(),
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _MonthArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: AppTheme.onSurface(context),
      disabledColor: AppTheme.mutedText(context).withValues(alpha: 0.3),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime? date;
  final TripCalendarDay? day;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  const _DayCell({
    required this.date,
    required this.day,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    if (date == null) return const SizedBox(height: 48);

    final rounds = day?.rounds ?? const <TripCalendarRound>[];
    final hasRounds = rounds.isNotEmpty;
    final isPast = date.isBefore(today);
    final isToday = isSameCalendarDay(date, today);
    final isSelected = selected != null && isSameCalendarDay(date, selected!);
    final onSurface = AppTheme.onSurface(context);

    final Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isPast) {
      textColor = AppTheme.mutedText(context).withValues(alpha: 0.4);
    } else if (hasRounds) {
      textColor = onSurface;
    } else {
      textColor = AppTheme.mutedText(context);
    }

    final cell = Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor
            : hasRounds
            ? AppTheme.tintOf(context, AppTheme.primaryColor)
            : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: isToday && !isSelected
            ? Border.all(color: AppTheme.primaryColor, width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            textScaler: TextScaler.noScaling,
            style: appFont(
              fontSize: AppText.sizeBody,
              height: 1.1,
              fontWeight: hasRounds || isToday
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 6,
            child: hasRounds
                ? _RoundDots(rounds: rounds, onPrimary: isSelected)
                : null,
          ),
        ],
      ),
    );

    final label = StringBuffer('วันที่ ${date.day}');
    if (isToday) label.write(' วันนี้');
    label.write(hasRounds ? ' มี ${rounds.length} รอบ' : ' ไม่มีรอบ');

    // excludeSemantics ตัดแอ็กชันแตะของ InkWell ข้างในทิ้งด้วย จึงต้องให้ onTap
    // ที่นี่ ไม่งั้นคนใช้ VoiceOver/TalkBack เลือกวันไม่ได้
    return Semantics(
      button: hasRounds,
      selected: isSelected,
      label: label.toString(),
      excludeSemantics: true,
      onTap: hasRounds ? () => onSelect(date) : null,
      child: hasRounds
          ? InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              onTap: () => onSelect(date),
              child: cell,
            )
          : cell,
    );
  }
}

/// สูงสุดสามจุด เรียงตามรอบในวันนั้น — มากกว่านั้นเป็นสองจุด + ตัวเลขที่เหลือ
class _RoundDots extends StatelessWidget {
  final List<TripCalendarRound> rounds;
  final bool onPrimary;

  const _RoundDots({required this.rounds, required this.onPrimary});

  @override
  Widget build(BuildContext context) {
    final overflow = rounds.length > 3;
    final shown = overflow ? rounds.take(2) : rounds;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final round in shown)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: onPrimary ? Colors.white : _statusColor(context, round),
              shape: BoxShape.circle,
            ),
          ),
        if (overflow)
          Padding(
            padding: const EdgeInsets.only(left: 1.5),
            child: Text(
              '+${rounds.length - 2}',
              textScaler: TextScaler.noScaling,
              style: appFont(
                fontSize: 8,
                height: 0.75,
                fontWeight: FontWeight.w800,
                color: onPrimary ? Colors.white : AppTheme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: appFont(
            fontSize: AppText.sizeCaption,
            color: AppTheme.mutedText(context),
          ),
        ),
      ],
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        item(AppTheme.primaryColor, 'ว่าง'),
        item(AppTheme.warningColor, 'ใกล้เต็ม'),
        item(_fullColor(context), 'เต็ม · จองคิวรอได้'),
      ],
    );
  }
}

Color _fullColor(BuildContext context) =>
    AppTheme.mutedText(context).withValues(alpha: 0.45);

Color _statusColor(BuildContext context, TripCalendarRound round) {
  if (round.isFull) return _fullColor(context);
  if (round.isLow) return AppTheme.warningColor;
  return AppTheme.primaryColor;
}

final _priceFormat = NumberFormat('#,##0.##');

String _baht(num value) => '฿${_priceFormat.format(value)}';

// ── ทริปไฟไหม้ ──────────────────────────────────────────────────────────────

class _HotStrip extends StatelessWidget {
  final List<TripCalendarRound> rounds;
  final int hotDays;
  final ValueChanged<TripCalendarRound> onOpen;

  const _HotStrip({
    required this.rounds,
    required this.hotDays,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '🔥 ทริปไฟไหม้',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  TextSpan(
                    text: '  ออกเดินทางใน $hotDays วัน · ยังมีที่ว่าง',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: rounds.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) =>
                  _HotCard(round: rounds[i], onTap: () => onOpen(rounds[i])),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotCard extends StatelessWidget {
  final TripCalendarRound round;
  final VoidCallback onTap;

  const _HotCard({required this.round, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusMd);
    return SizedBox(
      width: 272,
      child: Material(
        color: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: AppTheme.warningColor.withValues(alpha: 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Cover(url: round.coverImage, size: 84),
                    if (round.daysLeftLabel.isNotEmpty)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: _Pill(
                          text: round.daysLeftLabel,
                          color: Colors.white,
                          background: AppTheme.flashSaleColor,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        round.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        round.dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _PriceLine(round: round),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── รายการรายวัน ────────────────────────────────────────────────────────────

class _DayAgenda extends StatelessWidget {
  final List<TripCalendarDay> days;
  final DateTime today;
  final String heading;
  final String? summary;
  final Widget? trailing;
  final bool highlight;
  final ValueChanged<TripCalendarRound> onOpen;

  const _DayAgenda({
    required this.days,
    required this.today,
    required this.heading,
    required this.onOpen,
    this.summary,
    this.trailing,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ),
              if (summary != null)
                Text(
                  summary!,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ?trailing,
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final (i, day) in days.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          _DayCard(
            day: day,
            today: today,
            highlight: highlight,
            onOpen: onOpen,
          ),
        ],
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final TripCalendarDay day;
  final DateTime today;
  final bool highlight;
  final ValueChanged<TripCalendarRound> onOpen;

  const _DayCard({
    required this.day,
    required this.today,
    required this.highlight,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final diff = day.date.difference(today).inDays;
    final relative = switch (diff) {
      0 => 'วันนี้',
      1 => 'พรุ่งนี้',
      _ => '',
    };
    final hairline = AppTheme.border(context).withValues(alpha: 0.55);
    final radius = BorderRadius.circular(AppTheme.radiusLg);

    return Material(
      color: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: highlight
              ? AppTheme.primaryColor.withValues(alpha: 0.6)
              : hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    [
                      if (day.weekday.isNotEmpty) day.weekday,
                      day.dateLabel.isNotEmpty
                          ? day.dateLabel
                          : '${day.date.day}/${day.date.month}',
                    ].join(' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                if (relative.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _Pill(
                    text: relative,
                    color: AppTheme.primaryColor,
                    background: AppTheme.tintOf(context, AppTheme.primaryColor),
                  ),
                ],
              ],
            ),
          ),
          for (final (i, round) in day.rounds.indexed) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, indent: 16, color: hairline),
            _RoundRow(round: round, onTap: () => onOpen(round)),
          ],
        ],
      ),
    );
  }
}

class _RoundRow extends StatelessWidget {
  final TripCalendarRound round;
  final VoidCallback onTap;

  const _RoundRow({required this.round, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final details = [
      if (round.dateLabel.isNotEmpty) round.dateLabel,
      if ((round.durationDays ?? 0) > 1) '${round.durationDays} วัน',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: SizedBox(
                width: 56,
                height: 56,
                child: _Cover(url: round.coverImage, size: 56),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    round.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _PriceLine(round: round, wrap: true),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.mutedText(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// ราคา (ขีดฆ่าราคาเดิมถ้าลด) + ป้ายที่ว่าง + "ลดพิเศษ"
class _PriceLine extends StatelessWidget {
  final TripCalendarRound round;

  /// รายการรายวันกว้างพอให้ขึ้นบรรทัดใหม่ได้ การ์ดไฟไหม้ต้องอยู่บรรทัดเดียว
  final bool wrap;

  const _PriceLine({required this.round, this.wrap = false});

  @override
  Widget build(BuildContext context) {
    final statusColor = round.isFull
        ? AppTheme.mutedText(context)
        : round.isLow
        ? AppTheme.warningColor
        : AppTheme.primaryColor;

    final price = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: _baht(round.price),
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w800,
              color: round.isFull
                  ? AppTheme.mutedText(context)
                  : AppTheme.primaryColor,
            ),
          ),
          // การ์ดไฟไหม้แคบเกินจะใส่ราคาเดิมได้ — ถูกตัดเหลือ "฿..." ดูเหมือนบั๊ก
          if (wrap && round.originalPrice != null)
            TextSpan(
              text: '  ${_baht(round.originalPrice!)}',
              style: appFont(
                fontSize: AppText.sizeCaption,
                color: AppTheme.mutedText(context),
              ).copyWith(decoration: TextDecoration.lineThrough),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final status = _Pill(
      text: round.seatLabel,
      color: statusColor,
      background: AppTheme.tintOf(context, statusColor),
    );

    if (!wrap) {
      return Row(
        children: [
          Flexible(child: price),
          const SizedBox(width: 8),
          Flexible(child: status),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        price,
        status,
        if (round.onFlashSale)
          const _Pill(
            text: 'ลดพิเศษ',
            color: Colors.white,
            background: AppTheme.flashSaleColor,
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _Pill({
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: appFont(
          fontSize: AppText.sizeCaption,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String url;
  final double size;

  const _Cover({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(url);
    final placeholder = Container(
      color: AppTheme.subtleSurface(context),
      alignment: Alignment.center,
      child: Icon(
        Icons.landscape_rounded,
        color: AppTheme.mutedText(context).withValues(alpha: 0.5),
      ),
    );
    if (image.isEmpty) return placeholder;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: image,
      fit: BoxFit.cover,
      // ปกทริปเป็นรูปเต็มขนาด — ถอดรหัสแค่ขนาดที่วาดจริง ไม่งั้นหน้าที่มีหลาย
      // สิบรอบกินหน่วยความจำจนเครื่องรุ่นเล็กเด้ง
      memCacheWidth: (size * dpr).round(),
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

// ── สถานะว่าง / กำลังโหลด ───────────────────────────────────────────────────

class _EmptyMonth extends StatelessWidget {
  /// เดือนนี้มีรอบ แต่ตัวกรองปลายทางกรองออกหมด
  final bool filtered;
  final CalendarDestination destination;
  final TripCalendarMonthOption? nextMonth;
  final ValueChanged<String> onNextMonth;
  final VoidCallback onClearFilter;

  const _EmptyMonth({
    required this.filtered,
    required this.destination,
    required this.nextMonth,
    required this.onNextMonth,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    if (filtered) {
      final side = destination == CalendarDestination.international
          ? 'ต่างประเทศ'
          : 'ในประเทศ';
      return EmptyStateView(
        icon: Icons.filter_alt_off_rounded,
        title: 'เดือนนี้ยังไม่มีทริป$side',
        body: 'ดูทริปทั้งหมดของเดือนนี้ หรือเลือกเดือนอื่นได้เลยครับ',
        actionLabel: 'ดูทั้งหมด',
        onAction: onClearFilter,
      );
    }
    final next = nextMonth;
    return EmptyStateView(
      icon: Icons.calendar_month_rounded,
      title: 'เดือนนี้ยังไม่มีรอบเปิดจอง',
      // เดือนสุดท้ายที่เลือกได้ไม่มี "เดือนถัดไป" ให้ไปดู อย่าชวนไปหาสิ่งที่ไม่มีปุ่ม
      body: next == null
          ? 'รอบใหม่จะขึ้นที่นี่ทันทีที่เปิดจอง หรือทักทีมงานให้ช่วยจัดรอบให้ได้เลยครับ'
          : 'ลองดูเดือนถัดไป หรือทักทีมงานให้ช่วยจัดรอบให้ได้เลยครับ',
      actionLabel: next == null ? null : 'ดู${next.label}',
      onAction: next == null ? null : () => onNextMonth(next.value),
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const _CalendarSkeleton({required this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBox(
            height: 340,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < 3; i++) ...[
            SkeletonBox(
              height: 96,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
