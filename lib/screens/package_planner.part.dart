part of 'customer_app_screen.dart';

class PackageListSection extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final String? regionKey;

  const PackageListSection({super.key, required this.schedule, this.regionKey});

  @override
  Widget build(BuildContext context) {
    final points = asList(schedule['pickup_points'])
        .map(asMap)
        .where(
          (point) => regionKey == null || pickupRegionKey(point) == regionKey,
        )
        .toList();
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'ยังไม่มีรายละเอียดภาค/จุดรับสำหรับรอบนี้',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      );
    }

    return Column(
      children: [
        ...points.map((point) {
          final region = textOf(
            point['region_label'],
            textOf(point['region'], 'ไม่ระบุภาค'),
          );
          final location = textOf(point['pickup_location'], 'ไม่ระบุจุดรับ');
          final price = point['price'] != null ? money(point['price']) : 'ฟรี';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.border(context).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region,
                        style: GoogleFonts.anuphan(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.anuphan(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  price,
                  style: GoogleFonts.anuphan(
                    color: AppTheme.primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class PrimaryCTAButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const PrimaryCTAButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56, // Modern tall button
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: GoogleFonts.anuphan(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _PlannerSelectFrame extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _PlannerSelectFrame({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Icon(
              icon,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.anuphan(
                    color: AppTheme.mutedText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _tripTypeLabel(String type) {
  return switch (type.toLowerCase()) {
    'all' => 'ทริปทั้งหมด',
    'trekking' => 'เดินป่า',
    'diving' => 'ดำน้ำ',
    'snorkeling' => 'ดำน้ำตื้น',
    'van' || 'van-service' || 'van_service' => 'รถตู้นำเที่ยว',
    'climbing' => 'ปีนเขา',
    'camping' => 'แคมป์ปิ้ง',
    'kayaking' => 'พายเรือคายัค',
    'cycling' => 'ปั่นจักรยาน',
    _ => type,
  };
}

String _durationText(Map<String, dynamic> trip) {
  final days = int.tryParse(textOf(trip['duration_days'], '1')) ?? 1;
  if (days <= 1) return '1 วัน';
  return '$days วัน ${days - 1} คืน';
}

Color _tripTypeColor(String type) {
  return switch (type.toLowerCase()) {
    'trekking' => const Color(0xFF2D7A4F),
    'diving' => const Color(0xFF1A5F8A),
    'snorkeling' => const Color(0xFF3B9DD4),
    'climbing' => const Color(0xFFC8963E),
    _ => const Color(0xFF6B8F7A),
  };
}

num _tripPrice(Map<String, dynamic> trip) {
  return num.tryParse(
        textOf(
          trip['min_price'] ?? trip['price_per_person'] ?? trip['price'],
          '0',
        ),
      ) ??
      0;
}

String _priceLabel(Map<String, dynamic> trip) {
  final minValue =
      trip['min_price'] ?? trip['price_per_person'] ?? trip['price'];
  final maxValue = trip['max_price'];
  final min = num.tryParse(textOf(minValue));
  final max = num.tryParse(textOf(maxValue));

  if (min != null && max != null && min != max) {
    return '${money(min)} - ${money(max)}';
  }
  return money(minValue);
}

List<int?> _paginationPages(int current, int last) {
  if (last <= 7) return [for (var i = 1; i <= last; i++) i];

  final pages = <int?>[1];
  if (current > 3) pages.add(null);
  for (var i = current - 1; i <= current + 1; i++) {
    if (i > 1 && i < last) pages.add(i);
  }
  if (current < last - 2) pages.add(null);
  pages.add(last);
  return pages;
}

String scheduleRegionSummary(Map<String, dynamic> schedule) {
  final points = asList(schedule['pickup_points']).map(asMap).toList();
  if (points.isEmpty) return 'ยังไม่มีรายละเอียดภาค/จุดรับ';

  final labels = <String>{};
  for (final point in points) {
    final label = textOf(
      point['region_label'],
      textOf(point['region'], 'ไม่ระบุภาค'),
    );
    labels.add(label);
  }

  final visible = labels.take(3).join(', ');
  final more = labels.length > 3 ? ' +${labels.length - 3}' : '';
  return 'ภาค: $visible$more';
}

String scheduleTravelDateText(Map<String, dynamic> schedule) {
  var start = _compactThaiDate(schedule['departure_date']);
  if (start == '-') return 'รอระบุวัน';

  // ถ้ารถออกคืนก่อนวันทริป แสดงวัน-เวลาออกรถจริงเป็นจุดเริ่มต้น
  final departsAt = scheduleDepartsAt(schedule);
  if (departsAt != null) {
    start =
        '${_compactThaiDate(schedule['departs_at'])} ${DateFormat('HH:mm').format(departsAt)} น.';
  }

  final end = _compactThaiDate(schedule['return_date']);
  if (end == '-' || end == start) return start;

  return '$start - $end';
}

String _compactThaiDate(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '-';

  final date = DateTime.tryParse(raw);
  if (date == null) return raw;

  final month = DateFormat('MMM', 'th_TH').format(date);
  return '${date.day} $month${date.year + 543}';
}

class _PickupRegionOption {
  final String key;
  final String label;

  const _PickupRegionOption({required this.key, required this.label});
}

List<_PickupRegionOption> pickupRegionOptions(
  List<Map<String, dynamic>> schedules,
) {
  final labelsByKey = <String, String>{};

  for (final schedule in schedules) {
    final points = asList(schedule['pickup_points']).map(asMap);
    for (final point in points) {
      final key = pickupRegionKey(point);
      if (key.isEmpty || labelsByKey.containsKey(key)) continue;
      labelsByKey[key] = pickupRegionLabel(point);
    }
  }

  final regions = labelsByKey.entries
      .map((entry) => _PickupRegionOption(key: entry.key, label: entry.value))
      .toList();
  regions.sort((a, b) => a.label.compareTo(b.label));
  return regions;
}

bool scheduleHasPickupRegion(Map<String, dynamic> schedule, String regionKey) {
  final points = asList(schedule['pickup_points']).map(asMap);
  return points.any((point) => pickupRegionKey(point) == regionKey);
}

String pickupRegionKey(Map<String, dynamic> point) {
  final region = textOf(point['region']).trim();
  if (region.isNotEmpty) return region;
  return textOf(point['region_label']).trim();
}

String pickupRegionLabel(Map<String, dynamic> point) {
  return textOf(point['region_label'], textOf(point['region'], 'ไม่ระบุภาค'));
}

DateTime? bookingTravelDate(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  // วันออกรถจริง (departs_at) มาก่อนวันทริปได้ เช่น รถออกคืนวันศุกร์ 23:30
  final date = scheduleDepartsAt(schedule) ??
      DateTime.tryParse(textOf(schedule['departure_date']));
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day);
}

DateTime? _bookingReturnDate(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  final raw = textOf(
    schedule['return_date'],
    textOf(schedule['departure_date']),
  );
  if (raw.isEmpty) return null;
  final date = DateTime.tryParse(raw);
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day);
}

bool _isCancelledBooking(Map<String, dynamic> booking) {
  return ['cancelled', 'refunded'].contains(textOf(booking['status']));
}

bool _isPastBooking(Map<String, dynamic> booking) {
  if (_isCancelledBooking(booking)) return false;
  if (textOf(booking['status']) == 'completed') return true;

  final end = _bookingReturnDate(booking);
  if (end == null) return false;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return end.isBefore(today);
}

bool _isUpcomingBooking(Map<String, dynamic> booking) {
  if (_isCancelledBooking(booking) || _isPastBooking(booking)) return false;
  return ['pending', 'confirmed'].contains(textOf(booking['status']));
}

String _statusKey(Map<String, dynamic> booking) {
  final status = textOf(booking['status']);
  if (_isCancelledBooking(booking)) return 'cancelled';
  if (status == 'pending') return 'pending';
  if (_isPastBooking(booking) || status == 'completed') return 'completed';

  final travelDate = bookingTravelDate(booking);
  if (travelDate != null && status == 'confirmed') {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = travelDate.difference(today).inDays;
    if (days >= 0 && days <= 7) return 'near';
  }

  return 'confirmed';
}

String _countdownText(Map<String, dynamic> booking) {
  final status = textOf(booking['status']);
  if (status == 'pending') return 'รอชำระเงินเพื่อยืนยันที่นั่ง';
  if (_isCancelledBooking(booking)) return 'รายการนี้ถูกยกเลิก';

  final date = bookingTravelDate(booking);
  if (date == null) return 'รอระบุวันเดินทาง';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = date.difference(today).inDays;
  if (days > 0) return 'อีก $days วันเดินทาง';
  if (days == 0) return 'เดินทางวันนี้';
  return 'เดินทางแล้ว';
}

String _travelDateText(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  if (dateText(schedule['departure_date']) == '-') return 'รอระบุวัน';
  // ใช้วัน-เวลาออกรถจริงเป็นจุดเริ่มต้นเมื่อรอบนั้นกำหนดไว้
  final start = departureText(schedule);
  final end = dateText(schedule['return_date']);
  if (end == '-' || end == start) return start;
  return '$start - $end';
}

String _travelerText(Map<String, dynamic> booking) {
  final passengers = asList(booking['passengers']);
  final seats = asList(booking['seats']);
  final explicitCount =
      _positiveInt(booking['passenger_count']) ??
      _positiveInt(booking['passengers_count']) ??
      _positiveInt(booking['seat_count']) ??
      _positiveInt(booking['seats_count']);
  final count = passengers.isNotEmpty
      ? passengers.length
      : seats.isNotEmpty
      ? seats.length
      : explicitCount ?? 0;
  if (count <= 0) return 'รอข้อมูล';
  return '$count คน';
}

String _pickupText(Map<String, dynamic> booking) {
  final pickupPoint = _selectedPickupPoint(booking);
  final schedule = asMap(booking['schedule']);
  final trip = asMap(schedule['trip']);
  final regionCode = textOf(
    pickupPoint['region'],
    textOf(booking['pickup_region']),
  );
  final regionLabel = textOf(
    pickupPoint['region_label'],
    _regionLabel(regionCode),
  );
  final location = textOf(pickupPoint['pickup_location']);
  final notes = textOf(pickupPoint['notes']);
  final details = [
    if (location.isNotEmpty) location,
    if (notes.isNotEmpty) notes,
  ].join(' ');

  if (regionLabel.isNotEmpty && details.isNotEmpty) {
    return '$regionLabel — $details';
  }
  if (details.isNotEmpty) return details;
  if (regionLabel.isNotEmpty) return regionLabel;
  return textOf(trip['departure_point'], 'จุดนัดพบตามรายละเอียดทริป');
}

Map<String, dynamic> _selectedPickupPoint(Map<String, dynamic> booking) {
  final direct = asMap(booking['pickup_point']);
  if (direct.isNotEmpty) return direct;

  final pickupRegion = textOf(booking['pickup_region']);
  final pickupPointId = textOf(booking['pickup_point_id']);
  final schedule = asMap(booking['schedule']);
  final points = asList(schedule['pickup_points']).map(asMap).toList();

  for (final point in points) {
    if (pickupPointId.isNotEmpty && textOf(point['id']) == pickupPointId) {
      return point;
    }
  }
  for (final point in points) {
    if (pickupRegion.isNotEmpty && textOf(point['region']) == pickupRegion) {
      return point;
    }
  }
  return points.length == 1 ? points.first : const <String, dynamic>{};
}

int? _positiveInt(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

String _regionLabel(String region) {
  return switch (region.trim().toLowerCase()) {
    'bangkok' => 'กรุงเทพฯ',
    'central' => 'ภาคกลาง',
    'north' => 'ภาคเหนือ',
    'northeast' => 'ภาคอีสาน',
    'east' => 'ภาคตะวันออก',
    'west' => 'ภาคตะวันตก',
    'south' => 'ภาคใต้',
    _ => '',
  };
}
