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
      decoration: _premiumDecoration(context, radius: 16),
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
                            style: appFont(
                              color: isActive
                                  ? Colors.white
                                  : _mutedTextColor(context),
                              fontWeight: FontWeight.w800,
                              fontSize: AppText.sizeLabel,
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
                    style: appFont(
                      color: isActive
                          ? _premiumText(context)
                          : _mutedTextColor(context),
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      fontSize: AppText.sizeCaption,
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
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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
    // รอบที่บินไปไม่มีภูมิภาค/จุดขึ้นรถ — จุดนัดพบที่สนามบินมาแทนสองบรรทัดนั้น
    final isFlight = _scheduleIsFlight(schedule);
    final flightPlan = asMap(schedule['flight_plan']);
    final meetingPoint = textOf(flightPlan['meeting_point']).trim();
    final meetingTime = textOf(flightPlan['meeting_time']).trim();
    final pickupRegionLabel = isJoinTrip
        ? 'Join Trip'
        : _pickupRegionLabel(pickupPoint);
    final pickupLocationLabel = isJoinTrip
        ? 'เดินทางไปเอง · เจอกันที่จุดนัดพบ'
        : _pickupLocationLabel(pickupPoint);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _premiumDecoration(context, radius: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
                  style: appFont(
                    fontSize: AppText.sizeTitle,
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
                // รถอาจออกคืนก่อนวันทริป — แสดงเวลาออกรถจริงให้ชัดเจน
                if (scheduleDepartsAt(schedule) != null) ...[
                  const SizedBox(height: 8),
                  _SummaryMeta(
                    icon: Icons.departure_board_rounded,
                    text: 'ออกเดินทาง ${departureText(schedule)}',
                  ),
                ],
                const SizedBox(height: 8),
                if (isFlight)
                  _SummaryMeta(
                    icon: Icons.flight_takeoff_rounded,
                    text: meetingPoint.isEmpty
                        ? 'เดินทางโดยเครื่องบิน · เจอกันที่สนามบิน'
                        : 'จุดนัดพบ $meetingPoint'
                              '${meetingTime.isEmpty ? '' : ' · $meetingTime น.'}',
                  )
                else ...[
                  _SummaryMeta(
                    icon: Icons.location_on_rounded,
                    text: 'ภูมิภาค $pickupRegionLabel',
                  ),
                  const SizedBox(height: 8),
                  _SummaryMeta(
                    icon: Icons.directions_bus_filled_rounded,
                    text: 'จุดขึ้นรถ $pickupLocationLabel',
                  ),
                ],
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
  // ประเภทรถที่เลือก (รอบที่วิ่งทั้งบัสและตู้) — null = ยังไม่ได้เลือก
  final int? vehicleOptionId;
  final ValueChanged<int> onVehicleOptionChanged;
  // จุดรับที่ลูกค้าปักหมุดเอง { label, lat, lng, note } — null = ไม่ได้ใช้
  final Map<String, dynamic>? customPickup;
  final VoidCallback onCustomPickupTap;
  final VoidCallback onCustomPickupClear;

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
    required this.vehicleOptionId,
    required this.onVehicleOptionChanged,
    this.customPickup,
    required this.onCustomPickupTap,
    required this.onCustomPickupClear,
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
    // ทุกภูมิภาคของรอบนี้เป็นชิปให้สลับได้ — เดิม dropdown โชว์แค่ภูมิภาคที่
    // เลือกอยู่ จึงย้ายไปขึ้นรถภูมิภาคอื่นไม่ได้เลย
    final regionMaps = _pickupRegionOptions(pickupMaps);
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
    // รอบที่บินไปไม่มีรถวิ่งรับ — จุดนัดพบที่สนามบินมาแทนทั้งจุดขึ้นรถและหมุดเอง
    final isFlight = _scheduleIsFlight(selectedSchedule);
    // ประเภทรถของรอบ — แบบเดียวไม่ใช่ตัวเลือก มันคือรถของรอบนี้อยู่แล้ว
    final vehicleOptionMaps = asList(selectedSchedule['vehicle_options'])
        .map(asMap)
        .where((item) => int.tryParse(item['id'].toString()) != null)
        .toList();
    final showVehicleOptions =
        !isJoinTrip && !isFlight && vehicleOptionMaps.length > 1;

    // รอบที่ถูกซ่อนเพราะไม่มีจุดขึ้นรถในภูมิภาคที่เลือก — บอกไว้ ไม่งั้นลูกค้า
    // จะนึกว่ารอบนั้นหายไปเฉย ๆ
    final hiddenByRegion = allScheduleMaps.length - scheduleMaps.length;
    final selectedRegionLabel = filteredPickupMaps.isNotEmpty
        ? _pickupRegionLabel(filteredPickupMaps.first)
        : (selectedRegion ?? '');

    return _SectionShell(
      title: 'ข้อมูลการเดินทาง',
      icon: Icons.route_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldHeading(
            title: 'เลือกรอบเดินทาง',
            trailing: scheduleMaps.isEmpty ? null : '${scheduleMaps.length} รอบ',
          ),
          const SizedBox(height: 10),
          if (scheduleMaps.isEmpty)
            const _CompactNotice(
              icon: Icons.event_busy_rounded,
              text: 'ยังไม่มีรอบเดินทางที่เปิดจอง',
            )
          else
            _ScheduleDateStrip(
              schedules: scheduleMaps,
              selectedId: selectedScheduleId,
              onChanged: onScheduleChanged,
            ),
          if (hiddenByRegion > 0 && selectedRegionLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'แสดงเฉพาะรอบที่มีจุดขึ้นรถใน$selectedRegionLabel',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: _mutedTextColor(context),
              ),
            ),
          ],
          if (selectedSchedule.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RoundOverview(schedule: selectedSchedule),
          ],
          if (joinTripEnabled) ...[
            const SizedBox(height: 12),
            _JoinTripSwitch(
              selected: isJoinTrip,
              price: joinTripPrice,
              regularPrice: _asNum(selectedSchedule['price']),
              seatLabel: _joinTripSeatLabel(selectedSchedule),
              full: _joinTripIsFull(selectedSchedule),
              onChanged: onJoinTripChanged,
            ),
          ],
          if (showVehicleOptions) ...[
            const SizedBox(height: 20),
            _VehicleOptionPicker(
              options: vehicleOptionMaps,
              selectedId: vehicleOptionId,
              onChanged: onVehicleOptionChanged,
            ),
          ],
          const SizedBox(height: 20),
          if (isFlight)
            _FlightMeetingCard(schedule: selectedSchedule)
          else if (isJoinTrip)
            const _JoinTripInfoCard()
          else ...[
            _FieldHeading(
              title: 'เลือกจุดขึ้นรถ',
              trailing: pickupMaps.isEmpty ? null : '${pickupMaps.length} จุด',
            ),
            const SizedBox(height: 10),
            if (pickupMaps.isEmpty)
              const _CompactNotice(
                icon: Icons.place_outlined,
                text: 'ยังไม่มีจุดรับสำหรับรอบนี้ — ปักหมุดจุดรับของคุณได้ด้านล่าง',
              )
            else ...[
              if (regionMaps.length > 1) ...[
                _RegionChips(
                  regions: regionMaps,
                  points: pickupMaps,
                  selectedKey: selectedRegion,
                  onChanged: onRegionChanged,
                ),
                const SizedBox(height: 12),
              ],
              if (filteredPickupMaps.isEmpty)
                const _CompactNotice(
                  icon: Icons.directions_bus_outlined,
                  text: 'ยังไม่มีจุดขึ้นรถในภูมิภาคนี้',
                )
              else
                _PickupPointList(
                  key: ValueKey('pickup-list-$selectedScheduleId-$selectedRegion'),
                  points: filteredPickupMaps,
                  // ปักหมุดเองอยู่ = ยังไม่ได้ใช้จุดที่กำหนด ไม่ติ๊กจุดไหนค้างไว้
                  selectedId: customPickup == null ? selectedPickupPointId : null,
                  onChanged: onPickupChanged,
                ),
            ],
            const SizedBox(height: 12),
            _CustomPickupTile(
              customPickup: customPickup,
              pickupPoints: pickupMaps,
              basePrice: _asNum(
                selectedSchedule['effective_price'] ?? selectedSchedule['price'],
              ),
              onTap: onCustomPickupTap,
              onClear: onCustomPickupClear,
            ),
          ],
          // รอบที่บินไปอาจผูกรถไว้ในระบบเพื่องานอื่น แต่ลูกค้าไม่ได้ขึ้นคันนั้น
          if (!isJoinTrip && !isFlight && selectedVehicle.isNotEmpty) ...[
            const SizedBox(height: 20),
            _VehiclePhotoPreview(vehicle: selectedVehicle),
          ],
        ],
      ),
    );
  }
}

