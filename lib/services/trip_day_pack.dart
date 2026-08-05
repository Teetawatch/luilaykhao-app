import 'package:flutter/foundation.dart';

import '../providers/app_provider.dart';
import 'offline_cache.dart';

/// ชุดข้อมูล "วันเดินทาง" ที่เก็บไว้ใช้ตอนไม่มีสัญญาณ
///
/// ทริปของที่นี่จบลงในที่ที่ไม่มีเน็ต — ถนนบนดอย ที่กางเต็นท์ ทางเดินป่า ซึ่ง
/// เป็นช่วงเวลาเดียวกับที่ลูกค้าต้องการข้อมูลมากที่สุด: กำหนดการช่วงถัดไป
/// ประกาศจากผู้จัด จุดขึ้นรถ เบอร์สตาฟ หน้าจอเหล่านี้แต่ละหน้าจะแคชของตัวเอง
/// ก็ต่อเมื่อ "เคยเปิดตอนมีเน็ต" ซึ่งเป็นเงื่อนไขที่คนส่วนใหญ่ไม่ผ่าน — พอถึง
/// หน้างานถึงเปิดครั้งแรก แล้วก็เปิดไม่ขึ้น
///
/// ตัวนี้จึงดึงล่วงหน้าให้เองตั้งแต่ตอนยังมีเน็ต (D-2 ถึงวันกลับ) เก็บลง
/// [OfflineCache] ชุดเดียวกับที่หน้าจอเหล่านั้นอ่านอยู่แล้ว ไม่ได้สร้างชั้น
/// ข้อมูลใหม่ซ้อน — หน้าที่ของมันคือ "ทำให้แคชมีของ" ไม่ใช่เป็นแคชเอง
class TripDayPack {
  TripDayPack._();

  /// ดึงล่วงหน้ากี่วันก่อนออกเดินทาง — 2 วันพอให้คนที่เปิดแอปเช็คของก่อนนอน
  /// คืนก่อนเดินทางได้ครบ โดยไม่ไปดึงของรอบที่ยังอีกเป็นเดือน
  static const int prefetchWindowDays = 2;

  /// เว้นช่วงก่อนดึงซ้ำ — เปิดแอปวันละหลายรอบไม่ควรยิง API ชุดเดิมทุกครั้ง
  static const Duration minRefreshInterval = Duration(hours: 6);

  static String _metaKey(int scheduleId) => 'tripday_pack.$scheduleId';

  static String _announcementsKey(int scheduleId) =>
      'tripday_announcements.$scheduleId';

  /// รอบที่ควรมีชุดออฟไลน์ติดเครื่องไว้ ณ ตอนนี้
  ///
  /// นับจากวันออกเดินทางถึงวันกลับ (รวมวันกลับ) — ทริปสองวันจึงยังอยู่ในชุดนี้
  /// ตอนอยู่บนดอยคืนแรก ไม่ใช่หลุดออกไปตั้งแต่เที่ยงวันแรก
  static List<Map<String, dynamic>> dueBookings(List<dynamic> bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = <Map<String, dynamic>>[];

    for (final raw in bookings) {
      if (raw is! Map) continue;
      final booking = Map<String, dynamic>.from(raw);
      final status = booking['status']?.toString() ?? '';
      if (status != 'confirmed' && status != 'pending') continue;

      final schedule = booking['schedule'];
      if (schedule is! Map) continue;
      final scheduleId = int.tryParse('${schedule['id']}') ?? 0;
      if (scheduleId <= 0) continue;

      final departure = DateTime.tryParse('${schedule['departure_date']}');
      if (departure == null) continue;
      final returnDate =
          DateTime.tryParse('${schedule['return_date']}') ?? departure;

      final start = DateTime(
        departure.year,
        departure.month,
        departure.day,
      ).subtract(const Duration(days: prefetchWindowDays));
      final end = DateTime(returnDate.year, returnDate.month, returnDate.day);

      if (!today.isBefore(start) && !today.isAfter(end)) {
        due.add(booking);
      }
    }

    return due;
  }

