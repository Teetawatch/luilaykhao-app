import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';

import '../models/schedule_route.dart';
import '../models/tracking_model.dart';
import '../theme/app_theme.dart';

/// มุมมองกล้อง: เห็นทั้งคู่ / ตามรถ / ตามฉัน / อิสระ (ผู้ใช้ลากแผนที่เอง)
enum FollowMode { both, vehicle, me, free }

/// แผนที่จอติดตามรถแบบ Google Maps — ใช้เฉพาะจอนี้เพราะเป็นจอเดียวที่ต้องการ
/// ชั้นรถติดและชื่อสถานที่ไทยครบๆ ตอนลูกค้ายืนรอรถอยู่ริมถนน
///
/// หมุดของ Google เป็น bitmap ไม่ใช่ widget จึงต้องวาดหมุดเองลง canvas
/// (วาดครั้งเดียวแล้ว cache) ส่วนตำแหน่งของผู้ใช้ใช้จุดสีน้ำเงินของ Google เอง
class GoogleVehicleMap extends StatefulWidget {
  final VehicleTracking? tracking;
  final BookingInfo? booking;
  final LatLng? customerLocation;
  final List<LatLng> routePoints;
  final ScheduleRouteData? scheduleRoute;
  final TrackingPhase phase;
  final FollowMode mode;
  final VoidCallback onUserGesture;

  const GoogleVehicleMap({
    super.key,
    required this.tracking,
    required this.booking,
    required this.customerLocation,
    required this.routePoints,
    required this.scheduleRoute,
    required this.phase,
    required this.mode,
    required this.onUserGesture,
  });

  @override
  State<GoogleVehicleMap> createState() => _GoogleVehicleMapState();
}

class _GoogleVehicleMapState extends State<GoogleVehicleMap> {
  gmaps.GoogleMapController? _controller;

  /// หมุดที่วาดไว้แล้ว — key เช่น 'pickup', 'stop-3', 'stop-done'
  final Map<String, gmaps.BitmapDescriptor> _pins = {};
  bool _pinsReady = false;

