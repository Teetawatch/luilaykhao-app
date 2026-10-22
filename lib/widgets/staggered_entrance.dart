import 'dart:async';

import 'package:flutter/material.dart';

/// ช่วง "โหลดครั้งแรก" ของรายการหนึ่งหน้า — เปิดอยู่แค่เฟรมแรกที่หน้าถามหามัน
/// (คือเฟรมที่เนื้อหาจริงโผล่) แล้วปิดถาวร
///
/// การ์ดที่ถูกสร้างในเฟรมนั้นได้ไล่กันเข้ามา ([StaggeredEntrance]) ส่วนที่ถูกสร้าง
/// ทีหลังจากการเลื่อนลงไป, สลับตัวกรอง หรือโหลดหน้าถัดไป โผล่ตามปกติ
/// วัดเป็นเฟรม ไม่ใช่เวลา — ลิสต์แบบ lazy สร้างเฉพาะการ์ดที่เห็นในเฟรมแรกพอดี
///
/// ถามเฉพาะในทางที่วาดเนื้อหาจริง ไม่ใช่ทางโครงร่าง ไม่งั้นหน้าต่างจะปิดไปก่อน
/// ข้อมูลมาถึง
class EntranceWindow {
  bool _scheduled = false;
  bool _closed = false;

  bool get isOpen {
    if (_closed) return false;
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _closed = true);
    }
    return true;
  }
}

/// การ์ดในรายการที่ลอยขึ้นพร้อมจางเข้า ช้ากว่าใบก่อนหน้าทีละ [step]
///
/// [animate] ถูกอ่านแค่ตอนสร้าง (มักมาจาก [EntranceWindow.isOpen]) — สร้างมา
/// ด้วย false คืน [child] ตรงๆ ไม่มีชั้นเพิ่ม
///
/// แท็บล่างอยู่ใน IndexedStack ซึ่งสร้างทุกแท็บตั้งแต่เปิดแอป การ์ดของแท็บที่ยัง
/// ไม่ถูกเปิดจึงรอจน [Visibility.of] บอกว่าเห็นแล้วค่อยเริ่มไล่ ไม่งั้นจะเล่น
/// จบไปตอนผู้ใช้ยังอยู่หน้าแรก
class StaggeredEntrance extends StatefulWidget {
  final int index;
  final bool animate;
  final Widget child;
  final Duration step;

  /// ใบที่เกินนี้เริ่มพร้อมใบสุดท้าย — รายการยาวไม่ต้องรอนาน
  final int maxSteps;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.animate,
    required this.child,
    this.step = const Duration(milliseconds: 45),
    this.maxSteps = 8,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final Animation<double> _curve;
  Timer? _delay;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (!widget.animate) return;
    final controller = _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _curve = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = _controller;
    if (controller == null || _started) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _started = true;
      controller.value = 1;
      return;
    }
    // ลงทะเบียนพึ่ง Visibility ไว้ด้วย — พอแท็บถูกเปิด เมธอดนี้จะถูกเรียกอีกครั้ง
    if (!Visibility.of(context)) return;
    _started = true;
    final steps = widget.index.clamp(0, widget.maxSteps);
    _delay = Timer(widget.step * steps, () {
      if (mounted) controller.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 16 * (1 - _curve.value)),
        child: Opacity(opacity: _curve.value, child: child),
      ),
      child: widget.child,
    );
  }
}
