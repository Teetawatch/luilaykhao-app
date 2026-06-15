part of 'trip_detail_screen.dart';

class TravelSliverAppBar extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isLoading;
  final bool isCollapsed;
  final double expandedHeight;
  final bool isFavorite;
  final bool isAlertOn;
  final VoidCallback onSharePressed;
  final VoidCallback onFavoritePressed;
  final VoidCallback onAlertPressed;

  const TravelSliverAppBar({
    super.key,
    required this.trip,
    required this.isLoading,
    required this.isCollapsed,
    required this.expandedHeight,
    required this.isFavorite,
    required this.isAlertOn,
    required this.onSharePressed,
    required this.onFavoritePressed,
    required this.onAlertPressed,
  });

  @override
  Widget build(BuildContext context) {
    final title = _tripTitle(trip);

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isCollapsed
          ? AppTheme.surface(context)
          : Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      title: AnimatedOpacity(
        opacity: isCollapsed ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: appFont(
            color: _premiumText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      centerTitle: true,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: FloatingActionIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          isCollapsed: isCollapsed,
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      actions: [
        FloatingActionIconButton(
          icon: Icons.ios_share_rounded,
          isCollapsed: isCollapsed,
          onPressed: onSharePressed,
        ),
        const SizedBox(width: 8),
        FloatingActionIconButton(
          icon: isAlertOn
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          isCollapsed: isCollapsed,
          foregroundColor: isAlertOn ? const Color(0xFFF59E0B) : null,
          onPressed: onAlertPressed,
        ),
        const SizedBox(width: 8),
        FloatingActionIconButton(
          icon: isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          isCollapsed: isCollapsed,
          foregroundColor: isFavorite ? const Color(0xFFE11D48) : null,
          onPressed: onFavoritePressed,
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: HeroCoverImage(trip: trip, isLoading: isLoading),
      ),
    );
  }
}

/// A single, static cover image for the trip — no swiping, no counters.
/// The bottom dissolves into the page background so the detail card below
/// blends in cleanly, in the spirit of Apple's photo-led layouts.
class HeroCoverImage extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isLoading;

  const HeroCoverImage({
    super.key,
    required this.trip,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final images = _galleryImages(trip);
    final imageUrl = images.isNotEmpty ? images.first : '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── cover image only ───────────────────────────────────────
        Container(
          color: const Color(0xFFE7ECEA),
          child: isLoading
              ? const Skeleton(radius: 0)
              : imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const Skeleton(radius: 0),
                  errorWidget: (_, _, _) => const _GalleryImageFallback(),
                )
              : const _GalleryImageFallback(),
        ),

        // ── top scrim for control legibility only ─────────────────
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.42),
                Colors.transparent,
              ],
              stops: const [0.0, 0.38],
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryImageFallback extends StatelessWidget {
  const _GalleryImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE7ECEA),
      child: Center(
        child: Icon(Icons.landscape_rounded, color: _softAccent, size: 64),
      ),
    );
  }
}

class FloatingActionIconButton extends StatefulWidget {
  final IconData icon;
  final bool isCollapsed;
  final Color? foregroundColor;
  final VoidCallback onPressed;

  const FloatingActionIconButton({
    super.key,
    required this.icon,
    required this.isCollapsed,
    this.foregroundColor,
    required this.onPressed,
  });

  @override
  State<FloatingActionIconButton> createState() =>
      _FloatingActionIconButtonState();
}

class _FloatingActionIconButtonState extends State<FloatingActionIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final foreground =
        widget.foregroundColor ??
        (widget.isCollapsed ? AppTheme.onSurface(context) : Colors.white);
    final background = widget.isCollapsed
        ? AppTheme.surface(context).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.18);
    final border = widget.isCollapsed
        ? AppTheme.border(context)
        : Colors.white.withValues(alpha: 0.30);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 110),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: background,
              shape: CircleBorder(side: BorderSide(color: border)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onPressed,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(widget.icon, size: 20, color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
