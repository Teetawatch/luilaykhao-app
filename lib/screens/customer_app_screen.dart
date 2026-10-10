import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../providers/article_provider.dart';
import '../providers/tracking_provider.dart';
import 'tracking_screen.dart' show TrackingMapPage;
import '../services/home_widget_service.dart';
import '../services/notification_navigator.dart';
import '../services/push_notification_service.dart';
import '../services/search_history_service.dart';
import '../services/api_client.dart' show ApiException;
import '../services/check_in_outbox.dart';
import '../services/sos_outbox.dart';
import '../services/trip_activity_service.dart';
import '../widgets/app_snack.dart';
import '../widgets/booking_history_footer.dart';
import '../widgets/min_tap_target.dart';
import '../widgets/curved_nav_shape.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../utils/calendar_export.dart';
import '../utils/check_in_pass.dart';
import '../widgets/emergency_numbers_card.dart';
import '../widgets/rally_card.dart';
import '../widgets/review_dialog.dart';
import '../widgets/route_map_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/sos_button.dart';
import '../widgets/tier_badge.dart';
import '../widgets/travel_widgets.dart';
import '../widgets/trip_story_share_sheet.dart';
import '../widgets/vehicle_seat_map.dart';
import '../widgets/weather_card.dart';
import 'login_screen.dart';
import 'refund_status_screen.dart';
import 'payment_screen.dart';
import 'profile_screen.dart'
    show ProfileScreen, ContactUsScreen, NotificationsScreen, StaffWorkScreen;
import 'guest_booking_lookup_screen.dart';
import 'chat_list_screen.dart';
import 'claim_booking_screen.dart';
import 'join_booking_screen.dart';
import 'invite_friends_screen.dart';
import 'seat_handover_screen.dart';
import 'trip_attendance_screen.dart';
import 'pre_trip_checklist_screen.dart';
import 'schedule_announcements_screen.dart';
import 'article_list_screen.dart';
import 'article_detail_screen.dart';
import 'community_gallery_screen.dart' show CommunityGalleryScreen;
import 'places_screen.dart' show PlacesScreen;
import 'trip_map_screen.dart' show TripMapScreen;
import 'trip_detail_screen.dart' show TripDetailScreen, AllReviewsScreen;
import 'booking_documents_screen.dart';
import 'travel_documents_screen.dart';
import 'trip_day_screen.dart';
import 'trip_feed_screen.dart';
import 'trip_recap_screen.dart';
import 'medals_screen.dart' show MedalDetailScreen;
import '../models/trip_medal.dart';
import '../widgets/medal_art.dart' show MedalArt;
import 'group_rooms_screen.dart';
import 'group_room_screen.dart';
import 'referral_screen.dart' show ReferralScreen;
import '../models/group_plan.dart';
import '../services/checklist_storage.dart';

