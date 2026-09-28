/// ดวงเหรียญพิชิต — คู่แฝดของ partials/medal-art.blade.php (เว็บ) และ
/// MedalImageService (ภาพ OG) ทั้งสามที่ต้องหน้าตาเป็นเหรียญเดียวกัน
///
/// เหรียญแม่แบบ = ริบบิ้นตัว V + ขอบทอง + ดวงสีของทริป + ไอคอน + ชื่อ
/// ทริปที่มีภาพเหรียญออกแบบเอง ([MedalDesign.isCustom]) ใช้ภาพนั้นทั้งดวงแทน
///
/// แบนตามธีมของแอป: สีทึบล้วน ไม่มีเงา ไม่มีแสงวาว
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/trip_medal.dart';
import '../theme/app_theme.dart';

/// ทองของขอบเหรียญ — ตรงกับ #D9A441 ในเว็บและภาพ OG
const Color kMedalGold = Color(0xFFD9A441);

/// ความสูงของเหรียญทั้งดวง (รวมริบบิ้น) ต่อความกว้าง
const double kMedalAspect = 1.18;

/// ชื่อไอคอน (Material Symbols) จากเซิร์ฟเวอร์ → IconData
///
/// รายการต้องตรงกับ MedalDesign::ICONS — ชื่อที่ไม่รู้จัก (เซิร์ฟเวอร์ใหม่กว่า
/// แอป) ได้ภูเขาแทนที่จะว่าง
IconData medalIconFor(String name) {
  return switch (name) {
    'hiking' => Icons.hiking_rounded,
    'landscape' => Icons.landscape_rounded,
    'terrain' => Icons.terrain_rounded,
    'flag' => Icons.flag_rounded,
    'forest' => Icons.forest_rounded,
    'water' => Icons.water_rounded,
    'coffee' => Icons.coffee_rounded,
    'local_fire_department' => Icons.local_fire_department_rounded,
    'wb_sunny' => Icons.wb_sunny_rounded,
    'waves' => Icons.waves_rounded,
    'scuba_diving' => Icons.scuba_diving_rounded,
    'kayaking' => Icons.kayaking_rounded,
    'ac_unit' => Icons.ac_unit_rounded,
    'temple_buddhist' => Icons.temple_buddhist_rounded,
    _ => Icons.landscape_rounded,
  };
}

/// ภาพเหรียญออกแบบเองแบบย่อขนาดตอนถอดรหัส — PNG ต้นฉบับอาจใหญ่หลายพันพิกเซล
/// การถอดรหัสเต็มขนาดในตู้ที่มีหลายเหรียญคือทางลัดสู่ OOM
///
/// [scale] คือความละเอียดที่จะวาดจริง: จอปกติใช้ devicePixelRatio ส่วนการ์ดแชร์
/// ที่ถูกจับภาพ 3 เท่าต้องส่ง 3 มา และต้องใช้ตัวเดียวกันทั้งตอน precache และ
/// ตอนวาด ไม่งั้นแคชไม่ตรงกันแล้วภาพจะว่างใน PNG
ImageProvider medalImageProvider(
  String url,
  double logicalWidth,
  double scale,
) {
  final width = (logicalWidth * scale).round().clamp(64, 2048);

  return ResizeImage(NetworkImage(url), width: width, allowUpscaling: false);
}

/// ด้านหน้าของเหรียญ
class MedalArt extends StatelessWidget {
  final MedalDesign design;

  /// ความกว้างของดวงเหรียญ — ความสูงรวมคือ size × [kMedalAspect]
  final double size;

  /// ความละเอียดตอนถอดรหัสภาพออกแบบเอง (null = ตามจอ)
  final double? imageScale;

  const MedalArt({
    super.key,
    required this.design,
    required this.size,
    this.imageScale,
  });

  @override
  Widget build(BuildContext context) {
    final url = design.imageUrl;

    if (url != null && url.isNotEmpty) {
      final scale = imageScale ?? MediaQuery.devicePixelRatioOf(context);

      return SizedBox(
        width: size,
        height: size * kMedalAspect,
        child: Image(
          image: medalImageProvider(url, size, scale),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          // โหลดไม่ได้ (ออฟไลน์/ไฟล์หาย) — ยังมีเหรียญแม่แบบให้เห็น ไม่ใช่กรอบว่าง
          errorBuilder: (_, _, _) => _TemplateMedal(design: design, size: size),
          frameBuilder: (_, child, frame, sync) {
            if (sync || frame != null) return child;
            return _MedalSilhouette(size: size, color: design.color);
          },
        ),
      );
    }

    return _TemplateMedal(design: design, size: size);
  }
}

/// ด้านหลังของเหรียญ — ข้อมูลของคนที่พิชิต (ชื่อ เลข วันที่ สถิติ)
class MedalBack extends StatelessWidget {
  final TripMedal medal;
  final double size;

  const MedalBack({super.key, required this.medal, required this.size});

