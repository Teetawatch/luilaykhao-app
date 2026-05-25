part of 'booking_flow_screen.dart';

class BookingProgressStepper extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const BookingProgressStepper({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = AppTheme.border(context).withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _premiumDecoration(context, radius: 24),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == currentStep;
          final isDone = index < currentStep;
          final isConnectorDone = index < currentStep - 1 ||
              (index == currentStep - 1 && index < steps.length - 1);

          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive || isDone
                        ? _softAccent
                        : _fieldBackground(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive || isDone ? _softAccent : borderColor,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: _softAccent.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: Colors.white,
                          )
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.anuphan(
                              color: isActive
                                  ? Colors.white
                                  : _mutedTextColor(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    steps[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: isActive
                          ? _premiumText(context)
                          : _mutedTextColor(context),
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (index != steps.length - 1)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 18,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isConnectorDone ? _softAccent : borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class TripSummaryCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final Map<String, dynamic> schedule;
  final Map<String, dynamic> pickupPoint;
  final num pricePerTraveler;
  final bool isJoinTrip;

  const TripSummaryCard({
    super.key,
    required this.trip,
    required this.schedule,
    required this.pickupPoint,
    required this.pricePerTraveler,
    required this.isJoinTrip,
  });

  @override
  Widget build(BuildContext context) {
    final imageCacheSize = _cacheSizeFor(context, width: 104, height: 116);
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final pickupRegionLabel = isJoinTrip
        ? 'Join Trip'
        : _pickupRegionLabel(pickupPoint);
    final pickupLocationLabel = isJoinTrip
        ? 'รวมกลุ่มเดินทางตามเงื่อนไขรอบนี้'
        : _pickupLocationLabel(pickupPoint);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _premiumDecoration(context, radius: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 104,
                height: 116,
                child: image.isEmpty
                    ? const _TripImageFallback()
                    : CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        memCacheWidth: imageCacheSize.width,
                        memCacheHeight: imageCacheSize.height,
                        maxWidthDiskCache: imageCacheSize.width,
                        maxHeightDiskCache: imageCacheSize.height,
                        fadeInDuration: const Duration(milliseconds: 120),
                        fadeOutDuration: Duration.zero,
                        useOldImageOnUrlChange: true,
                        filterQuality: FilterQuality.low,
                        placeholder: (_, _) => const _TripImageFallback(),
                        errorWidget: (_, _, _) => const _TripImageFallback(),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ทริปที่เลือก', style: _labelStyle(context)),
                const SizedBox(height: 4),
                Text(
                  textOf(trip['title'], '-'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: _premiumText(context),
                  ),
                ),
                const SizedBox(height: 12),
                _SummaryMeta(
                  icon: Icons.calendar_month_rounded,
                  text: 'วันที่เดินทาง ${dateText(schedule['departure_date'])}',
                ),
                const SizedBox(height: 8),
                _SummaryMeta(
                  icon: Icons.location_on_rounded,
                  text: 'ภูมิภาค $pickupRegionLabel',
                ),
                const SizedBox(height: 8),
                _SummaryMeta(
                  icon: Icons.directions_bus_filled_rounded,
                  text: 'จุดขึ้นรถ $pickupLocationLabel',
                ),
                const SizedBox(height: 8),
                _SummaryMeta(
                  icon: Icons.payments_rounded,
                  text: 'ราคาต่อคน ${money(pricePerTraveler)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TravelInfoSection extends StatelessWidget {
  final int? scheduleId;
  final List<dynamic> schedules;
  final bool isJoinTrip;
  final String? pickupRegion;
  final int? pickupPointId;
  final List<dynamic> pickupPoints;
  final ValueChanged<int?> onScheduleChanged;
  final ValueChanged<bool> onJoinTripChanged;
  final ValueChanged<String?> onRegionChanged;
  final ValueChanged<int?> onPickupChanged;

  const TravelInfoSection({
    super.key,
    required this.scheduleId,
    required this.schedules,
    required this.isJoinTrip,
    required this.pickupRegion,
    required this.pickupPointId,
    required this.pickupPoints,
    required this.onScheduleChanged,
    required this.onJoinTripChanged,
    required this.onRegionChanged,
    required this.onPickupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final allScheduleMaps = schedules
        .map(asMap)
        .where((item) => int.tryParse(item['id'].toString()) != null)
        .toList();
    final currentPickupMaps = pickupPoints
        .map(asMap)
        .where((item) => int.tryParse(item['id'].toString()) != null)
        .toList();
    final currentRegionMaps = _pickupRegionOptions(currentPickupMaps);
    final requestedRegion = pickupRegion?.trim();
    final selectedRegion = requestedRegion != null && requestedRegion.isNotEmpty
        ? requestedRegion
        : _validStringDropdownValue(
            pickupRegion,
            currentRegionMaps.map(_pickupRegionKey),
          );
    final scheduleMaps = selectedRegion == null
        ? allScheduleMaps
        : allScheduleMaps
              .where(
                (schedule) =>
                    _scheduleHasPickupRegion(schedule, selectedRegion),
              )
              .toList();
    final charterScheduleIds = scheduleMaps
        .where((s) => _asBool(s['is_charter']))
        .map((s) => int.parse(s['id'].toString()))
        .toSet();
    final selectedScheduleId = _validDropdownValue(
      scheduleId,
      scheduleMaps
          .where((item) => !charterScheduleIds.contains(int.parse(item['id'].toString())))
          .map((item) => int.parse(item['id'].toString())),
    );
    final selectedSchedule = selectedScheduleId == null
        ? <String, dynamic>{}
        : scheduleMaps.firstWhere(
            (item) => int.tryParse(item['id'].toString()) == selectedScheduleId,
            orElse: () => <String, dynamic>{},
          );
    final selectedVehicle = asMap(selectedSchedule['vehicle']);
    final pickupMaps = selectedSchedule.isEmpty
        ? currentPickupMaps
        : asList(selectedSchedule['pickup_points'])
              .map(asMap)
              .where((item) => int.tryParse(item['id'].toString()) != null)
              .toList();
    final regionMaps = _pickupRegionOptions(pickupMaps);
    final visibleRegionMaps = selectedRegion == null
        ? regionMaps
        : regionMaps
              .where((point) => _pickupRegionKey(point) == selectedRegion)
              .toList();
    final filteredPickupMaps = selectedRegion == null
        ? pickupMaps
        : pickupMaps
              .where((point) => _pickupRegionKey(point) == selectedRegion)
              .toList();
    final selectedPickupPointId = _validDropdownValue(
      pickupPointId,
      filteredPickupMaps.map((item) => int.parse(item['id'].toString())),
    );
    final joinTripEnabled = _asBool(selectedSchedule['join_trip_enabled']);
    final joinTripPrice = _asNum(selectedSchedule['join_trip_price']);

    return _SectionShell(
      title: 'ข้อมูลการเดินทาง',
      icon: Icons.route_rounded,
      child: Column(
        children: [
          _PremiumDropdown<int>(
            key: ValueKey('schedule-$selectedScheduleId'),
            label: 'รอบเดินทาง',
            icon: Icons.calendar_today_rounded,
            value: selectedScheduleId,
            items: scheduleMaps.map((schedule) {
              final id = int.parse(schedule['id'].toString());
              final isCharter = _asBool(schedule['is_charter']);
              return DropdownMenuItem<int>(
                value: id,
                enabled: !isCharter,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${dateText(schedule['departure_date'])}  ·  ${isCharter ? 'รอบเหมา' : 'เหลือ ${textOf(schedule['available_seats'], '0')} ที่'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCharter)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          'เหมา',
                          style: GoogleFonts.anuphan(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: onScheduleChanged,
          ),
          const SizedBox(height: 12),
          if (joinTripEnabled) ...[
            _JoinTripSwitch(
              selected: isJoinTrip,
              price: joinTripPrice,
              onChanged: onJoinTripChanged,
            ),
            const SizedBox(height: 12),
          ],
          if (isJoinTrip)
            const _CompactNotice(
              icon: Icons.groups_rounded,
              text:
                  'จองแบบ Join Trip ใช้ราคาเหมาร่วมจาก Laravel และไม่ต้องล็อกที่นั่งรถ',
            )
          else if (pickupMaps.isEmpty)
            const _CompactNotice(
              icon: Icons.place_outlined,
              text: 'ยังไม่มีจุดรับสำหรับรอบนี้',
            )
          else
            Column(
              children: [
                _PremiumDropdown<String>(
                  key: ValueKey('region-$selectedRegion'),
                  label: 'ภูมิภาคที่จะขึ้นรถ',
                  icon: Icons.travel_explore_rounded,
                  value: selectedRegion,
                  items: visibleRegionMaps.map((region) {
                    final value = _pickupRegionKey(region);
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        _pickupRegionLabel(region),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: onRegionChanged,
                ),
                const SizedBox(height: 12),
                if (filteredPickupMaps.isEmpty)
                  const _CompactNotice(
                    icon: Icons.directions_bus_outlined,
                    text: 'ยังไม่มีจุดขึ้นรถในภูมิภาคนี้',
                  )
                else
                  _PremiumDropdown<int>(
                    key: ValueKey(
                      'pickup-$selectedRegion-$selectedPickupPointId',
                    ),
                    label: 'จุดขึ้นรถ',
                    icon: Icons.directions_bus_filled_rounded,
                    value: selectedPickupPointId,
                    selectedItemBuilder: (context) =>
                        filteredPickupMaps.map((point) {
                          final location = _pickupLocationLabel(point);
                          return Text(
                            location,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: GoogleFonts.anuphan(
                              color: _premiumText(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }).toList(),
                    items: filteredPickupMaps.map((point) {
                      final id = int.parse(point['id'].toString());
                      final location = _pickupLocationLabel(point);
                      final price = _pickupPriceText(point['price']);
                      final notes = textOf(point['notes']).trim();
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              location,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.anuphan(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _premiumText(context),
                              ),
                            ),
                            Text(
                              notes.isEmpty ? price : '$notes  ·  $price',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.anuphan(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _mutedTextColor(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: onPickupChanged,
                  ),
              ],
            ),
          if (!isJoinTrip && selectedVehicle.isNotEmpty) ...[
            const SizedBox(height: 16),
            _VehiclePhotoPreview(vehicle: selectedVehicle),
          ],
        ],
      ),
    );
  }
}

class _JoinTripSwitch extends StatelessWidget {
  final bool selected;
  final num price;
  final ValueChanged<bool> onChanged;

  const _JoinTripSwitch({
    required this.selected,
    required this.price,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? _softAccent.withValues(alpha: 0.10)
              : _fieldBackground(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _softAccent.withValues(alpha: 0.28) : _cardBorder(context),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _softAccent : _mutedTextColor(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join Trip',
                    style: GoogleFonts.anuphan(
                      color: _premiumText(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price > 0 ? '${money(price)} / คน' : 'ใช้ราคาจากรอบเดินทาง',
                    style: GoogleFonts.anuphan(
                      color: _mutedTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(value: selected, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