  /// จุดที่นิ้วแตะลงบนแผนที่ — ใช้จับว่า "ผู้ใช้ลากแผนที่เอง" จากนิ้วจริงๆ
  /// ไม่ใช่จาก onCameraMoveStarted เพราะ SDK ขยับกล้องเองเป็นระยะ
  /// (แค่รอเฉยๆ ก็ยิง event มาแล้ว) ซึ่งจะไปเตะโหมดตามรถให้หลุดเอง
  Offset? _touchStart;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pinsReady) _buildPins();
  }

  @override
  void didUpdateWidget(covariant GoogleVehicleMap old) {
    super.didUpdateWidget(old);
    if (widget.mode == FollowMode.free) return;

    // เลื่อนกล้องตามเมื่อโหมดเปลี่ยน หรือรถ/ผู้ใช้ขยับจริง (>~22 ม.)
    final modeChanged = widget.mode != old.mode;
    final vehicleMoved =
        _changed(widget.tracking?.driverLocation, old.tracking?.driverLocation);
    final userMoved = _changed(widget.customerLocation, old.customerLocation);
    if (modeChanged || vehicleMoved || userMoved) _recenter();

    // จุดจอดที่ "รับแล้ว" เปลี่ยนสถานะ → ต้องวาดหมุดใหม่
    if (_stopSignature(widget.scheduleRoute) !=
        _stopSignature(old.scheduleRoute)) {
      _buildPins();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _touchStart = event.position,
      onPointerMove: (event) {
        final start = _touchStart;
        // เผื่อสั่นมือ — ต้องลากเกิน 8 px ถึงนับว่าตั้งใจเลื่อนแผนที่เอง
        if (start != null && (event.position - start).distance > 8) {
          _touchStart = null;
          widget.onUserGesture();
        }
      },
      onPointerUp: (_) => _touchStart = null,
      onPointerCancel: (_) => _touchStart = null,
      child: gmaps.GoogleMap(
        initialCameraPosition: gmaps.CameraPosition(
          target: _toGoogle(_initialCenter()),
          zoom: 14.5,
        ),
        onMapCreated: (controller) {
          _controller = controller;
          // Android โยน error ถ้าสั่ง fit bounds ก่อนแผนที่วัดขนาดตัวเองเสร็จ
          Future<void>.delayed(const Duration(milliseconds: 350), _recenter);
        },
        // เว้นที่ให้แถบบนและแผ่นข้อมูลด้านล่าง หมุดจะได้ไม่ไปอยู่ใต้ UI
        padding: const EdgeInsets.only(top: 108, bottom: 300),
        myLocationEnabled: widget.customerLocation != null,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        trafficEnabled: true,
        polylines: _polylines(),
        markers: _markers(),
      ),
    );
  }

  // ── กล้อง ────────────────────────────────────────────────────────────────

  LatLng _initialCenter() {
    return _validPoint(widget.customerLocation) ??
        _validPoint(widget.tracking?.driverLocation) ??
        _validPoint(widget.booking?.pickupPoint) ??
        _validPoint(widget.booking?.destinationPoint) ??
        const LatLng(13.7563, 100.5018);
  }

  Future<void> _recenter() async {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final vehicle = _validPoint(widget.tracking?.driverLocation);
    final customer = _validPoint(widget.customerLocation);

    gmaps.CameraUpdate? update;
    switch (widget.mode) {
      case FollowMode.free:
        return;
      case FollowMode.vehicle:
        if (vehicle != null) {
          update = gmaps.CameraUpdate.newLatLngZoom(_toGoogle(vehicle), 15.5);
        }
      case FollowMode.me:
        if (customer != null) {
          update = gmaps.CameraUpdate.newLatLngZoom(_toGoogle(customer), 15.5);
        }
      case FollowMode.both:
        final points = <LatLng>[
          ?vehicle,
          ?customer,
          ?_validPoint(widget.booking?.pickupPoint),
        ];
        if (points.length == 1) {
          update = gmaps.CameraUpdate.newLatLngZoom(_toGoogle(points.first), 15.5);
        } else if (points.length > 1) {
          update = gmaps.CameraUpdate.newLatLngBounds(_boundsOf(points), 56);
        }
    }
    if (update == null) return;

    await controller.animateCamera(update);
  }

  gmaps.LatLngBounds _boundsOf(List<LatLng> points) {
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    // กันกรอบแบนสนิท (จุดซ้อนกันพอดี) ที่ทำให้ Google ซูมสุดขอบ
    const pad = 0.0008;
    return gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat - pad, minLng - pad),
      northeast: gmaps.LatLng(maxLat + pad, maxLng + pad),
    );
  }

  // ── เส้นทาง ──────────────────────────────────────────────────────────────

  Set<gmaps.Polyline> _polylines() {
    final lines = <gmaps.Polyline>{};

    // เส้นพื้นหลัง: เส้นทางเดินรถทั้งรอบ ให้เห็นว่ารถวิ่งเส้นไหน
    final full = widget.scheduleRoute;
    if (full != null) {
      final fullLine =
          full.polyline.length >= 2 ? full.polyline : full.stopPoints;
      if (fullLine.length >= 2) {
        lines.add(
          gmaps.Polyline(
            polylineId: const gmaps.PolylineId('schedule-route'),
            points: fullLine.map(_toGoogle).toList(),
            width: 5,
            color: const Color(0xFF94A3B8).withValues(alpha: 0.65),
          ),
        );
      }
    }

    // เส้นหลัก: เส้นทางตามถนนจริงจากรถถึงจุดของลูกค้า
    if (widget.routePoints.length >= 2) {
      lines.add(
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('road-route'),
          points: widget.routePoints.map(_toGoogle).toList(),
          width: 7,
          color: AppTheme.primaryColor.withValues(alpha: 0.9),
          zIndex: 2,
        ),
      );
      return lines;
    }

    // Fallback: เส้นตรงเมื่อยังไม่มีเส้นทางถนน (ยังไม่ได้ตั้งคีย์ฝั่ง backend)
    final vehicle = _validPoint(widget.tracking?.driverLocation);
    final pickup = _validPoint(widget.booking?.pickupPoint);
    final destination =
        widget.tracking?.destinationPoint ?? widget.booking?.destinationPoint;
    final straight = <LatLng>[
      ?vehicle,
      ?pickup,
      if (destination != null && !_samePoint(destination, pickup)) destination,
    ];
    if (straight.length >= 2) {
      lines.add(
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('straight-route'),
          points: straight.map(_toGoogle).toList(),
          width: 6,
          color: AppTheme.primaryColor.withValues(alpha: 0.5),
          zIndex: 1,
        ),
      );
    }
    return lines;
  }

  // ── หมุด ────────────────────────────────────────────────────────────────

  Set<gmaps.Marker> _markers() {
    if (!_pinsReady) return const {};

    final markers = <gmaps.Marker>{};
    final pickup = _validPoint(widget.booking?.pickupPoint);
    final destination = widget.tracking?.destinationPoint ??
        widget.booking?.destinationPoint ??
        widget.scheduleRoute?.stops
            .where((s) => s.isDestination)
            .firstOrNull
            ?.point;

    // จุดจอดอื่นๆ ตามเส้นทาง — รับแล้วเป็นติ๊กเขียว ยังไม่ถึงเป็นเลขลำดับ
    var number = 0;
    for (final stop in widget.scheduleRoute?.stops ?? const <RouteStop>[]) {
      if (stop.isDestination) continue;
      number++;
      final point = stop.point;
      if (point == null || _samePoint(point, pickup)) continue;
      final pin = _pins[stop.completed ? 'stop-done' : 'stop-$number'];
      if (pin == null) continue;
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('stop-${stop.id ?? number}'),
          position: _toGoogle(point),
          icon: pin,
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: true,
          infoWindow: gmaps.InfoWindow(title: stop.name),
        ),
      );
    }

    if (destination != null && !_samePoint(destination, pickup)) {
      final pin = _pins['destination'];
      if (pin != null) {
        markers.add(
          gmaps.Marker(
            markerId: const gmaps.MarkerId('destination'),
            position: _toGoogle(destination),
            icon: pin,
            anchor: _labelledAnchor,
          ),
        );
      }
    }

    if (pickup != null) {
      final pin = _pins['pickup'];
      if (pin != null) {
        markers.add(
          gmaps.Marker(
            markerId: const gmaps.MarkerId('pickup'),
            position: _toGoogle(pickup),
            icon: pin,
            anchor: _labelledAnchor,
          ),
        );
      }
    }

    final vehicle = _validPoint(widget.tracking?.driverLocation);
    final vehiclePin = _pins[
        widget.phase == TrackingPhase.imminent ? 'vehicle-near' : 'vehicle'];
    if (vehicle != null && vehiclePin != null) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('vehicle'),
          position: _toGoogle(vehicle),
          icon: vehiclePin,
          anchor: const Offset(0.5, 0.5),
          rotation: widget.tracking?.heading ?? 0,
          flat: true,
          zIndexInt: 3,
        ),
      );
    }
    return markers;
  }

  /// หมุดที่มีป้ายชื่อใต้วงกลม — จุดอ้างอิงคือกึ่งกลางวงกลม ไม่ใช่ก้นภาพ
  static const Offset _labelledAnchor = Offset(0.5, 18 / 62);

  Future<void> _buildPins() async {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final pins = <String, gmaps.BitmapDescriptor>{
      'pickup': await _pinBitmap(
        dpr: dpr,
        color: AppTheme.primaryColor,
        icon: Icons.location_on_rounded,
        label: 'จุดรับ',
      ),
      'destination': await _pinBitmap(
        dpr: dpr,
        color: const Color(0xFF111111),
        icon: Icons.flag_rounded,
        label: 'ปลายทาง',
      ),
      'vehicle': await _vehicleBitmap(dpr: dpr, glowAlpha: 0.10),
      'vehicle-near': await _vehicleBitmap(dpr: dpr, glowAlpha: 0.24),
      'stop-done': await _dotBitmap(
        dpr: dpr,
        color: const Color(0xFF10B981),
        icon: Icons.check_rounded,
      ),
    };
    // เลขลำดับจุดจอด — รอบหนึ่งมีจุดรับไม่เยอะ วาดเผื่อไว้ 12 จุด
    for (var i = 1; i <= 12; i++) {
      pins['stop-$i'] = await _dotBitmap(
        dpr: dpr,
        color: const Color(0xFF475569),
        text: '$i',
      );
    }

    if (!mounted) return;
    setState(() {
      _pins
        ..clear()
        ..addAll(pins);
      _pinsReady = true;
    });
  }

  /// จุดจอดเล็กๆ: วงกลม 24 + ขอบขาว + เลขหรือไอคอนตรงกลาง
  Future<gmaps.BitmapDescriptor> _dotBitmap({
    required double dpr,
    required Color color,
    IconData? icon,
    String? text,
  }) {
    return _record(dpr: dpr, size: const Size(28, 28), paint: (canvas) {
      const centre = Offset(14, 14);
      canvas.drawCircle(centre, 12, Paint()..color = Colors.white);
      canvas.drawCircle(centre, 9.5, Paint()..color = color);
      if (icon != null) {
        _drawIcon(canvas, icon, centre, 13, Colors.white);
      } else if (text != null) {
        _drawText(canvas, text, centre, 10.5, FontWeight.w900, Colors.white);
      }
    });
  }

  /// หมุดจุดรับ/ปลายทาง: วงกลม 36 + ไอคอน แล้วมีป้ายชื่อขาวใต้หมุด
  Future<gmaps.BitmapDescriptor> _pinBitmap({
    required double dpr,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    final labelPainter = _textPainter(
      label,
      11,
      FontWeight.w800,
      AppTheme.textMain,
    );
    final labelWidth = labelPainter.width + 16;
    final width = labelWidth > 36 ? labelWidth : 36.0;

    return _record(dpr: dpr, size: Size(width, 62), paint: (canvas) {
      final centre = Offset(width / 2, 18);
      canvas.drawCircle(centre, 18, Paint()..color = Colors.white);
      canvas.drawCircle(centre, 15, Paint()..color = color);
      _drawIcon(canvas, icon, centre, 18, Colors.white);

      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH((width - labelWidth) / 2, 40, labelWidth, 20),
        const Radius.circular(999),
      );
      canvas.drawRRect(pill, Paint()..color = Colors.white);
      labelPainter.paint(
        canvas,
        Offset((width - labelPainter.width) / 2, 45),
      );
    });
  }

  /// หมุดรถ: วงเรืองแสงรอบนอก + วงกลมสีแบรนด์ + ลูกศรบอกทิศ (หมุนตาม heading)
  Future<gmaps.BitmapDescriptor> _vehicleBitmap({
    required double dpr,
    required double glowAlpha,
  }) {
    return _record(dpr: dpr, size: const Size(64, 64), paint: (canvas) {
      const centre = Offset(32, 32);
      canvas.drawCircle(
        centre,
        30,
        Paint()..color = AppTheme.primaryColor.withValues(alpha: glowAlpha),
      );
      canvas.drawCircle(centre, 24, Paint()..color = Colors.white);
      canvas.drawCircle(centre, 20, Paint()..color = AppTheme.primaryColor);
      _drawIcon(canvas, Icons.navigation_rounded, centre, 22, Colors.white);
    });
  }

  Future<gmaps.BitmapDescriptor> _record({
    required double dpr,
    required Size size,
    required void Function(Canvas canvas) paint,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    paint(canvas);
    final image = await recorder.endRecording().toImage(
          (size.width * dpr).ceil(),
          (size.height * dpr).ceil(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    return gmaps.BitmapDescriptor.bytes(
      data!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }

  void _drawIcon(
    Canvas canvas,
    IconData icon,
    Offset centre,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset centre,
    double size,
    FontWeight weight,
    Color color,
  ) {
    final painter = _textPainter(text, size, weight, color);
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  TextPainter _textPainter(
    String text,
    double size,
    FontWeight weight,
    Color color,
  ) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: appFont(fontSize: size, fontWeight: weight, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  // ── ตัวช่วยเล็กๆ ─────────────────────────────────────────────────────────

  gmaps.LatLng _toGoogle(LatLng point) =>
      gmaps.LatLng(point.latitude, point.longitude);

  String _stopSignature(ScheduleRouteData? route) => (route?.stops ?? [])
      .map((s) => '${s.id}:${s.completed}')
      .join(',');

  bool _changed(LatLng? a, LatLng? b) {
    if (a == null && b == null) return false;
    if (a == null || b == null) return true;
    return (a.latitude - b.latitude).abs() > 0.0002 ||
        (a.longitude - b.longitude).abs() > 0.0002;
  }

  LatLng? _validPoint(LatLng? point) {
    if (point == null) return null;
    if (point.latitude == 0 && point.longitude == 0) return null;
    return mapSafePoint(point.latitude, point.longitude);
  }

  bool _samePoint(LatLng? a, LatLng? b) {
    if (a == null || b == null) return false;
    return (a.latitude - b.latitude).abs() < 0.00001 &&
        (a.longitude - b.longitude).abs() < 0.00001;
  }
}
