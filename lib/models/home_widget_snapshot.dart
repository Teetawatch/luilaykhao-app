/// ข้อมูลของวิดเจ็ตหน้าโฮมหนึ่งก้อน ตามที่เซิร์ฟเวอร์บอกมา
///
/// ข้อความไทยทุกบรรทัดในนี้ถูกเขียนมาแล้วจากฝั่ง Laravel (`HomeWidgetService`)
/// เหมือนการ์ดวันเดินทาง — แอปไม่แต่งประโยคเอง มีข้อยกเว้นข้อเดียวคือตัวเลข
/// "อีก N วัน" ที่ฝั่ง native นับใหม่จาก [HomeWidgetTrip.departureDate] ทุกครั้งที่
/// วาด เพราะวิดเจ็ตต้องนับถอยหลังถูกต้องข้ามคืนโดยไม่มีใครเปิดแอป
///
/// หน้าที่ของคลาสนี้คือ "ล้างชนิดข้อมูลให้เรียบร้อยก่อนข้ามไปฝั่ง native" —
/// PHP ส่ง 0 มาตรงที่ควรเป็น 0.0 ได้ ส่ง "3" มาตรงที่ควรเป็น 3 ได้ ถ้าปล่อยผ่านไป
/// ตรง ๆ ตัวถอดรหัสฝั่ง Swift/Kotlin จะพังทั้งก้อนแล้ววิดเจ็ตจะว่างเปล่าโดยไม่มี
/// ร่องรอยให้ตามหา
class HomeWidgetSnapshot {
  /// เวอร์ชันสัญญาที่ฝั่ง native ในบิลด์นี้อ่านได้ — ต้องตรงกับ
  /// `HomeWidgetService::SNAPSHOT_VERSION` ฝั่ง Laravel
  static const contractVersion = 1;

  /// ส่งต่อค่าที่เซิร์ฟเวอร์บอกมาตรง ๆ ไม่ทับด้วย [contractVersion] โดยตั้งใจ:
  /// ถ้าเซิร์ฟเวอร์ขึ้นเวอร์ชันก่อนที่แอปเครื่องนี้จะอัปเดต ฝั่ง native ต้องได้
  /// เห็นเลขจริงแล้วเลือกแสดงสถานะว่าง ดีกว่าวาดข้อมูลที่ตัวเองแปลผิด
  final int version;
  final String? generatedAt;
  final HomeWidgetTrip? trip;
  final HomeWidgetPayment? payment;

  const HomeWidgetSnapshot({
    required this.version,
    this.generatedAt,
    this.trip,
    this.payment,
  });

  static HomeWidgetSnapshot? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    return HomeWidgetSnapshot(
      version: _int(json['version']) ?? contractVersion,
      generatedAt: _string(json['generated_at']),
      trip: HomeWidgetTrip.fromJson(_map(json['trip'])),
      payment: HomeWidgetPayment.fromJson(_map(json['payment'])),
    );
  }

  bool get isEmpty => trip == null && payment == null;

  /// รูปแบบที่ฝั่ง native รอรับ — คีย์ชุดเดียวกับที่เซิร์ฟเวอร์ส่งมา (snake_case)
  /// เพื่อให้มีคำศัพท์ชุดเดียวตลอดสาย Laravel → Dart → Swift/Kotlin
  Map<String, dynamic> toNativeJson() => {
    'version': version,
    'generated_at': generatedAt,
    'trip': trip?.toNativeJson(),
    'payment': payment?.toNativeJson(),
  };
}

class HomeWidgetTrip {
  final String bookingRef;
  final String tripTitle;

  /// "2026-09-05" — ฝั่ง native นับ "อีกกี่วัน" ใหม่จากค่านี้
  final String? departureDate;

  /// วันสุดท้ายที่ก้อนนี้ยังจริง (วันกลับ) — ฝั่ง native เก็บการ์ดออกเองเมื่อเลยไปแล้ว
  final String? validUntil;
  final String dateLabel;
  final String? departTime;
  final int countdownDays;
  final String headline;
  final String detail;
  final String stage;
  final int? etaMinutes;
  final double progress;

