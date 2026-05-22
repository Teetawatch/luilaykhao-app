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
          style: GoogleFonts.anuphan(
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
        background: HeroImageGallery(trip: trip, isLoading: isLoading),
      ),
    );
  }
}

class HeroImageGallery extends StatefulWidget {
  final Map<String, dynamic> trip;
  final bool isLoading;

  const HeroImageGallery({
    super.key,
    required this.trip,
    required this.isLoading,
  });

  @override
  State<HeroImageGallery> createState() => _HeroImageGalleryState();
}

class _HeroImageGalleryState extends State<HeroImageGallery> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant HeroImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);

    final previousImages = _galleryImages(oldWidget.trip);
    final nextImages = _galleryImages(widget.trip);
    final galleryChanged =
        previousImages.length != nextImages.length ||
        (previousImages.isNotEmpty &&
            nextImages.isNotEmpty &&
            previousImages.first != nextImages.first);

    if (galleryChanged || _currentPage >= nextImages.length) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _galleryImages(widget.trip);
    final imageUrl = images.isNotEmpty ? images.first : '';
    final canSwipe = images.length > 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── image / page view ──────────────────────────────────────
        Container(
          color: const Color(0xFFE7ECEA),
          child: widget.isLoading
              ? const Skeleton(radius: 0)
              : canSwipe
              ? PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) => CachedNetworkImage(
                    imageUrl: images[index],
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const Skeleton(radius: 0),
                    errorWidget: (_, _, _) => const _GalleryImageFallback(),
                  ),
                )
              : imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const Skeleton(radius: 0),
                  errorWidget: (_, _, _) => const _GalleryImageFallback(),
                )
              : const _GalleryImageFallback(),
        ),

        // ── subtle gradient: light at top for button legibility,
        //    stronger at bottom to blend into the card ──────────────
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x55000000), // 33% — just enough for back button
                Color(0x00000000), // transparent mid
                Color(0x00000000),
                Color(0x66000000), // 40% at bottom edge
              ],
              stops: [0.0, 0.25, 0.6, 1.0],
            ),
          ),
        ),

        // ── dot page indicators ────────────────────────────────────
        if (canSwipe)
          Positioned(
            bottom: _contentOverlap + 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),

        // ── photo count badge (top-right) ──────────────────────────
        if (canSwipe)
          Positioned(
            right: 16,
            bottom: _contentOverlap + 14,
            child: _GalleryBadge(
              currentIndex: _currentPage,
              count: images.length,
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
