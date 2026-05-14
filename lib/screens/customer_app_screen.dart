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
import '../services/notification_navigator.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';
import 'login_screen.dart';
import 'payment_screen.dart';
import 'profile_screen.dart' show ProfileScreen, ContactUsScreen, NotificationsScreen;
import 'staff_check_in_screen.dart';
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

  // In-app foreground notification banner state.
  OverlayEntry? _bannerEntry;

  @override
  void initState() {
    super.initState();
    NotificationNavigator.registerTabSwitcher((index) => selectTab(index));
    PushNotificationService.instance.initialize(
      onNotificationTap: (type, data) {
        NotificationNavigator.handle(type, data);
      },
      onForegroundNotification: (title, body, type, data) {
        _showInAppBanner(
          _InAppNotification(
            title: title,
            body: body,
            type: type,
            data: data,
          ),
        );
      },
    );
  }

  void selectTab(int value) {
    setState(() => _index = value);
  }

  void _showInAppBanner(_InAppNotification notification) {
    _bannerEntry?.remove();
    _bannerEntry = OverlayEntry(
      builder: (_) => _InAppNotificationBanner(
        notification: notification,
        onTap: () {
          _dismissBanner();
          NotificationNavigator.handle(notification.type, notification.data);
        },
        onDismiss: _dismissBanner,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_bannerEntry!);

    // Auto-dismiss after 5 seconds.
    Future.delayed(const Duration(seconds: 5), _dismissBanner);
  }

  void _dismissBanner() {
    _bannerEntry?.remove();
    _bannerEntry = null;
  }

  @override
  void dispose() {
    _bannerEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (app.booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final showStaffCheckIn = app.canUseStaffCheckIn;
    final pages = [
      const ExploreScreen(),
      const AllTripsScreen(),
      const MyBookingsScreen(),
      const ProfileScreen(),
      if (showStaffCheckIn) const StaffCheckInScreen(),
    ];

    final unreadCount = app.notifications
        .where((n) => (n as Map?)?['is_read'] != true)
        .length;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index >= pages.length ? pages.length - 1 : _index,
        children: pages,
      ),
      bottomNavigationBar: CustomBottomNav(
        index: _index >= pages.length ? pages.length - 1 : _index,
        showStaffCheckIn: showStaffCheckIn,
        unreadNotificationCount: unreadCount,
        onChanged: selectTab,
      ),
    );
  }
}

class CustomBottomNav extends StatefulWidget {
  final int index;
  final bool showStaffCheckIn;
  final int unreadNotificationCount;
  final ValueChanged<int> onChanged;

