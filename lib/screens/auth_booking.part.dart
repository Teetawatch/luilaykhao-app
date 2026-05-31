part of 'customer_app_screen.dart';

class AuthScreen extends StatelessWidget {
  final VoidCallback? afterLogin;

  const AuthScreen({super.key, this.afterLogin});

  @override
  Widget build(BuildContext context) {
    return LoginScreen(onLoginSuccess: afterLogin, popOnSuccess: false);
  }
}

class BookingCard extends StatefulWidget {
  final AppProvider app;

  const BookingCard({super.key, required this.app});

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  String? _selectedSlug;
  int? _selectedScheduleId;
  String? _selectedPickupRegionKey;
  Future<List<dynamic>>? _schedulesFuture;
  bool _isPackagesExpanded = false;

  @override
  void didUpdateWidget(covariant BookingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final trips = _tripOptions;
    if (_selectedSlug != null &&
        !trips.any((trip) => trip['slug']?.toString() == _selectedSlug)) {
      _selectedSlug = null;
      _selectedScheduleId = null;
      _selectedPickupRegionKey = null;
      _schedulesFuture = null;
    }
  }

  List<Map<String, dynamic>> get _tripOptions {
    return widget.app.trips
        .map(asMap)
        .where((trip) => textOf(trip['slug']).isNotEmpty)
        .toList();
  }

  void _selectTrip(String? slug) {
    if (slug == null || slug == _selectedSlug) return;
    setState(() {
      _selectedSlug = slug;
      _selectedScheduleId = null;
      _selectedPickupRegionKey = null;
      _schedulesFuture = widget.app.schedules(slug);
      _isPackagesExpanded = false; // Reset expansion on trip change
    });
  }

