import 'package:flutter/material.dart';

/// [IndexedStack] ที่หน้าใหม่จางขึ้นพร้อมขยายจาก 98% ตอนสลับแท็บ (แบบ
/// fade-through ของ Material) แทนการตัดภาพ
///
/// ยังเป็น IndexedStack ตัวเดิม — ทุกแท็บอยู่ในต้นไม้ตลอด ตำแหน่ง scroll,
/// ข้อมูลที่โหลดไว้ และ state อื่นของแต่ละแท็บจึงไม่หาย แค่ห่อชั้นนอกด้วย
/// opacity/scale ที่ขยับเฉพาะตอน index เปลี่ยน
class FadeThroughIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const FadeThroughIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<FadeThroughIndexedStack> createState() =>
      _FadeThroughIndexedStackState();
}

class _FadeThroughIndexedStackState extends State<FadeThroughIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.98,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void didUpdateWidget(FadeThroughIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index &&
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
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}
