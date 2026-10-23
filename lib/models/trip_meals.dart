/// มื้ออาหารของทริป — ตอบ "กี่มื้อ มื้อไหน ต้องจ่ายเองไหม"
///
/// ทุกคำและตัวเลขมาจาก backend (`TripMealPlan` ฝั่ง PHP) แอปแค่อ่านแล้ววาด
/// ไม่นับเองและไม่แต่งประโยคเอง หน้าทริป หน้าสรุปก่อนจ่าย ใบจอง และห้องแชท
/// จะได้พูดตรงกันกับหน้าเว็บ ใบเดินทาง และบอทในห้องเสมอ
class TripMeals {
  final List<TripMealDay> days;
  final int includedCount;
  final int selfCount;

  /// ป้ายสั้นข้างจำนวนวัน — "อาหาร 5 มื้อ" / "ไม่รวมอาหาร"
  final String label;

  /// ประโยคเต็ม — "รวมอาหาร 5 มื้อ · จ่ายเอง 1 มื้อ"
  final String summary;
  final String? note;

  const TripMeals({
    required this.days,
    required this.includedCount,
    required this.selfCount,
    required this.label,
    required this.summary,
    required this.note,
  });

  /// null เมื่อทริปยังไม่ได้ระบุมื้ออาหาร (หรือ backend รุ่นเก่าที่ยังไม่ส่งคีย์นี้)
  /// — หน้าจอต้องซ่อนทั้งก้อน ไม่ใช่โชว์ "ไม่รวมอาหาร"
  static TripMeals? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final days = (raw['days'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => TripMealDay.fromJson(Map<String, dynamic>.from(e)))
        .where((day) => day.meals.isNotEmpty)
        .toList();
    final summary = _text(raw['summary']);
    if (days.isEmpty || summary == null) return null;

    return TripMeals(
      days: days,
      includedCount: int.tryParse('${raw['included_count']}') ?? 0,
      selfCount: int.tryParse('${raw['self_count']}') ?? 0,
      label: _text(raw['label']) ?? summary,
      summary: summary,
      note: _text(raw['note']),
    );
  }

  /// แสดงวันที่จริงต่อท้ายหัววันไหม — ทริปวันเดียวไม่ต้อง (หัวหน้าบอกวันอยู่แล้ว)
  bool get showDates => days.length > 1 && days.any((d) => d.dateLabel != null);
}

class TripMealDay {
  final int day;
  final String label;
  final String? dateLabel;
  final List<TripMeal> meals;

  /// หนึ่งวันเป็นข้อความ — "เช้า · กลางวัน – ข้าวกล่อง · เย็น (จ่ายเอง)"
  final String line;

  const TripMealDay({
    required this.day,
    required this.label,
    required this.dateLabel,
    required this.meals,
    required this.line,
  });

  factory TripMealDay.fromJson(Map<String, dynamic> json) {
    final day = int.tryParse('${json['day']}') ?? 0;
    return TripMealDay(
      day: day,
      label: _text(json['label']) ?? 'วันที่ $day',
      dateLabel: _text(json['date_label']),
      meals: (json['meals'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => TripMeal.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      line: _text(json['line']) ?? '',
    );
  }
}

enum TripMealStatus { included, selfPay, none }

class TripMeal {
  final String key;
  final String label;
  final TripMealStatus status;
  final String statusLabel;
  final String? note;

  const TripMeal({
    required this.key,
    required this.label,
    required this.status,
    required this.statusLabel,
    required this.note,
  });

  factory TripMeal.fromJson(Map<String, dynamic> json) {
    // สถานะที่ไม่รู้จักถือเป็น "ไม่มี" — บอกว่ามีอาหารทั้งที่ไม่มี แย่กว่าบอกน้อยไป
    final status = switch (json['status']?.toString()) {
      'included' => TripMealStatus.included,
      'self' => TripMealStatus.selfPay,
      _ => TripMealStatus.none,
    };
    return TripMeal(
      key: json['key']?.toString() ?? '',
      label: _text(json['label']) ?? '',
      status: status,
      statusLabel:
          _text(json['status_label']) ??
          switch (status) {
            TripMealStatus.included => 'รวมในราคา',
            TripMealStatus.selfPay => 'จ่ายเอง',
            TripMealStatus.none => 'ไม่มี',
          },
      note: status == TripMealStatus.none ? null : _text(json['note']),
    );
  }
}

String? _text(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
