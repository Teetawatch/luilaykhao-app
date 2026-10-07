import 'dart:math' as math;

import 'package:flutter/material.dart';

/// รูปทรงแถบเมนูล่างที่ขอบบน "นูนโค้งขึ้น" ตรงกลาง ห่อปุ่มกลม (ปุ่ม QR เช็คอิน)
/// ไว้ในตัวแถบ — ปุ่มอยู่บนพื้นแถบทั้งลูก ไม่มีช่องโปร่งให้เห็นเนื้อหาด้านหลัง
///
/// ขอบบนวิ่งตรง แล้วเชิดขึ้นด้วยเส้นโค้ง quadratic ที่ "สัมผัส" วงกลมพอดี ไล่ตาม
/// วงกลมข้ามด้านบนของปุ่ม แล้วลาดลงแบบสมมาตร — ทุกรอยต่อเนียน ไม่มีมุมหัก
/// มุมบนซ้าย/ขวาของแถบโค้งมน
///
/// พิกัด y วัดจากกรอบที่วาด: [top] คือแนวขอบบนของแถบ ส่วนนูนยื่นสูงกว่านั้น
/// (y น้อยกว่า [top]) จึงต้องวาดในกรอบที่เผื่อพื้นที่ด้านบนไว้อย่างน้อย
/// [bumpHeight]
class CurvedNavGeometry {
  /// จุดกึ่งกลางแนวนอนของส่วนนูน (ตรงกับจุดกึ่งกลางปุ่ม)
  final double centerX;

  /// แนวขอบบนของแถบภายในกรอบที่วาด
  final double top;

  /// จุดกึ่งกลางของปุ่มวัดลงจากขอบบนของแถบ (บวก = ต่ำกว่าขอบ)
  final double guestCenterY;

  /// รัศมีของส่วนนูน = รัศมีปุ่ม + ระยะขอบพื้นแถบรอบปุ่ม
  final double bumpRadius;

  /// มุมโค้งบนซ้าย/ขวาของแถบ
  final double cornerRadius;

  /// ระยะจากขอบวงกลมไปถึงจุดควบคุมของเส้นโค้งเชิง — ยิ่งมากเชิงยิ่งลาด
  final double shoulderInset;

  /// ความยาวช่วงที่ค่อย ๆ เชิดขึ้นก่อนถึงจุดควบคุม
  final double shoulderRun;

  const CurvedNavGeometry({
    required this.centerX,
    required this.guestCenterY,
    required this.bumpRadius,
    this.top = 0,
    this.cornerRadius = 0,
    this.shoulderInset = 10,
    this.shoulderRun = 18,
  });

  /// ครึ่งความกว้างของฐานส่วนนูน วัดจากจุดกึ่งกลาง
  double get halfWidth => bumpRadius + shoulderInset + shoulderRun;

  /// ส่วนนูนสูงพ้นขอบบนของแถบเท่าไร
  double get bumpHeight => bumpRadius - guestCenterY;

  /// จุดที่เส้นโค้งเชิง (ฝั่งซ้าย) ไปสัมผัสวงกลม — สัมพัทธ์กับจุดกึ่งกลางวงกลม
  ///
  /// เส้นสัมผัสจากจุด P(a, b) ภายนอกวงกลมรัศมี r: T = (r²/d²)·P ± (r·√(d²−r²)/d²)·P⊥
  /// เลือกจุดที่ y น้อยกว่า (ฝั่งบน) เพราะเส้นเชิดขึ้นไปต่อกับวงกลมด้านบนของปุ่ม
  Offset get leftTangent {
    final r = bumpRadius;
    final a = -(r + shoulderInset);
    final b = -guestCenterY;
    final d2 = a * a + b * b;
    final k1 = r * r / d2;
    final k2 = r * math.sqrt(math.max(0, d2 - r * r)) / d2;
    final t1 = Offset(k1 * a + k2 * -b, k1 * b + k2 * a);
    final t2 = Offset(k1 * a - k2 * -b, k1 * b - k2 * a);
    return t1.dy <= t2.dy ? t1 : t2;
  }

  /// เส้นรอบรูปปิดของแถบทั้งแผ่น ใช้ทั้งตัดขอบ (clip) และวาดเงา
  Path outline(Size size) {
    final path = Path()..moveTo(0, size.height);
    _traceTop(path, size, startAtCorner: false);
    path
      ..lineTo(size.width, size.height)
      ..close();
    return path;
  }

