import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show ScrollDirection, RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../providers/trip_alert_provider.dart';
import '../providers/wishlist_provider.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../widgets/min_tap_target.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/elevation_profile_chart.dart';
import '../widgets/flash_countdown_pill.dart';
import '../widgets/moderation_sheet.dart';
import '../widgets/pickup_vehicle_guide.dart';
import '../widgets/route_map_card.dart';
import '../widgets/travel_widgets.dart' hide TravelSliverAppBar;
import '../widgets/weather_card.dart';
import 'booking_flow_screen.dart';
import 'group_room_screen.dart';
import 'login_screen.dart';
import 'trip_feed_screen.dart';
import 'waitlist_screen.dart';

part 'trip_detail_hero.part.dart';
part 'trip_detail_info.part.dart';
part 'trip_detail_plan.part.dart';
part 'trip_detail_content.part.dart';
part 'trip_detail_reviews.part.dart';
part 'trip_detail_readiness.part.dart';
part 'trip_detail_related.part.dart';
part 'trip_detail_booking.part.dart';
part 'trip_detail_widgets.part.dart';
part 'trip_detail_helpers.part.dart';
part 'all_reviews.part.dart';

const Color _premiumText = Color(0xFF0F172A);
const Color _mutedText = Color(0xFF64748B);
const Color _softAccent = Color(0xFF10B981);
/// ความสูงของขอบโค้งที่การ์ดเนื้อหากินขึ้นไปทับรูปปก และเป็นระยะที่มุมโค้ง
/// ไล่ลงมาในแนวตั้ง
///
/// มากกว่า [AppTheme.radiusXl] เพราะรูปทรงนี้เป็น superellipse ไม่ใช่ส่วนโค้ง
/// วงกลม — มันต้องการพื้นที่มากกว่าเพื่อให้ได้ความโค้งที่ตาอ่านว่าเท่ากับ
/// รัศมี 32 แต่เข้าหาขอบตรงได้นุ่มกว่า (เทียบตัวเลขไว้ที่ [_SquircleCapPainter])
const double _contentOverlap = 40;

/// ระยะที่มุมโค้งคลี่ออกไปในแนวนอน กว้างกว่าแนวตั้งตามแบบมุมหน้าต่างของ iOS
const double _contentCornerSpread = 48;

/// ความสูงของเฉดที่ปลายรูปปกจางลงหาสีการ์ด วัดจากขอบล่างของแถบรูปขึ้นไป
/// (รวมช่วง [_contentOverlap] ที่อยู่หลังขอบโค้ง เพื่อให้เนื้อรูปที่โผล่ตรงมุม
/// โค้งจางเท่ากับที่อยู่เหนือมันพอดี ไม่งั้นจะเห็นรอยสว่างวาบตรงมุม)
const double _heroVeilHeight = 112;

/// ความทึบสูงสุดของเฉดนั้น ไม่ทึบสนิทเพราะยังอยากให้เห็นเนื้อรูปลอดมุมโค้ง
const double _heroVeilOpacity = 0.62;

/// แท็บนำทางในหน้าทริป เรียงตามลำดับที่คนตัดสินใจจริง — เลือกวันก่อน แล้วค่อย
/// ดูรายละเอียด เตรียมตัว และฟังเสียงคนที่ไปมาแล้ว
///
/// หัวเรื่อง (ชื่อทริป/เรตติ้ง/สถิติ) อยู่เหนือจุดยึดของแท็บแรก จึงไม่มีแท็บ
/// ของตัวเอง — เลื่อนอยู่บนสุดจะถือว่าอยู่แท็บแรก
const List<String> _tabLabels = ['วันเดินทาง', 'รายละเอียด', 'เตรียมตัว', 'รีวิว'];
const double _tabBarHeight = 46;

