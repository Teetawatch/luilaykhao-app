part of 'trip_detail_screen.dart';

class _QuickInfoItem {
  final IconData icon;
  final String label;

  const _QuickInfoItem({required this.icon, required this.label});
}

class _HighlightItem {
  final String title;
  final String? description;
  final String? icon;

  const _HighlightItem({required this.title, this.description, this.icon});
}

class _MustKnowItem {
  final String name;
  final num price;
  final String priceType;
  final String imageUrl;

  const _MustKnowItem({
    required this.name,
    required this.price,
    required this.priceType,
    this.imageUrl = '',
  });

  String get priceTypeLabel =>
      priceType == 'per_person' ? 'ต่อคน' : 'ครั้งเดียว';

  bool get hasImage => imageUrl.isNotEmpty;
}

class _ItinerarySector {
  final String title;
  final List<_ItineraryItem> items;

  const _ItinerarySector({required this.title, required this.items});
}

class _ItineraryItem {
  final int index;
  final String day;
  final String title;
  final String description;

  const _ItineraryItem({
    required this.index,
    required this.day,
    required this.title,
    required this.description,
  });
}

String _tripTitle(Map<String, dynamic> trip) {
  return textOf(trip['title'] ?? trip['name'], 'ทริปที่น่าสนใจ');
}

String _tripShareUrl(Map<String, dynamic> trip) {
  final slug = Uri.encodeComponent(textOf(trip['slug']).trim());
  if (slug.isEmpty) return '${ApiConfig.siteUrl}/trips';
  return '${ApiConfig.siteUrl}/trips/$slug';
}

void _showTripDetailMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

List<String> _detailGalleryImages(Map<String, dynamic> trip) {
  final imageValues = <dynamic>[
    ...asList(trip['images']),
    ...asList(trip['gallery']),
    ...asList(trip['photos']),
  ];

  return imageValues
      .map((image) {
        if (image is Map) {
          final data = asMap(image);
          return ApiConfig.mediaUrl(
            data['url'] ?? data['image'] ?? data['path'],
          );
        }
        return ApiConfig.mediaUrl(image);
      })
      .where((url) => url.isNotEmpty)
      .toSet()
      .toList();
}

List<String> _tripVideos(Map<String, dynamic> trip) {
  final videoValues = <dynamic>[
    ...asList(trip['videos']),
  ];

  return videoValues
      .map((video) {
        if (video is Map) {
          final data = asMap(video);
          return ApiConfig.mediaUrl(data['url'] ?? data['path']);
        }
        return ApiConfig.mediaUrl(video);
      })
      .where((url) => url.isNotEmpty)
      .toSet()
      .toList();
}

List<String> _galleryImages(Map<String, dynamic> trip) {
  final imageValues = <dynamic>[
    trip['cover_image'],
    trip['thumbnail_image'],
    ...asList(trip['images']),
    ...asList(trip['gallery']),
    ...asList(trip['photos']),
  ];

  return imageValues
      .map((image) {
        if (image is Map) {
          final data = asMap(image);
          return ApiConfig.mediaUrl(
            data['url'] ?? data['image'] ?? data['path'],
          );
        }
        return ApiConfig.mediaUrl(image);
      })
      .where((url) => url.isNotEmpty)
      .toSet()
      .toList();
}

String _tripTypeLabel(String type) {
  return switch (type.toLowerCase()) {
    'trekking' => 'เดินป่า',
    'diving' => 'ดำน้ำ',
    'snorkeling' => 'ดำน้ำตื้น',
    'climbing' => 'ปีนเขา',
    'camping' => 'แคมป์ปิ้ง',
    'kayaking' => 'พายเรือคายัค',
    'cycling' => 'ปั่นจักรยาน',
    _ => type,
  };
}

String _difficultyLabel(String difficulty) {
  return switch (difficulty.toLowerCase()) {
    'easy' => 'ง่าย',
    'medium' || 'moderate' => 'ปานกลาง',
    'hard' || 'difficult' => 'ยาก',
    'extreme' => 'ท้าทายมาก',
    _ => difficulty,
  };
}

