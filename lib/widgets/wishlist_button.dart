import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/wishlist_provider.dart';
import '../theme/app_theme.dart';

class WishlistButton extends StatelessWidget {
  final Map<String, dynamic> trip;
  final double size;
  final bool dense;

  /// วางทับรูปปกบนการ์ดทริป — พื้นวงกลมดำโปร่งกับหัวใจขาว ให้เห็นชัดบนทุกรูป
  /// แทนพื้นสีการ์ดที่จะกลืนไปกับรูปสว่าง
  final bool onImage;

  const WishlistButton({
    super.key,
    required this.trip,
    this.size = 40,
    this.dense = false,
    this.onImage = false,
  });

  @override
  Widget build(BuildContext context) {
    final slug = trip['slug']?.toString() ?? '';
    if (slug.isEmpty) return const SizedBox.shrink();
    final wishlist = context.watch<WishlistProvider>();
    final favourite = wishlist.contains(slug);
    final iconSize = dense ? 18.0 : 22.0;

    return Semantics(
      button: true,
      label: favourite ? 'ลบออกจากรายการที่ชอบ' : 'บันทึกเป็นทริปที่ชอบ',
      toggled: favourite,
      child: Material(
      color: onImage
          ? Colors.black.withValues(alpha: 0.38)
          : favourite
          ? AppTheme.errorColor.withValues(alpha: 0.12)
          : AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size / 2),
        side: onImage
            ? BorderSide.none
            : BorderSide(
                color: favourite
                    ? AppTheme.errorColor.withValues(alpha: 0.32)
                    : AppTheme.border(context),
              ),
      ),
      child: InkWell(
        onTap: () async {
          // สั่นเบาๆ ทันทีที่กด ไม่รอ toggle — คู่กับหัวใจที่เด้งตอนเปลี่ยนเป็นทึบ
          if (!favourite) HapticFeedback.lightImpact();
          final added = await context.read<WishlistProvider>().toggle(trip);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                added ? 'บันทึกไว้ในรายการที่ชอบแล้ว' : 'นำออกจากรายการที่ชอบแล้ว',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: HeartBounce(
            favourite: favourite,
            size: iconSize,
            color: favourite
                ? AppTheme.errorColor
                : onImage
                ? Colors.white
                : AppTheme.mutedText(context),
          ),
        ),
      ),
    ),
    );
  }
}

/// ไอคอนหัวใจที่เด้ง 1 → 1.3 → 1 ตอนเพิ่งถูกกดถูกใจ และค่อยๆ เปลี่ยนสี
///
/// เด้งเฉพาะตอน [favourite] เปลี่ยนจาก false เป็น true ระหว่างที่อยู่บนจอ —
/// การ์ดที่เลื่อนเข้ามาโดยถูกใจไว้แล้วไม่เด้ง ตอนเอาออกแค่เปลี่ยนสีกลับเงียบๆ
class HeartBounce extends StatefulWidget {
  final bool favourite;
  final double size;
  final Color color;

  const HeartBounce({
    super.key,
    required this.favourite,
    required this.size,
    required this.color,
  });

  @override
  State<HeartBounce> createState() => _HeartBounceState();
}

class _HeartBounceState extends State<HeartBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.3, end: 1.0).chain(
        CurveTween(curve: Curves.elasticOut),
      ),
      weight: 65,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(HeartBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.favourite &&
        widget.favourite &&
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
    return ScaleTransition(
      scale: _scale,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: widget.color),
        duration: const Duration(milliseconds: 200),
        builder: (_, color, _) => Icon(
          widget.favourite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          size: widget.size,
          color: color,
        ),
      ),
    );
  }
}
