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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _softAccent.withValues(alpha: 0.10),
                  _softAccent.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                bottom: BorderSide(color: _softAccent.withValues(alpha: 0.12)),
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

                // เวลาออกรถจริงของรอบที่เลือก — สำคัญมากเมื่อรถออกคืนก่อน
                // วันทริป (เช่น ทริปเสาร์ที่ 13 แต่รถออกศุกร์ที่ 12 เวลา 23:30)
                ..._departureTimeNotice(scheduleMaps, scheduleValue),

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

  return [
    const SizedBox(height: 12),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          Icon(
            isNightBefore ? Icons.nightlight_round : Icons.departure_board,
            size: 16,
            color: const Color(0xFFEA580C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: appFont(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF9A3412),
              ),
            ),
          ),
        ],
      ),
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
            boxShadow: [
              BoxShadow(
                color: _softAccent.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _softAccent.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
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
  late final Set<String> _expandedMonths;

  @override
  void initState() {
    super.initState();
    final groups = _groupSchedulesByMonth(widget.schedules);
    _expandedMonths = groups.map((g) => g.label).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupSchedulesByMonth(widget.schedules);
    final multiMonth = groups.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int gi = 0; gi < groups.length; gi++) ...[
          if (multiMonth) ...[
            _MonthHeader(
              label: groups[gi].label,
              isExpanded: _expandedMonths.contains(groups[gi].label),
              onTap: () => setState(() {
                final label = groups[gi].label;
                if (_expandedMonths.contains(label)) {
                  _expandedMonths.remove(label);
                } else {
                  _expandedMonths.add(label);
                }
              }),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _expandedMonths.contains(groups[gi].label)
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _chipWrap(groups[gi].schedules),
                    )
                  : const SizedBox.shrink(),
            ),
          ] else
            _chipWrap(groups[gi].schedules),
          if (multiMonth && gi < groups.length - 1)
            const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _chipWrap(List<Map<String, dynamic>> schedules) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        for (final schedule in schedules)
          _ScheduleChip(
            schedule: schedule,
            isSelected:
                widget.selectedId == int.tryParse(schedule['id'].toString()),
            regionKey: widget.regionKey,
            onTap: _asBool(schedule['is_charter']) ||
                    _isSchedulePast(schedule) ||
                    (int.tryParse(textOf(schedule['available_seats'], '0')) ?? 0) == 0
                ? null
                : () =>
                    widget.onChanged(int.tryParse(schedule['id'].toString())),
          ),
      ],
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
  return DateFormat('MMMM yyyy', 'th_TH').format(DateTime(year, month));
}

class _MonthHeader extends StatelessWidget {
  final String label;
  final bool isExpanded;
  final VoidCallback onTap;

  const _MonthHeader({
    required this.label,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              label,
              style: appFont(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: muted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: isExpanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _softAccent.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
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
                        : const Color(0xFFEF4444),
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
                                  ? const Color(0xFFF59E0B)
                                  : _softAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ว่าง $seats ที่',
                        maxLines: 1,
                        softWrap: false,
                        style: appFont(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.88)
                              : isLowSeats
                                  ? const Color(0xFFF59E0B)
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
            // Location name
            Expanded(
              child: Text(
                location.isNotEmpty ? location : 'ไม่ระบุจุดขึ้นรถ',
                style: appFont(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : _premiumText)
                      : AppTheme.onSurface(context).withValues(alpha: 0.85),
                  height: 1.3,
                ),
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
