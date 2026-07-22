part of 'booking_flow_screen.dart';

class _TrustSignal {
  final IconData icon;
  final String label;

  const _TrustSignal(this.icon, this.label);
}

class _CheckoutValidationException implements Exception {
  final String message;

  const _CheckoutValidationException(this.message);

  @override
  String toString() => message;
}

class _PricingQuote {
  final num pricePerTraveler;
  final int travelerCount;
  final num addonsTotal;
  final num rentalsTotal;
  final num serviceFee;
  final num discount;
  final bool hasVariedPrices;
  final num? _passengersSubtotal;

  const _PricingQuote({
    required this.pricePerTraveler,
    required this.travelerCount,
    required this.addonsTotal,
    this.rentalsTotal = 0,
    required this.serviceFee,
    required this.discount,
    this.hasVariedPrices = false,
    num? passengersSubtotal,
  }) : _passengersSubtotal = passengersSubtotal;

  num get tripSubtotal => _passengersSubtotal ?? pricePerTraveler * travelerCount;

  num get total {
    final value = tripSubtotal + addonsTotal + rentalsTotal + serviceFee - discount;
    return value < 0 ? 0 : value;
  }

  factory _PricingQuote.fromPassengers({
    required List<_PassengerControllers> passengers,
    required Map<String, dynamic> schedule,
    required bool isJoinTrip,
    required List<dynamic> pickupPoints,
    List<_AddonOption> selectedAddons = const [],
    List<_RentalSelection> selectedRentals = const [],
    Map<String, dynamic>? appliedPromo,
  }) {
    final basePrice = _asNum(
      isJoinTrip
          ? schedule['join_trip_price'] ??
                schedule['effective_price'] ??
                schedule['price']
          : schedule['effective_price'] ?? schedule['price'],
    );

    num passengersTotal = 0;
    num? firstPrice;
    var pricesVary = false;

    for (final passenger in passengers) {
      num passengerPrice = basePrice;
      final pickupId = passenger.pickupPointId.value;
      if (!isJoinTrip && pickupId != null && pickupPoints.isNotEmpty) {
        final ppData = pickupPoints.firstWhere(
          (p) => asMap(p)['id'].toString() == pickupId.toString(),
          orElse: () => const <String, dynamic>{},
        );
        final ppPrice = _asNum(asMap(ppData)['price']);
        if (ppPrice > 0) passengerPrice = ppPrice;
      }
      if (firstPrice == null) {
        firstPrice = passengerPrice;
      } else if (passengerPrice != firstPrice) {
        pricesVary = true;
      }
      passengersTotal += passengerPrice;
    }

    final count = passengers.length;
    final addonsTotalValue = selectedAddons.fold<num>(
      0,
      (sum, addon) => sum + addon.totalFor(count),
    );
    final rentalsTotalValue = selectedRentals.fold<num>(
      0,
      (sum, rental) => sum + rental.total,
    );

    // Preview the discount using the exact rule the backend applies at booking
    // (BookingService): percent/fixed off the trip subtotal + addons + rentals,
    // capped at that base — so the amount shown here equals the final charge.
    num discount = 0;
    if (appliedPromo != null) {
      final base = passengersTotal + addonsTotalValue + rentalsTotalValue;
      final value = _asNum(appliedPromo['value']);
      discount = textOf(appliedPromo['type']) == 'percent'
          ? base * value / 100
          : value;
      if (discount > base) discount = base;
      if (discount < 0) discount = 0;
    }

    return _PricingQuote(
      pricePerTraveler: firstPrice ?? basePrice,
      travelerCount: count,
      addonsTotal: addonsTotalValue,
      rentalsTotal: rentalsTotalValue,
      serviceFee: 0,
      discount: discount,
      hasVariedPrices: pricesVary,
      passengersSubtotal: passengersTotal,
    );
  }
}

class _AddonOption {
  final int index;
  final String name;
  final num price;
  final String priceType;
  final String imageUrl;

  const _AddonOption({
    required this.index,
    required this.name,
    required this.price,
    required this.priceType,
    this.imageUrl = '',
  });

  bool get hasImage => imageUrl.isNotEmpty;

  bool get isPerPerson => priceType == 'per_person';

  String get priceTypeLabel => isPerPerson ? 'ต่อคน' : 'ครั้งเดียว';

  num totalFor(int travelerCount) => price * (isPerPerson ? travelerCount : 1);
}

/// One rentable equipment item defined on the trip (`trip.rental_items`),
/// identified by its position so the backend can re-resolve it by index.
class _RentalOption {
  final int index;
  final String name;
  final num price;
  final String imageUrl;
  final String description;

