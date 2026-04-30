import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tracking_model.dart';
import '../providers/tracking_provider.dart';
import '../theme/app_theme.dart';

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

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  bool _isFollowing = true;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1, end: 1.28).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
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
            backgroundColor: const Color(0xFFF8F8F8),
            body: Stack(
              children: [
                VehicleMapWidget(
                  tracking: tracking,
                  booking: booking,
                  customerLocation: provider.customerLocation,
                  phase: provider.phase,
                  pulse: _pulseAnimation,
                  isFollowing: _isFollowing,
                  onUserGesture: () {
                    if (_isFollowing) setState(() => _isFollowing = false);
                  },
                ),
                TrackingTopBar(
                  eta: eta,
                  tracking: tracking,
                  onBack: () {
                    provider.stopTracking();
                    Navigator.pop(context);
                  },
                ),
                if (!_isFollowing)
                  Positioned(
                    right: 16,
                    bottom: MediaQuery.sizeOf(context).height * 0.38,
                    child: _FloatingAction(
                      icon: Icons.my_location_rounded,
                      label: 'ติดตามตำแหน่ง',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isFollowing = true);
                      },
                    ),
                  ),
                TrackingBottomSheet(
                  booking: booking,
                  tracking: tracking,
                  eta: eta,
                  phase: provider.phase,
                  onCall: () => _callDriver(phone),
                  onChat: () => _chatDriver(phone),
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
  final TrackingPhase phase;
  final Animation<double> pulse;
  final bool isFollowing;
  final VoidCallback onUserGesture;

  const VehicleMapWidget({
    super.key,
    required this.tracking,
    required this.booking,
    required this.customerLocation,
    required this.phase,
    required this.pulse,
    required this.isFollowing,
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
  Widget build(BuildContext context) {
    final tracking = widget.tracking;
    final target = tracking?.driverLocation;
    final begin = _lastVehicleLocation ?? target;

    return TweenAnimationBuilder<LatLng?>(
      tween: _LatLngTween(begin: begin, end: target),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      onEnd: () => _lastVehicleLocation = target,
      builder: (context, animatedVehicle, _) {
        if (widget.isFollowing && animatedVehicle != null && _isMapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isMapReady && widget.isFollowing) {
              _mapController.move(animatedVehicle, _mapController.camera.zoom);
            }
          });
        }

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter(animatedVehicle),
            initialZoom: 14.5,
            minZoom: 5,
            maxZoom: 18,
            onMapReady: () => setState(() => _isMapReady = true),
            onPositionChanged: (_, hasGesture) {
              if (hasGesture) widget.onUserGesture();
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.luilaykhao.app',
            ),
            PolylineLayer(polylines: _routeLines(animatedVehicle)),
            MarkerLayer(markers: _markers(animatedVehicle)),
          ],
        );
      },
    );
  }

  LatLng _initialCenter(LatLng? animatedVehicle) {
    return animatedVehicle ??
        widget.customerLocation ??
        _validPoint(widget.booking?.pickupPoint) ??
        widget.booking?.destinationPoint ??
        const LatLng(13.7563, 100.5018);
  }

  List<Polyline> _routeLines(LatLng? vehicle) {
    final pickup = _validPoint(widget.booking?.pickupPoint);
    final destination =
        widget.tracking?.destinationPoint ?? widget.booking?.destinationPoint;
    final route = <LatLng>[
      if (vehicle != null) vehicle,
      if (pickup != null) pickup,
      if (destination != null && !_samePoint(destination, pickup)) destination,
    ];
    if (route.length < 2) return const [];
    return [
      Polyline(
        points: route,
        strokeWidth: 5,
        color: AppTheme.primaryColor.withValues(alpha: 0.86),
      ),
    ];
  }

  List<Marker> _markers(LatLng? vehicle) {
    final pickup = _validPoint(widget.booking?.pickupPoint);
    final destination =
        widget.tracking?.destinationPoint ?? widget.booking?.destinationPoint;
    return [
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
          width: 44,
          height: 44,
          child: const _UserMarker(),
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

  const TrackingTopBar({
    super.key,
    required this.eta,
    required this.tracking,
    required this.onBack,
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
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
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
                          style: GoogleFonts.anuphan(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${eta?.formattedETA ?? '--'} • ${eta?.formattedDistance ?? '--'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.anuphan(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
  final TrackingPhase phase;
  final VoidCallback onCall;
  final VoidCallback onChat;

  const TrackingBottomSheet({
    super.key,
    required this.booking,
    required this.tracking,
    required this.eta,
    required this.phase,
    required this.onCall,
    required this.onChat,
  });

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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 32,
                offset: Offset(0, -10),
              ),
            ],
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
                  style: GoogleFonts.anuphan(
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
                  value: booking?.departureDate ?? 'รอข้อมูล',
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
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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
            style: GoogleFonts.anuphan(
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
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
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
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 8),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.anuphan(
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
  const _UserMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2F80ED),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8)],
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
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
            : const Color(0xFFF8F8F8),
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
            style: GoogleFonts.anuphan(
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
            style: GoogleFonts.anuphan(
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
                  style: GoogleFonts.anuphan(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'รอข้อมูล' : value,
                  style: GoogleFonts.anuphan(
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
                textStyle: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
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
                textStyle: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
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
        color: Colors.white,
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
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: AppTheme.textMain, size: 20),
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
      color: Colors.white.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
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
                style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatLngTween extends Tween<LatLng?> {
  _LatLngTween({required super.begin, required super.end});

  @override
  LatLng? lerp(double t) {
    if (begin == null) return end;
    if (end == null) return begin;
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}