/// หัวข้อย่อยในการ์ด — ชื่อช่องทางซ้าย ตัวเลขสรุปเล็ก ๆ ทางขวา
class _FieldHeading extends StatelessWidget {
  final String title;
  final String? trailing;

  const _FieldHeading({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: _premiumText(context),
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              color: _mutedTextColor(context),
            ),
          ),
      ],
    );
  }
}

/// แถบวันที่เลื่อนแนวนอน แทน dropdown รอบเดินทาง — เห็นวัน เวลารถออก และที่ว่าง
/// ของทุกรอบพร้อมกัน ไม่ต้องกดเปิดดูทีละรอบ
class _ScheduleDateStrip extends StatefulWidget {
  final List<Map<String, dynamic>> schedules;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const _ScheduleDateStrip({
    required this.schedules,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  State<_ScheduleDateStrip> createState() => _ScheduleDateStripState();
}

class _ScheduleDateStripState extends State<_ScheduleDateStrip> {
  static const double _cardWidth = 88;
  static const double _gap = 8;

  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected(animate: false));
  }

  @override
  void didUpdateWidget(covariant _ScheduleDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected(animate: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// เลื่อนให้รอบที่เลือกอยู่กลางแถบ — คำนวณ offset เอง เพราะ
  /// Scrollable.ensureVisible จะลากหน้าจอแนวตั้งที่ครอบอยู่ให้ขยับตามไปด้วย
  void _revealSelected({required bool animate}) {
    if (!mounted || !_controller.hasClients) return;
    final index = widget.schedules.indexWhere(
      (s) => int.tryParse(s['id'].toString()) == widget.selectedId,
    );
    if (index < 0) return;
    final position = _controller.position;
    final target = (index * (_cardWidth + _gap) -
            (position.viewportDimension - _cardWidth) / 2)
        .clamp(0.0, position.maxScrollExtent);
    if (animate) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.schedules.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              _ScheduleDateCard(
                schedule: widget.schedules[i],
                width: _cardWidth,
                selected: int.tryParse(widget.schedules[i]['id'].toString()) ==
                    widget.selectedId,
                onTap: () {
                  final id = int.tryParse(widget.schedules[i]['id'].toString());
                  if (id == null || id == widget.selectedId) return;
                  HapticFeedback.selectionClick();
                  widget.onChanged(id);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// เวลาที่ผู้ชมคนนี้เริ่มจองรอบนี้ได้ (`booking_opens_at`) — null เมื่อเปิดแล้ว
DateTime? _bookingOpensAt(Map<String, dynamic> schedule) {
  final at = DateTime.tryParse(textOf(schedule['booking_opens_at']))?.toLocal();
  if (at == null || !at.isAfter(DateTime.now())) return null;
  return at;
}

/// "เปิด 10:00" (วันนี้) หรือ "เปิด 20 ต.ค."
String _bookingOpensShortLabel(DateTime at) {
  final now = DateTime.now();
  final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
  return sameDay
      ? 'เปิด ${DateFormat('HH:mm').format(at)}'
      : 'เปิด ${DateFormat('d MMM', 'th_TH').format(at)}';
}

class _ScheduleDateCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  const _ScheduleDateCard({
    required this.schedule,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCharter = _asBool(schedule['is_charter']);
    final date = DateTime.tryParse(textOf(schedule['departure_date']));
    final departsAt = scheduleDepartsAt(schedule);
    final seats = int.tryParse(textOf(schedule['available_seats'], '0')) ?? 0;
    // รอบที่ยังไม่ถึงเวลาเปิดจอง — BookingService จะปฏิเสธตอนกดยืนยัน จึงเลือกไม่ได้
    final opensAt = isCharter ? null : _bookingOpensAt(schedule);
    final disabled = isCharter || opensAt != null;

    final (String seatText, Color seatColor) = isCharter
        ? ('รอบเหมา', const Color(0xFF7C3AED))
        : opensAt != null
        ? (_bookingOpensShortLabel(opensAt), AppTheme.infoColor)
        : seats <= 0
        ? ('เต็มแล้ว', AppTheme.dangerColor)
        : seats <= 3
        ? ('เหลือ $seats ที่', AppTheme.warningColor)
        : ('ว่าง $seats ที่', _softAccent);

    final accent = selected ? _softAccent : _premiumText(context);

    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: width,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.selectedTint(context)
                    : AppTheme.surface(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: selected ? _softAccent : _cardBorder(context),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    date == null ? '-' : DateFormat('EEE', 'th_TH').format(date),
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                      color: selected ? _softAccent : _mutedTextColor(context),
                    ),
                  ),
                  Text(
                    date == null ? '-' : '${date.day}',
                    style: appFont(
                      fontSize: AppText.sizeH1,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    date == null
                        ? ''
                        : '${DateFormat('MMM', 'th_TH').format(date)} '
                              '${(date.year + 543) % 100}',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    departsAt == null
                        ? 'ไม่ระบุเวลา'
                        : 'ออก ${DateFormat('HH:mm').format(departsAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeMicro,
                      fontWeight: FontWeight.w600,
                      color: _mutedTextColor(context),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.tintOf(context, seatColor),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                    ),
                    child: Text(
                      seatText,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeMicro,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onTintOf(context, seatColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// สรุปรอบที่เลือกในบรรทัดเดียว — ช่วงวัน จำนวนวัน และเวลารถออก ถ้ารถออก
/// ก่อนวันทริป (เช่นออกคืนวันศุกร์) ขึ้นเป็นสีเตือน เพราะเป็นจุดที่คนพลาดบ่อยสุด
class _RoundOverview extends StatelessWidget {
  final Map<String, dynamic> schedule;

  const _RoundOverview({required this.schedule});

  String _rangeText(DateTime start, DateTime? end) {
    if (end == null || !end.isAfter(start)) return thaiDateShortWeekday(start);
    final sameMonth = start.month == end.month && start.year == end.year;
    final head = DateFormat(sameMonth ? 'EEE d' : 'EEE d MMM', 'th_TH').format(start);
    return '$head – ${thaiDateShortWeekday(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(textOf(schedule['departure_date']));
    if (start == null) return const SizedBox.shrink();
    final end = DateTime.tryParse(textOf(schedule['return_date']));
    final days = end == null || !end.isAfter(start)
        ? 1
        : end.difference(start).inDays + 1;
    final departsAt = scheduleDepartsAt(schedule);
    final departsEarly = _asBool(schedule['departs_before_trip_day']) &&
        departsAt != null;

    final departText = departsAt == null
        ? null
        : departsEarly
        ? 'ขึ้นรถ ${DateFormat('EEEE', 'th_TH').format(departsAt)}ที่ '
              '${thaiDateShort(departsAt)} เวลา '
              '${DateFormat('HH:mm').format(departsAt)} น. — ก่อนวันทริป'
        : 'รถออก ${DateFormat('HH:mm').format(departsAt)} น.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _fieldBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewLine(
            icon: Icons.calendar_month_rounded,
            text: _rangeText(start, end),
            // ไม่มีวันกลับ = ไม่รู้ว่ากี่วัน อย่าเดาว่าไปเช้าเย็นกลับ
            trailing: end == null ? null : '$days วัน',
          ),
          if (departText != null) ...[
            const SizedBox(height: 8),
            _OverviewLine(
              icon: departsEarly
                  ? Icons.nights_stay_rounded
                  : Icons.departure_board_rounded,
              text: departText,
              color: departsEarly ? AppTheme.warningColor : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? trailing;
  final Color? color;

  const _OverviewLine({
    required this.icon,
    required this.text,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tone = color == null ? null : AppTheme.onTintOf(context, color!);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: tone ?? _mutedTextColor(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: tone ?? _premiumText(context),
              height: 1.35,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              color: _mutedTextColor(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// ภูมิภาคเป็นชิปแตะเดียว แทน dropdown ที่มีให้เลือกแค่ไม่กี่ค่า
class _RegionChips extends StatelessWidget {
  final List<Map<String, dynamic>> regions;
  final List<Map<String, dynamic>> points;
  final String? selectedKey;
  final ValueChanged<String?> onChanged;

  const _RegionChips({
    required this.regions,
    required this.points,
    required this.selectedKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: regions.map((region) {
        final key = _pickupRegionKey(region);
        final selected = key == selectedKey;
        final count = points.where((p) => _pickupRegionKey(p) == key).length;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: selected
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onChanged(key);
                  },
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _softAccent : AppTheme.surface(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(
                  color: selected ? _softAccent : _cardBorder(context),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  text: _pickupRegionLabel(region),
                  children: [
                    TextSpan(
                      text: '  $count',
                      style: appFont(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.8)
                            : _mutedTextColor(context),
                      ),
                    ),
                  ],
                ),
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _premiumText(context),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// จุดขึ้นรถเป็นการ์ดเลือกแบบ radio — เห็นเวลาขึ้นรถ หมายเหตุ และราคาของทุกจุด
/// ในครั้งเดียว จุดเยอะเกินจะพับไว้ก่อน (จุดที่เลือกอยู่ไม่ถูกพับทิ้ง)
class _PickupPointList extends StatefulWidget {
  final List<Map<String, dynamic>> points;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const _PickupPointList({
    super.key,
    required this.points,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  State<_PickupPointList> createState() => _PickupPointListState();
}

class _PickupPointListState extends State<_PickupPointList> {
  static const int _collapsedCount = 4;

  late bool _expanded = _selectedIndex >= _collapsedCount;

  int get _selectedIndex => widget.points.indexWhere(
    (p) => int.tryParse(p['id'].toString()) == widget.selectedId,
  );

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final canCollapse = points.length > _collapsedCount + 1;
    final visible = !canCollapse || _expanded
        ? points
        : points.take(_collapsedCount).toList();
    final hiddenCount = points.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _PickupPointOption(
            point: visible[i],
            selected:
                int.tryParse(visible[i]['id'].toString()) == widget.selectedId,
            onTap: () {
              final id = int.tryParse(visible[i]['id'].toString());
              if (id == null) return;
              HapticFeedback.selectionClick();
              widget.onChanged(id);
            },
          ),
        ],
        if (canCollapse)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _expanded = !_expanded);
              },
              icon: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
              ),
              label: Text(
                _expanded ? 'ย่อรายการ' : 'ดูจุดขึ้นรถอีก $hiddenCount จุด',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: _softAccent),
            ),
          ),
      ],
    );
  }
}

class _PickupPointOption extends StatelessWidget {
  final Map<String, dynamic> point;
  final bool selected;
  final VoidCallback onTap;

  const _PickupPointOption({
    required this.point,
    required this.selected,
    required this.onTap,
  });

  Future<void> _openMap() async {
    final uri = Uri.tryParse(textOf(point['map_url']).trim());
    if (uri == null) return;
    HapticFeedback.selectionClick();
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _pickupLocationLabel(point);
    final time = textOf(point['pickup_time']).trim();
    final notes = textOf(point['notes']).trim();
    final hasMap = textOf(point['map_url']).trim().isNotEmpty;
    // ราคาจุดขึ้นรถเป็นราคาเต็มต่อคนที่ทับราคารอบ — 0 = ใช้ราคารอบตามปกติ
    final price = _asNum(point['price']);
    final originalPrice = _asNum(point['original_price']);
    final discounted = price > 0 && originalPrice > price;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.selectedTint(context)
                  : AppTheme.surface(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: selected ? _softAccent : _cardBorder(context),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? _softAccent : Colors.transparent,
                      border: Border.all(
                        color: selected ? _softAccent : AppTheme.border(context),
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location,
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w700,
                          color: _premiumText(context),
                          height: 1.3,
                        ),
                      ),
                      if (time.isNotEmpty || hasMap) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (time.isNotEmpty)
                              _PointTag(
                                icon: Icons.schedule_rounded,
                                text: 'ขึ้นรถ $time น.',
                                strong: true,
                                onTint: selected,
                              ),
                            if (hasMap)
                              _PointTag(
                                icon: Icons.map_outlined,
                                text: 'ดูแผนที่',
                                onTap: _openMap,
                              ),
                          ],
                        ),
                      ],
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w500,
                            color: _mutedTextColor(context),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // ราคา 0 = ใช้ราคารอบตามปกติ ไม่ต้องเขียนซ้ำทุกการ์ด
                if (price > 0) ...[
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (discounted)
                        Text(
                          money(originalPrice),
                          style: appFont(
                            fontSize: AppText.sizeMicro,
                            fontWeight: FontWeight.w600,
                            color: _mutedTextColor(context),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        money(price),
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w800,
                          color: selected || discounted
                              ? _softAccent
                              : _premiumText(context),
                        ),
                      ),
                      Text(
                        'ต่อคน',
                        style: appFont(
                          fontSize: AppText.sizeMicro,
                          fontWeight: FontWeight.w600,
                          color: _mutedTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PointTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool strong;
  // การ์ดที่เลือกอยู่พื้นเป็นสีเขียวอ่อนเดียวกับป้าย — ต้องสลับเป็นพื้นขาว
  // ไม่งั้นป้ายจมหายเหลือแต่ตัวหนังสือลอย ๆ
  final bool onTint;
  final VoidCallback? onTap;

  const _PointTag({
    required this.icon,
    required this.text,
    this.strong = false,
    this.onTint = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = strong
        ? AppTheme.onTintOf(context, _softAccent)
        : _mutedTextColor(context);
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onTint
            ? AppTheme.surface(context)
            : strong
            ? AppTheme.tintOf(context, _softAccent)
            : _fieldBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        border: strong ? null : Border.all(color: _cardBorder(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return tag;
    // ขยายพื้นที่แตะขึ้นลงโดยไม่เปลี่ยนหน้าตาป้าย — ป้ายสูงแค่ ~20dp
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: tag,
      ),
    );
  }
}

/// สิ่งที่มาแทนขั้นตอน "เลือกจุดขึ้นรถ" ในรอบที่บินไป — บอกว่าเจอกันที่ไหน
/// กี่โมง แทนที่จะขอให้ลูกค้าปักหมุดจุดรับซึ่งไม่มีรถไปรับอยู่แล้ว
///
/// รอบเปิดขายได้ก่อนที่ตั๋วจะออก จุดนัดพบ/ขาบินจึงอาจยังว่าง — กรณีนั้นยังต้อง
/// บอกให้ชัดว่ารอบนี้บิน ไม่ใช่เงียบไปเฉย ๆ จนลูกค้าเดาเอง
class _FlightMeetingCard extends StatelessWidget {
  final Map<String, dynamic> schedule;

  const _FlightMeetingCard({required this.schedule});

  /// "2026-09-05 06:10:00" → "5 ก.ย. 06:10" (เวลาตามที่ทีมงานกรอก ไม่แปลงเขตเวลา)
  String _legTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    return '${thaiDateShort(parsed)} '
        '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  List<Widget> _legLines(BuildContext context, String label, List<dynamic> raw) {
    final legs = raw.map(asMap).toList();
    if (legs.isEmpty) return const [];

    return [
      const SizedBox(height: 12),
      Text(
        label,
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w700,
          color: _mutedTextColor(context),
        ),
      ),
      ...legs.map((leg) {
        final title = [
          textOf(leg['airline']).trim(),
          textOf(leg['flight_no']).trim(),
        ].where((s) => s.isNotEmpty).join(' ');
        final route = [
          textOf(leg['from']).trim(),
          textOf(leg['to']).trim(),
        ].where((s) => s.isNotEmpty).join(' → ');
        final times = [
          if (_legTime(textOf(leg['depart_at'])).isNotEmpty)
            'ออก ${_legTime(textOf(leg['depart_at']))}',
          if (_legTime(textOf(leg['arrive_at'])).isNotEmpty)
            'ถึง ${_legTime(textOf(leg['arrive_at']))}',
        ].join(' · ');

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.flight_rounded,
                size: 14,
                color: _mutedTextColor(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [title, route].where((s) => s.isNotEmpty).join(' · '),
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w800,
                        color: _premiumText(context),
                      ),
                    ),
                    if (times.isNotEmpty)
                      Text(
                        times,
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w600,
                          color: _mutedTextColor(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final plan = asMap(schedule['flight_plan']);
    final meetingPoint = textOf(plan['meeting_point']).trim();
    final meetingTime = textOf(plan['meeting_time']).trim();
    final mapUrl = textOf(plan['meeting_map_url']).trim();
    final baggage = textOf(plan['baggage_allowance']).trim();
    final legs = asMap(plan['legs']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fieldBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: _cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.flight_takeoff_rounded,
                size: 18,
                color: _softAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meetingTime.isEmpty
                          ? 'รอบนี้เดินทางโดยเครื่องบิน'
                          : 'นัดพบ $meetingTime น.',
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w900,
                        color: _premiumText(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meetingPoint.isNotEmpty
                          ? meetingPoint
                          : 'ไม่มีจุดขึ้นรถให้เลือก — ทีมงานจะแจ้งจุดนัดพบและ'
                                'เวลาที่สนามบินให้ก่อนวันเดินทาง',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w600,
                        color: _mutedTextColor(context),
                        height: 1.5,
                      ),
                    ),
                    if (meetingPoint.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'รอบนี้บินไป จึงไม่มีจุดขึ้นรถให้เลือก',
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w600,
                          color: _mutedTextColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (mapUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  final uri = Uri.tryParse(mapUrl);
                  if (uri == null) return;
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.map_rounded, size: 16),
                label: Text(
                  'เปิดแผนที่จุดนัดพบ',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _softAccent,
                  side: BorderSide(color: _softAccent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
              ),
            ),
          ],
          ..._legLines(context, 'ขาไป', asList(legs['outbound'])),
          ..._legLines(context, 'ขากลับ', asList(legs['return'])),
          if (baggage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.luggage_rounded,
                  size: 15,
                  color: _mutedTextColor(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'กระเป๋าที่รวมในทริป: $baggage',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w600,
                      color: _mutedTextColor(context),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// ปุ่ม/การ์ดสำหรับจุดรับที่ลูกค้าปักหมุดเอง (อยู่ในเส้นทางผ่านที่รับได้)
class _CustomPickupTile extends StatelessWidget {
  final Map<String, dynamic>? customPickup;
  // ใช้หาจุดรับที่ใกล้หมุดที่สุด เพื่อบอกราคาที่จะถูกคิดจริง
  final List<Map<String, dynamic>> pickupPoints;
  final num basePrice;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _CustomPickupTile({
    required this.customPickup,
    required this.pickupPoints,
    required this.basePrice,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFB45309);
    final cp = customPickup;
    // ราคาที่จะถูกคิดจริง = ราคาจุดรับที่ใกล้หมุดที่สุด (ขั้นต่ำ = ราคารอบ)
    final nearest = cp == null
        ? null
        : _nearestPickupPoint(
            pickupPoints,
            double.tryParse('${cp['lat']}') ?? 0,
            double.tryParse('${cp['lng']}') ?? 0,
          );
    final quotedPrice = cp == null
        ? basePrice
        : _customPickupPrice(basePrice, pickupPoints, cp);
    final matchesZone = nearest != null && _asNum(nearest['price']) > basePrice;

    if (cp == null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.border(context),
              width: 1.2,
              style: BorderStyle.solid,
            ),
            color: AppTheme.subtleSurface(context),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_location_alt_rounded,
                  color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ไม่มีจุดที่สะดวก? ปักหมุดจุดรับเอง',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppTheme.mutedText(context)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: amber.withValues(alpha: 0.4), width: 1.2),
        color: amber.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_location_alt_rounded, color: amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'จุดรับที่ปักหมุดเอง',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w800,
                    color: amber,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 18, color: AppTheme.mutedText(context)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            textOf(cp['label']),
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
            ),
          ),
          if (textOf(cp['note']).trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              textOf(cp['note']),
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w500,
                color: _mutedTextColor(context),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: amber),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  matchesZone
                      ? 'คิดราคาเท่าจุดรับ ${_pickupLocationLabel(nearest)} ที่ใกล้หมุดที่สุด · ${money(quotedPrice)} / คน'
                      : 'ใช้ราคาเดียวกับรอบเดินทาง · ${money(quotedPrice)} / คน',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                    color: amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: Text(
              'แก้ไขจุดที่ปักหมุด',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// เลือกว่าจะเดินทางไปกับคันไหน — รอบเดียวกันวิ่งได้ทั้งรถบัสและรถตู้ คนละราคา
///
/// ราคาที่แสดงเป็น "ส่วนต่างต่อคน" ตรงกับที่เซิร์ฟเวอร์คิด (บวกท้ายราคาจุดขึ้นรถ)
/// ไม่ใช่ราคาเต็มของคันนั้น เพราะราคาเต็มขึ้นกับจุดที่ยังไม่ได้เลือกในขั้นนี้
class _VehicleOptionPicker extends StatelessWidget {
  final List<Map<String, dynamic>> options;
  final int? selectedId;
  final ValueChanged<int> onChanged;

  const _VehicleOptionPicker({
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  String _priceLabel(num adjustment) {
    if (adjustment == 0) return 'ราคาปกติ';
    final sign = adjustment > 0 ? '+' : '-';
    return '$sign${money(adjustment.abs())} / คน';
  }

  String _seatLabel(Map<String, dynamic> option) {
    if (_asBool(option['is_sold_out'])) return 'เต็มแล้ว';
    final available = option['available_seats'];
    if (available == null) return '';
    return 'เหลือ ${textOf(available, '0')} ที่';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'เลือกประเภทรถ',
          style: appFont(
            color: _mutedTextColor(context),
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final option in options) ...[
          _VehicleOptionTile(
            option: option,
            selected:
                int.tryParse(option['id'].toString()) == selectedId,
            priceLabel: _priceLabel(_asNum(option['price_adjustment'])),
            seatLabel: _seatLabel(option),
            onTap: () {
              final id = int.tryParse(option['id'].toString());
              if (id == null || _asBool(option['is_sold_out'])) return;
              HapticFeedback.selectionClick();
              onChanged(id);
            },
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _VehicleOptionTile extends StatelessWidget {
  final Map<String, dynamic> option;
  final bool selected;
  final String priceLabel;
  final String seatLabel;
  final VoidCallback onTap;

  const _VehicleOptionTile({
    required this.option,
    required this.selected,
    required this.priceLabel,
    required this.seatLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final soldOut = _asBool(option['is_sold_out']);
    final note = textOf(option['note']).trim();
    final imageUrl = textOf(option['image_url']).trim();

    return Opacity(
      opacity: soldOut ? 0.55 : 1,
      child: InkWell(
        onTap: soldOut ? null : onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? _softAccent.withValues(alpha: 0.10)
                : _fieldBackground(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: selected
                  ? _softAccent.withValues(alpha: 0.28)
                  : _cardBorder(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? _softAccent : _mutedTextColor(context),
                size: 22,
              ),
              const SizedBox(width: 10),
              if (imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Image.network(
                    imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    cacheWidth: 144,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textOf(option['label']),
                      style: appFont(
                        color: _premiumText(context),
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          color: _mutedTextColor(context),
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (seatLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        seatLabel,
                        style: appFont(
                          color: soldOut ? AppTheme.dangerColor : _softAccent,
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                priceLabel,
                style: appFont(
                  color: selected ? _softAccent : _premiumText(context),
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// มาแทนขั้นตอน "เลือกจุดขึ้นรถ" เมื่อเปิดจอยทริป — ลูกค้าไม่ได้นั่งรถทีม
/// จึงต้องบอกให้ชัดว่าไปเองแล้วต้องทำอะไรต่อ แทนที่จะปล่อยช่องว่างไว้
class _JoinTripInfoCard extends StatelessWidget {
  const _JoinTripInfoCard();

  static const _steps = [
    (
      icon: Icons.directions_walk_rounded,
      title: 'เดินทางไปเองถึงจุดนัดพบ',
      detail: 'ไม่ต้องเลือกจุดขึ้นรถหรือที่นั่งบนรถ',
    ),
    (
      icon: Icons.campaign_outlined,
      title: 'รับข้อมูลจุดนัดพบและเวลานัด',
      detail: 'ทีมงานจะแจ้งให้ทราบก่อนวันเดินทาง',
    ),
    (
      icon: Icons.qr_code_2_rounded,
      title: 'เช็คอินด้วย QR Code',
      detail: 'ได้รับหลังทีมงานยืนยันการชำระเงิน',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fieldBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: _cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _softAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  size: 20,
                  color: _softAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'คุณเลือกจอยทริป',
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w900,
                        color: _premiumText(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'เดินทางไปเอง แล้วร่วมกิจกรรมกับกลุ่มที่จุดนัดพบ',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w600,
                        color: _mutedTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: _cardBorder(context)),
          for (final step in _steps)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(step.icon, size: 18, color: _softAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w800,
                            color: _premiumText(context),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          step.detail,
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w600,
                            color: _mutedTextColor(context),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _JoinTripSwitch extends StatelessWidget {
  final bool selected;
  final num price;

  /// ราคาแบบนั่งรถทีมของรอบเดียวกัน — ไว้เทียบในชีต "จอยทริปคืออะไร?"
  final num regularPrice;
  /// สรุปโควตาจอย เช่น "จอยแล้ว 3/10 · ว่าง 7 ที่" — ว่างไว้เมื่อไม่มีข้อมูล
  final String seatLabel;
  /// โควตาเต็มแล้ว: เปิดสวิตช์ไม่ได้ ต้องบอกให้ชัดว่าทำไม
  final bool full;
  final ValueChanged<bool> onChanged;

  const _JoinTripSwitch({
    required this.selected,
    required this.price,
    this.regularPrice = 0,
    required this.seatLabel,
    required this.full,
    required this.onChanged,
  });

  Future<void> _explain(BuildContext context) async {
    final choose = await JoinTripExplainerSheet.show(
      context,
      joinPrice: price,
      regularPrice: regularPrice,
      quotaLabel: seatLabel,
      canSelect: !selected && !full,
    );
    if (choose) onChanged(true);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: full ? null : () => onChanged(!selected),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? _softAccent.withValues(alpha: 0.10)
              : _fieldBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
                    style: appFont(
                      color: _premiumText(context),
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'เดินทางไปเอง ไม่ต้องนั่งรถทีม',
                    style: appFont(
                      color: _mutedTextColor(context),
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price > 0 ? '${money(price)} / คน' : 'ราคาตามรอบเดินทาง',
                    style: appFont(
                      color: _mutedTextColor(context),
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (seatLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      seatLabel,
                      style: appFont(
                        color: full ? AppTheme.dangerColor : _softAccent,
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  // ลูกค้าถามบ่อยว่าจอยทริปคืออะไร — ลิงก์แยกจากการกดเลือก
                  // แตะตรงนี้เปิดคำอธิบาย ไม่สลับสวิตช์
                  // padding แนวตั้งให้พื้นที่แตะสูงราว 40 โดยไม่ดันการ์ดให้สูงขึ้นมาก
                  InkWell(
                    onTap: () => _explain(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: AppTheme.onTintOf(
                              context,
                              AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'จอยทริปคืออะไร?',
                            style: appFont(
                              color: AppTheme.onTintOf(
                                context,
                                AppTheme.primaryColor,
                              ),
                              fontSize: AppText.sizeLabel,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: selected,
              onChanged: full ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
