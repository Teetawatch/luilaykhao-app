/// เส้นทางและกราฟความสูงของเหรียญ — แบบที่ Strava วาดลงการ์ดแชร์
///
/// ข้อมูลมาเป็นรูปร่างในกรอบ 0–1 แล้ว (MedalRouteService) ไม่มีพิกัดจริง
/// ที่นี่แค่ขยายลงกล่องที่ได้มาแบบรักษาสัดส่วน แบนตามธีม ไม่มีเงา/แสงเรือง
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/trip_medal.dart';

/// เส้นทาง — จุดเริ่มเป็นวงโปร่ง จุดจบเป็นวงทึบ เหมือนแผนที่วิ่งทั่วไป
class MedalRouteView extends StatelessWidget {
  final MedalRoute route;
  final Color color;
  final double strokeWidth;

  const MedalRouteView({
    super.key,
    required this.route,
    this.color = Colors.white,
    this.strokeWidth = 3.2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoutePainter(
        points: route.points,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const _RoutePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.isEmpty) return;

    // จุดอยู่ในสี่เหลี่ยมจัตุรัส 0–1 — วางจัตุรัสนั้นกลางกล่อง เว้นขอบเท่าเส้น
    // กับวงปลายทาง ไม่ให้ปลายเส้นถูกตัดขอบ
    final pad = strokeWidth * 2.2;
    final side = math.max(0.0, math.min(size.width, size.height) - pad * 2);
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    Offset at(Offset p) => origin + Offset(p.dx * side, p.dy * side);

    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dot = strokeWidth * 1.6;
    canvas
      ..drawCircle(
        at(points.first),
        dot,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.7,
      )
      ..drawCircle(at(points.last), dot, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.points != points ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// กราฟความสูงแบบพื้นทึบ — เส้นบนเข้ม พื้นใต้เส้นจาง
class MedalElevationView extends StatelessWidget {
  final List<int> elevations;
  final Color color;

  const MedalElevationView({
    super.key,
    required this.elevations,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ElevationPainter(values: elevations, color: color),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  final List<int> values;
  final Color color;

  const _ElevationPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;

    final lo = values.reduce(math.min).toDouble();
    final hi = values.reduce(math.max).toDouble();
    // ทางราบทั้งเส้น — วาดเป็นเส้นกลางกล่องแทนการหารศูนย์
    final range = hi - lo;

    double y(int v) {
      if (range <= 0) return size.height * 0.5;
      // เหลือพื้นล่างไว้ 12% ไม่ให้จุดต่ำสุดจมติดขอบ
      return size.height - (v - lo) / range * size.height * 0.88 - 1;
    }

    final dx = size.width / (values.length - 1);
    final line = Path()..moveTo(0, y(values.first));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(i * dx, y(values[i]));
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas
      ..drawPath(area, Paint()..color = color.withValues(alpha: 0.22))
      ..drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_ElevationPainter old) =>
      old.values != values || old.color != color;
}
