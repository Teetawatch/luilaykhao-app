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
          borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusSm),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border(context)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SkeletonBox(
            width: 88,
            height: 88,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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

/// A single line of placeholder text. [widthFactor] varies the run length so a
/// stack of these reads as prose rather than as a bar chart.
class SkeletonLine extends StatelessWidget {
  final double widthFactor;
  final double height;

  const SkeletonLine({super.key, this.widthFactor = 1, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: SkeletonBox(
        height: height,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
    );
  }
}

/// Avatar + two lines — the silhouette shared by the chat list, the
/// notification list and the staff roster.
class SkeletonListTile extends StatelessWidget {
  final bool showTrailing;

  const SkeletonListTile({super.key, this.showTrailing = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SkeletonBox(
            width: 44,
            height: 44,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(widthFactor: 0.45, height: 13),
                SizedBox(height: 8),
                SkeletonLine(widthFactor: 0.8, height: 11),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 12),
            const SkeletonLine(widthFactor: 1, height: 11),
          ],
        ],
      ),
    );
  }
}

/// [count] repeats of [item], for a list that is still loading its first page.
class SkeletonList extends StatelessWidget {
  final int count;
  final Widget item;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.count = 6,
    this.item = const SkeletonListTile(),
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      // ตัวนี้ไม่ได้เลื่อนเอง มันไปนั่งอยู่ในของที่เลื่อนอยู่แล้วเสมอ — และหลายที่
      // เป็น SliverToBoxAdapter ซึ่งให้ความสูงมาแบบไม่จำกัด ถ้าไม่ shrinkWrap
      // ListView จะพยายามขยายเต็มพื้นที่ที่ไม่มีที่สิ้นสุดแล้วโยน "Vertical
      // viewport was given unbounded height" ทิ้ง ผลคือช่วงกำลังโหลดว่างเปล่า
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(count, (_) => item),
    );
  }
}

/// Hero image, title, meta row and a paragraph — the first paint of a detail
/// screen. Shows the page's real shape while the request is in flight, which
/// reads as faster than a spinner even at identical latency.
class SkeletonDetail extends StatelessWidget {
  final bool showHero;

  const SkeletonDetail({super.key, this.showHero = true});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        if (showHero) ...[
          SkeletonBox(
            height: 180,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          const SizedBox(height: 20),
        ],
        const SkeletonLine(widthFactor: 0.7, height: 20),
        const SizedBox(height: 12),
        const SkeletonLine(widthFactor: 0.4, height: 13),
        const SizedBox(height: 24),
        const SkeletonLine(height: 12),
        const SizedBox(height: 10),
        const SkeletonLine(widthFactor: 0.95, height: 12),
        const SizedBox(height: 10),
        const SkeletonLine(widthFactor: 0.6, height: 12),
        const SizedBox(height: 28),
        SkeletonBox(
          height: 96,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        const SizedBox(height: 14),
        SkeletonBox(
          height: 96,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ],
    );
  }
}
