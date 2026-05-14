import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart' hide TravelSliverAppBar;
import 'booking_flow_screen.dart';
import 'login_screen.dart';

const Color _premiumText = Color(0xFF0F172A);
const Color _mutedText = Color(0xFF64748B);
const Color _softAccent = Color(0xFF10B981);
const double _contentOverlap = 32;
const String _favoriteTripSlugsKey = 'favorite_trip_slugs';

class TripDetailScreen extends StatefulWidget {
  final String? slug;
  final int? initialScheduleId;
  final int? initialPickupPointId;
  final String? initialPickupRegionKey;

  const TripDetailScreen({
    super.key,
    this.slug,
    this.initialScheduleId,
    this.initialPickupPointId,
    this.initialPickupRegionKey,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Future<Map<String, dynamic>>? _future;
  Map<String, dynamic>? _trip;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final app = Provider.of<AppProvider>(context, listen: false);
    final slug = widget.slug ?? '';

    final tripData = await app.trip(slug);
    if (mounted) {
      setState(() => _trip = tripData);
    }

    final tripId = int.tryParse(tripData['id']?.toString() ?? '') ?? 0;
    final results = await Future.wait([
      app.schedules(slug),
      if (tripId > 0) app.tripReviews(tripId) else Future.value(<dynamic>[]),
    ]);

    return <String, dynamic>{
      'schedules': results[0],
      'reviews': results[1],
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            _trip == null;

        if (snapshot.hasError && _trip == null) {
          return Scaffold(
            backgroundColor: AppTheme.background(context),
            appBar: AppBar(
              backgroundColor: AppTheme.surface(context),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        size: 36,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'โหลดข้อมูลไม่สำเร็จ',
                      style: GoogleFonts.anuphan(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _premiumText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต\nแล้วลองใหม่อีกครั้ง',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.anuphan(
                        fontSize: 14,
                        color: _mutedText,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() => _future = _loadData());
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _softAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        'ลองใหม่',
                        style: GoogleFonts.anuphan(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return TravelDetailPage(
          trip: _trip ?? <String, dynamic>{},
          schedules: snapshot.data?['schedules'] as List<dynamic>? ?? const [],
          reviews: snapshot.data?['reviews'] as List<dynamic>? ?? const [],
          isLoading: isLoading,
          initialScheduleId: widget.initialScheduleId,
          initialPickupPointId: widget.initialPickupPointId,
          initialPickupRegionKey: widget.initialPickupRegionKey,
          isDescriptionExpanded: _isDescriptionExpanded,
          onDescriptionToggle: () {
            setState(() {
              _isDescriptionExpanded = !_isDescriptionExpanded;
            });
          },
        );
      },
    );
  }
}

class TravelDetailPage extends StatefulWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> schedules;
  final List<dynamic> reviews;
  final bool isLoading;
  final int? initialScheduleId;
  final int? initialPickupPointId;
  final String? initialPickupRegionKey;
  final bool isDescriptionExpanded;
  final VoidCallback onDescriptionToggle;

  const TravelDetailPage({
    super.key,
    required this.trip,
    required this.schedules,
    required this.reviews,
    required this.isLoading,
    this.initialScheduleId,
    this.initialPickupPointId,
    this.initialPickupRegionKey,
    required this.isDescriptionExpanded,
    required this.onDescriptionToggle,
  });

  @override
  State<TravelDetailPage> createState() => _TravelDetailPageState();
}

class _TravelDetailPageState extends State<TravelDetailPage> {
  late final ScrollController _scrollController;
  bool _isCollapsed = false;
  int? _selectedScheduleId;
  int? _selectedPickupPointId;
  String? _selectedPickupRegionKey;
  bool _hasAppliedInitialSelection = false;
  bool _isFavorite = false;
  String? _favoriteSlug;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _syncInitialSelection();
    _syncFavoriteState();
  }

  @override
  void didUpdateWidget(covariant TravelDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedules != widget.schedules) {
      _syncInitialSelection();
    }
    if (oldWidget.trip['slug'] != widget.trip['slug']) {
      _syncFavoriteState();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final heroHeight = _heroHeight(context);
    final shouldCollapse =
        _scrollController.hasClients &&
        _scrollController.offset > heroHeight - kToolbarHeight - 56;

    if (shouldCollapse != _isCollapsed) {
      setState(() => _isCollapsed = shouldCollapse);
    }
  }

  Map<String, dynamic>? get _selectedSchedule {
    if (widget.schedules.isEmpty) return null;

    return asMap(
      widget.schedules.firstWhere(
        (item) =>
            asMap(item)['id'].toString() == _selectedScheduleId.toString(),
        orElse: () => widget.schedules.first,
      ),
    );
  }

  String? get _initialPickupRegionKey {
    final key = widget.initialPickupRegionKey?.trim();
    if (key == null || key.isEmpty) return null;
    return key;
  }

  /// The active region key: explicit selection takes precedence over the
  /// initial region passed via navigation.
  String? get _effectivePickupRegionKey =>
      _selectedPickupRegionKey ?? _initialPickupRegionKey;

  List<dynamic> get _selectedPickupPoints {
    final schedule = _selectedSchedule;
    if (schedule == null) return const [];

    final points = asList(schedule['pickup_points']);
    final regionKey = _effectivePickupRegionKey;
    if (regionKey == null) return points;

    return points
        .where((point) => _pickupRegionKey(asMap(point)) == regionKey)
        .toList();
  }

  Map<String, dynamic> get _selectedPickupPoint {
    final schedule = _selectedSchedule;
    if (schedule == null) return <String, dynamic>{};

    return _selectedPickupPointFor(schedule, _selectedPickupPointId);
  }

  void _syncInitialSelection() {
    if (widget.schedules.isEmpty) {
      _selectedScheduleId = null;
      _selectedPickupPointId = null;
      return;
    }

    final regionKey = _initialPickupRegionKey;
    final preferredScheduleId = !_hasAppliedInitialSelection
        ? widget.initialScheduleId
        : _selectedScheduleId;
    final selected = asMap(
      widget.schedules.firstWhere(
        (item) =>
            preferredScheduleId != null &&
            asMap(item)['id'].toString() == preferredScheduleId.toString() &&
            (regionKey == null ||
                _scheduleHasPickupRegion(asMap(item), regionKey)),
        orElse: () => widget.schedules.firstWhere(
          (item) =>
              regionKey != null &&
              _scheduleHasPickupRegion(asMap(item), regionKey),
          orElse: () => _selectedSchedule ?? widget.schedules.first,
        ),
      ),
    );
    _selectedScheduleId = int.tryParse(selected['id'].toString());
    _syncPickupSelection(
      selected,
      preferredPickupPointId: !_hasAppliedInitialSelection
          ? widget.initialPickupPointId
          : _selectedPickupPointId,
      preferredRegionKey: regionKey,
    );
    _hasAppliedInitialSelection = true;
  }

  void _syncPickupSelection(
    Map<String, dynamic> schedule, {
    int? preferredPickupPointId,
    String? preferredRegionKey,
  }) {
    final points = asList(schedule['pickup_points']);
    if (points.isEmpty) {
      _selectedPickupPointId = null;
      _selectedPickupRegionKey = null;
      return;
    }

    final normalizedRegionKey = preferredRegionKey?.trim();
    if (normalizedRegionKey != null && normalizedRegionKey.isNotEmpty) {
      final regionPoint = asMap(
        points.firstWhere(
          (item) => _pickupRegionKey(asMap(item)) == normalizedRegionKey,
          orElse: () => const <String, dynamic>{},
        ),
      );
      final regionPointId = int.tryParse(regionPoint['id']?.toString() ?? '');
      if (regionPointId != null) {
        _selectedPickupPointId = regionPointId;
        _selectedPickupRegionKey = normalizedRegionKey;
        return;
      }
    }

    final point = asMap(
      points.firstWhere(
        (item) =>
            asMap(item)['id'].toString() ==
            (preferredPickupPointId ?? _selectedPickupPointId).toString(),
        orElse: () => points.first,
      ),
    );
    _selectedPickupPointId = int.tryParse(point['id'].toString());
    _selectedPickupRegionKey = point.isNotEmpty
        ? _pickupRegionKey(point)
        : null;
  }

  void _handleScheduleChanged(int? value) {
    final schedule = asMap(
      widget.schedules.firstWhere(
        (item) => asMap(item)['id'].toString() == value.toString(),
        orElse: () => widget.schedules.first,
      ),
    );

    setState(() {
      _selectedScheduleId = value;
      _syncPickupSelection(
        schedule,
        preferredRegionKey: _effectivePickupRegionKey,
      );
    });
  }

  void _handleRegionChanged(String? regionKey) {
    setState(() {
      _selectedPickupRegionKey = regionKey;

      // If current schedule doesn't support the new region, switch to the
      // first schedule that does, then sync pickup from that schedule.
      if (regionKey != null && regionKey.isNotEmpty) {
        final current = _selectedSchedule;
        final currentValid =
            current != null && _scheduleHasPickupRegion(current, regionKey);

        if (!currentValid) {
          final match = asMap(
            widget.schedules.firstWhere(
              (item) => _scheduleHasPickupRegion(asMap(item), regionKey),
              orElse: () => const <String, dynamic>{},
            ),
          );
          if (match.isNotEmpty) {
            _selectedScheduleId = int.tryParse(match['id'].toString());
            _syncPickupSelection(match, preferredRegionKey: regionKey);
            return;
          }
        }
      }

      // Current schedule is valid (or no region filter) — just re-sync pickup.
      final schedule = _selectedSchedule;
      if (schedule != null) {
        _syncPickupSelection(schedule, preferredRegionKey: regionKey);
      }
    });
  }

  void _handlePickupChanged(int? value) {
    if (value == null) {
      setState(() {
        _selectedPickupPointId = null;
        _selectedPickupRegionKey = null;
      });
      return;
    }
    final schedule = _selectedSchedule;
    String? newRegionKey;
    if (schedule != null) {
      final point = asMap(
        asList(schedule['pickup_points']).firstWhere(
          (item) => asMap(item)['id']?.toString() == value.toString(),
          orElse: () => const <String, dynamic>{},
        ),
      );
      if (point.isNotEmpty) newRegionKey = _pickupRegionKey(point);
    }
    setState(() {
      _selectedPickupPointId = value;
      _selectedPickupRegionKey = newRegionKey;
    });
  }

  Future<void> _syncFavoriteState() async {
    final slug = textOf(widget.trip['slug']).trim();
    if (slug.isEmpty) {
      if (mounted) setState(() => _isFavorite = false);
      return;
    }
    if (_favoriteSlug == slug) return;

    _favoriteSlug = slug;
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoriteTripSlugsKey) ?? const [];
    if (!mounted || _favoriteSlug != slug) return;

    setState(() => _isFavorite = favorites.contains(slug));
  }

  Future<void> _handleShareTrip() async {
    final slug = textOf(widget.trip['slug']).trim();
    if (slug.isEmpty) {
      _showTripDetailMessage(context, 'กำลังโหลดข้อมูลทริป');
      return;
    }

    final title = _tripTitle(widget.trip);
    final url = _tripShareUrl(widget.trip);
    try {
      await SharePlus.instance.share(
        ShareParams(text: '$title\n$url', subject: title),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: '$title\n$url'));
      if (!mounted) return;
      _showTripDetailMessage(context, 'คัดลอกลิงก์ทริปแล้ว');
    }
  }

