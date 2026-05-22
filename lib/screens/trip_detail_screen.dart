import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/wishlist_provider.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart' hide TravelSliverAppBar;
import 'booking_flow_screen.dart';
import 'login_screen.dart';

part 'trip_detail_hero.part.dart';
part 'trip_detail_info.part.dart';
part 'trip_detail_plan.part.dart';
part 'trip_detail_content.part.dart';
part 'trip_detail_reviews.part.dart';
part 'trip_detail_booking.part.dart';
part 'trip_detail_widgets.part.dart';
part 'trip_detail_helpers.part.dart';

const Color _premiumText = Color(0xFF0F172A);
const Color _mutedText = Color(0xFF64748B);
const Color _softAccent = Color(0xFF10B981);
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

  /// True when at least one review of this trip carries a photo.
  bool get _hasCommunityPhotos => widget.reviews.any(
        (r) => asList(asMap(r)['images']).any((u) => u.toString().isNotEmpty),
      );

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
    final wishlist = context.read<WishlistProvider>();
    if (!wishlist.loaded) await wishlist.load();
    if (!mounted || _favoriteSlug != slug) return;
    setState(() => _isFavorite = wishlist.contains(slug));
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

    final added = await context.read<WishlistProvider>().toggle(widget.trip);
    if (!mounted) return;
    setState(() => _isFavorite = added);
    _showTripDetailMessage(
      context,
      added ? 'บันทึกทริปที่สนใจแล้ว' : 'นำออกจากทริปที่สนใจแล้ว',
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
                      PhotoGallerySection(trip: widget.trip),
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
                      if (_hasCommunityPhotos) ...[
                        CommunityPhotosSection(reviews: widget.reviews),
                        const SizedBox(height: 16),
                      ],
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

