import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/api_config.dart';
import '../models/schedule_route.dart';
import '../theme/app_theme.dart';
import 'skeleton.dart';

/// การ์ด "เส้นทางเดินรถ" — แผนที่พรีวิว (เส้นทางถนนจริง + หมุดจุดจอดเรียงเลข)
/// พร้อม timeline จุดรับ→ปลายทาง ใช้ร่วมกันบนหน้าทริปและหน้าการจอง
///
/// โหลดข้อมูลเองจาก `GET /schedules/{id}/route` (public) และ cache ในหน่วยความจำ
/// ต่อรอบ — สลับวันไปมาไม่ยิงซ้ำ; ไม่มีจุดจอดเลย → ไม่แสดงอะไร
class RouteMapCard extends StatefulWidget {
  final int scheduleId;

  /// จุดรับที่ลูกค้าเลือก/จองไว้ — ไฮไลต์ใน timeline และบนแผนที่
  final int? highlightPickupPointId;

  const RouteMapCard({
    super.key,
    required this.scheduleId,
    this.highlightPickupPointId,
  });

  @override
  State<RouteMapCard> createState() => _RouteMapCardState();
}

class _RouteMapCardState extends State<RouteMapCard> {
  // cache ต่อ session — เส้นทางของรอบแทบไม่เปลี่ยนระหว่างเปิดแอป
  static final Map<int, ScheduleRouteData> _cache = {};