List<_QuickInfoItem> _quickInfoItems(Map<String, dynamic> trip) {
  final duration = _durationLabel(trip);
  final typeRaw = textOf(trip['type'] ?? trip['category']).trim();
  final difficultyRaw = textOf(trip['difficulty']).trim();
  final type = typeRaw.isNotEmpty ? _tripTypeLabel(typeRaw) : '';
  final difficulty = difficultyRaw.isNotEmpty
      ? _difficultyLabel(difficultyRaw)
      : '';
  final maxPax = int.tryParse(trip['max_participants']?.toString() ?? '');
  final items = <_QuickInfoItem>[];

  if (duration.isNotEmpty) {
    items.add(_QuickInfoItem(icon: Icons.schedule_rounded, label: duration));
  }

  if (type.isNotEmpty) {
    items.add(_QuickInfoItem(icon: Icons.hiking_rounded, label: type));
  }

  if (difficulty.isNotEmpty) {
    items.add(
      _QuickInfoItem(icon: Icons.family_restroom_rounded, label: difficulty),
    );
  }

  if (maxPax != null && maxPax > 0) {
    items.add(
      _QuickInfoItem(
        icon: Icons.group_rounded,
        label: 'สูงสุด $maxPax คน',
      ),
    );
  }

  final rating = _ratingValue(trip);
  final reviewCount = _reviewCount(trip, const []);
  if (rating >= 4.5 || reviewCount >= 10 || trip['is_popular'] == true) {
    items.add(
      const _QuickInfoItem(
        icon: Icons.local_fire_department_outlined,
        label: 'ยอดนิยม',
      ),
    );
  }

  return items.take(5).toList();
}

String _durationLabel(Map<String, dynamic> trip) {
  final hours = num.tryParse(textOf(trip['duration_hours']));
  if (hours != null && hours > 0) return 'ระยะเวลา ${numberText(hours)} ชม.';

  final days = num.tryParse(textOf(trip['duration_days']));
  if (days != null && days > 0) return 'ระยะเวลา ${numberText(days)} วัน';

  final duration = textOf(trip['duration']).trim();
  if (duration.isEmpty) return '';
  return duration.startsWith('ระยะเวลา') ? duration : 'ระยะเวลา $duration';
}

List<_HighlightItem> _highlightItems(dynamic rawHighlights) {
  if (rawHighlights is String) {
    return rawHighlights
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((item) => _HighlightItem(title: item))
        .toList();
  }

  return asList(rawHighlights)
      .map((item) {
        if (item is String) return _HighlightItem(title: item);
        final data = asMap(item);
        return _HighlightItem(
          title: textOf(data['title'] ?? data['name']),
          description: textOf(data['desc'] ?? data['description']).trim(),
          icon: textOf(data['icon']).trim(),
        );
      })
      .where((item) => item.title.trim().isNotEmpty)
      .toList();
}

