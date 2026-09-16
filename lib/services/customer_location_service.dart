import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'location_stream_hub.dart';

/// หมุด "คุณอยู่ตรงนี้" บนแผนที่ติดตามรถ
///
/// เป็นผู้ใช้ GPS รายเดียวในแอปที่ไม่ต้องวิ่งต่อเบื้องหลัง — ปิดหน้าจอแล้วก็ไม่มี
/// แผนที่ให้ดูอยู่ดี แต่ยังต้องขอผ่าน [LocationStreamHub] เหมือนรายอื่น ไม่งั้น
/// สตรีมที่หน้าจอนี้เปิดค้างไว้จะกลายเป็นตัวกำหนดค่าให้การบันทึกเส้นทางกับการ
/// แชร์ตำแหน่งที่กดทีหลัง แล้วพากันตายตอนล็อกหน้าจอ
class CustomerLocationService {
  static const LocationNeed _need = LocationNeed(
    accuracy: LocationAccuracy.high,
    distanceFilterM: 10,
  );

  LocationLease? _lease;
  final StreamController<LatLng> _locationController =
      StreamController<LatLng>.broadcast();

  Stream<LatLng> get locationStream => _locationController.stream;

  Future<LatLng?> startTracking({
    required void Function(LatLng) onLocation,
    void Function(String)? onError,
  }) async {
    final permission = await _requestPermission();
    if (permission == null) {
      onError?.call(
        'ไม่ได้รับอนุญาตให้ใช้ GPS กรุณาเปิดสิทธิ์ตำแหน่งในการตั้งค่า',
      );
      return null;
    }

    LatLng? initial;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      initial = LatLng(pos.latitude, pos.longitude);
      onLocation(initial);
    } catch (e) {
      debugPrint('[CustomerLocationService] getCurrentPosition error: $e');
    }

    try {
      _lease = await LocationStreamHub.instance.attach(
        need: _need,
        onPosition: (pos) {
          final loc = LatLng(pos.latitude, pos.longitude);
          if (_locationController.isClosed) return;
          _locationController.add(loc);
          onLocation(loc);
        },
        onError: (e) {
          debugPrint('[CustomerLocationService] stream error: $e');
          onError?.call('เกิดข้อผิดพลาดในการรับตำแหน่ง');
        },
      );
    } catch (e) {
      debugPrint('[CustomerLocationService] could not attach: $e');
      onError?.call('เกิดข้อผิดพลาดในการรับตำแหน่ง');
    }

    return initial;
  }

  Future<LocationPermission?> _requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return permission;
  }

  void stop() {
    final lease = _lease;
    _lease = null;
    unawaited(lease?.cancel() ?? Future<void>.value());
  }

  void dispose() {
    stop();
    _locationController.close();
  }
}
