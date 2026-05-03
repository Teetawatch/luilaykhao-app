import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart' hide TravelSliverAppBar;
import 'booking_flow_screen.dart';
import 'login_screen.dart';

const Color _premiumText = Color(0xFF0F172A);
const Color _mutedText = Color(0xFF64748B);
const Color _softAccent = Color(0xFF10B981);
const Color _chipBackground = Color(0xFFECFDF5);
const double _contentOverlap = 32;

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

    final schedules = await app.schedules(slug);
    final reviews = await app.tripReviews(tripData['id'] ?? 0);

    return <String, dynamic>{'schedules': schedules, 'reviews': reviews};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            _trip == null;

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.background(context),
            body: Center(
              child: Text(
                'เกิดข้อผิดพลาด: ${snapshot.error}',
                style: GoogleFonts.anuphan(color: _premiumText),
                textAlign: TextAlign.center,
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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _syncInitialSelection();
  }

  @override
  void didUpdateWidget(covariant TravelDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedules != widget.schedules) {
      _syncInitialSelection();
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
    _selectedPickupRegionKey =
        point.isNotEmpty ? _pickupRegionKey(point) : null;
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

  @override
  Widget build(BuildContext context) {
    final heroHeight = _heroHeight(context);
    final bottomBarHeight = widget.isLoading ? 0.0 : 112.0;

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

  const TravelSliverAppBar({
    super.key,
    required this.trip,
    required this.isLoading,
    required this.isCollapsed,
    required this.expandedHeight,
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
      backgroundColor: isCollapsed ? Colors.white : Colors.transparent,
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
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        FloatingActionIconButton(
          icon: Icons.favorite_border_rounded,
          isCollapsed: isCollapsed,
          onPressed: () {},
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
                    errorWidget: (_, __, ___) =>
                        const _GalleryImageFallback(),
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
  final VoidCallback onPressed;

  const FloatingActionIconButton({
    super.key,
    required this.icon,
    required this.isCollapsed,
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
    final foreground = widget.isCollapsed ? _premiumText : Colors.white;
    final background = widget.isCollapsed
        ? Colors.white.withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.18);
    final border = widget.isCollapsed
        ? Colors.black.withValues(alpha: 0.06)
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
    if (isLoading) {
      return _PremiumCard(
        padding: const EdgeInsets.all(24),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 120, height: 26, radius: 13),
            SizedBox(height: 16),
            Skeleton(width: double.infinity, height: 34, radius: 12),
            SizedBox(height: 10),
            Skeleton(width: 220, height: 18, radius: 9),
            SizedBox(height: 20),
            Skeleton(width: double.infinity, height: 40, radius: 20),
          ],
        ),
      );
    }

    return _PremiumCard(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RatingSummary(trip: trip, reviews: reviews),
              if (trip['category_name'] != null)
                _InfoChip(
                  icon: Icons.tag_rounded,
                  label: textOf(trip['category_name']),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _tripTitle(trip),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _premiumText,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 18,
                color: _softAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  textOf(trip['location'], 'ประเทศไทย'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 14,
                    color: _mutedText,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),
          QuickInfoChips(trip: trip),
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map((chip) => _InfoChip(icon: chip.icon, label: chip.label))
          .toList(),
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

    final description = textOf(trip['description'], 'ไม่มีคำอธิบาย');

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.event_available_outlined,
            title: 'เลือกแผนการเดินทาง',
          ),
          const SizedBox(height: 16),
          // 1. ภูมิภาคที่จะขึ้นรถ
          if (regionMap.isEmpty)
            _EmptySelectionNotice(
              icon: Icons.map_outlined,
              text: 'ยังไม่มีภูมิภาคสำหรับทริปนี้',
            )
          else
            _PremiumDropdown<String>(
              key: ValueKey('region-$regionValue'),
              label: 'ภูมิภาคที่จะขึ้นรถ',
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
          const SizedBox(height: 12),
          // 2. วันเดินทาง
          if (scheduleMaps.isEmpty)
            _EmptySelectionNotice(
              icon: Icons.calendar_month_outlined,
              text: 'ยังไม่มีวันเดินทางที่เปิดจอง',
            )
          else ...[
            _PremiumDropdown<int>(
              key: ValueKey('schedule-$scheduleValue'),
              label: 'วันเดินทาง',
              icon: Icons.calendar_month_rounded,
              value: scheduleValue,
              items: scheduleMaps.map((schedule) {
                final id = int.parse(schedule['id'].toString());
                final seats = textOf(schedule['available_seats'], '0');
                final regionSummary = _regionSummary(
                  schedule,
                  regionKey: regionKey,
                );

                return DropdownMenuItem<int>(
                  value: id,
                  child: _DropdownText(
                    title: _scheduleTravelDateText(schedule),
                    subtitle: regionSummary.isEmpty
                        ? 'เหลือ $seats ที่'
                        : 'เหลือ $seats ที่ • $regionSummary',
                  ),
                );
              }).toList(),
              onChanged: onScheduleChanged,
            ),
            const SizedBox(height: 12),
            // 3. จุดที่จะขึ้นรถ
            if (pickupMaps.isEmpty)
              _EmptySelectionNotice(
                icon: Icons.place_outlined,
                text: 'ยังไม่มีจุดขึ้นรถสำหรับรอบนี้',
              )
            else
              _PremiumDropdown<int>(
                key: ValueKey('pickup-$pickupValue'),
                label: 'จุดที่จะขึ้นรถ',
                icon: Icons.place_rounded,
                value: pickupValue,
                items: pickupMaps.map((point) {
                  final id = int.parse(point['id'].toString());
                  final location = textOf(point['pickup_location']).trim();
                  final price = _pickupPriceText(point['price']);

                  return DropdownMenuItem<int>(
                    value: id,
                    child: _DropdownText(
                      title: location.isNotEmpty ? location : 'ไม่ระบุจุดขึ้นรถ',
                      subtitle: price,
                    ),
                  );
                }).toList(),
                onChanged: onPickupChanged,
              ),
          ],
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
          const _SectionHeader(
            icon: Icons.route_rounded,
            title: 'แผนการเดินทาง',
          ),
          const SizedBox(height: 20),
          ...sectors.asMap().entries.map(
            (entry) => _ItinerarySectorTile(
              sector: entry.value,
              index: entry.key,
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
  final bool initiallyExpanded;

  const _ItinerarySectorTile({
    required this.sector,
    required this.index,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: _softAccent,
          collapsedIconColor: _mutedText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.anuphan(
                  color: _softAccent,
                  fontSize: 13,
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
              color: _premiumText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            '${sector.items.length} รายการ',
            style: GoogleFonts.anuphan(
              color: _mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            ...sector.items.asMap().entries.map(
              (entry) => _ItineraryTimelineItem(
                item: entry.value,
                isLast: entry.key == sector.items.length - 1,
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

  const _ItineraryTimelineItem({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final marker = item.day.isNotEmpty ? item.day : '${item.index}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: _softAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _softAccent.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    marker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: _softAccent,
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
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.anuphan(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _premiumText,
                      height: 1.3,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: GoogleFonts.anuphan(
                        fontSize: 14,
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
    final user = asMap(review['user']);
    final rating = _ratingValue(review).round().clamp(0, 5);
    final comment = textOf(review['comment']).trim();
    final name = textOf(user['name'], 'ผู้ใช้ทั่วไป');
    final avatarUrl = textOf(user['avatar_url']);
    final date = _formatRelativeDate(review['created_at']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F5F4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE5F0EE),
                  backgroundImage: avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.anuphan(
                            color: _softAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        )
                      : null,
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
                          color: _premiumText,
                        ),
                      ),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: i < rating
                                  ? const Color(0xFFE8A117)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            style: GoogleFonts.anuphan(
                              fontSize: 11,
                              color: _mutedText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                comment,
                style: GoogleFonts.anuphan(
                  fontSize: 14,
                  color: const Color(0xFF374151),
                  height: 1.6,
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
    final selectedRegionLabel = _pickupRegionLabel(selectedPickupPoint);
    final priceLabel = selectedRegionLabel.isEmpty
        ? 'ราคาเริ่มต้น'
        : 'ราคาสำหรับ $selectedRegionLabel';

    void openBooking() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingFlowScreen(
            trip: trip,
            schedules: schedules,
            initialScheduleId: selectedScheduleId,
            initialPickupPointId: selectedPickupPointId,
          ),
        ),
      );
    }

    void handleBookingTap() {
      final app = context.read<AppProvider>();
      if (app.isLoggedIn) {
        openBooking();
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            onLoginSuccess: () {
              if (context.mounted) openBooking();
            },
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface(context).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.border(context), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          priceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.anuphan(
                            fontSize: 12,
                            color: AppTheme.mutedText(context),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _priceText(
                            trip,
                            schedule: selectedSchedule,
                            pickupPoint: selectedPickupPoint,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.anuphan(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.onSurface(context),
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: schedules.isEmpty ? null : handleBookingTap,
                    style:
                        ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _softAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ).copyWith(
                          overlayColor: WidgetStatePropertyAll(
                            Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'จองตอนนี้',
                          style: GoogleFonts.anuphan(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
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

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _softAccent.withValues(alpha: 0.12),
                _softAccent.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _softAccent.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, size: 20, color: _softAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _premiumText,
              height: 1.25,
              letterSpacing: -0.2,
            ),
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
    this.iconBackground = const Color(0xFFF7FAF9),
  });

  @override
  Widget build(BuildContext context) {
    if (title.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.anuphan(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _premiumText,
                    height: 1.45,
                  ),
                ),
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description!,
                    style: GoogleFonts.anuphan(
                      fontSize: 13,
                      color: _mutedText,
                      height: 1.55,
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _chipBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _softAccent.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _softAccent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.anuphan(
                fontSize: 12,
                color: _softAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
            prefixIcon: Icon(icon, color: _softAccent, size: 21),
            prefixIconConstraints: const BoxConstraints(minWidth: 42),
            labelStyle: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w700,
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
  final difficulty = difficultyRaw.isNotEmpty ? _difficultyLabel(difficultyRaw) : '';
  final items = <_QuickInfoItem>[];

  if (duration.isNotEmpty) {
    items.add(_QuickInfoItem(icon: Icons.schedule_rounded, label: duration));
  } else {
    items.add(
      const _QuickInfoItem(
        icon: Icons.schedule_rounded,
        label: 'ระยะเวลา 4 ชม.',
      ),
    );
  }

  items.add(
    _QuickInfoItem(
      icon: Icons.hiking_rounded,
      label: type.isNotEmpty ? type : 'เดินป่า',
    ),
  );
  items.add(
    _QuickInfoItem(
      icon: Icons.family_restroom_rounded,
      label: difficulty.isNotEmpty ? difficulty : 'เหมาะกับครอบครัว',
    ),
  );
  items.add(
    const _QuickInfoItem(
      icon: Icons.photo_camera_outlined,
      label: 'จุดถ่ายรูป',
    ),
  );

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
}) {
  final pickupPrice = num.tryParse(textOf(pickupPoint?['price']));
  final value = pickupPrice != null && pickupPrice > 0
      ? pickupPrice
      : schedule?['effective_price'] ??
            schedule?['price'] ??
            trip['price_per_person'] ??
            trip['price'] ??
            trip['start_price'];
  final number = num.tryParse(textOf(value));
  if (number == null || number <= 0) return 'ดูราคา';
  return '${money(number)} / คน';
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