// ── Apple HIG system colors (iOS) ───────────────────────────────────────────
// Semantic status colors with the light / dark variants from Apple's system
// palette, used for state (full / low seats / warnings) instead of ad-hoc
// values so they read correctly in both color schemes.
const Color _systemRed = Color(0xFFE11D48);
const Color _systemRedDark = Color(0xFFE11D48);
const Color _systemOrange = Color(0xFFFF9500);
const Color _systemOrangeDark = Color(0xFFFF9F0A);
const Color _systemGreen = Color(0xFF34C759);
const Color _systemGreenDark = Color(0xFF30D158);

Color _appleRed(bool isDark) => isDark ? _systemRedDark : _systemRed;
Color _appleOrange(bool isDark) => isDark ? _systemOrangeDark : _systemOrange;
Color _appleGreen(bool isDark) => isDark ? _systemGreenDark : _systemGreen;

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
  // Silent ~25s refresh so seat counts stay current while the page is open.
  List<dynamic>? _liveSchedules;
  Timer? _seatPoll;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    // ไกด์ประเภทรถรับ-ส่ง — ใช้เมื่อผู้ใช้เลือกจุดรับที่มีค่าใช้จ่ายเพิ่ม
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppProvider>().ensurePickupVehicleClasses();
    });
    _seatPoll = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _refreshSchedules(),
    );
  }

  @override
  void dispose() {
    _seatPoll?.cancel();
    super.dispose();
  }

  Future<void> _refreshSchedules() async {
    if (!mounted) return;
    try {
      final app = Provider.of<AppProvider>(context, listen: false);
      final schedules = await app.schedules(widget.slug ?? '');
      if (mounted) setState(() => _liveSchedules = schedules);
    } catch (_) {
      // transient — keep current data
    }
  }

  Future<Map<String, dynamic>> _loadData() async {
    final app = Provider.of<AppProvider>(context, listen: false);
    final slug = widget.slug ?? '';

    final tripData = await app.trip(slug);
    if (mounted) {
      setState(() {
        _trip = tripData;
        // The show payload already embeds this trip's schedules, so seed from
        // them right away. The booking/date details then render immediately and
        // survive a slow or failed separate schedules fetch below — build()'s
        // hasUsableSchedules guard keeps the page off the error screen too.
        final embedded = tripData['schedules'];
        if (_liveSchedules == null && embedded is List && embedded.isNotEmpty) {
          _liveSchedules = List<dynamic>.from(embedded);
        }
      });
    }
    // Remember this trip for the home "ดูล่าสุด" rail.
    app.recordRecentTrip(tripData);

    final tripId = int.tryParse(tripData['id']?.toString() ?? '') ?? 0;
    // Schedules are essential (booking dates / pickup) so a failure here must
    // propagate and surface the retry screen. Reviews are supplementary, so a
    // transient review failure degrades to an empty list rather than blanking
    // the whole page — this is what used to make the page "load incompletely".
    final embeddedSchedules =
        (tripData['schedules'] as List?)?.cast<dynamic>() ?? const <dynamic>[];
    final results = await Future.wait([
      // Fall back to the schedules embedded in the trip payload if the dedicated
      // refresh fails, so the page never ends up with empty booking details.
      app.schedules(slug).catchError((_) => embeddedSchedules),
      if (tripId > 0)
        app.tripReviews(tripId).catchError((_) => <dynamic>[])
      else
        Future.value(<dynamic>[]),
    ]);

    final schedules = results[0].isNotEmpty ? results[0] : embeddedSchedules;
    return <String, dynamic>{
      'schedules': schedules,
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

        // A silent-refresh poll may have populated schedules even when the
        // initial load errored; only fall back to the error screen when we have
        // nothing usable to show. Previously this was gated on `_trip == null`
        // alone, so a schedules/reviews failure after the trip header loaded
        // rendered a half-empty page with no way to retry.
        final hasUsableSchedules = _liveSchedules?.isNotEmpty ?? false;

        if (snapshot.hasError && !hasUsableSchedules) {
          return Scaffold(
            backgroundColor: AppTheme.background(context),
            appBar: AppBar(
              backgroundColor: AppTheme.surface(context),
              elevation: 0,
              leading: IconButton(
                tooltip: 'ย้อนกลับ',
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
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        size: 36,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'โหลดข้อมูลไม่สำเร็จ',
                      style: appFont(
                        fontSize: AppText.sizeTitle,
                        fontWeight: FontWeight.w900,
                        color: _premiumText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต\nแล้วลองใหม่อีกครั้ง',
                      textAlign: TextAlign.center,
                      style: appFont(
                        fontSize: AppText.sizeBody,
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
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        'ลองใหม่',
                        style: appFont(
                          fontSize: AppText.sizeSubtitle,
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
          schedules: _liveSchedules ??
              (snapshot.data?['schedules'] as List<dynamic>? ?? const []),
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

  /// จุดยึดของแต่ละกลุ่มเนื้อหา ใช้ทั้งตอนกดแท็บ (กระโดดไป) และตอนเลื่อน
  /// (หาว่าตอนนี้อยู่กลุ่มไหน)
  final List<GlobalKey> _tabAnchors = List.generate(
    _tabLabels.length,
    (_) => GlobalKey(),
  );
  int _activeTab = 0;

  /// กลุ่มไหนมีเนื้อหาให้ดูจริง — ทริปในประเทศที่ไม่มีสิ่งที่ควรรู้/ควรเตรียม/
  /// สิ่งที่รวม/FAQ/นโยบาย จะไม่มีอะไรในกลุ่ม "เตรียมตัว" เลย แท็บที่กดแล้ว
  /// กระโดดไปช่องว่างแย่กว่าไม่มีแท็บ
  ///
  /// ต้องคำนวณใน build() ก่อนสร้าง app bar ไม่ใช่ใน _buildSections ซึ่งถูก
  /// เรียกทีหลังในเฟรมเดียวกัน — ไม่งั้นแท็บจะช้าไปหนึ่งเฟรม
  List<bool> _tabHasContent = List.filled(_tabLabels.length, true);

  /// อีก 3 กลุ่มมีใบที่เรนเดอร์เสมออยู่แล้ว (เลือกวัน / ไหวไหม / รีวิว)
  /// กลุ่ม "เตรียมตัว" เป็นกลุ่มเดียวที่ทุกใบเป็น conditional หมด
  List<bool> _computeTabContent() {
    final trip = widget.trip;
    return [
      true,
      true,
      trip['is_international'] == true ||
          _mustKnowItems(trip).isNotEmpty ||
          textOf(asMap(trip['must_know'])['remarks']).trim().isNotEmpty ||
          _textItems(trip['preparations']).isNotEmpty ||
          asList(trip['inclusions']).any((e) => textOf(e).trim().isNotEmpty) ||
          asList(trip['exclusions']).any((e) => textOf(e).trim().isNotEmpty) ||
          _faqItems(trip['faqs']).isNotEmpty ||
          asList(asMap(trip['cancellation_policy'])['tiers']).isNotEmpty,
      true,
    ];
  }

  /// ระหว่างเลื่อนไปตามที่กดแท็บ อย่าให้ตัวจับกลุ่มแย่งเปลี่ยนแท็บกลับ
  bool _isJumpingToTab = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _syncInitialSelection();
    _syncFavoriteState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAlertState());
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
    if (!_scrollController.hasClients) return;

    // จุดที่แถบหุบสุดจริงคือตอนที่รูปเหลือเท่าส่วนที่ถูกยึดไว้ด้านบนพอดี
    // ห้ามใช้ตัวเลขคงที่แทน padding บน: ตอนเพิ่มแถบแท็บเข้ามา ส่วนที่ถูกยึด
    // โตขึ้นอีก 46 แล้วค่าคงที่เดิมทำให้ธงหุบมาช้ากว่าของจริงเกือบ 50px —
    // ช่วงนั้นแถบขาวโล่งไม่มีทั้งชื่อทริปและแท็บ
    final collapseAt = _heroHeight(context) - _pinnedTopExtent();
    final shouldCollapse = _scrollController.offset > collapseAt - 8;

    if (shouldCollapse != _isCollapsed) {
      setState(() => _isCollapsed = shouldCollapse);
    }
    _syncActiveTab();
  }

  /// ความสูงที่ถูกแถบบนยึดไว้ตอนหุบสุด — เนื้อหาที่อยู่เหนือเส้นนี้คือส่วนที่
  /// มองไม่เห็นแล้ว จึงใช้เป็นทั้งเส้นตัดสินว่าแถบหุบหรือยัง และว่าเลื่อนพ้น
  /// กลุ่มไหนไปแล้ว
  double _pinnedTopExtent() =>
      MediaQuery.paddingOf(context).top + kToolbarHeight + _tabBarHeight;

  void _syncActiveTab() {
    if (_isJumpingToTab || !_scrollController.hasClients) return;

    final current = _scrollController.offset;
    var active = 0;
    for (var i = 0; i < _tabAnchors.length; i++) {
      if (!_tabHasContent[i]) continue;
      final target = _anchorScrollOffset(i);
      // เผื่อไว้เล็กน้อย เพื่อให้กลุ่มที่เพิ่งโผล่มาแค่หัวยังไม่ถูกนับ
      if (target != null && current >= target - 12) active = i;
    }

    if (active != _activeTab) setState(() => _activeTab = active);
  }

  double? _anchorScrollOffset(int index) =>
      tripSectionAnchorOffset(_tabAnchors[index], _pinnedTopExtent());

  Future<void> _handleTabSelected(int index) async {
    if (!_scrollController.hasClients) return;
    final target = _anchorScrollOffset(index);
    if (target == null) return;

    setState(() {
      _activeTab = index;
      _isJumpingToTab = true;
    });
    await _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
    if (mounted) setState(() => _isJumpingToTab = false);
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
    // เมื่อไม่มีรอบที่ผู้ใช้ระบุมา (หรือระบุมาแต่หาไม่เจอ) ให้ตกไปที่รอบแรก
    // ที่ "จองได้จริง" ก่อน เพื่อไม่ให้เปิดหน้ามาแล้วเจอรอบที่เต็ม/ผ่านแล้ว
    // ถูกเลือกค้างไว้ ค่อย fallback ไปรอบแรกสุดถ้าไม่มีรอบไหนว่างเลย
    final selected = asMap(
      widget.schedules.firstWhere(
        (item) =>
            preferredScheduleId != null &&
            asMap(item)['id'].toString() == preferredScheduleId.toString() &&
            (regionKey == null ||
                _scheduleHasPickupRegion(asMap(item), regionKey)),
        orElse: () {
          final bookable = _firstBookableSchedule(
            widget.schedules,
            regionKey: regionKey,
          );
          if (bookable.isNotEmpty) return bookable;
          return widget.schedules.firstWhere(
            (item) =>
                regionKey != null &&
                _scheduleHasPickupRegion(asMap(item), regionKey),
            orElse: () => _selectedSchedule ?? widget.schedules.first,
          );
        },
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

  Future<void> _loadAlertState() async {
    if (!mounted) return;
    final app = context.read<AppProvider>();
    if (!app.isLoggedIn) return;
    await context.read<TripAlertProvider>().load(app.api, force: true);
  }

  Future<void> _handleAlertTap() async {
    final slug = textOf(widget.trip['slug']).trim();
    if (slug.isEmpty) {
      _showTripDetailMessage(context, 'กำลังโหลดข้อมูลทริป');
      return;
    }

    final app = context.read<AppProvider>();
    if (!app.isLoggedIn) {
      _showTripDetailMessage(context, 'กรุณาเข้าสู่ระบบเพื่อรับการแจ้งเตือน');
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    try {
      final on = await context.read<TripAlertProvider>().toggle(app.api, slug);
      if (!mounted) return;
      _showTripDetailMessage(
        context,
        on
            ? 'เปิดแจ้งเตือนแล้ว — เราจะบอกคุณเมื่อราคาลด เปิดรอบใหม่ หรือที่นั่งใกล้เต็ม'
            : 'ปิดแจ้งเตือนทริปนี้แล้ว',
      );
    } catch (e) {
      if (!mounted) return;
      _showTripDetailMessage(context, 'ดำเนินการไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  @override
  Widget build(BuildContext context) {
    _tabHasContent = _computeTabContent();
    final heroHeight = _heroHeight(context);
    final alertSlug = textOf(widget.trip['slug']).trim();
    final isAlertOn = alertSlug.isNotEmpty &&
        context.watch<TripAlertProvider>().isSubscribed(alertSlug);
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
              isAlertOn: isAlertOn,
              onSharePressed: _handleShareTrip,
              onFavoritePressed: _handleFavoriteTap,
              onAlertPressed: _handleAlertTap,
              // มีแท็บตั้งแต่ตอนโหลด แม้จะยังมองไม่เห็นเพราะแถบยังกางอยู่ —
              // ถ้าเพิ่มทีหลัง minExtent ของ sliver จะโตขึ้น 46 ตอนโหลดเสร็จ
              // แล้วเนื้อหาที่เลื่อนค้างไว้จะกระโดด (จุดยึดมีครบตั้งแต่แรก
              // ต่อให้ section ยังเป็นโครงร่างอยู่ กดแล้วจึงไปถูกที่)
              activeTab: _activeTab,
              tabHasContent: _tabHasContent,
              onTabSelected: _handleTabSelected,
            ),
            // ขอบโค้งด้านบนของการ์ดนี้ถูกวาดไว้ใน TravelSliverAppBar (ดู
            // _ContentTopCap) ไม่ใช่ตรงนี้ — sliver แรกถูกวาดทับ sliver ที่ตาม
            // มา ถ้าโค้งอยู่ฝั่งเนื้อหาจะโดนรูปปกบังจนดูเป็นสี่เหลี่ยม
            SliverToBoxAdapter(
              child: Container(
                color: AppTheme.background(context),
                // 16 บน ไม่ใช่ 24 เพราะหัวการ์ด (_contentOverlap) กินที่เหนือ
                // ขึ้นไปอีก 40 — รวมแล้วช่องว่างเหนือการ์ดใบแรกยังเท่าเดิม
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomBarHeight + 24),
                child: _buildSections(context),
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

  /// The stacked detail sections, each revealed on scroll for a calm cascade.
  ///
  /// Only sections that will actually render content are added, so a section
  /// that collapses to nothing (e.g. a trip with no videos) doesn't leave a
  /// stacked gap between the two 16px spacers that would otherwise wrap it.
  Widget _buildSections(BuildContext context) {
    final trip = widget.trip;

    // Mirror each section's own "empty?" guard so we skip the ones that would
    // render SizedBox.shrink().
    final hasDescription =
        widget.isLoading || textOf(trip['description']).trim().isNotEmpty;
    final hasMustKnow = _mustKnowItems(trip).isNotEmpty ||
        textOf(asMap(trip['must_know'])['remarks']).trim().isNotEmpty;
    final hasInclusions =
        asList(trip['inclusions']).any((e) => textOf(e).trim().isNotEmpty);
    final hasExclusions =
        asList(trip['exclusions']).any((e) => textOf(e).trim().isNotEmpty);
    final hasItinerary = _itinerarySectors(
      trip,
      regionKey: _effectivePickupRegionKey,
      regionLabel: _pickupRegionLabel(_selectedPickupPoint),
    ).isNotEmpty;

    final sections = <Widget>[
      // ── หัวเรื่อง ────────────────────────────────────────────────────
      // ไม่มีกรอบการ์ด ตั้งใจให้เป็นหัวหน้าไม่ใช่ section หนึ่ง และอยู่เหนือ
      // จุดยึดของแท็บแรก
      DestinationInfoSection(
        trip: trip,
        reviews: widget.reviews,
        isLoading: widget.isLoading,
      ),

      // ── แท็บ 1: วันเดินทาง ───────────────────────────────────────────
      // ย้ายขึ้นมาจากอันดับ 10 เพราะคนเปิดหน้านี้มาตอบ 2 คำถาม: วันไหนว่าง
      // และราคาเท่าไหร่ ให้ตอบได้ก่อนแล้วค่อยอ่านรายละเอียด
      _TabAnchor(key: _tabAnchors[0]),
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
      // เส้นทางเดินรถของรอบที่เลือก (จุดรับทุกจุด → ปลายทาง) — self-loading,
      // ซ่อนตัวเองเมื่อรอบไม่มีจุดจอดให้แสดง
      if (_selectedScheduleId != null)
        RouteMapCard(
          scheduleId: _selectedScheduleId!,
          highlightPickupPointId: _selectedPickupPointId,
        ),
      if (_selectedScheduleId != null)
        _GroupInviteEntry(
          onPressed: () => GroupRoomScreen.startFlow(
            context,
            _selectedScheduleId!,
          ),
        ),

      // ── แท็บ 2: รายละเอียด ───────────────────────────────────────────
      _TabAnchor(key: _tabAnchors[1]),
      // "ทริปนี้ไหวไหม" มาก่อนคำบรรยายและรูป ให้เจอความจริงก่อนโดนรูปสวยชวน
      // self-loading + ซ่อนตัวเองเมื่อทริปไม่มีระยะทาง/ความสูงให้เทียบ
      if (textOf(trip['slug']).isNotEmpty)
        TripReadinessSection(slug: textOf(trip['slug'])),
      if (hasDescription)
        AboutSection(
          trip: trip,
          isLoading: widget.isLoading,
          isExpanded: widget.isDescriptionExpanded,
          onToggle: widget.onDescriptionToggle,
        ),
      // ตัวเลขเส้นทางจริง วางต่อจากคำบรรยาย — ซ่อนตัวเองถ้าทริปยังไม่มี
      // ระยะทาง/ความสูง (ตรงกับ routeFacts บนหน้าเว็บ)
      RouteFactsSection(trip: trip),
      if (_highlightItems(trip['highlights']).isNotEmpty)
        HighlightsSection(trip: trip),
      if (hasItinerary)
        ItinerarySection(
          trip: trip,
          pickupRegionKey: _effectivePickupRegionKey,
          pickupRegionLabel: _pickupRegionLabel(_selectedPickupPoint),
        ),
      if (_detailGalleryImages(trip).isNotEmpty)
        PhotoGallerySection(trip: trip),
      if (_tripVideos(trip).isNotEmpty) VideoGallerySection(trip: trip),

      // ── แท็บ 3: เตรียมตัว ────────────────────────────────────────────
      // ทั้งกลุ่มพับเก็บได้ ยกเว้นวีซ่ากับคำเตือน — สองอันนั้นตัดสินได้เลยว่า
      // จองได้จริงหรือเปล่า ถ้าพับไว้เท่ากับซ่อนเรื่องที่ต้องรู้ก่อนจ่ายเงิน
      _TabAnchor(key: _tabAnchors[2]),
      // เอกสาร/วีซ่า/ประกัน/เบอร์ฉุกเฉิน (ซ่อนตัวเองเมื่อเป็นทริปในประเทศ)
      TravelRequirementsSection(trip: trip),
      if (hasMustKnow) MustKnowSection(trip: trip),
      if (_textItems(trip['preparations']).isNotEmpty)
        PreparationsSection(trip: trip),
      if (hasInclusions) IncludedSection(trip: trip),
      if (hasExclusions) ExcludedSection(trip: trip),
      if (_faqItems(trip['faqs']).isNotEmpty) FaqSection(trip: trip),
      // นโยบายยกเลิก — เงื่อนไขที่คนอ่านตอนกำลังตัดสินใจจ่าย
      // (backend ส่งชุดของทริปต่างประเทศมาให้เอง)
      CancellationPolicySection(trip: trip),

      // ── แท็บ 4: รีวิว ────────────────────────────────────────────────
      _TabAnchor(key: _tabAnchors[3]),
      if (_hasCommunityPhotos)
        CommunityPhotosSection(trip: trip, reviews: widget.reviews),
      // ฟีดรูปหลังทริป — ซ่อนตัวเองเมื่อไม่มีโพสต์และผู้ดูโพสต์ไม่ได้
      TripFeedSection(trip: trip),
      ReviewSection(trip: trip, reviews: widget.reviews),
      // "ทริปที่คล้ายกัน" — self-loading; renders nothing until it has matches.
      if (!widget.isLoading) RelatedTripsSection(trip: trip),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++)
          // จุดยึดแท็บไม่ผ่าน _RevealOnScroll และไม่กินระยะห่างของตัวเอง —
          // มันต้องวัดตำแหน่งได้ตั้งแต่ยังไม่ถูกเลื่อนถึง ถ้าใส่ animation
          // ครอบไว้ ตำแหน่งที่อ่านได้จะเป็นตำแหน่งระหว่างเคลื่อนไหว
          if (sections[i] is _TabAnchor)
            sections[i]
          else ...[
            if (i > 0) const SizedBox(height: 16),
            _RevealOnScroll(child: sections[i]),
          ],
      ],
    );
  }

  double _heroHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return (size.height * 0.46).clamp(320.0, 480.0);
  }
}

/// ตำแหน่ง scroll ที่ทำให้จุดยึด [key] มาหยุดใต้แถบบนที่สูง [pinnedExtent]
/// พอดี — null เมื่อจุดยึดยังไม่ได้เรนเดอร์หรือไม่ได้อยู่ใน viewport
///
/// ใช้เรขาคณิตของ viewport ไม่ใช่พิกัดบนจอจาก `localToGlobal` โดยตั้งใจ:
/// ตัวเรียกคือ scroll listener ซึ่งทำงาน**ก่อน** layout ของเฟรมใหม่ พิกัดบนจอ
/// ที่อ่านได้ตอนนั้นจึงเป็นของเฟรมก่อนหน้าเสมอ และถ้าเป็นการกระโดดทีเดียวที่
/// ไม่มี scroll event ตามมาอีก ค่าจะค้างผิดไปเลย — เคยทำให้แท็บค้างที่
/// "รายละเอียด" ทั้งที่เลื่อนถึงกลุ่มรีวิวแล้ว ส่วน getOffsetToReveal คืน
/// ตำแหน่งในเอกสาร ไม่ขึ้นกับว่าตอนนี้เลื่อนอยู่ตรงไหน
double? tripSectionAnchorOffset(GlobalKey key, double pinnedExtent) {
  final context = key.currentContext;
  if (context == null) return null;
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  final viewport = RenderAbstractViewport.maybeOf(box);
  if (viewport == null) return null;
  return viewport.getOffsetToReveal(box, 0).offset - pinnedExtent;
}

/// จุดยึดของแท็บ — กล่องเปล่าที่คั่นระหว่างกลุ่มเนื้อหา
///
/// มีตัวตนจริงในต้นไม้เพื่อให้ [GlobalKey] วัดตำแหน่งได้ และกินความสูงนิดหน่อย
/// ให้รอยต่อระหว่างกลุ่มอ่านออกว่าเป็นคนละเรื่องกัน
class _TabAnchor extends StatelessWidget {
  const _TabAnchor({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}

/// Call-to-action that lets a customer start a group plan for the chosen
/// schedule — friends join via a shared link and the host pays for everyone.
class _GroupInviteEntry extends StatelessWidget {
  final VoidCallback onPressed;
  const _GroupInviteEntry({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.accentColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border:
                Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ชวนเพื่อนมาเป็นกลุ่ม',
                      style: appFont(
                        fontSize: AppText.sizeSubtitle,
                        fontWeight: FontWeight.w800,
                        color: _premiumText,
                      ),
                    ),
                    Text(
                      'จองที่นั่งติดกัน เพื่อนเลือกที่นั่งเอง คุณจ่ายทีเดียว',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        color: _mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