part 'my_bookings_screen.dart';
part 'home_explore.part.dart';
part 'all_trips.part.dart';
part 'trip_cards.part.dart';
part 'bookings_section.part.dart';
part 'bookings_extras.part.dart';
part 'booking_detail.part.dart';
part 'booking_detail_layout.part.dart';
part 'booking_split.part.dart';
part 'booking_photos.part.dart';
part 'booking_receipts.part.dart';
part 'auth_booking.part.dart';
part 'package_planner.part.dart';
part 'trip_finder.part.dart';
part 'customer_app_helpers.part.dart';
part 'check_in_pass.part.dart';
part 'boarding_passes.part.dart';

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

  // Bookings already offered a review prompt this session — so we nudge at most
  // once per launch (a fresh launch will re-offer until the trip is reviewed,
  // since the backend keeps `can_review` true until then).
  final Set<int> _promptedReviewIds = {};
  bool _reviewDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationNavigator.registerTabSwitcher((index) => selectTab(index));
    NotificationNavigator.registerReviewPrompter(_promptReviewFromNotification);
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
        // An SOS raised while this phone was off, flat, or out of signal never
        // arrived — catch up on it the moment the phone is usable again.
        unawaited(app.recoverMissedSosAlerts());
        // และในทางกลับกัน — SOS ที่ "ผู้ใช้เครื่องนี้" กดตอนไม่มีสัญญาณยังค้าง
        // อยู่ในคิว การกลับเข้าแอปคือจังหวะที่มีโอกาสมีสัญญาณมากที่สุด
        unawaited(SosOutbox.instance.flush(force: true));
        // เช็คอินที่สตาฟกดไว้ตอนไม่มีสัญญาณก็เหมือนกัน — รถวิ่งออกจากจุดอับ
        // สัญญาณแล้วคนหยิบโทรศัพท์ขึ้นมา คือจังหวะที่คิวควรได้ออก
        unawaited(CheckInOutbox.instance.flush(force: true));
        // การ์ด "วันเดินทาง" อัปเดตตัวเองผ่าน APNs ได้ก็ต่อเมื่อเซิร์ฟเวอร์ถือ
        // token ของมันอยู่ ถ้าการฝากครั้งแรกล้มเหลว (เน็ตหลุดตอนกดจอง) นี่คือ
        // จังหวะที่ได้ลองใหม่ — เงียบและไม่มีค่าใช้จ่ายเมื่อไม่มีการ์ดเปิดอยู่
        //
        // และส่งรายการจองไปด้วย เพราะระบบเก็บการ์ดไปเองที่ราว 8 ชั่วโมง กลางทริป
        // สองวันจึงมีช่วงที่ไม่มีการ์ดทั้งที่ควรมี — ตรงนี้เปิดใบใหม่ให้
        unawaited(
          TripActivityService.instance.reregisterActiveTokens(
            bookings: app.bookings,
          ),
        );
        // วิดเจ็ตหน้าโฮมอ่านแต่ไฟล์ที่แอปเขียนไว้ ไม่ได้ต่อเน็ตเอง จังหวะที่แอป
        // กลับมาหน้าจอจึงเป็นจังหวะเดียวที่มันได้ข้อมูลใหม่ (มีตัวหน่วงในตัวอยู่
        // แล้ว การสลับแอปไปมาไม่ทำให้ยิงซ้ำ)
        unawaited(HomeWidgetService.instance.refresh());
        // สตาฟ: ถึงวันเดินทางของรอบที่ตัวเองรับผิดชอบเมื่อไหร่ มือถือเครื่องนี้
        // จะเป็น GPS ของรถให้เอง (และเลิกเองเมื่อรอบจบ) — ยิงถามเฉพาะวันที่มี
        // รอบใกล้ ๆ จริงเท่านั้น
        unawaited(app.refreshVehicleSharing());
      } else {
        unawaited(PushNotificationService.instance.clearBadge());
      }
    }
  }

  // Bottom-nav index of the "แชท" tab — also used to refresh unread on open.
  static const _chatTabIndex = 3;

  void selectTab(int value) {
    setState(() => _index = value);
    // Refresh the chat roster/unread badge whenever the user opens the tab so
    // counts reflect rooms read on other devices.
    if (value == _chatTabIndex) {
      final app = context.read<AppProvider>();
      if (app.isLoggedIn) unawaited(app.loadChatConversations());
    }
  }

  bool _checkInPassOpen = false;

  /// ปุ่ม QR กลางแถบเมนู — กันกดรัว ๆ แล้วแผ่นซ้อนกันหลายชั้น
  Future<void> _openCheckInPass() async {
    if (_checkInPassOpen) return;
    _checkInPassOpen = true;
    try {
      await CheckInPassSheet.show(
        context,
        onSelectTab: selectTab,
        onOpenBooking: (ref) {
          if (!mounted) return;
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => BookingDetailSheet(bookingRef: ref),
          );
        },
      );
    } finally {
      _checkInPassOpen = false;
    }
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

  /// On app open, if a finished trip is waiting to be reviewed, pop the review
  /// dialog automatically so every traveller gets the chance to review. The
  /// review window opens at 20:00 (Thai time) on the trip's last day, mirrored
  /// by the backend `can_review` flag and the 20:05 review-invite push.
  void _maybePromptReview(AppProvider app) {
    if (_reviewDialogOpen || !app.isLoggedIn) return;

    for (final raw in app.bookings) {
      final booking = asMap(raw);
      if (booking['can_review'] != true) continue;
      final id = int.tryParse('${booking['id']}');
      if (id == null || _promptedReviewIds.contains(id)) continue;

      _promptedReviewIds.add(id);
      _showReviewDialog(booking, id);
      break; // one nudge at a time
    }
  }

  /// Forced prompt from tapping a review-invite notification — re-shows even if
  /// already offered this session.
  void _promptReviewFromNotification(Map<String, dynamic> data) {
    final app = context.read<AppProvider>();
    final ref = textOf(data['booking_ref']);
    for (final raw in app.bookings) {
      final booking = asMap(raw);
      if (textOf(booking['booking_ref']) != ref) continue;
      if (booking['can_review'] != true) return;
      final id = int.tryParse('${booking['id']}');
      if (id == null) return;
      _showReviewDialog(booking, id);
      return;
    }
  }

  void _showReviewDialog(Map<String, dynamic> booking, int bookingId) {
    if (_reviewDialogOpen) return;
    _reviewDialogOpen = true;
    final trip = asMap(asMap(booking['schedule'])['trip']);
    ReviewSubmissionDialog.show(
      context,
      bookingId: bookingId,
      tripTitle: textOf(trip['title'], 'ทริปของคุณ'),
    ).whenComplete(() => _reviewDialogOpen = false);
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

    // After the frame settles, offer a review for any just-finished trip.
    if (app.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybePromptReview(app);
      });
    }

    final showStaffCheckIn = app.canUseStaffCheckIn;
    final pages = [
      const ExploreScreen(),
      const AllTripsScreen(showBackButton: false),
      const MyBookingsScreen(),
      const ChatListScreen(),
      const ProfileScreen(),
      if (showStaffCheckIn) const StaffWorkScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index >= pages.length ? pages.length - 1 : _index,
        children: pages,
      ),
      bottomNavigationBar: CustomBottomNav(
        index: _index >= pages.length ? pages.length - 1 : _index,
        showStaffCheckIn: showStaffCheckIn,
        unreadChatCount: app.chatUnreadTotal,
        onChanged: selectTab,
        onCheckInPass: _openCheckInPass,
      ),
    );
  }
}

