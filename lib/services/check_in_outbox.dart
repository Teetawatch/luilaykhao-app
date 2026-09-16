import 'dart:async';

import 'package:flutter/foundation.dart';

import '../providers/app_provider.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'offline_cache.dart';

/// เช็คอินที่สตาฟกดไปแล้วแต่ยังส่งไม่ออก — เก็บบนเครื่องแล้วส่งเองเมื่อสัญญาณมา
///
/// จุดรับหลายจุดของเราอยู่ในที่ที่สัญญาณไม่ถึง (ลานจอดใต้ทางด่วน ปั๊มริมทาง
/// ตีนดอย) ซึ่งเป็นที่เดียวกับที่ต้องเช็คอินคนขึ้นรถ ก่อนหน้านี้การกดตรงนั้น
/// ได้ SnackBar แดงหนึ่งอัน แล้วสตาฟก็ต้องจำเอาเองว่าใครขึ้นแล้วบ้าง — ความจำ
/// ที่ต้องแข่งกับการนับของ ยกกระเป๋า และคนถามทางพร้อมกัน
///
/// ตัวนี้รับไม้ต่อ โดยยึดรูปแบบเดียวกับ [SosOutbox]: เก็บลง [OfflineCache]
/// พร้อม "เวลาที่กดจริง" แล้วส่งใหม่ทุกครั้งที่สัญญาณกลับมาหรือเปิดแอปใหม่
/// เซิร์ฟเวอร์บันทึก `checked_in_at` ตามเวลาที่กด ไม่ใช่เวลาที่สัญญาณกลับมา
///
/// ข้อจำกัดที่ต้องบอกผู้ใช้ตรง ๆ เหมือน SOS: **คิวเดินเฉพาะตอนแอปทำงานอยู่**
class CheckInOutbox {
  CheckInOutbox._();
  static final CheckInOutbox instance = CheckInOutbox._();

  static const _key = 'checkin_outbox';

  /// เกินเท่านี้ทิ้ง — ตรงกับกรอบที่เซิร์ฟเวอร์ยอมรับ `checked_in_at` ย้อนหลัง
  /// เกินกว่านั้นส่งไปก็ถูกปัดเป็น now() ซึ่งไม่ใช่ความจริงอีกต่อไป
  static const Duration maxAge = Duration(hours: 24);

  /// เว้นระยะระหว่างรอบส่ง — กันสัญญาณติด ๆ ดับ ๆ ยิงรัวจนแบตหมดกลางทริป
  static const Duration minRetryInterval = Duration(seconds: 15);

  /// จำนวนรายการค้าง — หน้าจอฟังค่านี้เพื่อขึ้น/ปิดแถบ "ยังไม่ได้ส่ง"
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  AppProvider? _app;
  bool _flushing = false;
  DateTime? _lastAttempt;
  VoidCallback? _connectivityListener;

  void attach(AppProvider app) {
    _app = app;
    _refreshCount();

    if (_connectivityListener != null) return;

    _connectivityListener = () {
      if (ConnectivityService.instance.isOnline.value) {
        unawaited(flush());
      }
    };
    ConnectivityService.instance.isOnline.addListener(_connectivityListener!);
  }

  void detach() {
    if (_connectivityListener != null) {
      ConnectivityService.instance.isOnline.removeListener(
        _connectivityListener!,
      );
      _connectivityListener = null;
    }
    _app = null;
  }

