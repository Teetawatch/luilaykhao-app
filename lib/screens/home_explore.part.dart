part of 'customer_app_screen.dart';

// Shown at most once per app session (resets on restart). Permanent opt-out is
// stored in SharedPreferences under [_kScarcityDismissedKey].
bool _scarcitySheetShownThisSession = false;
const String _kScarcityDismissedKey = 'scarcity_sheet_dismissed';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final ScrollController _scrollController;
  double _topBarProgress = 0;
  String? _activeType;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final nextProgress = (_scrollController.offset / 120).clamp(0.0, 1.0);
    if ((nextProgress - _topBarProgress).abs() < 0.02) return;
    setState(() => _topBarProgress = nextProgress);
  }

  Future<void> _maybeShowScarcitySheet(AppProvider app) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kScarcityDismissedKey) == true) return;
    // small delay so it never interrupts the first glance
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted || app.almostFullTrips.isEmpty) return;
    final trip = asMap(app.almostFullTrips.first);
    if (tripScarcityLevel(trip) == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScarcitySheet(trip: trip),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.50).clamp(
      420.0,
      540.0,
    );

    // Polite one-per-session nudge for an almost-full trip.
    if (!_scarcitySheetShownThisSession && app.almostFullTrips.isNotEmpty) {
      _scarcitySheetShownThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeShowScarcitySheet(app),
      );
    }

    final notificationCount = app.notifications
        .where((item) => asMap(item)['is_read'] != true)
        .length;
    final hasFilter = _activeType != null;
    final showTrips =
        (hasFilter
                ? app.trips
                : (app.featuredTrips.isNotEmpty
                      ? app.featuredTrips
                      : app.trips))
            .map(asMap)
            .toList();

    Future<void> openNotifications() async {
      if (!app.isLoggedIn) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              onLoginSuccess: () async {
                final currentApp = context.read<AppProvider>();
                await currentApp.loadNotifications();
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
            ),
          ),
        );
        return;
      }

      await app.loadNotifications();
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: app.loadPublicData,
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Stack(
                    children: [
                      HeroHeader(slides: app.heroSlides),
                      Container(
                        margin: EdgeInsets.only(top: heroHeight - 64),
                        child: _HomeInspiredTopSection(app: app),
                      ),
                    ],
                  ),
                  _YourTripSection(app: app),
                  // Browse-continuity: trips the user opened before, so they can
                  // pick up where they left off (hidden until something's viewed).
                  _RecentlyViewedSection(app: app),
                  _CategoryChipsSection(
                    categories: app.categories.map(asMap).toList(),
                    activeType: _activeType,
                    onTypeChanged: (type) {
                      setState(() => _activeType = type);
                      app.loadPublicData(type: type);
                    },
                  ),
                  if (app.almostFullTrips.isNotEmpty)
                    _AlmostFullRail(
                      trips: app.almostFullTrips.map(asMap).toList(),
                    ),
                  _PopularTripsSection(
                    trips: showTrips,
                    activeType: _activeType,
                  ),
                  _UpcomingDeparturesSection(app: app),
                  // Deals — a strong conversion lever, placed right after the
                  // core browse rails to catch deal-seekers before softer content.
                  PromotionsSection(
                    promotions: app.promotions
                        .map(asMap)
                        .where((p) => p.isNotEmpty)
                        .toList(),
                  ),
                  // Social proof backs up the browsing above.
                  _CustomerReviewsSection(
                    reviews: app.reviews
                        .map(asMap)
                        .where((r) => r.isNotEmpty)
                        .toList(),
                  ),
                  // Secondary features (invite a group / refer a friend).
                  _GroupTripSection(app: app),
                  _ReferralBanner(app: app),
                  // Inspiration / SEO content sits last, before the nav padding.
                  const _ArticlesTeaserSection(),
                  const SizedBox(height: 100), // Bottom padding for Nav Bar
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _HeroTopBar(
                user: app.user,
                notificationCount: notificationCount,
                backgroundProgress: _topBarProgress,
                onNotificationsTap: openNotifications,
                onProfileTap: NotificationNavigator.goToProfile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeroHeader extends StatefulWidget {
  /// Admin-managed hero slides ({image_url, alt_text}); falls back to the
  /// bundled background when empty.
  final List<dynamic> slides;

  /// Whether to show the in-hero search bar. Home shows it; a reuse without
  /// search can pass false.
  final bool showSearch;

  const HeroHeader({super.key, this.slides = const [], this.showSearch = true});

  @override
  State<HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<HeroHeader> {
  int _index = 0;
  Timer? _timer;
  final _searchController = TextEditingController();

  static const _interval = Duration(seconds: 5);

  List<String> get _images => widget.slides
      .map((s) => ApiConfig.mediaUrl(asMap(s)['image_url']?.toString() ?? ''))
      .where((url) => url.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _maybeStartTimer();
  }

  @override
  void didUpdateWidget(covariant HeroHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Slides arrived (or changed count) after the first build — (re)evaluate.
    if (widget.slides.length != oldWidget.slides.length) {
      if (_index >= _images.length) _index = 0;
      _maybeStartTimer();
    }
  }

  void _maybeStartTimer() {
    _timer?.cancel();
    if (_images.length <= 1) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _images.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Time-of-day greeting shown above the hero search bar.
  ({String text, String emoji}) _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return (text: 'อรุณสวัสดิ์', emoji: '☀️');
    if (hour < 16) return (text: 'สวัสดีตอนบ่าย', emoji: '⛅');
    if (hour < 19) return (text: 'สวัสดีตอนเย็น', emoji: '🌅');
    return (text: 'สวัสดีตอนค่ำ', emoji: '🌙');
  }

  /// Opens the dedicated results page with the typed query (standard-app
  /// behaviour) instead of filtering the home in place.
  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AllTripsScreen(initialSearch: query)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    // Fall back to the bundled overlay image when no slides are configured.
    final fallback = ApiConfig.mediaUrl('/images/bgoverlaymobile.png');
    final currentImage = images.isEmpty
        ? fallback
        : images[_index.clamp(0, images.length - 1)];
    final size = MediaQuery.of(context).size;
    final heroHeight = (size.height * 0.50).clamp(420.0, 540.0);
    final compactWidth = size.width < 390;
    final horizontalPadding = compactWidth ? 18.0 : 24.0;
    final contentBottom = compactWidth ? 128.0 : 138.0;
    final titleSize = (size.width * 0.058).clamp(20.0, 26.0).toDouble();
    final greeting = _timeGreeting();

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (currentImage.isEmpty)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primaryColor, AppTheme.accentColor],
                      ),
                    ),
                  )
                else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    child: CachedNetworkImage(
                      // Key by URL so the switcher cross-fades between slides.
                      key: ValueKey(currentImage),
                      imageUrl: currentImage,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) =>
                          Container(color: const Color(0xFF0A3D46)),
                      errorWidget: (_, _, _) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.accentColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Two-ended scrim: a light wash up top keeps the nav bar legible
                // and a strong wash at the bottom anchors the greeting/headline/
                // search — the middle stays fully clear so the photo reads crisp.
                // (No full-image blur, which is what made the hero look murky.)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.30),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.62),
                      ],
                      stops: const [0.0, 0.22, 0.45, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Hero Content
          Positioned(
            left: horizontalPadding,
            right: horizontalPadding,
            bottom: contentBottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time-of-day greeting eyebrow — light personal context that
                // leads the eye into the primary search action below.
                Text(
                  '${greeting.text} ${greeting.emoji}',
                  style: appFont(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(color: Color(0x4D000000), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Short, functional headline — one scannable line instead of the
                // old two-line marketing copy, so the search bar reads sooner.
                Text(
                  'วันนี้อยากไปลุยที่ไหน?',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    color: Colors.white,
                    fontSize: titleSize,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    shadows: const [
                      Shadow(
                        color: Color(0x59000000),
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                if (widget.showSearch) ...[
                  const SizedBox(height: 16),
                  // Primary action: full-width search bar anchored at the bottom
                  // of the hero. Submitting opens a dedicated results page.
                  _HeroSearchField(
                    controller: _searchController,
                    onSubmitted: (_) => _submitSearch(),
                    onFilterTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AllTripsScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Secondary AI trip-finder entry, demoted below the search so
                  // it complements rather than competes with the primary action.
                  _HeroFinderChip(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TripFinderScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          // Slide indicator dots (only with more than one slide).
          if (images.length > 1)
            Positioned(
              left: horizontalPadding,
              bottom: contentBottom - 26,
              child: Row(
                children: List.generate(images.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 6),
                    width: active ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: active ? 0.95 : 0.5,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroTopBar extends StatelessWidget {
  final Map<String, dynamic>? user;
  final int notificationCount;
  final double backgroundProgress;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;

  const _HeroTopBar({
    required this.user,
    required this.notificationCount,
    required this.backgroundProgress,
    required this.onNotificationsTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = ApiConfig.mediaUrl(user?['avatar_url']);
    final name = textOf(user?['name'], 'ลุยเลเขา');
    final firstName =
        name.split(' ').where((part) => part.isNotEmpty).firstOrNull ?? name;
    final initial = firstName.characters.first.toUpperCase();
    final textColor = Color.lerp(
      Colors.white,
      AppTheme.textMain,
      backgroundProgress,
    )!;
    final iconColor = Color.lerp(
      Colors.white,
      AppTheme.primaryColor,
      backgroundProgress,
    )!;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(20 * backgroundProgress),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 22 * backgroundProgress,
          sigmaY: 22 * backgroundProgress,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78 * backgroundProgress),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.outlineColor.withValues(
                  alpha: 0.45 * backgroundProgress,
                ),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.05 * backgroundProgress,
                ),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onProfileTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: avatar.isNotEmpty
                                ? Image.network(avatar, fit: BoxFit.cover)
                                : Image.asset(
                                    'logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Center(
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'สวัสดี, $firstName',
                              style: appFont(
                                color: textColor,
                                fontSize: 17,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'พร้อมออกเดินทางครั้งใหม่?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                color: Color.lerp(
                                  Colors.white.withValues(alpha: 0.85),
                                  AppTheme.textSecondary,
                                  backgroundProgress,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Badge sits in an outer Stack so the count isn't clipped by
                  // the bell's ClipOval. The bell is the home for the unread
                  // notification count (not the bottom "บัญชี" tab).
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 44,
                            height: 44,
                            color: Colors.white.withValues(
                              alpha: 0.22 + (0.50 * backgroundProgress),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: onNotificationsTap,
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: iconColor,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (notificationCount > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            alignment: Alignment.center,
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.errorColor.withValues(
                                    alpha: 0.55,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              notificationCount > 99
                                  ? '99+'
                                  : '$notificationCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeInspiredTopSection extends StatelessWidget {
  final AppProvider app;

  const _HomeInspiredTopSection({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _TrustHub(app: app),
          // Booking-ref lookup is only useful to guests (members already
          // have their trips in-app), so keep it out of signed-in Home.
          if (!app.isLoggedIn) ...[
            const SizedBox(height: 14),
            const _GuestBookingBanner(),
          ],
        ],
      ),
    );
  }
}

class _HeroSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilterTap;

  const _HeroSearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onFilterTap,
  });

  @override
  State<_HeroSearchField> createState() => _HeroSearchFieldState();
}

class _HeroSearchFieldState extends State<_HeroSearchField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
    widget.controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? const Color(0xFF0B8A6E) : const Color(0xFFE5EBEB),
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? const Color(0xFF0B8A6E).withValues(alpha: 0.14)
                : const Color(0xFF082A30).withValues(alpha: 0.12),
            blurRadius: _focused ? 18 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => widget.onSubmitted(widget.controller.text),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 0, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.search_rounded,
                  key: ValueKey(_focused),
                  color: _focused
                      ? const Color(0xFF0B8A6E)
                      : const Color(0xFF8A9FA0),
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: const Color(0xFF0B8A6E),
              style: appFont(
                color: const Color(0xFF111313),
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'ค้นหาทริป ปลายทาง หรือกิจกรรม',
                hintStyle: appFont(
                  color: const Color(0xFF111313).withValues(alpha: 0.42),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: () {
                widget.controller.clear();
                _focusNode.unfocus();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF111313).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          const SizedBox(width: 6),
          // Tonal iOS-style filter button — same visual language as the field
          // so the bar reads as a single control.
          GestureDetector(
            onTap: widget.onFilterTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.all(5),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF0B8A6E).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF0B6E5A),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Secondary AI trip-finder entry shown under the hero search bar. Styled as a
/// translucent glass chip so it reads as a helper, not a competing search.
class _HeroFinderChip extends StatelessWidget {
  final VoidCallback onTap;

  const _HeroFinderChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'ผู้ช่วยหาทริป',
                  style: appFont(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified trust hub shown right under the hero: a tappable green header with
/// the legal licence claim, plus a light social-proof row (rating / travellers
/// / people booked). Merging the old licence strip and stats bar into one card
/// reads as a single "why trust us" block and saves vertical space.
class _TrustHub extends StatelessWidget {
  final AppProvider app;

  const _TrustHub({required this.app});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final titleSize = compact ? 14.0 : 15.0;
        final bodySize = compact ? 11.5 : 12.5;

        // Aggregate social-proof stats across all trips for the lower half. The
        // licence claim lives in the green header, so the old licence fallback
        // cell is dropped here to avoid repeating the same signal.
        final trips = app.trips.map(asMap).toList();
        num ratingSum = 0;
        var ratingTrips = 0;
        var reviewCount = 0;
        var travelers = 0;
        var bookedPeople = 0;
        for (final t in trips) {
          final rc = int.tryParse('${t['review_count'] ?? 0}') ?? 0;
          final r = num.tryParse('${t['rating'] ?? 0}') ?? 0;
          if (rc > 0 && r > 0) {
            ratingSum += r;
            ratingTrips++;
            reviewCount += rc;
          }
          travelers +=
              int.tryParse('${t['confirmed_passengers_count'] ?? 0}') ?? 0;
          bookedPeople +=
              int.tryParse('${t['booked_passengers_count'] ?? 0}') ?? 0;
        }
        final avgRating = ratingTrips > 0 ? ratingSum / ratingTrips : 0;
        final statCells = <({IconData icon, String value, String label})>[
          if (avgRating > 0)
            (
              icon: Icons.star_rounded,
              value: avgRating.toStringAsFixed(1),
              label: 'จาก $reviewCount รีวิว',
            ),
          if (travelers > 0)
            (
              icon: Icons.groups_rounded,
              value: '${_compactCount(travelers)}+',
              label: 'นักเดินทาง',
            ),
          if (bookedPeople > 0)
            (
              icon: Icons.event_available_rounded,
              value: '${_compactCount(bookedPeople)}+',
              label: 'คนจองแล้ว',
            ),
        ].take(3).toList();

        void showLicenseDialog() {
          showDialog<void>(
            context: context,
            builder: (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 40,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF044C4D), Color(0xFF087C68)],
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'ใบอนุญาตประกอบธุรกิจนำเที่ยว',
                                style: appFont(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Image
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.6,
                        ),
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Image.network(
                            ApiConfig.mediaUrl('/images/cer.jpg'),
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                height: 260,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                        : null,
                                    color: const Color(0xFF087C68),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, _, _) => SizedBox(
                              height: 200,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.broken_image_outlined,
                                      size: 48,
                                      color: Color(0xFFB0BFBF),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'ไม่สามารถโหลดรูปได้',
                                      style: appFont(
                                        color: const Color(0xFF8A9FA0),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Footer
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Text(
                          'เลขที่ใบอนุญาต 12/03773',
                          style: appFont(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B8080),
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

        // Compact, fully-tappable trust strip: a small seal, a one-line claim +
        // licence number, and a trailing chevron — far slimmer than the old
        // card with its full-width white button, so it reassures without
        // competing with the hero above it.
        // Green header — the tappable licence claim.
        final header = Semantics(
          button: true,
          label: 'ดูใบอนุญาตประกอบธุรกิจนำเที่ยว เลขที่ 12/03773',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: showLicenseDialog,
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B6E5F), Color(0xFF0E8770)],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 13 : 15,
                    vertical: compact ? 11 : 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: compact ? 20 : 22,
                        ),
                      ),
                      SizedBox(width: compact ? 11 : 13),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'จองมั่นใจ ปลอดภัย',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                color: Colors.white,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ใบอนุญาตเลขที่ 12/03773',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: bodySize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        // One rounded card, clipped so the green header and the light stats row
        // share the same corners; the shadow rides on the outer container.
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B6E5F).withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                if (statCells.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF4F8F8),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < statCells.length; i++) ...[
                          if (i > 0)
                            Container(
                              width: 1,
                              height: 34,
                              color: const Color(
                                0xFF0A3D46,
                              ).withValues(alpha: 0.08),
                            ),
                          Expanded(child: _TrustCell(data: statCells[i])),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HomeTopSection extends StatefulWidget {
  final AppProvider app;
  final Map<String, dynamic>? user;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onSearch;

  const HomeTopSection({
    super.key,
    required this.app,
    required this.user,
    required this.onCategorySelected,
    required this.onSearch,
  });

  @override
  State<HomeTopSection> createState() => _HomeTopSectionState();
}

class _HomeTopSectionState extends State<HomeTopSection> {
  String? _selectedSlug;
  int? _selectedScheduleId;
  String? _selectedPickupRegionKey;
  Future<List<dynamic>>? _schedulesFuture;
  bool _isPickupExpanded = false;

  @override
  void didUpdateWidget(covariant HomeTopSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final trips = _tripOptions;
    if (_selectedSlug != null &&
        !trips.any((trip) => trip['slug']?.toString() == _selectedSlug)) {
      _selectedSlug = null;
      _selectedScheduleId = null;
      _selectedPickupRegionKey = null;
      _schedulesFuture = null;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<Map<String, dynamic>> get _tripOptions {
    return widget.app.trips
        .map(asMap)
        .where((trip) => textOf(trip['slug']).isNotEmpty)
        .toList();
  }

  void _selectTrip(String? slug) {
    if (slug == null || slug == _selectedSlug) return;
    setState(() {
      _selectedSlug = slug;
      _selectedScheduleId = null;
      _selectedPickupRegionKey = null;
      _schedulesFuture = widget.app.schedules(slug);
      _isPickupExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trips = _tripOptions;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeHeader(user: widget.user),
          const SizedBox(height: 20),
          const TripFinderEntryCard(),
          const SizedBox(height: 20),
          if (widget.app.almostFullTrips.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'ใกล้เต็มแล้ว · รีบจอง',
                  style: appFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 440,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: widget.app.almostFullTrips.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) => SizedBox(
                  width: 280,
                  child: TripCard(
                    trip: asMap(widget.app.almostFullTrips[index]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'ทริปที่กำลังเปิดรับสมัคร',
            style: appFont(
              color: AppTheme.onSurface(context),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          DestinationDropdown(
            slug: _selectedSlug,
            options: trips,
            onChanged: _selectTrip,
          ),
          if (_selectedSlug != null) ...[
            const SizedBox(height: 20),
            Text(
              'เลือกภาคที่จะขึ้นและวันเดินทาง',
              style: appFont(
                color: AppTheme.onSurface(context),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            DateSelectorCard(
              schedulesFuture: _schedulesFuture,
              selectedScheduleId: _selectedScheduleId,
              onChanged: (id) => setState(() => _selectedScheduleId = id),
              onRegionChanged: (regionKey) =>
                  setState(() => _selectedPickupRegionKey = regionKey),
              app: context.read<AppProvider>(),
              isExpanded: _isPickupExpanded,
              onToggleExpand: () =>
                  setState(() => _isPickupExpanded = !_isPickupExpanded),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: PrimaryCTAButton(
                label: 'ดูรายละเอียดทริป',
                icon: Icons.explore_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TripDetailScreen(
                      slug: _selectedSlug!,
                      initialScheduleId: _selectedScheduleId,
                      initialPickupRegionKey: _selectedPickupRegionKey,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  final Map<String, dynamic>? user;

  const HomeHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = textOf(user?['name'], 'ลูกทริปลุยเลเขา');
    final firstName =
        name.split(' ').where((part) => part.isNotEmpty).firstOrNull ?? name;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สวัสดี, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  color: AppTheme.textMain,
                  fontSize: 22,
                  height: 1.16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'วันนี้อยากออกเดินทางแบบไหนดี?',
                style: appFont(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.travel_explore_rounded,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}

// ─── Category Chips Section ───────────────────────────────────────────────────

class _CategoryChipsSection extends StatelessWidget {
  /// Backend categories (id/name/slug/icon), already mapped from the API.
  final List<Map<String, dynamic>> categories;
  final String? activeType;
  final ValueChanged<String?> onTypeChanged;

  const _CategoryChipsSection({
    required this.categories,
    required this.activeType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    // "ทั้งหมด" always leads, followed by the backend-managed categories.
    final chips = <({String? type, String label, IconData icon})>[
      (type: null, label: 'ทั้งหมด', icon: Icons.explore_rounded),
      for (final cat in categories)
        if (textOf(cat['slug']).isNotEmpty)
          (
            type: textOf(cat['slug']),
            label: textOf(cat['name'], textOf(cat['slug'])),
            icon: categoryIcon(
              textOf(cat['icon']).isEmpty ? null : textOf(cat['icon']),
            ),
          ),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'หมวดหมู่',
            style: appFont(
              color: const Color(0xFF063F46),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(right: 20),
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = chips[index];
                final isSelected = activeType == cat.type;
                return _CategoryChip(
                  label: cat.label,
                  icon: cat.icon,
                  isSelected: isSelected,
                  onTap: () => onTypeChanged(cat.type),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Apple-style capsule filter chip (App Store / News / Maps language):
    // icon + label inline, flat fill, tint to signal selection — no drop
    // shadow, full 44pt-tall tap target.
    const accent = Color(0xFF044C4D);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? accent : const Color(0xFFF1F4F4),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? accent
                : const Color(0xFF0A3D46).withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : accent),
            const SizedBox(width: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: 14,
                height: 1.0,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF1C2B2B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// ─── Recently Viewed Rail ────────────────────────────────────────────────────
// Browse-continuity: trips the user opened before (stored locally by
// AppProvider.recordRecentTrip). Hidden until at least one trip is viewed.
class _RecentlyViewedSection extends StatelessWidget {
  final AppProvider app;

  const _RecentlyViewedSection({required this.app});

  @override
  Widget build(BuildContext context) {
    final trips = app.recentlyViewedTrips
        .map(asMap)
        .where((t) => textOf(t['slug']).isNotEmpty)
        .toList();
    if (trips.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 24, 0, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF063F46),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ดูล่าสุด',
                    style: appFont(
                      color: const Color(0xFF063F46),
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 250,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: trips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) => SizedBox(
                width: MediaQuery.of(context).size.width > 700 ? 230 : 180,
                child: _ReferenceTripCard(trip: trips[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Almost-Full Rail ────────────────────────────────────────────────────────
// Scarcity cue mirroring the web "ใกล้เต็มแล้ว" home rail: a horizontal list of
// trips that are nearly sold out, nudging users to book before seats run out.
class _AlmostFullRail extends StatelessWidget {
  final List<Map<String, dynamic>> trips;

  const _AlmostFullRail({required this.trips});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 16, 0, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppTheme.errorColor,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ใกล้เต็มแล้ว · รีบจองเลย',
                    style: appFont(
                      color: const Color(0xFF063F46),
                      fontSize: 25,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 250,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: trips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) => SizedBox(
                width: MediaQuery.of(context).size.width > 700 ? 230 : 180,
                child: _ReferenceTripCard(
                  trip: trips[index],
                  showScarcity: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PopularTripsSection extends StatelessWidget {
  final List<Map<String, dynamic>> trips;
  final String? activeType;

  const _PopularTripsSection({required this.trips, this.activeType});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 0, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeType != null
                            ? _tripTypeLabel(activeType!)
                            : 'ทริปแนะนำ',
                        style: appFont(
                          color: const Color(0xFF063F46),
                          fontSize: 25,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AllTripsScreen()),
                  ),
                  child: Text(
                    'ดูทั้งหมด',
                    style: appFont(
                      color: const Color(0xFF063F46),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (trips.isEmpty)
            const Padding(
              padding: EdgeInsets.only(right: 24),
              child: Center(
                child: _EmptyState(
                  icon: Icons.hiking,
                  title: 'ยังไม่มีทริปนี้',
                  body: 'ลองรีเฟรชหรือตรวจสอบการเชื่อมต่อข้อมูล',
                ),
              ),
            )
          else
            SizedBox(
              height: 250,
              child: ListView.separated(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 20),
                itemCount: trips.take(6).length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) => SizedBox(
                  width: MediaQuery.of(context).size.width > 700 ? 230 : 180,
                  child: _ReferenceTripCard(trip: trips[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Trust Hub stat cell ─────────────────────────────────────────────────────

class _TrustCell extends StatelessWidget {
  final ({IconData icon, String value, String label}) data;

  const _TrustCell({required this.data});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF044C4D);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data.icon, size: 16, color: accent),
            const SizedBox(width: 4),
            Text(
              data.value,
              style: appFont(
                fontSize: 16,
                height: 1.0,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: appFont(
            fontSize: 11,
            height: 1.0,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5E7777),
          ),
        ),
      ],
    );
  }
}

String _compactCount(int n) {
  if (n >= 1000) {
    final v = n / 1000;
    return '${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}k';
  }
  return '$n';
}

// ─── Upcoming Departures Section ─────────────────────────────────────────────

const _thaiMonthsShort = [
  '',
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

class _UpcomingDeparturesSection extends StatelessWidget {
  final AppProvider app;

  const _UpcomingDeparturesSection({required this.app});

  @override
  Widget build(BuildContext context) {
    // A trip can have many rounds — treat each schedule as its own departure so
    // every round (including the nearly-full ones) shows on the board.
    final entries =
        <
          ({
            Map<String, dynamic> trip,
            Map<String, dynamic> schedule,
            DateTime date,
          })
        >[];
    for (final raw in app.trips) {
      final trip = asMap(raw);
      for (final s in asList(trip['schedules']).map(asMap)) {
        final date = DateTime.tryParse(textOf(s['departure_date']));
        if (date == null) continue;
        entries.add((trip: trip, schedule: s, date: date));
      }
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    if (entries.isEmpty) return const SizedBox.shrink();
    final shown = entries.take(6).toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 4, 0, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ใกล้ออกเดินทาง',
                        style: appFont(
                          color: const Color(0xFF063F46),
                          fontSize: 22,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'จองก่อนที่นั่งเต็ม',
                        style: appFont(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AllTripsScreen()),
                  ),
                  child: Text(
                    'ดูทั้งหมด',
                    style: appFont(
                      color: const Color(0xFF063F46),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 100,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final e = shown[index];
                return _DepartureCard(
                  trip: e.trip,
                  schedule: e.schedule,
                  date: e.date,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartureCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final Map<String, dynamic> schedule;
  final DateTime date;

  const _DepartureCard({
    required this.trip,
    required this.schedule,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final title = textOf(trip['title'], 'ทริป');
    final location = textOf(trip['location']);
    final image = ApiConfig.mediaUrl(
      textOf(trip['thumbnail_image'], textOf(trip['cover_image'])),
    );
    final seats = int.tryParse('${schedule['available_seats'] ?? ''}');
    final total = int.tryParse('${schedule['total_seats'] ?? ''}');
    final full = seats != null && seats <= 0;
    // "ใกล้เต็ม" measured against capacity (≥70% booked) so it stays honest on
    // both small and large trips — plus an absolute floor of ≤3 seats left.
    final nearlyFull =
        seats != null &&
        seats > 0 &&
        (seats <= 3 || (total != null && total > 0 && seats <= total * 0.3));

    final (Color badgeBg, Color badgeFg, String seatText) = full
        ? (const Color(0xFFFDECEC), const Color(0xFFC0392B), 'เต็มแล้ว')
        : nearlyFull
        ? (
            const Color(0xFFFFF1E6),
            const Color(0xFFC2410C),
            'เหลือ $seats ที่นั่ง',
          )
        : (
            const Color(0xFFE8F3EF),
            const Color(0xFF0B6E5A),
            seats != null ? 'ว่าง $seats ที่นั่ง' : 'เปิดรับสมัคร',
          );

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(
              slug: textOf(trip['slug']),
              initialScheduleId: int.tryParse('${schedule['id'] ?? ''}'),
            ),
          ),
        );
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEAF0F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF082A30).withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const ColoredBox(color: Color(0xFF044C4D)),
                        errorWidget: (_, _, _) => const _DepartureCoverFallback(),
                      )
                    else
                      const _DepartureCoverFallback(),
                    // Bottom scrim so the date chip stays legible over any photo.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x99000000)],
                          stops: [0.4, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${date.day} ${_thaiMonthsShort[date.month]}',
                          textAlign: TextAlign.center,
                          style: appFont(
                            color: const Color(0xFF044C4D),
                            fontSize: 11.5,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      color: const Color(0xFF111313),
                      fontSize: 14.5,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          size: 13,
                          color: Color(0xFF8A9FA0),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(
                              color: const Color(0xFF6B8080),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      seatText,
                      style: appFont(
                        color: badgeFg,
                        fontSize: 11.5,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for the departure card's cover thumbnail when a trip has no
/// image (or it fails to load): the brand green with a subtle terrain glyph.
class _DepartureCoverFallback extends StatelessWidget {
  const _DepartureCoverFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF044C4D),
      child: Center(
        child: Icon(
          Icons.terrain_rounded,
          color: Colors.white24,
          size: 26,
        ),
      ),
    );
  }
}

// ─── Customer Reviews Section ────────────────────────────────────────────────

class _CustomerReviewsSection extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;

  const _CustomerReviewsSection({required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();
    final items = reviews.take(8).toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 4, 0, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เสียงจากลูกทริป',
                        style: appFont(
                          color: const Color(0xFF063F46),
                          fontSize: 22,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'รีวิวจริงจากผู้ที่เดินทางไปกับเรา',
                        style: appFont(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AllReviewsScreen()),
                  ),
                  child: Text(
                    'ดูทั้งหมด',
                    style: appFont(
                      color: const Color(0xFF063F46),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 206,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _HomeReviewCard(review: items[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _HomeReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final user = asMap(review['user']);
    final name = textOf(review['user_name'], textOf(user['name'], 'ลูกทริป'));
    final avatar = ApiConfig.mediaUrl(
      textOf(review['user_avatar'], textOf(user['avatar_url'])),
    );
    final rating = (num.tryParse('${review['rating'] ?? 0}') ?? 0)
        .round()
        .clamp(0, 5);
    final comment = textOf(review['comment']).trim();
    final tripTitle = textOf(review['trip_title']).trim();
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final images = asList(review['images'])
        .map((e) => ApiConfig.mediaUrl(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAF0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF044C4D),
                  shape: BoxShape.circle,
                ),
                child: avatar.isNotEmpty
                    ? Image.network(
                        avatar,
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _avatarInitial(initial),
                      )
                    : _avatarInitial(initial),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        color: const Color(0xFF111313),
                        fontSize: 14,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        for (var i = 0; i < 5; i++)
                          Icon(
                            i < rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 13,
                            color: const Color(0xFFE8A117),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              comment.isNotEmpty ? comment : 'ประทับใจการเดินทางกับเรา',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                color: const Color(0xFF44595A),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (tripTitle.isNotEmpty && tripTitle != '-') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.hiking_rounded,
                  size: 14,
                  color: Color(0xFF0B6E5A),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    tripTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      color: const Color(0xFF0B6E5A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: 10),
            _HomeReviewThumbnails(images: images),
          ],
        ],
      ),
    );
  }

  Widget _avatarInitial(String initial) {
    return Text(
      initial,
      style: appFont(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Compact, tappable strip of photos attached to a home-page review.
/// Shows up to 4 thumbnails; the last one overlays a "+N" badge when there
/// are more. Tapping any thumbnail opens the fullscreen photo viewer.
class _HomeReviewThumbnails extends StatelessWidget {
  final List<String> images;

  const _HomeReviewThumbnails({required this.images});

  static const double _size = 44;
  static const int _maxThumbs = 4;

  void _open(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _BookingPhotoViewer(urls: images, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = images.take(_maxThumbs).toList();
    final extra = images.length - shown.length;

    return Row(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _open(context, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: shown[i],
                    width: _size,
                    height: _size,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      width: _size,
                      height: _size,
                      color: const Color(0xFFEAF0F0),
                    ),
                    errorWidget: (_, _, _) => Container(
                      width: _size,
                      height: _size,
                      color: const Color(0xFFEAF0F0),
                      child: const Icon(
                        Icons.broken_image_rounded,
                        size: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  if (i == shown.length - 1 && extra > 0)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Text(
                          '+$extra',
                          style: appFont(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Promotions Section ──────────────────────────────────────────────────────

class PromotionsSection extends StatelessWidget {
  final List<Map<String, dynamic>> promotions;

  const PromotionsSection({super.key, required this.promotions});

  @override
  Widget build(BuildContext context) {
    if (promotions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.fromLTRB(20, 36, 0, 36),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(56)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'โปรโมชั่นและสิทธิพิเศษ',
                        style: appFont(
                          color: AppTheme.textMain,
                          fontSize: 22,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ส่วนลดและโค้ดพิเศษสำหรับการจอง',
                        style: appFont(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PromotionsScreen(promotions: promotions),
                    ),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  label: Text(
                    'ดูทั้งหมด',
                    style: appFont(
                      color: AppTheme.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: promotions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) => SizedBox(
                width: MediaQuery.of(context).size.width > 700 ? 360 : 300,
                child: _PromotionCard(promotion: promotions[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  final Map<String, dynamic> promotion;

  const _PromotionCard({required this.promotion});

  String _discountLabel() {
    final type = promotion['type']?.toString() ?? '';
    final value = promotion['value'];
    if (value == null) return '';
    final num v = value is num ? value : num.tryParse(value.toString()) ?? 0;
    return type == 'percent'
        ? 'ลด ${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}%'
        : 'ลด ฿${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final code = promotion['code']?.toString() ?? '';
    final name = promotion['name']?.toString() ?? '-';
    final endDate = promotion['end_date'];

    // Flash sale: a precise deadline drives a live countdown + remaining-uses
    // urgency instead of the plain "ใช้ได้ถึง <date>" footer.
    final isFlash = promotion['is_flash_sale'] == true;
    final endsAt = promotion['ends_at'] != null
        ? DateTime.tryParse(promotion['ends_at'].toString())
        : null;
    final showFlash = isFlash && endsAt != null && endsAt.isAfter(DateTime.now());
    final maxUses = int.tryParse('${promotion['max_uses'] ?? ''}');
    final usedCount = int.tryParse('${promotion['used_count'] ?? 0}') ?? 0;
    final remainingUses =
        maxUses != null ? (maxUses - usedCount).clamp(0, maxUses) : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.accentColor],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _discountLabel(),
                  style: appFont(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showFlash) ...[
                _FlashCountdown(endsAt: endsAt),
                if (remainingUses != null && remainingUses > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'เหลือเพียง $remainingUses สิทธิ์',
                    style: appFont(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
              _CodeChip(code: code),
              if (!showFlash && endDate != null) ...[
                const SizedBox(height: 6),
                Text(
                  'ใช้ได้ถึง ${_formatDate(endDate.toString())}',
                  style: appFont(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

/// Live "⚡ FLASH SALE · จบใน HH:MM:SS" pill that ticks down each second and
/// flips to a lapsed state when the deadline passes.
class _FlashCountdown extends StatefulWidget {
  final DateTime endsAt;

  const _FlashCountdown({required this.endsAt});

  @override
  State<_FlashCountdown> createState() => _FlashCountdownState();
}

class _FlashCountdownState extends State<_FlashCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt.difference(DateTime.now());
    final expired = remaining.isNegative;
    final label = expired ? 'หมดเวลาแล้ว' : 'จบใน ${_format(remaining)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            'FLASH SALE · $label',
            style: appFont(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    // Show days only when the sale runs longer than a day, otherwise HH:MM:SS.
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inDays > 0) {
      return '${d.inDays} วัน ${two(d.inHours % 24)}:${two(d.inMinutes % 60)}';
    }
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

class _CodeChip extends StatelessWidget {
  final String code;

  const _CodeChip({required this.code});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Copy code
        _copyCode(context, code);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: appFont(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  void _copyCode(BuildContext context, String code) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'คัดลอกโค้ด "$code" แล้ว',
          style: appFont(fontWeight: FontWeight.w700),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ─── Promotions Full Screen ───────────────────────────────────────────────────

class PromotionsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> promotions;

  const PromotionsScreen({super.key, required this.promotions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
        title: Text(
          'โปรโมชั่นและสิทธิพิเศษ',
          style: appFont(
            color: AppTheme.onSurface(context),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (promotions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _PromotionsEmptyState(),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  '${promotions.length} ดีลพร้อมใช้งาน',
                  style: appFont(
                    color: AppTheme.primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverList.builder(
                itemCount: promotions.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return const _PromotionsHintBanner();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _PromotionListCard(promotion: promotions[index - 1]),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PromotionsHintBanner extends StatelessWidget {
  const _PromotionsHintBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_offer_rounded,
            size: 18,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'แตะที่โค้ดเพื่อคัดลอก แล้วนำไปกรอกตอนชำระเงินเพื่อรับส่วนลด',
              style: appFont(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionsEmptyState extends StatelessWidget {
  const _PromotionsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                size: 42,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'ยังไม่มีโปรโมชั่นตอนนี้',
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'เรากำลังเตรียมดีลและสิทธิพิเศษใหม่ ๆ ไว้ให้ กลับมาเช็กได้เร็ว ๆ นี้',
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestBookingBanner extends StatelessWidget {
  const _GuestBookingBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GuestBookingLookupScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(context, radius: 20),
          child: Row(
            children: [
              // Solid emerald tile keeps the accent crisp against the clean
              // surface (iOS-style), with a soft glow for a bit of depth.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.32),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.confirmation_number_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'มีรหัสการจองอยู่แล้ว?',
                      style: appFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ดู QR เช็คอิน และติดตามรถ ไม่ต้องสมัครสมาชิก',
                      style: appFont(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedText(context),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppTheme.mutedText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Polite, dismissible bottom-sheet nudging the most urgent almost-full trip.
class _ScarcitySheet extends StatelessWidget {
  final Map<String, dynamic> trip;

  const _ScarcitySheet({required this.trip});

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final label = tripScarcityLabel(trip) ?? 'ใกล้เต็มแล้ว';
    final level = tripScarcityLevel(trip);
    final badgeColor = level == 'last'
        ? AppTheme.errorColor
        : AppTheme.warningColor;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: image.isEmpty
                      ? Container(color: AppTheme.subtleSurface(context))
                      : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.30),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ทริปนี้กำลังจะเต็ม',
                    style: appFont(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    textOf(trip['title'], '-'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TripDetailScreen(slug: trip['slug'].toString()),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bolt_rounded),
                      label: Text(
                        'จองเลย',
                        style: appFont(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(_kScarcityDismissedKey, true);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: Text(
                        'ไม่ต้องแสดงอีก',
                        style: appFont(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Your Trip Section (personalised next booking) ───────────────────────────
//
// Surfaces the signed-in traveller's nearest upcoming booking right at the top
// of Home, so the screen greets returning users with their own trip instead of
// generic discovery content. Reuses the existing booking helpers and detail
// sheet — no new backend.

class _YourTripSection extends StatelessWidget {
  final AppProvider app;

  const _YourTripSection({required this.app});

  @override
  Widget build(BuildContext context) {
    if (!app.isLoggedIn) return const SizedBox.shrink();

    final upcoming = app.bookings.map(asMap).where(_isUpcomingBooking).toList()
      ..sort((a, b) {
        final ad = bookingTravelDate(a) ?? DateTime(2100);
        final bd = bookingTravelDate(b) ?? DateTime(2100);
        return ad.compareTo(bd);
      });
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final next = upcoming.first;
    final more = upcoming.length - 1;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ทริปของคุณ',
                      style: appFont(
                        color: const Color(0xFF063F46),
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      more > 0
                          ? 'อีก $more ทริปที่กำลังจะถึง'
                          : 'เตรียมตัวให้พร้อมก่อนออกเดินทาง',
                      style: appFont(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: NotificationNavigator.goToBookings,
                child: Text(
                  more > 0 ? 'ดูทั้งหมด' : 'การจองของฉัน',
                  style: appFont(
                    color: const Color(0xFF063F46),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HomeNextTripCard(booking: next),
        ],
      ),
    );
  }
}

class _HomeNextTripCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _HomeNextTripCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final title = textOf(trip['title'], 'ทริปของคุณ');
    final location = textOf(trip['location']);
    final travelDate = bookingTravelDate(booking);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = travelDate?.difference(today).inDays;
    final ref = textOf(booking['booking_ref']);
    final image = ApiConfig.mediaUrl(
      textOf(trip['thumbnail_image'], textOf(trip['cover_image'])),
    );
    final isPending = textOf(booking['status']) == 'pending';

    final (String countLabel, Color countColor) = switch (days) {
      null => ('รอวันเดินทาง', AppTheme.primaryColor),
      < 0 => ('กำลังเดินทาง', const Color(0xFF16A34A)),
      0 => ('เดินทางวันนี้!', const Color(0xFF16A34A)),
      1 => ('พรุ่งนี้!', const Color(0xFFD97706)),
      <= 3 => ('อีก $days วัน!', const Color(0xFFD97706)),
      _ => ('อีก $days วัน', AppTheme.primaryColor),
    };

    void openSheet() {
      if (ref.isEmpty) return;
      HapticFeedback.selectionClick();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BookingDetailSheet(bookingRef: ref),
      );
    }

    return GestureDetector(
      onTap: openSheet,
      child: Container(
        height: 172,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF0B3D42),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B3D42).withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0xE6000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _GlassPill(
                        icon: Icons.hiking_rounded,
                        label: 'ทริปของคุณ',
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPending
                              ? const Color(0xFFD97706)
                              : countColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPending
                                  ? Icons.schedule_rounded
                                  : Icons.event_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isPending ? 'ค้างชำระ' : countLabel,
                              style: appFont(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      color: Colors.white,
                      fontSize: 19,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (travelDate != null) ...[
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('d MMM yyyy', 'th_TH').format(travelDate),
                          style: appFont(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (travelDate != null && location.isNotEmpty)
                        Text(
                          '  ·  ',
                          style: appFont(color: Colors.white54, fontSize: 12.5),
                        ),
                      if (location.isNotEmpty)
                        Flexible(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _NextTripCta(
                    label: isPending ? 'ชำระเงินให้เสร็จ' : 'ดูรายละเอียด',
                    icon: isPending
                        ? Icons.payments_rounded
                        : Icons.arrow_forward_rounded,
                    highlighted: isPending,
                    onTap: openSheet,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GlassPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: appFont(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextTripCta extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool highlighted;
  final VoidCallback onTap;

  const _NextTripCta({
    required this.label,
    required this.icon,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: highlighted
              ? Colors.white
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: highlighted
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: appFont(
                color: highlighted ? const Color(0xFFB45309) : Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              icon,
              size: 16,
              color: highlighted ? const Color(0xFFB45309) : Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Group Trip Section (find travel companions) ─────────────────────────────
//
// Promotes the Group Trip feature on Home and gives a quick way in: review the
// rooms you host or joined, or jump in with an invite code. The personalised
// rail loads silently — if it fails or is empty, the promo card still shows.

class _GroupTripSection extends StatefulWidget {
  final AppProvider app;

  const _GroupTripSection({required this.app});

  @override
  State<_GroupTripSection> createState() => _GroupTripSectionState();
}

class _GroupTripSectionState extends State<_GroupTripSection> {
  List<GroupPlan> _plans = const [];
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    if (widget.app.isLoggedIn) _load();
  }

  @override
  void didUpdateWidget(_GroupTripSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Login can complete after the first build — pick the rooms up then.
    if (widget.app.isLoggedIn && !_requested) _load();
  }

  Future<void> _load() async {
    _requested = true;
    try {
      final raw = await widget.app.myGroupPlans();
      final plans = raw
          .whereType<Map>()
          .map((e) => GroupPlan.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.status == 'open' || p.status == 'booked')
          .toList();
      if (!mounted) return;
      setState(() => _plans = plans);
    } catch (_) {
      // Silent — the promo card is still useful without the rail.
    }
  }

  void _openMine() {
    if (!widget.app.isLoggedIn) {
      _gateLogin(_pushMine);
      return;
    }
    _pushMine();
  }

  void _pushMine() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GroupRoomsScreen()),
    );
  }

  void _gateLogin(VoidCallback then) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoginSuccess: () {
            if (mounted) then();
          },
        ),
      ),
    );
  }

  Future<void> _joinByCode() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _JoinGroupSheet(),
    );
    if (code == null || code.isEmpty || !mounted) return;
    if (!widget.app.isLoggedIn) {
      _gateLogin(() => _openGroup(code));
      return;
    }
    _openGroup(code);
  }

  void _openGroup(String code) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupRoomScreen(inviteCode: code)),
    );
  }

  // Browsing trips is public; the create CTA inside trip detail gates login.
  void _createGroup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AllTripsScreen(introBanner: GroupCreateTripHint()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPlans = _plans.isNotEmpty;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เที่ยวเป็นกลุ่ม',
                      style: appFont(
                        color: const Color(0xFF063F46),
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ชวนเพื่อนไปทริปเดียวกัน',
                      style: appFont(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPlans)
                TextButton(
                  onPressed: _openMine,
                  child: Text(
                    'ดูทั้งหมด',
                    style: appFont(
                      color: const Color(0xFF063F46),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (hasPlans) ...[
            SizedBox(
              height: 124,
              child: ListView.separated(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                itemCount: _plans.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final plan = _plans[index];
                  return _HomeGroupCard(
                    plan: plan,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupRoomScreen(initialPlan: plan),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          _GroupPromoCard(
            onCreate: _createGroup,
            onMine: _openMine,
            onJoin: _joinByCode,
          ),
        ],
      ),
    );
  }
}

class _HomeGroupCard extends StatelessWidget {
  final GroupPlan plan;
  final VoidCallback onTap;

  const _HomeGroupCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = plan.trip?.title ?? 'ทริปแบบกลุ่ม';
    final dateRaw = plan.schedule?.departureDate;
    final date = dateRaw == null ? null : DateTime.tryParse(dateRaw);
    final isBooked = plan.isBooked;
    final accent = isBooked ? const Color(0xFF16A34A) : AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 244,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEAF0F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF082A30).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isBooked ? 'จองแล้ว' : 'กำลังเปิดรับ',
                    style: appFont(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                if (plan.isHost)
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: const Color(0xFFD97706).withValues(alpha: 0.9),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: const Color(0xFF063F46),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(
                  Icons.groups_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  '${plan.readyCount}/${plan.seatCount} พร้อมแล้ว',
                  style: appFont(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                if (date != null)
                  Text(
                    DateFormat('d MMM', 'th_TH').format(date),
                    style: appFont(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupPromoCard extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onMine;
  final VoidCallback onJoin;

  const _GroupPromoCard({
    required this.onCreate,
    required this.onMine,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3FBF8), Colors.white],
        ),
        border: Border.all(color: const Color(0xFFE3EFEC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF082A30).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.groups_2_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ไปเป็นกลุ่ม สนุกกว่า',
                      style: appFont(
                        color: const Color(0xFF063F46),
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ชวนเพื่อนจองพร้อมกัน เลือกที่นั่งเองได้ หัวหน้ากลุ่มจ่ายทีเดียว',
                      style: appFont(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _PromoButton(
            label: 'สร้างกลุ่มใหม่',
            icon: Icons.add_rounded,
            filled: true,
            fullWidth: true,
            onTap: onCreate,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PromoButton(
                  label: 'กลุ่มของฉัน',
                  icon: Icons.meeting_room_rounded,
                  filled: false,
                  onTap: onMine,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PromoButton(
                  label: 'ใส่โค้ดเชิญ',
                  icon: Icons.vpn_key_rounded,
                  filled: false,
                  onTap: onJoin,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromoButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool fullWidth;
  final VoidCallback onTap;

  const _PromoButton({
    required this.label,
    required this.icon,
    required this.filled,
    this.fullWidth = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 46,
        width: fullWidth ? double.infinity : null,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: const Color(0xFFD7E6E1)),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? Colors.white : AppTheme.primaryColor,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: appFont(
                color: filled ? Colors.white : const Color(0xFF063F46),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinGroupSheet extends StatefulWidget {
  const _JoinGroupSheet();

  @override
  State<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<_JoinGroupSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'เข้าร่วมกลุ่มด้วยโค้ด',
              style: appFont(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'กรอกโค้ดเชิญที่ได้รับจากหัวหน้ากลุ่ม',
              style: appFont(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _submit(),
              style: appFont(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppTheme.onSurface(context),
              ),
              decoration: InputDecoration(
                hintText: 'เช่น AB12CD',
                hintStyle: appFont(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppTheme.mutedText(context).withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppTheme.subtleSurface(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'เข้าร่วมกลุ่ม',
                  style: appFont(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Referral Banner (invite friends, earn points) ───────────────────────────
//
// A compact growth nudge into the existing referral hub. Loads the invite code
// silently so signed-in users can share in one tap straight from Home; guests
// see the value prop and are routed through login.

class _ReferralBanner extends StatefulWidget {
  final AppProvider app;

  const _ReferralBanner({required this.app});

  @override
  State<_ReferralBanner> createState() => _ReferralBannerState();
}

class _ReferralBannerState extends State<_ReferralBanner> {
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    if (widget.app.isLoggedIn) _load();
  }

  @override
  void didUpdateWidget(_ReferralBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.app.isLoggedIn && !_requested) _load();
  }

  Future<void> _load() async {
    _requested = true;
    if (widget.app.referral != null) return;
    try {
      await widget.app.fetchReferral();
      if (mounted) setState(() {});
    } catch (_) {
      // Silent — the banner still works as a plain CTA into the referral hub.
    }
  }

  String get _code => textOf(asMap(widget.app.referral)['code']);

  void _openHub() {
    if (!widget.app.isLoggedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            onLoginSuccess: () {
              if (mounted) _pushHub();
            },
          ),
        ),
      );
      return;
    }
    _pushHub();
  }

  void _pushHub() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReferralScreen()),
    );
  }

  Future<void> _share() async {
    final data = asMap(widget.app.referral);
    final msg = textOf(data['share_message'], textOf(data['share_url']));
    if (msg.isEmpty) {
      _openHub();
      return;
    }
    HapticFeedback.selectionClick();
    try {
      await SharePlus.instance.share(
        ShareParams(text: msg, subject: 'ชวนเพื่อนมาเที่ยวลุยลายเขา'),
      );
    } catch (_) {
      if (mounted) _openHub();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canShare = _code.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: GestureDetector(
        onTap: _openHub,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF047857), Color(0xFF10B981)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ชวนเพื่อน รับแต้มฟรีทั้งคู่',
                      style: appFont(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canShare
                          ? 'โค้ดของคุณ: $_code · ใช้แทนส่วนลดได้'
                          : 'เพื่อนจองทริปแรก รับแต้มทั้งสองฝ่าย',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (canShare)
                GestureDetector(
                  onTap: _share,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.ios_share_rounded,
                          size: 16,
                          color: Color(0xFF047857),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'แชร์',
                          style: appFont(
                            color: const Color(0xFF047857),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Articles Teaser Section ──────────────────────────────────────────────────
// Surfaces the latest blog articles on home and routes into the full reader.
// Renders nothing until articles load, so it never disrupts a fresh install.
class _ArticlesTeaserSection extends StatefulWidget {
  const _ArticlesTeaserSection();

  @override
  State<_ArticlesTeaserSection> createState() => _ArticlesTeaserSectionState();
}

class _ArticlesTeaserSectionState extends State<_ArticlesTeaserSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArticleProvider>().loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArticleProvider>();
    final articles = provider.articles;
    if (articles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 4, 0, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'บทความ & ทริคเที่ยว',
                    style: appFont(
                      color: const Color(0xFF063F46),
                      fontSize: 25,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ArticleListScreen()),
                  ),
                  child: Text(
                    'ดูทั้งหมด',
                    style: appFont(
                      color: const Color(0xFF063F46),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 262,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: articles.take(6).length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final a = articles[index];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ArticleDetailScreen(slug: a.slug),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 272,
                    child: Container(
                      decoration: AppTheme.cardDecoration(context),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: a.coverImageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl:
                                        ApiConfig.mediaUrl(a.coverImageUrl),
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Container(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.06),
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.08),
                                    ),
                                  )
                                : Container(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.08),
                                    child: const Icon(Icons.menu_book_rounded,
                                        color: Colors.white54),
                                  ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title leads (up to 2 full lines — no longer
                                  // squeezed by an Expanded that clipped it).
                                  Text(
                                    a.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: appFont(
                                      color: AppTheme.onSurface(context),
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      height: 1.3,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      if (a.category != null) ...[
                                        Flexible(
                                          child: Text(
                                            a.category!.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: appFont(
                                              color: AppTheme.primaryColor,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '  ·  ',
                                          style: appFont(
                                            color: AppTheme.mutedText(context),
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                      Text(
                                        'อ่าน ${a.readingMinutes} นาที',
                                        style: appFont(
                                          color: AppTheme.mutedText(context),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
