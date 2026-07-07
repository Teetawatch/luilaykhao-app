import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';

final _moneyFormat = NumberFormat.currency(locale: 'th_TH', symbol: '฿');

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}

String textOf(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String money(dynamic value) {
  final number = num.tryParse(value?.toString() ?? '');
  if (number == null) return _moneyFormat.format(0);
  return _moneyFormat.format(number);
}

String numberText(dynamic value, {String fallback = '0'}) {
  final number = num.tryParse(value?.toString() ?? '');
  if (number == null) return fallback;
  return number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 1);
}

String dateText(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '-';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  return thaiDateShort(date);
}

/// วัน-เวลาออกรถจริงของรอบเดินทาง (departs_at) — อาจอยู่ก่อนวันทริป เช่น
/// ทริปวันเสาร์ที่ 13 แต่รถออกคืนวันศุกร์ที่ 12 เวลา 23:30
/// ค่าจาก API เป็นเวลาท้องถิ่นไทยแบบไม่มี timezone จึง parse ตรง ๆ ได้เลย
DateTime? scheduleDepartsAt(Map<String, dynamic> schedule) {
  final raw = schedule['departs_at']?.toString() ?? '';
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

/// ข้อความวันออกเดินทางของรอบ — ถ้ารอบกำหนดเวลาออกรถจริงไว้ จะแสดง
/// วัน+เวลาออกรถ (เช่น "12 มิ.ย. 2026 23:30 น.") ไม่งั้นแสดงเฉพาะวันทริป
String departureText(Map<String, dynamic> schedule) {
  final departsAt = scheduleDepartsAt(schedule);
  if (departsAt != null) {
    final datePart = thaiDateShort(departsAt);
    final timePart = DateFormat('HH:mm').format(departsAt);
    return '$datePart $timePart น.';
  }
  return dateText(schedule['departure_date']);
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1A1C1C),
      ),
    );
  }
}

class TravelChip extends StatelessWidget {
  final String text;
  const TravelChip(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        text,
        style: appFont(
          fontSize: 12,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class BulletPoint extends StatelessWidget {
  final String text;
  const BulletPoint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppTheme.accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: appFont(color: const Color(0xFF414755)),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 56,
            color: const Color(0xFF414755).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: appFont(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: const Color(0xFF1A1C1C),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: appFont(color: const Color(0xFF414755)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class Skeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const Skeleton({super.key, this.width, this.height, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class PrimaryCTAButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final Color? color;

  const PrimaryCTAButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 56,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: onPressed != null
            ? LinearGradient(
                colors: [
                  color ?? AppTheme.primaryColor,
                  (color ?? AppTheme.primaryColor).withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: onPressed == null ? Colors.grey[300] : null,
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: (color ?? AppTheme.primaryColor).withValues(
                    alpha: 0.3,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: appFont(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double radius;
  final Color color;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.1,
    this.radius = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class TravelSliverAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool isTransparent;

  const TravelSliverAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.isTransparent = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      pinned: true,
      // This bar manages its own leading via [showBackButton]; never let the
      // SliverAppBar auto-inject a back button (which would appear on a tab
      // root the moment a detail page is pushed over it on the root navigator).
      automaticallyImplyLeading: false,
      backgroundColor: isTransparent
          ? Colors.transparent
          : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Text(
        title,
        style: appFont(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      leading: showBackButton && Navigator.canPop(context)
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: isTransparent
                    ? Colors.black26
                    : Colors.transparent,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: isTransparent
                        ? Colors.white
                        : isDark
                        ? colorScheme.onSurface
                        : AppTheme.textMain,
                    size: 19,
                  ),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            )
          : null,
      actions: actions,
    );
  }
}

/// iOS-style large title navigation bar that collapses to an inline centered
/// title on scroll, over a frosted background with a hairline that fades in.
/// Place directly inside a [CustomScrollView]'s `slivers` list.
class LargeTitleSliverHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? subtitleColor;

  /// Trailing action shown in the collapsed bar (e.g. a text button).
  final Widget? trailing;

  const LargeTitleSliverHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _LargeTitleHeaderDelegate(
        topPadding: MediaQuery.paddingOf(context).top,
        title: title,
        subtitle: subtitle,
        subtitleColor: subtitleColor,
        trailing: trailing,
      ),
    );
  }
}

class _LargeTitleHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;

  _LargeTitleHeaderDelegate({
    required this.topPadding,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.trailing,
  });

  static const double _bar = 52;
  static const double _largeTitle = 72;

  @override
  double get minExtent => topPadding + _bar;

  @override
  double get maxExtent => topPadding + _bar + _largeTitle;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / _largeTitle).clamp(0.0, 1.0);
    final onSurface = AppTheme.onSurface(context);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.background(context),
          border: Border(
            bottom: BorderSide(
              color: AppTheme.border(context).withValues(alpha: 0.55 * t),
              width: 0.5,
            ),
          ),
        ),
        padding: EdgeInsets.only(top: topPadding),
        child: Stack(
          children: [
            // Collapsed bar: back button + (fading-in) centered title + action.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _bar,
              child: Row(
                children: [
                  _LargeTitleBackButton(color: onSurface),
                  Expanded(
                    child: Opacity(
                      opacity: t,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: onSurface,
                        ),
                      ),
                    ),
                  ),
                  trailing ?? const SizedBox(width: 12),
                ],
              ),
            ),
            // Large title that fades and lifts away as the bar collapses.
            Positioned(
              left: 20,
              right: 20,
              top: _bar - (8 * t),
              child: Opacity(
                opacity: (1 - t * 1.4).clamp(0.0, 1.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor ?? AppTheme.mutedText(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_LargeTitleHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.subtitle != subtitle ||
        oldDelegate.subtitleColor != subtitleColor ||
        oldDelegate.trailing != trailing ||
        oldDelegate.topPadding != topPadding;
  }
}

class _LargeTitleBackButton extends StatelessWidget {
  final Color color;

  const _LargeTitleBackButton({required this.color});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.canPop(context)) return const SizedBox(width: 12);
    return IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        Navigator.maybePop(context);
      },
      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: color),
      splashRadius: 22,
    );
  }
}