  /// เก็บเช็คอินที่ส่งไม่ผ่านลงคิว — กดซ้ำใบเดิมไม่กลายเป็นสองรายการ
  Future<void> enqueue({
    required int scheduleId,
    required String bookingRef,
    required String qrCode,
    String? name,
    DateTime? occurredAt,
  }) async {
    final items = _read()..removeWhere((item) => item['booking_ref'] == bookingRef);

    items.add({
      'booking_ref': bookingRef,
      'qr_code': qrCode,
      'schedule_id': scheduleId,
      'name': name,
      'occurred_at': (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
    });

    OfflineCache.instance.writeAccount(_key, items);
    await OfflineCache.instance.flush();
    _refreshCount();
  }

  /// รายการที่ยังค้างอยู่ (ตัดของหมดอายุออกแล้ว)
  List<Map<String, dynamic>> pending() {
    final items = _read();
    final fresh = items.where(_isFresh).toList();

    if (fresh.length != items.length) {
      OfflineCache.instance.writeAccount(_key, fresh);
      unawaited(OfflineCache.instance.flush());
    }

    return fresh;
  }

  /// เลขที่จองของรอบนี้ที่ยังค้างส่งอยู่ — หน้ารายชื่อใช้ทำป้าย "รอส่ง"
  Set<String> pendingRefs(int scheduleId) => pending()
      .where((item) => item['schedule_id'] == scheduleId)
      .map((item) => '${item['booking_ref']}')
      .toSet();

  /// พยายามส่งทุกรายการที่ค้าง — คืนจำนวนที่ส่งสำเร็จในรอบนี้
  Future<int> flush({bool force = false}) async {
    final app = _app;
    if (app == null || !app.isLoggedIn || _flushing) return 0;

    final items = pending();
    if (items.isEmpty) {
      _refreshCount();
      return 0;
    }

    if (!force && _lastAttempt != null) {
      final since = DateTime.now().difference(_lastAttempt!);
      if (since < minRetryInterval) return 0;
    }

    _flushing = true;
    _lastAttempt = DateTime.now();
    var sent = 0;

    try {
      for (final item in List<Map<String, dynamic>>.from(items)) {
        final ref = '${item['booking_ref']}';
        final qr = '${item['qr_code']}';
        final scheduleId = item['schedule_id'] as int? ?? 0;
        if (qr.isEmpty || scheduleId <= 0) {
          _remove(ref);
          continue;
        }

        try {
          await app.confirmStaffCheckIn(
            qr,
            scheduleId: scheduleId,
            checkedInAt: DateTime.tryParse('${item['occurred_at']}'),
          );
          _remove(ref);
          sent++;
        } catch (e) {
          // เซิร์ฟเวอร์ปฏิเสธถาวร (ใบจองถูกยกเลิก, ไม่มีสิทธิ์, รหัสผิดรอบ) —
          // ลองอีกกี่ครั้งก็ได้คำตอบเดิม ปล่อยทิ้งดีกว่าค้างเป็นตัวเลขแดงทั้งทริป
          //
          // เช็คอินซ้ำไม่เข้าเคสนี้: คำขอที่มี checked_in_at ติดไปด้วยจะได้ 200
          // กลับมาพร้อมข้อความว่าเช็คอินไปแล้ว (ดู DriverController::checkIn)
          if (e is ApiException &&
              e.statusCode != null &&
              e.statusCode! >= 400 &&
              e.statusCode! < 500) {
            debugPrint('CheckInOutbox: dropping $ref — ${e.statusCode}');
            _remove(ref);
          } else {
            debugPrint('CheckInOutbox: $ref still stuck — $e');
          }
        }
      }
    } finally {
      _flushing = false;
      await OfflineCache.instance.flush();
      _refreshCount();
    }

    return sent;
  }

  /// ล้างคิวทั้งหมด — ใช้ตอนออกจากระบบ
  Future<void> clear() async {
    OfflineCache.instance.writeAccount(_key, null);
    await OfflineCache.instance.flush();
    _refreshCount();
  }

  void _remove(String bookingRef) {
    final items = _read()
      ..removeWhere((item) => item['booking_ref'] == bookingRef);
    OfflineCache.instance.writeAccount(_key, items);
  }

  List<Map<String, dynamic>> _read() {
    final raw = OfflineCache.instance.readAccount<List>(_key);
    if (raw == null) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  bool _isFresh(Map<String, dynamic> item) {
    final occurred = DateTime.tryParse('${item['occurred_at']}');
    if (occurred == null) return false;
    return DateTime.now().toUtc().difference(occurred.toUtc()) < maxAge;
  }

  void _refreshCount() => pendingCount.value = _read().where(_isFresh).length;

  @visibleForTesting
  void resetForTest() {
    _app = null;
    _flushing = false;
    _lastAttempt = null;
    pendingCount.value = 0;
  }
}