  Future<void> _handleFavoriteTap() async {
    final slug = textOf(widget.trip['slug']).trim();
    if (slug.isEmpty) {
      _showTripDetailMessage(context, 'กำลังโหลดข้อมูลทริป');
      return;
    }

    final next = !_isFavorite;
    setState(() => _isFavorite = next);

    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoriteTripSlugsKey) ?? <String>[];
    final updated = favorites.toSet();
    if (next) {
      updated.add(slug);
    } else {
      updated.remove(slug);
    }
    await prefs.setStringList(_favoriteTripSlugsKey, updated.toList());

    if (!mounted) return;
    _showTripDetailMessage(
      context,
      next ? 'บันทึกทริปที่สนใจแล้ว' : 'นำออกจากทริปที่สนใจแล้ว',
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroHeight = _heroHeight(context);
    final selectedSchedule = _selectedSchedule;
    final joinTripEnabled = selectedSchedule != null &&
        _asBool(selectedSchedule['join_trip_enabled']);
    final bottomBarHeight = widget.isLoading ? 0.0 : (joinTripEnabled ? 172.0 : 112.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isCollapsed
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            TravelSliverAppBar(
              trip: widget.trip,
              isLoading: widget.isLoading,
              isCollapsed: _isCollapsed,
              expandedHeight: heroHeight,
              isFavorite: _isFavorite,
              onSharePressed: _handleShareTrip,
              onFavoritePressed: _handleFavoriteTap,
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -_contentOverlap),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomBarHeight + 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DestinationInfoSection(
                        trip: widget.trip,
                        reviews: widget.reviews,
                        isLoading: widget.isLoading,
                      ),
                      const SizedBox(height: 16),
                      AboutSection(
                        trip: widget.trip,
                        isLoading: widget.isLoading,
                        isExpanded: widget.isDescriptionExpanded,
                        onToggle: widget.onDescriptionToggle,
                      ),
                      const SizedBox(height: 16),
                      MustKnowSection(trip: widget.trip),
                      const SizedBox(height: 16),
                      PreparationsSection(trip: widget.trip),
                      const SizedBox(height: 16),
                      TravelPlanSelectionSection(
                        schedules: widget.schedules,
                        pickupRegionKey: _effectivePickupRegionKey,
                        selectedScheduleId: _selectedScheduleId,
                        selectedPickupPointId: _selectedPickupPointId,
                        selectedPickupPoints: _selectedPickupPoints,
                        onRegionChanged: _handleRegionChanged,
                        onScheduleChanged: _handleScheduleChanged,
                        onPickupChanged: _handlePickupChanged,
                      ),
                      const SizedBox(height: 16),
                      HighlightsSection(trip: widget.trip),
                      const SizedBox(height: 16),
                      IncludedSection(trip: widget.trip),
                      const SizedBox(height: 16),
                      ExcludedSection(trip: widget.trip),
                      const SizedBox(height: 16),
                      ItinerarySection(
                        trip: widget.trip,
                        pickupRegionKey: _effectivePickupRegionKey,
                        pickupRegionLabel: _pickupRegionLabel(
                          _selectedPickupPoint,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ReviewSection(trip: widget.trip, reviews: widget.reviews),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.isLoading
            ? null
            : StickyBookingBar(
                trip: widget.trip,
                schedules: widget.schedules,
                selectedScheduleId: _selectedScheduleId,
                selectedPickupPointId: _selectedPickupPointId,
              ),
      ),
    );
  }

  double _heroHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return (size.height * 0.46).clamp(320.0, 480.0);
  }
}

