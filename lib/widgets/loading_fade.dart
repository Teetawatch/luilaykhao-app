import 'package:flutter/material.dart';

/// เปลี่ยนจากโครงร่าง (skeleton) เป็นเนื้อหาจริงแบบค่อยๆ จางขึ้น แทนการตัดภาพ
///
/// [child] คือสิ่งที่หน้าวาดอยู่แล้วทั้งตอนโหลดและตอนเสร็จ (เช่น `_buildBody()`
/// ที่คืนโครงร่างเองตอน `_loading`) — ห่อทั้งก้อนได้เลยโดยไม่ต้องแยกสองฝั่ง
/// ส่ง [loading] เป็นเงื่อนไขเดียวกับที่หน้าใช้เลือกโครงร่าง
///
/// จางทางเดียว เฉพาะตอน [loading] เปลี่ยนจาก true เป็น false: เนื้อหาจางขึ้น
/// พร้อมลอยขึ้นนิดหนึ่ง ไม่ครอสเฟดกับโครงร่างเดิม เพราะการคงของเก่าไว้ในต้นไม้
/// ระหว่างจาง จะทำให้ ScrollController / GlobalKey ของหน้าถูกผูกสองที่พร้อมกัน
/// ตอนเลือกระหว่างเนื้อหาชุดเก่ากับชุดใหม่ กลับไปโหลดใหม่ (ดึงรีเฟรช) จึงตัดเป็น
/// โครงร่างทันทีเหมือนเดิม และหน้าที่มีข้อมูลอยู่แล้วตั้งแต่แรกจะไม่จางเลย
///
/// โครงต้นไม้คงที่ตลอด (มีแค่ค่า opacity/offset ที่ขยับ) — state ของเนื้อหาจึง
/// ไม่ถูกสร้างใหม่ตอนจางเสร็จ และปิดเองเมื่อเครื่องตั้ง "ลดการเคลื่อนไหว"
///
/// [LoadingFade.sliver] สำหรับหน้าที่เป็น CustomScrollView — [child] เป็น sliver
/// และจางอย่างเดียว (sliver เลื่อนตำแหน่งด้วย transform ไม่ได้)
class LoadingFade extends StatefulWidget {
  final bool loading;
  final Widget child;
  final Duration duration;

  /// ระยะที่เนื้อหาลอยขึ้นมาระหว่างจาง — 0 = จางอย่างเดียว
  final double rise;

  final bool _sliver;

  const LoadingFade({
    super.key,
    required this.loading,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
    this.rise = 8,
  }) : _sliver = false;

  const LoadingFade.sliver({
    super.key,
    required this.loading,
    required Widget sliver,
    this.duration = const Duration(milliseconds: 260),
  }) : child = sliver,
       rise = 0,
       _sliver = true;

  @override
  State<LoadingFade> createState() => _LoadingFadeState();
}

class _LoadingFadeState extends State<LoadingFade>
    with SingleTickerProviderStateMixin {
  // เริ่มที่ 1 = เห็นเต็ม: หน้าที่ไม่เคยโหลด (มีแคช) ไม่ต้องจาง
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(LoadingFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.loading) {
      _controller.value = 1;
    } else if (oldWidget.loading &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget._sliver) {
      return SliverFadeTransition(opacity: _curve, sliver: widget.child);
    }
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, widget.rise * (1 - _curve.value)),
        child: Opacity(opacity: _curve.value, child: child),
      ),
      child: widget.child,
    );
  }
}