  /// ดึงชุดข้อมูลของทุกรอบที่ใกล้ถึง — เรียกแบบ fire-and-forget ได้
  ///
  /// ทุกคำขอถูกกลืน error ทีละตัว: นี่เป็นงานเบื้องหลังที่ผู้ใช้ไม่ได้สั่ง
  /// ดึงไม่สำเร็จก็แค่ยังไม่มีของชุดนั้น ไม่ควรเด้ง error ใส่หน้าจอที่กำลังใช้อยู่
  static Future<void> prefetch(AppProvider app, {bool force = false}) async {
    if (!app.isLoggedIn) return;

    for (final booking in dueBookings(app.bookings)) {
      final scheduleId =
          int.tryParse('${(booking['schedule'] as Map)['id']}') ?? 0;
      if (scheduleId <= 0) continue;
      if (!force && !_isStale(scheduleId)) continue;

      await packOne(app, booking);
    }
  }

  /// ดึงชุดข้อมูลของรอบเดียว แล้วบันทึกเวลาที่ดึงสำเร็จ
  ///
  /// คืน true เมื่อได้ของอย่างน้อยหนึ่งชิ้น — ปุ่ม "บันทึกไว้ใช้ออฟไลน์" ใช้ค่านี้
  /// บอกผู้ใช้ตรง ๆ ว่าสำเร็จหรือไม่ แทนที่จะขึ้นว่าสำเร็จทั้งที่ไม่มีสัญญาณ
  static Future<bool> packOne(
    AppProvider app,
    Map<String, dynamic> booking,
  ) async {
    final schedule = booking['schedule'];
    if (schedule is! Map) return false;
    final scheduleId = int.tryParse('${schedule['id']}') ?? 0;
    final ref = booking['booking_ref']?.toString() ?? '';
    if (scheduleId <= 0) return false;

    var packed = 0;

    // กำหนดการ — แคชตัวเองอยู่แล้วเมื่อโหลดสำเร็จ
    try {
      await app.scheduleItinerary(scheduleId);
      packed++;
    } catch (e) {
      debugPrint('TripDayPack: itinerary $scheduleId failed — $e');
    }

    // ประกาศจากผู้จัด — เก็บเฉพาะตัวประกาศ ไม่เก็บ unread_count/can_moderate
    // ซึ่งเป็นสถานะ ณ ตอนนั้นและจะเพี้ยนทันทีที่เอามาแสดงย้อนหลัง
    try {
      final data = await app.scheduleAnnouncements(scheduleId);
      final announcements = (data['announcements'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      OfflineCache.instance.writeAccount(
        _announcementsKey(scheduleId),
        announcements,
      );
      packed++;
    } catch (e) {
      debugPrint('TripDayPack: announcements $scheduleId failed — $e');
    }

    // รายละเอียดการจอง — จุดขึ้นรถ เบอร์สตาฟ ที่นั่ง ทั้งหมดอยู่ในนี้
    if (ref.isNotEmpty) {
      try {
        final detail = await app.booking(ref);
        OfflineCache.instance.writeAccount('booking.$ref', detail);
        packed++;
      } catch (e) {
        debugPrint('TripDayPack: booking $ref failed — $e');
      }
    }

    if (packed == 0) return false;

    OfflineCache.instance.writeAccount(_metaKey(scheduleId), {
      'saved_at': DateTime.now().toIso8601String(),
      'booking_ref': ref,
      'parts': packed,
    });
    await OfflineCache.instance.flush();

    return true;
  }

  /// เวลาที่ชุดข้อมูลของรอบนี้ถูกบันทึกล่าสุด — null คือยังไม่เคยบันทึกสำเร็จ
  static DateTime? savedAt(int scheduleId) {
    final meta = OfflineCache.instance.readAccount<Map>(_metaKey(scheduleId));
    if (meta == null) return null;
    return DateTime.tryParse('${meta['saved_at']}')?.toLocal();
  }

  /// ประกาศของรอบนี้ที่บันทึกไว้ — คืนลิสต์ว่างเมื่อยังไม่เคยบันทึก
  static List<Map<String, dynamic>> cachedAnnouncements(int scheduleId) {
    final cached = OfflineCache.instance.readAccount<List>(
      _announcementsKey(scheduleId),
    );
    if (cached == null) return const [];
    return cached
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// รายละเอียดการจองที่บันทึกไว้ — ใช้เมื่อเปิดใบจองตอนไม่มีสัญญาณ
  static Map<String, dynamic>? cachedBooking(String ref) {
    final cached = OfflineCache.instance.readAccount<Map>('booking.$ref');
    if (cached == null) return null;
    return Map<String, dynamic>.from(cached);
  }

  static bool _isStale(int scheduleId) {
    final saved = savedAt(scheduleId);
    if (saved == null) return true;
    return DateTime.now().difference(saved) >= minRefreshInterval;
  }
}
