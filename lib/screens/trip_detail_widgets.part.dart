part of 'trip_detail_screen.dart';

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: AppTheme.cardDecoration(
        context,
        radius: 20,
        borderColor: AppTheme.border(context).withValues(alpha: 0.55),
        shadowOpacity: 0.04,
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // tonal icon plate — flatter and calmer than the previous gradient
        // chip, matching the iOS-style icon plates used elsewhere in the app.
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _softAccent.withValues(alpha: isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: _softAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : _premiumText,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: appFont(
                    fontSize: 12,
                    color: _mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Color iconColor;
  final Color iconBackground;

  const _FeatureRow({
    required this.icon,
    required this.title,
    this.description,
    this.iconColor = _softAccent,
    this.iconBackground = const Color(0xFFECFDF5),
  });

  @override
  Widget build(BuildContext context) {
    if (title.trim().isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark
                  ? iconColor.withValues(alpha: 0.15)
                  : iconBackground,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: appFont(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white.withValues(alpha: 0.9) : _premiumText,
                      height: 1.4,
                    ),
                  ),
                  if (description != null && description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: appFont(
                        fontSize: 13,
                        color: _mutedText,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? _softAccent.withValues(alpha: 0.15)
            : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _softAccent.withValues(alpha: isDark ? 0.25 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _softAccent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: 12,
                color: isDark ? _softAccent : const Color(0xFF047857),
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySelectionNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptySelectionNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.mutedText(context), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: appFont(
                color: AppTheme.mutedText(context),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;

  const _RatingSummary({required this.trip, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final rating = _ratingValue(trip);
    final count = _reviewCount(trip, reviews);

    if (rating <= 0 || count <= 0) {
      return Text(
        'ยังไม่มีรีวิว',
        style: appFont(
          color: _mutedText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return _RatingPill(trip: trip, reviews: reviews);
  }
}

class _RatingPill extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;

  const _RatingPill({required this.trip, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final rating = _ratingValue(trip);
    final count = _reviewCount(trip, reviews);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.warningTint(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFE8A117).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFE8A117)),
          const SizedBox(width: 4),
          Text(
            numberText(rating, fallback: '0'),
            style: appFont(
              color: AppTheme.onSurface(context),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count รีวิว',
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades + gently lifts its child into place the first time it scrolls into the
/// viewport, giving the long detail page a calm, premium cascade. Purely
/// visual (Opacity/translate don't change layout, so scroll math stays stable).
/// Reveals immediately when there's no enclosing scrollable, so content can
/// never get stuck hidden.
class _RevealOnScroll extends StatefulWidget {
  final Widget child;

  const _RevealOnScroll({required this.child});

  @override
  State<_RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<_RevealOnScroll> {
  bool _shown = false;
  ScrollPosition? _position;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _position = Scrollable.maybeOf(context)?.position;
      if (_position == null) {
        _reveal();
        return;
      }
      _position!.addListener(_check);
      _check();
    });
  }

  void _check() {
    if (_shown || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final dy = box.localToGlobal(Offset.zero).dy;
    // Reveal a little before the section's top edge reaches the bottom of the
    // screen, so it eases in rather than popping at the very edge.
    if (dy < MediaQuery.sizeOf(context).height * 0.92) _reveal();
  }

  void _reveal() {
    if (_shown || !mounted) return;
    setState(() => _shown = true);
    _position?.removeListener(_check);
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.04),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
