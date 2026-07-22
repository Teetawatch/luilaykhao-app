import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// One sampled point of a route: how far in, and how high.
class ElevationPoint {
  final double km;
  final double elevation;

  const ElevationPoint({required this.km, required this.elevation});
}

/// Everything the trip's `route_track` block carries, parsed once.
///
/// Returns null from [parse] whenever the trip has no usable elevation data, so
/// callers can hide the section instead of drawing an empty chart.
class RouteTrack {
  final List<ElevationPoint> points;
  final double distanceKm;
  final int elevationGainM;
  final int elevationLossM;
  final int? maxElevationM;
  final int? minElevationM;
  final SteepestSegment? steepest;

  const RouteTrack({
    required this.points,
    required this.distanceKm,
    required this.elevationGainM,
    required this.elevationLossM,
    this.maxElevationM,
    this.minElevationM,
    this.steepest,
  });

  static RouteTrack? parse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map['has_elevation'] != true) return null;

    final points = <ElevationPoint>[];
    for (final item in (map['points'] as List? ?? const [])) {
      if (item is! Map) continue;
      final ele = item['ele'];
      final km = item['km'];
      if (ele == null || km == null) continue;
      points.add(
        ElevationPoint(
          km: double.tryParse('$km') ?? 0,
          elevation: double.tryParse('$ele') ?? 0,
        ),
      );
    }

    // Two points is the minimum that draws a line rather than a dot.
    if (points.length < 2) return null;

    return RouteTrack(
      points: points,
      distanceKm: double.tryParse('${map['distance_km'] ?? 0}') ?? 0,
      elevationGainM: int.tryParse('${map['elevation_gain_m'] ?? 0}') ?? 0,
      elevationLossM: int.tryParse('${map['elevation_loss_m'] ?? 0}') ?? 0,
      maxElevationM: int.tryParse('${map['max_elevation_m'] ?? ''}'),
      minElevationM: int.tryParse('${map['min_elevation_m'] ?? ''}'),
      steepest: SteepestSegment.parse(map['steepest']),
    );
  }
}

class SteepestSegment {
  final double fromKm;
  final double toKm;
  final int riseM;
  final double gradePercent;

  const SteepestSegment({
    required this.fromKm,
    required this.toKm,
    required this.riseM,
    required this.gradePercent,
  });

  static SteepestSegment? parse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final grade = double.tryParse('${map['grade_percent'] ?? ''}');
    if (grade == null) return null;

    return SteepestSegment(
      fromKm: double.tryParse('${map['from_km'] ?? 0}') ?? 0,
      toKm: double.tryParse('${map['to_km'] ?? 0}') ?? 0,
      riseM: int.tryParse('${map['rise_m'] ?? 0}') ?? 0,
      gradePercent: grade,
    );
  }
}

/// Elevation profile of a route — the shape of the walk, which is what anyone
/// deciding whether they can handle a trek actually reads.
///
/// Dragging along the chart reveals the exact height at that distance; the
/// steepest stretch is shaded so it is visible without any interaction.
class ElevationProfileChart extends StatefulWidget {
  final RouteTrack track;

  const ElevationProfileChart({super.key, required this.track});

  @override
  State<ElevationProfileChart> createState() => _ElevationProfileChartState();
}

class _ElevationProfileChartState extends State<ElevationProfileChart> {
  int? _touchedIndex;