List<String> _textItems(dynamic raw) {
  if (raw is String) {
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  return asList(raw)
      .map((item) {
        if (item is String) return item.trim();
        final data = asMap(item);
        return textOf(
          data['title'] ??
              data['name'] ??
              data['label'] ??
              data['description'] ??
              data['desc'] ??
              data['text'],
        ).trim();
      })
      .where((item) => item.isNotEmpty)
      .toList();
}

List<_MustKnowItem> _mustKnowItems(Map<String, dynamic> trip) {
  final raw = trip['must_know'];
  if (raw is String) {
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map(
          (name) =>
              _MustKnowItem(name: name, price: 0, priceType: 'per_booking'),
        )
        .toList();
  }

  final mustKnow = asMap(raw);
  final rawItems = mustKnow.isNotEmpty
      ? asList(mustKnow['items'])
      : asList(raw);

  return rawItems
      .asMap()
      .entries
      .map((entry) {
        final item = entry.value;
        final data = asMap(item);
        final name = item is String
            ? item.trim()
            : textOf(data['name'] ?? data['title'] ?? data['label']).trim();
        if (name.isEmpty) return null;

        return _MustKnowItem(
          name: name,
          price: _asNum(data['price']),
          priceType: data['price_type'] == 'per_person'
              ? 'per_person'
              : 'per_booking',
          imageUrl: textOf(data['image_url']).trim(),
        );
      })
      .whereType<_MustKnowItem>()
      .toList();
}

IconData? _iconFor(String? name) {
  switch (name?.toLowerCase()) {
    case 'star':
      return Icons.star_rounded;
    case 'beach':
      return Icons.beach_access_rounded;
    case 'hiking':
      return Icons.hiking_rounded;
    case 'camera':
      return Icons.photo_camera_outlined;
    case 'food':
      return Icons.restaurant_rounded;
    case 'hotel':
      return Icons.hotel_rounded;
    default:
      return null;
  }
}

List<_ItinerarySector> _itinerarySectors(
  Map<String, dynamic> trip, {
  String? regionKey,
  String? regionLabel,
}) {
  final raw = trip['itinerary'] ?? trip['itineraries'] ?? trip['program'];
  final sectors = <_ItinerarySector>[];
  final flatItems = <_ItineraryItem>[];
  final normalizedRegionKey = regionKey?.trim();
  final normalizedRegionLabel = regionLabel?.trim();

  void addFlatItem(dynamic value) {
    if (!_itineraryEntryMatchesRegion(
      value,
      normalizedRegionKey,
      normalizedRegionLabel,
    )) {
      return;
    }

    final item = _itineraryItemFrom(value, flatItems.length + 1);
    if (item != null) flatItems.add(item);
  }

  void addSector(Map<String, dynamic> sectorData, List<dynamic> rawItems) {
    final explicitSectorRegionValues = _itineraryExplicitRegionValues(
      sectorData,
    );
    final sectorRegionValues = _itineraryRegionValues(sectorData);
    final sectorMatches =
        sectorRegionValues.isNotEmpty &&
        sectorRegionValues.any(
          (value) =>
              _regionTextMatches(value, normalizedRegionKey) ||
              _regionTextMatches(value, normalizedRegionLabel),
        );
    final explicitSectorMismatch =
        explicitSectorRegionValues.isNotEmpty && !sectorMatches;
    final visibleRawItems = explicitSectorMismatch
        ? const <dynamic>[]
        : sectorMatches
        ? rawItems
        : rawItems
              .where(
                (value) => _itineraryEntryMatchesRegion(
                  value,
                  normalizedRegionKey,
                  normalizedRegionLabel,
                ),
              )
              .toList();
    final items = <_ItineraryItem>[];
    for (final value in visibleRawItems) {
      final item = _itineraryItemFrom(value, items.length + 1);
      if (item != null) items.add(item);
    }

    if (items.isNotEmpty) {
      final title = _itinerarySectorTitle(sectorData, sectors.length + 1);
      sectors.add(
        _ItinerarySector(
          title: title.trim().isNotEmpty
              ? title.trim()
              : 'ช่วงที่ ${sectors.length + 1}',
          items: items,
        ),
      );
    }
  }

  if (raw is String) {
    for (final line in raw.split('\n')) {
      final text = line.trim();
      if (text.isNotEmpty) addFlatItem(text);
    }
    return flatItems.isEmpty
        ? const []
        : [_ItinerarySector(title: 'แผนการเดินทาง', items: flatItems)];
  }

  if (raw is Map) {
    final map = asMap(raw);
    final nestedItems = _nestedItineraryItems(map);
    if (nestedItems.isNotEmpty) {
      addSector(map, nestedItems);
    } else {
      addFlatItem(map);
    }
    return sectors.isNotEmpty
        ? sectors
        : flatItems.isEmpty
        ? const []
        : [_ItinerarySector(title: 'แผนการเดินทาง', items: flatItems)];
  }

  for (final entry in asList(raw)) {
    final map = asMap(entry);
    final nestedItems = _nestedItineraryItems(map);
    if (nestedItems.isNotEmpty) {
      addSector(map, nestedItems);
    } else {
      addFlatItem(entry);
    }
  }

  if (flatItems.isNotEmpty) {
    sectors.insert(
      0,
      _ItinerarySector(title: 'แผนการเดินทาง', items: flatItems),
    );
  }

  return sectors;
}

bool _itineraryEntryMatchesRegion(
  dynamic value,
  String? regionKey,
  String? regionLabel,
) {
  if ((regionKey == null || regionKey.isEmpty) &&
      (regionLabel == null || regionLabel.isEmpty)) {
    return true;
  }
  if (value is String) {
    return _regionTextMatches(value, regionKey) ||
        _regionTextMatches(value, regionLabel);
  }

  final data = asMap(value);
  if (data.isEmpty) return false;

  final entryValues = _itineraryRegionValues(data);

  // An itinerary entry with no region tagging is a *shared* plan that applies
  // to every pickup region — it must stay visible when a region is selected,
  // otherwise the whole programme disappears for trips whose itinerary isn't
  // split per region (the common case).
  if (entryValues.isEmpty) return true;
  return entryValues.any(
    (value) =>
        _regionTextMatches(value, regionKey) ||
        _regionTextMatches(value, regionLabel),
  );
}

List<dynamic> _nestedItineraryItems(Map<String, dynamic> data) {
  for (final key in ['items', 'itinerary', 'itineraries', 'days', 'program']) {
    final items = asList(data[key]);
    if (items.isNotEmpty) return items;
  }

  return const [];
}

String _itineraryRegionKey(Map<String, dynamic> data) {
  final region = textOf(data['region']).trim();
  if (region.isNotEmpty) return region;
  return textOf(data['region_label']).trim();
}

Set<String> _itineraryExplicitRegionValues(Map<String, dynamic> data) {
  final region = textOf(data['region']).trim();
  final label = textOf(data['region_label']).trim();

  return <String>{if (region.isNotEmpty) region, if (label.isNotEmpty) label};
}

Set<String> _itineraryRegionValues(Map<String, dynamic> data) {
  final key = _itineraryRegionKey(data);
  final label = textOf(data['region_label']).trim();
  final sector = textOf(
    data['sector'] ?? data['sector_name'] ?? data['section'] ?? data['part'],
  ).trim();

  return <String>{
    if (key.isNotEmpty) key,
    if (label.isNotEmpty) label,
    if (sector.isNotEmpty) sector,
  };
}

bool _regionTextMatches(String? value, String? selectedRegion) {
  final text = value?.trim().toLowerCase();
  final region = selectedRegion?.trim().toLowerCase();
  if (text == null || text.isEmpty || region == null || region.isEmpty) {
    return false;
  }

  return text == region || text.contains(region) || region.contains(text);
}

String _itinerarySectorTitle(Map<String, dynamic> data, int index) {
  return textOf(
    data['sector'] ??
        data['sector_name'] ??
        data['section'] ??
        data['part'] ??
        data['region_label'] ??
        data['region'] ??
        data['title'] ??
        data['name'],
    'ภาคที่ $index',
  );
}

_ItineraryItem? _itineraryItemFrom(dynamic value, int index) {
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return _ItineraryItem(
      index: index,
      day: '$index',
      title: text,
      description: '',
    );
  }

  final data = asMap(value);
  if (data.isEmpty) return null;

  final day = textOf(
    data['day'] ?? data['day_number'] ?? data['order'] ?? data['sort_order'],
    '$index',
  ).trim();
  final description = textOf(
    data['description'] ?? data['desc'] ?? data['detail'] ?? data['content'],
  ).trim();
  final title = textOf(
    data['title'] ?? data['name'] ?? data['activity'],
    description.isNotEmpty ? 'ช่วงที่ $index' : '',
  ).trim();

  if (title.isEmpty && description.isEmpty) return null;

  return _ItineraryItem(
    index: index,
    day: day,
    title: title.isNotEmpty ? title : 'ช่วงที่ $index',
    description: description,
  );
}

