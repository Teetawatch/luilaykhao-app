import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/tracking_model.dart';
import '../services/customer_location_service.dart';
import '../services/tracking_service.dart';

class TrackingProvider extends ChangeNotifier {
  final TrackingService _service = TrackingService();
  final CustomerLocationService _locationService = CustomerLocationService();

  BookingInfo? _booking;
  VehicleTracking? _vehicleTracking;
  ETAResult? _eta;
  TrackingPhase _phase = TrackingPhase.far;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isTracking = false;

  String? _cachedDriverName;
  String? _cachedDriverPhone;

  LatLng? _customerLocation;
  bool _locationPermissionDenied = false;
  String? _locationError;

  BookingInfo? get booking => _booking;
  VehicleTracking? get vehicleTracking => _vehicleTracking;
  ETAResult? get eta => _eta;
  TrackingPhase get phase => _phase;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isTracking => _isTracking;
  LatLng? get customerLocation => _customerLocation;
  bool get locationPermissionDenied => _locationPermissionDenied;
  String? get locationError => _locationError;

  Future<void> startTracking(String bookingRef) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    final booking = await _service.fetchBookingInfo(bookingRef);
    if (booking == null) {
      _isLoading = false;
      _errorMessage = 'ไม่พบข้อมูลการจอง กรุณาตรวจสอบรหัสอีกครั้ง';
      notifyListeners();
      return;
    }

    _booking = booking;
    _cachedDriverName = booking.driverName;
    _cachedDriverPhone = booking.driverPhone;

    final initial = await _service.fetchVehicleLocation(booking.vehicleId);
    _handleNewTracking(initial);

    _isLoading = false;
    _isTracking = true;
    notifyListeners();

    _locationService.startTracking(
      onLocation: (loc) {
        _customerLocation = loc;
        _recomputeETA();
        notifyListeners();
      },
      onError: (err) {
        _locationError = err;
        _locationPermissionDenied = true;
        notifyListeners();
      },
    );

    _service.startAdaptivePolling(
      vehicleId: booking.vehicleId,
      initialPhase: _phase,
      onData: (tracking) {
        _handleNewTracking(tracking);
        if (_booking != null && tracking != null && _eta != null) {
          _service.updatePhase(
            newPhase: _eta!.phase,
            vehicleId: booking.vehicleId,
            onData: (t) {
              _handleNewTracking(t);
              notifyListeners();
            },
            onPhaseChange: (p) {
              _phase = p;
              notifyListeners();
            },
          );
        }
        notifyListeners();
      },
      onPhaseChange: (p) {
        _phase = p;
        notifyListeners();
      },
    );
  }

  void _handleNewTracking(VehicleTracking? tracking) {
    if (tracking != null && _booking != null) {
      _vehicleTracking = VehicleTracking(
        vehicleId: tracking.vehicleId,
        licensePlate: tracking.licensePlate,
        driverName: tracking.driverName ?? _cachedDriverName,
        driverPhone: tracking.driverPhone ?? _cachedDriverPhone,
        driverLocation: tracking.driverLocation,
        destinationPoint:
            tracking.destinationPoint ?? _booking?.destinationPoint,
        tripTitle: tracking.tripTitle,
        heading: tracking.heading,
        speed: tracking.speed,
        updatedAt: tracking.updatedAt,
      );
    } else {
      _vehicleTracking = tracking;
    }
    _recomputeETA();
  }

  void _recomputeETA() {
    if (_vehicleTracking == null) return;
    final target = _customerLocation ?? _booking?.pickupPoint;
    if (target == null) return;
    if (target.latitude == 0.0 && target.longitude == 0.0) return;

    _eta = ETAResult.compute(
      from: _vehicleTracking!.driverLocation,
      to: target,
      speedKmh: _vehicleTracking!.speed,
    );
    _phase = _eta!.phase;
  }

  void stopTracking() {
    _service.stop();
    _locationService.stop();
    _isTracking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    _locationService.dispose();
    super.dispose();
  }
}
