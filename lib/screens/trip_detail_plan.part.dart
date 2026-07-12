part of 'trip_detail_screen.dart';

class TravelPlanSelectionSection extends StatelessWidget {
  final List<dynamic> schedules;
  final String? pickupRegionKey;
  final int? selectedScheduleId;
  final int? selectedPickupPointId;
  final List<dynamic> selectedPickupPoints;
  final ValueChanged<String?> onRegionChanged;
  final ValueChanged<int?> onScheduleChanged;
  final ValueChanged<int?> onPickupChanged;

  const TravelPlanSelectionSection({
    super.key,
    required this.schedules,
    this.pickupRegionKey,
    required this.selectedScheduleId,
    required this.selectedPickupPointId,
    required this.selectedPickupPoints,
    required this.onRegionChanged,
    required this.onScheduleChanged,
    required this.onPickupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final regionKey = pickupRegionKey?.trim();

    final regionMap = <String, String>{};
    for (final schedule in schedules) {
      for (final point in asList(asMap(schedule)['pickup_points'])) {
        final p = asMap(point);
        final key = _pickupRegionKey(p);
        if (key.isNotEmpty) {
          regionMap[key] ??= textOf(p['region_label'], textOf(p['region'], key));
        }
      }
    }

    final scheduleMaps = schedules
        .map(asMap)
        .where((s) =>
            int.tryParse(s['id'].toString()) != null &&
            (regionKey == null ||
                regionKey.isEmpty ||
                _scheduleHasPickupRegion(s, regionKey)))
        .toList();

    final pickupMaps = selectedPickupPoints
        .map(asMap)
        .where((point) =>
            int.tryParse(point['id'].toString()) != null &&
            (regionKey == null ||
                regionKey.isEmpty ||
                _pickupRegionKey(point) == regionKey))
        .toList();

    final regionValue = (regionKey != null && regionMap.containsKey(regionKey))
        ? regionKey
        : (regionMap.isEmpty ? null : regionMap.keys.first);

    final charterIds = scheduleMaps
        .where((s) => _asBool(s['is_charter']))
        .map((s) => int.parse(s['id'].toString()))
        .toSet();

    final bookableSchedules = scheduleMaps
        .where((item) => !charterIds.contains(int.parse(item['id'].toString())))
        .toList();

    final scheduleValue = _validDropdownValue(
      selectedScheduleId,
      bookableSchedules.map((item) => int.parse(item['id'].toString())),
    );
    final pickupValue = _validDropdownValue(
      selectedPickupPointId,
      pickupMaps.map((item) => int.parse(item['id'].toString())),
    );

    final showRegion = regionMap.length > 1;
    var stepNum = 1;
    final regionStep = showRegion ? stepNum++ : 0;
    final scheduleStep = stepNum++;
    final pickupStep = stepNum;

    return _PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.border(context).withValues(alpha: 0.4)),
              ),
            ),
            child: const _SectionHeader(
              icon: Icons.event_available_outlined,
              title: 'เลือกแผนการเดินทาง',
              subtitle: 'เลือกวันและจุดขึ้นรถที่ต้องการ',
            ),
          ),

          // ── body ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step 1 — Region (only when > 1 region exists)
                if (showRegion) ...[
                  _PlanStepLabel(step: '$regionStep', label: 'ภูมิภาคที่ขึ้นรถ'),
                  const SizedBox(height: 10),
                  _RegionPillSelector(
                    regions: regionMap,
                    selected: regionValue,
                    onChanged: onRegionChanged,
                  ),
                  const SizedBox(height: 22),
                ],

                // Step 2 — Date
                _PlanStepLabel(step: '$scheduleStep', label: 'วันเดินทาง'),
                const SizedBox(height: 10),
                if (scheduleMaps.isEmpty)
                  const _EmptySelectionNotice(
                    icon: Icons.calendar_month_outlined,
                    text: 'ยังไม่มีวันเดินทางที่เปิดจอง',
                  )
                else
                  _ScheduleDatePicker(
                    schedules: scheduleMaps,
                    selectedId: scheduleValue,
                    regionKey: regionKey,
                    onChanged: onScheduleChanged,
                  ),

                // สถานะการันตีออกเดินทางของรอบที่เลือก (waiting/almost/guaranteed)
                // + แถบความคืบหน้า เพื่อให้ลูกค้าเห็นว่ารอบนี้จะได้ออกไหม
                ..._departureStatusNotice(context, scheduleMaps, scheduleValue),

                // เวลาออกรถจริงของรอบที่เลือก — สำคัญมากเมื่อรถออกคืนก่อน
                // วันทริป (เช่น ทริปเสาร์ที่ 13 แต่รถออกศุกร์ที่ 12 เวลา 23:30)
                ..._departureTimeNotice(context, scheduleMaps, scheduleValue),

                // พยากรณ์อากาศของวันเดินทางที่เลือก (ถ้า backend มีข้อมูล —
                // เฉพาะรอบที่อยู่ในช่วงพยากรณ์ ~6 วันข้างหน้า)
                ..._weatherNotice(scheduleMaps, scheduleValue),

                // Step 3 — Pickup point
                if (scheduleMaps.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _PlanStepLabel(step: '$pickupStep', label: 'จุดขึ้นรถ'),
                  const SizedBox(height: 10),
                  if (pickupMaps.isEmpty)
                    const _EmptySelectionNotice(
                      icon: Icons.place_outlined,
                      text: 'ยังไม่มีจุดขึ้นรถสำหรับรอบนี้',
                    )
                  else
                    _PickupPointSelector(
                      points: pickupMaps,
                      selectedId: pickupValue,
                      onChanged: onPickupChanged,
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

/// แถบแจ้งเวลาออกรถจริงของรอบที่เลือก แสดงเฉพาะเมื่อรอบนั้นกำหนด departs_at
List<Widget> _departureTimeNotice(
  BuildContext context,
  List<Map<String, dynamic>> schedules,
  int? selectedId,
) {
  if (selectedId == null) return const [];

  final schedule = schedules.firstWhere(
    (s) => int.tryParse(s['id'].toString()) == selectedId,
    orElse: () => const {},
  );
  final departsAt = scheduleDepartsAt(schedule);
  if (departsAt == null) return const [];

  final tripDate = DateTime.tryParse(textOf(schedule['departure_date']));
  final isNightBefore = tripDate != null &&
      DateTime(departsAt.year, departsAt.month, departsAt.day)
          .isBefore(DateTime(tripDate.year, tripDate.month, tripDate.day));

  final label = 'ออกเดินทาง ${departureText(schedule)}'
      '${isNightBefore ? ' (คืนก่อนวันทริป)' : ''}';

  // Apple-style inline notice: systemOrange tint background + symbol, with the
  // primary label color for the text (high contrast, adapts to dark mode).
  final isDark = AppTheme.isDark(context);
  final orange = _appleOrange(isDark);

  return [
    const SizedBox(height: 12),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: orange.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: orange.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(
            isNightBefore ? Icons.nightlight_round : Icons.departure_board,
            size: 16,
            color: orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: appFont(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    ),
  ];
}

/// ระบบสถานะการันตีออกเดินทาง (Trip Status) — แสดงสถานะ 3 ระดับของรอบที่เลือก
/// พร้อมแถบความคืบหน้าไปสู่การการันตีออกเดินทาง เพื่อให้ลูกค้าเห็นภาพชัดว่ารอบนี้
/// จะได้ออกไหม และช่วยกันดันยอดให้ครบ (อ่านฟิลด์ที่ backend คำนวณให้)
List<Widget> _departureStatusNotice(
  BuildContext context,
  List<Map<String, dynamic>> schedules,
  int? selectedId,
) {
  if (selectedId == null) return const [];

  final schedule = schedules.firstWhere(
    (s) => int.tryParse(s['id'].toString()) == selectedId,
    orElse: () => const {},
  );
  if (schedule.isEmpty) return const [];

  final status = textOf(schedule['departure_status']);
  // เหมาคัน (status = null) หรือรอบที่ผ่านไปแล้ว ไม่ต้องแสดงสถานะการันตี
  if (status.isEmpty || _isSchedulePast(schedule)) return const [];

  final booked = int.tryParse(textOf(schedule['booked_seats'], '0')) ?? 0;
  final guaranteeMin =
      int.tryParse(textOf(schedule['guarantee_min_seats'], '8')) ?? 8;
  final toGuarantee =
      int.tryParse(textOf(schedule['seats_to_guarantee'], '0')) ?? 0;

  final isDark = AppTheme.isDark(context);

  final Color tint;
  final IconData icon;
  final String title;
  final String subtitle;
  switch (status) {
    case 'guaranteed':
      tint = _appleGreen(isDark);
      icon = Icons.verified_rounded;
      title = 'การันตีออกเดินทางแน่นอน';
      subtitle = 'มีผู้ร่วมทางครบแล้ว รถออกชัวร์ 100% 🎉';
      break;
    case 'almost_ready':
      tint = _appleOrange(isDark);
      icon = Icons.local_fire_department_rounded;
      title = 'อีกนิดเดียว รถตู้การันตีออก!';
      subtitle = toGuarantee > 0
          ? 'ขาดอีกเพียง $toGuarantee ที่นั่ง ก็การันตีออกเดินทางทันที'
          : 'ใกล้ครบแล้ว ชวนเพื่อนมาปิดรอบกันเถอะ';
      break;
    default: // waiting
      tint = _appleRed(isDark);
      icon = Icons.groups_rounded;
      title = 'กำลังหาเพื่อนร่วมทาง';
      subtitle = 'จองแล้ว $booked ที่นั่ง — ครบ $guaranteeMin คนเมื่อไหร่ '
          'รถออกแน่นอน ชวนเพื่อนมาช่วยกันดัน!';
  }

  final progress = guaranteeMin > 0
      ? (booked / guaranteeMin).clamp(0.0, 1.0).toDouble()
      : 0.0;

  return [
    const SizedBox(height: 12),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: Colors.white),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: appFont(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: appFont(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedText(context),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // แถบความคืบหน้าไปสู่การการันตีออกเดินทาง
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: tint.withValues(alpha: isDark ? 0.20 : 0.16),
              valueColor: AlwaysStoppedAnimation<Color>(tint),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'จองแล้ว $booked ที่นั่ง',
                style: appFont(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tint,
                ),
              ),
              Text(
                'การันตีที่ $guaranteeMin ที่นั่ง',
                style: appFont(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ];
}

/// Weather forecast for the selected departure date. Reads the `weather`
/// payload the backend attaches to a schedule (present only when the trip has
/// coordinates and the date is within the ~6-day forecast window).
List<Widget> _weatherNotice(
  List<Map<String, dynamic>> schedules,
  int? selectedId,
) {
  if (selectedId == null) return const [];

  final schedule = schedules.firstWhere(
    (s) => int.tryParse(s['id'].toString()) == selectedId,
    orElse: () => const {},
  );
  final weather = asMap(schedule['weather']);
  if (weather.isEmpty) return const [];

  return [
    const SizedBox(height: 12),
    WeatherCard(
      weather: weather,
      label: 'พยากรณ์อากาศวันที่เลือก',
      compact: true,
    ),
  ];
}

// ─── Step label ───────────────────────────────────────────────────────────────

class _PlanStepLabel extends StatelessWidget {
  final String step;
  final String label;

  const _PlanStepLabel({required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF10B981)],
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text(
              step,
              style: appFont(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: appFont(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white.withValues(alpha: 0.85) : _premiumText,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ─── Region pill selector ─────────────────────────────────────────────────────

class _RegionPillSelector extends StatelessWidget {
  final Map<String, String> regions;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _RegionPillSelector({
    required this.regions,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final entry in regions.entries) ...[
            _RegionPill(
              label: entry.value,
              isSelected: selected == entry.key,
              onTap: () => onChanged(entry.key),
            ),
            if (entry.key != regions.keys.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _RegionPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RegionPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? _softAccent
              : isDark
                  ? AppTheme.subtleSurface(context)
                  : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? _softAccent
                : AppTheme.border(context).withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: appFont(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : isDark
                    ? Colors.white.withValues(alpha: 0.75)
                    : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

// ─── Schedule date picker ─────────────────────────────────────────────────────

class _ScheduleDatePicker extends StatefulWidget {
  final List<Map<String, dynamic>> schedules;
  final int? selectedId;
  final String? regionKey;
  final ValueChanged<int?> onChanged;

  const _ScheduleDatePicker({
    required this.schedules,
    required this.selectedId,
    required this.regionKey,
    required this.onChanged,
  });

  @override
  State<_ScheduleDatePicker> createState() => _ScheduleDatePickerState();
}

class _ScheduleDatePickerState extends State<_ScheduleDatePicker> {
  // Single fixed-height horizontal strip — keeps the section height stable no
  // matter how many departures exist, and reads like a calendar date picker.
  // Month dividers are interleaved between groups so it's obvious, while
  // scrolling, that more months lie ahead.
  static const double _chipWidth = 84;
  static const double _dividerWidth = 30;
  static const double _chipSpacing = 8;

  final ScrollController _controller = ScrollController();
  late List<_StripEntry> _entries;

  // "Swipe to see more" affordance — shown only when the strip actually
  // overflows, and dismissed once the user starts scrolling.
  bool _canScroll = false;
  bool _hintDismissed = false;

  @override
  void initState() {
    super.initState();
    _entries = _buildEntries(widget.schedules);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Auto-scroll first, then start listening — otherwise the programmatic
      // jump would be mistaken for a user swipe and dismiss the hint instantly.
      _scrollToInitial();
      _refreshScrollHint();
      _controller.addListener(_onScroll);
    });
  }

  @override
  void didUpdateWidget(_ScheduleDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Region filtering can swap the schedule list out from under us. Compare by
    // CONTENT, not identity — the parent rebuilds this list on every setState
    // (e.g. just picking a date), and resetting the scroll then would yank the
    // strip back to the start under the user's finger.
    if (_scheduleSignature(oldWidget.schedules) !=
        _scheduleSignature(widget.schedules)) {
      setState(() {
        _entries = _buildEntries(widget.schedules);
        _hintDismissed = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) _controller.jumpTo(0);
        _refreshScrollHint();
      });
    }
  }

  // The ordered departure ids — changes only when the actual set of rounds
  // changes (region switch), not when an unrelated rebuild hands us a fresh
  // list with the same contents.
  String _scheduleSignature(List<Map<String, dynamic>> schedules) =>
      schedules.map((s) => s['id']).join(',');

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  // Builds the interleaved [divider, chip, chip, …, divider, chip, …] list.
  // Dividers are only added when the strip spans more than one month.
  List<_StripEntry> _buildEntries(List<Map<String, dynamic>> schedules) {
    final groups = _groupSchedulesByMonth(schedules);
    final multiMonth = groups.length > 1;
    return [
      for (final group in groups) ...[
        if (multiMonth) _StripEntry.month(group.label),
        for (final schedule in group.schedules) _StripEntry.chip(schedule),
      ],
    ];
  }

  // Sum of item + separator widths preceding [index].
  double _offsetForEntry(int index) {
    double offset = 0;
    for (int i = 0; i < index; i++) {
      offset +=
          (_entries[i].isDivider ? _dividerWidth : _chipWidth) + _chipSpacing;
    }
    return offset;
  }

  // Open on the selected date, or — if nothing is selected yet — on the first
  // bookable departure so users don't land on a row of past/full dates. Lead
  // with that month's divider so the month context is visible on open.
  void _scrollToInitial() {
    if (!_controller.hasClients || _entries.isEmpty) return;
    int idx = -1;
    if (widget.selectedId != null) {
      idx = _entries.indexWhere(
        (e) =>
            e.schedule != null &&
            int.tryParse(e.schedule!['id'].toString()) == widget.selectedId,
      );
    }
    if (idx < 0) {
      idx = _entries.indexWhere(
        (e) => e.schedule != null && !_isSchedulePast(e.schedule!),
      );
    }
    if (idx > 0 && _entries[idx - 1].isDivider) idx -= 1;
    if (idx <= 0) return;
    _controller.jumpTo(
      _offsetForEntry(idx).clamp(0.0, _controller.position.maxScrollExtent),
    );
  }

  void _refreshScrollHint() {
    if (!_controller.hasClients) return;
    final canScroll = _controller.position.maxScrollExtent > 0;
    if (canScroll != _canScroll) setState(() => _canScroll = canScroll);
  }

  // Hide the hint once the user drags the strip themselves. Checking the user
  // scroll direction ignores programmatic jumps (which stay idle).
  void _onScroll() {
    if (_hintDismissed || !_controller.hasClients) return;
    if (_controller.position.userScrollDirection != ScrollDirection.idle) {
      setState(() => _hintDismissed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) return const SizedBox.shrink();

    final muted = AppTheme.mutedText(context);
    final showHint = _canScroll && !_hintDismissed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: showHint ? 1 : 0,
            child: showHint
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.swipe_rounded, size: 14, color: muted),
                        const SizedBox(width: 5),
                        Text(
                          'เลื่อนดูวันอื่น ๆ',
                          style: appFont(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: muted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
        SizedBox(
          height: 122,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: _chipSpacing),
            itemBuilder: (context, i) {
              final entry = _entries[i];
              if (entry.isDivider) {
                return _MonthDivider(label: entry.monthLabel!);
              }
              final schedule = entry.schedule!;
              final disabled = _asBool(schedule['is_charter']) ||
                  _isSchedulePast(schedule) ||
                  (int.tryParse(textOf(schedule['available_seats'], '0')) ??
                          0) ==
                      0;
              return _ScheduleChip(
                schedule: schedule,
                isSelected: widget.selectedId ==
                    int.tryParse(schedule['id'].toString()),
                regionKey: widget.regionKey,
                onTap: disabled
                    ? null
                    : () => widget.onChanged(
                          int.tryParse(schedule['id'].toString()),
                        ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One slot in the horizontal date strip — either an inline month divider or a
/// selectable schedule chip.
class _StripEntry {
  final String? monthLabel;
  final Map<String, dynamic>? schedule;

  const _StripEntry.month(this.monthLabel) : schedule = null;
  const _StripEntry.chip(this.schedule) : monthLabel = null;

  bool get isDivider => monthLabel != null;
}

/// Slim vertical month marker shown between month groups in the strip. The
/// label is rotated so it stays compact yet readable next to the date chips.
class _MonthDivider extends StatelessWidget {
  final String label;

  const _MonthDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    return SizedBox(
      width: _ScheduleDatePickerState._dividerWidth,
      height: 122,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 1.5,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.border(context).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Expanded(
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: muted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGroup {
  final String label;
  final List<Map<String, dynamic>> schedules;

  const _MonthGroup({required this.label, required this.schedules});
}

bool _isSchedulePast(Map<String, dynamic> schedule) {
  final date = DateTime.tryParse(textOf(schedule['departure_date']));
  if (date == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return date.isBefore(today);
}

List<_MonthGroup> _groupSchedulesByMonth(
  List<Map<String, dynamic>> schedules,
) {
  final groups = <String, List<Map<String, dynamic>>>{};

  for (final schedule in schedules) {
    final raw = textOf(schedule['departure_date']);
    final date = DateTime.tryParse(raw);
    final key = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}'
        : '0000-00';
    groups.putIfAbsent(key, () => []).add(schedule);
  }

  final sortedKeys = groups.keys.toList()..sort();

  return [
    for (final key in sortedKeys)
      _MonthGroup(
        label: _monthGroupLabel(key),
        schedules: groups[key]!
          ..sort((a, b) {
            final da = DateTime.tryParse(textOf(a['departure_date']));
            final db = DateTime.tryParse(textOf(b['departure_date']));
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          }),
      ),
  ];
}

String _monthGroupLabel(String yearMonthKey) {
  final parts = yearMonthKey.split('-');
  if (parts.length < 2) return '';
  final year = int.tryParse(parts[0]) ?? 0;
  final month = int.tryParse(parts[1]) ?? 0;
  if (year == 0 || month == 0) return '';
  return thaiMonthYear(DateTime(year, month));
}

class _ScheduleChip extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final bool isSelected;
  final String? regionKey;
  final VoidCallback? onTap;

  const _ScheduleChip({
    required this.schedule,
    required this.isSelected,
    required this.regionKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isCharter = _asBool(schedule['is_charter']);
    final departureDate = DateTime.tryParse(textOf(schedule['departure_date']));
    final returnDate = DateTime.tryParse(textOf(schedule['return_date']));
    final seats = int.tryParse(textOf(schedule['available_seats'], '0')) ?? 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isPast = departureDate != null && departureDate.isBefore(today);
    final isLowSeats = !isCharter && !isPast && seats > 0 && seats <= 5;
    final isUnavailable = isCharter || seats == 0 || isPast;

    final Color bg;
    final Color border;
    final Color fg;
    final Color sub;

    if (isSelected) {
      bg = _softAccent;
      border = _softAccent;
      fg = Colors.white;
      sub = Colors.white.withValues(alpha: 0.78);
    } else if (isUnavailable) {
      bg = isDark
          ? Colors.white.withValues(alpha: 0.04)
          : const Color(0xFFF9FAFB);
      border = AppTheme.border(context).withValues(alpha: 0.35);
      fg = AppTheme.mutedText(context).withValues(alpha: 0.40);
      sub = AppTheme.mutedText(context).withValues(alpha: 0.30);
    } else {
      bg = isDark
          ? AppTheme.subtleSurface(context)
          : const Color(0xFFF0FDF4);
      border = isDark
          ? AppTheme.border(context).withValues(alpha: 0.45)
          : _softAccent.withValues(alpha: 0.20);
      fg = isDark ? Colors.white : _premiumText;
      sub = _mutedText;
    }

    final dayLabel = departureDate != null
        ? departureDate.day.toString()
        : '?';
    final monthLabel = departureDate != null
        ? DateFormat('MMM', 'th_TH').format(departureDate)
        : '—';
    final weekdayLabel = departureDate != null
        ? _shortThaiWeekday(departureDate)
        : '';

    // Night count for multi-day trips
    String? nightsLabel;
    if (departureDate != null && returnDate != null) {
      final nights = returnDate.difference(departureDate).inDays;
      if (nights > 0) nightsLabel = '$nights คืน';
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        width: 84,
        height: 122,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Weekday (Apple Calendar-style abbreviation)
            if (weekdayLabel.isNotEmpty)
              Text(
                weekdayLabel,
                style: appFont(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: sub,
                  letterSpacing: 0.4,
                  height: 1.0,
                ),
              ),
            const SizedBox(height: 4),
            // Day number
            Text(
              dayLabel,
              style: appFont(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: fg,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            // Month abbreviation
            Text(
              monthLabel,
              style: appFont(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: sub,
                height: 1.1,
              ),
            ),
            // Duration badge — wrapped in FittedBox to guarantee it never
            // overflows the chip (e.g. "10 คืน" on long expeditions).
            if (nightsLabel != null) ...[
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.22)
                        : isDark
                            ? _softAccent.withValues(alpha: 0.14)
                            : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    nightsLabel,
                    maxLines: 1,
                    softWrap: false,
                    style: appFont(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : _softAccent,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
            // Seat count — always shown for non-charter schedules
            if (!isCharter) ...[
              const SizedBox(height: 6),
              if (isPast)
                Text(
                  'ผ่านแล้ว',
                  style: appFont(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: sub,
                  ),
                )
              else if (seats == 0)
                Text(
                  'เต็ม',
                  style: appFont(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.75)
                        : _appleRed(isDark),
                  ),
                )
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.80)
                              : isLowSeats
                                  ? _appleOrange(isDark)
                                  : _softAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        seats <= 2 ? 'เหลือ $seats ที่สุดท้าย' : 'ว่าง $seats ที่',
                        maxLines: 1,
                        softWrap: false,
                        style: appFont(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.88)
                              : isLowSeats
                                  ? _appleOrange(isDark)
                                  : sub,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            // Charter label
            if (isCharter) ...[
              const SizedBox(height: 6),
              Text(
                'เหมา',
                style: appFont(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: sub,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Apple Calendar–style Thai weekday abbreviation
/// (จ. / อ. / พ. / พฤ. / ศ. / ส. / อา.).
String _shortThaiWeekday(DateTime date) {
  const labels = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
  // DateTime.weekday: 1 = Monday … 7 = Sunday.
  return labels[date.weekday - 1];
}

// ─── Pickup point selector ────────────────────────────────────────────────────

class _PickupPointSelector extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const _PickupPointSelector({
    required this.points,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...points]
      ..sort((a, b) {
        final aOrder = int.tryParse(a['sort_order']?.toString() ?? '') ?? 0;
        final bOrder = int.tryParse(b['sort_order']?.toString() ?? '') ?? 0;
        return aOrder.compareTo(bOrder);
      });

    final selected = sorted.firstWhere(
      (p) => int.tryParse(p['id'].toString()) == selectedId,
      orElse: () => const <String, dynamic>{},
    );
    final selectedImage = ApiConfig.mediaUrl(selected['image_url']);

    return Column(
      children: [
        for (int i = 0; i < sorted.length; i++) ...[
          _PickupPointRow(
            point: sorted[i],
            isSelected:
                selectedId == int.tryParse(sorted[i]['id'].toString()),
            onTap: () =>
                onChanged(int.tryParse(sorted[i]['id'].toString())),
          ),
          if (i < sorted.length - 1) const SizedBox(height: 8),
        ],
        if (selectedImage.isNotEmpty) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: selectedImage,
              height: 170,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, _) => Container(
                height: 170,
                alignment: Alignment.center,
                color: AppTheme.subtleSurface(context),
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }
}

/// Prominent "เวลาขึ้นรถ" badge shown under a pickup point. Apple-style: a solid
/// accent capsule with a clock glyph so the departure time is the clear anchor
/// of the row, regardless of selection state.
class _PickupTimeBadge extends StatelessWidget {
  final String time;

  const _PickupTimeBadge({required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _softAccent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            'ขึ้นรถ ',
            style: appFont(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: -0.1,
            ),
          ),
          Text(
            '$time น.',
            style: appFont(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupPointRow extends StatelessWidget {
  final Map<String, dynamic> point;
  final bool isSelected;
  final VoidCallback onTap;

  const _PickupPointRow({
    required this.point,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final location = textOf(point['pickup_location']).trim();
    final time = textOf(point['pickup_time']).trim();
    final price = _pickupPriceText(point['price']);
    final hasExtra = price != 'ไม่มีค่าใช้จ่ายเพิ่ม';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? _softAccent.withValues(alpha: 0.12)
                  : const Color(0xFFF0FDF4))
              : (isDark ? AppTheme.subtleSurface(context) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _softAccent.withValues(alpha: isDark ? 0.45 : 0.55)
                : AppTheme.border(context).withValues(alpha: 0.55),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _softAccent : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? _softAccent
                      : AppTheme.border(context),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            // Location name + prominent departure time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    location.isNotEmpty ? location : 'ไม่ระบุจุดขึ้นรถ',
                    style: appFont(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? (isDark ? Colors.white : _premiumText)
                          : AppTheme.onSurface(context).withValues(alpha: 0.85),
                      height: 1.3,
                    ),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    _PickupTimeBadge(time: time),
                  ],
                ],
              ),
            ),
            // Price tag (only shown when there's an extra charge)
            if (hasExtra) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: isDark ? 0.15 : 0.75)
                      : (isDark
                          ? _softAccent.withValues(alpha: 0.12)
                          : const Color(0xFFECFDF5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  price,
                  style: appFont(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? _softAccent
                        : (isDark ? _softAccent : const Color(0xFF059669)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
