/// ปฏิทินทริปรายเดือน — ข้อมูลจาก `GET /trips/calendar?month=YYYY-MM`
/// (App\Services\TripCalendarService ชุดเดียวกับหน้าเว็บ /calendar)
///
/// เซิร์ฟเวอร์จัดรอบเป็นวัน ๆ และคิดสถานะที่นั่ง/ป้ายข้อความมาให้แล้ว แอปแค่วาด
/// สิ่งที่แอปคิดเองมีแค่ตารางวันของเดือน และ "วันนี้" ตามเวลาไทย
library;

/// วันที่แบบไม่มีเวลา ("2026-11-06") เป็น DateTime เที่ยงคืนของเครื่อง —
/// ไม่ผ่าน DateTime.parse เพราะสตริงที่มีเวลา/โซนจะเลื่อนวันได้เมื่อแปลงโซน
DateTime? parseCalendarDate(dynamic value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})',
  ).firstMatch('${value ?? ''}'.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  // 2026-02-31 ไม่ใช่วันจริง — DateTime จะปัดเป็นมีนาคมเงียบ ๆ
  if (date.month != month || date.day != day) return null;
  return date;
}

/// "วันนี้" ตามเวลาไทย ไม่ใช่ตามโซนของเครื่อง — รอบทุกรอบนับวันแบบไทย
/// คนที่ตั้งเครื่องไว้โซนอื่นจะได้เห็นวันนี้ตรงกับที่เซิร์ฟเวอร์ตัดรอบที่ผ่านไปแล้ว
DateTime bangkokToday([DateTime? now]) {
  final t = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  return DateTime(t.year, t.month, t.day);
}

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "2026-11" → (2026, 11)
(int, int)? parseCalendarMonth(String? value) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value ?? '');
  if (match == null) return null;
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return null;
  return (int.parse(match.group(1)!), month);
}

String calendarMonthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