double _ratingValue(Map<String, dynamic> data) {
  return double.tryParse(textOf(data['rating'])) ?? 0;
}

int _reviewCount(Map<String, dynamic> trip, List<dynamic> reviews) {
  final count = int.tryParse(textOf(trip['review_count']));
  if (count != null && count > 0) return count;
  return reviews.length;
}

int? _validDropdownValue(int? selected, Iterable<int> values) {
  final ids = values.toList();
  if (ids.isEmpty) return null;
  if (selected != null && ids.contains(selected)) return selected;
  return ids.first;
}

bool _scheduleHasPickupRegion(Map<String, dynamic> schedule, String regionKey) {
  return asList(
    schedule['pickup_points'],
  ).map(asMap).any((point) => _pickupRegionKey(point) == regionKey);
}

String _regionSummary(Map<String, dynamic> schedule, {String? regionKey}) {
  final regions = asList(schedule['pickup_points'])
      .map(asMap)
      .where(
        (point) =>
            regionKey == null ||
            regionKey.isEmpty ||
            _pickupRegionKey(point) == regionKey,
      )
      .map(
        (point) => textOf(
          point['region_label'],
          textOf(point['region'], 'ไม่ระบุภูมิภาค'),
        ),
      )
      .where((region) => region.trim().isNotEmpty)
      .toSet()
      .toList();

  if (regions.isEmpty) return '';
  if (regions.length == 1) return regions.first;
  return '${regions.length} ภูมิภาค';
}