  @override
  Widget build(BuildContext context) {
    final trips = _tripOptions;
    Map<String, dynamic>? selectedTrip;
    for (final trip in trips) {
      if (trip['slug']?.toString() == _selectedSlug) {
        selectedTrip = trip;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20), // Standardized spacing
      decoration: _ecoCardDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(24), // Softer corners
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppTheme.accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'อยากไปเที่ยวที่ไหน?',
                style: GoogleFonts.anuphan(
                  color: AppTheme.primaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Destination Selector
          DestinationDropdown(
            slug: _selectedSlug,
            options: trips,
            onChanged: _selectTrip,
          ),

          const SizedBox(height: 12),

          // Date Selector
          DateSelectorCard(
            schedulesFuture: _schedulesFuture,
            selectedScheduleId: _selectedScheduleId,
            onChanged: (id) => setState(() {
              _selectedScheduleId = id;
            }),
            onRegionChanged: (regionKey) =>
                setState(() => _selectedPickupRegionKey = regionKey),
            app: widget.app,
            onSelectedSchedule: (schedule) {
              // This can be used if we need more info from the selected schedule
            },
            isExpanded: _isPackagesExpanded,
            onToggleExpand: () => setState(() {
              _isPackagesExpanded = !_isPackagesExpanded;
            }),
          ),

          const SizedBox(height: 20),

          // Primary CTA Button
          PrimaryCTAButton(
            label: 'เริ่มเที่ยวเลย',
            icon: Icons.explore_rounded,
            onPressed: selectedTrip == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TripDetailScreen(
                        slug: selectedTrip!['slug'].toString(),
                        initialScheduleId: _selectedScheduleId,
                        initialPickupRegionKey: _selectedPickupRegionKey,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class DestinationDropdown extends StatelessWidget {
  final String? slug;
  final List<Map<String, dynamic>> options;
  final ValueChanged<String?> onChanged;

  const DestinationDropdown({
    super.key,
    required this.slug,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _PlannerSelectFrame(
      icon: Icons.map_outlined,
      label: 'เลือกทริปที่สนใจ',
      child: options.isEmpty
          ? const Text(
              'ยังไม่มีทริปที่เปิดขาย',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: slug,
                isExpanded: true,
                menuMaxHeight: 400,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.primaryColor,
                ),
                items: options.map((trip) {
                  return DropdownMenuItem<String>(
                    value: trip['slug']?.toString(),
                    child: Text(
                      textOf(trip['title'], '-'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
                hint: Text(
                  'เลือกทริป',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onChanged: onChanged,
              ),
            ),
    );
  }
}

class DateSelectorCard extends StatefulWidget {
  final Future<List<dynamic>>? schedulesFuture;
  final int? selectedScheduleId;
  final ValueChanged<int?> onChanged;
  final ValueChanged<String?>? onRegionChanged;
  final AppProvider app;
  final Function(Map<String, dynamic>)? onSelectedSchedule;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const DateSelectorCard({
    super.key,
    required this.schedulesFuture,
    required this.selectedScheduleId,
    required this.onChanged,
    this.onRegionChanged,
    required this.app,
    this.onSelectedSchedule,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  State<DateSelectorCard> createState() => _DateSelectorCardState();
}

class _DateSelectorCardState extends State<DateSelectorCard> {
  String? _selectedRegionKey;
  int? _selectedPickupPointId;

  @override
  void didUpdateWidget(covariant DateSelectorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedulesFuture != widget.schedulesFuture) {
      _selectedRegionKey = null;
      _selectedPickupPointId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.schedulesFuture == null) {
      return const _PlannerSelectFrame(
        icon: Icons.route_outlined,
        label: 'เลือกภาคที่จะขึ้น',
        child: Text(
          'เลือกทริปก่อน',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: widget.schedulesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PlannerSelectFrame(
            icon: Icons.route_outlined,
            label: 'เลือกภาคที่จะขึ้น',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                minHeight: 2,
              ),
            ),
          );
        }

        final scheduleMaps = asList(snapshot.data).map(asMap).toList();
        if (scheduleMaps.isEmpty) {
          return const _PlannerSelectFrame(
            icon: Icons.calendar_today_outlined,
            label: 'เลือกวันเดินทาง',
            child: Text(
              'ยังไม่มีวันเดินทางที่เปิดจอง',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
          );
        }

        final regions = pickupRegionOptions(scheduleMaps);
        final selectedRegion = regions
            .where((region) => region.key == _selectedRegionKey)
            .firstOrNull;
        final filteredSchedules = selectedRegion == null
            ? <Map<String, dynamic>>[]
            : scheduleMaps
                  .where(
                    (schedule) =>
                        scheduleHasPickupRegion(schedule, selectedRegion.key),
                  )
                  .toList();
        final currentSchedule = filteredSchedules
            .where(
              (schedule) =>
                  schedule['id']?.toString() ==
                  widget.selectedScheduleId?.toString(),
            )
            .firstOrNull;
        final dropdownScheduleId = currentSchedule == null
            ? null
            : int.tryParse(currentSchedule['id'].toString());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlannerSelectFrame(
              icon: Icons.route_outlined,
              label: 'เลือกภาคที่จะขึ้น',
              child: regions.isEmpty
                  ? const Text(
                      'ยังไม่มีข้อมูลภาค/จุดรับสำหรับทริปนี้',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRegion?.key,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(16),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.primaryColor,
                        ),
                        hint: Text(
                          'เลือกภาค',
                          style: GoogleFonts.anuphan(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        items: regions.map((region) {
                          return DropdownMenuItem<String>(
                            value: region.key,
                            child: Text(
                              region.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.anuphan(
                                color: AppTheme.primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRegionKey = value;
                            _selectedPickupPointId = null;
                          });
                          widget.onChanged(null);
                          widget.onRegionChanged?.call(value);
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            _PlannerSelectFrame(
              icon: Icons.calendar_today_outlined,
              label: 'เลือกวันเดินทาง',
              child: selectedRegion == null
                  ? const Text(
                      'เลือกภาคก่อนจึงจะเลือกวันได้',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    )
                  : filteredSchedules.isEmpty
                  ? const Text(
                      'ยังไม่มีวันเดินทางสำหรับภาคนี้',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    )
                  : _ScheduleDropdown(
                      schedules: filteredSchedules,
                      value: dropdownScheduleId,
                      regionKey: selectedRegion.key,
                      onChanged: (id) {
                        setState(() => _selectedPickupPointId = null);
                        widget.onChanged(id);
                        final selectedSchedule = filteredSchedules
                            .where(
                              (schedule) =>
                                  schedule['id']?.toString() == id?.toString(),
                            )
                            .firstOrNull;
                        if (selectedSchedule != null) {
                          widget.onSelectedSchedule?.call(selectedSchedule);
                        }
                      },
                    ),
            ),
            const SizedBox(height: 12),
            _PlannerSelectFrame(
              icon: Icons.place_outlined,
              label: 'จุดขึ้นรถ',
              child: currentSchedule == null || selectedRegion == null
                  ? const Text(
                      'เลือกวันเดินทางก่อน',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final pickupPoints =
                            asList(currentSchedule['pickup_points'])
                                .map(asMap)
                                .where(
                                  (p) =>
                                      pickupRegionKey(p) == selectedRegion.key,
                                )
                                .toList();
                        if (pickupPoints.isEmpty) {
                          return const Text(
                            'ยังไม่มีจุดขึ้นรถสำหรับภาคนี้',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                          );
                        }
                        final validId =
                            _selectedPickupPointId != null &&
                                pickupPoints.any(
                                  (p) =>
                                      int.tryParse(p['id'].toString()) ==
                                      _selectedPickupPointId,
                                )
                            ? _selectedPickupPointId
                            : int.tryParse(pickupPoints.first['id'].toString());
                        return DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: validId,
                            isExpanded: true,
                            itemHeight: 64,
                            borderRadius: BorderRadius.circular(16),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.primaryColor,
                            ),
                            selectedItemBuilder: (context) =>
                                pickupPoints.map((point) {
                                  final location = textOf(
                                    point['pickup_location'],
                                    textOf(point['region_label'], 'ไม่ระบุจุด'),
                                  );
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.anuphan(
                                        color: AppTheme.primaryColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            items: pickupPoints.map((point) {
                              final id = int.tryParse(point['id'].toString());
                              final location = textOf(
                                point['pickup_location'],
                                textOf(point['region_label'], 'ไม่ระบุจุด'),
                              );
                              final priceNum = num.tryParse(
                                point['price']?.toString() ?? '',
                              );
                              final priceText = priceNum != null && priceNum > 0
                                  ? money(priceNum)
                                  : '';
                              final notes = textOf(point['notes']).trim();
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.anuphan(
                                        color: AppTheme.primaryColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (priceText.isNotEmpty ||
                                        notes.isNotEmpty)
                                      Text(
                                        notes.isNotEmpty && priceText.isNotEmpty
                                            ? '$notes  ·  $priceText'
                                            : notes.isNotEmpty
                                            ? notes
                                            : priceText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.anuphan(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => _selectedPickupPointId = value),
                          ),
                        );
                      },
                    ),
            ),
            if (currentSchedule != null && selectedRegion != null)
              Builder(
                builder: (context) {
                  final points = asList(currentSchedule['pickup_points'])
                      .map(asMap)
                      .where((p) => pickupRegionKey(p) == selectedRegion.key)
                      .toList();
                  if (points.isEmpty) return const SizedBox.shrink();
                  final selected = points.firstWhere(
                    (p) =>
                        int.tryParse(p['id'].toString()) ==
                        _selectedPickupPointId,
                    orElse: () => points.first,
                  );
                  final imageUrl = ApiConfig.mediaUrl(selected['image_url']);
                  if (imageUrl.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                        placeholder: (context, _) => Container(
                          height: 160,
                          alignment: Alignment.center,
                          color: AppTheme.subtleSurface(context),
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (currentSchedule != null && selectedRegion != null) ...[
              const SizedBox(height: 8),
              _SchedulePickupDetailToggle(
                isExpanded: widget.isExpanded,
                onToggleExpand: widget.onToggleExpand,
              ),
              if (widget.isExpanded)
                PackageListSection(
                  schedule: currentSchedule,
                  regionKey: selectedRegion.key,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ScheduleDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> schedules;
  final int? value;
  final String? regionKey;
  final ValueChanged<int?> onChanged;

  const _ScheduleDropdown({
    required this.schedules,
    required this.value,
    required this.onChanged,
    this.regionKey,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        isExpanded: true,
        itemHeight: 70,
        borderRadius: BorderRadius.circular(16),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppTheme.primaryColor,
        ),
        hint: Text(
          'เลือกวันเดินทาง',
          style: GoogleFonts.anuphan(
            color: AppTheme.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        selectedItemBuilder: (context) {
          return schedules.map((schedule) {
            final date = scheduleTravelDateText(schedule);
            final seats = textOf(schedule['available_seats'], '0');
            return Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SeatBadge(count: int.tryParse(seats) ?? 0),
              ],
            );
          }).toList();
        },
        items: schedules.map((schedule) {
          final date = scheduleTravelDateText(schedule);
          final seats = textOf(schedule['available_seats'], '0');
          return DropdownMenuItem<int>(
            value: int.tryParse(schedule['id'].toString()),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.primaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SeatBadge(count: int.tryParse(seats) ?? 0, compact: true),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _SchedulePickupDetailToggle extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const _SchedulePickupDetailToggle({
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggleExpand,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 14,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'รายละเอียดจุดรับและราคา',
                style: GoogleFonts.anuphan(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatBadge extends StatelessWidget {
  final int count;
  final bool compact;

  const _SeatBadge({required this.count, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isLow = count < 5;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isLow
            ? const Color(0xFFFFDAD6)
            : AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'เหลือ $count ที่',
        style: GoogleFonts.anuphan(
          color: isLow ? const Color(0xFF93000A) : AppTheme.primaryColor,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