  const _RentalOption({
    required this.index,
    required this.name,
    required this.price,
    this.imageUrl = '',
    this.description = '',
  });

  bool get hasImage => imageUrl.isNotEmpty;
}

/// A rental item plus the quantity the customer picked (>= 1).
class _RentalSelection {
  final _RentalOption option;
  final int quantity;

  const _RentalSelection({required this.option, required this.quantity});

  num get total => option.price * quantity;
}

List<_RentalOption> _rentalOptionsFrom(Map<String, dynamic> trip) {
  final rawItems = asList(trip['rental_items']);
  final options = <_RentalOption>[];

  for (var i = 0; i < rawItems.length; i++) {
    final data = asMap(rawItems[i]);
    final name = textOf(data['name'] ?? data['title']).trim();
    final price = _asNum(data['price']);
    if (name.isEmpty || price <= 0) continue;

    options.add(
      _RentalOption(
        index: i,
        name: name,
        price: price,
        imageUrl: textOf(data['image_url']).trim(),
        description: textOf(data['description']).trim(),
      ),
    );
  }

  return options;
}

// Fullscreen, zoomable viewer for an add-on item image.
void _openAddonImage(BuildContext context, String url) {
  if (url.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) {
        final safeBottom = MediaQuery.paddingOf(ctx).bottom;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(
                          child: CircularProgressIndicator(color: Colors.white54),
                        ),
                        errorWidget: (_, _, _) => const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Close action sits at the bottom: the booking flow shows a
                // persistent seat-lock countdown banner pinned to the top of
                // every route, which would otherwise cover a top-right button.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: safeBottom + 24,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ปิด',
                              style: appFont(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _PassengerControllers {
  final title = TextEditingController();
  final name = TextEditingController();
  final nickname = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final idCard = TextEditingController();
  final birthDate = ValueNotifier<DateTime?>(null);
  final bloodGroup = TextEditingController();
  final emergencyContact = TextEditingController();
  final emergencyPhone = TextEditingController();
  final allergies = TextEditingController();
  final healthNotes = TextEditingController();
  final halalFood = ValueNotifier<bool>(false);
  final pickupPointId = ValueNotifier<int?>(null);

  void applyWallet(Map<String, dynamic> wallet) {
    final t = (wallet['title'] as String? ?? '').trim();
    if (t.isNotEmpty) title.text = t;
    final n = (wallet['name'] as String? ?? '').trim();
    if (n.isNotEmpty) name.text = n;
    final nn = (wallet['nickname'] as String? ?? '').trim();
    if (nn.isNotEmpty) nickname.text = nn;
    final p = (wallet['phone'] as String? ?? '').trim();
    if (p.isNotEmpty) phone.text = p;
    final id = (wallet['id_card'] as String? ?? '').trim();
    if (id.isNotEmpty) idCard.text = id;
    final bd = _parseBirthDate(wallet['birth_date']);
    if (bd != null) birthDate.value = bd;
    final bg = (wallet['blood_group'] as String? ?? '').trim();
    if (bg.isNotEmpty) bloodGroup.text = bg;
    final ec = (wallet['emergency_contact'] as String? ?? '').trim();
    if (ec.isNotEmpty) emergencyContact.text = ec;
    final ep = (wallet['emergency_phone'] as String? ?? '').trim();
    if (ep.isNotEmpty) emergencyPhone.text = ep;
    final al = (wallet['allergies'] as String? ?? '').trim();
    if (al.isNotEmpty) allergies.text = al;
    final hn = (wallet['health_notes'] as String? ?? '').trim();
    if (hn.isNotEmpty) healthNotes.text = hn;
    halalFood.value = wallet['halal_food'] == true;
  }

  /// เติมจากสมุดผู้ร่วมเดินทาง — payload มาจาก backend ในรูปแบบเดียวกับ
  /// โปรไฟล์อยู่แล้ว จึงใช้ตัวแปลงชุดเดียวกัน
  void applySavedTraveller(Map<String, dynamic> traveller) {
    applyProfile(traveller);
  }

  void applyProfile(Map<String, dynamic> user) {
    title.text = _profileTitle(user['title']);
    name.text = textOf(user['name']);
    nickname.text = textOf(user['nickname']);
    phone.text = textOf(user['phone']);
    email.text = textOf(user['email']);
    idCard.text = textOf(user['id_card']);
    birthDate.value = _parseBirthDate(user['birth_date']);
    bloodGroup.text = _profileBloodGroup(user['blood_group']);
    emergencyContact.text = textOf(user['emergency_contact']);
    emergencyPhone.text = textOf(user['emergency_phone']);
    allergies.text = textOf(user['allergies']);
    healthNotes.text = textOf(user['health_notes']);
    halalFood.value = _asBool(
      user['halal_food'] ??
          user['needs_halal_food'] ??
          user['requires_halal_food'],
    );
  }

  Map<String, dynamic> payload() => {
    'title': title.text.trim(),
    'name': name.text.trim(),
    'nickname': nickname.text.trim().isEmpty ? null : nickname.text.trim(),
    'phone': phone.text.trim(),
    'email': email.text.trim().isEmpty ? null : email.text.trim(),
    'id_card': idCard.text.trim().isEmpty ? null : idCard.text.trim(),
    'birth_date': _formatBirthDate(birthDate.value),
    'blood_group': bloodGroup.text.trim().isEmpty
        ? null
        : bloodGroup.text.trim(),
    'emergency_contact': emergencyContact.text.trim().isEmpty
        ? null
        : emergencyContact.text.trim(),
    'emergency_phone': emergencyPhone.text.trim().isEmpty
        ? null
        : emergencyPhone.text.trim(),
    'allergies': allergies.text.trim().isEmpty ? null : allergies.text.trim(),
    'halal_food': halalFood.value,
    'health_notes': healthNotes.text.trim().isEmpty
        ? null
        : healthNotes.text.trim(),
    'pickup_point_id': pickupPointId.value,
  };

  void dispose() {
    title.dispose();
    name.dispose();
    nickname.dispose();
    phone.dispose();
    email.dispose();
    idCard.dispose();
    birthDate.dispose();
    bloodGroup.dispose();
    emergencyContact.dispose();
    emergencyPhone.dispose();
    allergies.dispose();
    healthNotes.dispose();
    halalFood.dispose();
    pickupPointId.dispose();
  }
}

BoxDecoration _premiumDecoration(BuildContext context, {double radius = 20}) {
  return AppTheme.cardDecoration(
    context,
    radius: radius,
    borderColor: AppTheme.border(context).withValues(alpha: 0.55),
  );
}

InputDecoration _fieldDecoration({
  required BuildContext context,
  required IconData icon,
  required String hint,
}) {
  return InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: AppTheme.fieldSurface(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
    prefixIcon: Icon(icon, size: 19, color: AppTheme.mutedText(context)),
    prefixIconConstraints: const BoxConstraints(minWidth: 44),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _cardBorder(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _cardBorder(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _softAccent, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppTheme.errorColor),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.4),
    ),
    hintStyle: appFont(
      color: _mutedTextColor(context).withValues(alpha: 0.62),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  );
}

TextStyle _labelStyle(BuildContext context) {
  return appFont(
    color: _mutedTextColor(context),
    fontSize: 12,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );
}

String? Function(String?) _requiredValidator(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  };
}

String? Function(String?) _phoneValidator(String requiredMessage) {
  return _exactDigitsValidator(
    requiredMessage: requiredMessage,
    lengthMessage: 'เบอร์โทรศัพท์ต้องมี 10 หลัก',
    length: 10,
  );
}

String? _optionalEmailValidator(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return null;
  if (!email.contains('@') || !email.contains('.')) {
    return 'กรุณากรอกอีเมลให้ถูกต้อง';
  }
  return null;
}

String? Function(String?) _exactDigitsValidator({
  required String requiredMessage,
  required String lengthMessage,
  required int length,
}) {
  return (value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return requiredMessage;
    if (digits.length != length) return lengthMessage;
    return null;
  };
}

String? _titleValue(String value) {
  final title = _profileTitle(value);
  return _titleOptions.contains(title) ? title : null;
}

String _profileTitle(dynamic value) {
  final title = textOf(value).trim();
  if (title == 'น.ส.' || title == 'นส') return 'นางสาว';
  return _titleOptions.contains(title) ? title : '';
}

String? _bloodGroupValue(String value) {
  final group = _profileBloodGroup(value);
  return _bloodGroupOptions.contains(group) ? group : null;
}

String _profileBloodGroup(dynamic value) {
  final group = textOf(value).trim().toUpperCase();
  return _bloodGroupOptions.contains(group) ? group : '';
}

/// Parse a stored birth date (ISO 'YYYY-MM-DD' or full ISO timestamp) into a
/// local DateTime, or null when missing/unparseable.
DateTime? _parseBirthDate(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Format a birth date as the 'YYYY-MM-DD' string the API expects, or null.
String? _formatBirthDate(DateTime? date) {
  if (date == null) return null;
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

const _thaiMonthsAbbr = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

/// Whole years between [birth] and today.
int _ageFromBirthDate(DateTime birth) {
  final now = DateTime.now();
  var age = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    age--;
  }
  return age;
}

/// Human label for a chosen birth date, e.g. "15 ม.ค. 2543 · อายุ 25 ปี"
/// (Buddhist era year for display, with the computed age).
String _birthDateLabel(DateTime date) {
  final month = _thaiMonthsAbbr[date.month - 1];
  final buddhistYear = date.year + 543;
  return '${date.day} $month $buddhistYear · อายุ ${_ageFromBirthDate(date)} ปี';
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

List<_AddonOption> _addonOptionsFrom(Map<String, dynamic> trip) {
  final mustKnow = asMap(trip['must_know']);
  final rawItems = mustKnow.isNotEmpty
      ? asList(mustKnow['items'])
      : asList(trip['must_know']);
  final options = <_AddonOption>[];

  for (var i = 0; i < rawItems.length; i++) {
    final item = rawItems[i];
    final data = asMap(item);
    final name = item is String
        ? item.trim()
        : textOf(data['name'] ?? data['title'] ?? data['label']).trim();
    final price = _asNum(data['price']);
    if (name.isEmpty || price <= 0) continue;

    options.add(
      _AddonOption(
        index: i,
        name: name,
        price: price,
        priceType: data['price_type'] == 'per_person'
            ? 'per_person'
            : 'per_booking',
        imageUrl: textOf(data['image_url']).trim(),
      ),
    );
  }

  return options;
}

int? _validDropdownValue(int? selected, Iterable<int> values) {
  final ids = values.toList();
  if (ids.isEmpty) return null;
  if (selected != null && ids.contains(selected)) return selected;
  return ids.first;
}

String? _validStringDropdownValue(String? selected, Iterable<String> values) {
  final ids = values.where((value) => value.isNotEmpty).toList();
  if (ids.isEmpty) return null;
  if (selected != null && ids.contains(selected)) return selected;
  return ids.first;
}

num _asNum(dynamic value) {
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _preferredPickupPoint(
  List<dynamic> points, {
  int? preferredPickupPointId,
  String? preferredRegion,
}) {
  if (points.isEmpty) return <String, dynamic>{};

  if (preferredPickupPointId != null) {
    final match = points
        .map(asMap)
        .where(
          (point) =>
              int.tryParse(point['id'].toString()) == preferredPickupPointId,
        );
    if (match.isNotEmpty) return match.first;
  }

  if (preferredRegion != null && preferredRegion.isNotEmpty) {
    final match = points
        .map(asMap)
        .where((point) => _pickupRegionKey(point) == preferredRegion);
    if (match.isNotEmpty) return match.first;
  }

  return asMap(points.first);
}

List<Map<String, dynamic>> _pickupRegionOptions(
  List<Map<String, dynamic>> points,
) {
  final options = <String, Map<String, dynamic>>{};
  for (final point in points) {
    final region = _pickupRegionKey(point);
    if (region.isEmpty || options.containsKey(region)) continue;
    options[region] = point;
  }
  return options.values.toList();
}

bool _scheduleHasPickupRegion(Map<String, dynamic> schedule, String regionKey) {
  return asList(
    schedule['pickup_points'],
  ).map(asMap).any((point) => _pickupRegionKey(point) == regionKey);
}

String _pickupRegionKey(Map<String, dynamic> point) {
  final region = textOf(point['region']).trim();
  if (region.isNotEmpty) return region;
  return textOf(point['region_label']).trim();
}

String _pickupRegionLabel(Map<String, dynamic> point) {
  return textOf(point['region_label'] ?? point['region'], 'ยังไม่ระบุภูมิภาค');
}

String _pickupLocationLabel(Map<String, dynamic> point) {
  return textOf(
    point['pickup_location'] ?? point['region_label'] ?? point['region'],
    'ยังไม่ระบุจุดขึ้นรถ',
  );
}

String _pickupPriceText(dynamic value) {
  final price = _asNum(value);
  if (price <= 0) return 'ไม่มีค่าใช้จ่ายเพิ่ม';
  return money(price);
}

List<String> _vehicleImageUrls(Map<String, dynamic> vehicle) {
  final urls = <String>[];

  void addUrl(dynamic value) {
    final url = ApiConfig.mediaUrl(value);
    if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
  }

  for (final item in asList(vehicle['images'])) {
    final value = item is Map
        ? asMap(item)['url'] ?? asMap(item)['image'] ?? asMap(item)['path']
        : item;
    addUrl(value);
  }

  addUrl(vehicle['image']);
  addUrl(vehicle['photo']);
  addUrl(vehicle['thumbnail_image']);
  addUrl(vehicle['cover_image']);

  return urls;
}

bool _sameStringList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

_ImageCacheSize _cacheSizeFor(
  BuildContext context, {
  required double width,
  required double height,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
  return _ImageCacheSize(
    width: (width * dpr).round().clamp(1, 1200),
    height: (height * dpr).round().clamp(1, 900),
  );
}

bool _isSeatAvailable(Map<String, dynamic> seat) {
  final status = textOf(seat['status'], 'available');
  return status != 'booked' && status != 'locked';
}

bool _seatLockedByCurrentUser(Map<String, dynamic> seat) {
  return _asBool(seat['locked_by_current_user']);
}

String _seatTooltip(
  Map<String, dynamic>? seat,
  String id, {
  required bool selected,
}) {
  if (seat == null) return '$id ไม่พร้อมใช้งาน';
  if (selected) return '$id กำลังเลือก';

  final status = textOf(seat['status'], 'available');
  if (status == 'booked') return '$id จองแล้ว';
  if (status == 'locked') {
    final remaining = _seatLockRemainingText(seat);
    if (_seatLockedByCurrentUser(seat)) {
      return remaining.isEmpty
          ? '$id คุณกำลังจองอยู่'
          : '$id คุณกำลังจองอยู่ เหลือ $remaining';
    }
    return remaining.isEmpty
        ? '$id มีผู้ใช้อื่นกำลังจองอยู่'
        : '$id มีผู้ใช้อื่นกำลังจองอยู่ เหลือ $remaining';
  }

  return '$id ว่าง';
}

String _seatLockRemainingText(Map<String, dynamic> seat) {
  final seconds = int.tryParse(textOf(seat['locked_ttl_seconds'])) ?? 0;
  if (seconds <= 0) return '';
  final minutes = seconds ~/ 60;
  final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainingSeconds นาที';
}

/// Fill + glyph colors for a single seat tile, tuned for a soft, iOS-like
/// palette: muted tints rather than candy-bright blocks, with only the
/// selected seat carrying the full brand accent.
class _SeatVisual {
  final Color fill;
  final Color glyph;
  final Color badge;

  const _SeatVisual({
    required this.fill,
    required this.glyph,
    required this.badge,
  });
}

_SeatVisual _seatVisual({required String status, required bool selected}) {
  if (selected) {
    return const _SeatVisual(
      fill: _softAccent,
      glyph: Colors.white,
      badge: Colors.white,
    );
  }
  switch (status) {
    case 'booked':
      return const _SeatVisual(
        fill: Color(0xFFEFEFF1),
        glyph: Color(0xFFC4C8CF),
        badge: Color(0xFF9CA3AF),
      );
    case 'locked':
      return const _SeatVisual(
        fill: Color(0xFFFFF3E0),
        glyph: Color(0xFFE08A00),
        badge: Color(0xFFE08A00),
      );
    default: // available
      return const _SeatVisual(
        fill: Color(0xFFE7F6EE),
        glyph: _softAccent,
        badge: _softAccent,
      );
  }
}

Map<String, dynamic>? _seatById(Map<String, dynamic> seatMap, String id) {
  for (final item in asList(seatMap['seats'])) {
    final seat = asMap(item);
    if (textOf(seat['id']) == id) return seat;
  }
  return null;
}

List<_SeatRowData> _seatRows(Map<String, dynamic> seatMap) {
  final rows = int.tryParse(textOf(seatMap['rows'])) ?? 0;
  final columns = asList(
    seatMap['columns'],
  ).map((item) => item?.toString() ?? '').toList();
  final frontSeatId = textOf(seatMap['front_seat']);
  final centerSeatIds = asList(
    seatMap['last_row_center'],
  ).map((item) => item?.toString() ?? '').toSet();
  final result = <_SeatRowData>[];

  for (var rowIndex = 1; rowIndex <= rows; rowIndex++) {
    final left = <String>[];
    final right = <String>[];
    final center = <String>[];
    var hasAisle = false;
    var inRight = false;

    for (final column in columns) {
      if (column.isEmpty) {
        hasAisle = true;
        inRight = true;
        continue;
      }

      final seatId = '$column$rowIndex';
      if (seatId == frontSeatId) continue;
      if (_seatById(seatMap, seatId) == null) continue;

      if (centerSeatIds.contains(seatId)) {
        center.add(seatId);
      } else if (inRight) {
        right.add(seatId);
      } else {
        left.add(seatId);
      }
    }

    if (left.isEmpty && right.isEmpty && center.isEmpty) continue;

    result.add(
      _SeatRowData(
        left: left,
        right: right,
        center: center,
        hasAisle: hasAisle && right.isNotEmpty,
      ),
    );
  }

  return result;
}