  ScheduleRouteData? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RouteMapCard old) {
    super.didUpdateWidget(old);
    if (old.scheduleId != widget.scheduleId) _load();
  }

  Future<void> _load() async {
    final cached = _cache[widget.scheduleId];
    if (cached != null) {
      setState(() {
        _data = cached;
        _loading = false;
      });
      return;
    }

    setState(() {
      _data = null;
      _loading = true;
    });

    final requestedId = widget.scheduleId;
    ScheduleRouteData? data;
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/schedules/$requestedId/route'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is Map && body['success'] == true && body['data'] is Map) {
          data = ScheduleRouteData.fromJson(
            Map<String, dynamic>.from(body['data'] as Map),
          );
          _cache[requestedId] = data;
        }
      }
    } catch (e) {
      debugPrint('[RouteMapCard] load error: $e');
    }

    if (!mounted || requestedId != widget.scheduleId) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SkeletonBox(
        height: 150,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      );
    }

    final data = _data;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    final stops = data.stops;
    final mapPoints = stops
        .where((s) => s.point != null)
        .map((s) => s.point!)
        .toList();
    // เส้นถนนจริงจาก backend; ไม่มี (ไม่มีคีย์/หาไม่ได้) → เส้นตรงไล่ตามจุดจอด
    final line = data.polyline.length >= 2
        ? data.polyline
        : (mapPoints.length >= 2 ? mapPoints : const <LatLng>[]);

    return Container(
      decoration: AppTheme.cardDecoration(context, radius: 20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, data),
          if (mapPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            _mapPreview(context, stops, mapPoints, line),
          ],
          const SizedBox(height: 14),
          RouteTimeline(
            stops: stops,
            highlightPickupPointId: widget.highlightPickupPointId,
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ScheduleRouteData data) {
    final pickupCount = data.stops.where((s) => !s.isDestination).length;
    final parts = <String>[
      'จุดรับ $pickupCount จุด',
      if (data.distanceMeters > 0) _distanceText(data.distanceMeters),
      if (data.durationSeconds > 0) '~${_durationText(data.durationSeconds)}',
    ];

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.route_rounded,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เส้นทางเดินรถ',
                style: appFont(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                parts.join(' • '),
                style: appFont(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapPreview(
    BuildContext context,
    List<RouteStop> stops,
    List<LatLng> mapPoints,
    List<LatLng> line,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullScreenRouteMap(
              stops: stops,
              line: line,
              highlightPickupPointId: widget.highlightPickupPointId,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 190,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: _RouteMap(
                    stops: stops,
                    mapPoints: mapPoints,
                    line: line,
                    highlightPickupPointId: widget.highlightPickupPointId,
                    interactive: false,
                  ),
                ),
              ),
              // ป้ายบอกว่าแตะเพื่อขยายดูเต็มจอ
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.border(context).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_full_rounded,
                        size: 13,
                        color: AppTheme.onSurface(context),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'ขยายแผนที่',
                        style: appFont(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// Timeline จุดจอดเรียงลำดับ (จุดรับ→ปลายทาง) — ใช้ในการ์ดเส้นทางเดินรถ
/// และใน bottom sheet ของหน้าติดตามรถ
class RouteTimeline extends StatelessWidget {
  final List<RouteStop> stops;
  final int? highlightPickupPointId;

  const RouteTimeline({
    super.key,
    required this.stops,
    this.highlightPickupPointId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < stops.length; i++)
          _TimelineRow(
            stop: stops[i],
            index: i,
            isLast: i == stops.length - 1,
            highlighted: stops[i].id != null &&
                stops[i].id == highlightPickupPointId,
          ),
      ],
    );
  }
}

String _distanceText(int meters) {
  final km = meters / 1000;
  if (km >= 1) return '${km >= 100 ? km.round() : km.toStringAsFixed(1)} กม.';
  return '$meters ม.';
}

String _durationText(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes นาที';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m > 0 ? '$h ชม. $m นาที' : '$h ชม.';
}

/// แผนที่เส้นทาง (ใช้ทั้งพรีวิวในการ์ดและแบบเต็มจอ)
class _RouteMap extends StatelessWidget {
  final List<RouteStop> stops;
  final List<LatLng> mapPoints;
  final List<LatLng> line;
  final int? highlightPickupPointId;
  final bool interactive;

  const _RouteMap({
    required this.stops,
    required this.mapPoints,
    required this.line,
    required this.highlightPickupPointId,
    required this.interactive,
  });

  @override
  Widget build(BuildContext context) {
    final fitPoints = line.length >= 2 ? [...line, ...mapPoints] : mapPoints;

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: fitPoints.length >= 2
            ? CameraFit.coordinates(
                coordinates: fitPoints,
                padding: const EdgeInsets.all(36),
                maxZoom: 15,
              )
            : null,
        initialCenter: fitPoints.isNotEmpty
            ? fitPoints.first
            : const LatLng(13.7563, 100.5018),
        initialZoom: 13,
        minZoom: 5,
        maxZoom: 18,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.luilaykhao.app',
        ),
        if (line.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: line,
                strokeWidth: 4.5,
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
              ),
            ],
          ),
        MarkerLayer(markers: _markers()),
      ],
    );
  }

  List<Marker> _markers() {
    final markers = <Marker>[];
    var number = 0;
    for (final stop in stops) {
      if (stop.point == null) continue;
      if (stop.isDestination) {
        markers.add(
          Marker(
            point: stop.point!,
            width: 34,
            height: 34,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(
                Icons.flag_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        );
        continue;
      }

      number++;
      final highlighted =
          stop.id != null && stop.id == highlightPickupPointId;
      markers.add(
        Marker(
          point: stop.point!,
          width: highlighted ? 32 : 26,
          height: highlighted ? 32 : 26,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlighted
                  ? AppTheme.primaryColor
                  : const Color(0xFF475569),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: Text(
              '$number',
              style: appFont(
                color: Colors.white,
                fontSize: highlighted ? 13 : 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }
}

/// แถวหนึ่งจุดจอดใน timeline (จุด + เส้นเชื่อม + ชื่อ/เวลา)
class _TimelineRow extends StatelessWidget {
  final RouteStop stop;
  final int index;
  final bool isLast;
  final bool highlighted;

  const _TimelineRow({
    required this.stop,
    required this.index,
    required this.isLast,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    final Color dotColor = stop.isDestination
        ? const Color(0xFF111111)
        : stop.completed
            ? const Color(0xFF10B981)
            : highlighted
                ? AppTheme.primaryColor
                : const Color(0xFF94A3B8);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // คอลัมน์จุด + เส้นเชื่อมแนวตั้ง
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 3),
                stop.completed
                    ? Icon(Icons.check_circle_rounded,
                        size: 15, color: dotColor)
                    : Container(
                        width: stop.isDestination || highlighted ? 13 : 10,
                        height: stop.isDestination || highlighted ? 13 : 10,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          border: highlighted
                              ? Border.all(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.25),
                                  width: 2,
                                  strokeAlign:
                                      BorderSide.strokeAlignOutside,
                                )
                              : null,
                        ),
                      ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.border(context)
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          stop.name.isEmpty
                              ? (stop.isDestination ? 'ปลายทาง' : '-')
                              : stop.name,
                          style: appFont(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                            color: stop.completed
                                ? muted
                                : AppTheme.onSurface(context),
                          ),
                        ),
                      ),
                      if (stop.pickupTime.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.subtleSurface(context),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            stop.pickupTime,
                            style: appFont(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (stop.isDestination ||
                      stop.regionLabel.isNotEmpty ||
                      highlighted ||
                      stop.completed) ...[
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (stop.isDestination)
                          Text(
                            'ปลายทาง',
                            style: appFont(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          )
                        else if (stop.regionLabel.isNotEmpty)
                          Text(
                            stop.regionLabel,
                            style: appFont(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        if (highlighted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'จุดของคุณ',
                              style: appFont(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        if (stop.completed)
                          Text(
                            'รับแล้ว',
                            style: appFont(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// แผนที่เส้นทางแบบเต็มจอ (เปิดจากการแตะพรีวิวในการ์ด)
class _FullScreenRouteMap extends StatelessWidget {
  final List<RouteStop> stops;
  final List<LatLng> line;
  final int? highlightPickupPointId;

  const _FullScreenRouteMap({
    required this.stops,
    required this.line,
    required this.highlightPickupPointId,
  });

  @override
  Widget build(BuildContext context) {
    final mapPoints =
        stops.where((s) => s.point != null).map((s) => s.point!).toList();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(
          'เส้นทางเดินรถ',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: _RouteMap(
        stops: stops,
        mapPoints: mapPoints,
        line: line,
        highlightPickupPointId: highlightPickupPointId,
        interactive: true,
      ),
    );
  }
}