  void _updateTouch(Offset localPosition, double width) {
    final points = widget.track.points;
    final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
    final targetKm = ratio * points.last.km;

    // Points are unevenly spaced in distance, so pick by km rather than index.
    var nearest = 0;
    var bestDelta = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final delta = (points[i].km - targetKm).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        nearest = i;
      }
    }

    if (nearest != _touchedIndex) {
      HapticFeedback.selectionClick();
      setState(() => _touchedIndex = nearest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final touched = _touchedIndex == null
        ? null
        : track.points[_touchedIndex!.clamp(0, track.points.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Readout sits above the chart so a finger on the line never covers it.
        SizedBox(
          height: 26,
          child: touched == null
              ? Text(
                  'ลากนิ้วบนกราฟเพื่อดูความสูงแต่ละช่วง',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText(context),
                  ),
                )
              : Row(
                  children: [
                    Text(
                      'กม. ${touched.km.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${touched.elevation.round()} ม.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onHorizontalDragStart: (d) =>
                  _updateTouch(d.localPosition, width),
              onHorizontalDragUpdate: (d) =>
                  _updateTouch(d.localPosition, width),
              onHorizontalDragEnd: (_) => setState(() => _touchedIndex = null),
              onTapDown: (d) => _updateTouch(d.localPosition, width),
              onTapUp: (_) => setState(() => _touchedIndex = null),
              onTapCancel: () => setState(() => _touchedIndex = null),
              child: SizedBox(
                height: 150,
                width: width,
                child: CustomPaint(
                  painter: _ElevationPainter(
                    track: track,
                    touchedIndex: _touchedIndex,
                    lineColor: AppTheme.primaryColor,
                    fillColor: AppTheme.primaryColor.withValues(alpha: 0.14),
                    gridColor: AppTheme.border(context),
                    steepColor: AppTheme.accentColor.withValues(alpha: 0.18),
                    labelColor: AppTheme.mutedText(context),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ElevationPainter extends CustomPainter {
  final RouteTrack track;
  final int? touchedIndex;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color steepColor;
  final Color labelColor;

  _ElevationPainter({
    required this.track,
    required this.touchedIndex,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.steepColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final points = track.points;
    if (points.length < 2) return;

    const labelGutter = 34.0; // room for the two height labels on the left
    const chartLeft = labelGutter;
    final chartWidth = size.width - labelGutter;
    final chartHeight = size.height - 16;

    final totalKm = points.last.km;
    if (totalKm <= 0 || chartWidth <= 0) return;

    var minEle = points.first.elevation;
    var maxEle = points.first.elevation;
    for (final p in points) {
      minEle = math.min(minEle, p.elevation);
      maxEle = math.max(maxEle, p.elevation);
    }
    // A flat route would divide by zero; give it a nominal band instead.
    final span = (maxEle - minEle).abs() < 1 ? 1.0 : maxEle - minEle;

    double dx(double km) => chartLeft + (km / totalKm) * chartWidth;
    double dy(double ele) => chartHeight - ((ele - minEle) / span) * chartHeight;

    // Baseline + top line, labelled with the real heights.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(chartLeft, chartHeight),
      Offset(size.width, chartHeight),
      grid,
    );
    canvas.drawLine(const Offset(chartLeft, 0), Offset(size.width, 0), grid);

    _drawLabel(canvas, '${maxEle.round()}', const Offset(0, 0), labelColor);
    _drawLabel(
      canvas,
      '${minEle.round()}',
      Offset(0, chartHeight - 11),
      labelColor,
    );

    // Shade the steepest stretch so it reads without touching anything.
    final steepest = track.steepest;
    if (steepest != null && steepest.toKm > steepest.fromKm) {
      canvas.drawRect(
        Rect.fromLTRB(
          dx(steepest.fromKm),
          0,
          dx(steepest.toKm),
          chartHeight,
        ),
        Paint()..color = steepColor,
      );
    }

    final path = Path()..moveTo(dx(points.first.km), dy(points.first.elevation));
    for (final p in points.skip(1)) {
      path.lineTo(dx(p.km), dy(p.elevation));
    }

    final fill = Path.from(path)
      ..lineTo(dx(points.last.km), chartHeight)
      ..lineTo(dx(points.first.km), chartHeight)
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    if (touchedIndex != null) {
      final p = points[touchedIndex!.clamp(0, points.length - 1)];
      final x = dx(p.km);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, chartHeight),
        Paint()
          ..color = lineColor.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        Offset(x, dy(p.elevation)),
        4.5,
        Paint()..color = lineColor,
      );
      canvas.drawCircle(
        Offset(x, dy(p.elevation)),
        2,
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter old) =>
      old.touchedIndex != touchedIndex || old.track != track;
}
