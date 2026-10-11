import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/api_config.dart';
import '../models/schedule_route.dart';
import '../models/tracking_model.dart';

class TrackingService {
  /// ที่อยู่ API มีแหล่งเดียวคือ [ApiConfig] — ก่อนหน้านี้ไฟล์นี้อ่าน
  /// `API_BASE_URL` เองซ้ำอีกที่ ซึ่งแปลว่าถ้าค่าที่ส่งเข้ามาเพี้ยน ตรงนี้ก็
  /// เพี้ยนตามโดยไม่ผ่านการกรองของ ApiConfig
  static String get baseUrl => ApiConfig.baseUrl;

  String? authToken;

  /// รถยังอยู่ไกล (ETA เกิน 30 นาที) — เดิม 30 นาที ซึ่งนานจนหมุดบนจอที่เปิด
  /// ค้างไว้กลายเป็นตำแหน่งเก่าไปหลายกิโล รถวิ่งกิโลกว่าต่อนาที
  static const Duration _farInterval = Duration(minutes: 2);
  static const Duration _nearSoonInterval = Duration(seconds: 30);
  static const Duration _imminentInterval = Duration(seconds: 4);

  /// ยังไม่มีพิกัดของรอบนี้เลย (สตาฟยังไม่เริ่มแชร์) — ถามถี่พอให้รถโผล่บนจอ
  /// ภายในนาทีเดียวหลังสตาฟเปิดแอป ไม่ใช่รอรอบ "ไกล" ถัดไป
  static const Duration _noSignalInterval = Duration(minutes: 1);

  /// รถถึงจุดรับแล้ว — ลูกค้ากำลังขึ้นรถ ไม่ต้องถามถี่
  static const Duration _arrivedInterval = Duration(minutes: 5);

  Timer? _pollTimer;
  TrackingPhase _currentPhase = TrackingPhase.far;
  bool _hasSignal = false;

  /// เปลี่ยนทุกครั้งที่เริ่ม/หยุด — คำตอบของรอบที่ถูกหยุดไปแล้วจะไม่ไปตั้งเวลาต่อ
  int _generation = 0;

  final StreamController<VehicleTracking?> _trackingController =
      StreamController<VehicleTracking?>.broadcast();