  const CustomBottomNav({
    super.key,
    required this.index,
    required this.showStaffCheckIn,
    required this.onChanged,
    this.unreadNotificationCount = 0,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(CustomBottomNav old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final items = _buildItems();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.surfaceDark.withValues(alpha: 0.97)
                  : Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? AppTheme.outlineDark.withValues(alpha: 0.6)
                    : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      for (int i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavItem(
                            icon: items[i].icon,
                            activeIcon: items[i].activeIcon,
                            label: items[i].label,
                            isSelected: widget.index == i,
                            // Profile tab (index 3) shows unread notification badge.
                            badge: i == 3
                                ? widget.unreadNotificationCount
                                : 0,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onChanged(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_NavItemData> _buildItems() => [
    _NavItemData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'หน้าหลัก',
    ),
    _NavItemData(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'ทริป',
    ),
    _NavItemData(
      icon: Icons.confirmation_number_outlined,
      activeIcon: Icons.confirmation_number_rounded,
      label: 'การจอง',
    ),
    _NavItemData(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'บัญชี',
    ),
    if (widget.showStaffCheckIn)
      _NavItemData(
        icon: Icons.qr_code_scanner_rounded,
        activeIcon: Icons.fact_check_rounded,
        label: 'เช็คอิน',
      ),
  ];
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _iconScale;
  late Animation<double> _pillWidth;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.isSelected ? 1.0 : 0.0,
    );
    _iconScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );
    _pillWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != old.isSelected) {
      if (widget.isSelected) {
        _anim.forward();
      } else {
        _anim.reverse();
      }
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final activeColor =
        isDark ? AppTheme.accentColor : AppTheme.primaryColor;
    final inactiveColor = isDark
        ? const Color(0xFF64748B)
        : const Color(0xFF94A3B8);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _anim,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // pill indicator
                    Container(
                      width: 48 * _pillWidth.value,
                      height: 32,
                      decoration: BoxDecoration(
                        color: activeColor.withValues(
                          alpha: 0.12 * _pillWidth.value,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    // icon
                    Transform.scale(
                      scale: _iconScale.value,
                      child: Icon(
                        widget.isSelected ? widget.activeIcon : widget.icon,
                        size: 22,
                        color: Color.lerp(
                          inactiveColor,
                          activeColor,
                          _anim.value,
                        ),
                      ),
                    ),
                    // unread badge
                    if (widget.badge > 0)
                      Positioned(
                        top: -2,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.surfaceDark
                                  : Colors.white,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            widget.badge > 99 ? '99+' : '${widget.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: GoogleFonts.anuphan(
                fontSize: 10.5,
                fontWeight: widget.isSelected
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: widget.isSelected ? activeColor : inactiveColor,
                letterSpacing: widget.isSelected ? 0.1 : 0,
              ),
              child: Text(widget.label, maxLines: 1),
            ),
          ],
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
                    clipBehavior: Clip.none,
                    children: [
                      HeroHeader(trip: heroTrip),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -286,
                        child: _HomeInspiredTopSection(
                          app: app,
                          user: app.user,
                          onCategorySelected: (value) =>
                              app.loadPublicData(type: value),
                          onSearch: (value) => app.loadPublicData(
                            search: value.isEmpty ? null : value,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 318),
                  _PopularTripsSection(trips: showTrips),
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
    final contentBottom = compactWidth ? 146.0 : 156.0;
    final contentWidth = (size.width - (horizontalPadding * 2)).clamp(
      260.0,
      680.0,
    );
    final titleSize = (size.width * 0.074).clamp(24.0, 36.0).toDouble();
    final subtitleSize = compactWidth ? 14.0 : 16.0;

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
                    errorWidget: (_, __, ___) => Container(
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
                          height: 1.24,
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
                        textAlign: TextAlign.start,
                        style: GoogleFonts.anuphan(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: subtitleSize,
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

  const _HeroTopBar({
    required this.user,
    required this.notificationCount,
    required this.backgroundProgress,
    required this.onNotificationsTap,
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
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 14),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: avatar.isNotEmpty
                          ? Image.network(avatar, fit: BoxFit.cover)
                          : Image.asset(
                              'logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'สวัสดี, $firstName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            height: 1.05,
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
                        const SizedBox(height: 6),
                        Text(
                          'พร้อมออกเดินทางครั้งใหม่?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.anuphan(
                            color: Color.lerp(
                              Colors.white.withValues(alpha: 0.88),
                              AppTheme.textSecondary,
                              backgroundProgress,
                            ),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            shadows: backgroundProgress < 0.45
                                ? const [
                                    Shadow(
                                      color: Colors.black38,
                                      offset: Offset(0, 1),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 54,
                            height: 54,
                            color: Colors.white.withValues(
                              alpha: 0.20 + (0.58 * backgroundProgress),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: onNotificationsTap,
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

class _HomeInspiredTopSection extends StatefulWidget {
  final AppProvider app;
  final Map<String, dynamic>? user;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<String> onSearch;

  const _HomeInspiredTopSection({
    required this.app,
    required this.user,
    required this.onCategorySelected,
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(42)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 102,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _homeCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 18),
                  itemBuilder: (context, index) {
                    final category = _homeCategories[index];
                    return _HomeCategoryBubble(
                      category: category,
                      onTap: () => widget.onCategorySelected(category.type),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              const _LicenseAssuranceBanner(),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _focused
              ? const Color(0xFF0B8A6E)
              : const Color(0xFFDDE4E4),
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? const Color(0xFF0B8A6E).withValues(alpha: 0.18)
                : const Color(0xFF082A30).withValues(alpha: 0.18),
            blurRadius: _focused ? 20 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              Icons.search_rounded,
              key: ValueKey(_focused),
              color: _focused
                  ? const Color(0xFF0B8A6E)
                  : const Color(0xFF8A9FA0),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
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
                  color: const Color(0xFF111313).withValues(alpha: 0.40),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF6B8080),
                ),
              ),
            ),
          const SizedBox(width: 8),
          // Filter button
          GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              margin: const EdgeInsets.all(8),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0E7A62), Color(0xFF0B5260)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B5260).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCategoryData {
  final String label;
  final String? type;
  final IconData icon;

  const _HomeCategoryData({
    required this.label,
    required this.type,
    required this.icon,
  });
}

const _homeCategories = [
  _HomeCategoryData(
    label: 'เดินป่า',
    type: 'trekking',
    icon: Icons.hiking_rounded,
  ),
  _HomeCategoryData(
    label: 'ดำน้ำตื้น',
    type: 'snorkeling',
    icon: Icons.scuba_diving_rounded,
  ),
  _HomeCategoryData(
    label: 'เช่ารถตู้',
    type: 'van-service',
    icon: Icons.airport_shuttle_rounded,
  ),
  _HomeCategoryData(
    label: 'แคมป์ปิ้ง',
    type: 'camping',
    icon: Icons.cabin_rounded,
  ),
  _HomeCategoryData(
    label: 'ทริปทั้งหมด',
    type: null,
    icon: Icons.explore_rounded,
  ),
];

class _HomeCategoryBubble extends StatelessWidget {
  final _HomeCategoryData category;
  final VoidCallback onTap;

  const _HomeCategoryBubble({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE5F0EE),
                ),
                child: Icon(category.icon, color: Color(0xFF0F766E), size: 31),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                color: const Color(0xFF667577),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
                      InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.network(
                          '${ApiConfig.siteUrl}/images/cer.jpg',
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
                          errorBuilder: (_, __, ___) => SizedBox(
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
          return Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 14 : 18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Icon(
              Icons.verified_user_outlined,
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
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ใบอนุญาตประกอบธุรกิจนำเที่ยว\nเลขที่ 12/03773',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: bodySize,
                  height: 1.42,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        }

        Widget licenseButton() {
          return TextButton.icon(
            onPressed: showLicenseDialog,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF083C42).withValues(alpha: 0.62),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 14,
                vertical: compact ? 10 : 12,
              ),
              minimumSize: narrow ? const Size.fromHeight(42) : null,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
              ),
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            label: Text(
              'ดูใบอนุญาต',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.anuphan(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w900,
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
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF044C4D), Color(0xFF087C68)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF044C4D).withValues(alpha: 0.24),
                blurRadius: 22,
                offset: const Offset(0, 10),
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

class _PopularTripsSection extends StatelessWidget {
  final List<Map<String, dynamic>> trips;

  const _PopularTripsSection({required this.trips});

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
                        'ทริปแนะนำ',
                        style: GoogleFonts.anuphan(
                          color: const Color(0xFF063F46),
                          fontSize: 25,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox.shrink(),
                      Text(
                        '',
                        style: GoogleFonts.anuphan(
                          color: AppTheme.textSecondary,
                          fontSize: 0,
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
                separatorBuilder: (_, __) => const SizedBox(width: 14),
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

  const PromotionsSection({required this.promotions});

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
              separatorBuilder: (_, __) => const SizedBox(width: 16),
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
        slivers: [
          const TravelSliverAppBar(title: 'โปรโมชั่นและสิทธิพิเศษ'),
          SliverToBoxAdapter(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: promotions.isEmpty
                    ? const _EmptyState(
                        icon: Icons.local_offer_outlined,
                        title: 'ยังไม่มีโปรโมชั่น',
                        body: 'ติดตามโปรโมชั่นและสิทธิพิเศษได้ที่นี่',
                      )
                    : Column(
                        children: [
                          for (final promo in promotions) ...[
                            _PromotionListCard(promotion: promo),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AllTripsScreen extends StatefulWidget {
  const AllTripsScreen({super.key});

  @override
  State<AllTripsScreen> createState() => _AllTripsScreenState();
}

class _AllTripsScreenState extends State<AllTripsScreen> {
  final _searchController = TextEditingController();
  final _difficulties = const [
    ('easy', 'ระดับเริ่มต้น'),
    ('medium', 'ระดับปานกลาง'),
    ('hard', 'ระดับท้าทาย'),
  ];

  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _meta;
  bool _loading = true;
  String _selectedType = '';
  String _selectedDifficulty = '';
  String _sortOrder = 'popular';
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchTrips());
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchTrips([int page = 1]) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final app = context.read<AppProvider>();
      if (_categories.isEmpty) {
        _categories = app.categories.map(asMap).toList();
      }

      final response = await app.api.get(
        'trips',
        query: {
          'page': page,
          'per_page': 12,
          'type': _selectedType,
          'difficulty': _selectedDifficulty,
          'search': _searchController.text.trim(),
        },
      );

      if (_categories.isEmpty) {
        final categoryResponse = await app.api.get('categories');
        _categories = List<dynamic>.from(
          app.api.data(categoryResponse) ?? [],
        ).map(asMap).toList();
      }

      if (!mounted) return;
      setState(() {
        _trips = List<dynamic>.from(
          app.api.data(response) ?? [],
        ).map(asMap).toList();
        _meta = app.api.meta(response);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _sortedTrips {
    final list = [..._trips];
    if (_sortOrder == 'price_asc') {
      list.sort((a, b) => _tripPrice(a).compareTo(_tripPrice(b)));
    } else if (_sortOrder == 'price_desc') {
      list.sort((a, b) => _tripPrice(b).compareTo(_tripPrice(a)));
    }
    return list;
  }

  int get _totalConfirmedParticipants {
    return _trips.fold<int>(
      0,
      (sum, trip) =>
          sum +
          (int.tryParse(textOf(trip['confirmed_passengers_count'], '0')) ?? 0),
    );
  }

  int get _currentPage =>
      int.tryParse(textOf(_meta?['current_page'], '1')) ?? 1;
  int get _lastPage => int.tryParse(textOf(_meta?['last_page'], '1')) ?? 1;
  int get _totalTrips =>
      int.tryParse(textOf(_meta?['total'], _trips.length.toString())) ??
      _trips.length;

  void _toggleType(String value) {
    setState(() {
      _selectedType = _selectedType == value ? '' : value;
      if (_selectedType != 'trekking') _selectedDifficulty = '';
    });
  }

  void _toggleDifficulty(String value) {
    setState(() {
      _selectedDifficulty = _selectedDifficulty == value ? '' : value;
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedType = '';
      _selectedDifficulty = '';
      _sortOrder = 'popular';
    });
    _fetchTrips();
  }

  String _categoryLabel(String value) {
    final category = _categories.firstWhere(
      (item) => textOf(item['slug']) == value,
      orElse: () => const <String, dynamic>{},
    );
    return textOf(
      category['name'],
      value.isEmpty ? 'ทริป' : _tripTypeLabel(value),
    );
  }

  bool get _hasFilters =>
      _selectedType.isNotEmpty ||
      _selectedDifficulty.isNotEmpty ||
      _searchController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        onRefresh: () => _fetchTrips(_currentPage),
        child: CustomScrollView(
          slivers: [
            const TravelSliverAppBar(title: 'กิจกรรมและทริปทั้งหมด'),
            SliverToBoxAdapter(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AllTripsHero(),
                      const SizedBox(height: 22),
                      _TripsFilterPanel(
                        searchController: _searchController,
                        categories: _categories,
                        selectedType: _selectedType,
                        selectedDifficulty: _selectedDifficulty,
                        difficulties: _difficulties,
                        onToggleType: _toggleType,
                        onToggleDifficulty: _toggleDifficulty,
                        onApply: () => _fetchTrips(),
                        onClear: _clearFilters,
                        hasFilters: _hasFilters,
                      ),
                      const SizedBox(height: 22),
                      _TripsResultsToolbar(
                        totalTrips: _totalTrips,
                        participants: _totalConfirmedParticipants,
                        sortOrder: _sortOrder,
                        onSortChanged: (value) {
                          if (value == null) return;
                          setState(() => _sortOrder = value);
                        },
                      ),
                      const SizedBox(height: 18),
                      if (_loading)
                        const _TripsLoadingCard()
                      else if (_error != null)
                        _TripsErrorCard(
                          message: _error!,
                          onRetry: () => _fetchTrips(_currentPage),
                        )
                      else if (_trips.isEmpty)
                        _EmptyState(
                          icon: Icons.explore_off_rounded,
                          title: 'ไม่พบกิจกรรมที่ตรงกับเงื่อนไข',
                          body: 'ลองปรับตัวกรองหรือคำค้นหา แล้วค้นหาอีกครั้ง',
                        )
                      else ...[
                        for (final trip in _sortedTrips) ...[
                          _AllTripCard(
                            trip: trip,
                            typeLabel: _categoryLabel(
                              textOf(
                                trip['type'] ??
                                    trip['category_slug'] ??
                                    trip['category_name'] ??
                                    trip['category'],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_lastPage > 1)
                          _TripsPaginationBar(
                            currentPage: _currentPage,
                            lastPage: _lastPage,
                            onPageSelected: _fetchTrips,
                          ),
                      ],
                    ],
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

class _AllTripsHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_rounded,
                color: AppTheme.primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'ค้นพบประสบการณ์ใหม่',
                style: GoogleFonts.anuphan(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'กิจกรรมและ\nทริปทั้งหมด',
          style: GoogleFonts.anuphan(
            color: AppTheme.textMain,
            fontSize: 36,
            height: 1.12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'สำรวจทริปที่คัดสรรมาเพื่อคุณ ตั้งแต่ดำน้ำตื้น เดินป่า จนถึงบริการรถตู้ระดับพรีเมียม',
          style: GoogleFonts.anuphan(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TripsFilterPanel extends StatelessWidget {
  final TextEditingController searchController;
  final List<Map<String, dynamic>> categories;
  final String selectedType;
  final String selectedDifficulty;
  final List<(String, String)> difficulties;
  final ValueChanged<String> onToggleType;
  final ValueChanged<String> onToggleDifficulty;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final bool hasFilters;

  const _TripsFilterPanel({
    required this.searchController,
    required this.categories,
    required this.selectedType,
    required this.selectedDifficulty,
    required this.difficulties,
    required this.onToggleType,
    required this.onToggleDifficulty,
    required this.onApply,
    required this.onClear,
    required this.hasFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterTitle(icon: Icons.search_rounded, label: 'ค้นหา'),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onApply(),
            decoration: InputDecoration(
              hintText: 'ค้นหาทริป...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppTheme.subtleSurface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
            style: GoogleFonts.anuphan(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          _FilterTitle(icon: Icons.category_rounded, label: 'หมวดหมู่กิจกรรม'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                _FilterChipButton(
                  label: textOf(category['name'], textOf(category['slug'])),
                  selected: selectedType == textOf(category['slug']),
                  onTap: () => onToggleType(textOf(category['slug'])),
                ),
            ],
          ),
          if (selectedType == 'trekking') ...[
            const SizedBox(height: 20),
            _FilterTitle(icon: Icons.terrain_rounded, label: 'ระดับความยาก'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in difficulties)
                  _FilterChipButton(
                    label: item.$2,
                    selected: selectedDifficulty == item.$1,
                    onTap: () => onToggleDifficulty(item.$1),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.filter_list_rounded),
              label: const Text('ใช้ตัวกรอง'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: GoogleFonts.anuphan(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('ล้างตัวกรอง'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FilterTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.anuphan(
            color: AppTheme.textMain,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor
              : AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.border(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.anuphan(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripsResultsToolbar extends StatelessWidget {
  final int totalTrips;
  final int participants;
  final String sortOrder;
  final ValueChanged<String?> onSortChanged;

  const _TripsResultsToolbar({
    required this.totalTrips,
    required this.participants,
    required this.sortOrder,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _InfoPill(text: 'พบทริปทั้งหมด $totalTrips', icon: Icons.explore),
            if (participants > 0)
              _InfoPill(
                text: '$participants คนร่วมเดินทางแล้ว',
                icon: Icons.group_rounded,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sortOrder,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              borderRadius: BorderRadius.circular(18),
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'popular',
                  child: Text('เรียงโดย: ทริปยอดนิยม'),
                ),
                DropdownMenuItem(
                  value: 'price_asc',
                  child: Text('เรียงโดย: ราคาจากน้อยไปมาก'),
                ),
                DropdownMenuItem(
                  value: 'price_desc',
                  child: Text('เรียงโดย: ราคาจากมากไปน้อย'),
                ),
              ],
              onChanged: onSortChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;
  final IconData icon;

  const _InfoPill({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.anuphan(
              color: AppTheme.textMain,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripsLoadingCard extends StatelessWidget {
  const _TripsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 18),
          Text(
            'กำลังค้นหาทริปที่ดีที่สุดให้คุณ...',
            style: GoogleFonts.anuphan(
              color: AppTheme.textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripsErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TripsErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: AppTheme.textSecondary,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            'โหลดข้อมูลทริปไม่สำเร็จ',
            style: GoogleFonts.anuphan(
              color: AppTheme.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
}

class _AllTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String typeLabel;

  const _AllTripCard({required this.trip, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final slug = textOf(trip['slug']);
    final title = textOf(trip['title'], '-');
    final description = textOf(trip['description']);
    final location = textOf(trip['location'], 'ประเทศไทย');
    final duration = textOf(trip['duration_days'], '1');
    final difficulty = textOf(trip['difficulty']);
    final joined =
        int.tryParse(textOf(trip['confirmed_passengers_count'], '0')) ?? 0;
    final reviewCount = int.tryParse(textOf(trip['review_count'], '0')) ?? 0;

    return InkWell(
      onTap: slug.isEmpty
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TripDetailScreen(slug: slug)),
            ),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: AspectRatio(
                aspectRatio: 1.12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image.isEmpty)
                        Container(
                          color: AppTheme.subtleSurface(context),
                          child: const Icon(
                            Icons.image_rounded,
                            color: AppTheme.textSecondary,
                            size: 46,
                          ),
                        )
                      else
                        CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: AppTheme.subtleSurface(context)),
                          errorWidget: (context, url, error) => Container(
                            color: AppTheme.subtleSurface(context),
                            child: const Icon(Icons.broken_image_rounded),
                          ),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.62),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OverlayPill(
                              text: typeLabel,
                              icon: null,
                              backgroundColor: _tripTypeColor(
                                textOf(trip['type']),
                              ).withValues(alpha: 0.92),
                              foregroundColor: Colors.white,
                            ),
                            if (_asBool(trip['is_women_only'])) ...[
                              const SizedBox(height: 8),
                              _OverlayPill(
                                text: 'หญิงล้วน',
                                icon: Icons.female_rounded,
                                backgroundColor: Colors.pinkAccent.withValues(
                                  alpha: 0.92,
                                ),
                                foregroundColor: Colors.white,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 14,
                        child: Row(
                          children: [
                            _OverlayPill(
                              text: '$duration วัน',
                              icon: Icons.schedule_rounded,
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.34,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            const Spacer(),
                            if (difficulty.isNotEmpty)
                              _OverlayPill(
                                text: _difficultyLabel(difficulty),
                                icon: Icons.terrain_rounded,
                                backgroundColor: Colors.black.withValues(
                                  alpha: 0.34,
                                ),
                                foregroundColor: Colors.white,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFB020),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      if (reviewCount > 0) ...[
                        Text(
                          numberText(trip['rating'], fallback: '0'),
                          style: GoogleFonts.anuphan(
                            color: AppTheme.textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($reviewCount รีวิว)',
                          style: GoogleFonts.anuphan(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else
                        Text(
                          'ยังไม่มีรีวิว',
                          style: GoogleFonts.anuphan(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const Spacer(),
                      if (joined > 0)
                        _MiniStatPill(
                          icon: Icons.group_rounded,
                          text: '$joined คนร่วมทริป',
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.textMain,
                      fontSize: 18,
                      height: 1.22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description.isNotEmpty ? description : location,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppTheme.border(context), height: 1),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pricePrefix(trip),
                              style: GoogleFonts.anuphan(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _priceLabel(trip),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.anuphan(
                                color: AppTheme.textMain,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.subtleSurface(context),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppTheme.primaryColor,
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

class _MiniStatPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniStatPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 15),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.anuphan(
              color: AppTheme.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripsPaginationBar extends StatelessWidget {
  final int currentPage;
  final int lastPage;
  final ValueChanged<int> onPageSelected;

  const _TripsPaginationBar({
    required this.currentPage,
    required this.lastPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pages = _paginationPages(currentPage, lastPage);

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageButton(
            icon: Icons.chevron_left_rounded,
            enabled: currentPage > 1,
            onTap: () => onPageSelected(currentPage - 1),
          ),
          const SizedBox(width: 6),
          for (final page in pages) ...[
            if (page == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '...',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else
              _NumberPageButton(
                page: page,
                selected: page == currentPage,
                onTap: () => onPageSelected(page),
              ),
            const SizedBox(width: 6),
          ],
          _PageButton(
            icon: Icons.chevron_right_rounded,
            enabled: currentPage < lastPage,
            onTap: () => onPageSelected(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
    );
  }
}

class _NumberPageButton extends StatelessWidget {
  final int page;
  final bool selected;
  final VoidCallback onTap;

  const _NumberPageButton({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.surface(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.border(context),
          ),
        ),
        child: Text(
          page.toString(),
          style: GoogleFonts.anuphan(
            color: selected ? Colors.white : AppTheme.textMain,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PromotionListCard extends StatelessWidget {
  final Map<String, dynamic> promotion;

  const _PromotionListCard({required this.promotion});

  String _discountLabel() {
    final type = promotion['type']?.toString() ?? '';
    final value = promotion['value'];
    if (value == null) return '';
    final num v = value is num ? value : num.tryParse(value.toString()) ?? 0;
    return type == 'percent'
        ? 'ลด ${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}%'
        : 'ลด ฿${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = promotion['code']?.toString() ?? '';
    final name = promotion['name']?.toString() ?? '-';
    final startDate = promotion['start_date'];
    final endDate = promotion['end_date'];
    final maxUses = promotion['max_uses'];
    final usedCount = promotion['used_count'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.anuphan(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CodeChip(code: code),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (startDate != null)
                      _MetaPill(
                        icon: Icons.calendar_today_outlined,
                        text: 'เริ่ม ${_formatDate(startDate.toString())}',
                      ),
                    if (endDate != null)
                      _MetaPill(
                        icon: Icons.event_outlined,
                        text: 'ถึง ${_formatDate(endDate.toString())}',
                      ),
                    if (maxUses != null)
                      _MetaPill(
                        icon: Icons.people_outline_rounded,
                        text: 'ใช้แล้ว $usedCount/$maxUses',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.anuphan(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class PopularTripCardLegacy extends StatelessWidget {
  final Map<String, dynamic> trip;

  const PopularTripCardLegacy({required this.trip});

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final slug = textOf(trip['slug']);
    final tag = _tripTypeLabel(
      textOf(trip['category_name'] ?? trip['category'] ?? trip['type'], 'ทริป'),
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
          color: AppTheme.surface(context),
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
                          color: AppTheme.warningTint(context),
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
                  const SizedBox(height: 8),
                  _ParticipantRow(trip: trip),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final Map<String, dynamic> trip;

  const _ParticipantRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    final joined = trip['confirmed_passengers_count'] as int? ?? 0;

    if (joined == 0) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(
          Icons.people_alt_outlined,
          size: 13,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          '$joined คน ร่วมเดินทางแล้ว',
          style: GoogleFonts.anuphan(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ReferenceTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;

  const _ReferenceTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final slug = textOf(trip['slug']);
    final type = textOf(
      trip['category_name'] ?? trip['category'] ?? trip['type'],
      'ทริป',
    );
    final title = textOf(trip['title'], '-');
    final duration = _durationText(trip);
    final reviewCount = textOf(trip['review_count'], '0');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: slug.isEmpty
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TripDetailScreen(slug: slug)),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isEmpty)
              Container(
                color: const Color(0xFFE5F0EE),
                child: const Icon(
                  Icons.landscape_rounded,
                  color: Color(0xFF0F766E),
                  size: 42,
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: const Color(0xFFE5F0EE)),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFE5F0EE),
                  child: const Icon(
                    Icons.landscape_rounded,
                    color: Color(0xFF0F766E),
                    size: 42,
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.74),
                  ],
                  stops: const [0.0, 0.46, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _tripTypeLabel(type),
                  style: GoogleFonts.anuphan(
                    color: const Color(0xFF087C68),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    duration,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: money(
                                  trip['min_price'] ??
                                      trip['price_per_person'] ??
                                      trip['price'],
                                ),
                                style: const TextStyle(
                                  color: Color(0xFFAFC4FF),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const TextSpan(
                                text: ' / คน',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.anuphan(fontSize: 14),
                        ),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFB020),
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${numberText(trip['rating'], fallback: '4.9')} ($reviewCount รีวิว)',
                        style: GoogleFonts.anuphan(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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
                color: AppTheme.subtleSurface(context),
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
                    Container(color: AppTheme.subtleSurface(context)),
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
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.3),
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
                            color: AppTheme.subtleSurface(context),
                            child: const Icon(Icons.landscape, size: 42),
                          )
                        : CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppTheme.subtleSurface(context),
                            ),
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
                          _tripTypeLabel(textOf(trip['type'], 'ประสบการณ์')),
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
                          color: AppTheme.subtleSurface(context),
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

BoxDecoration _ecoCardDecoration(BuildContext context) {
  return AppTheme.cardDecoration(
    context,
    radius: 32,
    borderColor: AppTheme.border(context).withValues(alpha: 0.45),
    shadowOpacity: 0.05,
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
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.18 : 0.06,
            ),
            blurRadius: 32,
            offset: const Offset(0, 14),
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
          Text(
            'ติดตามและจัดการการเดินทางของคุณ',
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: 24,
              height: 1.18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ดูสถานะทริป รายละเอียดการชำระเงิน และเอกสารยืนยันได้ครบในที่เดียว',
            style: TextStyle(
              color: AppTheme.mutedText(context),
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
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.mutedText(context),
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
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppTheme.isDark(context) ? 0.16 : 0.05,
              ),
              blurRadius: 22,
              offset: const Offset(0, 10),
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
                        : AppTheme.mutedText(context),
                  ),
                  label: Text('${tab.$2} ${counts[tab.$1] ?? 0}'),
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: selected == tab.$1
                        ? Colors.white
                        : AppTheme.mutedText(context),
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
              fillColor: AppTheme.surface(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppTheme.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppTheme.border(context)),
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
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Icon(icon, color: AppTheme.onSurface(context)),
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
                    style: TextStyle(
                      color: AppTheme.mutedText(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.onSurface(context),
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
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Text(
                '${bookings.length} รายการ',
                style: TextStyle(
                  color: AppTheme.mutedText(context),
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
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppTheme.isDark(context) ? 0.20 : 0.06,
              ),
              blurRadius: 34,
              offset: const Offset(0, 16),
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
                          style: TextStyle(
                            color: AppTheme.onSurface(context),
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
                            color: AppTheme.subtleSurface(context),
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
                    style: TextStyle(
                      color: AppTheme.mutedText(context),
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
                            Text(
                              'ยอดรวม',
                              style: TextStyle(
                                color: AppTheme.mutedText(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              money(booking['total_amount']),
                              style: TextStyle(
                                color: AppTheme.onSurface(context),
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
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
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
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.onSurface(context),
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
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactUsScreen()),
          ),
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
    final filledBg = AppTheme.onSurface(context);
    final outlinedBg = AppTheme.surface(context);
    final outlinedFg = AppTheme.onSurface(context);
    return ActionChip(
      avatar: Icon(
        icon,
        size: 17,
        color: filled ? AppTheme.surface(context) : outlinedFg,
      ),
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: filled ? filledBg : outlinedBg,
      side: BorderSide(
        color: filled
            ? filledBg
            : AppTheme.border(context),
      ),
      labelStyle: TextStyle(
        color: filled ? AppTheme.surface(context) : outlinedFg,
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
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.18 : 0.05,
            ),
            blurRadius: 28,
            offset: const Offset(0, 12),
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
          Text(
            'ยังไม่มีการจอง',
            style: TextStyle(
              color: AppTheme.onSurface(context),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'เริ่มออกผจญภัยครั้งใหม่กันเลย',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.mutedText(context),
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
            decoration: BoxDecoration(
              color: AppTheme.background(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Check-in card (confirmed only)
                if (textOf(booking['status']) == 'confirmed') ...[
                  _BookingCheckInCard(booking: booking),
                  const SizedBox(height: 20),
                ],

                // Trip title + booking ref
                Text(
                  textOf(trip['title'], 'รายละเอียดการจอง'),
                  style: GoogleFonts.anuphan(
                    color: AppTheme.primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  textOf(booking['booking_ref']),
                  style: GoogleFonts.anuphan(
                    color: AppTheme.mutedText(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                // Status chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(status: textOf(booking['status'])),
                    _Chip('เดินทาง ${dateText(schedule['departure_date'])}'),
                    _Chip(money(booking['total_amount'])),
                  ],
                ),
                const SizedBox(height: 20),

                // Passengers section
                _SheetSectionTitle(
                  icon: Icons.people_alt_rounded,
                  title: 'ผู้เดินทาง',
                ),
                const SizedBox(height: 10),
                ...passengers.map((item) {
                  final p = asMap(item);
                  final name =
                      '${textOf(p['title'])} ${textOf(p['name'])}'.trim();
                  final phone = textOf(p['phone'], 'ไม่มีเบอร์โทร');
                  final seat = textOf(p['seat_id']);
                  final halal = p['halal_food'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.subtleSurface(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.border(context).withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primaryColor.withValues(
                              alpha: 0.10,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppTheme.primaryColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isEmpty ? '-' : name,
                                  style: GoogleFonts.anuphan(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppTheme.onSurface(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  phone,
                                  style: GoogleFonts.anuphan(
                                    fontSize: 12,
                                    color: AppTheme.mutedText(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (seat.isNotEmpty || halal) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      if (seat.isNotEmpty)
                                        _InlineBadge('ที่นั่ง $seat'),
                                      if (halal)
                                        _InlineBadge('อาหารฮาลาล'),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Installments section
                if (installments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SheetSectionTitle(
                    icon: Icons.receipt_long_rounded,
                    title: 'งวดชำระ',
                  ),
                  const SizedBox(height: 10),
                  ...installments.map((item) {
                    final inst = asMap(item);
                    final instStatus = textOf(inst['status']);
                    final isPaid = instStatus == 'paid';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? AppTheme.primaryColor.withValues(alpha: 0.06)
                              : AppTheme.subtleSurface(context),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isPaid
                                ? AppTheme.primaryColor.withValues(alpha: 0.16)
                                : AppTheme.border(context).withValues(
                                    alpha: 0.6,
                                  ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPaid
                                  ? Icons.check_circle_rounded
                                  : Icons.schedule_rounded,
                              color: isPaid
                                  ? AppTheme.primaryColor
                                  : AppTheme.warningColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'งวดที่ ${textOf(inst['installment_no'])}  ·  ${money(inst['amount'])}',
                                    style: GoogleFonts.anuphan(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: AppTheme.onSurface(context),
                                    ),
                                  ),
                                  Text(
                                    'ครบกำหนด ${dateText(inst['due_date'])}',
                                    style: GoogleFonts.anuphan(
                                      fontSize: 12,
                                      color: AppTheme.mutedText(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _StatusChip(status: instStatus),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 20),

                // Payment actions (pending status)
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
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
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
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancel(context),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('ยกเลิกการจอง'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(
                          color: AppTheme.errorColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ],

                // Review CTA
                if (_asBool(booking['can_review'])) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _review(context, booking),
                      icon: const Icon(Icons.star_rounded),
                      label: const Text('รีวิวทริป'),
                    ),
                  ),
                ],
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
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => const _ReviewDialog(),
    );
    if (result == null) return;
    final (rating, comment) = result;
    try {
      await context.read<AppProvider>().submitReview(
        bookingId: int.parse(booking['id'].toString()),
        rating: rating,
        comment: comment,
      );
      if (context.mounted) showSnack(context, 'ส่งรีวิวแล้ว ขอบคุณที่ช่วยแชร์ประสบการณ์');
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString());
    }
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 5;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('รีวิวทริป'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คะแนน',
            style: GoogleFonts.anuphan(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = star),
                icon: Icon(
                  star <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: star <= _rating ? const Color(0xFFFFB020) : AppTheme.textSecondary,
                  size: 36,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'เล่าประสบการณ์ของคุณ',
              hintStyle: GoogleFonts.anuphan(color: AppTheme.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 4,
            style: GoogleFonts.anuphan(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () {
            final comment = _commentController.text.trim();
            if (comment.isEmpty) return;
            Navigator.pop(context, (_rating, comment));
          },
          child: const Text('ส่งรีวิว'),
        ),
      ],
    );
  }
}

class AuthScreen extends StatelessWidget {
  final VoidCallback? afterLogin;

  const AuthScreen({super.key, this.afterLogin});

  @override
  Widget build(BuildContext context) {
    return LoginScreen(onLoginSuccess: afterLogin, popOnSuccess: false);
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
  String? _selectedPickupRegionKey;
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
      _selectedPickupRegionKey = null;
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
      _selectedPickupRegionKey = null;
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
      decoration: _ecoCardDecoration(context).copyWith(
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
            onRegionChanged: (regionKey) =>
                setState(() => _selectedPickupRegionKey = regionKey),
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
                        initialScheduleId: _selectedScheduleId,
                        initialPickupRegionKey: _selectedPickupRegionKey,
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
  final ValueChanged<String?>? onRegionChanged;
  final AppProvider app;
  final Function(Map<String, dynamic>)? onSelectedSchedule;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const DateSelectorCard({
    super.key,
    required this.schedulesFuture,
    required this.selectedScheduleId,
    required this.onChanged,
    this.onRegionChanged,
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
  int? _selectedPickupPointId;

  @override
  void didUpdateWidget(covariant DateSelectorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedulesFuture != widget.schedulesFuture) {
      _selectedRegionKey = null;
      _selectedPickupPointId = null;
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
                          setState(() {
                            _selectedRegionKey = value;
                            _selectedPickupPointId = null;
                          });
                          widget.onChanged(null);
                          widget.onRegionChanged?.call(value);
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
                      regionKey: selectedRegion.key,
                      onChanged: (id) {
                        setState(() => _selectedPickupPointId = null);
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
            const SizedBox(height: 12),
            _PlannerSelectFrame(
              icon: Icons.place_outlined,
              label: 'จุดขึ้นรถ',
              child: currentSchedule == null || selectedRegion == null
                  ? const Text(
                      'เลือกวันเดินทางก่อน',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final pickupPoints =
                            asList(currentSchedule['pickup_points'])
                                .map(asMap)
                                .where(
                                  (p) =>
                                      pickupRegionKey(p) == selectedRegion.key,
                                )
                                .toList();
                        if (pickupPoints.isEmpty) {
                          return const Text(
                            'ยังไม่มีจุดขึ้นรถสำหรับภาคนี้',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                          );
                        }
                        final validId =
                            _selectedPickupPointId != null &&
                                pickupPoints.any(
                                  (p) =>
                                      int.tryParse(p['id'].toString()) ==
                                      _selectedPickupPointId,
                                )
                            ? _selectedPickupPointId
                            : int.tryParse(pickupPoints.first['id'].toString());
                        return DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: validId,
                            isExpanded: true,
                            itemHeight: 64,
                            borderRadius: BorderRadius.circular(16),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.primaryColor,
                            ),
                            selectedItemBuilder: (context) =>
                                pickupPoints.map((point) {
                                  final location = textOf(
                                    point['pickup_location'],
                                    textOf(point['region_label'], 'ไม่ระบุจุด'),
                                  );
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.anuphan(
                                        color: AppTheme.primaryColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            items: pickupPoints.map((point) {
                              final id = int.tryParse(point['id'].toString());
                              final location = textOf(
                                point['pickup_location'],
                                textOf(point['region_label'], 'ไม่ระบุจุด'),
                              );
                              final priceNum = num.tryParse(
                                point['price']?.toString() ?? '',
                              );
                              final priceText = priceNum != null && priceNum > 0
                                  ? money(priceNum)
                                  : '';
                              final notes = textOf(point['notes']).trim();
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.anuphan(
                                        color: AppTheme.primaryColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (priceText.isNotEmpty ||
                                        notes.isNotEmpty)
                                      Text(
                                        notes.isNotEmpty && priceText.isNotEmpty
                                            ? '$notes  ·  $priceText'
                                            : notes.isNotEmpty
                                            ? notes
                                            : priceText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.anuphan(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => _selectedPickupPointId = value),
                          ),
                        );
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
  final String? regionKey;
  final ValueChanged<int?> onChanged;

  const _ScheduleDropdown({
    required this.schedules,
    required this.value,
    required this.onChanged,
    this.regionKey,
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
            final date = scheduleTravelDateText(schedule);
            final seats = textOf(schedule['available_seats'], '0');
            return Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          final date = scheduleTravelDateText(schedule);
          final seats = textOf(schedule['available_seats'], '0');
          return DropdownMenuItem<int>(
            value: int.tryParse(schedule['id'].toString()),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.primaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.border(context).withValues(alpha: 0.4),
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
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.5),
        ),
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
                    color: AppTheme.mutedText(context),
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

String _tripTypeLabel(String type) {
  return switch (type.toLowerCase()) {
    'all' => 'ทริปทั้งหมด',
    'trekking' => 'เดินป่า',
    'diving' => 'ดำน้ำ',
    'snorkeling' => 'ดำน้ำตื้น',
    'van' || 'van-service' || 'van_service' => 'เช่ารถตู้',
    'climbing' => 'ปีนเขา',
    'camping' => 'แคมป์ปิ้ง',
    'kayaking' => 'พายเรือคายัค',
    'cycling' => 'ปั่นจักรยาน',
    _ => type,
  };
}

String _durationText(Map<String, dynamic> trip) {
  final days = int.tryParse(textOf(trip['duration_days'], '1')) ?? 1;
  if (days <= 1) return '1 วัน';
  return '$days วัน ${days - 1} คืน';
}

Color _tripTypeColor(String type) {
  return switch (type.toLowerCase()) {
    'trekking' => const Color(0xFF2D7A4F),
    'diving' => const Color(0xFF1A5F8A),
    'snorkeling' => const Color(0xFF3B9DD4),
    'climbing' => const Color(0xFFC8963E),
    _ => const Color(0xFF6B8F7A),
  };
}

String _difficultyLabel(String difficulty) {
  return switch (difficulty.toLowerCase()) {
    'easy' => 'ง่าย',
    'medium' => 'ปานกลาง',
    'hard' => 'ท้าทาย',
    _ => difficulty,
  };
}

num _tripPrice(Map<String, dynamic> trip) {
  return num.tryParse(
        textOf(
          trip['min_price'] ?? trip['price_per_person'] ?? trip['price'],
          '0',
        ),
      ) ??
      0;
}

String _pricePrefix(Map<String, dynamic> trip) {
  final min = num.tryParse(textOf(trip['min_price']));
  final max = num.tryParse(textOf(trip['max_price']));
  if (min != null && max != null && min != max) return 'ช่วงราคา';
  return 'เริ่มต้น';
}

String _priceLabel(Map<String, dynamic> trip) {
  final minValue =
      trip['min_price'] ?? trip['price_per_person'] ?? trip['price'];
  final maxValue = trip['max_price'];
  final min = num.tryParse(textOf(minValue));
  final max = num.tryParse(textOf(maxValue));

  if (min != null && max != null && min != max) {
    return '${money(min)} - ${money(max)}';
  }
  return money(minValue);
}

List<int?> _paginationPages(int current, int last) {
  if (last <= 7) return [for (var i = 1; i <= last; i++) i];

  final pages = <int?>[1];
  if (current > 3) pages.add(null);
  for (var i = current - 1; i <= current + 1; i++) {
    if (i > 1 && i < last) pages.add(i);
  }
  if (current < last - 2) pages.add(null);
  pages.add(last);
  return pages;
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

String scheduleTravelDateText(Map<String, dynamic> schedule) {
  final start = _compactThaiDate(schedule['departure_date']);
  if (start == '-') return 'รอระบุวัน';

  final end = _compactThaiDate(schedule['return_date']);
  if (end == '-' || end == start) return start;

  return '$start - $end';
}

String _compactThaiDate(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '-';

  final date = DateTime.tryParse(raw);
  if (date == null) return raw;

  final month = DateFormat('MMM', 'th_TH').format(date);
  return '${date.day} $month${date.year + 543}';
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

// ─────────────────────────────────────────────────────────────────────────────
// Sheet helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SheetSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SheetSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.anuphan(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppTheme.onSurface(context),
          ),
        ),
      ],
    );
  }
}

class _InlineBadge extends StatelessWidget {
  final String text;

  const _InlineBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.anuphan(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// In-app foreground notification banner
// ---------------------------------------------------------------------------

class _InAppNotification {
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;

  const _InAppNotification({
    required this.title,
    required this.body,
    required this.type,
    required this.data,
  });
}

class _InAppNotificationBanner extends StatefulWidget {
  final _InAppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppNotificationBanner({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<_InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  IconData _icon() {
    return switch (widget.notification.type) {
      'payment' || 'payment_confirmed' || 'installment_due' =>
        Icons.payments_rounded,
      'payment_rejected' => Icons.money_off_rounded,
      'booking' || 'booking_confirmed' => Icons.confirmation_number_rounded,
      'booking_cancelled' => Icons.cancel_rounded,
      'booking_reminder' || 'trip_reminder' => Icons.calendar_month_rounded,
      'seat_alert' => Icons.local_fire_department_rounded,
      'promo' => Icons.card_giftcard_rounded,
      'loyalty' => Icons.star_rounded,
      _ => Icons.notifications_rounded,
    };
  }

  Color _accentColor(bool isDark) {
    return switch (widget.notification.type) {
      'seat_alert' || 'payment_rejected' || 'booking_cancelled' =>
        AppTheme.errorColor,
      'booking_reminder' || 'trip_reminder' => const Color(0xFF2563EB),
      'promo' => AppTheme.warningColor,
      'loyalty' => const Color(0xFFEA580C),
      'installment_due' => const Color(0xFFD97706),
      _ => AppTheme.primaryColor,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final accent = _accentColor(isDark);
    final mediaQuery = MediaQuery.of(context);

    return Positioned(
      top: mediaQuery.padding.top + 8,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: GestureDetector(
              onTap: () async {
                await _controller.reverse();
                widget.onTap();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.surfaceDark.withValues(alpha: 0.97)
                      : Colors.white.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.45 : 0.12,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_icon(), color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.notification.title.isNotEmpty)
                            Text(
                              widget.notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.anuphan(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textMain,
                              ),
                            ),
                          if (widget.notification.body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.notification.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.anuphan(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _dismiss,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
