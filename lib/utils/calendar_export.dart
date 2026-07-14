import 'package:add_2_calendar/add_2_calendar.dart';

/// เพิ่มวันเดินทางของทริปลงในปฏิทินของเครื่อง (เปิดหน้าเพิ่มอีเวนต์ของ OS).
///
/// เวลาออกรถจริง (`departsAt`) มาก่อนเสมอ เพราะบางรอบรถออกคืนก่อนวันทริป —
/// ถ้าไม่มีเวลา ให้สร้างเป็นอีเวนต์ทั้งวัน (all-day) จาก `departureDate`.
/// ค่าที่ส่งเข้ามาเป็นเวลาท้องถิ่นไทย จึง fix timeZone เป็น Asia/Bangkok.
Future<bool> addTripToCalendar({
  required String title,
  DateTime? departsAt,
  DateTime? departureDate,
  DateTime? returnDate,
  String? location,
  String? description,
}) {
  final hasTime = departsAt != null;
  final DateTime start;
  final DateTime end;

  if (hasTime) {
    start = departsAt;
    // End on the return day (early evening) for multi-day trips, otherwise pad
    // a few hours so the event isn't zero-length.
    end = (returnDate != null &&
            !returnDate.isBefore(DateTime(start.year, start.month, start.day)))
        ? DateTime(returnDate.year, returnDate.month, returnDate.day, 18)
        : start.add(const Duration(hours: 8));
  } else {
    final day = departureDate ?? DateTime.now();
    start = DateTime(day.year, day.month, day.day);
    final ret = returnDate ?? day;
    end = DateTime(ret.year, ret.month, ret.day);
  }

  final event = Event(
    title: title,
    description: description ?? '',
    location: location ?? '',
    startDate: start,
    endDate: end,
    allDay: !hasTime,
    timeZone: 'Asia/Bangkok',
  );

  return Add2Calendar.addEvent2Cal(event);
}
