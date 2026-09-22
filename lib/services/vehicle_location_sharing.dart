import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'api_client.dart';
import 'location_stream_hub.dart';

/// มือถือของสตาฟที่นั่งไปกับรถ = GPS ของรถ
///
/// คนขับไม่ได้ใช้แอป ตำแหน่งรถที่ลูกค้าเห็นบนแผนที่ ETA จุดรับ และการ์ด
/// "วันเดินทาง" บนหน้าจอล็อก ทั้งหมดเดินด้วยพิกัดชุดนี้ชุดเดียว ถ้าไม่มีใครเปิด
/// ของทั้งสามอย่างจะไม่พังแบบมี error แต่จะเงียบไปเฉย ๆ ทั้งวัน
///
/// โครงเดียวกับ [TripLocationSharing] (แชร์ตำแหน่งให้เพื่อนร่วมทริป) ด้วยเหตุผล
/// เดียวกัน: การแชร์ที่หยุดเองตอนสตาฟกดย้อนกลับออกจากหน้าจอ ไม่ใช่การแชร์ —
/// สตาฟเก็บเครื่องลงกระเป๋าแล้วทำงานหน้างานต่อคือพฤติกรรมปกติ ไม่ใช่กรณีขอบ
///
/// ต่างกันที่จังหวะ: รถวิ่ง 80 กม./ชม. ขยับ 500 เมตรใน 25 วินาที หมุดที่ช้ากว่า
/// นั้นทำให้ ETA ที่ลูกค้าเห็นผิดพอจะพาให้เขาลงมายืนรอเร็วหรือช้าเกินไป
class VehicleLocationSharing extends ChangeNotifier {
  VehicleLocationSharing._();

  static final VehicleLocationSharing instance = VehicleLocationSharing._();

  /// ส่งพิกัดขึ้นเซิร์ฟเวอร์อย่างมากทุกกี่วินาที
  static const Duration uploadInterval = Duration(seconds: 12);

  /// ขยับน้อยกว่านี้ไม่ต้องส่ง (เมตร) — รถติดไฟแดงไม่ต้องยิงรัว
  static const int distanceFilterM = 25;

  static const LocationNeed _need = LocationNeed(
    accuracy: LocationAccuracy.high,
    distanceFilterM: distanceFilterM,
    keepAliveInBackground: true,
    notificationTitle: 'กำลังแชร์ตำแหน่งรถให้ลูกค้า',
    notificationText: 'ลูกค้าในรอบนี้เห็นว่ารถถึงไหนแล้ว',
  );

  ApiClient? _api;
  int? _scheduleId;
  String? _plate;
  LocationLease? _lease;
  DateTime? _lastUpload;
  bool _busy = false;

  LatLng? vanPosition;
  DateTime? lastSentAt;
  String? error;

  bool get busy => _busy;
  bool get isSharing => _lease != null;
  int? get scheduleId => _scheduleId;
  String? get plate => _plate;
  bool isSharingFor(int id) => _lease != null && _scheduleId == id;

  @visibleForTesting
  void debugClearUploadThrottle() => _lastUpload = null;