class CustomBottomNav extends StatefulWidget {
  final int index;
  final bool showStaffCheckIn;
  final int unreadChatCount;
  final ValueChanged<int> onChanged;

  /// ปุ่ม QR เช็คอินกลางแถบ — เป็น "ปุ่ม" ไม่ใช่แท็บ (ไม่มีหน้าใน IndexedStack)
  /// index ของแท็บอื่นจึงไม่เลื่อน ลิงก์/แจ้งเตือนที่สลับแท็บด้วยเลขเดิมยังพาไปถูกที่
  final VoidCallback onCheckInPass;

  const CustomBottomNav({
    super.key,
    required this.index,
    required this.showStaffCheckIn,
    required this.onChanged,
    required this.onCheckInPass,
    this.unreadChatCount = 0,
  });

  /// ส่วนนูนกลางแถบสูงพ้นขอบบนของแถบเท่านี้ — หน้าที่เว้นระยะล่างเป็นตัวเลขตายตัว
  /// (ไม่อ่านจาก MediaQuery) ต้องบวกค่านี้ ไม่งั้นเนื้อหาท้ายหน้าจมใต้ปุ่ม QR
  static const double qrOverhang = _CustomBottomNavState._overhang;

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  static const double _barHeight = 68;
  static const double _qrButtonSize = 56;
  // จุดกึ่งกลางปุ่ม QR อยู่ต่ำกว่าขอบบนของแถบเท่านี้ — ปุ่มนั่งบนพื้นแถบ
  // แล้วขอบบนนูนโค้งขึ้นห่อครึ่งบนของปุ่มไว้ โดยเหลือพื้นแถบรอบปุ่ม _bumpPadding
  static const double _qrButtonCenterY = 8;
  static const double _bumpPadding = 6;
  static const double _bumpRadius = _qrButtonSize / 2 + _bumpPadding;
  // ส่วนนูนสูงพ้นขอบบนของแถบ = พื้นที่ที่ต้องเผื่อไว้เหนือแถบ
  static const double _overhang = _bumpRadius - _qrButtonCenterY;
  // ช่องกลางที่ว่างไว้ให้ปุ่ม QR + ป้าย "เช็คอิน" — ปุ่มกว้าง 56 จึงเหลือที่ข้างละ
  // 10 ไม่ให้ชิดไอคอนของแท็บข้าง ๆ
  static const double _centerSlotWidth = 76;