  Stream<VehicleTracking?> get trackingStream => _trackingController.stream;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (authToken != null && authToken!.isNotEmpty)
      'Authorization': 'Bearer $authToken',
  };

  Future<BookingInfo?> fetchBookingInfo(String bookingRef) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/bookings/${Uri.encodeComponent(bookingRef)}/tracking',
        ),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true) {
          return BookingInfo.fromJson(
            Map<String, dynamic>.from(body['data'] as Map),
          );
        }
      }
    } catch (e) {
      debugPrint('[TrackingService] fetchBookingInfo error: $e');
    }
    return null;
  }

  /// พิกัดล่าสุดของรถ *ของรอบนี้* — null เมื่อรอบนี้ยังไม่มีใครส่งพิกัด
  ///
  /// [scheduleId] ทำให้เซิร์ฟเวอร์ไม่หยิบจุดสุดท้ายของทริปก่อนหน้า (รถคันเดียวกัน)
  /// มาตอบเป็นตำแหน่งสด
  Future<VehicleTracking?> fetchVehicleLocation(
    int vehicleId, {
    int? scheduleId,
  }) async {
    try {
      final query = (scheduleId != null && scheduleId > 0)
          ? '?schedule_id=$scheduleId'
          : '';
      final response = await http.get(
        Uri.parse('$baseUrl/tracking/current/$vehicleId$query'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true) {
          return VehicleTracking.fromJson(
            Map<String, dynamic>.from(body['data'] as Map),
          );
        }
      }
    } catch (e) {
      debugPrint('[TrackingService] fetchVehicleLocation error: $e');
    }
    return null;
  }

  /// เส้นทางขับรถตามถนนจริงจากรถไปยังจุดของลูกค้า (วาดเส้นแบบ Grab)
  /// คืน list ว่างเมื่อ backend ไม่มีคีย์/หาเส้นทางไม่ได้ → ผู้เรียก fallback เส้นตรง
  Future<List<LatLng>> fetchRoute(LatLng from, LatLng to) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/tracking/route?from_lat=${from.latitude}&from_lng=${from.longitude}'
          '&to_lat=${to.latitude}&to_lng=${to.longitude}',
        ),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final points = body['data']?['polyline'];
        if (points is String && points.isNotEmpty) {
          return decodeGooglePolyline(points);
        }
      }
    } catch (e) {
      debugPrint('[TrackingService] fetchRoute error: $e');
    }
    return const [];
  }

  /// เส้นทางเดินรถทั้งรอบ (จุดรับทุกจุด → ปลายทาง) สำหรับวาดเส้นเต็ม
  /// + หมุดจุดจอดบนแผนที่ติดตามรถ; คืน null เมื่อดึงไม่ได้
  Future<ScheduleRouteData?> fetchScheduleRoute(int scheduleId) async {
    if (scheduleId <= 0) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/schedules/$scheduleId/route'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] is Map) {
          return ScheduleRouteData.fromJson(
            Map<String, dynamic>.from(body['data'] as Map),
          );
        }
      }
    } catch (e) {
      debugPrint('[TrackingService] fetchScheduleRoute error: $e');
    }
    return null;
  }

  void startAdaptivePolling({
    required int vehicleId,
    int? scheduleId,
    required TrackingPhase initialPhase,
    required bool hasSignal,
    required void Function(VehicleTracking?) onData,
  }) {
    _generation++;
    _currentPhase = initialPhase;
    _hasSignal = hasSignal;
    _vehicleId = vehicleId;
    _scheduleId = scheduleId;
    _onData = onData;
    _scheduleNextPoll();
  }

  int? _vehicleId;
  int? _scheduleId;
  void Function(VehicleTracking?)? _onData;

  /// ETA เปลี่ยนช่วง — ตั้งเวลาครั้งถัดไปใหม่ตามช่วงใหม่ทันที
  void updatePhase({
    required TrackingPhase newPhase,
    void Function(TrackingPhase)? onPhaseChange,
  }) {
    if (newPhase == _currentPhase) return;
    debugPrint('[TrackingService] Phase changed: $_currentPhase -> $newPhase');
    _currentPhase = newPhase;
    onPhaseChange?.call(newPhase);
    _scheduleNextPoll();
  }

  /// ตั้งเวลาทีละครั้ง (ไม่ใช่ periodic) เพื่อให้ช่วงถัดไปขึ้นกับคำตอบล่าสุดเสมอ —
  /// ไม่มีสัญญาณ → ถามทุกนาที, มีแล้ว → ตามระยะห่างของรถ
  void _scheduleNextPoll() {
    final vehicleId = _vehicleId;
    if (vehicleId == null) return;

    _pollTimer?.cancel();
    final generation = _generation;
    final interval = _hasSignal
        ? _intervalForPhase(_currentPhase)
        : _noSignalInterval;
    debugPrint(
      '[TrackingService] Next poll in ${interval.inSeconds}s '
      '(phase: $_currentPhase, signal: $_hasSignal)',
    );

    _pollTimer = Timer(interval, () async {
      final tracking = await fetchVehicleLocation(
        vehicleId,
        scheduleId: _scheduleId,
      );
      if (generation != _generation) return;

      _hasSignal = tracking != null;
      _trackingController.add(tracking);
      _onData?.call(tracking);
      // onData อาจเรียก updatePhase ซึ่งตั้งเวลาให้แล้ว — ตั้งซ้ำได้เพราะ
      // _scheduleNextPoll ยกเลิกตัวเก่าก่อนเสมอ
      if (generation == _generation) _scheduleNextPoll();
    });
  }

  Duration _intervalForPhase(TrackingPhase phase) {
    return switch (phase) {
      TrackingPhase.far => _farInterval,
      TrackingPhase.nearSoon => _nearSoonInterval,
      TrackingPhase.imminent => _imminentInterval,
      TrackingPhase.arrived => _arrivedInterval,
    };
  }

  void stop() {
    _generation++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _vehicleId = null;
    _scheduleId = null;
    _onData = null;
  }

  void dispose() {
    stop();
    _trackingController.close();
  }
}