/// ช่องของตารางเดือน เริ่มสัปดาห์ที่วันอาทิตย์แบบปฏิทินไทย ช่องว่างหน้า/ท้าย
/// เดือนเป็น null และความยาวเป็นจำนวนเต็มสัปดาห์เสมอ (4–6 แถว)
List<DateTime?> monthGridCells(int year, int month) {
  final first = DateTime(year, month, 1);
  final daysInMonth = DateTime(year, month + 1, 0).day;
  // DateTime.weekday: จันทร์ = 1 … อาทิตย์ = 7 → อาทิตย์เป็นช่องแรก (0)
  final leading = first.weekday % 7;
  final cells = <DateTime?>[
    for (var i = 0; i < leading; i++) null,
    for (var d = 1; d <= daysInMonth; d++) DateTime(year, month, d),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}

/// ในประเทศ / ต่างประเทศ — ตัวกรองฝั่งแอป ใช้ `trip.is_international` ในแต่ละรอบ
enum CalendarDestination { all, domestic, international }

class TripCalendarRound {
  final int id;
  final int tripId;
  final String title;
  final String slug;
  final String location;
  final int? durationDays;
  final String coverImage;
  final bool isInternational;
  final DateTime? departureDate;
  final DateTime? returnDate;
  final String dateLabel;
  final num price;
  final num? originalPrice;
  final bool onFlashSale;
  final num? joinTripPrice;
  final int seatsLeft;
  final bool isFull;
  final bool isLow;
  final String statusLabel;
  final String daysLeftLabel;

  const TripCalendarRound({
    required this.id,
    required this.tripId,
    required this.title,
    required this.slug,
    this.location = '',
    this.durationDays,
    this.coverImage = '',
    this.isInternational = false,
    this.departureDate,
    this.returnDate,
    this.dateLabel = '',
    this.price = 0,
    this.originalPrice,
    this.onFlashSale = false,
    this.joinTripPrice,
    this.seatsLeft = 0,
    this.isFull = false,
    this.isLow = false,
    this.statusLabel = '',
    this.daysLeftLabel = '',
  });

  factory TripCalendarRound.fromJson(Map<String, dynamic> json) {
    final trip = _map(json['trip']);
    final seats = _int(json['seats_left']) ?? 0;
    final isFull = _bool(json['is_full']) || seats <= 0;
    final original = _num(json['original_price']);
    final price = _num(json['price']) ?? 0;
    return TripCalendarRound(
      id: _int(json['id']) ?? 0,
      tripId: _int(trip['id']) ?? 0,
      title: _text(trip['title']),
      slug: _text(trip['slug']),
      location: _text(trip['location']),
      durationDays: _int(trip['duration_days']),
      coverImage: _text(trip['cover_image']),
      isInternational: _bool(trip['is_international']),
      departureDate: parseCalendarDate(json['departure_date']),
      returnDate: parseCalendarDate(json['return_date']),
      dateLabel: _text(json['date_label']),
      price: price,
      originalPrice: original != null && original > price ? original : null,
      onFlashSale: _bool(json['on_flash_sale']),
      joinTripPrice: _num(json['join_trip_price']),
      seatsLeft: seats < 0 ? 0 : seats,
      isFull: isFull,
      isLow: !isFull && _bool(json['is_low']),
      statusLabel: _text(json['status_label']),
      daysLeftLabel: _text(json['days_left_label']),
    );
  }

  bool matches(CalendarDestination destination) => switch (destination) {
    CalendarDestination.all => true,
    CalendarDestination.domestic => !isInternational,
    CalendarDestination.international => isInternational,
  };

  /// ป้ายสถานะ — ใช้ข้อความของเซิร์ฟเวอร์ (ตรงกับหน้าเว็บ) ถ้าไม่มีค่อยแต่งเอง
  String get seatLabel {
    if (statusLabel.isNotEmpty) return statusLabel;
    if (isFull) return 'เต็มแล้ว · จองคิวรอได้';
    return isLow ? 'เหลือ $seatsLeft ที่' : 'ว่าง $seatsLeft ที่';
  }
}

class TripCalendarDay {
  final DateTime date;
  final String dateLabel;
  final String weekday;
  final List<TripCalendarRound> rounds;

  const TripCalendarDay({
    required this.date,
    required this.rounds,
    this.dateLabel = '',
    this.weekday = '',
  });

  /// คืน null เมื่อวันที่อ่านไม่ออก — วันที่ไม่มีวันจริงวางลงตารางไม่ได้
  static TripCalendarDay? fromJson(Map<String, dynamic> json) {
    final date = parseCalendarDate(json['date']);
    if (date == null) return null;
    return TripCalendarDay(
      date: date,
      dateLabel: _text(json['date_label']),
      weekday: _text(json['weekday']),
      rounds: _list(json['rounds'])
          .map((e) => TripCalendarRound.fromJson(_map(e)))
          .where((r) => r.id > 0 && r.slug.isNotEmpty)
          .toList(),
    );
  }

  TripCalendarDay withRounds(List<TripCalendarRound> rounds) => TripCalendarDay(
    date: date,
    dateLabel: dateLabel,
    weekday: weekday,
    rounds: rounds,
  );
}

class TripCalendarMonthOption {
  final String value;
  final String label;
  final String shortLabel;
  final bool isCurrent;

  const TripCalendarMonthOption({
    required this.value,
    this.label = '',
    this.shortLabel = '',
    this.isCurrent = false,
  });

  static TripCalendarMonthOption? fromJson(Map<String, dynamic> json) {
    final value = _text(json['value']);
    if (parseCalendarMonth(value) == null) return null;
    return TripCalendarMonthOption(
      value: value,
      label: _text(json['label'], value),
      shortLabel: _text(json['short_label']),
      isCurrent: _bool(json['is_current']),
    );
  }

  /// ชิปเดือนปัจจุบันเขียนว่า "เดือนนี้" แบบเดียวกับหน้าเว็บ
  String get chipLabel => isCurrent ? 'เดือนนี้' : label;
}

class TripCalendarMonth {
  /// "2026-11" — เดือนที่เซิร์ฟเวอร์ตอบกลับจริง (อาจต่างจากที่ขอ เมื่อขอไกลเกิน)
  final String month;
  final int year;
  final int monthNumber;
  final String monthLabel;
  final bool isCurrentMonth;
  final List<TripCalendarMonthOption> months;
  final List<TripCalendarDay> days;
  final List<TripCalendarRound> hot;
  final int hotDays;

  const TripCalendarMonth({
    required this.month,
    required this.year,
    required this.monthNumber,
    this.monthLabel = '',
    this.isCurrentMonth = false,
    this.months = const [],
    this.days = const [],
    this.hot = const [],
    this.hotDays = 10,
  });

  /// คืน null เมื่อไม่มีเดือนที่อ่านได้ — ไม่รู้ว่าเป็นเดือนไหนก็วาดตารางไม่ได้
  static TripCalendarMonth? fromJson(dynamic raw) {
    final json = _map(raw);
    final month = _text(json['month']);
    final parsed = parseCalendarMonth(month);
    if (parsed == null) return null;
    final (year, monthNumber) = parsed;

    final days =
        _list(json['days'])
            .map((e) => TripCalendarDay.fromJson(_map(e)))
            .whereType<TripCalendarDay>()
            // วันที่ไม่ได้อยู่ในเดือนนี้วางลงตารางไม่ได้ ตัดทิ้งไว้ก่อน
            .where((d) => d.date.year == year && d.date.month == monthNumber)
            .where((d) => d.rounds.isNotEmpty)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return TripCalendarMonth(
      month: month,
      year: year,
      monthNumber: monthNumber,
      monthLabel: _text(json['month_label'], month),
      isCurrentMonth: _bool(json['is_current_month']),
      months: _list(json['months'])
          .map((e) => TripCalendarMonthOption.fromJson(_map(e)))
          .whereType<TripCalendarMonthOption>()
          .toList(),
      days: days,
      hot: _list(json['hot'])
          .map((e) => TripCalendarRound.fromJson(_map(e)))
          .where((r) => r.id > 0 && r.slug.isNotEmpty)
          .toList(),
      hotDays: _int(json['hot_days']) ?? 10,
    );
  }

  /// วันที่ยังมีรอบหลังกรองแล้ว — วันที่ไม่เหลือรอบหายไปทั้งวัน
  List<TripCalendarDay> daysFor(CalendarDestination destination) {
    if (destination == CalendarDestination.all) return days;
    return [
      for (final day in days)
        if (day.rounds.where((r) => r.matches(destination)).toList()
            case final rounds when rounds.isNotEmpty)
          day.withRounds(rounds),
    ];
  }

  List<TripCalendarRound> hotFor(CalendarDestination destination) =>
      hot.where((r) => r.matches(destination)).toList();

  /// โชว์ชิปในประเทศ/ต่างประเทศเฉพาะเดือนที่มีทั้งสองฝั่ง —
  /// ถ้ามีฝั่งเดียว ชิปที่กดแล้วได้หน้าว่างไม่ได้ช่วยใคร
  bool get hasBothDestinations {
    final rounds = days.expand((d) => d.rounds);
    return rounds.any((r) => r.isInternational) &&
        rounds.any((r) => !r.isInternational);
  }

  /// เดือนถัดไปในรายการเดือนที่เลือกได้ (ไว้ใส่ปุ่มตอนเดือนนี้ไม่มีรอบ)
  TripCalendarMonthOption? get nextMonth {
    final index = months.indexWhere((m) => m.value == month);
    if (index < 0 || index + 1 >= months.length) return null;
    return months[index + 1];
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic value) => value is List ? value : const [];

String _text(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

num? _num(dynamic value) =>
    value is num ? value : num.tryParse('${value ?? ''}'.trim());

int? _int(dynamic value) => _num(value)?.toInt();

bool _bool(dynamic value) =>
    value == true || value == 1 || value == '1' || value == 'true';
