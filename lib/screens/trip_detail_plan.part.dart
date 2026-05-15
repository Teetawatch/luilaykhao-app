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

    // Collect distinct regions from all schedules
    final regionMap = <String, String>{};
    for (final schedule in schedules) {
      for (final point in asList(asMap(schedule)['pickup_points'])) {
        final p = asMap(point);
        final key = _pickupRegionKey(p);
        if (key.isNotEmpty) {
          regionMap[key] ??= textOf(
            p['region_label'],
            textOf(p['region'], key),
          );
        }
      }
    }

    final scheduleMaps = schedules
        .map(asMap)
        .where(
          (schedule) =>
              int.tryParse(schedule['id'].toString()) != null &&
              (regionKey == null ||
                  regionKey.isEmpty ||
                  _scheduleHasPickupRegion(schedule, regionKey)),
        )
        .toList();
    final pickupMaps = selectedPickupPoints
        .map(asMap)
        .where(
          (point) =>
              int.tryParse(point['id'].toString()) != null &&
              (regionKey == null ||
                  regionKey.isEmpty ||
                  _pickupRegionKey(point) == regionKey),
        )
        .toList();

    final regionValue = (regionKey != null && regionMap.containsKey(regionKey))
        ? regionKey
        : (regionMap.isEmpty ? null : regionMap.keys.first);
    final scheduleValue = _validDropdownValue(
      selectedScheduleId,
      scheduleMaps.map((item) => int.parse(item['id'].toString())),
    );
    final pickupValue = _validDropdownValue(
      selectedPickupPointId,
      pickupMaps.map((item) => int.parse(item['id'].toString())),
    );

    return _PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header with gradient accent
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Step 1 — region
                _StepDropdownRow(
                  step: '1',
                  label: 'ภูมิภาคที่ขึ้นรถ',
                  child: regionMap.isEmpty
                      ? const _EmptySelectionNotice(
                          icon: Icons.map_outlined,
                          text: 'ยังไม่มีภูมิภาคสำหรับทริปนี้',
                        )
                      : _PremiumDropdown<String>(
                          key: ValueKey('region-$regionValue'),
                          label: 'เลือกภูมิภาค',
                          icon: Icons.map_outlined,
                          value: regionValue,
                          items: regionMap.entries.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.key,
                              child: _DropdownText(title: e.value, subtitle: ''),
                            );
                          }).toList(),
                          onChanged: onRegionChanged,
                        ),
                ),
                const SizedBox(height: 14),
                // Step 2 — schedule
                _StepDropdownRow(
                  step: '2',
                  label: 'วันเดินทาง',
                  child: scheduleMaps.isEmpty
                      ? const _EmptySelectionNotice(
                          icon: Icons.calendar_month_outlined,
                          text: 'ยังไม่มีวันเดินทางที่เปิดจอง',
                        )
                      : _PremiumDropdown<int>(
                          key: ValueKey('schedule-$scheduleValue'),
                          label: 'เลือกวันเดินทาง',
                          icon: Icons.calendar_month_rounded,
                          value: scheduleValue,
                          items: scheduleMaps.map((schedule) {
                            final id = int.parse(schedule['id'].toString());
                            final seats =
                                textOf(schedule['available_seats'], '0');
                            final regionSummary =
                                _regionSummary(schedule, regionKey: regionKey);
                            return DropdownMenuItem<int>(
                              value: id,
                              child: _DropdownText(
                                title: _scheduleTravelDateText(schedule),
                                subtitle: regionSummary.isEmpty
                                    ? 'เหลือ $seats ที่นั่ง'
                                    : 'เหลือ $seats ที่ • $regionSummary',
                              ),
                            );
                          }).toList(),
                          onChanged: onScheduleChanged,
                        ),
                ),
                if (scheduleMaps.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  // Step 3 — pickup
                  _StepDropdownRow(
                    step: '3',
                    label: 'จุดขึ้นรถ',
                    child: pickupMaps.isEmpty
                        ? const _EmptySelectionNotice(
                            icon: Icons.place_outlined,
                            text: 'ยังไม่มีจุดขึ้นรถสำหรับรอบนี้',
                          )
                        : _PremiumDropdown<int>(
                            key: ValueKey('pickup-$pickupValue'),
                            label: 'เลือกจุดขึ้นรถ',
                            icon: Icons.place_rounded,
                            value: pickupValue,
                            items: pickupMaps.map((point) {
                              final id = int.parse(point['id'].toString());
                              final location =
                                  textOf(point['pickup_location']).trim();
                              final price = _pickupPriceText(point['price']);
                              return DropdownMenuItem<int>(
                                value: id,
                                child: _DropdownText(
                                  title: location.isNotEmpty
                                      ? location
                                      : 'ไม่ระบุจุดขึ้นรถ',
                                  subtitle: price,
                                ),
                              );
                            }).toList(),
                            onChanged: onPickupChanged,
                          ),
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