  /// เปิดแชร์ คืน true เมื่อเริ่มส่งแล้ว — ถ้าไม่สำเร็จดูเหตุผลที่ [error]
  Future<bool> start({
    required ApiClient api,
    required int scheduleId,
    String? plate,
  }) async {
    if (isSharingFor(scheduleId)) return true;
    if (_busy) return false;

    _busy = true;
    error = null;
    notifyListeners();

    try {
      // ย้ายรอบ: ปิดของเดิมก่อน ไม่งั้นพิกัดของรถคันนี้จะไปลงรอบที่แล้ว
      if (_lease != null) {
        await _teardown();
      }

      if (!await _ensurePermission()) {
        error = 'ต้องอนุญาตให้เข้าถึงตำแหน่งก่อน จึงจะแชร์ตำแหน่งรถได้';
        return false;
      }

      _api = api;
      _scheduleId = scheduleId;
      _plate = plate;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _remember(position);

      // ยิงครั้งแรกแบบรอผล เพื่อให้รู้เดี๋ยวนี้ว่าเซิร์ฟเวอร์รับไหม (เป็นรอบของ
      // เราหรือเปล่า อยู่ในช่วงวันเดินทางหรือยัง) — ยกเว้นเน็ตหลุด ซึ่งระหว่าง
      // ทางเป็นเรื่องปกติ กรณีนั้นเปิดไว้ก่อนแล้วให้รอบถัดไปส่งแทน
      try {
        await _send(position);
      } on ApiException catch (e) {
        if (!e.isNetworkError) rethrow;
      }

      _lease = await LocationStreamHub.instance.attach(
        need: _need,
        onPosition: _onPosition,
        onError: (Object e) =>
            debugPrint('[VehicleLocationSharing] stream error: $e'),
      );
      return true;
    } on ApiException catch (e) {
      error = e.message;
      _forgetSession();
      return false;
    } catch (e) {
      debugPrint('[VehicleLocationSharing] start failed: $e');
      error = 'เปิดแชร์ตำแหน่งรถไม่สำเร็จ';
      _forgetSession();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// ปิดแชร์ — หยุดส่งทันที
  ///
  /// ไม่ต้องบอกเซิร์ฟเวอร์: พิกัดรถเป็นประวัติการเดินทางของรถคันนั้น ไม่ใช่
  /// หมุดของคน การหยุดส่งคือการหยุดเอง ตัวที่อ่านพิกัดจะถือว่าหมดอายุตามเวลา
  Future<void> stop() async {
    if (_lease == null) return;

    await _teardown();
    error = null;
    notifyListeners();
  }

  /// เลิกแชร์โดยไม่แตะเซิร์ฟเวอร์ — ใช้ตอนออกจากระบบ
  Future<void> abandonLocally() => stop();

  void _onPosition(Position position) {
    _remember(position);
    notifyListeners();

    final last = _lastUpload;
    if (last != null && DateTime.now().difference(last) < uploadInterval) {
      return;
    }
    unawaited(_sendGuarded(position));
  }

  void _remember(Position position) {
    vanPosition = LatLng(position.latitude, position.longitude);
  }

  Future<void> _sendGuarded(Position position) async {
    try {
      await _send(position);
    } on ApiException catch (e) {
      // ระหว่างทางเน็ตหลุดเป็นเรื่องปกติ — เก็บเงียบแล้วรอรอบถัดไป
      if (e.isNetworkError) return;

      // 403 = ไม่ใช่รอบของเราแล้ว, 422 = นอกช่วงวันเดินทาง/รอบไม่มีรถ
      // ทั้งคู่ไม่มีทางหายเองในรอบหน้า ปล่อยสตรีมวิ่งต่อคือกินแบตทิ้งเปล่า ๆ
      if (e.statusCode == 403 || e.statusCode == 422) {
        error = e.message;
        await _teardown();
        notifyListeners();
        return;
      }

      debugPrint('[VehicleLocationSharing] upload rejected: ${e.message}');
    } catch (e) {
      debugPrint('[VehicleLocationSharing] upload failed: $e');
    }
  }

  Future<void> _send(Position position) async {
    final api = _api;
    final scheduleId = _scheduleId;
    if (api == null || scheduleId == null) return;

    _lastUpload = DateTime.now();

    await api.post(
      'staff/schedules/$scheduleId/vehicle-location',
      body: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        if (position.heading >= 0) 'heading': position.heading,
        // geolocator ให้ความเร็วเป็น m/s ส่วนฝั่งเซิร์ฟเวอร์คิด ETA เป็น กม./ชม.
        if (position.speed >= 0) 'speed': position.speed * 3.6,
      },
    );

    lastSentAt = DateTime.now();
    notifyListeners();
  }

  Future<void> _teardown() async {
    final lease = _lease;

    // เคลียร์สถานะก่อนรอ I/O เสมอ: ปุ่มต้องบอกความจริงทันทีที่สตาฟกดปิด
    _forgetSession();
    await lease?.cancel();
  }

  void _forgetSession() {
    _lease = null;
    _api = null;
    _scheduleId = null;
    _plate = null;
    _lastUpload = null;
    vanPosition = null;
    lastSentAt = null;
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