  static CurvedNavGeometry _geometryFor(Size size) => CurvedNavGeometry(
    centerX: size.width / 2,
    top: _overhang,
    guestCenterY: _qrButtonCenterY,
    bumpRadius: _bumpRadius,
    cornerRadius: AppTheme.radiusXl,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final items = _buildItems();
    // ปุ่ม QR อยู่กลางจอพอดีเสมอ: ลูกค้า 5 แท็บ = ซ้าย 2 ขวา 3, สตาฟ 6 แท็บ = 3/3
    // สองฝั่งกว้างเท่ากัน ฝั่งที่มีแท็บมากกว่าจึงวางไอคอนชิดกันกว่าเล็กน้อย
    final split = items.length ~/ 2;

    // Keep clearance from the home indicator, but trim a little of the
    // bottom inset so the icons sit lower instead of floating high.
    final bottomInset = (MediaQuery.viewPaddingOf(context).bottom - 4).clamp(
      0.0,
      double.infinity,
    );

    // Following iOS, the bar lifts off the page with the translucent blur and
    // a hairline top border — not a heavy drop shadow. The shadow that remains
    // is a single, very soft, low-opacity layer painted OUTSIDE the clip so it
    // isn't clipped away. Both now trace the curve around the QR button.
    final shadow = isDark
        ? BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, -2),
          )
        : BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, -1),
          );
    final borderColor = isDark
        ? AppTheme.outlineDark.withValues(alpha: 0.7)
        : AppTheme.border(context);

    Widget navItem(int i) => Expanded(
      child: _NavItem(
        icon: items[i].icon,
        activeIcon: items[i].activeIcon,
        label: items[i].label,
        isSelected: widget.index == i,
        // Chat tab (index 3) → unread messages. Unread notifications live on
        // the home header bell, not the "บัญชี" tab.
        badge: i == 3 ? widget.unreadChatCount : 0,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onChanged(i);
        },
      ),
    );

    // ความสูงรวมเผื่อส่วนนูนเหนือแถบไว้ด้วย ไม่งั้นส่วนนั้นทั้งวาดไม่ออกและกด
    // ไม่ติด (Flutter ไม่ hit-test นอกกรอบของ parent) พื้นหลังถูก clip ตามรูปทรง
    // แถบโปร่งใสข้างส่วนนูนจึงไม่รับการแตะ ทะลุลงไปถึงเนื้อหาด้านหลังตามปกติ
    return SizedBox(
      height: _overhang + _barHeight + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final geometry = _geometryFor(constraints.biggest);
                return CustomPaint(
                  painter: CurvedNavShadowPainter(
                    geometry: geometry,
                    shadow: shadow,
                  ),
                  foregroundPainter: CurvedNavBorderPainter(
                    geometry: geometry,
                    color: borderColor,
                  ),
                  child: ClipPath(
                    clipper: const CurvedNavClipper(_geometryFor),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: ColoredBox(
                        color: isDark
                            ? AppTheme.surfaceDark.withValues(alpha: 0.97)
                            : Colors.white.withValues(alpha: 0.97),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _overhang,
            height: _barHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [for (int i = 0; i < split; i++) navItem(i)],
                    ),
                  ),
                  SizedBox(
                    width: _centerSlotWidth,
                    child: _CheckInNavLabel(onTap: widget.onCheckInPass),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        for (int i = split; i < items.length; i++) navItem(i),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ยอดส่วนนูนอยู่ที่ y = 0 พอดี (_overhang = _bumpRadius - _qrButtonCenterY)
          Positioned(
            top: _overhang + _qrButtonCenterY - _bumpRadius,
            left: 0,
            right: 0,
            child: Center(
              child: _CheckInNavButton(
                size: _qrButtonSize,
                rim: _bumpPadding,
                onTap: widget.onCheckInPass,
              ),
            ),
          ),
        ],
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
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum_rounded,
      label: 'แชท',
    ),
    const _NavItemData(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'บัญชี',
    ),
    if (widget.showStaffCheckIn)
      const _NavItemData(
        icon: Icons.badge_outlined,
        activeIcon: Icons.badge_rounded,
        label: 'งานสตาฟ',
      ),
  ];
}

