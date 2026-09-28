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

  /// ปี พ.ศ. ที่วิ่งรอบขอบเหรียญ — null = ไม่ใส่ปี (เช่น พรีวิวที่ยังไม่มีวันจบทริป)
  final int? year;

  const MedalArt({
    super.key,
    required this.design,
    required this.size,
    this.imageScale,
    this.year,
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
          errorBuilder: (_, _, _) =>
              _TemplateMedal(design: design, size: size, year: year),
          frameBuilder: (_, child, frame, sync) {
            if (sync || frame != null) return child;
            return _MedalSilhouette(size: size, color: design.color);
          },
        ),
      );
    }

    return _TemplateMedal(design: design, size: size, year: year);
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
      year: medal.buddhistYear,
      ornaments: false,
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
                  : MedalArt(
                      design: widget.medal.design,
                      size: widget.size,
                      year: widget.medal.buddhistYear,
                    ),
            );
          },
        ),
      ),
    );
  }
}

// ── รูปทรง ──────────────────────────────────────────────────────────────────
//
// ตัวเลขทั้งหมดคัดลอกจาก App\Support\MedalGeometry (PHP) — แหล่งเดียวที่เว็บ
// พรีวิวแอดมิน และภาพ OG ใช้ แก้ที่นั่นแล้วต้องแก้ที่นี่ด้วย ไม่งั้นเหรียญในแอป
// กับเหรียญที่คนเห็นตอนกดลิงก์จะหน้าตาไม่ตรงกัน
//
// หน่วยเป็นพิกัดบนผืน 100 × 118 จุดศูนย์กลางดวงอยู่ที่ (50, 68)

const double _cx = 50;
const double _cy = 68;
const double _rosetteR = 44;
const int _scallops = 28;
const double _scallopR = 5.6;
const double _bandR = 41;
const double _rimR = 35.5;
const double _discR = 34;
const double _ringTextR = 38.2;
const double _ringTextSize = 4.2;
const double _ribbonJoin = 40;
const double _iconY = 52;
const double _iconSize = 17;
const Rect _nameBox = Rect.fromLTWH(28, 62, 44, 15);
const double _nameSize = 5.6;
const double _bannerTextY = 87;
const double _bannerTextSize = 5;

const Color _goldDeep = Color(0xFFA87A2A);
const Color _ringInk = Color(0xFFFCE9C0);
const Color _laurel = Color(0xFFF2C66D);
const Color _bannerPaper = Color(0xFFFBF3E1);

/// ตัวอักษรที่วิ่งรอบขอบบน — ต้องตรงกับ MedalGeometry::ringText()
/// อังกฤษ+ตัวเลขเท่านั้น: วางทีละตัวแล้วสระไทยจะหลุดจากพยัญชนะ
String medalRingText(int? buddhistYear) => buddhistYear == null
    ? 'LUILAYKHAO  •  FINISHER'
    : 'LUILAYKHAO  •  FINISHER  •  $buddhistYear';

/// ใบไม้ของช่อ — ตรงกับ MedalGeometry::laurel()
final List<({Offset center, double rx, double ry, double angle})> _leaves = () {
  final leaves = <({Offset center, double rx, double ry, double angle})>[];
  const r = 30.0;
  const steps = 8;

  for (final side in [-1, 1]) {
    for (var i = 0; i <= steps; i++) {
      final deg = 118 + 94 * i / steps;
      final a = (side < 0 ? deg : 180 - deg) * math.pi / 180;
      final px = _cx + r * math.cos(a);
      final py = _cy + r * math.sin(a);
      final tx = side < 0 ? -math.sin(a) : math.sin(a);
      final ty = side < 0 ? math.cos(a) : -math.cos(a);
      final tangent = math.atan2(ty, tx);

      for (final fork in [-1, 1]) {
        if (i == steps && fork > 0) continue;

        final leafAngle = i == steps
            ? tangent
            : tangent + fork * 40 * math.pi / 180;
        leaves.add((
          center: Offset(
            px + 2.1 * math.cos(leafAngle),
            py + 2.1 * math.sin(leafAngle),
          ),
          rx: 3.2,
          ry: 1.35,
          angle: leafAngle,
        ));
      }
    }
  }

  return leaves;
}();

