import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// วงกลมที่ถูกวาดรอบตัวแล้วตามด้วยเครื่องหมายถูก — จังหวะ "สำเร็จแล้ว" ตอนสแกน
/// เช็คอินผ่าน / ส่งสลิปเสร็จ
///
/// วาดครั้งเดียวตอนโผล่ อยากให้วาดใหม่ (เช็คอินอีกใบ) ให้เปลี่ยน key
/// [haptic] = สั่นเบาๆ ตอนขีดถูกเสร็จ — ปิดไว้ถ้าจุดนั้นสั่นเองอยู่แล้ว
/// เครื่องตั้ง "ลดการเคลื่อนไหว" = โชว์เครื่องหมายเต็มทันที
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  /// วาดวงกลมรอบนอกด้วย — false = ขีดแค่เครื่องหมายถูก (วางในวงที่มีอยู่แล้ว)
  final bool ring;
  final bool haptic;
  final Duration duration;

  const AnimatedCheckmark({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 3,
    this.ring = true,
    this.haptic = false,
    this.duration = const Duration(milliseconds: 650),
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.haptic) {
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'สำเร็จ',
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _CheckmarkPainter(
            progress: _controller,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
            ring: widget.ring,
          ),
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;
  final double strokeWidth;
  final bool ring;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.ring,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // วงกลมกินครึ่งแรก เครื่องหมายถูกเริ่มก่อนวงปิดนิดหนึ่งให้ต่อเนื่อง
    final ringT = ring ? Curves.easeInOut.transform((t / 0.55).clamp(0, 1)) : 1.0;
    final checkStart = ring ? 0.45 : 0.0;
    final checkT = Curves.easeOutCubic.transform(
      ((t - checkStart) / (1 - checkStart)).clamp(0.0, 1.0),
    );

    final rect = Offset.zero & size;
    if (ring && ringT > 0) {
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        -1.5708, // เริ่มที่ 12 นาฬิกา
        6.28318 * ringT,
        false,
        paint,
      );
    }

    if (checkT <= 0) return;
    final w = size.width;
    final h = size.height;
    final check = Path()
      ..moveTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.44, h * 0.67)
      ..lineTo(w * 0.73, h * 0.36);
    for (final PathMetric metric in check.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * checkT), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.ring != ring ||
      old.progress != progress;
}