/// ปุ่มกลม QR เช็คอินกลางแถบเมนู — สีหลักทึบ แบน ไม่มีเงา (ตามสไตล์ทั้งแอป)
/// นั่งบนพื้นแถบ ครึ่งบนอยู่ในส่วนนูนโค้งที่ขอบแถบยกขึ้นมาห่อไว้
class _CheckInNavButton extends StatefulWidget {
  final double size;

  /// พื้นแถบรอบปุ่มในส่วนนูน — นับเป็นพื้นที่กดด้วย แตะขอบส่วนนูนก็เปิด QR
  final double rim;
  final VoidCallback onTap;

  const _CheckInNavButton({
    required this.size,
    required this.rim,
    required this.onTap,
  });

  @override
  State<_CheckInNavButton> createState() => _CheckInNavButtonState();
}

class _CheckInNavButtonState extends State<_CheckInNavButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'แสดง QR เช็คอิน',
      excludeSemantics: true,
      // ClipOval จำกัดการแตะให้อยู่ในวงกลมของส่วนนูน — มุมสี่เหลี่ยมนอกวง
      // ไม่บังการแตะเนื้อหาด้านหลัง
      child: ClipOval(
        child: GestureDetector(
          key: const ValueKey('nav-check-in-qr'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onTap();
          },
          child: Padding(
            padding: EdgeInsets.all(widget.rim),
            child: AnimatedScale(
              scale: _pressed ? 0.92 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ป้าย "เช็คอิน" ใต้ปุ่ม QR — วางระดับเดียวกับป้ายของแท็บอื่น (เว้นที่ไอคอน 32
/// + ช่องไฟ 3 เท่า [_NavItem]) และกดได้ทั้งช่องเพื่อให้เป้ากว้าง
class _CheckInNavLabel extends StatelessWidget {
  final VoidCallback onTap;

  const _CheckInNavLabel({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.isDark(context)
        ? AppTheme.accentColor
        : AppTheme.primaryColor;
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: SizedBox(
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'เช็คอิน',
                  maxLines: 1,
                  style: appFont(
                    fontSize: AppText.sizeMicro,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    _iconScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOut),
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
        ? AppTheme.mutedText(context)
        : AppTheme.mutedText(context);

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
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.surfaceDark
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 19,
                            minHeight: 19,
                          ),
                          child: Text(
                            widget.badge > 99 ? '99+' : '${widget.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: AppText.sizeMicro,
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
              style: appFont(
                fontSize: AppText.sizeMicro,
                fontWeight: widget.isSelected
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: widget.isSelected ? activeColor : inactiveColor,
                letterSpacing: widget.isSelected ? 0.1 : 0,
              ),
              // ฝั่งขวามีสามแท็บในพื้นที่เท่าฝั่งซ้าย — ตัวอักษรขยาย (textScaler) จะ
              // ล้นช่องแคบ ๆ ได้ ย่อลงแทนการล้น
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(widget.label, maxLines: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

