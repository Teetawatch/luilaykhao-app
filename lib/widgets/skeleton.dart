import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Shimmer block primitive — wrap any size to get a pulsing placeholder.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Shimmer.fromColors(
      baseColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06),
      highlightColor: isDark
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.black.withValues(alpha: 0.02),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Trip card skeleton — matches the rough silhouette of TripCard.
class TripCardSkeleton extends StatelessWidget {
  const TripCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SkeletonBox(
            width: 88,
            height: 88,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, width: 180),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: 120),
                SizedBox(height: 14),
                SkeletonBox(height: 12, width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A list of [count] trip-card skeletons for use in list/refresh placeholders.
class TripListSkeleton extends StatelessWidget {
  final int count;
  const TripListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => const TripCardSkeleton()),
    );
  }
}