class TravelSliverAppBar extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isLoading;
  final bool isCollapsed;
  final double expandedHeight;
  final bool isFavorite;
  final VoidCallback onSharePressed;
  final VoidCallback onFavoritePressed;

  const TravelSliverAppBar({
    super.key,
    required this.trip,
    required this.isLoading,
    required this.isCollapsed,
    required this.expandedHeight,
    required this.isFavorite,
    required this.onSharePressed,
    required this.onFavoritePressed,
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
                    placeholder: (_, __) => const Skeleton(radius: 0),
                    errorWidget: (_, __, ___) => const _GalleryImageFallback(),
                  ),
                )
              : imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Skeleton(radius: 0),
                  errorWidget: (_, __, ___) => const _GalleryImageFallback(),
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

class DestinationInfoSection extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;
  final bool isLoading;

  const DestinationInfoSection({
    super.key,
    required this.trip,
    required this.reviews,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    if (isLoading) {
      return _PremiumCard(
        padding: const EdgeInsets.all(24),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Skeleton(width: 110, height: 28, radius: 14),
              Spacer(),
              Skeleton(width: 80, height: 28, radius: 14),
            ]),
            SizedBox(height: 18),
            Skeleton(width: double.infinity, height: 36, radius: 12),
            SizedBox(height: 8),
            Skeleton(width: 220, height: 36, radius: 12),
            SizedBox(height: 14),
            Skeleton(width: 180, height: 18, radius: 9),
            SizedBox(height: 24),
            Skeleton(width: double.infinity, height: 88, radius: 20),
          ],
        ),
      );
    }

    final chips = _quickInfoItems(trip);
    final location = textOf(trip['location'] ?? trip['destination']).trim();
    final catLabel = textOf(
      trip['category_name'] ??
          asMap(trip['category'])['name'] ??
          trip['type'],
    ).trim();

    return _PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── top badge row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                _RatingSummary(trip: trip, reviews: reviews),
                const Spacer(),
                if (catLabel.isNotEmpty)
                  _InfoChip(icon: Icons.tag_rounded, label: catLabel),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── title ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _tripTitle(trip),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.anuphan(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : _premiumText,
                height: 1.2,
                letterSpacing: -0.4,
              ),
            ),
          ),
          // ── location ───────────────────────────────────────────────
          if (location.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _softAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: _softAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        fontSize: 13,
                        color: _mutedText,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ── stats grid ─────────────────────────────────────────────
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFE9F5F1),
                ),
              ),
              child: QuickInfoChips(trip: trip),
            ),
          ] else
            const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class QuickInfoChips extends StatelessWidget {
  final Map<String, dynamic> trip;

  const QuickInfoChips({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final chips = _quickInfoItems(trip);
    if (chips.isEmpty) return const SizedBox.shrink();

    // 2-column grid layout
    final rows = <List<_QuickInfoItem>>[];
    for (var i = 0; i < chips.length; i += 2) {
      rows.add([
        chips[i],
        if (i + 1 < chips.length) chips[i + 1],
      ]);
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          return Column(
            children: [
              Row(
                children: row.asMap().entries.map((e) {
                  final isLastInRow = e.key == row.length - 1;
                  final chip = e.value;
                  return Expanded(
                    child: _StatTile(
                      icon: chip.icon,
                      label: chip.label,
                      showRightBorder: !isLastInRow && row.length > 1,
                      showBottomBorder: !isLast,
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showRightBorder;
  final bool showBottomBorder;

  const _StatTile({
    required this.icon,
    required this.label,
    this.showRightBorder = false,
    this.showBottomBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE9F5F1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          right: showRightBorder
              ? BorderSide(color: dividerColor)
              : BorderSide.none,
          bottom: showBottomBorder
              ? BorderSide(color: dividerColor)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _softAccent.withValues(alpha: 0.18),
                  _softAccent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: _softAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.anuphan(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white.withValues(alpha: 0.85) : _premiumText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutSection extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isLoading;
  final bool isExpanded;
  final VoidCallback onToggle;

  const AboutSection({
    super.key,
    required this.trip,
    required this.isLoading,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 150, height: 24),
            SizedBox(height: 16),
            Skeleton(width: double.infinity, height: 16),
            SizedBox(height: 8),
            Skeleton(width: double.infinity, height: 16),
            SizedBox(height: 8),
            Skeleton(width: 260, height: 16),
          ],
        ),
      );
    }

    final description = textOf(trip['description']).trim();
    if (description.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.article_outlined,
            title: 'เกี่ยวกับทริปนี้',
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Text(
              description,
              maxLines: isExpanded ? null : 5,
              overflow: isExpanded ? TextOverflow.visible : TextOverflow.fade,
              style: GoogleFonts.anuphan(
                fontSize: 15,
                height: 1.75,
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (description.length > 160) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                foregroundColor: _softAccent,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                isExpanded ? 'อ่านน้อยลง' : 'อ่านเพิ่มเติม',
                style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MustKnowSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const MustKnowSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final items = _mustKnowItems(trip);
    final remarks = textOf(asMap(trip['must_know'])['remarks']).trim();
    if (items.isEmpty && remarks.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return _PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // amber accent header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFFB45309).withValues(alpha: 0.12)
                  : const Color(0xFFFFFBEB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFFB45309).withValues(alpha: 0.18)
                      : const Color(0xFFFDE68A),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFB45309).withValues(alpha: 0.2)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สิ่งที่ควรรู้ก่อนเดินทาง',
                        style: GoogleFonts.anuphan(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF92400E),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'อ่านก่อนทำการจอง',
                        style: GoogleFonts.anuphan(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFFD97706)
                              : const Color(0xFFB45309),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                ...items.map(
                  (item) => _FeatureRow(
                    icon: Icons.error_outline_rounded,
                    title: item.price > 0
                        ? '${item.name} · ${money(item.price)} ${item.priceTypeLabel}'
                        : item.name,
                    iconColor: const Color(0xFFD97706),
                    iconBackground: const Color(0xFFFEF3C7),
                  ),
                ),
                if (remarks.isNotEmpty)
                  _FeatureRow(
                    icon: Icons.notes_rounded,
                    title: remarks,
                    iconColor: const Color(0xFFD97706),
                    iconBackground: const Color(0xFFFEF3C7),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PreparationsSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const PreparationsSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final items = _textItems(trip['preparations']);
    if (items.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.backpack_rounded,
            title: 'สิ่งที่ควรเตรียม',
            subtitle: 'เตรียมตัวก่อนออกเดินทาง',
          ),
          const SizedBox(height: 20),
          // checklist with sequential numbers
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final text = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.anuphan(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        text,
                        style: GoogleFonts.anuphan(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.85)
                              : _premiumText,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class TravelPlanSelectionSection extends StatelessWidget {
  final List<dynamic> schedules;
  final String? pickupRegionKey;
  final int? selectedScheduleId;
  final int? selectedPickupPointId;
  final List<dynamic> selectedPickupPoints;
  final ValueChanged<String?> onRegionChanged;
  final ValueChanged<int?> onScheduleChanged;
  final ValueChanged<int?> onPickupChanged;

  const TravelPlanSelectionSection({
    super.key,
    required this.schedules,
    this.pickupRegionKey,
    required this.selectedScheduleId,
    required this.selectedPickupPointId,
    required this.selectedPickupPoints,
    required this.onRegionChanged,
    required this.onScheduleChanged,
    required this.onPickupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final regionKey = pickupRegionKey?.trim();

    // Collect distinct regions from all schedules
    final regionMap = <String, String>{};
    for (final schedule in schedules) {
      for (final point in asList(asMap(schedule)['pickup_points'])) {
        final p = asMap(point);
        final key = _pickupRegionKey(p);
        if (key.isNotEmpty) {
          regionMap[key] ??= textOf(
            p['region_label'],
            textOf(p['region'], key),
          );
        }
      }
    }

    final scheduleMaps = schedules
        .map(asMap)
        .where(
          (schedule) =>
              int.tryParse(schedule['id'].toString()) != null &&
              (regionKey == null ||
                  regionKey.isEmpty ||
                  _scheduleHasPickupRegion(schedule, regionKey)),
        )
        .toList();
    final pickupMaps = selectedPickupPoints
        .map(asMap)
        .where(
          (point) =>
              int.tryParse(point['id'].toString()) != null &&
              (regionKey == null ||
                  regionKey.isEmpty ||
                  _pickupRegionKey(point) == regionKey),
        )
        .toList();

    final regionValue = (regionKey != null && regionMap.containsKey(regionKey))
        ? regionKey
        : (regionMap.isEmpty ? null : regionMap.keys.first);
    final scheduleValue = _validDropdownValue(
      selectedScheduleId,
      scheduleMaps.map((item) => int.parse(item['id'].toString())),
    );
    final pickupValue = _validDropdownValue(
      selectedPickupPointId,
      pickupMaps.map((item) => int.parse(item['id'].toString())),
    );

    return _PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header with gradient accent
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _softAccent.withValues(alpha: 0.10),
                  _softAccent.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border(
                bottom: BorderSide(color: _softAccent.withValues(alpha: 0.12)),
              ),
            ),
            child: const _SectionHeader(
              icon: Icons.event_available_outlined,
              title: 'เลือกแผนการเดินทาง',
              subtitle: 'เลือกวันและจุดขึ้นรถที่ต้องการ',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Step 1 — region
                _StepDropdownRow(
                  step: '1',
                  label: 'ภูมิภาคที่ขึ้นรถ',
                  child: regionMap.isEmpty
                      ? _EmptySelectionNotice(
                          icon: Icons.map_outlined,
                          text: 'ยังไม่มีภูมิภาคสำหรับทริปนี้',
                        )
                      : _PremiumDropdown<String>(
                          key: ValueKey('region-$regionValue'),
                          label: 'เลือกภูมิภาค',
                          icon: Icons.map_outlined,
                          value: regionValue,
                          items: regionMap.entries.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.key,
                              child: _DropdownText(title: e.value, subtitle: ''),
                            );
                          }).toList(),
                          onChanged: onRegionChanged,
                        ),
                ),
                const SizedBox(height: 14),
                // Step 2 — schedule
                _StepDropdownRow(
                  step: '2',
                  label: 'วันเดินทาง',
                  child: scheduleMaps.isEmpty
                      ? _EmptySelectionNotice(
                          icon: Icons.calendar_month_outlined,
                          text: 'ยังไม่มีวันเดินทางที่เปิดจอง',
                        )
                      : _PremiumDropdown<int>(
                          key: ValueKey('schedule-$scheduleValue'),
                          label: 'เลือกวันเดินทาง',
                          icon: Icons.calendar_month_rounded,
                          value: scheduleValue,
                          items: scheduleMaps.map((schedule) {
                            final id = int.parse(schedule['id'].toString());
                            final seats =
                                textOf(schedule['available_seats'], '0');
                            final regionSummary =
                                _regionSummary(schedule, regionKey: regionKey);
                            return DropdownMenuItem<int>(
                              value: id,
                              child: _DropdownText(
                                title: _scheduleTravelDateText(schedule),
                                subtitle: regionSummary.isEmpty
                                    ? 'เหลือ $seats ที่นั่ง'
                                    : 'เหลือ $seats ที่ • $regionSummary',
                              ),
                            );
                          }).toList(),
                          onChanged: onScheduleChanged,
                        ),
                ),
                if (scheduleMaps.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  // Step 3 — pickup
                  _StepDropdownRow(
                    step: '3',
                    label: 'จุดขึ้นรถ',
                    child: pickupMaps.isEmpty
                        ? _EmptySelectionNotice(
                            icon: Icons.place_outlined,
                            text: 'ยังไม่มีจุดขึ้นรถสำหรับรอบนี้',
                          )
                        : _PremiumDropdown<int>(
                            key: ValueKey('pickup-$pickupValue'),
                            label: 'เลือกจุดขึ้นรถ',
                            icon: Icons.place_rounded,
                            value: pickupValue,
                            items: pickupMaps.map((point) {
                              final id = int.parse(point['id'].toString());
                              final location =
                                  textOf(point['pickup_location']).trim();
                              final price = _pickupPriceText(point['price']);
                              return DropdownMenuItem<int>(
                                value: id,
                                child: _DropdownText(
                                  title: location.isNotEmpty
                                      ? location
                                      : 'ไม่ระบุจุดขึ้นรถ',
                                  subtitle: price,
                                ),
                              );
                            }).toList(),
                            onChanged: onPickupChanged,
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HighlightsSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const HighlightsSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final highlights = _highlightItems(trip['highlights']);
    if (highlights.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(icon: Icons.auto_awesome, title: 'ไฮไลท์'),
          const SizedBox(height: 16),
          ...highlights.map(
            (item) => _FeatureRow(
              icon: _iconFor(item.icon) ?? Icons.check_rounded,
              title: item.title,
              description: item.description,
            ),
          ),
        ],
      ),
    );
  }
}

class IncludedSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const IncludedSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final inclusions = asList(trip['inclusions'])
        .map((item) => textOf(item).trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (inclusions.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.verified_outlined,
            title: 'สิ่งที่รวมในแพ็กเกจ',
          ),
          const SizedBox(height: 16),
          ...inclusions.map(
            (item) => _FeatureRow(icon: Icons.check_rounded, title: item),
          ),
        ],
      ),
    );
  }
}

class ExcludedSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const ExcludedSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final exclusions = asList(trip['exclusions'])
        .map((item) => textOf(item).trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (exclusions.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.remove_circle_outline_rounded,
            title: 'สิ่งที่ไม่รวมในแพ็กเกจ',
          ),
          const SizedBox(height: 16),
          ...exclusions.map(
            (item) => _FeatureRow(
              icon: Icons.close_rounded,
              title: item,
              iconColor: Color(0xFFEF4444),
              iconBackground: Color(0xFFFEF2F2),
            ),
          ),
        ],
      ),
    );
  }
}

class ItinerarySection extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String? pickupRegionKey;
  final String? pickupRegionLabel;

  const ItinerarySection({
    super.key,
    required this.trip,
    this.pickupRegionKey,
    this.pickupRegionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final sectors = _itinerarySectors(
      trip,
      regionKey: pickupRegionKey,
      regionLabel: pickupRegionLabel,
    );
    if (sectors.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.route_rounded,
            title: 'แผนการเดินทาง',
            subtitle: '${sectors.fold(0, (sum, s) => sum + s.items.length)} กิจกรรม',
          ),
          const SizedBox(height: 20),
          ...sectors.asMap().entries.map(
            (entry) => _ItinerarySectorTile(
              sector: entry.value,
              index: entry.key,
              total: sectors.length,
              initiallyExpanded: sectors.length == 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItinerarySectorTile extends StatelessWidget {
  final _ItinerarySector sector;
  final int index;
  final int total;
  final bool initiallyExpanded;

  const _ItinerarySectorTile({
    required this.sector,
    required this.index,
    required this.total,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    // gradient color cycle per sector
    final gradients = [
      [const Color(0xFF059669), const Color(0xFF10B981)],
      [const Color(0xFF0891B2), const Color(0xFF06B6D4)],
      [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)],
      [const Color(0xFFD97706), const Color(0xFFF59E0B)],
    ];
    final grad = gradients[index % gradients.length];

    return Container(
      margin: EdgeInsets.only(top: index == 0 ? 0 : 10),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: _softAccent,
          collapsedIconColor: _mutedText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: grad,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: grad[0].withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.anuphan(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          title: Text(
            sector.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(
              color: isDark ? Colors.white : _premiumText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: grad[0].withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${sector.items.length} รายการ',
                  style: GoogleFonts.anuphan(
                    color: grad[0],
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          children: [
            ...sector.items.asMap().entries.map(
              (entry) => _ItineraryTimelineItem(
                item: entry.value,
                isLast: entry.key == sector.items.length - 1,
                accentColor: grad[0],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItineraryTimelineItem extends StatelessWidget {
  final _ItineraryItem item;
  final bool isLast;
  final Color accentColor;

  const _ItineraryTimelineItem({
    required this.item,
    required this.isLast,
    this.accentColor = _softAccent,
  });

  @override
  Widget build(BuildContext context) {
    final marker = item.day.isNotEmpty ? item.day : '${item.index}';
    final isDark = AppTheme.isDark(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // timeline column
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor,
                        accentColor.withValues(alpha: 0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      marker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accentColor.withValues(alpha: 0.4),
                            accentColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.anuphan(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : _premiumText,
                      height: 1.35,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: GoogleFonts.anuphan(
                        fontSize: 13.5,
                        color: _mutedText,
                        height: 1.65,
                        fontWeight: FontWeight.w500,
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

class ReviewSection extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;

  const ReviewSection({super.key, required this.trip, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final rating = _ratingValue(trip);
    final count = _reviewCount(trip, reviews);
    final hasReviews = count > 0 && rating > 0;

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header row ──────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  icon: Icons.star_border_rounded,
                  title: 'รีวิว',
                ),
              ),
              if (hasReviews) _RatingPill(trip: trip, reviews: reviews),
            ],
          ),

          if (!hasReviews) ...[
            const SizedBox(height: 20),
            // ── empty state ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.rate_review_outlined,
                      size: 30,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ยังไม่มีรีวิว',
                    style: GoogleFonts.anuphan(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _premiumText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'เป็นคนแรกที่มาสัมผัสและแชร์ประสบการณ์',
                    style: GoogleFonts.anuphan(
                      fontSize: 13,
                      color: _mutedText,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            // ── rating summary bar ───────────────────────────────
            _ReviewRatingSummary(trip: trip, reviews: reviews),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),
            // ── review cards ────────────────────────────────────
            ...reviews.take(3).map((reviewData) {
              final review = asMap(reviewData);
              return _ReviewCard(review: review);
            }),
          ],
        ],
      ),
    );
  }
}

class _ReviewRatingSummary extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;

  const _ReviewRatingSummary({required this.trip, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final rating = _ratingValue(trip);
    final count = _reviewCount(trip, reviews);

    // count per star from review list
    final starCounts = List.filled(5, 0);
    for (final r in reviews) {
      final v = _ratingValue(asMap(r)).round().clamp(1, 5);
      starCounts[v - 1]++;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // big score
        Column(
          children: [
            Text(
              numberText(rating, fallback: '0'),
              style: GoogleFonts.anuphan(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: _premiumText,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final full = i < rating.floor();
                final half = !full && i < rating;
                return Icon(
                  full
                      ? Icons.star_rounded
                      : half
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
                  size: 16,
                  color: const Color(0xFFE8A117),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              '$count รีวิว',
              style: GoogleFonts.anuphan(
                fontSize: 12,
                color: _mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        // star bars
        Expanded(
          child: Column(
            children: List.generate(5, (i) {
              final star = 5 - i;
              final c = reviews.isEmpty ? 0 : starCounts[star - 1];
              final pct = reviews.isEmpty ? 0.0 : c / reviews.length;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      '$star',
                      style: GoogleFonts.anuphan(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _mutedText,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.star_rounded,
                      size: 11,
                      color: Color(0xFFE8A117),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF3F4F6),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFE8A117),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 20,
                      child: Text(
                        '$c',
                        style: GoogleFonts.anuphan(
                          fontSize: 11,
                          color: _mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final user = asMap(review['user']);
    final rating = _ratingValue(review).round().clamp(0, 5);
    final comment = textOf(review['comment']).trim();
    final name = textOf(user['name'], 'ผู้ใช้ทั่วไป');
    final avatarUrl = textOf(user['avatar_url']);
    final date = _formatRelativeDate(review['created_at']);
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // avatar background color cycle
    final colors = [
      [const Color(0xFF059669), const Color(0xFF6EE7B7)],
      [const Color(0xFF0891B2), const Color(0xFF67E8F9)],
      [const Color(0xFF7C3AED), const Color(0xFFC4B5FD)],
      [const Color(0xFFD97706), const Color(0xFFFDE68A)],
    ];
    final colorPair = colors[(initials.codeUnitAt(0)) % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFEEF2F7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: avatarUrl.isEmpty
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colorPair,
                          )
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl,
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Center(
                              child: Text(
                                initials,
                                style: GoogleFonts.anuphan(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: GoogleFonts.anuphan(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.anuphan(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : _premiumText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 14,
                              color: i < rating
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFD1D5DB),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(width: 3, height: 3, decoration: BoxDecoration(color: _mutedText.withValues(alpha: 0.4), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            style: GoogleFonts.anuphan(
                              fontSize: 11.5,
                              color: _mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // rating badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        '$rating.0',
                        style: GoogleFonts.anuphan(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  comment,
                  style: GoogleFonts.anuphan(
                    fontSize: 13.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : const Color(0xFF374151),
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StickyBookingBar extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> schedules;
  final int? selectedScheduleId;
  final int? selectedPickupPointId;

  const StickyBookingBar({
    super.key,
    required this.trip,
    required this.schedules,
    this.selectedScheduleId,
    this.selectedPickupPointId,
  });

  @override
  Widget build(BuildContext context) {
    final selectedSchedule = _selectedScheduleFor(
      schedules,
      selectedScheduleId,
    );
    final selectedPickupPoint = _selectedPickupPointFor(
      selectedSchedule,
      selectedPickupPointId,
    );
    final joinTripEnabled = _asBool(selectedSchedule['join_trip_enabled']);
    final joinTripPrice = _asNum(selectedSchedule['join_trip_price']);
    final selectedRegionLabel = _pickupRegionLabel(selectedPickupPoint);
    final priceLabel = selectedRegionLabel.isEmpty
        ? 'ราคาเริ่มต้น'
        : 'ราคาสำหรับ $selectedRegionLabel';

    void openBooking({bool joinTrip = false}) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingFlowScreen(
            trip: trip,
            schedules: schedules,
            initialScheduleId: selectedScheduleId,
            initialPickupPointId: selectedPickupPointId,
            initialJoinTrip: joinTrip,
          ),
        ),
      );
    }

    void handleBookingTap({bool joinTrip = false}) {
      final app = context.read<AppProvider>();
      if (app.isLoggedIn) {
        openBooking(joinTrip: joinTrip);
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            onLoginSuccess: () {
              if (context.mounted) openBooking(joinTrip: joinTrip);
            },
          ),
        ),
      );
    }

    final isDark = AppTheme.isDark(context);
    final priceValue = _priceText(
      trip,
      schedule: selectedSchedule,
      pickupPoint: selectedPickupPoint,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.surfaceDark.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? AppTheme.outlineDark.withValues(alpha: 0.5)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : const Color(0xFF0F172A).withValues(alpha: 0.10),
                    blurRadius: 32,
                    offset: const Offset(0, -6),
                  ),
                  if (!isDark)
                    BoxShadow(
                      color: _softAccent.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── price + book row ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // price section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: _softAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    priceLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.anuphan(
                                      fontSize: 11.5,
                                      color: AppTheme.mutedText(context),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                priceValue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.anuphan(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : _premiumText,
                                  height: 1.1,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              if (joinTripEnabled) ...[
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _softAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Join Trip ${_priceText(trip, schedule: selectedSchedule, isJoinTrip: true)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.anuphan(
                                      fontSize: 11,
                                      color: _softAccent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // book button
                        _BookingButton(
                          enabled: schedules.isNotEmpty,
                          onPressed: handleBookingTap,
                        ),
                      ],
                    ),
                  ),
                  // ── join trip button ──────────────────────────────
                  if (joinTripEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _softAccent.withValues(alpha: 0.12),
                                _softAccent.withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _softAccent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: TextButton.icon(
                            onPressed: schedules.isEmpty
                                ? null
                                : () => handleBookingTap(joinTrip: true),
                            style: TextButton.styleFrom(
                              foregroundColor: _softAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.groups_rounded, size: 20),
                            label: Text(
                              joinTripPrice > 0
                                  ? 'จอยทริป · ${money(joinTripPrice)} / คน'
                                  : 'จอยทริป',
                              style: GoogleFonts.anuphan(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _BookingButton({required this.enabled, required this.onPressed});

  @override
  State<_BookingButton> createState() => _BookingButtonState();
}

class _BookingButtonState extends State<_BookingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (widget.enabled) widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient: widget.enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF059669), Color(0xFF065F46)],
                  )
                : null,
            color: widget.enabled ? null : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(22),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.40),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'จองเลย',
                style: GoogleFonts.anuphan(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          icon: Icon(
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

class _QuickInfoItem {
  final IconData icon;
  final String label;

  const _QuickInfoItem({required this.icon, required this.label});
}

class _HighlightItem {
  final String title;
  final String? description;
  final String? icon;

  const _HighlightItem({required this.title, this.description, this.icon});
}

class _MustKnowItem {
  final String name;
  final num price;
  final String priceType;

  const _MustKnowItem({
    required this.name,
    required this.price,
    required this.priceType,
  });

  String get priceTypeLabel =>
      priceType == 'per_person' ? 'ต่อคน' : 'ครั้งเดียว';
}

class _ItinerarySector {
  final String title;
  final List<_ItineraryItem> items;

  const _ItinerarySector({required this.title, required this.items});
}

class _ItineraryItem {
  final int index;
  final String day;
  final String title;
  final String description;

  const _ItineraryItem({
    required this.index,
    required this.day,
    required this.title,
    required this.description,
  });
}

String _tripTitle(Map<String, dynamic> trip) {
  return textOf(trip['title'] ?? trip['name'], 'ทริปที่น่าสนใจ');
}

String _tripShareUrl(Map<String, dynamic> trip) {
  final slug = Uri.encodeComponent(textOf(trip['slug']).trim());
  if (slug.isEmpty) return '${ApiConfig.siteUrl}/trips';
  return '${ApiConfig.siteUrl}/trips/$slug';
}

void _showTripDetailMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

List<String> _galleryImages(Map<String, dynamic> trip) {
  final imageValues = <dynamic>[
    trip['cover_image'],
    trip['thumbnail_image'],
    ...asList(trip['images']),
    ...asList(trip['gallery']),
    ...asList(trip['photos']),
  ];

  return imageValues
      .map((image) {
        if (image is Map) {
          final data = asMap(image);
          return ApiConfig.mediaUrl(
            data['url'] ?? data['image'] ?? data['path'],
          );
        }
        return ApiConfig.mediaUrl(image);
      })
      .where((url) => url.isNotEmpty)
      .toSet()
      .toList();
}

String _tripTypeLabel(String type) {
  return switch (type.toLowerCase()) {
    'trekking' => 'เดินป่า',
    'diving' => 'ดำน้ำ',
    'snorkeling' => 'ดำน้ำตื้น',
    'climbing' => 'ปีนเขา',
    'camping' => 'แคมป์ปิ้ง',
    'kayaking' => 'พายเรือคายัค',
    'cycling' => 'ปั่นจักรยาน',
    _ => type,
  };
}

String _difficultyLabel(String difficulty) {
  return switch (difficulty.toLowerCase()) {
    'easy' => 'ง่าย',
    'medium' || 'moderate' => 'ปานกลาง',
    'hard' || 'difficult' => 'ยาก',
    'extreme' => 'ท้าทายมาก',
    _ => difficulty,
  };
}

List<_QuickInfoItem> _quickInfoItems(Map<String, dynamic> trip) {
  final duration = _durationLabel(trip);
  final typeRaw = textOf(trip['type'] ?? trip['category']).trim();
  final difficultyRaw = textOf(trip['difficulty']).trim();
  final type = typeRaw.isNotEmpty ? _tripTypeLabel(typeRaw) : '';
  final difficulty = difficultyRaw.isNotEmpty
      ? _difficultyLabel(difficultyRaw)
      : '';
  final maxPax = int.tryParse(trip['max_participants']?.toString() ?? '');
  final items = <_QuickInfoItem>[];

  if (duration.isNotEmpty) {
    items.add(_QuickInfoItem(icon: Icons.schedule_rounded, label: duration));
  }

  if (type.isNotEmpty) {
    items.add(_QuickInfoItem(icon: Icons.hiking_rounded, label: type));
  }

  if (difficulty.isNotEmpty) {
    items.add(
      _QuickInfoItem(icon: Icons.family_restroom_rounded, label: difficulty),
    );
  }

  if (maxPax != null && maxPax > 0) {
    items.add(
      _QuickInfoItem(
        icon: Icons.group_rounded,
        label: 'สูงสุด $maxPax คน',
      ),
    );
  }

  final rating = _ratingValue(trip);
  final reviewCount = _reviewCount(trip, const []);
  if (rating >= 4.5 || reviewCount >= 10 || trip['is_popular'] == true) {
    items.add(
      const _QuickInfoItem(
        icon: Icons.local_fire_department_outlined,
        label: 'ยอดนิยม',
      ),
    );
  }

  return items.take(5).toList();
}

String _durationLabel(Map<String, dynamic> trip) {
  final hours = num.tryParse(textOf(trip['duration_hours']));
  if (hours != null && hours > 0) return 'ระยะเวลา ${numberText(hours)} ชม.';

  final days = num.tryParse(textOf(trip['duration_days']));
  if (days != null && days > 0) return 'ระยะเวลา ${numberText(days)} วัน';

  final duration = textOf(trip['duration']).trim();
  if (duration.isEmpty) return '';
  return duration.startsWith('ระยะเวลา') ? duration : 'ระยะเวลา $duration';
}

List<_HighlightItem> _highlightItems(dynamic rawHighlights) {
  if (rawHighlights is String) {
    return rawHighlights
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((item) => _HighlightItem(title: item))
        .toList();
  }

  return asList(rawHighlights)
      .map((item) {
        if (item is String) return _HighlightItem(title: item);
        final data = asMap(item);
        return _HighlightItem(
          title: textOf(data['title'] ?? data['name']),
          description: textOf(data['desc'] ?? data['description']).trim(),
          icon: textOf(data['icon']).trim(),
        );
      })
      .where((item) => item.title.trim().isNotEmpty)
      .toList();
}

List<String> _textItems(dynamic raw) {
  if (raw is String) {
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  return asList(raw)
      .map((item) {
        if (item is String) return item.trim();
        final data = asMap(item);
        return textOf(
          data['title'] ??
              data['name'] ??
              data['label'] ??
              data['description'] ??
              data['desc'] ??
              data['text'],
        ).trim();
      })
      .where((item) => item.isNotEmpty)
      .toList();
}

List<_MustKnowItem> _mustKnowItems(Map<String, dynamic> trip) {
  final raw = trip['must_know'];
  if (raw is String) {
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map(
          (name) =>
              _MustKnowItem(name: name, price: 0, priceType: 'per_booking'),
        )
        .toList();
  }

  final mustKnow = asMap(raw);
  final rawItems = mustKnow.isNotEmpty
      ? asList(mustKnow['items'])
      : asList(raw);

  return rawItems
      .asMap()
      .entries
      .map((entry) {
        final item = entry.value;
        final data = asMap(item);
        final name = item is String
            ? item.trim()
            : textOf(data['name'] ?? data['title'] ?? data['label']).trim();
        if (name.isEmpty) return null;

        return _MustKnowItem(
          name: name,
          price: _asNum(data['price']),
          priceType: data['price_type'] == 'per_person'
              ? 'per_person'
              : 'per_booking',
        );
      })
      .whereType<_MustKnowItem>()
      .toList();
}

IconData? _iconFor(String? name) {
  switch (name?.toLowerCase()) {
    case 'star':
      return Icons.star_rounded;
    case 'beach':
      return Icons.beach_access_rounded;
    case 'hiking':
      return Icons.hiking_rounded;
    case 'camera':
      return Icons.photo_camera_outlined;
    case 'food':
      return Icons.restaurant_rounded;
    case 'hotel':
      return Icons.hotel_rounded;
    default:
      return null;
  }
}

List<_ItinerarySector> _itinerarySectors(
  Map<String, dynamic> trip, {
  String? regionKey,
  String? regionLabel,
}) {
  final raw = trip['itinerary'] ?? trip['itineraries'] ?? trip['program'];
  final sectors = <_ItinerarySector>[];
  final flatItems = <_ItineraryItem>[];
  final normalizedRegionKey = regionKey?.trim();
  final normalizedRegionLabel = regionLabel?.trim();

  void addFlatItem(dynamic value) {
    if (!_itineraryEntryMatchesRegion(
      value,
      normalizedRegionKey,
      normalizedRegionLabel,
    )) {
      return;
    }

    final item = _itineraryItemFrom(value, flatItems.length + 1);
    if (item != null) flatItems.add(item);
  }

  void addSector(Map<String, dynamic> sectorData, List<dynamic> rawItems) {
    final explicitSectorRegionValues = _itineraryExplicitRegionValues(
      sectorData,
    );
    final sectorRegionValues = _itineraryRegionValues(sectorData);
    final sectorMatches =
        sectorRegionValues.isNotEmpty &&
        sectorRegionValues.any(
          (value) =>
              _regionTextMatches(value, normalizedRegionKey) ||
              _regionTextMatches(value, normalizedRegionLabel),
        );
    final explicitSectorMismatch =
        explicitSectorRegionValues.isNotEmpty && !sectorMatches;
    final visibleRawItems = explicitSectorMismatch
        ? const <dynamic>[]
        : sectorMatches
        ? rawItems
        : rawItems
              .where(
                (value) => _itineraryEntryMatchesRegion(
                  value,
                  normalizedRegionKey,
                  normalizedRegionLabel,
                ),
              )
              .toList();
    final items = <_ItineraryItem>[];
    for (final value in visibleRawItems) {
      final item = _itineraryItemFrom(value, items.length + 1);
      if (item != null) items.add(item);
    }

    if (items.isNotEmpty) {
      final title = _itinerarySectorTitle(sectorData, sectors.length + 1);
      sectors.add(
        _ItinerarySector(
          title: title.trim().isNotEmpty
              ? title.trim()
              : 'ช่วงที่ ${sectors.length + 1}',
          items: items,
        ),
      );
    }
  }

  if (raw is String) {
    for (final line in raw.split('\n')) {
      final text = line.trim();
      if (text.isNotEmpty) addFlatItem(text);
    }
    return flatItems.isEmpty
        ? const []
        : [_ItinerarySector(title: 'แผนการเดินทาง', items: flatItems)];
  }

  if (raw is Map) {
    final map = asMap(raw);
    final nestedItems = _nestedItineraryItems(map);
    if (nestedItems.isNotEmpty) {
      addSector(map, nestedItems);
    } else {
      addFlatItem(map);
    }
    return sectors.isNotEmpty
        ? sectors
        : flatItems.isEmpty
        ? const []
        : [_ItinerarySector(title: 'แผนการเดินทาง', items: flatItems)];
  }

  for (final entry in asList(raw)) {
    final map = asMap(entry);
    final nestedItems = _nestedItineraryItems(map);
    if (nestedItems.isNotEmpty) {
      addSector(map, nestedItems);
    } else {
      addFlatItem(entry);
    }
  }

  if (flatItems.isNotEmpty) {
    sectors.insert(
      0,
      _ItinerarySector(title: 'แผนการเดินทาง', items: flatItems),
    );
  }

  return sectors;
}

bool _itineraryEntryMatchesRegion(
  dynamic value,
  String? regionKey,
  String? regionLabel,
) {
  if ((regionKey == null || regionKey.isEmpty) &&
      (regionLabel == null || regionLabel.isEmpty)) {
    return true;
  }
  if (value is String) {
    return _regionTextMatches(value, regionKey) ||
        _regionTextMatches(value, regionLabel);
  }

  final data = asMap(value);
  if (data.isEmpty) return false;

  final entryValues = _itineraryRegionValues(data);

  if (entryValues.isEmpty) return false;
  return entryValues.any(
    (value) =>
        _regionTextMatches(value, regionKey) ||
        _regionTextMatches(value, regionLabel),
  );
}

List<dynamic> _nestedItineraryItems(Map<String, dynamic> data) {
  for (final key in ['items', 'itinerary', 'itineraries', 'days', 'program']) {
    final items = asList(data[key]);
    if (items.isNotEmpty) return items;
  }

  return const [];
}

String _itineraryRegionKey(Map<String, dynamic> data) {
  final region = textOf(data['region']).trim();
  if (region.isNotEmpty) return region;
  return textOf(data['region_label']).trim();
}

Set<String> _itineraryExplicitRegionValues(Map<String, dynamic> data) {
  final region = textOf(data['region']).trim();
  final label = textOf(data['region_label']).trim();

  return <String>{if (region.isNotEmpty) region, if (label.isNotEmpty) label};
}

Set<String> _itineraryRegionValues(Map<String, dynamic> data) {
  final key = _itineraryRegionKey(data);
  final label = textOf(data['region_label']).trim();
  final sector = textOf(
    data['sector'] ?? data['sector_name'] ?? data['section'] ?? data['part'],
  ).trim();

  return <String>{
    if (key.isNotEmpty) key,
    if (label.isNotEmpty) label,
    if (sector.isNotEmpty) sector,
  };
}

bool _regionTextMatches(String? value, String? selectedRegion) {
  final text = value?.trim().toLowerCase();
  final region = selectedRegion?.trim().toLowerCase();
  if (text == null || text.isEmpty || region == null || region.isEmpty) {
    return false;
  }

  return text == region || text.contains(region) || region.contains(text);
}

String _itinerarySectorTitle(Map<String, dynamic> data, int index) {
  return textOf(
    data['sector'] ??
        data['sector_name'] ??
        data['section'] ??
        data['part'] ??
        data['region_label'] ??
        data['region'] ??
        data['title'] ??
        data['name'],
    'ภาคที่ $index',
  );
}

_ItineraryItem? _itineraryItemFrom(dynamic value, int index) {
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return _ItineraryItem(
      index: index,
      day: '$index',
      title: text,
      description: '',
    );
  }

  final data = asMap(value);
  if (data.isEmpty) return null;

  final day = textOf(
    data['day'] ?? data['day_number'] ?? data['order'] ?? data['sort_order'],
    '$index',
  ).trim();
  final description = textOf(
    data['description'] ?? data['desc'] ?? data['detail'] ?? data['content'],
  ).trim();
  final title = textOf(
    data['title'] ?? data['name'] ?? data['activity'],
    description.isNotEmpty ? 'ช่วงที่ $index' : '',
  ).trim();

  if (title.isEmpty && description.isEmpty) return null;

  return _ItineraryItem(
    index: index,
    day: day,
    title: title.isNotEmpty ? title : 'ช่วงที่ $index',
    description: description,
  );
}

double _ratingValue(Map<String, dynamic> data) {
  return double.tryParse(textOf(data['rating'])) ?? 0;
}

int _reviewCount(Map<String, dynamic> trip, List<dynamic> reviews) {
  final count = int.tryParse(textOf(trip['review_count']));
  if (count != null && count > 0) return count;
  return reviews.length;
}

int? _validDropdownValue(int? selected, Iterable<int> values) {
  final ids = values.toList();
  if (ids.isEmpty) return null;
  if (selected != null && ids.contains(selected)) return selected;
  return ids.first;
}

bool _scheduleHasPickupRegion(Map<String, dynamic> schedule, String regionKey) {
  return asList(
    schedule['pickup_points'],
  ).map(asMap).any((point) => _pickupRegionKey(point) == regionKey);
}

String _regionSummary(Map<String, dynamic> schedule, {String? regionKey}) {
  final regions = asList(schedule['pickup_points'])
      .map(asMap)
      .where(
        (point) =>
            regionKey == null ||
            regionKey.isEmpty ||
            _pickupRegionKey(point) == regionKey,
      )
      .map(
        (point) => textOf(
          point['region_label'],
          textOf(point['region'], 'ไม่ระบุภูมิภาค'),
        ),
      )
      .where((region) => region.trim().isNotEmpty)
      .toSet()
      .toList();

  if (regions.isEmpty) return '';
  if (regions.length == 1) return regions.first;
  return '${regions.length} ภูมิภาค';
}

String _scheduleTravelDateText(Map<String, dynamic> schedule) {
  final start = dateText(schedule['departure_date']);
  if (start == '-') return 'รอระบุวัน';

  final end = dateText(schedule['return_date']);
  if (end == '-' || end == start) return start;

  return '$start - $end';
}

String _pickupRegionKey(Map<String, dynamic> point) {
  final region = textOf(point['region']).trim();
  if (region.isNotEmpty) return region;
  return textOf(point['region_label']).trim();
}

String _pickupPriceText(dynamic value) {
  final number = num.tryParse(textOf(value));
  if (number == null || number <= 0) return 'ไม่มีค่าใช้จ่ายเพิ่ม';
  return '+${money(number)}';
}

Map<String, dynamic> _selectedScheduleFor(
  List<dynamic> schedules,
  int? selectedScheduleId,
) {
  if (schedules.isEmpty) return <String, dynamic>{};

  return asMap(
    schedules.firstWhere(
      (item) => asMap(item)['id'].toString() == selectedScheduleId.toString(),
      orElse: () => schedules.first,
    ),
  );
}

Map<String, dynamic> _selectedPickupPointFor(
  Map<String, dynamic> schedule,
  int? selectedPickupPointId,
) {
  final points = asList(schedule['pickup_points']);
  if (points.isEmpty) return <String, dynamic>{};

  return asMap(
    points.firstWhere(
      (item) =>
          asMap(item)['id'].toString() == selectedPickupPointId.toString(),
      orElse: () => points.first,
    ),
  );
}

String _pickupRegionLabel(Map<String, dynamic> point) {
  return textOf(point['region_label'], textOf(point['region'])).trim();
}

String _priceText(
  Map<String, dynamic> trip, {
  Map<String, dynamic>? schedule,
  Map<String, dynamic>? pickupPoint,
  bool isJoinTrip = false,
}) {
  final pickupPrice = num.tryParse(textOf(pickupPoint?['price']));
  final dynamic value;
  if (isJoinTrip) {
    value =
        schedule?['join_trip_price'] ??
        schedule?['effective_price'] ??
        schedule?['price'] ??
        trip['price_per_person'] ??
        trip['price'] ??
        trip['start_price'];
  } else if (pickupPrice != null && pickupPrice > 0) {
    value = pickupPrice;
  } else {
    value =
        schedule?['effective_price'] ??
        schedule?['price'] ??
        trip['price_per_person'] ??
        trip['price'] ??
        trip['start_price'];
  }
  final number = num.tryParse(textOf(value));
  if (number == null || number <= 0) return 'ดูราคา';
  return '${money(number)} / คน';
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'y';
}

num _asNum(dynamic value) {
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatRelativeDate(dynamic value) {
  final raw = textOf(value).trim();
  if (raw.isEmpty) return '';

  try {
    final date = DateTime.parse(raw);
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return '${diff.inDays} วันที่แล้ว';
    if (diff.inHours > 0) return '${diff.inHours} ชม. ที่แล้ว';
    return 'เมื่อครู่';
  } catch (_) {
    return '';
  }
}
