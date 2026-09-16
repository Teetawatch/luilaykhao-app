import 'package:flutter/foundation.dart';

import '../providers/app_provider.dart';
import 'offline_cache.dart';

/// ชุดข้อมูลหน้างานของ "สตาฟ" ที่เก็บไว้ใช้ตอนไม่มีสัญญาณ
///
/// ฝั่งลูกค้ามี [TripDayPack] ทำเรื่องนี้อยู่แล้ว แต่ฝั่งสตาฟไม่เคยมี ทั้งที่
/// ของที่สตาฟต้องเปิดบนดอยหนักกว่า: รายชื่อผู้โดยสาร เบอร์โทรรายคน ผู้ติดต่อ
/// ฉุกเฉิน อาการแพ้ และโรคประจำตัว หน้ารายชื่อเดิมยิง API สดทุกครั้ง แปลว่าใน
/// นาทีที่มีคนเป็นลมกลางทาง มันคือหน้าจอว่างที่ขึ้นว่า "โหลดไม่สำเร็จ"
///
/// ตัวนี้จึงดึงล่วงหน้าตั้งแต่ตอนยังมีสัญญาณ (D-1 ถึงวันกลับ) ลง [OfflineCache]
/// ชุดเดียวกับที่หน้ารายชื่ออ่านอยู่แล้ว — หน้าที่ของมันคือ "ทำให้แคชมีของ"
class StaffTripPack {
  StaffTripPack._();

  /// ดึงล่วงหน้ากี่วันก่อนออกเดินทาง — สตาฟรู้ตารางตัวเองล่วงหน้าอยู่แล้วและ
  /// มักเปิดแอปเช็ครายชื่อคืนก่อนเดินทาง หนึ่งวันจึงพอ และไม่ไปดึงของทั้งเดือน
  static const int prefetchWindowDays = 1;

  /// เว้นช่วงก่อนดึงซ้ำ — รายชื่อเปลี่ยนได้ (คนยกเลิก/ย้ายจุดรับ) แต่ไม่ใช่ทุกนาที
  static const Duration minRefreshInterval = Duration(hours: 3);

  static String _metaKey(int scheduleId) => 'staff_pack.$scheduleId';

  /// รอบของสตาฟที่ควรมีของติดเครื่องไว้ ณ ตอนนี้ — รับ `staffSchedules` ตรง ๆ
  static List<int> dueScheduleIds(List<dynamic> schedules) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = <int>[];

    for (final raw in schedules) {
      if (raw is! Map) continue;
      final id = int.tryParse('${raw['id']}') ?? 0;
      if (id <= 0) continue;

      // รอบที่ถูกยกเลิกไม่ต้องแบกไว้ — ไม่มีใครไปที่จุดรับของมัน
      final status = '${raw['status'] ?? ''}';
      if (status == 'cancelled') continue;

      final departure = DateTime.tryParse('${raw['departure_date']}');
      if (departure == null) continue;
      final returnDate =
          DateTime.tryParse('${raw['return_date']}') ?? departure;

      final start = DateTime(
        departure.year,
        departure.month,
        departure.day,
      ).subtract(const Duration(days: prefetchWindowDays));
      final end = DateTime(returnDate.year, returnDate.month, returnDate.day);

      if (!today.isBefore(start) && !today.isAfter(end)) {
        due.add(id);
      }
    }

    return due;
  }

  /// ดึงของของทุกรอบที่ใกล้ถึง — เรียกแบบ fire-and-forget ได้
  static Future<void> prefetch(AppProvider app, {bool force = false}) async {
    if (!app.isLoggedIn || !app.canUseStaffCheckIn) return;

    for (final scheduleId in dueScheduleIds(app.staffSchedules)) {
      if (!force && !_isStale(scheduleId)) continue;
      await packOne(app, scheduleId);
    }
  }

  /// ดึงของของรอบเดียว คืน true เมื่อได้อย่างน้อยหนึ่งชิ้น
  static Future<bool> packOne(AppProvider app, int scheduleId) async {
    if (scheduleId <= 0) return false;

    var packed = 0;

    // รายชื่อผู้โดยสาร — ตัว loadStaffManifest แคชให้เองเมื่อดึงสำเร็จ
    try {
      final manifest = await app.loadStaffManifest(scheduleId);
      if (!manifest.fromCache) packed++;
    } catch (e) {
      debugPrint('StaffTripPack: manifest $scheduleId failed — $e');
    }

    // เบอร์สำรองของรอบ (สตาฟด้วยกัน คนขับ ศูนย์ช่วยเหลือ เบอร์ฉุกเฉินราชการ)
    try {
      await app.sosContacts(scheduleId);
      packed++;
    } catch (e) {
      debugPrint('StaffTripPack: sos contacts $scheduleId failed — $e');
    }

    if (packed == 0) return false;

    OfflineCache.instance.writeAccount(_metaKey(scheduleId), {
      'saved_at': DateTime.now().toIso8601String(),
      'parts': packed,
    });
    await OfflineCache.instance.flush();

    return true;
  }

  /// เวลาที่ชุดข้อมูลของรอบนี้ถูกบันทึกล่าสุด — null คือยังไม่เคยสำเร็จ
  static DateTime? savedAt(int scheduleId) {
    final meta = OfflineCache.instance.readAccount<Map>(_metaKey(scheduleId));
    if (meta == null) return null;
    return DateTime.tryParse('${meta['saved_at']}')?.toLocal();
  }

  static bool _isStale(int scheduleId) {
    final saved = savedAt(scheduleId);
    if (saved == null) return true;
    return DateTime.now().difference(saved) >= minRefreshInterval;
  }
}