  /// เฉพาะขอบบน (รวมมุมโค้งสองข้างและส่วนนูน) — ใช้วาดเส้นขอบบาง ๆ
  Path topEdge(Size size) {
    final path = Path();
    _traceTop(path, size, startAtCorner: true);
    return path;
  }

  void _traceTop(Path path, Size size, {required bool startAtCorner}) {
    final w = size.width;
    final rc = math.min(
      cornerRadius,
      math.min(w / 2, math.max(0.0, size.height - top)),
    );
    if (startAtCorner) {
      path.moveTo(0, top + rc);
    } else {
      path.lineTo(0, top + rc);
    }
    if (rc > 0) {
      path.arcToPoint(Offset(rc, top), radius: Radius.circular(rc));
    }

    // แถบแคบเกินกว่าจะมีส่วนนูน (ไม่ควรเกิดบนมือถือจริง) — วาดขอบตรงไปเลย
    // ดีกว่าให้เส้นตัดกันเองจนรูปทรงพัง
    final cx = centerX;
    final hasBump = cx - halfWidth >= rc && cx + halfWidth <= w - rc;
    if (hasBump) {
      final c = Offset(cx, top + guestCenterY);
      final a = -(bumpRadius + shoulderInset);
      final b = -guestCenterY;
      final t = leftTangent;
      final p0 = c + Offset(a - shoulderRun, b);
      final p1 = c + Offset(a, b);
      final p2 = c + t;
      final p3 = c + Offset(-t.dx, t.dy);
      final p4 = c + Offset(-a, b);
      final p5 = c + Offset(-a + shoulderRun, b);
      path
        ..lineTo(p0.dx, p0.dy)
        ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy)
        // ไล่วงกลมข้าม "ด้านบน" ของปุ่ม: บนจอ (y ชี้ลง) จากซ้ายขึ้นบนไปขวา
        // = ตามเข็ม ถ้าจุดสัมผัสอยู่ต่ำกว่าจุดกึ่งกลางวงกลม ส่วนโค้งจะเกินครึ่งวง
        ..arcToPoint(
          p3,
          radius: Radius.circular(bumpRadius),
          largeArc: t.dy > 0,
        )
        ..quadraticBezierTo(p4.dx, p4.dy, p5.dx, p5.dy);
    }

    path.lineTo(w - rc, top);
    if (rc > 0) {
      path.arcToPoint(Offset(w, top + rc), radius: Radius.circular(rc));
    }
  }
}

/// ตัดพื้นหลังของแถบให้เป็นรูปทรงมีส่วนนูน — การแตะนอกรูปทรง (แถบโปร่งใส
/// ข้างส่วนนูน) จึงทะลุลงไปถึงเนื้อหาด้านหลังด้วย
class CurvedNavClipper extends CustomClipper<Path> {
  final CurvedNavGeometry Function(Size size) geometryFor;

  const CurvedNavClipper(this.geometryFor);

  @override
  Path getClip(Size size) => geometryFor(size).outline(size);

  // geometryFor ขึ้นกับขนาดเท่านั้น และ CustomClipper คำนวณใหม่เองเมื่อขนาดเปลี่ยน
  @override
  bool shouldReclip(CurvedNavClipper oldClipper) => false;
}

/// วาดเงาบาง ๆ ใต้รูปทรง (อยู่ "นอก" clip ไม่งั้นเงาถูกตัดทิ้ง)
class CurvedNavShadowPainter extends CustomPainter {
  final CurvedNavGeometry geometry;
  final BoxShadow shadow;

  const CurvedNavShadowPainter({required this.geometry, required this.shadow});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      geometry.outline(size).shift(shadow.offset),
      shadow.toPaint(),
    );
  }

  // ค่าเริ่มต้นของ CustomPaint ที่มี painter คือ "รับการแตะทั้งกรอบ" ซึ่งรวมแถบ
  // โปร่งใสข้างส่วนนูนด้วย — ปล่อยให้พื้นหลังที่ clip ตามรูปทรงเป็นตัวตัดสินแทน
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(CurvedNavShadowPainter old) =>
      old.shadow != shadow || old.geometry.centerX != geometry.centerX;
}

/// เส้นขอบบนบาง ๆ ที่วิ่งตามส่วนนูน (แทน Border(top:) ของแถบตรงแบบเดิม)
class CurvedNavBorderPainter extends CustomPainter {
  final CurvedNavGeometry geometry;
  final Color color;
  final double width;

  const CurvedNavBorderPainter({
    required this.geometry,
    required this.color,
    this.width = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      geometry.topEdge(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(CurvedNavBorderPainter old) =>
      old.color != color ||
      old.width != width ||
      old.geometry.centerX != geometry.centerX;
}