String _scheduleTravelDateText(Map<String, dynamic> schedule) {
  final start = dateText(schedule['departure_date']);
  if (start == '-') return 'รอระบุวัน';

  final end = dateText(schedule['return_date']);
  if (end == '-' || end == start) return start;

  return '$start - $end';
}

String _pickupRegionKey(Map<String, dynamic> point) {
  final region = textOf(point['region']).trim();
  if (region.isNotEmpty) return region;
  return textOf(point['region_label']).trim();
}

String _pickupPriceText(dynamic value) {
  final number = num.tryParse(textOf(value));
  if (number == null || number <= 0) return 'ไม่มีค่าใช้จ่ายเพิ่ม';
  return '+${money(number)}';
}

Map<String, dynamic> _selectedScheduleFor(
  List<dynamic> schedules,
  int? selectedScheduleId,
) {
  if (schedules.isEmpty) return <String, dynamic>{};

  return asMap(
    schedules.firstWhere(
      (item) => asMap(item)['id'].toString() == selectedScheduleId.toString(),
      orElse: () => schedules.first,
    ),
  );
}

int _scheduleAvailableSeats(Map<String, dynamic> schedule) =>
    int.tryParse(textOf(schedule['available_seats'], '0')) ?? 0;

/// รอบที่ "จองได้จริง": ไม่ใช่รอบเหมา ยังไม่ผ่านวันเดินทาง และยังมีที่นั่งว่าง
bool _scheduleIsBookable(Map<String, dynamic> schedule) {
  if (schedule.isEmpty) return false;
  if (_asBool(schedule['is_charter'])) return false;
  if (_isSchedulePast(schedule)) return false;
  return _scheduleAvailableSeats(schedule) > 0;
}

/// รอบแรกที่จองได้จาก list (กรองตาม region ถ้าระบุ) — ไว้ใช้เป็นค่าเริ่มต้น
/// เพื่อไม่ให้ระบบเลือกรอบที่เต็ม/ผ่านแล้วมาให้ผู้ใช้ตั้งแต่เปิดหน้า
Map<String, dynamic> _firstBookableSchedule(
  List<dynamic> schedules, {
  String? regionKey,
}) {
  final key = regionKey?.trim();
  for (final item in schedules) {
    final schedule = asMap(item);
    if (!_scheduleIsBookable(schedule)) continue;
    if (key != null && key.isNotEmpty && !_scheduleHasPickupRegion(schedule, key)) {
      continue;
    }
    return schedule;
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _selectedPickupPointFor(
  Map<String, dynamic> schedule,
  int? selectedPickupPointId,
) {
  final points = asList(schedule['pickup_points']);
  if (points.isEmpty) return <String, dynamic>{};

  return asMap(
    points.firstWhere(
      (item) =>
          asMap(item)['id'].toString() == selectedPickupPointId.toString(),
      orElse: () => points.first,
    ),
  );
}

String _pickupRegionLabel(Map<String, dynamic> point) {
  return textOf(point['region_label'], textOf(point['region'])).trim();
}

String _priceText(
  Map<String, dynamic> trip, {
  Map<String, dynamic>? schedule,
  Map<String, dynamic>? pickupPoint,
  bool isJoinTrip = false,
}) {
  final pickupPrice = num.tryParse(textOf(pickupPoint?['price']));
  final dynamic value;
  if (isJoinTrip) {
    value =
        schedule?['join_trip_price'] ??
        schedule?['effective_price'] ??
        schedule?['price'] ??
        trip['price_per_person'] ??
        trip['price'] ??
        trip['start_price'];
  } else if (pickupPrice != null && pickupPrice > 0) {
    value = pickupPrice;
  } else {
    value =
        schedule?['effective_price'] ??
        schedule?['price'] ??
        trip['price_per_person'] ??
        trip['price'] ??
        trip['start_price'];
  }
  final number = num.tryParse(textOf(value));
  if (number == null || number <= 0) return 'ดูราคา';
  return '${money(number)} / คน';
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'y';
}

num _asNum(dynamic value) {
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatRelativeDate(dynamic value) {
  final raw = textOf(value).trim();
  if (raw.isEmpty) return '';

  try {
    final date = DateTime.parse(raw);
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return '${diff.inDays} วันที่แล้ว';
    if (diff.inHours > 0) return '${diff.inHours} ชม. ที่แล้ว';
    return 'เมื่อครู่';
  } catch (_) {
    return '';
  }
}
