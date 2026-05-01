import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'booking_lookup_screen.dart';
import 'login_screen.dart';
import 'payment_screen.dart';
import 'profile_screen.dart';
import 'trip_detail_screen.dart' show TripDetailScreen;

part 'my_bookings_screen.dart';

final _moneyFormat = NumberFormat.currency(locale: 'th_TH', symbol: '฿');

class CustomerAppScreen extends StatefulWidget {
  const CustomerAppScreen({super.key});

  @override
  State<CustomerAppScreen> createState() => _CustomerAppScreenState();
}

class _CustomerAppScreenState extends State<CustomerAppScreen> {
  int _index = 0;

  void selectTab(int value) {
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (app.booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      const ExploreScreen(),
      const MyBookingsScreen(),
      BookingLookupScreen(embedded: true, onOpenBookings: () => selectTab(1)),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: CustomBottomNav(index: _index, onChanged: selectTab),
    );
  }
}

class CustomBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const CustomBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                height: 64,
                backgroundColor: Colors.transparent,
                indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.10),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(
                      color: AppTheme.primaryColor,
                      size: 24,
                    );
                  }
                  return const IconThemeData(
                    color: AppTheme.textSecondary,
                    size: 24,
                  );
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  return GoogleFonts.anuphan(
                    fontSize: 11,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: states.contains(WidgetState.selected)
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: onChanged,
                elevation: 0,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'หน้าแรก',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.confirmation_number_outlined),
                    selectedIcon: Icon(Icons.confirmation_number_rounded),
                    label: 'การจอง',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore_rounded),
                    label: 'ติดตาม',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'บัญชี',
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

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final ScrollController _scrollController;
  double _topBarProgress = 0;

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
    final size = MediaQuery.of(context).size;
    final heroHeight = size.height * 0.55;

    final notificationCount = app.notifications
        .where((item) => asMap(item)['is_read'] != true)
        .length;
    final heroTrip =
        (app.featuredTrips.isNotEmpty ? app.featuredTrips : app.trips)
            .map(asMap)
            .firstOrNull;
    final showTrips =
        (app.featuredTrips.isNotEmpty ? app.featuredTrips : app.trips)
            .map(asMap)
            .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
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
                    clipBehavior: Clip.none,
                    children: [
                      HeroHeader(trip: heroTrip),
                      // Position the card so it overlaps the Hero
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          heroHeight * 0.55,
                          16,
                          0,
                        ),
                        child: HomeTopSection(
                          app: app,
                          user: app.user,
                          onCategorySelected: (value) =>
                              app.loadPublicData(search: value),
                          onSearch: (value) => app.loadPublicData(
                            search: value.isEmpty ? null : value,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PopularTripsSection(trips: showTrips),
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
    final image = ApiConfig.mediaUrl('/images/khaochangphueak.webp');
    final size = MediaQuery.of(context).size;
    final heroHeight = size.height * 0.55;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image with Gradient Overlay
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
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
                  Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        ),
                      ),
                    ),
                  ),
                // Dark Gradient Overlay for Readability (Top to Bottom)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.15),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.2),
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
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
            left: 24,
            right: 24,
            bottom: heroHeight * 0.50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'การเที่ยวที่ดี เริ่มจาก\nความรู้สึกที่ดี ตั้งแต่การจอง',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anuphan(
                    color: Colors.white,
                    fontSize: size.width > 600 ? 36 : 28,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ค้นหาทริปและประสบการณ์ที่พร้อมเดินทาง',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anuphan(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
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

  const _HeroTopBar({
    required this.user,
    required this.notificationCount,
    required this.backgroundProgress,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = ApiConfig.mediaUrl(user?['avatar_url']);
    final name = textOf(user?['name'], 'นักเที่ยว');
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
        bottom: Radius.circular(24 * backgroundProgress),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18 * backgroundProgress,
          sigmaY: 18 * backgroundProgress,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82 * backgroundProgress),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.outlineColor.withValues(
                  alpha: 0.55 * backgroundProgress,
                ),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.08 * backgroundProgress,
                ),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    backgroundImage: avatar.isEmpty
                        ? null
                        : NetworkImage(avatar),
                    child: avatar.isEmpty
                        ? Text(
                            initial,
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'สวัสดี, $firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        shadows: backgroundProgress < 0.45
                            ? const [
                                Shadow(
                                  color: Colors.black38,
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
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
                              alpha: 0.20 + (0.58 * backgroundProgress),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {},
                              icon: Icon(
                                Icons.notifications_none,
                                color: iconColor,
                              ),
                            ),
                          ),
                          if (notificationCount > 0)
                            Positioned(
                              top: 10,
                              right: 12,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppTheme.outlineColor.withValues(alpha: 0.55),
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
              color: AppTheme.textMain,
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
                color: AppTheme.textMain,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            DateSelectorCard(
              schedulesFuture: _schedulesFuture,
              selectedScheduleId: _selectedScheduleId,
              onChanged: (id) => setState(() => _selectedScheduleId = id),
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
                    builder: (_) => TripDetailScreen(slug: _selectedSlug!),
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
    final name = textOf(user?['name'], 'นักเที่ยว');
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

class _PopularTripsSection extends StatelessWidget {
  final List<Map<String, dynamic>> trips;

  const _PopularTripsSection({required this.trips});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 48),
      padding: const EdgeInsets.fromLTRB(20, 40, 0, 40),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(56)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, -10),
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
                        'ทริปยอดนิยม',
                        style: GoogleFonts.anuphan(
                          color: AppTheme.textMain,
                          fontSize: 26,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'คัดสรรจุดหมายปลายทางที่ดีที่สุดสำหรับคุณ',
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
                  onPressed: () {},
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
          const SizedBox(height: 28),
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
              height: 320,
              child: ListView.separated(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 20),
                itemCount: trips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 20),
                itemBuilder: (context, index) => SizedBox(
                  width: MediaQuery.of(context).size.width > 700 ? 340 : 300,
                  child: _PopularTripCard(trip: trips[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PopularTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;

  const _PopularTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final slug = textOf(trip['slug']);
    final tag = textOf(
      trip['category_name'] ?? trip['category'] ?? trip['type'],
      'ทริป',
    );
    final location = textOf(trip['location'], 'ประเทศไทย');
    final price = trip['min_price'] ?? trip['price'];

    return InkWell(
      onTap: slug.isEmpty
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TripDetailScreen(slug: slug)),
            ),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1C1C).withValues(alpha: 0.06),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: const Color(0xFF1A1C1C).withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image.isEmpty)
                      Container(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.landscape_rounded,
                          color: AppTheme.primaryColor,
                          size: 40,
                        ),
                      )
                    else
                      Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.landscape_rounded,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _OverlayPill(
                        text: tag,
                        icon: null,
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                    if (price != null)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _OverlayPill(
                          text: money(price),
                          icon: null,
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textOf(trip['title'], '-'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.textMain,
                      fontSize: 18,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.anuphan(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDCBF).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              numberText(trip['rating'], fallback: '5.0'),
                              style: GoogleFonts.anuphan(
                                color: const Color(0xFF92400E),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _OverlayPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _OverlayPill({
    required this.text,
    required this.icon,
    this.backgroundColor = const Color(0xE6E2E2E2),
    this.foregroundColor = AppTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foregroundColor),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturedTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;

  const FeaturedTripCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TripDetailScreen(slug: trip['slug'].toString()),
        ),
      ),
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isEmpty)
              Container(
                color: const Color(0xFFF3F3F3),
                child: const Icon(
                  Icons.landscape,
                  size: 54,
                  color: AppTheme.primaryColor,
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: const Color(0xFFF3F3F3)),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                    AppTheme.primaryColor.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 36,
                    height: 36,
                    color: Colors.white.withValues(alpha: 0.20),
                    child: const Icon(
                      Icons.favorite_border,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          textOf(trip['location'], 'ประเทศไทย'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.anuphan(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    textOf(trip['title'], '-'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          money(trip['price_per_person']),
                          style: GoogleFonts.anuphan(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFDCBF),
                        size: 17,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        numberText(trip['rating'], fallback: '5.0'),
                        style: GoogleFonts.anuphan(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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

class TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool compact;

  const TripCard({super.key, required this.trip, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final title = textOf(trip['title'], '-');
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TripDetailScreen(slug: trip['slug'].toString()),
        ),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.outlineColor.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SizedBox(
                height: 192,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image.isEmpty
                        ? Container(
                            color: const Color(0xFFF3F3F3),
                            child: const Icon(Icons.landscape, size: 42),
                          )
                        : CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: const Color(0xFFF3F3F3)),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          textOf(trip['type'], 'ประสบการณ์'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 24,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 15,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              numberText(trip['rating'], fallback: '4.8'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          textOf(trip['location'], 'ประเทศไทย'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppTheme.outlineColor),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'เริ่มต้น ',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: money(trip['price_per_person']),
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const TextSpan(text: ' /คน'),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
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

// TripDetailScreen has been moved to its own file lib/screens/trip_detail_screen.dart

BoxDecoration _ecoCardDecoration() {
  return BoxDecoration(
    color: AppTheme.surfaceLight,
    borderRadius: BorderRadius.circular(32),
    boxShadow: const [
      BoxShadow(
        color: Color(0x141A1C1C),
        blurRadius: 40,
        offset: Offset(0, 12),
      ),
    ],
  );
}

class _BookingsHeader extends StatelessWidget {
  final int totalCount;
  final int upcomingCount;

  const _BookingsHeader({
    required this.totalCount,
    required this.upcomingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFEAEDED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F111313),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.luggage_rounded,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ติดตามและจัดการการเดินทางของคุณ',
            style: TextStyle(
              color: Color(0xFF111313),
              fontSize: 24,
              height: 1.18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ดูสถานะทริป รายละเอียดการชำระเงิน และเอกสารยืนยันได้ครบในที่เดียว',
            style: TextStyle(
              color: Color(0xFF687272),
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryPill(
                  label: 'ทริปที่กำลังจะถึง',
                  value: '$upcomingCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryPill(
                  label: 'การจองทั้งหมด',
                  value: '$totalCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7ECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111313),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF687272),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ReservationSegmentTabs extends StatelessWidget {
  final _ReservationSegment selected;
  final Map<_ReservationSegment, int> counts;
  final ValueChanged<_ReservationSegment> onChanged;

  const ReservationSegmentTabs({
    super.key,
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (_ReservationSegment.all, 'ทั้งหมด', Icons.grid_view_rounded),
      (
        _ReservationSegment.upcoming,
        'กำลังจะถึง',
        Icons.event_available_rounded,
      ),
      (_ReservationSegment.past, 'เดินทางแล้ว', Icons.history_rounded),
      (_ReservationSegment.cancelled, 'ยกเลิก', Icons.event_busy_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE3E8E8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D111313),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final tab in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  selected: selected == tab.$1,
                  onSelected: (_) => onChanged(tab.$1),
                  showCheckmark: false,
                  avatar: Icon(
                    tab.$3,
                    size: 17,
                    color: selected == tab.$1
                        ? Colors.white
                        : const Color(0xFF687272),
                  ),
                  label: Text('${tab.$2} ${counts[tab.$1] ?? 0}'),
                  selectedColor: const Color(0xFF111313),
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: selected == tab.$1
                        ? Colors.white
                        : const Color(0xFF687272),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BookingUtilityBar extends StatelessWidget {
  final String query;
  final String sort;
  final String statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onStatusFilterChanged;

  const _BookingUtilityBar({
    required this.query,
    required this.sort,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onStatusFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'ค้นหาการจอง',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE3E8E8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE3E8E8)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'เรียงลำดับ',
          initialValue: sort,
          onSelected: onSortChanged,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'upcoming', child: Text('วันเดินทางใกล้สุด')),
            PopupMenuItem(value: 'latest', child: Text('จองล่าสุด')),
          ],
          child: _UtilityIconButton(icon: Icons.swap_vert_rounded),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'กรองการจอง',
          initialValue: statusFilter,
          onSelected: onStatusFilterChanged,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'all', child: Text('ทุกสถานะ')),
            PopupMenuItem(value: 'confirmed', child: Text('ยืนยันแล้ว')),
            PopupMenuItem(value: 'pending', child: Text('รอชำระเงิน')),
            PopupMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
            PopupMenuItem(value: 'completed', child: Text('เสร็จสิ้น')),
          ],
          child: _UtilityIconButton(
            icon: statusFilter == 'all'
                ? Icons.tune_rounded
                : Icons.filter_alt_rounded,
          ),
        ),
      ],
    );
  }
}

class _UtilityIconButton extends StatelessWidget {
  final IconData icon;

  const _UtilityIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8E8)),
      ),
      child: Icon(icon, color: const Color(0xFF111313)),
    );
  }
}

class UpcomingSection extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final ValueChanged<Map<String, dynamic>> onCancel;

  const UpcomingSection({
    super.key,
    required this.bookings,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return BookingSection(
      eyebrow: 'ทริปถัดไปของคุณ',
      title: 'กำลังจะถึง',
      bookings: bookings,
      onCancel: onCancel,
    );
  }
}

class PastTripsSection extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;

  const PastTripsSection({super.key, required this.bookings});

  @override
  Widget build(BuildContext context) {
    return BookingSection(
      eyebrow: 'ความทรงจำที่ผ่านมา',
      title: 'เดินทางแล้ว',
      bookings: bookings,
    );
  }
}

class BookingSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final List<Map<String, dynamic>> bookings;
  final ValueChanged<Map<String, dynamic>>? onCancel;

  const BookingSection({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.bookings,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      color: Color(0xFF8A9494),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF111313),
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE3E8E8)),
              ),
              child: Text(
                '${bookings.length} รายการ',
                style: const TextStyle(
                  color: Color(0xFF687272),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final booking in bookings) ...[
          ReservationCard(booking: booking, onCancel: onCancel),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class ReservationCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final ValueChanged<Map<String, dynamic>>? onCancel;

  const ReservationCard({super.key, required this.booking, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final bookingRef = textOf(booking['booking_ref'], '-');
    final isCancelled = _isCancelledBooking(booking);
    final image = ApiConfig.mediaUrl(
      textOf(
        trip['thumbnail_image'],
        textOf(trip['cover_image'], '/images/landscape.webp'),
      ),
    );

    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            BookingDetailSheet(bookingRef: booking['booking_ref'].toString()),
      ),
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE4E8E8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10111313),
              blurRadius: 34,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: Stack(
                children: [
                  SizedBox(
                    height: 178,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      color: isCancelled ? Colors.grey : null,
                      colorBlendMode: isCancelled ? BlendMode.saturation : null,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFFEDEFEF)),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFFEDEFEF),
                        child: const Icon(Icons.landscape_rounded),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.46),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: _DateBadge(date: bookingTravelDate(booking)),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      children: [
                        Expanded(child: _CountdownPill(booking: booking)),
                        const SizedBox(width: 8),
                        BookingStatusChip(booking: booking),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          textOf(trip['title'], 'การจอง'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111313),
                            fontSize: 20,
                            height: 1.22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'เมนูเพิ่มเติม',
                        onSelected: (value) {
                          if (value == 'cancel') onCancel?.call(booking);
                          if (value == 'detail') {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) =>
                                  BookingDetailSheet(bookingRef: bookingRef),
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'detail',
                            child: Text('ดูรายละเอียด'),
                          ),
                          if (textOf(booking['status']) == 'pending')
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Text('ยกเลิกการจอง'),
                            ),
                        ],
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8F8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.more_horiz_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'หมายเลขการจอง $bookingRef',
                    style: const TextStyle(
                      color: Color(0xFF687272),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (textOf(booking['status']) == 'confirmed') ...[
                    const SizedBox(height: 14),
                    _BookingCheckInCard(booking: booking, compact: true),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ReservationMetaPill(
                        icon: Icons.calendar_month_rounded,
                        label: 'วันเดินทาง',
                        value: _travelDateText(booking),
                      ),
                      _ReservationMetaPill(
                        icon: Icons.groups_rounded,
                        label: 'ผู้เดินทาง',
                        value: _travelerText(booking),
                      ),
                      _ReservationMetaPill(
                        icon: Icons.location_on_rounded,
                        label: 'จุดรับ',
                        value: _pickupText(booking),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ยอดรวม',
                              style: TextStyle(
                                color: Color(0xFF8A9494),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              money(booking['total_amount']),
                              style: const TextStyle(
                                color: Color(0xFF111313),
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) =>
                              BookingDetailSheet(bookingRef: bookingRef),
                        ),
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('ดูรายละเอียด'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  BookingQuickActions(
                    booking: booking,
                    onDetail: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          BookingDetailSheet(bookingRef: bookingRef),
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

class BookingStatusChip extends StatelessWidget {
  final Map<String, dynamic> booking;

  const BookingStatusChip({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final key = _statusKey(booking);
    final color = switch (key) {
      'pending' => const Color(0xFFD97706),
      'near' => const Color(0xFF006565),
      'completed' => const Color(0xFF315A9D),
      'cancelled' => const Color(0xFF687272),
      _ => AppTheme.primaryColor,
    };
    final label = switch (key) {
      'pending' => 'รอชำระเงิน',
      'near' => 'ใกล้เดินทาง',
      'completed' => 'เสร็จสิ้น',
      'cancelled' => 'ยกเลิก',
      _ => 'ยืนยันแล้ว',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime? date;

  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            date == null ? '--' : DateFormat('MMM', 'th_TH').format(date!),
            style: const TextStyle(
              color: Color(0xFF687272),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            date == null ? '--' : DateFormat('d', 'th_TH').format(date!),
            style: const TextStyle(
              color: Color(0xFF111313),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _CountdownPill({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _countdownText(booking),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF111313),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReservationMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReservationMetaPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 142, maxWidth: 310),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECEC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8A9494),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111313),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookingQuickActions extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onDetail;

  const BookingQuickActions({
    super.key,
    required this.booking,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final status = textOf(booking['status']);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'pending')
          _ActionChipButton(
            icon: Icons.payments_rounded,
            label: 'ชำระเงินต่อ',
            filled: true,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PaymentScreen(bookingRef: textOf(booking['booking_ref'])),
              ),
            ),
          ),
        if (status != 'pending')
          _ActionChipButton(
            icon: Icons.confirmation_number_rounded,
            label: 'ดู Voucher',
            onPressed: onDetail,
          ),
        _ActionChipButton(
          icon: Icons.support_agent_rounded,
          label: 'ติดต่อทีมงานลุยเลเขา',
          onPressed: () => showSnack(context, 'ติดต่อทีมงานผ่านหน้าติดต่อเรา'),
        ),
        _ActionChipButton(
          icon: Icons.download_rounded,
          label: 'ดาวน์โหลดใบยืนยัน',
          onPressed: onDetail,
        ),
      ],
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 17,
        color: filled ? Colors.white : const Color(0xFF111313),
      ),
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: filled ? const Color(0xFF111313) : Colors.white,
      side: BorderSide(
        color: filled ? const Color(0xFF111313) : const Color(0xFFE1E6E6),
      ),
      labelStyle: TextStyle(
        color: filled ? Colors.white : const Color(0xFF111313),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE3E8E8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D111313),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              color: AppTheme.primaryColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'ยังไม่มีการจอง',
            style: TextStyle(
              color: Color(0xFF111313),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'เริ่มออกผจญภัยครั้งใหม่กันเลย',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF687272),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              final state = context
                  .findAncestorStateOfType<_CustomerAppScreenState>();
              state?.selectTab(0);
            },
            icon: const Icon(Icons.search_rounded),
            label: const Text('ค้นหาทริป'),
          ),
        ],
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.search_off_rounded,
      title: 'ไม่พบการจอง',
      body: 'ลองเปลี่ยนคำค้นหา ตัวกรอง หรือแท็บสถานะอีกครั้ง',
    );
  }
}

class BookingDetailSheet extends StatefulWidget {
  final String bookingRef;

  const BookingDetailSheet({super.key, required this.bookingRef});

  @override
  State<BookingDetailSheet> createState() => _BookingDetailSheetState();
}

class _BookingDetailSheetState extends State<BookingDetailSheet> {
  late Future<Map<String, dynamic>> _future;
  String _paymentType = 'full';

  @override
  void initState() {
    super.initState();
    _future = context.read<AppProvider>().booking(widget.bookingRef);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      builder: (_, controller) => FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final booking = snapshot.data!;
          final schedule = asMap(booking['schedule']);
          final trip = asMap(schedule['trip']);
          final passengers = asList(booking['passengers']);
          final installments = asList(booking['installment_payments']);
          final installmentAvailable = _scheduleInstallmentAvailable(schedule);
          final paymentType =
              installmentAvailable && _paymentType == 'installment'
              ? 'installment'
              : 'full';
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.outlineColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (textOf(booking['status']) == 'confirmed') ...[
                  _BookingCheckInCard(booking: booking),
                  const SizedBox(height: 18),
                ],
                Text(
                  textOf(trip['title'], 'รายละเอียดการจอง'),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  textOf(booking['booking_ref']),
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(status: textOf(booking['status'])),
                    _Chip('เดินทาง ${dateText(schedule['departure_date'])}'),
                    _Chip(money(booking['total_amount'])),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionTitle('ผู้เดินทาง'),
                ...passengers.map((item) {
                  final p = asMap(item);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      '${textOf(p['title'])} ${textOf(p['name'])}'.trim(),
                    ),
                    subtitle: Text(textOf(p['phone'], 'ไม่มีเบอร์โทร')),
                  );
                }),
                if (installments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _SectionTitle('งวดชำระ'),
                  ...installments.map((item) {
                    final installment = asMap(item);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'งวด ${textOf(installment['installment_no'])} - ${money(installment['amount'])}',
                      ),
                      subtitle: Text(
                        'ครบกำหนด ${dateText(installment['due_date'])}',
                      ),
                      trailing: _StatusChip(
                        status: textOf(installment['status']),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 18),
                if (booking['status'] == 'pending') ...[
                  if (installmentAvailable) ...[
                    DropdownButtonFormField<String>(
                      initialValue: paymentType,
                      decoration: const InputDecoration(
                        labelText: 'รูปแบบชำระเงิน',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'full',
                          child: Text('จ่ายเต็ม'),
                        ),
                        DropdownMenuItem(
                          value: 'installment',
                          child: Text('ผ่อนชำระ'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _paymentType = value ?? 'full'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(
                            bookingRef: widget.bookingRef,
                            initialPaymentType: paymentType,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('ไปหน้าชำระเงิน'),
                  ),
                  TextButton.icon(
                    onPressed: () => _cancel(context),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('ยกเลิกการจอง'),
                  ),
                ],
                if (booking['status'] == 'confirmed')
                  OutlinedButton.icon(
                    onPressed: () => _review(context, booking),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('รีวิวทริป'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final reason = await promptText(
      context,
      title: 'เหตุผลการยกเลิก',
      hint: 'ระบุเหตุผล',
    );
    if (reason == null) return;
    try {
      await context.read<AppProvider>().cancelBooking(
        widget.bookingRef,
        reason,
      );
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString());
    }
  }

  Future<void> _review(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final comment = await promptText(
      context,
      title: 'รีวิวทริป',
      hint: 'เล่าประสบการณ์ของคุณ',
    );
    if (comment == null) return;
    try {
      await context.read<AppProvider>().submitReview(
        bookingId: int.parse(booking['id'].toString()),
        rating: 5,
        comment: comment,
      );
      if (context.mounted) showSnack(context, 'ส่งรีวิวแล้ว');
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString());
    }
  }
}

class AuthScreen extends StatelessWidget {
  final VoidCallback? afterLogin;

  const AuthScreen({super.key, this.afterLogin});

  @override
  Widget build(BuildContext context) {
    return LoginScreen(onLoginSuccess: afterLogin);
  }
}

class BookingCard extends StatefulWidget {
  final AppProvider app;

  const BookingCard({super.key, required this.app});

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  String? _selectedSlug;
  int? _selectedScheduleId;
  Future<List<dynamic>>? _schedulesFuture;
  bool _isPackagesExpanded = false;

  @override
  void didUpdateWidget(covariant BookingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final trips = _tripOptions;
    if (_selectedSlug != null &&
        !trips.any((trip) => trip['slug']?.toString() == _selectedSlug)) {
      _selectedSlug = null;
      _selectedScheduleId = null;
      _schedulesFuture = null;
    }
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
      _schedulesFuture = widget.app.schedules(slug);
      _isPackagesExpanded = false; // Reset expansion on trip change
    });
  }

  @override
  Widget build(BuildContext context) {
    final trips = _tripOptions;
    Map<String, dynamic>? selectedTrip;
    for (final trip in trips) {
      if (trip['slug']?.toString() == _selectedSlug) {
        selectedTrip = trip;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20), // Standardized spacing
      decoration: _ecoCardDecoration().copyWith(
        borderRadius: BorderRadius.circular(24), // Softer corners
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppTheme.accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'อยากไปเที่ยวที่ไหน?',
                style: GoogleFonts.anuphan(
                  color: AppTheme.primaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Destination Selector
          DestinationDropdown(
            slug: _selectedSlug,
            options: trips,
            onChanged: _selectTrip,
          ),

          const SizedBox(height: 12),

          // Date Selector
          DateSelectorCard(
            schedulesFuture: _schedulesFuture,
            selectedScheduleId: _selectedScheduleId,
            onChanged: (id) => setState(() {
              _selectedScheduleId = id;
            }),
            app: widget.app,
            onSelectedSchedule: (schedule) {
              // This can be used if we need more info from the selected schedule
            },
            isExpanded: _isPackagesExpanded,
            onToggleExpand: () => setState(() {
              _isPackagesExpanded = !_isPackagesExpanded;
            }),
          ),

          const SizedBox(height: 20),

          // Primary CTA Button
          PrimaryCTAButton(
            label: 'เริ่มเที่ยวเลย',
            icon: Icons.explore_rounded,
            onPressed: selectedTrip == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TripDetailScreen(
                        slug: selectedTrip!['slug'].toString(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class DestinationDropdown extends StatelessWidget {
  final String? slug;
  final List<Map<String, dynamic>> options;
  final ValueChanged<String?> onChanged;

  const DestinationDropdown({
    super.key,
    required this.slug,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _PlannerSelectFrame(
      icon: Icons.map_outlined,
      label: 'เลือกทริปที่สนใจ',
      child: options.isEmpty
          ? const Text(
              'ยังไม่มีทริปที่เปิดขาย',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: slug,
                isExpanded: true,
                menuMaxHeight: 400,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.primaryColor,
                ),
                items: options.map((trip) {
                  return DropdownMenuItem<String>(
                    value: trip['slug']?.toString(),
                    child: Text(
                      textOf(trip['title'], '-'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
                hint: Text(
                  'เลือกทริป',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onChanged: onChanged,
              ),
            ),
    );
  }
}

class DateSelectorCard extends StatefulWidget {
  final Future<List<dynamic>>? schedulesFuture;
  final int? selectedScheduleId;
  final ValueChanged<int?> onChanged;
  final AppProvider app;
  final Function(Map<String, dynamic>)? onSelectedSchedule;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const DateSelectorCard({
    super.key,
    required this.schedulesFuture,
    required this.selectedScheduleId,
    required this.onChanged,
    required this.app,
    this.onSelectedSchedule,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  State<DateSelectorCard> createState() => _DateSelectorCardState();
}

class _DateSelectorCardState extends State<DateSelectorCard> {
  String? _selectedRegionKey;

  @override
  void didUpdateWidget(covariant DateSelectorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedulesFuture != widget.schedulesFuture) {
      _selectedRegionKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.schedulesFuture == null) {
      return _PlannerSelectFrame(
        icon: Icons.route_outlined,
        label: 'เลือกภาคที่จะขึ้น',
        child: const Text(
          'เลือกทริปก่อน',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: widget.schedulesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _PlannerSelectFrame(
            icon: Icons.route_outlined,
            label: 'เลือกภาคที่จะขึ้น',
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                minHeight: 2,
              ),
            ),
          );
        }

        final scheduleMaps = asList(snapshot.data).map(asMap).toList();
        if (scheduleMaps.isEmpty) {
          return _PlannerSelectFrame(
            icon: Icons.calendar_today_outlined,
            label: 'เลือกวันเดินทาง',
            child: const Text(
              'ยังไม่มีวันเดินทางที่เปิดจอง',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
          );
        }

        final regions = pickupRegionOptions(scheduleMaps);
        final selectedRegion = regions
            .where((region) => region.key == _selectedRegionKey)
            .firstOrNull;
        final filteredSchedules = selectedRegion == null
            ? <Map<String, dynamic>>[]
            : scheduleMaps
                  .where(
                    (schedule) =>
                        scheduleHasPickupRegion(schedule, selectedRegion.key),
                  )
                  .toList();
        final currentSchedule = filteredSchedules
            .where(
              (schedule) =>
                  schedule['id']?.toString() ==
                  widget.selectedScheduleId?.toString(),
            )
            .firstOrNull;
        final dropdownScheduleId = currentSchedule == null
            ? null
            : int.tryParse(currentSchedule['id'].toString());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlannerSelectFrame(
              icon: Icons.route_outlined,
              label: 'เลือกภาคที่จะขึ้น',
              child: regions.isEmpty
                  ? const Text(
                      'ยังไม่มีข้อมูลภาค/จุดรับสำหรับทริปนี้',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRegion?.key,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(16),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.primaryColor,
                        ),
                        hint: Text(
                          'เลือกภาค',
                          style: GoogleFonts.anuphan(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        items: regions.map((region) {
                          return DropdownMenuItem<String>(
                            value: region.key,
                            child: Text(
                              region.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.anuphan(
                                color: AppTheme.primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedRegionKey = value);
                          widget.onChanged(null);
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            _PlannerSelectFrame(
              icon: Icons.calendar_today_outlined,
              label: 'เลือกวันเดินทาง',
              child: selectedRegion == null
                  ? const Text(
                      'เลือกภาคก่อนจึงจะเลือกวันได้',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    )
                  : filteredSchedules.isEmpty
                  ? const Text(
                      'ยังไม่มีวันเดินทางสำหรับภาคนี้',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    )
                  : _ScheduleDropdown(
                      schedules: filteredSchedules,
                      value: dropdownScheduleId,
                      onChanged: (id) {
                        widget.onChanged(id);
                        final selectedSchedule = filteredSchedules
                            .where(
                              (schedule) =>
                                  schedule['id']?.toString() == id?.toString(),
                            )
                            .firstOrNull;
                        if (selectedSchedule != null) {
                          widget.onSelectedSchedule?.call(selectedSchedule);
                        }
                      },
                    ),
            ),
            if (currentSchedule != null && selectedRegion != null) ...[
              const SizedBox(height: 8),
              _SchedulePickupDetailToggle(
                isExpanded: widget.isExpanded,
                onToggleExpand: widget.onToggleExpand,
              ),
              if (widget.isExpanded)
                PackageListSection(
                  schedule: currentSchedule,
                  regionKey: selectedRegion.key,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ScheduleDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> schedules;
  final int? value;
  final ValueChanged<int?> onChanged;

  const _ScheduleDropdown({
    required this.schedules,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        isExpanded: true,
        itemHeight: 70,
        borderRadius: BorderRadius.circular(16),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppTheme.primaryColor,
        ),
        hint: Text(
          'เลือกวันเดินทาง',
          style: GoogleFonts.anuphan(
            color: AppTheme.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        selectedItemBuilder: (context) {
          return schedules.map((schedule) {
            final date = dateText(schedule['departure_date']);
            final seats = textOf(schedule['available_seats'], '0');
            return Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SeatBadge(count: int.tryParse(seats) ?? 0),
              ],
            );
          }).toList();
        },
        items: schedules.map((schedule) {
          final date = dateText(schedule['departure_date']);
          final seats = textOf(schedule['available_seats'], '0');
          return DropdownMenuItem<int>(
            value: int.tryParse(schedule['id'].toString()),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.primaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SeatBadge(count: int.tryParse(seats) ?? 0, compact: true),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _SchedulePickupDetailToggle extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const _SchedulePickupDetailToggle({
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggleExpand,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 14,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'รายละเอียดจุดรับและราคา',
                style: GoogleFonts.anuphan(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatBadge extends StatelessWidget {
  final int count;
  final bool compact;

  const _SeatBadge({required this.count, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isLow = count < 5;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isLow
            ? const Color(0xFFFFDAD6)
            : AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'เหลือ $count ที่',
        style: GoogleFonts.anuphan(
          color: isLow ? const Color(0xFF93000A) : AppTheme.primaryColor,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class PackageListSection extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final String? regionKey;

  const PackageListSection({super.key, required this.schedule, this.regionKey});

  @override
  Widget build(BuildContext context) {
    final points = asList(schedule['pickup_points'])
        .map(asMap)
        .where(
          (point) => regionKey == null || pickupRegionKey(point) == regionKey,
        )
        .toList();
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'ยังไม่มีรายละเอียดภาค/จุดรับสำหรับรอบนี้',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      );
    }

    return Column(
      children: [
        ...points.map((point) {
          final region = textOf(
            point['region_label'],
            textOf(point['region'], 'ไม่ระบุภาค'),
          );
          final location = textOf(point['pickup_location'], 'ไม่ระบุจุดรับ');
          final price = point['price'] != null ? money(point['price']) : 'ฟรี';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.outlineColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region,
                        style: GoogleFonts.anuphan(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.anuphan(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  price,
                  style: GoogleFonts.anuphan(
                    color: AppTheme.primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class PrimaryCTAButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const PrimaryCTAButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56, // Modern tall button
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: GoogleFonts.anuphan(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _PlannerSelectFrame extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _PlannerSelectFrame({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA), // Slightly lighter and cleaner
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outlineColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Icon(
              icon,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.anuphan(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String scheduleRegionSummary(Map<String, dynamic> schedule) {
  final points = asList(schedule['pickup_points']).map(asMap).toList();
  if (points.isEmpty) return 'ยังไม่มีรายละเอียดภาค/จุดรับ';

  final labels = <String>{};
  for (final point in points) {
    final label = textOf(
      point['region_label'],
      textOf(point['region'], 'ไม่ระบุภาค'),
    );
    labels.add(label);
  }

  final visible = labels.take(3).join(', ');
  final more = labels.length > 3 ? ' +${labels.length - 3}' : '';
  return 'ภาค: $visible$more';
}

class _PickupRegionOption {
  final String key;
  final String label;

  const _PickupRegionOption({required this.key, required this.label});
}

List<_PickupRegionOption> pickupRegionOptions(
  List<Map<String, dynamic>> schedules,
) {
  final labelsByKey = <String, String>{};

  for (final schedule in schedules) {
    final points = asList(schedule['pickup_points']).map(asMap);
    for (final point in points) {
      final key = pickupRegionKey(point);
      if (key.isEmpty || labelsByKey.containsKey(key)) continue;
      labelsByKey[key] = pickupRegionLabel(point);
    }
  }

  final regions = labelsByKey.entries
      .map((entry) => _PickupRegionOption(key: entry.key, label: entry.value))
      .toList();
  regions.sort((a, b) => a.label.compareTo(b.label));
  return regions;
}

bool scheduleHasPickupRegion(Map<String, dynamic> schedule, String regionKey) {
  final points = asList(schedule['pickup_points']).map(asMap);
  return points.any((point) => pickupRegionKey(point) == regionKey);
}

String pickupRegionKey(Map<String, dynamic> point) {
  final region = textOf(point['region']).trim();
  if (region.isNotEmpty) return region;
  return textOf(point['region_label']).trim();
}

String pickupRegionLabel(Map<String, dynamic> point) {
  return textOf(point['region_label'], textOf(point['region'], 'ไม่ระบุภาค'));
}

DateTime? bookingTravelDate(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  final raw = textOf(schedule['departure_date']);
  if (raw.isEmpty) return null;
  final date = DateTime.tryParse(raw);
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day);
}

DateTime? _bookingReturnDate(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  final raw = textOf(
    schedule['return_date'],
    textOf(schedule['departure_date']),
  );
  if (raw.isEmpty) return null;
  final date = DateTime.tryParse(raw);
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day);
}

bool _isCancelledBooking(Map<String, dynamic> booking) {
  return ['cancelled', 'refunded'].contains(textOf(booking['status']));
}

bool _isPastBooking(Map<String, dynamic> booking) {
  if (_isCancelledBooking(booking)) return false;
  if (textOf(booking['status']) == 'completed') return true;

  final end = _bookingReturnDate(booking);
  if (end == null) return false;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return end.isBefore(today);
}

bool _isUpcomingBooking(Map<String, dynamic> booking) {
  if (_isCancelledBooking(booking) || _isPastBooking(booking)) return false;
  return ['pending', 'confirmed'].contains(textOf(booking['status']));
}

String _statusKey(Map<String, dynamic> booking) {
  final status = textOf(booking['status']);
  if (_isCancelledBooking(booking)) return 'cancelled';
  if (status == 'pending') return 'pending';
  if (_isPastBooking(booking) || status == 'completed') return 'completed';

  final travelDate = bookingTravelDate(booking);
  if (travelDate != null && status == 'confirmed') {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = travelDate.difference(today).inDays;
    if (days >= 0 && days <= 7) return 'near';
  }

  return 'confirmed';
}

String _countdownText(Map<String, dynamic> booking) {
  final status = textOf(booking['status']);
  if (status == 'pending') return 'รอชำระเงินเพื่อยืนยันที่นั่ง';
  if (_isCancelledBooking(booking)) return 'รายการนี้ถูกยกเลิก';

  final date = bookingTravelDate(booking);
  if (date == null) return 'รอระบุวันเดินทาง';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = date.difference(today).inDays;
  if (days > 0) return 'อีก $days วันเดินทาง';
  if (days == 0) return 'เดินทางวันนี้';
  return 'เดินทางแล้ว';
}

String _travelDateText(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  final start = dateText(schedule['departure_date']);
  final end = dateText(schedule['return_date']);
  if (start == '-') return 'รอระบุวัน';
  if (end == '-' || end == start) return start;
  return '$start - $end';
}

String _travelerText(Map<String, dynamic> booking) {
  final passengers = asList(booking['passengers']);
  final seats = asList(booking['seats']);
  final explicitCount =
      _positiveInt(booking['passenger_count']) ??
      _positiveInt(booking['passengers_count']) ??
      _positiveInt(booking['seat_count']) ??
      _positiveInt(booking['seats_count']);
  final count = passengers.isNotEmpty
      ? passengers.length
      : seats.isNotEmpty
      ? seats.length
      : explicitCount ?? 0;
  if (count <= 0) return 'รอข้อมูล';
  return '$count คน';
}

String _pickupText(Map<String, dynamic> booking) {
  final pickupPoint = _selectedPickupPoint(booking);
  final schedule = asMap(booking['schedule']);
  final trip = asMap(schedule['trip']);
  final regionCode = textOf(
    pickupPoint['region'],
    textOf(booking['pickup_region']),
  );
  final regionLabel = textOf(
    pickupPoint['region_label'],
    _regionLabel(regionCode),
  );
  final location = textOf(pickupPoint['pickup_location']);
  final notes = textOf(pickupPoint['notes']);
  final details = [
    if (location.isNotEmpty) location,
    if (notes.isNotEmpty) notes,
  ].join(' ');

  if (regionLabel.isNotEmpty && details.isNotEmpty) {
    return '$regionLabel — $details';
  }
  if (details.isNotEmpty) return details;
  if (regionLabel.isNotEmpty) return regionLabel;
  return textOf(trip['departure_point'], 'จุดนัดพบตามรายละเอียดทริป');
}

Map<String, dynamic> _selectedPickupPoint(Map<String, dynamic> booking) {
  final direct = asMap(booking['pickup_point']);
  if (direct.isNotEmpty) return direct;

  final pickupRegion = textOf(booking['pickup_region']);
  final pickupPointId = textOf(booking['pickup_point_id']);
  final schedule = asMap(booking['schedule']);
  final points = asList(schedule['pickup_points']).map(asMap).toList();

  for (final point in points) {
    if (pickupPointId.isNotEmpty && textOf(point['id']) == pickupPointId) {
      return point;
    }
  }
  for (final point in points) {
    if (pickupRegion.isNotEmpty && textOf(point['region']) == pickupRegion) {
      return point;
    }
  }
  return points.length == 1 ? points.first : const <String, dynamic>{};
}

int? _positiveInt(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

String _regionLabel(String region) {
  return switch (region.trim().toLowerCase()) {
    'bangkok' => 'กรุงเทพฯ',
    'central' => 'ภาคกลาง',
    'north' => 'ภาคเหนือ',
    'northeast' => 'ภาคอีสาน',
    'east' => 'ภาคตะวันออก',
    'west' => 'ภาคตะวันตก',
    'south' => 'ภาคใต้',
    _ => '',
  };
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' => AppTheme.accentColor,
      'pending' => AppTheme.warningColor,
      'cancelled' => AppTheme.errorColor,
      _ => AppTheme.primaryColor,
    };
    final label = switch (status) {
      'confirmed' => 'ยืนยันแล้ว',
      'pending' => 'รอชำระ',
      'cancelled' => 'ยกเลิก',
      'completed' => 'จบทริป',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}

String textOf(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String money(dynamic value) {
  final number = num.tryParse(value?.toString() ?? '');
  if (number == null) return _moneyFormat.format(0);
  return _moneyFormat.format(number);
}

String numberText(dynamic value, {String fallback = '0'}) {
  final number = num.tryParse(value?.toString() ?? '');
  if (number == null) return fallback;
  return number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 1);
}

bool _scheduleInstallmentAvailable(Map<String, dynamic> schedule) {
  return _asBool(schedule['installment_enabled']);
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String dateText(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '-';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  return DateFormat('d MMM yyyy', 'th_TH').format(date);
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: hint),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('ตกลง'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result == null || result.isEmpty ? null : result;
}
