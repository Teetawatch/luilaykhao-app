import 'package:flutter/material.dart';

/// ข้อความที่เพิ่งเข้ามาในห้องแชท (ส่งเอง/มาทาง socket/poll) เลื่อนขึ้นพร้อม
/// จางเข้า สติกเกอร์เด้งขยายจากมุมฝั่งคนส่งแทน
///
/// [animate] ถูกอ่านแค่ตอนสร้าง — ห้องตัดสินว่าข้อความไหน "ใหม่" แล้วส่ง true
/// ครั้งเดียว build ถัดไปส่ง false ได้โดยไม่ตัดอนิเมชันที่กำลังเล่น และตัวที่
/// สร้างมาด้วย false (ประวัติแชท) คืน [child] ตรงๆ ไม่มีชั้น opacity/transform
/// เพิ่มให้ทุกบับเบิลในห้อง
class ChatBubbleEntrance extends StatefulWidget {
  final bool animate;
  final bool sticker;

  /// ข้อความของเรา (ชิดขวา) — สติกเกอร์ขยายจากมุมล่างขวา ของคนอื่นจากล่างซ้าย
  final bool isMine;
  final Widget child;

  const ChatBubbleEntrance({
    super.key,
    required this.animate,
    required this.child,
    this.sticker = false,
    this.isMine = false,
  });

  @override
  State<ChatBubbleEntrance> createState() => _ChatBubbleEntranceState();
}

class _ChatBubbleEntranceState extends State<ChatBubbleEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final Animation<double> _curve;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    if (!widget.animate) return;
    final controller = _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.sticker ? 420 : 240),
    )..forward();
    _curve = CurvedAnimation(
      parent: controller,
      curve: widget.sticker ? Curves.easeOutBack : Curves.easeOutCubic,
    );
    _fade = widget.sticker
        ? CurvedAnimation(parent: controller, curve: const Interval(0, 0.4))
        : _curve;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller?.value = 1;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;

    return AnimatedBuilder(
      animation: _curve,
      builder: (_, child) {
        // easeOutBack เกิน 1 เล็กน้อย = สติกเกอร์เด้งเลยขนาดจริงแล้วหดกลับ
        final t = _curve.value;
        final opacity = _fade.value.clamp(0.0, 1.0);
        return widget.sticker
            ? Transform.scale(
                scale: 0.6 + 0.4 * t,
                alignment: widget.isMine
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: Opacity(opacity: opacity, child: child),
              )
            : Transform.translate(
                offset: Offset(0, 14 * (1 - t)),
                child: Opacity(opacity: opacity, child: child),
              );
      },
      child: widget.child,
    );
  }
}
