import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/schedule_route.dart';
import '../models/tracking_model.dart';
import '../providers/tracking_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/route_map_card.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class TrackingMapPage extends StatelessWidget {
  const TrackingMapPage({super.key});

  @override
  Widget build(BuildContext context) => const TrackingScreen();
}

/// มุมมองกล้อง: เห็นทั้งคู่ / ตามรถ / ตามฉัน / อิสระ (ผู้ใช้ลากแผนที่เอง)
enum FollowMode { both, vehicle, me, free }

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // เปิดหน้ามาให้กล้องเริ่มที่ "ตำแหน่งของฉัน" ก่อน แล้วผู้ใช้กด "ดูทั้งคู่"/"ดูรถ" ได้
  FollowMode _mode = FollowMode.me;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1, end: 1.28).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // กลับเข้าแอปหลังไปเปิดสิทธิ์ตำแหน่งในตั้งค่า → ลองจับตำแหน่งใหม่อัตโนมัติ
    if (state == AppLifecycleState.resumed && mounted) {
      final provider = context.read<TrackingProvider>();
      if (provider.locationPermissionDenied) {
        provider.retryCustomerLocation();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _callDriver(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _chatDriver(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'sms', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _shareTracking(BookingInfo? booking) async {
    final url = booking?.shareUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ยังไม่มีลิงก์ติดตามสำหรับการจองนี้',
            style: appFont(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    final trip = booking?.tripTitle ?? 'ทริปของเรา';
    await SharePlus.instance.share(
      ShareParams(
        text: 'ติดตามตำแหน่งรถ "$trip" แบบเรียลไทม์ได้ที่นี่เลย\n$url',
        subject: 'ติดตามรถ - ลุยเลเขา',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(
      builder: (context, provider, _) {
        final tracking = provider.vehicleTracking;
        final booking = provider.booking;
        final eta = provider.eta;
        final phone = tracking?.driverPhone ?? booking?.driverPhone;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: AppTheme.background(context),
            body: Stack(
              children: [
                VehicleMapWidget(
                  tracking: tracking,
                  booking: booking,
                  customerLocation: provider.customerLocation,
                  routePoints: provider.routePoints,
                  scheduleRoute: provider.scheduleRoute,
                  phase: provider.phase,
                  pulse: _pulseAnimation,
                  mode: _mode,
                  onUserGesture: () {
                    if (_mode != FollowMode.free) {
                      setState(() => _mode = FollowMode.free);
                    }
                  },
                ),
                TrackingTopBar(
                  eta: eta,
                  tracking: tracking,
                  onBack: () {
                    provider.stopTracking();
                    Navigator.pop(context);
                  },
                  onShare: () => _shareTracking(booking),
                ),
                Positioned(
                  right: 16,
                  bottom: MediaQuery.sizeOf(context).height * 0.38,
                  child: _FollowModeControl(
                    mode: _mode,
                    hasCustomer: provider.customerLocation != null,
                    onSelect: (m) {
                      HapticFeedback.selectionClick();
                      setState(() => _mode = m);
                    },
                  ),
                ),
                TrackingBottomSheet(
                  booking: booking,
                  tracking: tracking,
                  eta: eta,
                  scheduleRoute: provider.scheduleRoute,
                  phase: provider.phase,
                  onCall: () => _callDriver(phone),
                  onChat: () => _chatDriver(phone),
                ),
                if (provider.locationPermissionDenied)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: MediaQuery.paddingOf(context).top + 76,
                    child: _LocationPermissionBanner(
                      message: provider.locationError ??
                          'เปิดสิทธิ์ตำแหน่งเพื่อแสดงจุดที่คุณอยู่บนแผนที่',
                      onRetry: () => provider.retryCustomerLocation(),
                      onOpenSettings: () => Geolocator.openAppSettings(),
                    ),
                  ),
                if (provider.isLoading) const _TrackingLoadingOverlay(),
                if (provider.phase == TrackingPhase.imminent)
                  Positioned(
                    left: 24,
                    right: 24,
                    top: MediaQuery.paddingOf(context).top + 112,
                    child: const TrackingStatusBanner(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class VehicleMapWidget extends StatefulWidget {
  final VehicleTracking? tracking;
  final BookingInfo? booking;
  final LatLng? customerLocation;
  final List<LatLng> routePoints;
  final ScheduleRouteData? scheduleRoute;
  final TrackingPhase phase;
  final Animation<double> pulse;
  final FollowMode mode;
  final VoidCallback onUserGesture;

  const VehicleMapWidget({
    super.key,
    required this.tracking,
    required this.booking,
    required this.customerLocation,
    required this.routePoints,
    required this.scheduleRoute,
    required this.phase,
    required this.pulse,
    required this.mode,
    required this.onUserGesture,
  });

  @override
  State<VehicleMapWidget> createState() => _VehicleMapWidgetState();
}

class _VehicleMapWidgetState extends State<VehicleMapWidget> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  LatLng? _lastVehicleLocation;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VehicleMapWidget old) {
    super.didUpdateWidget(old);
    if (!_isMapReady || widget.mode == FollowMode.free) return;

    // Grab/LineMan-style: keep the camera framed for the chosen mode. Re-fit
    // when the mode changes or the van/customer actually moves.
    final modeChanged = widget.mode != old.mode;
    final vehicleMoved =
        _changed(widget.tracking?.driverLocation, old.tracking?.driverLocation);
    final userMoved = _changed(widget.customerLocation, old.customerLocation);

    if (modeChanged || vehicleMoved || userMoved) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recenter());
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.tracking?.driverLocation;

    // No vehicle location yet — render map directly without TweenAnimationBuilder
    // to avoid null-check crash inside tween_animation_builder.dart (tween.end!)
    if (target == null) {
      return _buildMap(null);
    }

    final begin = _lastVehicleLocation ?? target;
    return TweenAnimationBuilder<LatLng>(
      tween: _LatLngTween(begin: begin, end: target),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      onEnd: () => _lastVehicleLocation = target,
      builder: (context, animatedVehicle, _) => _buildMap(animatedVehicle),
    );
  }

  /// Frame the camera for the active follow mode. "both" fits the van, the
  /// customer and the pickup; "vehicle"/"me" centre on one. Padding leaves room
  /// for the top bar and the bottom sheet so no marker hides behind the UI.
  void _recenter() {
    if (!mounted || !_isMapReady) return;

    final vehicle = _validPoint(widget.tracking?.driverLocation);
    final customer = _validPoint(widget.customerLocation);

    switch (widget.mode) {
      case FollowMode.free:
        return;
      case FollowMode.vehicle:
        if (vehicle != null) _mapController.move(vehicle, 15.5);
        return;
      case FollowMode.me:
        if (customer != null) _mapController.move(customer, 15.5);
        return;
      case FollowMode.both:
        break;
    }

    final points = <LatLng>[
      ?vehicle,
      ?customer,
      ?_validPoint(widget.booking?.pickupPoint),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 15.5);
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(64, 180, 64, 320),
        maxZoom: 16.5,
      ),
    );
  }

  // ~22m threshold so GPS jitter doesn't re-frame the camera every tick — only
  // real movement of the van or the customer nudges the view.
  bool _changed(LatLng? a, LatLng? b) {
    if (a == null && b == null) return false;
    if (a == null || b == null) return true;
    return (a.latitude - b.latitude).abs() > 0.0002 ||
        (a.longitude - b.longitude).abs() > 0.0002;
  }

  Widget _buildMap(LatLng? vehicleLocation) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter(vehicleLocation),
        initialZoom: 14.5,
        minZoom: 5,
        maxZoom: 18,
        onMapReady: () {
          setState(() => _isMapReady = true);
          WidgetsBinding.instance.addPostFrameCallback((_) => _recenter());
        },
        onPositionChanged: (_, hasGesture) {
          if (hasGesture) widget.onUserGesture();
        },
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.luilaykhao.app',
        ),
        PolylineLayer(polylines: _routeLines(vehicleLocation)),
        MarkerLayer(markers: _markers(vehicleLocation)),
      ],
    );
  }

  LatLng _initialCenter(LatLng? animatedVehicle) {
    // เริ่มที่ตำแหน่งของฉันก่อน (fallback ไปรถ/จุดรับเมื่อยังไม่มีพิกัดผู้ใช้)
    return _validPoint(widget.customerLocation) ??
        animatedVehicle ??
        _validPoint(widget.booking?.pickupPoint) ??
        widget.booking?.destinationPoint ??
        const LatLng(13.7563, 100.5018);
  }

  List<Polyline> _routeLines(LatLng? vehicle) {
    final lines = <Polyline>[];

    // เส้นพื้นหลัง: เส้นทางเดินรถทั้งรอบ (จุดรับทุกจุด → ปลายทาง) สีจางกว่า
    // เพื่อให้เห็นภาพรวมว่ารถวิ่งเส้นไหน อยู่ช่วงไหนของเส้นทาง
    final full = widget.scheduleRoute;
    if (full != null) {
      final fullLine =
          full.polyline.length >= 2 ? full.polyline : full.stopPoints;
      if (fullLine.length >= 2) {
        lines.add(
          Polyline(
            points: fullLine,
            strokeWidth: 4,
            color: const Color(0xFF94A3B8).withValues(alpha: 0.65),
          ),
        );
      }
    }

    // เส้นหลัก: เส้นทางตามถนนจริงจากรถถึงจุดของลูกค้าแบบ Grab
    if (widget.routePoints.length >= 2) {
      lines.add(
        Polyline(
          points: widget.routePoints,
          strokeWidth: 5,
          color: AppTheme.primaryColor.withValues(alpha: 0.86),
        ),
      );
      return lines;
    }

    // Fallback: เส้นตรงเมื่อยังไม่มีเส้นทางถนน (ไม่มีคีย์/ยังโหลดไม่เสร็จ)
    final pickup = _validPoint(widget.booking?.pickupPoint);
    final destination =
        widget.tracking?.destinationPoint ?? widget.booking?.destinationPoint;
    final route = <LatLng>[
      ?vehicle,
      ?pickup,
      if (destination != null && !_samePoint(destination, pickup)) destination,
    ];
    if (route.length >= 2) {
      lines.add(
        Polyline(
          points: route,
          strokeWidth: 5,
          color: AppTheme.primaryColor.withValues(alpha: 0.5),
        ),
      );
    }
    return lines;
  }

  /// หมุดจุดรับอื่นๆ ตามเส้นทาง (ไม่รวมจุดของลูกค้าเองที่มีหมุด "จุดรับ" อยู่แล้ว)
  /// — จุดที่รับแล้วเป็นติ๊กเขียว จุดที่ยังไม่ถึงเป็นเลขลำดับสีเทา
  List<Marker> _stopMarkers(LatLng? myPickup) {
    final stops = widget.scheduleRoute?.stops ?? const <RouteStop>[];
    final markers = <Marker>[];
    var number = 0;
    for (final stop in stops) {
      if (stop.isDestination) continue;
      number++;
      final point = stop.point;
      if (point == null || _samePoint(point, myPickup)) continue;
      markers.add(
        Marker(
          point: point,
          width: 24,
          height: 24,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: stop.completed
                  ? const Color(0xFF10B981)
                  : const Color(0xFF475569),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: stop.completed
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                : Text(
                    '$number',
                    style: appFont(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
      );
    }
    return markers;
  }

  List<Marker> _markers(LatLng? vehicle) {
    final pickup = _validPoint(widget.booking?.pickupPoint);
    final destination = widget.tracking?.destinationPoint ??
        widget.booking?.destinationPoint ??
        widget.scheduleRoute?.stops
            .where((s) => s.isDestination)
            .firstOrNull
            ?.point;
    return [
      ..._stopMarkers(pickup),
      if (destination != null && !_samePoint(destination, pickup))
        Marker(
          point: destination,
          width: 56,
          height: 64,
          child: const _MapPin(
            icon: Icons.flag_rounded,
            label: 'ปลายทาง',
            color: Color(0xFF111111),
          ),
        ),
      if (pickup != null)
        Marker(
          point: pickup,
          width: 56,
          height: 64,
          child: const _MapPin(
            icon: Icons.location_on_rounded,
            label: 'จุดรับ',
            color: AppTheme.primaryColor,
          ),
        ),
      if (widget.customerLocation != null)
        Marker(
          point: widget.customerLocation!,
          width: 70,
          height: 68,
          child: _UserMarker(pulse: widget.pulse),
        ),
      if (vehicle != null)
        Marker(
          point: vehicle,
          width: 88,
          height: 88,
          child: _VehicleMarker(
            phase: widget.phase,
            pulse: widget.pulse,
            heading: widget.tracking?.heading,
          ),
        ),
    ];
  }

  LatLng? _validPoint(LatLng? point) {
    if (point == null) return null;
    if (point.latitude == 0 && point.longitude == 0) return null;
    return point;
  }

  bool _samePoint(LatLng? a, LatLng? b) {
    if (a == null || b == null) return false;
    return (a.latitude - b.latitude).abs() < 0.00001 &&
        (a.longitude - b.longitude).abs() < 0.00001;
  }
}

class TrackingTopBar extends StatelessWidget {
  final ETAResult? eta;
  final VehicleTracking? tracking;
  final VoidCallback onBack;
  final VoidCallback onShare;

  const TrackingTopBar({
    super.key,
    required this.eta,
    required this.tracking,
    required this.onBack,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.paddingOf(context).top + 12,
      child: Row(
        children: [
          _FloatingAction(
            icon: Icons.arrow_back_ios_new_rounded,
            label: 'ย้อนกลับ',
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: AppTheme.surface(context).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_bus_filled_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _headline(eta),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appFont(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${eta?.formattedETA ?? '--'} • ${eta?.formattedDistance ?? '--'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appFont(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _FloatingAction(
            icon: Icons.ios_share_rounded,
            label: 'แชร์ตำแหน่งรถ',
            onTap: onShare,
          ),
        ],
      ),
    );
  }

  String _headline(ETAResult? eta) {
    if (eta?.phase == TrackingPhase.arrived) return 'รถถึงจุดรับแล้ว';
    return 'รถกำลังมาถึง';
  }
}

class TrackingBottomSheet extends StatelessWidget {
  final BookingInfo? booking;
  final VehicleTracking? tracking;
  final ETAResult? eta;
  final ScheduleRouteData? scheduleRoute;
  final TrackingPhase phase;
  final VoidCallback onCall;
  final VoidCallback onChat;

  const TrackingBottomSheet({
    super.key,
    required this.booking,
    required this.tracking,
    required this.eta,
    required this.scheduleRoute,
    required this.phase,
    required this.onCall,
    required this.onChat,
  });

  /// จุดรับของลูกค้าใน timeline — เทียบจากพิกัดจุดรับที่จองไว้ (BookingInfo
  /// ไม่ได้ส่ง pickup_point_id มา จึงจับคู่จากระยะห่าง ~30 ม.)
  int? _myStopId() {
    final myPickup = booking?.pickupPoint;
    final stops = scheduleRoute?.stops;
    if (myPickup == null || stops == null) return null;
    if (myPickup.latitude == 0 && myPickup.longitude == 0) return null;
    const distance = Distance();
    for (final stop in stops) {
      if (stop.isDestination || stop.point == null) continue;
      if (distance.as(LengthUnit.Meter, stop.point!, myPickup) < 30) {
        return stop.id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.24,
      maxChildSize: 0.62,
      snap: true,
      snapSizes: const [0.24, 0.32, 0.62],
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E7EC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'เวลาถึง',
                        value: eta?.formattedETA ?? '--',
                        highlighted: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'ระยะทาง',
                        value: eta?.formattedDistance ?? '--',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'สถานะ',
                        value: _phaseLabel(phase),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  booking?.tripTitle ?? tracking?.tripTitle ?? 'กำลังโหลดทริป',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'เวลานัด',
                  // เวลาออกรถจริง (departs_at) มาก่อนวันทริปได้ เช่น 23:30 คืนก่อนหน้า
                  value: (booking?.departsAt.isNotEmpty ?? false)
                      ? booking!.departsAt
                      : booking?.departureDate ?? 'รอข้อมูล',
                ),
                _DetailRow(
                  icon: Icons.location_on_rounded,
                  label: 'จุดรับ',
                  value: booking?.departurePoint ?? 'รอข้อมูลจุดรับ',
                ),
                _DetailRow(
                  icon: Icons.directions_bus_filled_rounded,
                  label: 'รถ',
                  value: [
                    if ((tracking?.licensePlate ?? booking?.licensePlate ?? '')
                        .isNotEmpty)
                      tracking?.licensePlate ?? booking?.licensePlate,
                    if ((tracking?.driverName ?? booking?.driverName ?? '')
                        .isNotEmpty)
                      tracking?.driverName ?? booking?.driverName,
                  ].whereType<String>().join(' • '),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.phone_rounded,
                        label: 'โทร',
                        onTap: onCall,
                        filled: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.chat_bubble_rounded,
                        label: 'แชท',
                        onTap: onChat,
                      ),
                    ),
                  ],
                ),

                // เส้นทางเดินรถทั้งรอบ — เลื่อนแผ่นขึ้นมาดูว่ารถผ่านจุดไหนบ้าง
                // จุดไหนรับแล้ว และจุดของเราอยู่ลำดับที่เท่าไร
                if (scheduleRoute != null && !scheduleRoute!.isEmpty) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Icon(
                        Icons.route_rounded,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'เส้นทางเดินรถ',
                        style: appFont(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RouteTimeline(
                    stops: scheduleRoute!.stops,
                    highlightPickupPointId: _myStopId(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _phaseLabel(TrackingPhase phase) {
    return switch (phase) {
      TrackingPhase.arrived => 'ถึงแล้ว',
      TrackingPhase.imminent => 'ใกล้ถึง',
      TrackingPhase.nearSoon => 'กำลังมา',
      TrackingPhase.far => 'ออกเดินทาง',
    };
  }
}

class TrackingStatusBanner extends StatelessWidget {
  const TrackingStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'รถใกล้ถึงจุดรับแล้ว',
            style: appFont(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleMarker extends StatelessWidget {
  final TrackingPhase phase;
  final Animation<double> pulse;
  final double? heading;

  const _VehicleMarker({
    required this.phase,
    required this.pulse,
    required this.heading,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 52 * pulse.value,
              height: 52 * pulse.value,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(
                  alpha: phase == TrackingPhase.imminent ? 0.22 : 0.10,
                ),
                shape: BoxShape.circle,
              ),
            ),
            Transform.rotate(
              angle: ((heading ?? 0) * math.pi) / 180,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MapPin extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MapPin({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: appFont(
              color: AppTheme.textMain,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserMarker extends StatelessWidget {
  final Animation<double> pulse;

  const _UserMarker({required this.pulse});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2F80ED);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // วงกลม accuracy ที่ค่อยๆ ขยายและจางหาย (แบบจุดสีน้ำเงินของ Grab)
              AnimatedBuilder(
                animation: pulse,
                builder: (context, _) {
                  final t = ((pulse.value - 1.0) / 0.28).clamp(0.0, 1.0);
                  return Container(
                    width: 30 + 16 * t,
                    height: 30 + 16 * t,
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.22 * (1 - t)),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: blue,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'คุณ',
            style: appFont(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationPermissionBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const _LocationPermissionBanner({
    required this.message,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2F80ED).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: Color(0xFF2F80ED), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ยังไม่เห็นตำแหน่งของคุณ',
                  style: appFont(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: appFont(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText(context),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _BannerButton(
                      label: 'ลองใหม่',
                      filled: true,
                      onTap: onRetry,
                    ),
                    const SizedBox(width: 8),
                    _BannerButton(
                      label: 'ตั้งค่า',
                      filled: false,
                      onTap: onOpenSettings,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _BannerButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2F80ED);
    return Material(
      color: filled ? blue : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: filled ? null : Border.all(color: blue.withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: appFont(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: filled ? Colors.white : blue,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;

  const _MetricCard({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : AppTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              color: highlighted ? AppTheme.primaryColor : AppTheme.textMain,
              fontSize: highlighted ? 18 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: appFont(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'รอข้อมูล' : value,
                  style: appFont(
                    color: AppTheme.textMain,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 19),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                textStyle: appFont(fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 19),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                textStyle: appFont(fontWeight: FontWeight.w900),
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
    );
  }
}

class _FollowModeControl extends StatelessWidget {
  final FollowMode mode;
  final bool hasCustomer;
  final ValueChanged<FollowMode> onSelect;

  const _FollowModeControl({
    required this.mode,
    required this.hasCustomer,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(context, FollowMode.both, Icons.fit_screen_rounded, 'ดูทั้งคู่'),
          _button(context, FollowMode.vehicle,
              Icons.directions_bus_filled_rounded, 'ดูรถ'),
          if (hasCustomer)
            _button(context, FollowMode.me, Icons.my_location_rounded, 'ดูฉัน'),
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context,
    FollowMode value,
    IconData icon,
    String label,
  ) {
    final active = mode == value;
    return Semantics(
      label: label,
      button: true,
      selected: active,
      child: Material(
        color: active ? AppTheme.primaryColor : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onSelect(value),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: active ? Colors.white : AppTheme.onSurface(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FloatingAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: AppTheme.surface(context),
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.onSurface(context), size: 20),
          ),
        ),
      ),
    );
  }
}

class _TrackingLoadingOverlay extends StatelessWidget {
  const _TrackingLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background(context).withValues(alpha: 0.72),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 12),
              Text(
                'กำลังเชื่อมต่อรถ',
                style: appFont(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required LatLng super.begin, required LatLng super.end});

  @override
  LatLng lerp(double t) {
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}