  @override
  Widget build(BuildContext context) {
    final stats = [
      if ((medal.distanceKm ?? 0) > 0) '${_trimNumber(medal.distanceKm!)} กม.',
      if ((medal.elevationGainM ?? 0) > 0)
        '+${_thousands(medal.elevationGainM!)} ม.',
    ].join('  ·  ');

    return _MedalFrame(
      size: size,
      color: medal.design.color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MedalText(
            'FINISHER',
            size: size * 0.05,
            spacing: size * 0.006,
            opacity: 0.85,
          ),
          SizedBox(height: size * 0.01),
          _MedalText('#${medal.finisherNo}', size: size * 0.16),
          SizedBox(height: size * 0.02),
          _MedalText(medal.holderName, size: size * 0.07, maxLines: 1),
          SizedBox(height: size * 0.012),
          _MedalText(
            medal.earnedLabel,
            size: size * 0.05,
            weight: FontWeight.w600,
            opacity: 0.85,
            maxLines: 1,
          ),
          if (stats.isNotEmpty) ...[
            SizedBox(height: size * 0.012),
            _MedalText(
              stats,
              size: size * 0.048,
              weight: FontWeight.w600,
              opacity: 0.85,
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }
}

/// เหรียญที่แตะแล้วพลิกดูด้านหลังได้
class MedalFlip extends StatefulWidget {
  final TripMedal medal;
  final double size;

  const MedalFlip({super.key, required this.medal, required this.size});

  @override
  State<MedalFlip> createState() => _MedalFlipState();
}

class _MedalFlipState extends State<MedalFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  late final Animation<double> _angle = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  ).drive(Tween(begin: 0.0, end: math.pi));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_controller.isAnimating) return;

    if (_controller.value >= 0.5) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'แตะเพื่อพลิกเหรียญ',
      child: GestureDetector(
        onTap: _flip,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _angle,
          builder: (context, _) {
            final angle = _angle.value;
            final showBack = angle > math.pi / 2;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: showBack
                  // ด้านหลังถูกหมุนกลับอีกครึ่งรอบ ไม่งั้นตัวหนังสือจะกลับด้าน
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: MedalBack(medal: widget.medal, size: widget.size),
                    )
                  : MedalArt(design: widget.medal.design, size: widget.size),
            );
          },
        ),
      ),
    );
  }
}

// ── ชิ้นส่วน ────────────────────────────────────────────────────────────────

class _TemplateMedal extends StatelessWidget {
  final MedalDesign design;
  final double size;

  const _TemplateMedal({required this.design, required this.size});

  @override
  Widget build(BuildContext context) {
    return _MedalFrame(
      size: size,
      color: design.color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            medalIconFor(design.icon),
            size: size * 0.28,
            color: Colors.white,
          ),
          SizedBox(height: size * 0.025),
          _MedalText(design.name, size: size * 0.075, maxLines: 2),
          SizedBox(height: size * 0.02),
          _MedalText(
            'FINISHER',
            size: size * 0.05,
            spacing: size * 0.006,
            opacity: 0.85,
          ),
        ],
      ),
    );
  }
}

/// ริบบิ้น + ขอบทอง + ดวงสี — โครงที่ทั้งด้านหน้าแม่แบบและด้านหลังใช้ร่วมกัน
class _MedalFrame extends StatelessWidget {
  final double size;
  final Color color;
  final Widget child;

  const _MedalFrame({
    required this.size,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final rim = size * 0.06;

    // ตัวหนังสือบนเหรียญอยู่ในวงกลมขนาดตายตัว — ปล่อยให้ขยายตามการตั้งค่า
    // ตัวอักษรของเครื่องจะล้นดวง จึงตรึงไว้ที่ 1 เท่าเฉพาะในเหรียญ
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: size,
        height: size * kMedalAspect,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _RibbonPainter(color: color)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size,
              child: Container(
                decoration: const BoxDecoration(
                  color: kMedalGold,
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(rim),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(size * 0.04),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: math.max(1.2, size * 0.01),
                      ),
                    ),
                    alignment: Alignment.center,
                    // ความกว้างตายตัวเท่าช่องกลางดวง ข้อความยาวจึงตัดบรรทัดที่ขอบ
                    // ช่องนี้ แล้ว FittedBox ค่อยย่อเฉพาะเมื่อสูงเกินดวง
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(width: size * 0.6, child: child),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// เงาของเหรียญระหว่างรอภาพออกแบบเองโหลด — ขนาดเท่าเหรียญจริง หน้าไม่กระตุก
class _MedalSilhouette extends StatelessWidget {
  final double size;
  final Color color;

  const _MedalSilhouette({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MedalText extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;
  final double opacity;
  final double spacing;
  final int maxLines;

  const _MedalText(
    this.text, {
    required this.size,
    this.weight = FontWeight.w800,
    this.opacity = 1,
    this.spacing = 0,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: appFont(
        fontSize: size,
        fontWeight: weight,
        color: Colors.white.withValues(alpha: opacity),
        letterSpacing: spacing,
        height: 1.25,
      ),
    );
  }
}

/// ริบบิ้นสองเส้นไขว้เป็นตัว V จากขอบบนลงหาเหรียญ — ปลายล่างจมใต้ขอบทอง
class _RibbonPainter extends CustomPainter {
  final Color color;

  const _RibbonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final join = size.height - w + w * 0.16;

    final band = Paint()..color = Color.lerp(color, Colors.black, 0.22)!;
    final stripe = Paint()..color = Colors.white;

    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(cx + side * w * 0.5, 0)
          ..lineTo(cx + side * w * 0.27, 0)
          ..lineTo(cx - side * w * 0.04, join)
          ..lineTo(cx + side * w * 0.19, join)
          ..close(),
        band,
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx + side * w * 0.405, 0)
          ..lineTo(cx + side * w * 0.365, 0)
          ..lineTo(cx + side * w * 0.055, join)
          ..lineTo(cx + side * w * 0.095, join)
          ..close(),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => oldDelegate.color != color;
}

String _trimNumber(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

String _thousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return buffer.toString();
}
