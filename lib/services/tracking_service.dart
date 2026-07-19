import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/schedule_route.dart';
import '../models/tracking_model.dart';

class TrackingService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://luilaykhao.com/api/v1',
  );

  String? authToken;

  static const Duration _farInterval = Duration(minutes: 30);
  static const Duration _nearSoonInterval = Duration(seconds: 30);
  static const Duration _imminentInterval = Duration(seconds: 4);

  Timer? _pollTimer;
  TrackingPhase _currentPhase = TrackingPhase.far;

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

  Future<VehicleTracking?> fetchVehicleLocation(int vehicleId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tracking/current/$vehicleId'),
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
    required TrackingPhase initialPhase,
    required void Function(VehicleTracking?) onData,
    void Function(TrackingPhase)? onPhaseChange,
  }) {
    _currentPhase = initialPhase;
    _scheduleNextPoll(
      vehicleId: vehicleId,
      onData: onData,
      onPhaseChange: onPhaseChange,
    );
  }

  void updatePhase({
    required TrackingPhase newPhase,
    required int vehicleId,
    required void Function(VehicleTracking?) onData,
    void Function(TrackingPhase)? onPhaseChange,
  }) {
    if (newPhase == _currentPhase) return;
    debugPrint('[TrackingService] Phase changed: $_currentPhase -> $newPhase');
    _currentPhase = newPhase;
    _pollTimer?.cancel();
    onPhaseChange?.call(newPhase);
    _scheduleNextPoll(
      vehicleId: vehicleId,
      onData: onData,
      onPhaseChange: onPhaseChange,
    );
  }

  void _scheduleNextPoll({
    required int vehicleId,
    required void Function(VehicleTracking?) onData,
    void Function(TrackingPhase)? onPhaseChange,
  }) {
    _pollTimer?.cancel();
    final interval = _intervalForPhase(_currentPhase);
    debugPrint(
      '[TrackingService] Polling every ${interval.inSeconds}s (phase: $_currentPhase)',
    );

    _pollTimer = Timer.periodic(interval, (_) async {
      final tracking = await fetchVehicleLocation(vehicleId);
      _trackingController.add(tracking);
      onData(tracking);
    });
  }

  Duration _intervalForPhase(TrackingPhase phase) {
    return switch (phase) {
      TrackingPhase.far => _farInterval,
      TrackingPhase.nearSoon => _nearSoonInterval,
      TrackingPhase.imminent => _imminentInterval,
      TrackingPhase.arrived => _farInterval,
    };
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    stop();
    _trackingController.close();
  }
}
