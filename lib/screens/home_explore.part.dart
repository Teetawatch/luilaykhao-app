part of 'customer_app_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final ScrollController _scrollController;
  double _topBarProgress = 0;
  String? _activeSearch;
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.50).clamp(420.0, 540.0);

    final notificationCount = app.notifications
        .where((item) => asMap(item)['is_read'] != true)
        .length;
    final heroTrip =
        (app.featuredTrips.isNotEmpty ? app.featuredTrips : app.trips)
            .map(asMap)
            .firstOrNull;
    final hasFilter = _activeSearch != null || _activeType != null;
    final showTrips = (hasFilter
            ? app.trips
            : (app.featuredTrips.isNotEmpty ? app.featuredTrips : app.trips))
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
                      HeroHeader(trip: heroTrip),
                      Container(
                        margin: EdgeInsets.only(top: heroHeight - 64),
                        child: _HomeInspiredTopSection(
                          app: app,
                          user: app.user,
                          onSearch: (value) {
                            setState(() {
                              _activeSearch = value.isEmpty ? null : value;
                              _activeType = null;
                            });
                            app.loadPublicData(
                              search: value.isEmpty ? null : value,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  _CategoryChipsSection(
                    activeType: _activeType,
                    onTypeChanged: (type) {
                      setState(() {
                        _activeType = type;
                        _activeSearch = null;
                      });
                      app.loadPublicData(type: type);
                    },
                  ),
                  _PopularTripsSection(
                    trips: showTrips,
                    activeType: _activeType,
                  ),
                  PromotionsSection(
                    promotions: app.promotions
                        .map(asMap)
                        .where((p) => p.isNotEmpty)
                        .toList(),
                  ),
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

class HeroHeader extends StatelessWidget {
  final Map<String, dynamic>? trip;

  const HeroHeader({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl('/images/bgoverlaymobile.png');
    final size = MediaQuery.of(context).size;
    final heroHeight = (size.height * 0.50).clamp(420.0, 540.0);
    final compactWidth = size.width < 390;
    final horizontalPadding = compactWidth ? 18.0 : 24.0;
    final contentBottom = compactWidth ? 148.0 : 158.0;
    final contentWidth = (size.width - (horizontalPadding * 2)).clamp(
      260.0,
      680.0,
    );
    final titleSize = (size.width * 0.058).clamp(20.0, 26.0).toDouble();
    final subtitleSize = compactWidth ? 14.0 : 15.0;

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
                if (image.isEmpty)
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
                  CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: const Color(0xFF0A3D46)),
                    errorWidget: (_, _, _) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        ),
                      ),
                    ),
                  ),
                // Apple-style vignette: stronger scrim where the headline sits
                // so text is legible without needing per-character text shadows.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.38),
                        Colors.black.withValues(alpha: 0.10),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.36),
                      ],
                      stops: const [0.0, 0.28, 0.55, 1.0],
                    ),
                  ),
                ),
                // Optional subtle BackdropFilter for a premium feel
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),
          ),
          // Hero Content
          Positioned(
            left: horizontalPadding,
            right: horizontalPadding,
            top: null,
            bottom: contentBottom,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'การเที่ยวที่ดี เริ่มจาก\nความรู้สึกที่ดี ตั้งแต่การจอง',
                        textAlign: TextAlign.start,
                        style: GoogleFonts.anuphan(
                          color: Colors.white,
                          fontSize: titleSize,
                          height: 1.22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'ค้นหาทริปและประสบการณ์ที่พร้อมเดินทาง',
                        textAlign: TextAlign.start,
                        style: GoogleFonts.anuphan(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: subtitleSize,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                              style: GoogleFonts.anuphan(
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
                              style: GoogleFonts.anuphan(
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
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
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
                          if (notificationCount > 0)
                            Positioned(
                              top: 9,
                              right: 10,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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

class _HomeInspiredTopSection extends StatefulWidget {
  final AppProvider app;
  final Map<String, dynamic>? user;
  final ValueChanged<String> onSearch;

  const _HomeInspiredTopSection({
    required this.app,
    required this.user,
    required this.onSearch,
  });

  @override
  State<_HomeInspiredTopSection> createState() =>
      _HomeInspiredTopSectionState();
}

class _HomeInspiredTopSectionState extends State<_HomeInspiredTopSection> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    FocusScope.of(context).unfocus();
    widget.onSearch(_searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 40),
          padding: const EdgeInsets.fromLTRB(20, 70, 20, 22),
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
          child: const Column(
            children: [
              _LicenseAssuranceBanner(),
              SizedBox(height: 14),
              _GuestBookingBanner(),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 28,
          right: 28,
          child: _HeroSearchField(
            controller: _searchController,
            onSubmitted: (_) => _submitSearch(),
            onFilterTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AllTripsScreen())),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused
              ? const Color(0xFF0B8A6E)
              : const Color(0xFFE5EBEB),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.search_rounded,
                  key: ValueKey(_focused),
                  color: _focused
                      ? const Color(0xFF0B8A6E)
                      : const Color(0xFF8A9FA0),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: const Color(0xFF0B8A6E),
              style: GoogleFonts.anuphan(
                color: const Color(0xFF111313),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'ค้นหาทริป ปลายทาง หรือกิจกรรม',
                hintStyle: GoogleFonts.anuphan(
                  color: const Color(0xFF111313).withValues(alpha: 0.42),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF111313).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
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
              margin: const EdgeInsets.all(6),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF0B8A6E).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF0B6E5A),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LicenseAssuranceBanner extends StatelessWidget {
  const _LicenseAssuranceBanner();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final narrow = constraints.maxWidth < 430;
        final padding = compact
            ? const EdgeInsets.all(14)
            : const EdgeInsets.fromLTRB(18, 16, 16, 16);
        final iconBoxSize = compact ? 48.0 : (narrow ? 56.0 : 66.0);
        final iconSize = compact ? 31.0 : (narrow ? 36.0 : 44.0);
        final titleSize = compact ? 15.0 : 17.0;
        final bodySize = compact ? 12.0 : 13.0;

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
                                style: GoogleFonts.anuphan(
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
                                      style: GoogleFonts.anuphan(
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
                          style: GoogleFonts.anuphan(
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

        Widget iconBox() {
          // Apple Wallet-style trust glyph — white seal on a soft inner tint
          // so the verified mark reads first.
          return Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(compact ? 14 : 16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.verified_rounded,
              color: Colors.white,
              size: iconSize,
            ),
          );
        }

        Widget textContent() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'จองมั่นใจ ปลอดภัย',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ใบอนุญาตประกอบธุรกิจนำเที่ยว\nเลขที่ 12/03773',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: bodySize,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        Widget licenseButton() {
          // Filled-light CTA: white pill on dark green — far higher contrast
          // than the previous dark-on-dark button.
          return TextButton.icon(
            onPressed: showLicenseDialog,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF0B5E55),
              backgroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 16,
                vertical: compact ? 10 : 12,
              ),
              minimumSize: narrow ? const Size.fromHeight(42) : null,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: Text(
              'ดูใบอนุญาต',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.anuphan(
                fontSize: compact ? 12.5 : 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }

        final content = narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      iconBox(),
                      SizedBox(width: compact ? 12 : 14),
                      Expanded(child: textContent()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  licenseButton(),
                ],
              )
            : Row(
                children: [
                  iconBox(),
                  const SizedBox(width: 16),
                  Expanded(child: textContent()),
                  const SizedBox(width: 12),
                  Flexible(flex: 0, child: licenseButton()),
                ],
              );

        return Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B6E5F), Color(0xFF0E8770)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B6E5F).withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: content,
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
          Text(
            'ทริปที่กำลังเปิดรับสมัคร',
            style: GoogleFonts.anuphan(
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
              style: GoogleFonts.anuphan(
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
                style: GoogleFonts.anuphan(
                  color: AppTheme.textMain,
                  fontSize: 22,
                  height: 1.16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'วันนี้อยากออกเดินทางแบบไหนดี?',
                style: GoogleFonts.anuphan(
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

// ─── Trip type helpers ────────────────────────────────────────────────────────

const _tripCategories = [
  (type: null, label: 'ทั้งหมด', icon: Icons.explore_rounded),
  (type: 'trekking', label: 'เดินป่า', icon: Icons.forest_rounded),
  (type: 'snorkeling', label: 'ดำน้ำตื้น', icon: Icons.waves_rounded),
  (type: 'camping', label: 'แคมป์ปิ้ง', icon: Icons.cabin_rounded),
  (type: 'van_service', label: 'รถตู้นำเที่ยว', icon: Icons.airport_shuttle_rounded),
];

// ─── Category Chips Section ───────────────────────────────────────────────────

class _CategoryChipsSection extends StatelessWidget {
  final String? activeType;
  final ValueChanged<String?> onTypeChanged;

  const _CategoryChipsSection({
    required this.activeType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'หมวดหมู่',
            style: GoogleFonts.anuphan(
              color: const Color(0xFF063F46),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(right: 20, bottom: 4),
              itemCount: _tripCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final cat = _tripCategories[index];
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 68,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF044C4D)
              : const Color(0xFFF0F4F4),
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF044C4D).withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF044C4D),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.anuphan(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF3D6363),
              ),
            ),
          ],
        ),
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
                        style: GoogleFonts.anuphan(
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
                    style: GoogleFonts.anuphan(
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
              padding: EdgeInsets.only(right: 20),
              child: _EmptyState(
                icon: Icons.hiking,
                title: 'ยังไม่มีทริปที่เปิดขาย',
                body: 'ลองรีเฟรชหรือตรวจสอบการเชื่อมต่อข้อมูล',
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
                        style: GoogleFonts.anuphan(
                          color: AppTheme.textMain,
                          fontSize: 22,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ส่วนลดและโค้ดพิเศษสำหรับการจอง',
                        style: GoogleFonts.anuphan(
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
                    style: GoogleFonts.anuphan(
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
                  style: GoogleFonts.anuphan(
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
                  style: GoogleFonts.anuphan(
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
              _CodeChip(code: code),
              if (endDate != null) ...[
                const SizedBox(height: 6),
                Text(
                  'ใช้ได้ถึง ${_formatDate(endDate.toString())}',
                  style: GoogleFonts.anuphan(
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
              style: GoogleFonts.anuphan(
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
          style: GoogleFonts.anuphan(fontWeight: FontWeight.w700),
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
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          LargeTitleSliverHeader(
            title: 'โปรโมชั่นและสิทธิพิเศษ',
            subtitle: promotions.isEmpty
                ? 'รออัปเดตเร็ว ๆ นี้'
                : '${promotions.length} ดีลพร้อมใช้งาน',
            subtitleColor: promotions.isEmpty ? null : AppTheme.primaryColor,
          ),
          if (promotions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _PromotionsEmptyState(),
            )
          else
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
              style: GoogleFonts.anuphan(
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
              style: GoogleFonts.anuphan(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'เรากำลังเตรียมดีลและสิทธิพิเศษใหม่ ๆ ไว้ให้ กลับมาเช็กได้เร็ว ๆ นี้',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const GuestBookingLookupScreen(),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'มีรหัสการจองอยู่แล้ว?',
                      style: GoogleFonts.anuphan(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ดู QR เช็คอิน และติดตามรถได้เลย ไม่ต้องสมัครสมาชิก',
                      style: GoogleFonts.anuphan(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor.withValues(alpha: 0.72),
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
                color: AppTheme.primaryColor.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