// ── ชิ้นส่วน ────────────────────────────────────────────────────────────────

class _TemplateMedal extends StatelessWidget {
  final MedalDesign design;
  final double size;
  final int? year;

  const _TemplateMedal({required this.design, required this.size, this.year});

  @override
  Widget build(BuildContext context) {
    final u = size / 100;

    return _MedalFrame(
      size: size,
      color: design.color,
      year: year,
      ornaments: true,
      overlays: [
        Positioned(
          left: 0,
          right: 0,
          top: (_iconY - _iconSize / 2) * u,
          height: _iconSize * u,
          child: Icon(
            medalIconFor(design.icon),
            size: _iconSize * u,
            color: Colors.white,
          ),
        ),
        Positioned(
          left: _nameBox.left * u,
          top: _nameBox.top * u,
          width: _nameBox.width * u,
          height: _nameBox.height * u,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: _nameBox.width * u,
                child: _MedalText(
                  design.name,
                  size: _nameSize * u,
                  maxLines: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ริบบิ้น + ขอบหยักทอง + แถบตัวอักษรวิ่ง + ดวงสี (+ ช่อใบไม้และแถบป้ายเมื่อ
/// [ornaments]) — โครงที่ด้านหน้าและด้านหลังใช้ร่วมกัน
///
/// [child] คือเนื้อหากลางดวงแบบกล่องเดียว (ด้านหลังใช้) ส่วน [overlays] คือชิ้น
/// ที่วางตามพิกัดเอง (ด้านหน้าใช้วางไอคอนกับชื่อ)
class _MedalFrame extends StatelessWidget {
  final double size;
  final Color color;
  final int? year;
  final bool ornaments;
  final Widget? child;
  final List<Widget> overlays;

  const _MedalFrame({
    required this.size,
    required this.color,
    required this.year,
    required this.ornaments,
    this.child,
    this.overlays = const [],
  });

  @override
  Widget build(BuildContext context) {
    final u = size / 100;
    final body = child;

    // ตัวหนังสือบนเหรียญอยู่ในวงกลมขนาดตายตัว — ปล่อยให้ขยายตามการตั้งค่า
    // ตัวอักษรของเครื่องจะล้นดวง จึงตรึงไว้ที่ 1 เท่าเฉพาะในเหรียญ
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: size,
        height: size * kMedalAspect,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MedalPainter(
                  color: color,
                  ringText: medalRingText(year),
                  ornaments: ornaments,
                ),
              ),
            ),
            if (body != null)
              Positioned(
                left: 22 * u,
                top: 42 * u,
                width: 56 * u,
                height: 52 * u,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(width: 56 * u, child: body),
                  ),
                ),
              ),
            ...overlays,
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
        height: 1.2,
      ),
    );
  }
}

/// วาดทุกชั้นของเหรียญแม่แบบที่ไม่ใช่ widget — ลำดับชั้นตรงกับ MedalGeometry
class _MedalPainter extends CustomPainter {
  final Color color;
  final String ringText;
  final bool ornaments;

