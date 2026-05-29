import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../providers/tracking_provider.dart';
import 'tracking_screen.dart' show TrackingMapPage;
import '../services/notification_navigator.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';
import 'login_screen.dart';
import 'refund_status_screen.dart';
import 'payment_screen.dart';
import 'profile_screen.dart' show ProfileScreen, ContactUsScreen, NotificationsScreen;
import 'guest_booking_lookup_screen.dart';
import 'staff_check_in_screen.dart';
import 'chat_screen.dart';
import 'pre_trip_checklist_screen.dart';
import 'trip_detail_screen.dart' show TripDetailScreen;
import '../services/checklist_storage.dart';

part 'my_bookings_screen.dart';
part 'home_explore.part.dart';
part 'all_trips.part.dart';
part 'trip_cards.part.dart';
part 'bookings_section.part.dart';
part 'bookings_extras.part.dart';
part 'booking_detail.part.dart';
part 'booking_photos.part.dart';
part 'auth_booking.part.dart';
part 'package_planner.part.dart';
part 'customer_app_helpers.part.dart';

final _moneyFormat = NumberFormat.currency(locale: 'th_TH', symbol: '฿');

class CustomerAppScreen extends StatefulWidget {
  const CustomerAppScreen({super.key});

  @override
  State<CustomerAppScreen> createState() => _CustomerAppScreenState();
}

class _CustomerAppScreenState extends State<CustomerAppScreen>
    with WidgetsBindingObserver {
  int _index = 0;

  // In-app foreground notification banner state.
  OverlayEntry? _bannerEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Re-sync notifications from the server so the app-icon badge reflects
      // anything the user marked read on another device — and so APNs-driven
      // badges from while we were backgrounded get cleared if there's nothing
      // unread left.
      final app = context.read<AppProvider>();
      if (app.isLoggedIn) {
        unawaited(app.loadNotifications());
      } else {
        unawaited(PushNotificationService.instance.clearBadge());
      }
    }
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
    WidgetsBinding.instance.removeObserver(this);
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
    const _NavItemData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'หน้าหลัก',
    ),
    const _NavItemData(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'ทริป',
    ),
    const _NavItemData(
      icon: Icons.confirmation_number_outlined,
      activeIcon: Icons.confirmation_number_rounded,
      label: 'การจอง',
    ),
    const _NavItemData(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'บัญชี',
    ),
    if (widget.showStaffCheckIn)
      const _NavItemData(
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
                        top: -3,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.surfaceDark
                                  : Colors.white,
                              width: 2,
                            ),
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
                          constraints: const BoxConstraints(
                            minWidth: 19,
                            minHeight: 19,
                          ),
                          child: Text(
                            widget.badge > 99 ? '99+' : '${widget.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
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

