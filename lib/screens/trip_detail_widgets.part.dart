part of 'trip_detail_screen.dart';

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: AppTheme.cardDecoration(
        context,
        radius: 32,
        borderColor: AppTheme.border(context).withValues(alpha: 0.7),
        shadowOpacity: 0.045,
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
        // colored icon box
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF059669), Color(0xFF10B981)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _softAccent.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : _premiumText,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.anuphan(
                    fontSize: 12,
                    color: _mutedText,
                    fontWeight: FontWeight.w600,
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
                    style: GoogleFonts.anuphan(
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
                      style: GoogleFonts.anuphan(
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
              style: GoogleFonts.anuphan(
                fontSize: 12,
                color: isDark ? _softAccent : const Color(0xFF047857),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDropdownRow extends StatelessWidget {
  final String step;
  final String label;
  final Widget child;

  const _StepDropdownRow({
    required this.step,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // step badge
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: _softAccent.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                step,
                style: GoogleFonts.anuphan(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Text(
                  label,
                  style: GoogleFonts.anuphan(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? _mutedText : const Color(0xFF64748B),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _PremiumDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppTheme.border(context)
              : const Color(0xFFD1FAE5),
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _softAccent,
            size: 20,
          ),
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
            prefixIcon: Icon(icon, color: _softAccent, size: 19),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            labelStyle: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          style: GoogleFonts.anuphan(
            color: AppTheme.onSurface(context),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DropdownText extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DropdownText({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.anuphan(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _premiumText,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _mutedText,
            ),
          ),
      ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.mutedText(context), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.anuphan(
                color: AppTheme.mutedText(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryBadge extends StatelessWidget {
  final int currentIndex;
  final int count;

  const _GalleryBadge({required this.currentIndex, required this.count});

  @override
  Widget build(BuildContext context) {
    final current = (currentIndex + 1).clamp(1, count);

    return Semantics(
      label: 'รูปภาพที่ $current จาก $count',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    '$current / $count',
                    key: ValueKey<int>(current),
                    style: GoogleFonts.anuphan(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        style: GoogleFonts.anuphan(
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
          const Icon(Icons.star_rounded, size: 17, color: Color(0xFFE8A117)),
          const SizedBox(width: 4),
          Text(
            numberText(rating, fallback: '0'),
            style: GoogleFonts.anuphan(
              color: AppTheme.onSurface(context),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count รีวิว',
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