  const _MedalPainter({
    required this.color,
    required this.ringText,
    required this.ornaments,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100;
    Offset p(double x, double y) => Offset(x * u, y * u);
    final center = p(_cx, _cy);

    // ริบบิ้น: แถบสีสองข้าง แต่ละข้างมีเส้นขาวสองเส้น
    final band = Paint()..color = Color.lerp(color, Colors.black, 0.25)!;
    final white = Paint()..color = Colors.white;

    for (final s in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(p(_cx + s * 50, 0).dx, 0)
          ..lineTo(p(_cx + s * 27, 0).dx, 0)
          ..lineTo(p(_cx - s * 4, _ribbonJoin).dx, _ribbonJoin * u)
          ..lineTo(p(_cx + s * 19, _ribbonJoin).dx, _ribbonJoin * u)
          ..close(),
        band,
      );

      for (final f in [1 / 3, 2 / 3]) {
        final top = 27 + 23 * f;
        final bottom = -4 + 23 * f;
        canvas.drawPath(
          Path()
            ..moveTo((_cx + s * (top - 1.1)) * u, 0)
            ..lineTo((_cx + s * (top + 1.1)) * u, 0)
            ..lineTo((_cx + s * (bottom + 1.1)) * u, _ribbonJoin * u)
            ..lineTo((_cx + s * (bottom - 1.1)) * u, _ribbonJoin * u)
            ..close(),
          white,
        );
      }
    }

    // ขอบหยักทอง = วงฐาน + วงเล็กรอบ ๆ
    final gold = Paint()..color = kMedalGold;
    canvas.drawCircle(center, _rosetteR * u, gold);
    for (var i = 0; i < _scallops; i++) {
      final a = 2 * math.pi * i / _scallops;
      canvas.drawCircle(
        p(_cx + _rosetteR * math.cos(a), _cy + _rosetteR * math.sin(a)),
        _scallopR * u,
        gold,
      );
    }

    canvas.drawCircle(center, _bandR * u, Paint()..color = _goldDeep);
    canvas.drawCircle(center, _rimR * u, gold);
    canvas.drawCircle(center, _discR * u, Paint()..color = color);

    _paintRingText(canvas, center, _ringTextR * u, _ringTextSize * u);

    if (!ornaments) return;

    final leaf = Paint()..color = _laurel;
    for (final l in _leaves) {
      canvas
        ..save()
        ..translate(l.center.dx * u, l.center.dy * u)
        ..rotate(l.angle)
        ..drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: l.rx * 2 * u,
            height: l.ry * 2 * u,
          ),
          leaf,
        )
        ..restore();
    }

    // แถบป้ายหางนกนางแอ่นพาดล่างดวง
    const banner = [
      14.0,
      82.0,
      86.0,
      82.0,
      82.0,
      87.0,
      86.0,
      92.0,
      14.0,
      92.0,
      18.0,
      87.0,
    ];
    final path = Path()..moveTo(banner[0] * u, banner[1] * u);
    for (var i = 2; i < banner.length; i += 2) {
      path.lineTo(banner[i] * u, banner[i + 1] * u);
    }
    canvas.drawPath(path..close(), Paint()..color = _bannerPaper);

    final label = TextPainter(
      text: TextSpan(
        text: 'FINISHER',
        style: appFont(
          fontSize: _bannerTextSize * u,
          fontWeight: FontWeight.w800,
          color: Color.lerp(color, Colors.black, 0.35),
          letterSpacing: 0.6 * u,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(_cx * u - label.width / 2, _bannerTextY * u - label.height / 2),
    );
    label.dispose();
  }

  /// ตัวอักษรวิ่งรอบขอบบน วางทีละตัวให้เอียงตามวง จัดกึ่งกลางที่จุดบนสุด
  void _paintRingText(
    Canvas canvas,
    Offset center,
    double radius,
    double fontSize,
  ) {
    final style = appFont(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: _ringInk,
    );
    final glyphs = [
      for (final ch in ringText.characters)
        TextPainter(
          text: TextSpan(text: ch, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final gap = fontSize * 0.18;
    final total =
        glyphs.fold<double>(0, (sum, g) => sum + g.width) +
        gap * (glyphs.length - 1);
    var angle = -math.pi / 2 - (total / radius) / 2;

    for (final glyph in glyphs) {
      final a = angle + (glyph.width / 2) / radius;
      canvas
        ..save()
        ..translate(
          center.dx + radius * math.cos(a),
          center.dy + radius * math.sin(a),
        )
        ..rotate(a + math.pi / 2);
      glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
      canvas.restore();
      angle += (glyph.width + gap) / radius;
      glyph.dispose();
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) =>
      old.color != color ||
      old.ringText != ringText ||
      old.ornaments != ornaments;
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
