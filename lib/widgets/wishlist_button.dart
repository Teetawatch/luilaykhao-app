import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wishlist_provider.dart';
import '../theme/app_theme.dart';

class WishlistButton extends StatelessWidget {
  final Map<String, dynamic> trip;
  final double size;
  final bool dense;

  const WishlistButton({
    super.key,
    required this.trip,
    this.size = 40,
    this.dense = false,
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
      color: favourite
          ? AppTheme.errorColor.withValues(alpha: 0.12)
          : AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size / 2),
        side: BorderSide(
          color: favourite
              ? AppTheme.errorColor.withValues(alpha: 0.32)
              : AppTheme.border(context),
        ),
      ),
      child: InkWell(
        onTap: () async {
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
          child: Icon(
            favourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: iconSize,
            color: favourite
                ? AppTheme.errorColor
                : AppTheme.mutedText(context),
          ),
        ),
      ),
    ),
    );
  }
}