  /// true = อยู่ในช่วงที่การ์ดหน้าจอล็อกทำงาน ให้เชื่อ [headline] ที่ส่งมาทั้งดุ้น
  /// false = ยังไม่ถึงวันเดินทาง ฝั่ง native นับวันเองได้
  final bool isLive;

  const HomeWidgetTrip({
    required this.bookingRef,
    required this.tripTitle,
    required this.dateLabel,
    required this.countdownDays,
    required this.headline,
    required this.detail,
    required this.stage,
    required this.progress,
    required this.isLive,
    this.departureDate,
    this.validUntil,
    this.departTime,
    this.etaMinutes,
  });

  static HomeWidgetTrip? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final ref = _string(json['booking_ref']);
    // ไม่มีเลขการจองก็ไม่มีที่ให้แตะไป และแปลว่าก้อนนี้เพี้ยน — ทิ้งทั้งบล็อก
    if (ref == null) return null;

    return HomeWidgetTrip(
      bookingRef: ref,
      tripTitle: _string(json['trip_title']) ?? 'ทริปของคุณ',
      departureDate: _string(json['departure_date']),
      validUntil: _string(json['valid_until']),
      dateLabel: _string(json['date_label']) ?? '',
      departTime: _string(json['depart_time']),
      countdownDays: _int(json['countdown_days']) ?? 0,
      headline: _string(json['headline']) ?? 'ทริปของคุณ',
      detail: _string(json['detail']) ?? '',
      stage: _string(json['stage']) ?? 'countdown',
      etaMinutes: _int(json['eta_minutes']),
      progress: (_double(json['progress']) ?? 0).clamp(0.0, 1.0),
      isLive: json['is_live'] == true,
    );
  }

  Map<String, dynamic> toNativeJson() => {
    'booking_ref': bookingRef,
    'trip_title': tripTitle,
    'departure_date': departureDate,
    'valid_until': validUntil,
    'date_label': dateLabel,
    'depart_time': departTime,
    'countdown_days': countdownDays,
    'headline': headline,
    'detail': detail,
    'stage': stage,
    'eta_minutes': etaMinutes,
    'progress': progress,
    'is_live': isLive,
  };
}

class HomeWidgetPayment {
  final String bookingRef;
  final String tripTitle;
  final String label;
  final double amount;
  final String amountLabel;
  final String? dueDate;
  final String dueLabel;
  final int? daysLeft;
  final bool overdue;
  final bool slipPending;

  const HomeWidgetPayment({
    required this.bookingRef,
    required this.tripTitle,
    required this.label,
    required this.amount,
    required this.amountLabel,
    required this.dueLabel,
    required this.overdue,
    required this.slipPending,
    this.dueDate,
    this.daysLeft,
  });

  static HomeWidgetPayment? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final ref = _string(json['booking_ref']);
    if (ref == null) return null;

    return HomeWidgetPayment(
      bookingRef: ref,
      tripTitle: _string(json['trip_title']) ?? 'ทริปของคุณ',
      label: _string(json['label']) ?? 'ยอดค้างชำระ',
      amount: _double(json['amount']) ?? 0,
      amountLabel: _string(json['amount_label']) ?? '',
      dueDate: _string(json['due_date']),
      dueLabel: _string(json['due_label']) ?? '',
      daysLeft: _int(json['days_left']),
      overdue: json['overdue'] == true,
      slipPending: json['slip_pending'] == true,
    );
  }

  Map<String, dynamic> toNativeJson() => {
    'booking_ref': bookingRef,
    'trip_title': tripTitle,
    'label': label,
    'amount': amount,
    'amount_label': amountLabel,
    'due_date': dueDate,
    'due_label': dueLabel,
    'days_left': daysLeft,
    'overdue': overdue,
    'slip_pending': slipPending,
  };
}

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

/// สตริงว่างถือว่าไม่มีค่า — ฝั่ง native จะได้ไม่ต้องเช็ค `isEmpty` ทุกจุดที่วาด
String? _string(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value == null) return null;
  return int.tryParse(value.toString());
}

double? _double(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString());
}
