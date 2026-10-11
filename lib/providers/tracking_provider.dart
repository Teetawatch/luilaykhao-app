import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/schedule_route.dart';
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

  // เส้นทางเดินรถทั้งรอบ (จุดรับทุกจุด → ปลายทาง) — เส้นพื้นหลัง + หมุดจุดจอด
  ScheduleRouteData? _scheduleRoute;

  // เส้นทางตามถนนจริง (รถ → จุดของลูกค้า) สำหรับวาดเส้นบนแผนที่แบบ Grab
  List<LatLng> _routePoints = const [];
  LatLng? _lastRouteFrom;
  LatLng? _lastRouteTo;
  DateTime? _lastRouteAt;
  bool _routeFetching = false;

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
  List<LatLng> get routePoints => _routePoints;

  /// พิกัดรถเงียบนานกว่านี้ถือว่าไม่สด — จอต้องบอกอายุแทนการพูดว่ารถกำลังมา
  static const Duration staleAfter = Duration(minutes: 5);

  /// เปิดติดตามแล้วแต่รอบนี้ยังไม่มีพิกัดรถเลย — สตาฟยังไม่เริ่มแชร์ตำแหน่ง
  bool get waitingForSignal =>
      _isTracking && !_isLoading && _vehicleTracking == null;

  /// พิกัดล่าสุดเก่าแค่ไหน — null เมื่อยังไม่เคยได้พิกัด
  Duration? get signalAge {
    final tracking = _vehicleTracking;
    if (tracking == null) return null;
    final age = DateTime.now().difference(tracking.updatedAt);
    return age.isNegative ? Duration.zero : age;
  }

  bool get signalStale => (signalAge ?? Duration.zero) > staleAfter;
  ScheduleRouteData? get scheduleRoute => _scheduleRoute;

  /// เริ่มติดตามสำหรับ guest ที่ผ่านการ verify แล้ว — ข้าม fetchBookingInfo เพราะมีข้อมูลครบแล้ว
  Future<void> startTrackingAsGuest(BookingInfo bookingInfo) async {
    _service.stop();
    _locationService.stop();
    _isLoading = true;
    _errorMessage = '';
    _vehicleTracking = null;
    _eta = null;
    _customerLocation = null;
    _locationPermissionDenied = false;
    _locationError = null;
    _resetRoute();
    _phase = TrackingPhase.far;
    _service.authToken = null;
    notifyListeners();

    if (bookingInfo.vehicleId == 0) {
      _isLoading = false;
      _errorMessage = 'ยังไม่ได้กำหนดรถสำหรับทริปนี้';
      notifyListeners();
      return;
    }

    _booking = bookingInfo;
    _cachedDriverName = bookingInfo.driverName;
    _cachedDriverPhone = bookingInfo.driverPhone;
    _loadScheduleRoute(bookingInfo.scheduleId);

    final initial = await _service.fetchVehicleLocation(
      bookingInfo.vehicleId,
      scheduleId: bookingInfo.scheduleId,
    );
    _handleNewTracking(initial);

    _isLoading = false;
    _isTracking = true;
    notifyListeners();

    _beginCustomerLocation();
    _startPolling(bookingInfo);
  }

  Future<void> startTracking(String bookingRef, {String? authToken}) async {
    _service.stop();
    _locationService.stop();
    _isLoading = true;
    _errorMessage = '';
    _vehicleTracking = null;
    _eta = null;
    _customerLocation = null;
    _locationPermissionDenied = false;
    _locationError = null;
    _resetRoute();
    _phase = TrackingPhase.far;
    _service.authToken = authToken;
    notifyListeners();

    final booking = await _service.fetchBookingInfo(bookingRef);
    if (booking == null) {
      _isLoading = false;
      _errorMessage = 'ไม่พบข้อมูลการจอง กรุณาตรวจสอบรหัสอีกครั้ง';
      notifyListeners();
      return;
    }

    if (booking.vehicleId == 0) {
      _isLoading = false;
      _errorMessage = 'ยังไม่ได้กำหนดรถสำหรับทริปนี้';
      notifyListeners();
      return;
    }

    _booking = booking;
    _cachedDriverName = booking.driverName;
    _cachedDriverPhone = booking.driverPhone;
    _loadScheduleRoute(booking.scheduleId);

    final initial = await _service.fetchVehicleLocation(
      booking.vehicleId,
      scheduleId: booking.scheduleId,
    );
    _handleNewTracking(initial);

    _isLoading = false;
    _isTracking = true;
    notifyListeners();

    _beginCustomerLocation();
    _startPolling(booking);
  }

  void _startPolling(BookingInfo booking) {
    _service.startAdaptivePolling(
      vehicleId: booking.vehicleId,
      scheduleId: booking.scheduleId,
      initialPhase: _phase,
      hasSignal: _vehicleTracking != null,
      onData: (tracking) {
        _handleNewTracking(tracking);
        if (tracking != null && _eta != null) {
          _service.updatePhase(
            newPhase: _eta!.phase,
            onPhaseChange: (p) => _phase = p,
          );
        }
        notifyListeners();
      },
    );
  }

  /// เริ่มสตรีมตำแหน่งลูกค้า (GPS) — ใช้ร่วมกันทั้งตอนเริ่มติดตามและตอนกดลองใหม่
  void _beginCustomerLocation() {
    _locationService.startTracking(
      onLocation: (loc) {
        _customerLocation = loc;
        _locationPermissionDenied = false;
        _locationError = null;
        _recomputeETA();
        _maybeRefreshRoute();
        notifyListeners();
      },
      onError: (err) {
        _locationError = err;
        _locationPermissionDenied = true;
        notifyListeners();
      },
    );
  }

  /// ลองขอสิทธิ์/เริ่มจับตำแหน่งลูกค้าใหม่ (หลังผู้ใช้เปิดสิทธิ์ในตั้งค่า)
  Future<void> retryCustomerLocation() async {
    _locationService.stop();
    _locationPermissionDenied = false;
    _locationError = null;
    notifyListeners();
    _beginCustomerLocation();
  }

  void _handleNewTracking(VehicleTracking? tracking) {
    // เคยเห็นรถแล้วแต่รอบนี้ถามไม่ได้ (เน็ตสะดุด) — คงหมุดเดิมไว้ให้จอบอกอายุของมัน
    // ([signalStale]) ดีกว่าหมุดหายแล้วจอกลับไปพูดว่ารถยังไม่เริ่มส่งตำแหน่ง
    // เซิร์ฟเวอร์ตอบเฉพาะพิกัดของรอบนี้ หมุดที่คงไว้จึงไม่ใช่ของทริปอื่นแน่นอน
    if (tracking == null && _vehicleTracking != null) return;

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
    _maybeRefreshRoute();
  }

  /// ดึงเส้นทางตามถนนจริง (throttle: รีเฟรชเมื่อรถ/ลูกค้าขยับ >120m หรือทุก ~25 วิ)
  Future<void> _maybeRefreshRoute() async {
    final from = _vehicleTracking?.driverLocation;
    final to = _customerLocation ?? _booking?.pickupPoint;
    if (from == null || to == null) return;
    if (to.latitude == 0 && to.longitude == 0) return;
    if (_routeFetching) return;

    const distance = Distance();
    final movedFar = _lastRouteFrom == null ||
        distance.as(LengthUnit.Meter, _lastRouteFrom!, from) > 120 ||
        (_lastRouteTo != null &&
            distance.as(LengthUnit.Meter, _lastRouteTo!, to) > 120);
    final stale = _lastRouteAt == null ||
        DateTime.now().difference(_lastRouteAt!) > const Duration(seconds: 25);
    if (_routePoints.isNotEmpty && !movedFar && !stale) return;

    _routeFetching = true;
    _lastRouteAt = DateTime.now();
    _lastRouteFrom = from;
    _lastRouteTo = to;
    try {
      final pts = await _service.fetchRoute(from, to);
      if (pts.isNotEmpty) {
        _routePoints = pts;
        notifyListeners();
      }
    } finally {
      _routeFetching = false;
    }
  }

  void _resetRoute() {
    _routePoints = const [];
    _lastRouteFrom = null;
    _lastRouteTo = null;
    _lastRouteAt = null;
    _scheduleRoute = null;
  }

  /// ดึงเส้นทางเดินรถทั้งรอบครั้งเดียวตอนเริ่มติดตาม (backend cache ให้แล้ว)
  Future<void> _loadScheduleRoute(int scheduleId) async {
    final data = await _service.fetchScheduleRoute(scheduleId);
    if (data == null || data.isEmpty) return;
    _scheduleRoute = data;
    notifyListeners();
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
