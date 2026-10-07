import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/curved_nav_shape.dart';

/// ส่วนนูนห่อปุ่ม QR: ขอบแถบต้องยกขึ้นห่อปุ่มทั้งลูกโดยเหลือพื้นแถบรอบปุ่ม
/// ทุกรอยต่อเนียน และรูปทรงไม่พังเมื่อแถบแคบเกิน
/// ขอบเขตจริงของเส้น — Path.getBounds() รวมจุดควบคุมของเส้นโค้งด้วย จึงกว้างเกินจริง
Rect tightBounds(Path path) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final metric in path.computeMetrics()) {
    for (var d = 0.0; d <= metric.length; d += 0.25) {
      final p = metric.getTangentForOffset(d)!.position;
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

void main() {
  // แถบเริ่มที่ y = 26 (เผื่อที่ให้ส่วนนูนด้านบน) ปุ่มรัศมี 28 อยู่ต่ำกว่าขอบแถบ 8
  const top = 26.0;
  const size = Size(375, 130);
  const cx = 187.5;
  const geometry = CurvedNavGeometry(
    centerX: cx,
    top: top,
    guestCenterY: 8,
    bumpRadius: 34,
    cornerRadius: 32,
  );
  final outline = geometry.outline(size);
  const buttonCenter = Offset(cx, top + 8);

  test('ส่วนนูนสูงพ้นขอบแถบพอดีกับพื้นที่ที่เผื่อไว้', () {
    expect(geometry.bumpHeight, 26);
    expect(tightBounds(outline).top, closeTo(0, 0.01));
    // ยอดส่วนนูนเป็นเนื้อแถบ เหนือขึ้นไปเป็นที่ว่าง
    expect(outline.contains(const Offset(cx, 2)), isTrue);
    expect(outline.contains(const Offset(cx, -1)), isFalse);
  });

  test('ปุ่มอยู่ในเนื้อแถบทั้งลูก เหลือพื้นแถบรอบปุ่มอย่างน้อย 5pt', () {
    for (var deg = 0; deg < 360; deg += 5) {
      final p =
          buttonCenter + Offset.fromDirection(deg * math.pi / 180, 28 + 5);
      expect(outline.contains(p), isTrue, reason: 'มุม $deg°');
    }
  });

  test('ข้างส่วนนูน เหนือขอบแถบเป็นที่ว่าง (แตะทะลุถึงเนื้อหา)', () {
    expect(outline.contains(const Offset(cx - 80, top - 2)), isFalse);
    expect(outline.contains(const Offset(cx + 80, top - 2)), isFalse);
    expect(outline.contains(const Offset(cx - 80, top + 2)), isTrue);
    expect(outline.contains(const Offset(60, top + 40)), isTrue);
  });

  test('จุดสัมผัสอยู่บนวงกลมด้านบน และเชิงโค้งต่อกับวงกลมเนียน', () {
    final t = geometry.leftTangent;
    expect(t.distance, closeTo(34, 1e-9));
    expect(t.dx, lessThan(0));
    expect(t.dy, lessThan(-geometry.guestCenterY), reason: 'สูงกว่าขอบแถบ');
    // เส้นเชิง (จากจุดควบคุมไปจุดสัมผัส) ตั้งฉากกับรัศมี = ต่อกันเนียน ไม่หัก
    final control = Offset(
      -(geometry.bumpRadius + geometry.shoulderInset),
      -geometry.guestCenterY,
    );
    final dir = t - control;
    expect(dir.dx * t.dx + dir.dy * t.dy, closeTo(0, 1e-6));
  });

  test('ปุ่มสูงกว่าขอบแถบ (จุดสัมผัสต่ำกว่าจุดศูนย์กลาง) ก็ยังห่อรอบปุ่ม', () {
    const raised = CurvedNavGeometry(
      centerX: cx,
      top: 50,
      guestCenterY: -10,
      bumpRadius: 34,
    );
    final path = raised.outline(const Size(375, 150));
    const c = Offset(cx, 40);
    for (var deg = 0; deg < 360; deg += 10) {
      final p = c + Offset.fromDirection(deg * math.pi / 180, 30);
      expect(path.contains(p), isTrue, reason: 'มุม $deg°');
    }
    expect(path.contains(const Offset(cx, 40 - 36)), isFalse);
  });

  test('แถบแคบเกินจะมีส่วนนูน — วาดขอบตรงแทน ไม่พัง', () {
    const narrow = CurvedNavGeometry(
      centerX: 60,
      top: 26,
      guestCenterY: 8,
      bumpRadius: 34,
      cornerRadius: 32,
    );
    final path = narrow.outline(const Size(120, 100));
    expect(path.contains(const Offset(60, 20)), isFalse);
    expect(path.contains(const Offset(60, 40)), isTrue);
    expect(path.getBounds().width, closeTo(120, 0.5));
  });

  test('มุมบนโค้งมน — มุมซ้าย/ขวาบนสุดของแถบไม่ใช่เนื้อแถบ', () {
    expect(outline.contains(const Offset(1, top + 1)), isFalse);
    expect(outline.contains(const Offset(374, top + 1)), isFalse);
    expect(outline.contains(const Offset(1, top + 60)), isTrue);
  });

  test('ขอบบนสำหรับวาดเส้นเริ่มและจบที่ปลายมุมโค้งสองข้าง', () {
    final edge = tightBounds(geometry.topEdge(size));
    expect(edge.left, closeTo(0, 0.5));
    expect(edge.right, closeTo(375, 0.5));
    expect(edge.top, closeTo(0, 0.5));
    expect(edge.bottom, closeTo(top + 32, 0.5));
  });
}
