import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class CustomerLocationService {
  StreamSubscription<Position>? _positionSub;
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

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (pos) {
            final loc = LatLng(pos.latitude, pos.longitude);
            _locationController.add(loc);
            onLocation(loc);
          },
          onError: (e) {
            debugPrint('[CustomerLocationService] stream error: $e');
            onError?.call('เกิดข้อผิดพลาดในการรับตำแหน่ง');
          },
        );

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
    _positionSub?.cancel();
    _positionSub = null;
  }

  void dispose() {
    stop();
    _locationController.close();
  }
}
