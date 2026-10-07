import '../widgets/travel_widgets.dart' show asMap, scheduleDepartsAt, textOf;

/// ใบจองที่ปุ่ม QR กลางแถบเมนูต้องโชว์ — เรียงจากทริปที่ใกล้ที่สุดก่อน
///
/// กติกาเดียวกับการ์ดเช็คอินในใบจอง: ต้อง `confirmed` แล้วเท่านั้น (ใบที่ยังรอ
/// ชำระ/รอตรวจสลิปยังไม่มี QR ที่สตาฟสแกนผ่าน) และไม่ใช่รอบที่ออกไม่ได้เพราะ
/// เหตุสุดวิสัยซึ่งยังรอเลือกรอบใหม่ ทริปยังอยู่ในจอจนถึงวันกลับ — ระหว่างทริป
/// หลายวันลูกค้ายังอยากเห็นว่า "เช็คอินแล้ว" แต่พ้นวันกลับไปแล้วก็ไม่เกี่ยวอีก
///
/// รับ [now] เพื่อให้เทสต์ล็อกวันได้ ใช้เวลาเครื่อง (ไทย) เหมือนตัวช่วยวันที่อื่น ๆ
/// ในแอป ไม่ใช่ UTC
List<Map<String, dynamic>> checkInPassBookings(
  List<dynamic> bookings, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final seen = <String>{};
  final eligible = <Map<String, dynamic>>[];

  for (final raw in bookings) {
    final booking = asMap(raw);
    if (booking.isEmpty) continue;
    if (textOf(booking['status']).toLowerCase() != 'confirmed') continue;
    if (asMap(booking['force_majeure'])['awaiting'] == true) continue;

    // รายการจองต่อท้ายด้วยหน้าประวัติ — ใบเดียวกันห้ามขึ้นสองหน้า
    final key = textOf(booking['booking_ref'], textOf(booking['id']));
    if (key.isEmpty || !seen.add(key)) continue;

    final end = checkInPassEndDate(booking);
    if (end != null && today.isAfter(end)) continue;
    eligible.add(booking);
  }

  // ใบที่ไม่มีวันเดินทางเลย (ข้อมูลไม่ครบ) ไปต่อท้าย ไม่แย่งที่ใบที่รู้วัน
  eligible.sort((a, b) {
    final da = checkInPassTravelDate(a);
    final db = checkInPassTravelDate(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return eligible;
}

/// วันออกรถจริง (ตัดเวลา) — รอบที่รถออกคืนก่อนวันทริปนับจากคืนนั้น
DateTime? checkInPassTravelDate(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  final date =
      scheduleDepartsAt(schedule) ??
      DateTime.tryParse(textOf(schedule['departure_date']));
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day);
}

/// วันสุดท้ายที่ QR ยังเกี่ยวข้อง: วันกลับ หรือวันเดินทางถ้ารอบไม่มีวันกลับ
DateTime? checkInPassEndDate(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  final ret =
      DateTime.tryParse(textOf(schedule['return_date'])) ??
      DateTime.tryParse(textOf(schedule['departure_date']));
  final start = checkInPassTravelDate(booking);
  if (ret == null) return start;
  final end = DateTime(ret.year, ret.month, ret.day);
  if (start != null && start.isAfter(end)) return start;
  return end;
}

/// ป้ายบอกระยะห่างของทริป — "วันนี้" / "พรุ่งนี้" / "อีก N วัน" / "ระหว่างทริป"
String checkInPassWhenLabel(Map<String, dynamic> booking, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final start = checkInPassTravelDate(booking);
  if (start == null) return '';
  // ปัดเป็นวันเต็ม — นับเป็นชั่วโมงหารตรง ๆ จะคลาดหนึ่งวันในเขตเวลาที่มี DST
  final days = (start.difference(today).inHours / 24).round();
  if (days > 1) return 'อีก $days วัน';
  if (days == 1) return 'พรุ่งนี้';
  if (days == 0) return 'วันนี้';
  return 'ระหว่างทริป';
}

/// มีใบจองที่ยังรอชำระ/รอยืนยันอยู่ไหม — ใช้บอกในหน้าว่างว่า QR จะมาหลังยืนยัน
bool hasPendingUpcomingBooking(List<dynamic> bookings, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  for (final raw in bookings) {
    final booking = asMap(raw);
    if (textOf(booking['status']).toLowerCase() != 'pending') continue;
    final end = checkInPassEndDate(booking);
    if (end == null || !today.isAfter(end)) return true;
  }
  return false;
}
