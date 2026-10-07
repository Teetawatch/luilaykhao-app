import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/api_endpoints.dart';
import '../models/chat_notify_level.dart';
import '../models/pickup_vehicle_class.dart';
import '../models/sos_alert.dart';
import '../models/medal_social.dart';
import '../models/trip_medal.dart';
import '../services/analytics_service.dart';
import '../services/api_client.dart';
import '../services/booking_draft_store.dart';
import '../services/connectivity_service.dart';
import '../services/home_widget_service.dart';
import '../services/notification_navigator.dart';
import '../services/offline_cache.dart';
import '../services/push_notification_service.dart';
import '../services/rating_prompt_service.dart';
import '../services/realtime_service.dart';
import '../services/secure_storage.dart';
import '../services/check_in_outbox.dart';
import '../services/sos_outbox.dart';
import '../services/trek_recorder_service.dart';
import '../services/trip_activity_service.dart';
import '../services/staff_trip_pack.dart';
import '../services/trip_day_pack.dart';
import '../services/trip_live_location_service.dart';
import '../services/vehicle_location_sharing.dart';
import '../services/version_gate_service.dart';

class AppProvider extends ChangeNotifier {
  static const _tokenKey = 'auth_token';
  static const _themeModeKey = 'theme_mode';
  static const _localeKey = 'app_locale';

  final ApiClient api = ApiClient();
  final RealtimeService realtime = RealtimeService.instance;
  final List<VoidCallback> _userChannelDisposers = [];
  VoidCallback? _onSessionExpired;
  bool _handlingUnauthorized = false;
  bool _deletingAccount = false;
  VersionGateResult _versionGate = VersionGateResult.ok;
  VersionGateResult get versionGate => _versionGate;

  /// True while the backend is in maintenance mode (any request returned 503,
  /// i.e. `php artisan down`). Raises a full-screen gate; cleared by a probe
  /// once the server is back up.
  bool _maintenance = false;
  bool get maintenance => _maintenance;
  bool _recheckingMaintenance = false;
  bool get recheckingMaintenance => _recheckingMaintenance;

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('th');
  Locale get locale => _locale;
  bool booting = true;
  bool busy = false;
  String? error;
  Map<String, dynamic>? user;

  StreamSubscription<Uri>? _deepLinkSub;
  String? _pendingSocialError;

  List<dynamic> trips = [];
  List<dynamic> featuredTrips = [];
  List<dynamic> almostFullTrips = [];
  List<dynamic> flashSaleTrips = [];

  /// แคมเปญวันพิเศษที่กำลังลดราคาทั้งเว็บอยู่ (9.9 / 10.10) — null เมื่อไม่มี
  /// ราคาที่แอปโชว์ถูกลดมาจากเซิร์ฟเวอร์แล้ว ก้อนนี้มีไว้บอกว่า "ทำไมถึงถูกลง"
  Map<String, dynamic>? saleCampaign;
  List<dynamic> categories = [];
  /// ไกด์ประเภทรถรับ-ส่งจุดรับต่างภูมิภาค — โหลดครั้งเดียวแล้วใช้ซ้ำทั้งแอป
  List<PickupVehicleClass> pickupVehicleClasses = [];
  bool _pickupVehicleClassesLoaded = false;
  /// การจองของบัญชีนี้ = ทริปที่ยังไม่จบ "ทั้งหมด" + ประวัติ "เท่าที่โหลดแล้ว"
  ///
  /// ทริปที่ยังไม่จบมีจำนวนจำกัดโดยธรรมชาติจึงโหลดครบทุกครั้ง ทุกจุดที่สนใจทริป
  /// ข้างหน้า (หน้าแรก วันเดินทาง การ์ดล็อกสกรีน วิดเจ็ต) อ่านรายการนี้ได้เหมือนเดิม
  /// ส่วนประวัติ (เดินทางแล้ว/ยกเลิก) โตขึ้นเรื่อย ๆ จึงโหลดทีละหน้าผ่าน
  /// [loadMoreBookingHistory] — ตัวเลขรวมให้อ่านจาก [bookingsTotalCount] และ
  /// [unloadedTravelledCount] / [unloadedCancelledCount] ไม่ใช่ `bookings.length`
  List<dynamic> bookings = [];
  static const bookingHistoryPageSize = 20;
  /// meta ของประวัติจากเซิร์ฟเวอร์ (ยอดนับทั้งชุด) — null = ไม่รู้ (เทสต์/แคชรุ่นเก่า)
  /// ซึ่งถือว่าสิ่งที่อยู่ใน [bookings] คือทั้งหมดแล้ว
  Map<String, dynamic>? bookingHistoryMeta;
  int _bookingHistoryPage = 0;
  final Set<String> _bookingHistoryIds = {};
  /// เพิ่มขึ้นทุกครั้งที่รายการถูกโหลดใหม่/ล้าง — หน้าที่กำลังโหลดค้างจากรอบก่อน
  /// จะถูกทิ้งแทนที่จะต่อท้ายรายการชุดใหม่
  int _bookingHistoryGen = 0;
  bool bookingHistoryLoading = false;
  String? bookingHistoryError;

  int _historyMetaInt(String key) =>
      int.tryParse('${bookingHistoryMeta?[key] ?? ''}') ?? 0;

  bool get bookingHistoryHasMore =>
      bookingHistoryMeta != null &&
      _bookingHistoryPage < _historyMetaInt('last_page');

  Iterable<Map> get _loadedHistory => bookings
      .whereType<Map>()
      .where((b) => _bookingHistoryIds.contains('${b['id']}'));

  static bool _isCancelledStatus(Map booking) =>
      const ['cancelled', 'refunded'].contains('${booking['status']}');

  /// จำนวนการจองทั้งหมดของบัญชี รวมประวัติหน้าที่ยังไม่ได้โหลด
  int get bookingsTotalCount {
    if (bookingHistoryMeta == null) return bookings.length;
    final unloaded =
        _historyMetaInt('history_count') - _bookingHistoryIds.length;
    return bookings.length + (unloaded > 0 ? unloaded : 0);
  }

  /// ทริปที่เดินทางแล้ว (ไม่นับยกเลิก) ที่อยู่ในหน้าประวัติที่ยังไม่ได้โหลด —
  /// หน้าจอนับใบที่โหลดแล้วเอง แล้วบวกตัวนี้
  int get unloadedTravelledCount {
    if (bookingHistoryMeta == null) return 0;
    final loaded = _loadedHistory.where((b) => !_isCancelledStatus(b)).length;
    final n = _historyMetaInt('travelled_count') - loaded;
    return n > 0 ? n : 0;
  }

  /// ใบที่ยกเลิก/คืนเงินแล้วที่อยู่ในหน้าประวัติที่ยังไม่ได้โหลด
  int get unloadedCancelledCount {
    if (bookingHistoryMeta == null) return 0;
    final loaded = _loadedHistory.where(_isCancelledStatus).length;
    final n = _historyMetaInt('cancelled_count') - loaded;
    return n > 0 ? n : 0;
  }

  /// จำนวนจุดหมายที่เคยไปจากประวัติทั้งชุด (null = ไม่รู้)
  int? get travelledDestinationsCount => bookingHistoryMeta == null
      ? null
      : _historyMetaInt('destinations_count');

  // True once account data (incl. bookings) has been loaded at least once —
  // from the network or a cache restore. Lets screens show a skeleton on the
  // very first load instead of flashing an empty state.
  bool accountLoaded = false;
  /// ข้อความผิดพลาดของการโหลดการจองครั้งล่าสุด (null = สำเร็จ) — ให้หน้าจอ
  /// แสดงสถานะผิดพลาดพร้อมปุ่มลองใหม่ แทนที่จะค้างอยู่ที่ skeleton ตลอดไป
  String? accountError;
  List<dynamic> notifications = [];
  List<dynamic> reviews = [];
  List<dynamic> recentlyViewedTrips = [];
  List<dynamic> myReviews = [];
  List<dynamic> rewards = [];
  List<dynamic> coupons = [];
  List<dynamic> promotions = [];
  List<dynamic> heroSlides = [];
  List<dynamic> activeSeatLocks = [];
  List<dynamic> staffSchedules = [];
  Map<String, dynamic> staffSummary = {};
  // Trip group-chat rooms the user belongs to (for the "แชท" tab) + total unread.
  List<dynamic> chatConversations = [];
  int chatUnreadTotal = 0;
  // Unread messages from the team in the support inbox (ศูนย์ช่วยเหลือ).
  int supportUnread = 0;
  Map<String, dynamic>? loyalty;
  Map<String, dynamic>? referral;
  Map<String, dynamic>? stats;
  Timer? _activeSeatLockTimer;
  bool _activeSeatLocksLoading = false;

  bool get isLoggedIn => api.token != null && api.token!.isNotEmpty;
  String? get token => api.token;
  int? get userId => int.tryParse('${user?['id']}');
  ThemeMode get themeMode => _themeMode;
  String? get pendingSocialError => _pendingSocialError;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  List<String> get roleNames {
    final roles = user?['roles'];
    if (roles is! List) return const [];

    return roles
        .map((role) {
          if (role is Map) return role['name']?.toString() ?? '';
          return role?.toString() ?? '';
        })
        .where((role) => role.isNotEmpty)
        .toList(growable: false);
  }

  /// Whether the "งานสตาฟ" tab and staff check-in are available. Gated to the
  /// `staff` role only — the backend staff manifest endpoint is staff-only, so
  /// operators/admins (who have their own tooling) shouldn't see this tab.
  bool get canUseStaffCheckIn => roleNames.contains('staff');

  /// บัญชีแอดมิน — จองในแอปได้โดยข้ามหน้าชำระเงิน (หลังบ้านตรวจสิทธิ์ซ้ำอีกชั้น
  /// ที่ BookingController ธงจากแอปเพียงอย่างเดียวยืนยันการจองให้ไม่ได้)
  bool get isAdmin => roleNames.contains('admin');

  /// คนจัดของ — บทบาทเสริม `packer` ที่แอดมินเปิดให้ในหน้าผู้ใช้ (ซ้อนบน
  /// บทบาทหลักใดก็ได้ รวมถึงลูกค้า) เปิดใบเตรียมของแต่ละรอบในแอปได้
  /// แอดมิน/เจ้าหน้าที่เปิดได้ด้วยเพื่อดูว่าคนจัดของเห็นอะไร
  bool get canViewPackingList =>
      roleNames.contains('packer') ||
      roleNames.contains('admin') ||
      roleNames.contains('operator');

  int get unreadNotificationCount =>
      notifications.where((n) => (n as Map?)?['is_read'] != true).length;

  void _syncAppIconBadge() {
    unawaited(
      PushNotificationService.instance.setBadgeCount(unreadNotificationCount),
    );
  }

  void setOnSessionExpired(VoidCallback callback) {
    _onSessionExpired = callback;
  }

  void _handleMaintenance() {
    if (_maintenance) return;
    _maintenance = true;
    notifyListeners();
  }

  /// Probe the backend to see whether maintenance mode has ended. Uses the
  /// lightweight public `app/version` endpoint — during `php artisan down` it
  /// returns 503 (keeps the gate up); once the server is back it succeeds and
  /// we lower the gate so the app resumes normally.
  Future<void> recheckMaintenance() async {
    if (_recheckingMaintenance) return;
    _recheckingMaintenance = true;
    notifyListeners();
    try {
      await api.get('app/version');
      _maintenance = false;
    } on ApiException catch (e) {
      // Still 503 → stay on the gate. Any other error (network, etc.) we also
      // treat as "not yet back" and keep the gate up.
      if (e.statusCode != 503) _maintenance = false;
    } catch (_) {
      // Network hiccup — leave the gate up, let the user try again.
    } finally {
      _recheckingMaintenance = false;
      notifyListeners();
    }
  }

  /// True while an expired session is being torn down — logging out, then
  /// bouncing to the login screen.
  ///
  /// Anything that puts UI on the root navigator has to wait this out. The
  /// teardown ends in `pushAndRemoveUntil(..., (route) => false)`, which
  /// removes *every* route, dialogs included. It is also slower than it looks:
  /// `logout()` makes two network round trips first, so the bounce can land
  /// seconds after the 401 that caused it — long after boot has finished.
  bool get sessionExpiring => _handlingUnauthorized;

  Future<void> _handleUnauthorized() async {
    // While deleting the account the token is intentionally invalidated
    // server-side; ignore the resulting 401s so the session-expired handler
    // does not tear down the navigation stack mid-flow.
    if (_deletingAccount) return;
    if (_handlingUnauthorized) return;
    if (!isLoggedIn) return;
    _handlingUnauthorized = true;
    notifyListeners();
    try {
      await AnalyticsService.instance.log('session_expired_auto_logout');
      await logout();
      _onSessionExpired?.call();
    } finally {
      _handlingUnauthorized = false;
      notifyListeners();
    }
  }

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final secureToken = await SecureStorage.instance.readToken();
    api.token = secureToken ?? prefs.getString(_tokenKey);
    if (secureToken == null && api.token != null && api.token!.isNotEmpty) {
      // Migrate legacy plaintext token to secure storage.
      await SecureStorage.instance.writeToken(api.token!);
      await prefs.remove(_tokenKey);
    }
    api.onUnauthorized = () {
      // Defer so the current request returns its error first.
      Future.microtask(_handleUnauthorized);
    };
    api.onMaintenance = () {
      // Defer so the current request returns its error first.
      Future.microtask(_handleMaintenance);
    };
    _themeMode = _themeModeFromStorage(prefs.getString(_themeModeKey));
    _locale = _localeFromStorage(prefs.getString(_localeKey));
    realtime.attachApi(api);
    TripActivityService.instance.attachApi(api);
    HomeWidgetService.instance.attachApi(api);
    unawaited(ConnectivityService.instance.initialize());
    unawaited(
      VersionGateService.instance.check(api).then((result) {
        _versionGate = result;
        notifyListeners();
      }),
    );
    await OfflineCache.instance.load();
    _hydrateFromCache();
    // ต้องผูกหลัง OfflineCache โหลดเสร็จ — คิว SOS อยู่ในนั้น และแถบเตือน
    // "ยังส่งไม่สำเร็จ" จะไม่ขึ้นเลยถ้านับจำนวนตอนแคชยังว่าง
    SosOutbox.instance.attach(this);
    unawaited(SosOutbox.instance.flush(force: true));
    // เหตุผลเดียวกันสำหรับคิวเช็คอินของสตาฟ — รายการที่ค้างจากจุดรับที่ไม่มี
    // สัญญาณเมื่อเช้า ต้องได้ออกทันทีที่แอปเปิดในที่ที่มีสัญญาณ
    CheckInOutbox.instance.attach(this);
    unawaited(CheckInOutbox.instance.flush(force: true));
    notifyListeners();
    _initDeepLinks();
    // Push init must NOT block the first data load. On iOS real devices the
    // APNs-dependent calls inside initialize() (getInitialMessage / the
    // permission prompt) can stall until APNs registration completes, whereas
    // on the simulator they return instantly because there's no APNs. That
    // discrepancy is why TestFlight builds showed no data while the simulator
    // worked: loadPublicData() below was sequenced after this await. Fire it
    // unawaited and sync the FCM token once it finishes.
    unawaited(
      PushNotificationService.instance
          .initialize(
            onRefreshRequested: () {
              if (isLoggedIn) loadAccountData();
            },
          )
          .then((_) {
            if (isLoggedIn) {
              unawaited(PushNotificationService.instance.syncToken(api));
            }
          }),
    );
    try {
      await Future.wait([loadPublicData(), if (isLoggedIn) refreshMe()]);
      if (isLoggedIn) {
        await loadAccountData();
        await loadActiveSeatLocks();
        startActiveSeatLockPolling();
        await _bindUserChannel();
        unawaited(preloadBlockedUsers());
      }
    } catch (e) {
      error = e.toString();
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  void _hydrateFromCache() {
    final cache = OfflineCache.instance;
    trips = List<dynamic>.from(cache.readPublic<List>('trips') ?? const []);
    featuredTrips = List<dynamic>.from(
      cache.readPublic<List>('featured') ?? const [],
    );
    almostFullTrips = List<dynamic>.from(
      cache.readPublic<List>('almost_full') ?? const [],
    );
    flashSaleTrips = List<dynamic>.from(
      cache.readPublic<List>('flash_sale') ?? const [],
    );
    final cachedCampaign = cache.readPublic<Map>('sale_campaign');
    // แคมเปญที่แคชไว้อาจจบไปแล้วตั้งแต่เปิดแอปครั้งก่อน — เช็ควันหมดก่อนใช้
    saleCampaign = _liveCampaign(
      cachedCampaign == null ? null : Map<String, dynamic>.from(cachedCampaign),
    );
    categories = List<dynamic>.from(
      cache.readPublic<List>('categories') ?? const [],
    );
    pickupVehicleClasses = PickupVehicleClass.listFrom(
      cache.readPublic<List>('pickup_vehicle_classes'),
    );
    reviews = List<dynamic>.from(cache.readPublic<List>('reviews') ?? const []);
    recentlyViewedTrips = List<dynamic>.from(
      cache.readPublic<List>('recently_viewed') ?? const [],
    );
    promotions = List<dynamic>.from(
      cache.readPublic<List>('promotions') ?? const [],
    );
    heroSlides = List<dynamic>.from(
      cache.readPublic<List>('hero_slides') ?? const [],
    );
    stats = Map<String, dynamic>.from(
      cache.readPublic<Map>('stats') ?? const {},
    );

    if (isLoggedIn) {
      final cachedUser = cache.readAccount<Map>('user');
      if (cachedUser != null) user = Map<String, dynamic>.from(cachedUser);
      bookings = List<dynamic>.from(
        cache.readAccount<List>('bookings') ?? const [],
      );
      _restoreBookingHistoryState(cache.readAccount<Map>('bookingHistory'));
      notifications = List<dynamic>.from(
        cache.readAccount<List>('notifications') ?? const [],
      );
      final cachedLoyalty = cache.readAccount<Map>('loyalty');
      loyalty = cachedLoyalty == null
          ? null
          : Map<String, dynamic>.from(cachedLoyalty);
      rewards = List<dynamic>.from(
        cache.readAccount<List>('rewards') ?? const [],
      );
      coupons = List<dynamic>.from(
        cache.readAccount<List>('coupons') ?? const [],
      );
      myReviews = List<dynamic>.from(
        cache.readAccount<List>('myReviews') ?? const [],
      );
    }
  }

  Future<void> _bindUserChannel() async {
    final userId = user?['id']?.toString();
    if (userId == null || userId.isEmpty) return;
    for (final dispose in _userChannelDisposers) {
      dispose();
    }
    _userChannelDisposers.clear();

    final channel = 'private-user.$userId';
    _userChannelDisposers.add(
      await realtime.subscribe(
        channel: channel,
        event: 'PaymentConfirmed',
        handler: (_) => loadAccountData(),
      ),
    );
    _userChannelDisposers.add(
      await realtime.subscribe(
        channel: channel,
        event: 'SosTriggered',
        handler: (data) => NotificationNavigator.handle('sos_alert', data),
      ),
    );

    // A session that starts mid-emergency (fresh launch, re-login) has missed
    // every push and broadcast that already went out.
    unawaited(recoverMissedSosAlerts());
  }

  Future<void> _unbindUserChannel() async {
    for (final dispose in _userChannelDisposers) {
      dispose();
    }
    _userChannelDisposers.clear();
    await realtime.disconnect();
  }

  void _initDeepLinks() {
    final appLinks = AppLinks();
    _deepLinkSub?.cancel();
    _deepLinkSub = appLinks.uriLinkStream.listen(
      _dispatchDeepLink,
      onError: (_) {},
    );
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _dispatchDeepLink(uri);
    });
  }

  Future<void> _dispatchDeepLink(Uri uri) async {
    // Trip/booking links take precedence; fall through to social auth flow.
    if (NotificationNavigator.handleDeepLink(uri)) return;
    await _handleSocialDeepLink(uri);
  }

  Future<void> _handleSocialDeepLink(Uri uri) async {
    if (uri.scheme != 'luilaykhao' ||
        uri.host != 'auth' ||
        uri.path != '/social/callback') {
      return;
    }

    final params = uri.queryParameters;
    final errorMsg = params['error'];
    if (errorMsg != null && errorMsg.isNotEmpty) {
      final message = params['message']?.isNotEmpty == true
          ? params['message']!
          : 'เข้าสู่ระบบผ่าน Social ไม่สำเร็จ';
      _pendingSocialError = message;
      notifyListeners();
      return;
    }

    final token = params['token'];
    final userParam = params['user'];
    if (token == null || token.isEmpty || userParam == null) {
      _pendingSocialError = 'ไม่พบข้อมูลเข้าสู่ระบบจาก Social';
      notifyListeners();
      return;
    }

    try {
      final decodedUser = jsonDecode(userParam);
      await completeSocialLogin(
        token: token,
        user: Map<String, dynamic>.from(decodedUser as Map),
      );
    } catch (e) {
      _pendingSocialError = e.toString();
      notifyListeners();
    }
  }

  void clearPendingSocialError() {
    _pendingSocialError = null;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  Future<void> toggleThemeMode() {
    return setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  Future<void> loadPublicData({String? search, String? type}) async {
    // แต่ละ endpoint แยกกันด้วย safe() — ถ้าตัวใดพัง (timeout/สะดุด) จะไม่ทำให้
    // ตัวอื่นหายไปทั้งหมด โดยเฉพาะรายการทริปหน้าแรก (เคยเป็น Future.wait แบบ
    // fail-fast ที่ทำให้ทั้งหน้าว่างเมื่อมี endpoint เดียว error)
    Future<dynamic> safe(Future<dynamic> f) => f.catchError((_) => null);

    final results = await Future.wait([
      safe(
        api.get(
          ApiEndpoints.trips,
          query: {'per_page': 30, 'search': search, 'type': type},
        ),
      ),
      safe(api.get(ApiEndpoints.tripsFeatured)),
      safe(api.get(ApiEndpoints.categories)),
      safe(api.get(ApiEndpoints.reviews, query: {'per_page': 8})),
      safe(api.get(ApiEndpoints.stats)),
      safe(api.get(ApiEndpoints.promotionsActive)),
      safe(api.get(ApiEndpoints.heroSlides)),
      safe(api.get('trips/almost-full')),
      safe(api.get('trips/flash-sale')),
      safe(api.get('sale-campaign/active')),
    ]);

    final cache = OfflineCache.instance;
    if (results[0] != null) {
      trips = List<dynamic>.from(api.data(results[0]) ?? []);
      cache.writePublic('trips', trips);
    }
    if (results[1] != null) {
      featuredTrips = List<dynamic>.from(api.data(results[1]) ?? []);
      cache.writePublic('featured', featuredTrips);
    }
    if (results[2] != null) {
      categories = List<dynamic>.from(api.data(results[2]) ?? []);
      cache.writePublic('categories', categories);
    }
    if (results[3] != null) {
      reviews = List<dynamic>.from(api.data(results[3]) ?? []);
      cache.writePublic('reviews', reviews);
    }
    if (results[4] != null) {
      stats = Map<String, dynamic>.from(api.data(results[4]) ?? {});
      cache.writePublic('stats', stats);
    }
    if (results[5] != null) {
      promotions = List<dynamic>.from(api.data(results[5]) ?? []);
      cache.writePublic('promotions', promotions);
    }
    if (results[6] != null) {
      heroSlides = List<dynamic>.from(api.data(results[6]) ?? []);
      cache.writePublic('hero_slides', heroSlides);
    }
    if (results[7] != null) {
      almostFullTrips = List<dynamic>.from(api.data(results[7]) ?? []);
      cache.writePublic('almost_full', almostFullTrips);
    }
    if (results[8] != null) {
      flashSaleTrips = List<dynamic>.from(api.data(results[8]) ?? []);
      cache.writePublic('flash_sale', flashSaleTrips);
    }
    if (results[9] != null) {
      // endpoint คืน data: null เมื่อไม่มีแคมเปญ ซึ่งเป็นคำตอบที่ถูกต้อง
      // ไม่ใช่ความผิดพลาด — เขียนทับแคชด้วย null ได้เลย
      final raw = api.data(results[9]);
      saleCampaign = _liveCampaign(
        raw is Map ? Map<String, dynamic>.from(raw) : null,
      );
      cache.writePublic('sale_campaign', saleCampaign ?? const {});
    }
    notifyListeners();
  }

  /// คืนแคมเปญเฉพาะตอนที่มันยังไม่หมดเวลา ไม่งั้นคืน null
  ///
  /// แอปเปิดค้างข้ามเที่ยงคืนได้ และแคชก็อยู่ข้ามการเปิดแอป การ์ดแคมเปญจึงต้อง
  /// ตรวจวันหมดเองทุกครั้ง แทนที่จะเชื่อว่าอะไรก็ตามที่โหลดมาแล้วยังใช้ได้อยู่
  Map<String, dynamic>? _liveCampaign(Map<String, dynamic>? campaign) {
    if (campaign == null || campaign.isEmpty) return null;
    final endsAt = DateTime.tryParse('${campaign['ends_at'] ?? ''}');
    if (endsAt == null || endsAt.isBefore(DateTime.now())) return null;
    return campaign;
  }

  /// โหลดไกด์ประเภทรถรับ-ส่งครั้งเดียวต่อการเปิดแอป
  ///
  /// ไม่ได้อยู่ใน [loadPublicData] เพราะหน้าแรกไม่ได้ใช้ — เรียกจากหน้าที่แสดง
  /// จุดรับจริง ๆ (รายละเอียดทริป/ขั้นตอนจอง) พังก็เงียบ ๆ ไป เพราะเป็นแค่
  /// ข้อมูลประกอบ ไม่ควรทำให้หน้าจองสะดุด
  Future<void> ensurePickupVehicleClasses({bool force = false}) async {
    if (_pickupVehicleClassesLoaded && !force) return;
    _pickupVehicleClassesLoaded = true;

    try {
      final response = await api.get(ApiEndpoints.pickupVehicleClasses);
      final classes = PickupVehicleClass.listFrom(api.data(response));
      if (classes.isEmpty && pickupVehicleClasses.isNotEmpty) return;

      pickupVehicleClasses = classes;
      OfflineCache.instance.writePublic(
        'pickup_vehicle_classes',
        classes.map((c) => c.toJson()).toList(),
      );
      notifyListeners();
    } catch (_) {
      // เก็บของเดิมจากแคชไว้ใช้ต่อ และเปิดให้ลองใหม่รอบหน้า
      _pickupVehicleClassesLoaded = false;
    }
  }

  /// ประเภทรถที่ตรงกับจำนวนผู้โดยสาร [pax] (null = ไม่มีช่วงไหนครอบคลุม)
  PickupVehicleClass? pickupVehicleClassFor(int pax) {
    for (final c in pickupVehicleClasses) {
      if (c.covers(pax)) return c;
    }
    return null;
  }

  Future<Map<String, dynamic>> trip(String slug) async {
    final response = await api.get('trips/$slug');
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Remembers a trip the user just opened so the home "ดูล่าสุด" rail can
  /// resurface it. Stores a trimmed copy (only the fields a trip card needs),
  /// most-recent first, deduped by slug, capped at [_recentTripLimit].
  static const int _recentTripLimit = 10;

  void recordRecentTrip(Map<String, dynamic> trip) {
    final slug = trip['slug']?.toString() ?? '';
    if (slug.isEmpty) return;

    final card = <String, dynamic>{
      'id': trip['id'],
      'slug': slug,
      'title': trip['title'],
      'location': trip['location'],
      'price_per_person': trip['price_per_person'],
      'cover_image': trip['cover_image'],
      'thumbnail_image': trip['thumbnail_image'],
      'rating': trip['rating'],
      'review_count': trip['review_count'],
      'duration_days': trip['duration_days'],
      'type': trip['type'],
    };

    final next = [
      card,
      ...recentlyViewedTrips
          .map(_asMap)
          .where((t) => t['slug']?.toString() != slug),
    ].take(_recentTripLimit).toList();

    recentlyViewedTrips = next;
    OfflineCache.instance.writePublic('recently_viewed', next);
    notifyListeners();
  }

  Future<List<dynamic>> schedules(String slug) async {
    final response = await api.get('trips/$slug/schedules');
    return List<dynamic>.from(api.data(response) ?? []);
  }

  /// "ทริปที่คล้ายกัน" — up to 6 other active trips the backend ranks as
  /// related (same type/region, upcoming rounds preferred).
  Future<List<dynamic>> relatedTrips(String slug) async {
    final response = await api.get('trips/$slug/related');
    return List<dynamic>.from(api.data(response) ?? []);
  }

  // ── "ทริปนี้ไหวไหม" ────────────────────────────────────────────────────────
  // เทียบระยะทาง/ความสูงของทริปกับสิ่งที่ผู้ใช้เคยเดินมา (ประวัติจริงก่อน
  // ถ้าไม่มีจึงใช้ค่าที่กรอกเอง) endpoint เป็น public จึงเรียกได้แม้ยังไม่ล็อกอิน

  Future<Map<String, dynamic>> tripReadiness(String slug) async {
    final response = await api.get('trips/$slug/readiness');
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  // ── ความคืบหน้าระหว่างทริป ────────────────────────────────────────────────
  // สร้างจากกำหนดการที่ทีมงานกดยืนยัน ไม่ใช้ GPS ลูกค้า
  //
  // แคชผลไว้ต่อ booking เพราะหน้านี้ถูกเปิดตอนอยู่บนดอยที่มักไม่มีสัญญาณ
  // ผู้ใช้ควรเห็นหมุดล่าสุดที่โหลดไว้ แทนที่จะเห็นจอเปล่า

  static String _progressCacheKey(String ref) => 'trip_progress.$ref';

  /// ความคืบหน้าที่แคชไว้ล่าสุดของการจองนี้ (null เมื่อยังไม่เคยโหลดสำเร็จ)
  Map<String, dynamic>? cachedTripProgress(String ref) {
    final cached = OfflineCache.instance.readAccount<Map>(
      _progressCacheKey(ref),
    );
    return cached == null ? null : Map<String, dynamic>.from(cached);
  }

  Future<Map<String, dynamic>> tripProgress(String ref) async {
    final response = await api.get('bookings/$ref/progress');
    final data = Map<String, dynamic>.from(api.data(response) ?? const {});

    OfflineCache.instance.writeAccount(_progressCacheKey(ref), {
      ...data,
      'cached_at': DateTime.now().toIso8601String(),
    });

    return data;
  }

  /// "ช่วยกันเปิดรอบ" — สถานะการชวนเพื่อนของรอบนี้ (403 เมื่อยังไม่ได้จอง)
  Future<Map<String, dynamic>> scheduleRally(int scheduleId) async {
    final response = await api.get('schedules/$scheduleId/rally');
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  /// บันทึกค่าอ้างอิงที่ผู้ใช้กรอกเอง (อย่างน้อยหนึ่งค่า)
  Future<void> saveHikingBaseline({
    double? maxDistanceKm,
    int? maxElevationGainM,
  }) async {
    await api.post('me/hiking-baseline', body: {
      'max_distance_km': ?maxDistanceKm,
      'max_elevation_gain_m': ?maxElevationGainM,
    });
  }

  // ── Waitlist (คิวรอที่นั่งว่าง) ─────────────────────────────────────────────
  // Backend manages the queue, offers seats on cancellation (15-min TTL) and
  // pushes waitlist_offered/expired notifications; the app just drives the
  // join/leave/status surface.

  /// Joins the waitlist for a sold-out schedule. Returns the created entry.
  Future<Map<String, dynamic>> joinWaitlist(
    int scheduleId, {
    int seatCount = 1,
  }) async {
    final response = await api.post(
      'schedules/$scheduleId/waitlist',
      body: {'seat_count': seatCount},
    );
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  /// Leaves the waitlist for a schedule.
  Future<void> leaveWaitlist(int scheduleId) async {
    await api.delete('schedules/$scheduleId/waitlist');
  }

  /// Current user's waitlist standing for a single schedule, e.g.
  /// `{in_waitlist: bool, status, position, expires_in_seconds, ...}`.
  Future<Map<String, dynamic>> waitlistStatus(int scheduleId) async {
    final response = await api.get('schedules/$scheduleId/waitlist/status');
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  /// All active (waiting/offered) waitlist entries for the current user.
  Future<List<dynamic>> myWaitlistEntries() async {
    final response = await api.get('waitlist');
    return List<dynamic>.from(api.data(response) ?? []);
  }

  /// สมุดสะสมการเดินทาง (Passport) — สถิติตลอดชีพ + ตราสะสมของผู้ใช้ปัจจุบัน.
  Future<Map<String, dynamic>> fetchPassport() async {
    final response = await api.get('me/passport');
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  // ── ตู้เหรียญพิชิต ──────────────────────────────────────────────────────

  MedalCabinet? _medalCabinet;
  DateTime? _medalCabinetAt;

  /// ตู้เหรียญล่าสุดที่โหลดไว้ — หน้าใบจอง/Passport ใช้เช็คเร็ว ๆ ว่ามีเหรียญไหม
  MedalCabinet? get medalCabinet => _medalCabinet;

  /// ตู้เหรียญพิชิต (GET /me/medals)
  ///
  /// จำไว้หนึ่งนาที เพราะหน้า Passport หน้าใบจอง และตู้เหรียญเรียกต่อกันได้
  /// ในไม่กี่วินาที — [force] ใช้ตอนดึงลงเพื่อรีเฟรช
  Future<MedalCabinet> fetchMedals({bool force = false}) async {
    final cached = _medalCabinet;
    final at = _medalCabinetAt;

    if (!force &&
        cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 1)) {
      return cached;
    }

    final response = await api.get('me/medals');
    final cabinet = MedalCabinet.fromJson(
      Map<String, dynamic>.from(api.data(response) ?? const {}),
    );

    _medalCabinet = cabinet;
    _medalCabinetAt = DateTime.now();

    return cabinet;
  }

  /// เปลี่ยนทรงเหรียญ (null = แบบของทริป) — ลิงก์ /m/ ภาพ OG และโปรไฟล์
  /// สาธารณะวาดตามนี้ คืนทรงที่เซิร์ฟเวอร์เก็บจริง (ขอบหยักของทริปแม่แบบถูก
  /// เก็บเป็น null) แล้วอัปเดตตู้ที่แคชไว้ให้ทุกหน้าที่โชว์เหรียญนี้เห็นทรงใหม่
  Future<MedalShape?> saveMedalShape(int medalId, MedalShape? shape) async {
    final response = await api.put(
      'me/medals/$medalId',
      body: {'shape': shape?.name},
    );
    final data = Map<String, dynamic>.from(api.data(response) ?? const {});
    final saved = MedalShape.fromName(data['shape']);

    final cached = _medalCabinet;
    if (cached != null) {
      _medalCabinet = MedalCabinet(
        medals: [
          for (final m in cached.medals)
            m.id == medalId ? m.withShape(saved) : m,
        ],
        tripsCount: cached.tripsCount,
      );
      notifyListeners();
    }

    return saved;
  }

  /// เหรียญใบล่าสุดในตู้ที่แคชไว้ — null เมื่อยังไม่เคยโหลดหรือไม่มีใบนี้
  TripMedal? cachedMedal(int medalId) {
    for (final m in _medalCabinet?.medals ?? const <TripMedal>[]) {
      if (m.id == medalId) return m;
    }
    return null;
  }

  /// ใครพิชิตรอบเดียวกับเหรียญ [medalId] ของเรา + ปรบมือให้กัน
  Future<MedalRound> fetchMedalRound(int medalId) async {
    final response = await api.get('me/medals/$medalId/round');
    return MedalRound.fromJson(
      Map<String, dynamic>.from(api.data(response) ?? const {}),
    );
  }

  /// ปรบมือ/เลิกปรบมือ — คืนสถานะที่เซิร์ฟเวอร์ยืนยันแล้ว
  Future<({bool kudoed, int count})> toggleMedalKudos(int medalId) async {
    final response = await api.post('me/medals/$medalId/kudos');
    final data = Map<String, dynamic>.from(api.data(response) ?? const {});

    return (
      kudoed: data['kudoed'] == true,
      count: int.tryParse('${data['kudos_count'] ?? 0}') ?? 0,
    );
  }

  Future<ChallengeBoard> fetchChallenges() async {
    final response = await api.get('me/challenges');
    return ChallengeBoard.fromJson(
      Map<String, dynamic>.from(api.data(response) ?? const {}),
    );
  }

  /// [year] เป็น ค.ศ. — null = ปีปัจจุบัน
  Future<YearReview> fetchYearReview([int? year]) async {
    final response = await api.get(
      'me/year-review',
      query: year == null ? null : {'year': '$year'},
    );
    return YearReview.fromJson(
      Map<String, dynamic>.from(api.data(response) ?? const {}),
    );
  }

  /// ปิดฉากฉลองเหรียญใหม่ — ว่าง = ทุกเหรียญที่ยังไม่เคยเห็น
  Future<void> markMedalsSeen([List<int> ids = const []]) async {
    await api.post(
      'me/medals/seen',
      body: ids.isEmpty ? null : {'ids': ids},
    );

    final cached = _medalCabinet;
    if (cached != null) {
      _medalCabinet = ids.isEmpty
          ? cached.markAllSeen()
          : MedalCabinet(
              medals: [
                for (final m in cached.medals)
                  ids.contains(m.id) ? m.markSeen() : m,
              ],
              tripsCount: cached.tripsCount,
            );
    }
  }

  /// สร้างลิงก์ให้ผู้โดยสารคนหนึ่งกรอกข้อมูลของตัวเอง (ลิงก์เก่าจะใช้ไม่ได้ทันที)
  Future<Map<String, dynamic>> createPassengerInvite(
    String bookingRef,
    int passengerId,
  ) async {
    final response = await api.post(
      'bookings/$bookingRef/passengers/$passengerId/invite',
    );
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  /// สมุดผู้ร่วมเดินทาง — คนที่เก็บไว้กรอกซ้ำ (เรียงคนที่ใช้ล่าสุดขึ้นก่อน).
  Future<List<dynamic>> savedTravellers() async {
    final response = await api.get('saved-travellers');
    return List<dynamic>.from(api.data(response) ?? const []);
  }

  Future<Map<String, dynamic>> saveTraveller(Map<String, dynamic> body) async {
    final response = await api.post('saved-travellers', body: body);
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  Future<void> deleteSavedTraveller(int id) async {
    await api.delete('saved-travellers/$id');
  }

  /// บอกเซิร์ฟเวอร์ว่าเพิ่งเลือกคนนี้ไปใช้ เพื่อจัดลำดับครั้งถัดไป.
  /// ล้มเหลวเงียบ ๆ ได้ — เป็นแค่การจัดลำดับ ไม่ควรขวางการจอง.
  Future<void> markSavedTravellerUsed(int id) async {
    try {
      await api.post('saved-travellers/$id/used');
    } catch (_) {}
  }

  /// เก็บผู้โดยสารจากการจองที่ทำไปแล้วเข้าสมุด.
  Future<Map<String, dynamic>> importTravellersFromBooking(String ref) async {
    final response = await api.post('bookings/$ref/save-travellers');
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  /// แผนที่พิชิต — ทริปที่เดินจบแล้ววางบนแผนที่ + ความลึกรายภาค.
  Future<Map<String, dynamic>> fetchConquestMap() async {
    final response = await api.get('me/passport/map');
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  /// แทร็ก GPS ที่ผู้ใช้บันทึกไว้เองในรอบนี้ (null เมื่อยังไม่เคยบันทึก).
  Future<Map<String, dynamic>?> fetchMyTrack(String bookingRef) async {
    final response = await api.get('bookings/$bookingRef/track');
    final data = api.data(response);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// แทร็กทั้งหมดที่เคยบันทึก (ไม่มีจุดพิกัด — payload เบา ใช้ทำรายการ).
  Future<List<Map<String, dynamic>>> myTracks() async {
    final response = await api.get('me/tracks');
    final data = api.data(response);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// ตั้งค่าโปรไฟล์สาธารณะของตัวเอง `{enabled, handle, bio, url}`.
  Future<Map<String, dynamic>> publicProfileSettings() async {
    final response = await api.get('me/public-profile');
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  Future<Map<String, dynamic>> updatePublicProfile({
    required bool enabled,
    String? bio,
  }) async {
    final response = await api.put(
      'me/public-profile',
      body: {'enabled': enabled, 'bio': bio},
    );
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  /// อัปโหลดแทร็กที่บันทึกไว้ — สถิติคำนวณใหม่ฝั่งเซิร์ฟเวอร์เสมอ.
  Future<Map<String, dynamic>> uploadMyTrack(
    String bookingRef,
    Map<String, dynamic> payload,
  ) async {
    final response = await api.post(
      'bookings/$bookingRef/track',
      body: payload,
    );
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  Future<List<dynamic>> tripReviews(int tripId) async {
    final response = await api.get(
      'reviews',
      query: {'trip_id': tripId, 'per_page': 10},
    );
    return List<dynamic>.from(api.data(response) ?? []);
  }

  /// Fetches one page of a trip's reviews along with whether more pages remain,
  /// so the UI can lazily reveal every review instead of capping at the first
  /// page.
  Future<({List<dynamic> items, bool hasMore})> tripReviewsPage(
    int tripId, {
    int page = 1,
    int perPage = 10,
  }) async {
    final response = await api.get(
      'reviews',
      query: {'trip_id': tripId, 'page': page, 'per_page': perPage},
    );
    final items = List<dynamic>.from(api.data(response) ?? []);
    final meta = api.meta(response);
    final currentPage =
        int.tryParse('${meta?['current_page'] ?? page}') ?? page;
    final lastPage =
        int.tryParse('${meta?['last_page'] ?? currentPage}') ?? currentPage;
    return (items: items, hasMore: currentPage < lastPage);
  }

  /// Fetches one page of every approved review across all trips, optionally
  /// filtered by an exact star [rating]. Backs the "ดูทั้งหมด" all-reviews
  /// screen with infinite scroll and the total count for its header.
  Future<({List<dynamic> items, bool hasMore, int total})> allReviewsPage({
    int page = 1,
    int perPage = 12,
    int? rating,
  }) async {
    final response = await api.get(
      ApiEndpoints.reviews,
      query: {
        'page': page,
        'per_page': perPage,
        'rating': ?rating,
      },
    );
    final items = List<dynamic>.from(api.data(response) ?? []);
    final meta = api.meta(response);
    final currentPage =
        int.tryParse('${meta?['current_page'] ?? page}') ?? page;
    final lastPage =
        int.tryParse('${meta?['last_page'] ?? currentPage}') ?? currentPage;
    final total = int.tryParse('${meta?['total'] ?? items.length}') ?? items.length;
    return (items: items, hasMore: currentPage < lastPage, total: total);
  }

  /// ผังที่นั่งของรอบ — รอบที่วิ่งหลายคันต้องบอกด้วยว่าเป็นผังของคันไหน
  /// (ไม่ส่งไป = คันราคาปกติ ตามที่เซิร์ฟเวอร์เลือกให้)
  Future<Map<String, dynamic>> seats(int scheduleId, {int? vehicleOptionId}) async {
    final query = vehicleOptionId != null
        ? '?vehicle_option_id=$vehicleOptionId'
        : '';
    final response = await api.get('schedules/$scheduleId/seats$query');
    final map = Map<String, dynamic>.from(api.data(response) ?? {});
    // ตรึงเส้นตายของแต่ละล็อกไว้กับนาฬิกาเครื่อง โดยคิดจาก ttl แบบ "เหลืออีกกี่
    // วินาที" ที่เซิร์ฟเวอร์ส่งมา (ไม่ใช่ timestamp สัมบูรณ์) — UI จึงนับถอยหลัง
    // ต่อเองได้ทุกวินาทีโดยไม่ต้องรอ refetch และไม่เพี้ยนตามนาฬิกาที่ไม่ตรงกัน
    // แนวเดียวกับ fetchActiveSeatLocks
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final item in (map['seats'] is List ? map['seats'] as List : const [])) {
      if (item is Map) {
        final ttl = int.tryParse('${item['locked_ttl_seconds'] ?? ''}');
        if (ttl != null && ttl > 0) {
          item['client_deadline_ms'] = nowMs + ttl * 1000;
        }
      }
    }
    return map;
  }

  Future<List<dynamic>> fetchActiveSeatLocks() async {
    final response = await api.get(ApiEndpoints.seatLocksActive);
    final list = List<dynamic>.from(api.data(response) ?? []);
    // Anchor the countdown to a device-local deadline derived from the server's
    // RELATIVE ttl (locked_ttl_seconds), not its absolute timestamp. This keeps
    // the displayed time immune to device/server clock skew (which previously
    // made the app count down faster than the backend lock actually expired).
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final item in list) {
      if (item is Map) {
        final ttl = int.tryParse('${item['locked_ttl_seconds'] ?? ''}');
        if (ttl != null && ttl > 0) {
          item['client_deadline_ms'] = nowMs + ttl * 1000;
        }
      }
    }
    return list;
  }

  Future<void> loadActiveSeatLocks({bool silent = false}) async {
    if (!isLoggedIn || _activeSeatLocksLoading) return;
    _activeSeatLocksLoading = true;
    if (!silent) notifyListeners();

    try {
      activeSeatLocks = await fetchActiveSeatLocks();
    } catch (_) {
      activeSeatLocks = [];
    } finally {
      _activeSeatLocksLoading = false;
      notifyListeners();
    }
  }

  void startActiveSeatLockPolling() {
    _activeSeatLockTimer?.cancel();
    if (!isLoggedIn) return;
    final interval = ApiConfig.hasRealtimeConfig
        ? const Duration(seconds: 30)
        : const Duration(seconds: 5);
    _activeSeatLockTimer = Timer.periodic(
      interval,
      (_) => loadActiveSeatLocks(silent: true),
    );
  }

  void stopActiveSeatLockPolling() {
    _activeSeatLockTimer?.cancel();
    _activeSeatLockTimer = null;
  }

  Future<Map<String, dynamic>> lockSeats(
    int scheduleId,
    List<String> seatIds, {
    int? pickupPointId,
    String? pickupRegion,
    int? vehicleOptionId,
  }) async {
    final response = await api.post(
      'schedules/$scheduleId/seats/lock',
      body: {
        'seat_ids': seatIds,
        'pickup_point_id': ?pickupPointId,
        if (pickupRegion != null && pickupRegion.isNotEmpty)
          'pickup_region': pickupRegion,
        // ที่นั่งผูกกับคัน — A1 ของบัสกับ A1 ของตู้ล็อกกันคนละใบ
        'vehicle_option_id': ?vehicleOptionId,
      },
    );
    final result = Map<String, dynamic>.from(api.data(response) ?? {});
    await loadActiveSeatLocks(silent: true);
    return result;
  }

  Future<void> unlockSeats(
    int scheduleId,
    List<String> seatIds, {
    int? vehicleOptionId,
  }) async {
    await api.delete(
      'schedules/$scheduleId/seats/lock',
      body: {'seat_ids': seatIds, 'vehicle_option_id': ?vehicleOptionId},
    );
    await loadActiveSeatLocks(silent: true);
  }

  Future<void> cancelActiveSeatLock(
    int scheduleId, {
    List<String> seatIds = const [],
    int? vehicleOptionId,
  }) async {
    await api.delete(
      'seat-locks/$scheduleId',
      body: {
        if (seatIds.isNotEmpty) 'seat_ids': seatIds,
        'vehicle_option_id': ?vehicleOptionId,
      },
    );
    await loadActiveSeatLocks(silent: true);
  }

  Future<void> login(String email, String password) async {
    await _auth(
      () => api.post(
        ApiEndpoints.authLogin,
        body: {'email': email, 'password': password},
      ),
    );
    await AnalyticsService.instance.logLogin('password');
  }

  Future<void> register(Map<String, dynamic> payload) async {
    await _auth(() => api.post(ApiEndpoints.authRegister, body: payload));
    await AnalyticsService.instance.logSignUp('password');
  }

  Future<void> loginWithApple({
    required String identityToken,
    String? givenName,
    String? familyName,
  }) async {
    await _auth(
      () => api.post(
        ApiEndpoints.authAppleNative,
        body: {
          'identity_token': identityToken,
          'given_name': ?givenName,
          'family_name': ?familyName,
        },
      ),
    );
    await AnalyticsService.instance.logLogin('apple');
  }

  Future<void> completeSocialLogin({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      api.token = token;
      this.user = user;
      await SecureStorage.instance.writeToken(token);
      await loadAccountData();
      await loadActiveSeatLocks();
      startActiveSeatLockPolling();
      await PushNotificationService.instance.syncToken(api);
      await _bindUserChannel();
      await AnalyticsService.instance.setUser(
        id: this.user?['id']?.toString(),
        email: this.user?['email']?.toString(),
      );
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _auth(Future<dynamic> Function() request) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final response = await request();
      final data = Map<String, dynamic>.from(api.data(response) as Map);
      api.token = data['token']?.toString();
      user = Map<String, dynamic>.from(data['user'] as Map);
      if (api.token != null && api.token!.isNotEmpty) {
        await SecureStorage.instance.writeToken(api.token!);
      }
      await loadAccountData();
      await loadActiveSeatLocks();
      startActiveSeatLockPolling();
      await PushNotificationService.instance.syncToken(api);
      await _bindUserChannel();
      await AnalyticsService.instance.setUser(
        id: user?['id']?.toString(),
        email: user?['email']?.toString(),
      );
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// ขอลิงก์ตั้งรหัสผ่านใหม่ทางอีเมล
  ///
  /// ไม่ผ่าน [_auth]/busy เพราะไม่ได้ทำให้ล็อกอิน และไม่ควรทำให้ทั้งแอปขึ้น
  /// สถานะกำลังโหลด — หน้าจอที่เรียกจัดการ loading ของตัวเอง คืนข้อความจาก
  /// เซิร์ฟเวอร์ตรง ๆ เพราะฝั่งนั้นตั้งใจตอบข้อความเดียวกันทั้งกรณีมีและไม่มี
  /// บัญชี (กันการไล่เดาว่าอีเมลไหนเป็นลูกค้า)
  Future<String> requestPasswordReset(String email) async {
    final response = await api.post(
      ApiEndpoints.authForgotPassword,
      body: {'email': email},
    );
    return _messageOf(
      response,
      fallback: 'ถ้าอีเมลนี้มีบัญชีอยู่ เราได้ส่งลิงก์ตั้งรหัสผ่านใหม่ไปให้แล้วครับ',
    );
  }

  /// ตั้งรหัสผ่านใหม่ด้วยโทเคนจากลิงก์ในอีเมล
  ///
  /// เซิร์ฟเวอร์ล้าง token ทั้งหมดของบัญชีนี้ทิ้ง — รวมถึงตัวที่เครื่องนี้ถืออยู่
  /// ถ้ากำลังล็อกอินค้างไว้ จึงต้องพากลับไปหน้าเข้าสู่ระบบเอง ไม่ปล่อยให้ใช้
  /// token ที่ตายแล้วต่อจนไปเจอ 401 กลางทาง
  Future<String> resetPassword({
    required String token,
    required String email,
    required String password,
  }) async {
    final response = await api.post(
      ApiEndpoints.authResetPassword,
      body: {
        'token': token,
        'email': email,
        'password': password,
        'password_confirmation': password,
      },
    );
    if (isLoggedIn) await logout();
    return _messageOf(
      response,
      fallback: 'ตั้งรหัสผ่านใหม่เรียบร้อยแล้วครับ เข้าสู่ระบบด้วยรหัสผ่านใหม่ได้เลย',
    );
  }

  /// ส่งลิงก์ยืนยันอีเมลอีกครั้ง แล้วดึงสถานะบัญชีใหม่ (เผื่อผู้ใช้กดยืนยัน
  /// ไปแล้วจากอีกอุปกรณ์ — จะได้ปิดแถบเตือนทันทีแทนที่จะส่งเมลซ้ำเปล่า ๆ)
  Future<String> resendEmailVerification() async {
    final response = await api.post(ApiEndpoints.authResendVerification);
    try {
      await refreshMe();
    } catch (_) {
      // สถานะบัญชีดึงไม่ได้ไม่ใช่เหตุให้บอกว่าส่งเมลไม่สำเร็จ
    }
    return _messageOf(
      response,
      fallback: 'ส่งลิงก์ยืนยันไปที่อีเมลของคุณแล้วครับ',
    );
  }

  bool get isEmailVerified => user?['email_verified'] == true;

  /// บัญชีที่ตั้งรหัสผ่านเองเท่านั้นที่ต้องยืนยันอีเมล — บัญชี social ที่ระบบ
  /// สร้างอีเมลหลอกให้ (`@social.local`) ส่งเมลไปก็ไม่มีใครได้รับ
  bool get needsEmailVerification {
    if (!isLoggedIn || isEmailVerified) return false;
    final email = user?['email']?.toString().toLowerCase() ?? '';
    if (email.isEmpty || email.endsWith('@social.local')) return false;
    return true;
  }

  String _messageOf(dynamic response, {required String fallback}) {
    if (response is Map) {
      final message = response['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return fallback;
  }

  Future<void> refreshMe() async {
    final response = await api.get(ApiEndpoints.authMe);
    user = Map<String, dynamic>.from(api.data(response) as Map);
    notifyListeners();
  }

  Future<void> updateProfile(
    Map<String, dynamic> payload, {
    String? avatarImagePath,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final response = avatarImagePath == null
          ? await api.post(ApiEndpoints.authProfile, body: payload)
          : await api.postMultipart(
              'auth/profile',
              fields: payload,
              files: {'avatar': avatarImagePath},
            );
      user = Map<String, dynamic>.from(api.data(response) as Map);
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      // เก็บการ์ดวันเดินทางออกจากหน้าจอล็อกก่อน — มันผูกกับบัญชีที่กำลังจะออก
      await TripActivityService.instance.stop();
      // ลบหมุดของบัญชีนี้ออกจากรอบก่อน โทเคนยังใช้ได้อยู่ตรงนี้ ถ้าปล่อยไว้ให้
      // _clearLocalSession จัดการ จะเหลือแค่การหยุดส่งฝั่งเครื่อง ส่วนหมุดบน
      // เซิร์ฟเวอร์จะค้างให้เพื่อนเห็นจนกว่าจะหมดอายุ
      await TripLocationSharing.instance.stop();
      await PushNotificationService.instance.unregisterToken();
      if (isLoggedIn) await api.post(ApiEndpoints.authLogout);
    } catch (_) {
      // Keep local logout responsive even if token is already expired.
    }
    await _clearLocalSession();
  }

  /// Deletes the signed-in account on the server. [password] is required for
  /// password-based accounts and omitted for social-only accounts. Throws if
  /// the server rejects the request (e.g. wrong password), leaving the local
  /// session intact. The local session is cleared separately via
  /// [finalizeAccountDeletion] so the UI can show a success confirmation that
  /// stays visible until the user dismisses it — clearing here would flip the
  /// screen to the login view before the confirmation can be seen.
  Future<void> deleteAccount({String? password}) async {
    _deletingAccount = true;
    try {
      await api.delete(
        ApiEndpoints.authAccount,
        body: password == null ? null : {'password': password},
      );
    } catch (e) {
      // Deletion failed (e.g. wrong password) — restore normal 401 handling.
      _deletingAccount = false;
      rethrow;
    }
    // Account + its tokens are gone server-side. Halt background work that would
    // otherwise fire an authenticated request and 401, without clearing the
    // session yet so the success confirmation can stay on screen.
    stopActiveSeatLockPolling();
    await _unbindUserChannel();
  }

  /// Clears the local session after the user acknowledges a successful account
  /// deletion. No network calls are made here — the server-side token and push
  /// tokens were already removed by the deletion (cascade) — so the dead-token
  /// 401 path that used to tear down the navigation stack never runs.
  Future<void> finalizeAccountDeletion() async {
    await _clearLocalSession();
    _deletingAccount = false;
  }

  Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await SecureStorage.instance.deleteToken();
    api.token = null;
    user = null;
    _medalCabinet = null;
    _medalCabinetAt = null;
    await OfflineCache.instance.clearAccount();
    // แคชถูกล้างไปแล้ว แต่ตัวนับของคิว SOS อยู่ในหน่วยความจำ ถ้าไม่รีเซ็ต แถบ
    // "ยังส่งไม่สำเร็จ" ของบัญชีก่อนหน้าจะค้างให้คนที่ล็อกอินคนถัดไปเห็น
    await SosOutbox.instance.clear();
    await CheckInOutbox.instance.clear();
    // GPS ที่วิ่งอยู่เบื้องหลังต้องดับไปพร้อมบัญชี ไม่งั้นเครื่องจะกินแบตบันทึก
    // เส้นทางของคนที่ออกจากระบบไปแล้วต่อไปเรื่อย ๆ — ไม่ยิง API ตรงนี้เพราะการ
    // ลบบัญชีก็ผ่านทางนี้ ซึ่งโทเคนตายไปแล้ว (logout() ลบหมุดบนเซิร์ฟเวอร์ไป
    // ก่อนหน้านี้แล้ว) ใช้ pause ไม่ใช่ discard: เส้นทางที่บันทึกไว้ยังไม่ถูกทิ้ง
    await TripLocationSharing.instance.abandonLocally();
    // ตำแหน่งรถที่สตาฟกำลังแชร์ก็ต้องดับไปพร้อมบัญชี ไม่งั้นเครื่องจะส่งพิกัด
    // ของรอบที่เจ้าตัวออกจากระบบไปแล้วต่อจนแบตหมด
    await VehicleLocationSharing.instance.abandonLocally();
    await TrekRecorderService.instance.pause();
    // ทริปของบัญชีที่ออกไปต้องไม่ค้างอยู่บนหน้าโฮมให้คนถัดไปที่หยิบเครื่องขึ้นมา
    // เห็น — วางไว้ที่นี่ ไม่ใช่ใน logout() เพราะการลบบัญชีก็ผ่านทางนี้เหมือนกัน
    await HomeWidgetService.instance.clear();
    // Drafts hold ID numbers and health notes belonging to this account.
    await BookingDraftStore.clearAll();
    await _unbindUserChannel();
    await AnalyticsService.instance.setUser(id: null);
    stopActiveSeatLockPolling();
    bookings = [];
    _resetBookingHistory();
    notifications = [];
    activeSeatLocks = [];
    claimableBookingCount = 0;
    loyalty = null;
    myReviews = [];
    rewards = [];
    coupons = [];
    _syncAppIconBadge();
    notifyListeners();
  }

  @override
  void dispose() {
    stopActiveSeatLockPolling();
    _deepLinkSub?.cancel();
    super.dispose();
  }

  Future<void> loadAccountData() async {
    if (!isLoggedIn) return;

    Future<dynamic> safe(Future<dynamic> f) => f.catchError((_) => null);

    final hasStaff = canUseStaffCheckIn;
    // การจองเป็นข้อมูลหลักของหน้านี้ ถ้าดึงไม่สำเร็จต้องบอกผู้ใช้ให้ลองใหม่
    // (เดิม exception หลุดออกไปก่อนตั้ง accountLoaded = ค้าง skeleton ถาวร)
    Object? bookingsError;
    Future<dynamic> bookingsCall(Map<String, dynamic> query) =>
        api.get(ApiEndpoints.bookings, query: query).catchError((Object e) {
          bookingsError ??= e;
          return null;
        });
    final results = await Future.wait([
      bookingsCall({'scope': 'current'}),
      bookingsCall({
        'scope': 'history',
        'per_page': bookingHistoryPageSize,
        'page': 1,
      }),
      safe(api.get(ApiEndpoints.notifications, query: {'per_page': 20})),
      safe(api.get(ApiEndpoints.loyaltyAccount)),
      safe(api.get(ApiEndpoints.loyaltyRewards)),
      safe(api.get(ApiEndpoints.loyaltyCoupons)),
      safe(api.get(ApiEndpoints.reviewsMy)),
      safe(api.get(ApiEndpoints.chatMyConversations)),
      safe(api.get(ApiEndpoints.supportUnreadCount)),
      if (hasStaff) safe(api.get(ApiEndpoints.staffSchedulesMy)),
    ]);

    if (bookingsError != null) {
      // เก็บของเดิม (หรือแคช) ไว้ให้ผู้ใช้ยังเห็นได้ ไม่ล้างทิ้งเพราะเน็ตสะดุด
      accountError = bookingsError is ApiException
          ? (bookingsError as ApiException).message
          : 'โหลดการจองไม่สำเร็จ กรุณาลองใหม่';
    } else {
      accountError = null;
      _applyBookingsFirstPage(
        current: List<dynamic>.from(api.data(results[0]) ?? []),
        history: List<dynamic>.from(api.data(results[1]) ?? []),
        historyMeta: api.meta(results[1]),
      );
    }
    if (results[2] != null) {
      notifications = List<dynamic>.from(api.data(results[2]) ?? []);
    }
    if (results[3] != null) {
      loyalty = Map<String, dynamic>.from(api.data(results[3]) ?? {});
    }
    if (results[4] != null) {
      rewards = List<dynamic>.from(api.data(results[4]) ?? []);
    }
    if (results[5] != null) {
      coupons = List<dynamic>.from(api.data(results[5]) ?? []);
    }
    if (results[6] != null) {
      myReviews = List<dynamic>.from(api.data(results[6]) ?? []);
    }
    if (results[7] != null) {
      chatConversations = List<dynamic>.from(api.data(results[7]) ?? []);
      chatUnreadTotal = chatConversations.fold<int>(0, (sum, c) {
        final n = int.tryParse('${(c as Map?)?['unread_count']}') ?? 0;
        return sum + n;
      });
    }
    if (results[8] != null) {
      final supportData = api.data(results[8]) as Map?;
      supportUnread = int.tryParse('${supportData?['count']}') ?? 0;
    }
    if (hasStaff && results.length > 9 && results[9] != null) {
      final staffData = api.data(results[9]) as Map?;
      staffSchedules = List<dynamic>.from(staffData?['schedules'] ?? []);
      staffSummary = Map<String, dynamic>.from(staffData?['summary'] ?? {});
    }

    final cache = OfflineCache.instance;
    if (user != null) cache.writeAccount('user', user);
    _writeBookingsCache();
    cache.writeAccount('notifications', notifications);
    cache.writeAccount('loyalty', loyalty);
    cache.writeAccount('rewards', rewards);
    cache.writeAccount('coupons', coupons);
    cache.writeAccount('myReviews', myReviews);
    _syncAppIconBadge();
    accountLoaded = true;
    notifyListeners();

    // ใบจองที่ทีมงานเปิดให้ก่อนลูกค้าจะมีบัญชี ไม่ได้อยู่ในรายการข้างบน เพราะมัน
    // ยังผูกกับบัญชีเงาอยู่ — ถามแยกเพื่อเอามาชวนให้กดผูกเข้าบัญชี
    unawaited(loadClaimableBookings());

    // เตรียมชุดข้อมูลวันเดินทางไว้ใช้ตอนไม่มีสัญญาณ — ทำเงียบ ๆ ต่อท้ายและไม่
    // ให้เกี่ยวกับผลของ loadAccountData เพราะผู้ใช้ไม่ได้สั่งและไม่ได้รออยู่
    unawaited(
      TripDayPack.prefetch(this).catchError((Object e) {
        debugPrint('TripDayPack prefetch failed: $e');
      }),
    );

    // และชุดของสตาฟ — รายชื่อผู้โดยสารของรอบที่รับผิดชอบพรุ่งนี้ ต้องอยู่ใน
    // เครื่องตั้งแต่ตอนที่ยังมีสัญญาณ ไม่ใช่ตอนยืนอยู่ที่จุดรับแล้วค่อยโหลด
    if (hasStaff) {
      unawaited(
        StaffTripPack.prefetch(this).catchError((Object e) {
          debugPrint('StaffTripPack prefetch failed: $e');
        }),
      );
      // ถึงวันเดินทางแล้วให้มือถือของสตาฟเป็น GPS ของรถเอง ลูกค้าจะได้เห็นรถ
      // โดยไม่มีใครต้องกดอะไรเพิ่มหน้างาน
      unawaited(
        syncVehicleSharing().catchError((Object e) {
          debugPrint('syncVehicleSharing failed: $e');
        }),
      );
    }

    // การ์ด "วันเดินทาง" บนหน้าจอล็อก — เปิดให้เองตั้งแต่วันก่อนเดินทาง ผู้ใช้ไม่
    // ต้องรู้ว่ามีปุ่มให้กด เพราะจังหวะที่เขาต้องการมันคือจังหวะที่เขาไม่ได้เปิดแอป
    unawaited(
      TripActivityService.instance.syncFromBookings(bookings).catchError((
        Object e,
      ) {
        debugPrint('TripActivity sync failed: $e');
      }),
    );

    // วิดเจ็ตหน้าโฮม — เพิ่งได้รายการจองชุดใหม่มา ถ้ามีอะไรเปลี่ยนก็เปลี่ยนตอนนี้
    unawaited(HomeWidgetService.instance.refresh(force: true));
  }

  Future<void> loadStaffSchedules() async {
    if (!isLoggedIn || !canUseStaffCheckIn) return;
    final response = await api.get(ApiEndpoints.staffSchedulesMy);
    final data = api.data(response) as Map?;
    staffSchedules = List<dynamic>.from(data?['schedules'] ?? []);
    staffSummary = Map<String, dynamic>.from(data?['summary'] ?? {});
    notifyListeners();
  }

  Future<Map<String, dynamic>> booking(String ref) async {
    final response = await api.get('bookings/$ref');
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Customer activity photos for a booking — taken by staff during the trip,
  /// served from Cloudflare R2. Returns a list of `{id, url, sort_order, ...}`.
  Future<List<Map<String, dynamic>>> bookingPhotos(String ref) async {
    final response = await api.get('bookings/$ref/photos');
    final data = api.data(response);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  // ── สถานที่ (ปลายทาง) ────────────────────────────────────────────────────

  /// รายการสถานที่ + ตัวเลือกฟิลเตอร์ที่ backend รองรับ
  ///
  /// แคชผลของ "ทั้งหมด" (ไม่มีฟิลเตอร์) ไว้ในชั้น public เพราะเป็นเนื้อหาที่ไม่
  /// ผูกกับบัญชี และเป็นชุดที่หน้าจอเปิดขึ้นมาเห็นก่อนเสมอ
  Future<Map<String, dynamic>> places({int? month, String? region}) async {
    final response = await api.get(
      'places',
      query: {'month': ?month?.toString(), 'region': ?region},
    );
    final data = Map<String, dynamic>.from(api.data(response) ?? {});

    if (month == null && (region == null || region.isEmpty)) {
      OfflineCache.instance.writePublic('places', data);
    }

    return data;
  }

  Map<String, dynamic>? get cachedPlaces {
    final cached = OfflineCache.instance.readPublic<Map>('places');
    return cached == null ? null : Map<String, dynamic>.from(cached);
  }

  Future<Map<String, dynamic>> place(String slug) async {
    final response = await api.get('places/$slug');
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  /// ทริปที่มีพิกัด สำหรับหมุดบนแผนที่ — backend แคชไว้ 10 นาทีอยู่แล้ว
  /// ที่นี่แคชอีกชั้นในเครื่องเพื่อให้เปิดแผนที่ซ้ำแล้วหมุดขึ้นทันที
  Future<List<Map<String, dynamic>>> tripsOnMap() async {
    final response = await api.get('trips/map');
    final data = api.data(response);
    final trips = (data is List ? data : const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((trip) => trip['latitude'] != null && trip['longitude'] != null)
        .toList();

    OfflineCache.instance.writePublic('trips_map', trips);

    return trips;
  }

  List<Map<String, dynamic>> get cachedTripsOnMap {
    final cached = OfflineCache.instance.readPublic<List>('trips_map');
    if (cached == null) return const [];
    return cached
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// รูปจากรีวิวของลูกค้าทุกทริป — กำแพงรูป "คนที่ไปมาแล้วเจออะไร"
  ///
  /// [month] คือเดือนที่ "ไปจริง" (วันออกเดินทางของรอบ) ไม่ใช่เดือนที่เขียนรีวิว
  /// คืน `{photos: [...], has_more: bool, total: int}` ตามที่ backend ส่งมา
  Future<Map<String, dynamic>> communityPhotos({int? month, int page = 1}) async {
    final response = await api.get(
      'reviews/photos',
      query: {'month': ?month?.toString(), 'page': page, 'per_page': 30},
    );
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  /// ใบเสร็จของการจอง — เอกสารจริงอยู่บนเว็บ (หน้าตรวจสอบ + PDF) ที่นี่ได้มา
  /// แค่รายการกับลิงก์ ยังไม่มีใบเสร็จก็คืนลิสต์ว่าง (ออกตอนยืนยันการชำระ)
  Future<List<Map<String, dynamic>>> bookingReceipts(String ref) async {
    final response = await api.get('bookings/$ref/receipts');
    final data = api.data(response);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// ผู้ช่วยส่วนตัว — ถามเป็นภาษาคนเรื่องการจองของตัวเอง ("รถออกกี่โมง",
  /// "ยอดคงเหลือเท่าไหร่") คำตอบอ้างอิงข้อมูลการจองจริงฝั่งเซิร์ฟเวอร์
  ///
  /// คืน `{reply, actions}` โดย actions = ปุ่มลัดที่ผู้ช่วยเสนอ ชนิดของปุ่มถูก
  /// จำกัดไว้ฝั่ง backend แล้ว แอปจึงแมปเป็นหน้าจอได้โดยไม่ต้องเดาจากข้อความ
  Future<Map<String, dynamic>> askAssistant(
    String message, {
    List<Map<String, String>> history = const [],
  }) async {
    final response = await api.post(
      'me/assistant',
      body: {'message': message, if (history.isNotEmpty) 'history': history},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// คำถามตัวอย่างของผู้ช่วย — เปลี่ยนตามว่ามีทริปที่กำลังจะถึงหรือไม่
  Future<List<String>> assistantSuggestions() async {
    final response = await api.get('me/assistant/suggestions');
    final data = api.data(response);
    final list = data is Map ? data['suggestions'] : null;
    if (list is List) {
      return list.map((e) => e.toString()).toList();
    }
    return const [];
  }

  /// Trip Recap — สถิติสรุปทริปแบบ story หลังจบทริป (สายเดินป่า Wrapped รายทริป).
  Future<Map<String, dynamic>> bookingRecap(String ref) async {
    final response = await api.get('bookings/$ref/recap');
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ดูรายละเอียดของขวัญจากโค้ด ก่อนกดรับ (ไม่เปิดเผยราคาให้ผู้รับ)
  Future<Map<String, dynamic>> giftPreview(String code) async {
    final response = await api.get('gifts/${code.trim().toUpperCase()}');
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// กดรับของขวัญ — การจองย้ายมาเป็นของผู้รับ แล้วรีเฟรชรายการจอง
  Future<Map<String, dynamic>> claimGift(String code) async {
    final response = await api.post(
      'gifts/${code.trim().toUpperCase()}/claim',
    );
    final booking = Map<String, dynamic>.from(api.data(response) as Map);
    await loadAccountData();
    return booking;
  }

  /// ของขวัญที่ฉันเป็นผู้ให้ — โค้ด/สถานะการรับของแต่ละชิ้น
  Future<List<Map<String, dynamic>>> sentGifts() async {
    final response = await api.get('gifts/sent');
    final data = api.data(response);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  // ── เหมาทริป / จัดทริปส่วนตัว ──────────────────────────────────────

  Future<List<Map<String, dynamic>>> charterRequests() async {
    final response = await api.get(ApiEndpoints.charterRequests);
    final data = api.data(response);
    return data is List
        ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];
  }

  Future<Map<String, dynamic>> charterRequest(int id) async {
    final response = await api.get(ApiEndpoints.charterRequest(id));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ส่งคำขอ — คืน `(request, message)` ข้อความจากหลังบ้านบอกขั้นตอนถัดไป
  Future<({Map<String, dynamic> request, String message})> createCharterRequest(
    Map<String, dynamic> payload,
  ) async {
    final response = await api.post(ApiEndpoints.charterRequests, body: payload);
    return (
      request: Map<String, dynamic>.from(api.data(response) as Map),
      message: response is Map ? '${response['message'] ?? ''}' : '',
    );
  }

  Future<Map<String, dynamic>> respondCharterRequest(
    int id,
    String action, {
    String? reason,
  }) async {
    final response = await api.post(
      ApiEndpoints.charterRequestAction(id, action),
      body: {if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim()},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  // ── บัตรของขวัญแบบระบุยอดเงิน ────────────────────────────────────

  /// `{wallet: [...], purchased: [...], config: {min_amount, max_amount, presets, designs}}`
  Future<Map<String, dynamic>> giftVouchers() async {
    final response = await api.get(ApiEndpoints.giftVouchers);
    final data = api.data(response);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> giftVoucher(int id) async {
    final response = await api.get(ApiEndpoints.giftVoucher(id));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// สร้างบัตรที่รอจ่าย — คืน `{voucher, payment}` (payment = QR และบัญชีโอน)
  Future<Map<String, dynamic>> createGiftVoucher({
    required int amount,
    required bool forSelf,
    String? recipientName,
    String? fromName,
    String? message,
    String? design,
  }) async {
    final response = await api.post(
      ApiEndpoints.giftVouchers,
      body: {
        'amount': amount,
        'for_self': forSelf,
        if (!forSelf && (recipientName ?? '').trim().isNotEmpty)
          'recipient_name': recipientName!.trim(),
        if ((fromName ?? '').trim().isNotEmpty) 'from_name': fromName!.trim(),
        if ((message ?? '').trim().isNotEmpty) 'message': message!.trim(),
        'design': ?design,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> giftVoucherPayment(int id) async {
    final response = await api.get(ApiEndpoints.giftVoucherPayment(id));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ส่งสลิป — คืน `{voucher, message}` บัตรเปิดใช้ทันทีถ้าระบบอ่านสลิปผ่าน
  /// ไม่งั้นสถานะเป็น under_review รอทีมงาน
  Future<({Map<String, dynamic> voucher, String message})> submitGiftVoucherSlip(
    int id,
    String slipPath,
  ) async {
    final response = await api.postMultipart(
      ApiEndpoints.giftVoucherSlip(id),
      fields: const {},
      files: {'slip_image': slipPath},
    );
    final message = response is Map ? '${response['message'] ?? ''}' : '';
    return (
      voucher: Map<String, dynamic>.from(api.data(response) as Map),
      message: message,
    );
  }

  Future<void> cancelGiftVoucher(int id) async {
    await api.delete(ApiEndpoints.giftVoucher(id));
  }

  /// ดูบัตรจากรหัส (ก่อนเพิ่มเข้าบัญชีหรือก่อนใช้ตอนจอง)
  Future<Map<String, dynamic>> lookupGiftVoucher(String code) async {
    final response = await api.post(
      ApiEndpoints.giftVoucherLookup,
      body: {'code': code.trim()},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> claimGiftVoucher(String code) async {
    final response = await api.post(
      ApiEndpoints.giftVoucherClaim,
      body: {'code': code.trim()},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Triggers an SOS, retrying on network/server failures with backoff.
  ///
  /// SOS must reach the server even on a weak (3G) connection, so each attempt
  /// is bounded by a timeout and transient failures are retried. The backend
  /// de-duplicates repeated triggers, so a retry never creates a second alert.
  Future<SosAlert> triggerSos({
    required int scheduleId,
    double? latitude,
    double? longitude,
    String? message,
    String? photoPath,
    DateTime? occurredAt,
    String? clientToken,
    bool retry = true,
  }) async {
    final body = {
      'schedule_id': scheduleId,
      'latitude': ?latitude,
      'longitude': ?longitude,
      if (message != null && message.isNotEmpty) 'message': message,
      // เวลาที่กดจริงกับกุญแจกันซ้ำ — ทำให้เคสที่ค้างอยู่ในเครื่องแล้วส่งตามมา
      // ทีหลังยังบันทึกเวลาที่ถูกต้อง และส่งซ้ำกี่รอบก็ยังเป็นเคสเดียว
      if (occurredAt != null)
        'occurred_at': occurredAt.toUtc().toIso8601String(),
      if (clientToken != null && clientToken.isNotEmpty)
        'client_token': clientToken,
    };

    // A photo can take longer to upload on a weak connection, so give multipart
    // attempts more headroom than a plain JSON trigger.
    final hasPhoto = photoPath != null && photoPath.isNotEmpty;
    final attemptTimeout = hasPhoto
        ? const Duration(seconds: 30)
        : const Duration(seconds: 15);
    // คิวออฟไลน์ ([SosOutbox]) มีจังหวะลองใหม่ของตัวเอง จึงยิงครั้งเดียวต่อรอบ
    // ไม่ให้รายการแรกนั่งลองซ้ำ 14 วินาทีจนรายการถัดไปไม่ได้คิว
    final backoff = retry
        ? const [
            Duration(seconds: 2),
            Duration(seconds: 4),
            Duration(seconds: 8),
          ]
        : const <Duration>[];

    Object lastError = const ApiException('ส่งสัญญาณ SOS ไม่สำเร็จ');

    for (var attempt = 0; attempt <= backoff.length; attempt++) {
      try {
        final response = hasPhoto
            ? await api
                  .postMultipart(
                    'sos',
                    fields: body,
                    files: {'photo': photoPath},
                  )
                  .timeout(attemptTimeout)
            : await api.post('sos', body: body).timeout(attemptTimeout);
        return SosAlert.fromJson(
          Map<String, dynamic>.from(api.data(response) as Map),
        );
      } on ApiException catch (e) {
        // Client errors (validation, auth, trip-window) won't be fixed by a
        // retry — surface them immediately.
        final status = e.statusCode;
        if (status != null && status >= 400 && status < 500) rethrow;
        lastError = e;
      } catch (e) {
        // Timeouts and connectivity errors — worth retrying.
        lastError = e;
      }

      if (attempt < backoff.length) {
        await Future.delayed(backoff[attempt]);
      }
    }

    throw lastError;
  }

  Future<List<SosAlert>> activeSosAlerts() async {
    final response = await api.get('sos/active');
    final list = api.data(response);
    if (list is! List) return const [];
    return list
        .map((e) => SosAlert.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Alerts already surfaced this session, so returning to the app repeatedly
  /// doesn't reopen the same emergency screen after the user dismissed it.
  final Set<int> _seenSosIds = {};

  /// Pulls any SOS still open in the user's trips and surfaces the newest one.
  ///
  /// Push and the websocket both only reach a phone that is on and connected —
  /// the phone in a pack with no signal, or one that was flat, learns about the
  /// emergency only when it comes back. That's exactly when the group needs it
  /// to know, so re-check on resume rather than trusting delivery.
  Future<void> recoverMissedSosAlerts() async {
    if (!isLoggedIn) return;

    try {
      final alerts = await activeSosAlerts();
      final incoming = alerts
          .where((a) => !a.isMine && a.isActive && !_seenSosIds.contains(a.id))
          .toList();

      if (incoming.isEmpty) return;

      final latest = incoming.first;
      _seenSosIds.add(latest.id);
      NotificationNavigator.openSosAlert(latest);
    } catch (_) {
      // Offline or the endpoint is unreachable — nothing to recover right now.
    }
  }

  Future<void> resolveSos(int id) async {
    await api.post('sos/$id/resolve');
  }

  static String _sosContactsKey(int scheduleId) => 'sos_contacts.$scheduleId';

  /// เบอร์สำรองของรอบนี้ — สตาฟ คนขับ ศูนย์ช่วยเหลือ และเบอร์ฉุกเฉินราชการ
  ///
  /// อ่านจากแคชก่อนเสมอเมื่อดึงใหม่ไม่ได้ เพราะหน้าจอที่ใช้ข้อมูลชุดนี้คือหน้าจอ
  /// ที่เปิดตอนไม่มีสัญญาณ — ถ้ามันต้องมีเน็ตถึงจะทำงาน ก็ไม่ต่างจากปุ่ม SOS
  /// ที่เพิ่งส่งไม่ผ่านไปเมื่อครู่
  Future<({List<Map<String, dynamic>> contacts, Map<String, String> emergency})>
  sosContacts(int scheduleId) async {
    final key = _sosContactsKey(scheduleId);

    try {
      final response = await api.get('schedules/$scheduleId/emergency-contacts');
      final data = api.data(response);
      if (data is Map) {
        final payload = Map<String, dynamic>.from(data);
        OfflineCache.instance.writeAccount(key, payload);
        return _parseSosContacts(payload);
      }
    } catch (_) {
      // ไม่มีสัญญาณ — ตกไปใช้ของที่เก็บไว้ ซึ่งเป็นเหตุผลที่ดึงล่วงหน้าตั้งแต่แรก
    }

    final cached = OfflineCache.instance.readAccount<Map>(key);
    if (cached == null) return (contacts: <Map<String, dynamic>>[], emergency: <String, String>{});
    return _parseSosContacts(Map<String, dynamic>.from(cached));
  }

  ({List<Map<String, dynamic>> contacts, Map<String, String> emergency})
  _parseSosContacts(Map<String, dynamic> payload) {
    final contacts = (payload['contacts'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => '${e['phone'] ?? ''}'.trim().isNotEmpty)
        .toList();

    final emergency = <String, String>{};
    final raw = payload['emergency_numbers'];
    if (raw is Map) {
      raw.forEach((key, value) => emergency['$key'] = '$value');
    }

    return (contacts: contacts, emergency: emergency);
  }

  /// Looks up a booking for staff check-in. Returns the booking plus `meta`,
  /// which carries the pickup-point summary (how many travellers this stop
  /// receives in total and how many are already checked in).
  Future<({Map<String, dynamic> booking, Map<String, dynamic> meta})>
  lookupStaffCheckIn(String qrCode) async {
    final response = await api.post(
      'staff/check-in/lookup',
      body: {'qr_code': qrCode},
    );
    final envelope = Map<String, dynamic>.from(response as Map);
    return (
      booking: Map<String, dynamic>.from(envelope['data'] as Map),
      meta: envelope['meta'] is Map
          ? Map<String, dynamic>.from(envelope['meta'] as Map)
          : <String, dynamic>{},
    );
  }

  /// Confirms a staff QR check-in. Returns `{ booking, meta, message }` — the
  /// message reflects server-side side effects (e.g. auto-notifying the next
  /// pickup point once everyone at this point has checked in); `meta` carries
  /// the refreshed pickup-point summary.
  Future<
    ({Map<String, dynamic> booking, Map<String, dynamic> meta, String message})
  >
  confirmStaffCheckIn(
    String qrCode, {
    int? scheduleId,
    DateTime? checkedInAt,
  }) async {
    final response = await api.post(
      'staff/check-in/confirm',
      // ส่ง schedule_id เมื่อรู้รอบแน่ชัด (เช่น กดเช็คอินจากรายชื่อ) เพื่อกัน
      // การเช็คอินข้ามรอบจากรหัสที่พิมพ์ผิด
      //
      // checked_in_at ติดไปเฉพาะรายการที่ออกจาก [CheckInOutbox] — มันบอก
      // เซิร์ฟเวอร์ทั้งว่า "คนขึ้นรถตอนกี่โมงจริง ๆ" และว่านี่คือการส่งซ้ำของคิว
      // (ใบที่เช็คอินไปแล้วจะตอบ 200 แทน 422 ให้คิวปล่อยทิ้งได้)
      body: {
        'qr_code': qrCode,
        'schedule_id': ?scheduleId,
        'checked_in_at': ?checkedInAt?.toUtc().toIso8601String(),
      },
    );
    final envelope = Map<String, dynamic>.from(response as Map);
    return (
      booking: Map<String, dynamic>.from(envelope['data'] as Map),
      meta: envelope['meta'] is Map
          ? Map<String, dynamic>.from(envelope['meta'] as Map)
          : <String, dynamic>{},
      message: envelope['message']?.toString() ?? 'เช็คอินสำเร็จแล้ว',
    );
  }

  static String _staffManifestKey(int scheduleId) => 'staff_manifest.$scheduleId';

  /// Full passenger manifest for a schedule the staff is assigned to —
  /// contact name, callable phone, pickup point/map/notes per booking.
  /// Backed by the driver manifest endpoint, which grants staff access.
  ///
  /// เก็บสำเนาไว้ทุกครั้งที่ดึงสำเร็จ แล้วตกไปใช้สำเนานั้นเมื่อดึงใหม่ไม่ได้
  ///
  /// เหตุผลเดียวกับ [sosContacts] แต่หนักกว่า: สิ่งที่อยู่ในรายชื่อนี้คือเบอร์โทร
  /// ผู้ติดต่อฉุกเฉิน ข้อมูลแพ้อาหาร และโรคประจำตัวของคนที่กำลังอยู่บนดอยกับเรา
  /// หน้าจอที่ต้องมีสัญญาณถึงจะเปิดได้ คือหน้าจอที่ใช้ไม่ได้ในนาทีที่ต้องใช้
  ///
  /// [fromCache] บอกหน้าจอว่ากำลังอ่านของเก่าอยู่ เพื่อให้มันพูดตรง ๆ ได้ว่า
  /// ข้อมูลนี้บันทึกไว้เมื่อไหร่ แทนที่จะแสดงเป็นความจริง ณ ตอนนี้
  Future<({Map<String, dynamic> data, bool fromCache, DateTime? savedAt})>
  loadStaffManifest(int scheduleId) async {
    final key = _staffManifestKey(scheduleId);

    try {
      final response = await api.get('driver/schedules/$scheduleId/manifest');
      final data = Map<String, dynamic>.from(api.data(response) as Map);
      OfflineCache.instance.writeAccount(key, {
        'saved_at': DateTime.now().toIso8601String(),
        'manifest': data,
      });
      return (data: data, fromCache: false, savedAt: null);
    } catch (e) {
      final cached = cachedStaffManifest(scheduleId);
      if (cached == null) rethrow;
      return (
        data: cached.data,
        fromCache: true,
        savedAt: cached.savedAt,
      );
    }
  }

  /// รายชื่อผู้โดยสารชุดที่บันทึกไว้ครั้งล่าสุดของรอบนี้ — null เมื่อยังไม่เคยมี
  ({Map<String, dynamic> data, DateTime? savedAt})? cachedStaffManifest(
    int scheduleId,
  ) {
    final cached = OfflineCache.instance.readAccount<Map>(
      _staffManifestKey(scheduleId),
    );
    final manifest = cached?['manifest'];
    if (manifest is! Map) return null;

    return (
      data: Map<String, dynamic>.from(manifest),
      savedAt: DateTime.tryParse('${cached!['saved_at']}')?.toLocal(),
    );
  }

  /// ลูกค้ากดบอกสถานะตัวเองที่จุดนัด — `on_the_way` / `arrived` / `late`
  ///
  /// [etaMinutes] มีความหมายเฉพาะกับ `late` และเซิร์ฟเวอร์จะล้างทิ้งเองกับ
  /// สถานะอื่น คืน payload เดียวกับที่ API ตอบ (สถานะ เวลา และคำอธิบายไทย)
  Future<Map<String, dynamic>> reportPickupStatus(
    String bookingRef, {
    required String status,
    int? etaMinutes,
  }) async {
    final response = await api.post(
      'bookings/$bookingRef/pickup-status',
      body: {'status': status, 'eta_minutes': ?etaMinutes},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Staff reports an on-trip incident (accident / injury) for a schedule.
  /// Notifies ops/admin/assigned staff on the server. Returns the created
  /// incident map. Sends multipart when a [photoPath] is attached.
  Future<Map<String, dynamic>> reportIncident({
    required int scheduleId,
    required String severity,
    required String description,
    String? passengerName,
    int? bookingId,
    double? latitude,
    double? longitude,
    String? photoPath,
  }) async {
    final fields = <String, dynamic>{
      'severity': severity,
      'description': description,
      'latitude': ?latitude,
      'longitude': ?longitude,
      if (passengerName != null && passengerName.isNotEmpty)
        'passenger_name': passengerName,
      'booking_id': ?bookingId,
    };

    final hasPhoto = photoPath != null && photoPath.isNotEmpty;
    final response = hasPhoto
        ? await api.postMultipart(
            'driver/schedules/$scheduleId/incidents',
            fields: fields,
            files: {'photo': photoPath},
          )
        : await api.post(
            'driver/schedules/$scheduleId/incidents',
            body: fields,
          );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Incidents logged for a schedule (most recent first).
  Future<List<Map<String, dynamic>>> loadIncidents(int scheduleId) async {
    final response = await api.get('driver/schedules/$scheduleId/incidents');
    final list = api.data(response);
    if (list is! List) return const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// ยอดค้างชำระของรอบที่สตาฟรับผิดชอบ — คืน `{count, total_due, items}`
  /// แต่ละ item มี `pay_url` ให้ทำเป็น QR ให้ลูกค้าสแกนจ่ายเองหน้างาน
  Future<Map<String, dynamic>> loadStaffOutstanding(int scheduleId) async {
    final response = await api.get(ApiEndpoints.staffOutstanding(scheduleId));
    final data = api.data(response);
    if (data is! Map) return const {'count': 0, 'total_due': 0, 'items': []};
    return Map<String, dynamic>.from(data);
  }

  /// ใบแจกอุปกรณ์เช่าของรอบ — คืน `{summary, items, bookings}`
  /// items = ยอดรวมต่อชิ้นของทั้งรอบ, bookings = รายการจองพร้อมสถานะแจก/รับคืน
  /// โปรไฟล์แนะนำตัวของสตาฟ — สิ่งที่ลูกทริปเห็นในการ์ดแนะนำทีมงานในห้องแชท
  Future<Map<String, dynamic>> loadStaffProfile() async {
    final response = await api.get(ApiEndpoints.staffProfile);
    final data = api.data(response);
    if (data is! Map) return const {};
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> saveStaffProfile({
    required String nickname,
    required String bio,
    required List<String> trails,
    required List<String> skills,
  }) async {
    final response = await api.put(
      ApiEndpoints.staffProfile,
      body: {
        'nickname': nickname,
        'staff_bio': bio,
        'staff_trails': trails,
        'staff_skills': skills,
      },
    );
    final data = api.data(response);
    // ชื่อเล่นใช้ทั้งแอป (ห้องแชท โปรไฟล์) — อัปเดตตัวเก็บผู้ใช้ไปด้วย
    if (user != null) {
      user = {
        ...user!,
        'nickname': nickname.trim().isEmpty ? null : nickname.trim(),
        'has_staff_intro': bio.trim().isNotEmpty,
      };
      notifyListeners();
    }
    if (data is! Map) return const {};
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> loadStaffRentals(int scheduleId) async {
    final response = await api.get(ApiEndpoints.staffRentals(scheduleId));
    final data = api.data(response);
    if (data is! Map) return const {};
    return Map<String, dynamic>.from(data);
  }

  /// รอบที่ยังไม่ออกเดินทางและมีคนเช่าอุปกรณ์ — สำหรับคนจัดของ
  Future<List<Map<String, dynamic>>> loadPackingSchedules() async {
    final response = await api.get(ApiEndpoints.packingSchedules);
    final data = api.data(response);
    final list = data is Map ? data['schedules'] : null;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  static String _packingCacheKey(int scheduleId) => 'packing.$scheduleId';

  /// ใบเตรียมของที่โหลดสำเร็จล่าสุดของรอบนี้ — โกดังบางที่สัญญาณไม่ดี
  Map<String, dynamic>? cachedPackingList(int scheduleId) {
    final cached = OfflineCache.instance.readAccount<Map>(
      _packingCacheKey(scheduleId),
    );
    return cached == null ? null : Map<String, dynamic>.from(cached);
  }

  /// ใบเตรียมของหนึ่งรอบ — คืน `{schedule, picking, items, bookings, totals}`
  /// picking = ชิ้นที่ต้องหยิบจริง (แตกชุดแล้ว), items = ตามที่ลูกค้าเช่า
  Future<Map<String, dynamic>> loadPackingList(int scheduleId) async {
    final response = await api.get(ApiEndpoints.packingSchedule(scheduleId));
    final data = api.data(response);
    if (data is! Map) return const {};
    final result = Map<String, dynamic>.from(data);
    OfflineCache.instance.writeAccount(_packingCacheKey(scheduleId), {
      ...result,
      'cached_at': DateTime.now().toIso8601String(),
    });
    return result;
  }

  /// ติ๊กแจก/รับคืนอุปกรณ์หนึ่งชิ้น — คืนใบแจกชุดใหม่ทั้งก้อน (ไม่ต้องโหลดซ้ำ)
  Future<Map<String, dynamic>> markStaffRental(
    int scheduleId, {
    required String bookingRef,
    required String itemName,
    required String action, // handout | return
    required bool done,
  }) async {
    final response = await api.post(
      ApiEndpoints.staffRentalMark(scheduleId),
      body: {
        'booking_ref': bookingRef,
        'item_name': itemName,
        'action': action,
        'done': done,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// สมุดบัญชีหน้างานของรอบ — คืน `{schedule, summary, categories, items}`
  Future<Map<String, dynamic>> loadStaffLedger(int scheduleId) async {
    final response = await api.get(ApiEndpoints.staffLedger(scheduleId));
    final data = api.data(response);
    if (data is! Map) return const {};
    return Map<String, dynamic>.from(data);
  }

  /// บันทึก/แก้ไขรายการหนึ่งบรรทัด — ส่ง [entryId] มาคือแก้ของเดิม
  /// แนบสลิปเมื่อมี [slipPath] (multipart) นอกนั้นส่ง JSON ตามปกติ
  /// คืนสมุดบัญชีชุดใหม่ทั้งก้อน จะได้ไม่ต้องโหลดซ้ำ
  Future<Map<String, dynamic>> saveStaffLedgerEntry(
    int scheduleId, {
    int? entryId,
    required String kind, // expense | income
    required String name,
    required double amount,
    String? category,
    String? note,
    String? spentAt, // YYYY-MM-DD
    String? slipPath,
    bool removeSlip = false,
  }) async {
    final path = entryId == null
        ? ApiEndpoints.staffLedger(scheduleId)
        : ApiEndpoints.staffLedgerEntry(scheduleId, entryId);

    final fields = <String, dynamic>{
      'kind': kind,
      'name': name,
      'amount': amount,
      'category': ?category,
      if (note != null && note.isNotEmpty) 'note': note,
      'spent_at': ?spentAt,
      if (removeSlip) 'remove_slip': true,
    };

    final hasSlip = slipPath != null && slipPath.isNotEmpty;
    final response = hasSlip
        ? await api.postMultipart(path, fields: fields, files: {'slip': slipPath})
        : await api.post(path, body: fields);

    final data = api.data(response);
    if (data is! Map) return const {};
    final map = Map<String, dynamic>.from(data);
    // create/update ห่อไว้ใต้ ledger, ส่วน delete คืนสมุดตรงๆ
    final ledger = map['ledger'];
    return ledger is Map ? Map<String, dynamic>.from(ledger) : map;
  }

  /// ลบรายการที่ตัวเองบันทึกไว้ — คืนสมุดบัญชีชุดใหม่
  Future<Map<String, dynamic>> deleteStaffLedgerEntry(
    int scheduleId,
    int entryId,
  ) async {
    final response = await api.delete(
      ApiEndpoints.staffLedgerEntry(scheduleId, entryId),
    );
    final data = api.data(response);
    if (data is! Map) return const {};
    return Map<String, dynamic>.from(data);
  }

  /// ใบซื้อของของรอบ — คืน `{schedule, headcount, summary, locked, items, report}`
  /// รอบแรกที่เปิด เซิร์ฟเวอร์ก๊อปรายการประจำทริปมาให้เอง
  Future<Map<String, dynamic>> loadStaffShopping(int scheduleId) async {
    final response = await api.get(ApiEndpoints.staffShopping(scheduleId));
    final data = api.data(response);
    if (data is! Map) return const {};
    return Map<String, dynamic>.from(data);
  }

  /// ติ๊ก/เลิกติ๊ก "ซื้อแล้ว" — คืนใบซื้อของชุดใหม่ทั้งใบ
  Future<Map<String, dynamic>> markStaffShoppingItem(
    int scheduleId,
    int itemId, {
    required bool bought,
  }) async {
    final response = await api.post(
      ApiEndpoints.staffShoppingBought(scheduleId, itemId),
      body: {'bought': bought},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// เพิ่มของเฉพาะรอบนี้ (ไม่แตะรายการประจำทริป)
  Future<Map<String, dynamic>> addStaffShoppingItem(
    int scheduleId, {
    required String name,
    double? quantity,
    String? unit,
    String? note,
  }) async {
    final response = await api.post(
      ApiEndpoints.staffShoppingItems(scheduleId),
      body: {
        'name': name,
        'quantity': ?quantity,
        if (unit != null && unit.isNotEmpty) 'unit': unit,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ลบของที่ตัวเองเพิ่มไว้
  Future<Map<String, dynamic>> deleteStaffShoppingItem(
    int scheduleId,
    int itemId,
  ) async {
    final response = await api.delete(
      ApiEndpoints.staffShoppingItem(scheduleId, itemId),
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ส่งรายงานซื้อของ — [photoPaths] ต้องมีอย่างน้อยหนึ่งรูป (เซิร์ฟเวอร์บังคับ)
  /// ใส่ [totalAmount] + [addToLedger] แล้วยอดจะลงบัญชีหน้างานให้เลย
  Future<Map<String, dynamic>> submitStaffShoppingReport(
    int scheduleId, {
    required List<String> photoPaths,
    double? totalAmount,
    String? note,
    bool addToLedger = false,
  }) async {
    final response = await api.postMultipart(
      ApiEndpoints.staffShoppingReport(scheduleId),
      fields: {
        'total_amount': ?totalAmount,
        if (note != null && note.isNotEmpty) 'note': note,
        // multipart ส่งทุกอย่างเป็นข้อความ — กฎ boolean ของ Laravel รับ "1"/"0"
        // แต่ไม่รับ "true"
        'add_to_ledger': addToLedger ? '1' : '0',
      },
      files: {
        for (var i = 0; i < photoPaths.length; i++) 'photos[$i]': photoPaths[i],
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ส่งลิงก์ชำระเงินซ้ำให้ลูกค้าที่ค้างชำระ (email / sms)
  Future<void> sendStaffPaymentLink(
    int scheduleId,
    String bookingRef, {
    List<String> channels = const ['email'],
  }) async {
    await api.post(
      ApiEndpoints.staffOutstandingSendLink(scheduleId, bookingRef),
      body: {'channels': channels},
    );
  }

  /// Mark an incident resolved.
  Future<Map<String, dynamic>> resolveIncident(int id) async {
    final response = await api.post('driver/incidents/$id/resolve');
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Mark a pickup point done (or undo). On completion, passengers at the next
  /// pending point are notified the van is on its way. Returns
  /// `{ point_id, completed_at, next_point, notified, pickup_points }`.
  Future<Map<String, dynamic>> setPickupCompleted(
    int scheduleId,
    int pointId,
    bool completed,
  ) async {
    final response = await api.post(
      'driver/schedules/$scheduleId/pickup-points/$pointId/complete',
      body: {'completed': completed},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// รอบที่ถึงเวลาให้มือถือของสตาฟเป็น GPS ของรถแล้ว — เซิร์ฟเวอร์เป็นคนตัดสิน
  /// (share_location_due) แอปแค่ทำตาม
  Map<String, dynamic>? get _vehicleSharingDueRound {
    for (final raw in staffSchedules) {
      final s = raw is Map ? Map<String, dynamic>.from(raw) : null;
      final mode = s?['share_location_mode']?.toString();
      if (s == null || mode == null || mode.isEmpty || mode == 'null') continue;
      if (int.tryParse('${s['id']}') == null) continue;

      return s;
    }

    return null;
  }

  /// เปิด/ปิดการแชร์ตำแหน่งรถให้ตรงกับรอบที่กำลังเดินทาง
  ///
  /// ลูกค้าต้องเห็นรถโดยที่สตาฟไม่ต้องทำอะไรเพิ่ม — สตาฟกำลังเช็คอินและดูแลคน
  /// หน้างานอยู่ตอนรถออกพอดี การแชร์จึงเปิดเองเมื่อถึงวันเดินทางของรอบที่ตัวเอง
  /// รับผิดชอบ และปิดเองเมื่อรอบจบ ยังปิดเองได้ทุกเมื่อจากการ์ดในหน้ารายชื่อ
  /// (ปิดแล้วจำไว้ ไม่ใช่เปิดกลับมาให้ในอีกห้านาที)
  Future<void> syncVehicleSharing() async {
    final sharing = VehicleLocationSharing.instance;

    if (!isLoggedIn || !canUseStaffCheckIn) {
      await sharing.abandonLocally();

      return;
    }

    final round = _vehicleSharingDueRound;

    await sharing.syncAuto(
      api: api,
      dueScheduleId: round == null ? null : int.parse('${round['id']}'),
      plate: round == null
          ? null
          : (round['vehicle'] as Map?)?['license_plate']?.toString(),
      mode: round?['share_location_mode']?.toString() ??
          VehicleLocationSharing.modePickup,
    );
  }

  /// ดึงรอบของสตาฟใหม่แล้วซิงก์การแชร์ — ใช้ตอนกลับเข้าแอป เพราะ
  /// share_location_due เป็นคำตอบ ณ เวลาที่โหลด ไม่ใช่ค่าที่เปลี่ยนเอง
  ///
  /// ยิงเฉพาะตอนที่มีรอบใกล้ ๆ จริง (เมื่อวาน–พรุ่งนี้) วันธรรมดาที่ไม่มีทริป
  /// จะไม่มีคำขอเพิ่มสักครั้ง
  /// ดึงรอบของสตาฟซ้ำเร็วที่สุดทุกกี่นาที — หน้ารายชื่อเป็น query ที่หนัก
  /// (ไล่ผู้โดยสารทุกใบของทุกรอบ) การสลับแอปไปมาไม่ควรลากมันมาทุกครั้ง
  static const Duration _staffRosterMinGap = Duration(minutes: 5);

  DateTime? _lastStaffRosterFetch;

  Future<void> refreshVehicleSharing() async {
    if (!isLoggedIn || !canUseStaffCheckIn) return;

    final last = _lastStaffRosterFetch;
    final stale = last == null || DateTime.now().difference(last) > _staffRosterMinGap;

    if (stale && _hasRoundAroundToday()) {
      _lastStaffRosterFetch = DateTime.now();
      try {
        final response = await api.get(ApiEndpoints.staffSchedulesMy);
        final data = api.data(response) as Map?;
        staffSchedules = List<dynamic>.from(data?['schedules'] ?? staffSchedules);
        notifyListeners();
      } catch (e) {
        debugPrint('refreshVehicleSharing: โหลดรอบของสตาฟไม่สำเร็จ $e');
      }
    }

    await syncVehicleSharing();
  }

  /// มีรอบที่เดินทางอยู่ในช่วงเมื่อวานถึงพรุ่งนี้ไหม (เทียบด้วยวันที่ล้วน ๆ)
  bool _hasRoundAroundToday() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - 1);
    final to = DateTime(now.year, now.month, now.day + 1);

    for (final raw in staffSchedules) {
      final s = raw is Map ? raw : null;
      final start = DateTime.tryParse('${s?['departure_date']}');
      if (start == null) continue;
      final end = DateTime.tryParse('${s?['return_date']}') ?? start;

      if (!end.isBefore(from) && !start.isAfter(to)) return true;
    }

    return false;
  }

  /// สตาฟกด "รถถึงจุดนี้แล้ว" — รูปตรงที่จอดคือหัวใจ ไม่ใช่ของแถม
  ///
  /// คนละปุ่มกับ [setPickupCompleted] ("รับครบแล้ว") โดยตั้งใจ: รถถึงคือนาทีที่
  /// ลูกค้ายังยืนหาอยู่ รับครบคือนาทีที่ทุกคนขึ้นรถแล้ว
  Future<Map<String, dynamic>> markPickupArrived(
    int scheduleId,
    int pointId, {
    String? photoPath,
    String? note,
  }) async {
    final path = 'staff/schedules/$scheduleId/pickup-points/$pointId/arrived';
    final response = photoPath == null
        ? await api.post(path, body: {'note': ?note})
        : await api.postMultipart(
            path,
            fields: {'note': ?note},
            files: {'photo': photoPath},
          );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// กดผิดจุด — ถอนคืนทั้งรูปและข้อความที่ลงห้องแชทไปแล้ว
  Future<Map<String, dynamic>> clearPickupArrival(
    int scheduleId,
    int pointId,
  ) async {
    final response = await api.delete(
      'staff/schedules/$scheduleId/pickup-points/$pointId/arrived',
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// เงื่อนไขก่อนจองที่ประกาศใช้อยู่ {terms_version, booking_terms, ...}
  ///
  /// ไม่แคช — ลูกค้าต้องเห็นฉบับล่าสุดทุกครั้งที่กดจอง ไม่งั้นเซิร์ฟเวอร์จะปฏิเสธ
  /// ใบจองที่ยอมรับฉบับเก่า แล้วลูกค้าก็กดซ้ำไปเจอข้อความเดิมวนไม่จบ
  Future<Map<String, dynamic>> fetchLegalPolicy() async {
    final response = await api.get(ApiEndpoints.legalPolicy);
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  Future<Map<String, dynamic>> createBooking(
    Map<String, dynamic> payload,
  ) async {
    final response = await api.post(ApiEndpoints.bookings, body: payload);
    final booking = Map<String, dynamic>.from(api.data(response) as Map);
    await loadAccountData();
    await loadActiveSeatLocks(silent: true);
    final amountRaw = booking['total_amount'];
    final amount = amountRaw is num
        ? amountRaw
        : num.tryParse(amountRaw?.toString() ?? '');
    await AnalyticsService.instance.logBookingCreated(
      tripSlug: payload['trip_slug']?.toString() ?? '',
      amount: amount,
    );
    return booking;
  }

  void _resetBookingHistory() {
    _bookingHistoryGen++;
    bookingHistoryMeta = null;
    _bookingHistoryPage = 0;
    _bookingHistoryIds.clear();
    bookingHistoryLoading = false;
    bookingHistoryError = null;
  }

  void _applyBookingsFirstPage({
    required List<dynamic> current,
    required List<dynamic> history,
    required Map<String, dynamic>? historyMeta,
  }) {
    _resetBookingHistory();
    final known = {for (final b in current) if (b is Map) '${b['id']}'};
    bookings = [
      ...current,
      for (final b in history)
        if (b is! Map || !known.contains('${b['id']}')) b,
    ];
    for (final b in history) {
      if (b is Map) _bookingHistoryIds.add('${b['id']}');
    }
    bookingHistoryMeta = historyMeta;
    _bookingHistoryPage = 1;
  }

  /// ให้เทสต์ตั้งสภาพ "เพิ่งโหลดหน้าแรกมา" โดยไม่ต้องผ่าน [loadAccountData]
  /// ที่พ่วงงานเบื้องหลังอื่นอีกมาก
  @visibleForTesting
  void debugApplyBookingsFirstPage({
    required List<dynamic> current,
    required List<dynamic> history,
    required Map<String, dynamic>? historyMeta,
  }) =>
      _applyBookingsFirstPage(
        current: current,
        history: history,
        historyMeta: historyMeta,
      );

  void _writeBookingsCache() {
    final cache = OfflineCache.instance;
    cache.writeAccount('bookings', bookings);
    cache.writeAccount('bookingHistory', {
      'meta': bookingHistoryMeta,
      'page': _bookingHistoryPage,
      'ids': _bookingHistoryIds.toList(),
    });
  }

  void _restoreBookingHistoryState(Map? saved) {
    _resetBookingHistory();
    if (saved == null || saved['meta'] is! Map) return;
    bookingHistoryMeta = Map<String, dynamic>.from(saved['meta'] as Map);
    _bookingHistoryPage = int.tryParse('${saved['page']}') ?? 0;
    final ids = saved['ids'];
    if (ids is List) _bookingHistoryIds.addAll(ids.map((e) => '$e'));
  }

  /// โหลดประวัติการจองหน้าถัดไปต่อท้าย [bookings] — เรียกซ้ำระหว่างกำลังโหลด
  /// หรือเมื่อครบแล้วจะไม่ทำอะไร ผิดพลาดเก็บไว้ที่ [bookingHistoryError]
  Future<void> loadMoreBookingHistory() async {
    if (!isLoggedIn || bookingHistoryLoading || !bookingHistoryHasMore) return;
    final gen = _bookingHistoryGen;
    final page = _bookingHistoryPage + 1;
    bookingHistoryLoading = true;
    bookingHistoryError = null;
    notifyListeners();
    try {
      final response = await api.get(
        ApiEndpoints.bookings,
        query: {
          'scope': 'history',
          'per_page': bookingHistoryPageSize,
          'page': page,
        },
      );
      // รายการถูกโหลดใหม่ (ดึงลงรีเฟรช/ออกจากระบบ) ระหว่างรอ — หน้านี้เป็นของชุดเก่า
      if (gen != _bookingHistoryGen) return;
      final items = List<dynamic>.from(api.data(response) ?? []);
      // ทริปที่เพิ่งจบระหว่างเลื่อนดูทำให้รายการขยับหนึ่งช่อง จึงอาจได้ใบซ้ำกับหน้าก่อน
      final known = {for (final b in bookings) if (b is Map) '${b['id']}'};
      bookings = [
        ...bookings,
        for (final b in items)
          if (b is! Map || !known.contains('${b['id']}')) b,
      ];
      for (final b in items) {
        if (b is Map) _bookingHistoryIds.add('${b['id']}');
      }
      _bookingHistoryPage = page;
      final meta = api.meta(response);
      if (meta != null) bookingHistoryMeta = meta;
      _writeBookingsCache();
    } catch (e) {
      if (gen != _bookingHistoryGen) return;
      bookingHistoryError = e is ApiException
          ? e.message
          : 'โหลดรายการก่อนหน้าไม่สำเร็จ';
    } finally {
      if (gen == _bookingHistoryGen) {
        bookingHistoryLoading = false;
        notifyListeners();
      }
    }
  }

  /// โหลดประวัติที่เหลือทั้งหมด — ใช้ตอนค้นหา เพราะการค้นหาทำในเครื่อง
  /// ถ้ามีหน้าที่ยังไม่ได้โหลด ทริปเก่าที่ตรงคำค้นจะไม่ขึ้นเลย
  Future<void> loadAllBookingHistory() async {
    final gen = _bookingHistoryGen;
    while (bookingHistoryHasMore &&
        gen == _bookingHistoryGen &&
        bookingHistoryError == null) {
      if (bookingHistoryLoading) return; // อีกตัวกำลังไล่โหลดอยู่แล้ว
      final before = _bookingHistoryPage;
      await loadMoreBookingHistory();
      if (_bookingHistoryPage == before) return; // ไม่คืบหน้า — กันวนไม่รู้จบ
    }
  }

  Future<void> cancelBooking(String ref, String reason) async {
    await api.post('bookings/$ref/cancel', body: {'reason': reason});
    await loadAccountData();
    await AnalyticsService.instance.logBookingCancelled(ref);
  }

  /// ย้ายการจองไปอีกรอบเดินทางของทริปเดียวกัน (คงราคาเดิม เลือกที่นั่งใหม่)
  Future<Map<String, dynamic>> rescheduleBooking(
    String ref, {
    required int targetScheduleId,
    List<String> seatIds = const [],
    int? pickupPointId,
  }) async {
    final response = await api.post(
      ApiEndpoints.bookingReschedule(ref),
      body: {
        'target_schedule_id': targetScheduleId,
        if (seatIds.isNotEmpty) 'seat_ids': seatIds,
        'pickup_point_id': ?pickupPointId,
      },
    );
    await loadAccountData();
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// รอบไม่ได้ออกเพราะผู้ร่วมทริปไม่ครบ — ยกเลิกและขอรับเงินคืนเต็มจำนวน
  /// บัญชีรับเงินจำเป็นเมื่อมียอดที่ชำระแล้ว (เซิร์ฟเวอร์ตรวจเลขบัญชีเอง)
  Future<Map<String, dynamic>> requestPostponementRefund(
    String ref, {
    String? bank,
    String? accountNumber,
    String? accountName,
  }) async {
    final response = await api.post(
      ApiEndpoints.bookingPostponementRefund(ref),
      body: {
        'bank': ?bank,
        'account_number': ?accountNumber,
        'account_name': ?accountName,
      },
    );
    await loadAccountData();
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// เปลี่ยนจุดรับของการจอง (คงราคาเดิม)
  Future<Map<String, dynamic>> changeBookingPickup(
    String ref, {
    required int pickupPointId,
  }) async {
    final response = await api.post(
      ApiEndpoints.bookingChangePickup(ref),
      body: {'pickup_point_id': pickupPointId},
    );
    await loadAccountData();
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  // ─── เอกสารเดินทาง (ทริปต่างประเทศ) ────────────────────────────────────

  /// สถานะพาสปอร์ตของผู้เดินทางทุกคนในการจอง + เกณฑ์วันหมดอายุที่ยังรับได้
  Future<Map<String, dynamic>> travelDocuments(String ref) async {
    final response = await api.get(ApiEndpoints.bookingTravelDocuments(ref));
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  /// บันทึกพาสปอร์ตของผู้เดินทางหลายคนในครั้งเดียว
  ///
  /// แถวที่เว้นว่างทั้งแถวถือว่า "ยังไม่พร้อมกรอก" ฝั่งเซิร์ฟเวอร์จะข้ามให้เอง
  /// และถ้ามีแถวใดผิด จะไม่บันทึกอะไรเลย (ทั้งใบผ่านหรือทั้งใบไม่ผ่าน)
  Future<Map<String, dynamic>> saveTravelDocuments(
    String ref,
    List<Map<String, dynamic>> passengers,
  ) async {
    final response = await api.post(
      ApiEndpoints.bookingTravelDocuments(ref),
      body: {'passengers': passengers},
    );
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  // ─── ไฟล์เอกสารแนบที่ทริปขอ ─────────────────────────────────────────────
  // รายการที่ต้องแนบมาจากทริป (แอดมินตั้งเอง) ไฟล์ผูกกับผู้เดินทางรายคน

  Future<Map<String, dynamic>> bookingDocuments(String ref) async {
    final response = await api.get(ApiEndpoints.bookingDocuments(ref));
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  /// แนบไฟล์หนึ่งใบให้ผู้เดินทางหนึ่งคน — คืนผังเอกสารชุดใหม่ทั้งการจอง
  Future<Map<String, dynamic>> uploadBookingDocument({
    required String ref,
    required int passengerId,
    required String requirementKey,
    required String filePath,
  }) async {
    final response = await api.postMultipart(
      ApiEndpoints.bookingDocuments(ref),
      fields: {
        'passenger_id': passengerId,
        'requirement_key': requirementKey,
      },
      files: {'file': filePath},
    );
    final data = api.data(response);
    final documents = data is Map ? data['documents'] : null;
    return documents is Map
        ? Map<String, dynamic>.from(documents)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> deleteBookingDocument(
    String ref,
    int documentId,
  ) async {
    final response = await api.delete(ApiEndpoints.bookingDocument(ref, documentId));
    return Map<String, dynamic>.from(api.data(response) ?? const {});
  }

  // ─── Booking members / companion invites ───────────────────────────────

  /// รายชื่อสมาชิกของการจอง (เจ้าของ + เพื่อนที่ถูกเชิญ/รับแล้ว)
  Future<Map<String, dynamic>> bookingMembers(String ref) async {
    final response = await api.get(ApiEndpoints.bookingMembers(ref));
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  /// เจ้าของสร้างคำเชิญหนึ่งใบ — คืน invite_token + invite_url สำหรับส่งต่อ
  Future<Map<String, dynamic>> createBookingInvite(
    String ref, {
    int? passengerId,
    String? label,
  }) async {
    final response = await api.post(
      ApiEndpoints.bookingInvites(ref),
      body: {'passenger_id': ?passengerId, 'label': ?label},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// เจ้าของนำสมาชิกออกหรือยกเลิกคำเชิญ
  Future<void> revokeBookingMember(String ref, int memberId) async {
    await api.delete(ApiEndpoints.bookingMember(ref, memberId));
  }

  /// พรีวิวคำเชิญก่อนกดรับ (ผูกจาก user ที่ล็อกอินอยู่ ไม่ว่าจะล็อกอินด้วยวิธีใด)
  Future<Map<String, dynamic>> previewBookingInvite(String token) async {
    final response = await api.get(ApiEndpoints.bookingInvite(token));
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  /// รับคำเชิญ แล้วรีโหลดรายการจองให้เห็นทริปที่เพิ่งเข้าร่วม
  Future<Map<String, dynamic>> acceptBookingInvite(String token) async {
    final response = await api.post(ApiEndpoints.bookingInviteAccept(token));
    final data = Map<String, dynamic>.from(api.data(response) as Map);
    await loadAccountData();
    return data;
  }

  // ─── ส่งต่อที่นั่ง ─────────────────────────────────────────────────────────

  /// ที่นั่งที่ผู้ใช้ส่งต่อได้ + ลิงก์ที่เปิดค้าง + ประวัติ (กติกาทั้งหมดมาจากเซิร์ฟเวอร์)
  Future<Map<String, dynamic>> seatHandovers(String ref) async {
    final response = await api.get(ApiEndpoints.bookingHandovers(ref));
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  /// ออกลิงก์ส่งต่อที่นั่งของผู้เดินทางหนึ่งคน — ลิงก์เก่าของที่นั่งเดียวกันใช้ไม่ได้อีก
  Future<Map<String, dynamic>> createSeatHandover(
    String ref, {
    required int passengerId,
    bool transfersOwnership = false,
    String? note,
  }) async {
    final response = await api.post(
      ApiEndpoints.bookingHandovers(ref),
      body: {
        'passenger_id': passengerId,
        'transfers_ownership': transfersOwnership,
        'note': ?note,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<void> cancelSeatHandover(String ref, int handoverId) async {
    await api.delete(ApiEndpoints.bookingHandover(ref, handoverId));
  }

  /// พรีวิวลิงก์ส่งต่อที่นั่งก่อนรับ (พร้อมข้อมูลโปรไฟล์ไว้เติมฟอร์ม)
  Future<Map<String, dynamic>> previewSeatHandover(String token) async {
    final response = await api.get(ApiEndpoints.seatHandover(token));
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  /// รับที่นั่ง แล้วรีโหลดรายการจองให้เห็นทริปที่เพิ่งได้มา
  Future<Map<String, dynamic>> claimSeatHandover(
    String token,
    Map<String, dynamic> traveller,
  ) async {
    final response = await api.post(
      ApiEndpoints.seatHandoverClaim(token),
      body: {...traveller, 'channel': 'app'},
    );
    final data = Map<String, dynamic>.from(api.data(response) as Map);
    await loadAccountData();
    return data;
  }

  // ─── การจองที่ทีมงานจองให้ ───────────────────────────────────────────────

  /// จำนวนใบจองที่ "น่าจะ" เป็นของผู้ใช้ (เบอร์ตรงกับใบที่ทีมงานเปิดให้)
  /// เซิร์ฟเวอร์ตอบแค่จำนวนกับชื่อทริป — รายละเอียดต้องยืนยันด้วยเลขที่จองก่อน
  int claimableBookingCount = 0;

  Future<void> loadClaimableBookings() async {
    try {
      final response = await api.get(ApiEndpoints.claimableBookings);
      final data = Map<String, dynamic>.from(api.data(response) ?? {});
      final count = (data['count'] as num?)?.toInt() ?? 0;
      if (count == claimableBookingCount) return;
      claimableBookingCount = count;
      notifyListeners();
    } catch (_) {
      // เป็นแค่คำชวน ไม่ใช่ข้อมูลหลักของหน้า — เงียบไว้ดีกว่าขึ้น error ให้ตกใจ
    }
  }

  /// ผูกใบจองที่ทีมงานเปิดให้เข้าบัญชีนี้ ด้วยเลขที่จอง + เบอร์ (4 ตัวท้ายก็พอ)
  Future<Map<String, dynamic>> claimBooking({
    required String bookingRef,
    required String phone,
  }) async {
    final response = await api.post(
      ApiEndpoints.claimBooking,
      body: {'booking_ref': bookingRef, 'phone': phone},
    );
    final data = Map<String, dynamic>.from(api.data(response) as Map);
    claimableBookingCount = 0;
    await loadAccountData();
    return data;
  }

  // ─── Trip posts / ฟีดรูปหลังทริป ────────────────────────────────────────

  /// ฟีดโพสต์รูป — ส่ง slug = ฟีดของทริปเดียว, ไม่ส่ง = ฟีดรวมทุกทริป
  /// คืน {data: [...], meta: {..., can_post?}}
  Future<Map<String, dynamic>> tripPosts({String? slug, int page = 1}) async {
    final response = await api.get(
      slug == null ? ApiEndpoints.tripPosts : ApiEndpoints.tripPostsOf(slug),
      query: {'page': page},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// โพสต์รูปเข้าฟีดของทริป (สูงสุด 6 รูป + แคปชัน)
  Future<Map<String, dynamic>> createTripPost(
    String slug, {
    required List<String> imagePaths,
    String? caption,
  }) async {
    final files = <String, String>{};
    for (var i = 0; i < imagePaths.length; i++) {
      files['images[$i]'] = imagePaths[i];
    }
    final response = await api.postMultipart(
      ApiEndpoints.tripPostsOf(slug),
      fields: {'caption': ?caption},
      files: files,
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<void> deleteTripPost(int postId) async {
    await api.delete(ApiEndpoints.tripPost(postId));
  }

  /// กดไลก์/เลิกไลก์ — คืน {liked, likes_count}
  Future<Map<String, dynamic>> likeTripPost(int postId) async {
    final response = await api.post(ApiEndpoints.tripPostLike(postId));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> tripPostComments(
    int postId, {
    int page = 1,
  }) async {
    final response = await api.get(
      ApiEndpoints.tripPostComments(postId),
      query: {'page': page},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> addTripPostComment(
    int postId,
    String body,
  ) async {
    final response = await api.post(
      ApiEndpoints.tripPostComments(postId),
      body: {'body': body},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<void> deleteTripPostComment(int postId, int commentId) async {
    await api.delete(ApiEndpoints.tripPostComment(postId, commentId));
  }

  Future<void> reportTripPost(int postId, {String? reason}) async {
    await api.post(
      ApiEndpoints.tripPostReport(postId),
      body: {'reason': ?reason},
    );
  }

  // ─── ดูแลเนื้อหา (รายงาน / บล็อก) ───────────────────────────────────────

  /// id ของผู้ใช้ที่ถูกบล็อกไว้ — เก็บไว้ในหน่วยความจำเพื่อกรองเนื้อหาที่
  /// มาแบบเรียลไทม์ (ข้อความแชทที่ยิงผ่าน Reverb) ซึ่งเซิร์ฟเวอร์กรองให้ไม่ได้
  final Set<int> blockedUserIds = <int>{};

  bool isBlocked(int? userId) =>
      userId != null && blockedUserIds.contains(userId);

  /// รายงานเนื้อหาชิ้นหนึ่ง — [type] ต้องตรงกับ ModerationService::TYPES
  Future<void> reportContent({
    required String type,
    required int id,
    String? reason,
    String? note,
  }) async {
    await api.post(ApiEndpoints.reports, body: {
      'type': type,
      'id': id,
      'reason': ?reason,
      'note': ?note,
    });
  }

  Future<void> blockUser(int userId) async {
    await api.post(ApiEndpoints.myBlocks, body: {'user_id': userId});
    blockedUserIds.add(userId);
    notifyListeners();
  }

  Future<void> unblockUser(int userId) async {
    await api.delete(ApiEndpoints.myBlock(userId));
    blockedUserIds.remove(userId);
    notifyListeners();
  }

  /// รายชื่อผู้ใช้ที่ถูกบล็อก (สำหรับหน้าจัดการ) — ถือโอกาสรีเฟรช
  /// [blockedUserIds] ให้ตรงกับเซิร์ฟเวอร์ไปด้วย
  Future<List<Map<String, dynamic>>> blockedUsers() async {
    final response = await api.get(ApiEndpoints.myBlocks);
    final data = Map<String, dynamic>.from(api.data(response) ?? {});
    final blocks = (data['blocks'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    blockedUserIds
      ..clear()
      ..addAll(blocks
          .map((b) => int.tryParse('${b['user_id']}'))
          .whereType<int>());
    notifyListeners();

    return blocks;
  }

  /// โหลดรายการบล็อกเงียบ ๆ ตอนเปิดแอป — ถ้าล้มเหลวก็ปล่อยผ่าน
  /// อย่างมากคือเห็นเนื้อหาที่บล็อกไว้โผล่มาแบบเรียลไทม์จนกว่าจะรีเฟรช
  Future<void> preloadBlockedUsers() async {
    if (!isLoggedIn) return;
    try {
      await blockedUsers();
    } catch (_) {
      // เงียบไว้ — ไม่ใช่ข้อมูลที่ต้องมีเพื่อให้แอปทำงาน
    }
  }

  // ─── Split payment (แบ่งจ่ายกลุ่ม) ──────────────────────────────────────

  /// ภาพรวมการแบ่งจ่ายของการจอง: รายการส่วนแบ่ง สถานะ และลิงก์จ่าย
  Future<Map<String, dynamic>> bookingSplit(String ref) async {
    final response = await api.get(ApiEndpoints.bookingSplit(ref));
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  /// เจ้าของเริ่มแบ่งจ่าย — ไม่ส่ง shares = หารเท่าตามจำนวนผู้เดินทาง
  Future<Map<String, dynamic>> setupBookingSplit(
    String ref, {
    List<Map<String, dynamic>>? shares,
  }) async {
    final response = await api.post(
      ApiEndpoints.bookingSplit(ref),
      body: {'shares': ?shares},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// เจ้าของแก้ยอด/รายชื่อของส่วนที่ยังไม่ถูกชำระ (ส่งชุด pending ครบชุด)
  Future<Map<String, dynamic>> updateBookingSplit(
    String ref,
    List<Map<String, dynamic>> shares,
  ) async {
    final response = await api.put(
      ApiEndpoints.bookingSplit(ref),
      body: {'shares': shares},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// เจ้าของยกเลิกการแบ่งจ่าย (ลบเฉพาะส่วนที่ยังไม่จ่าย)
  Future<void> cancelBookingSplit(String ref) async {
    await api.delete(ApiEndpoints.bookingSplit(ref));
  }

  /// ระบบ Flexi-Price (Go Together) — ดูข้อเสนอไปต่อของการจอง (null = ไม่มีข้อเสนอ)
  Future<Map<String, dynamic>?> bookingFlexiOffer(String ref) async {
    final response = await api.get(ApiEndpoints.bookingFlexiOffer(ref));
    final data = api.data(response);
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// เจ้าของตอบรับ/ปฏิเสธข้อเสนอไปต่อ — คืนสถานะข้อเสนอล่าสุด
  Future<Map<String, dynamic>?> respondBookingFlexiOffer(
    String ref, {
    required bool accept,
  }) async {
    final response = await api.post(
      ApiEndpoints.bookingFlexiOfferRespond(ref),
      body: {'accept': accept},
    );
    final data = api.data(response);
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// ชำระส่วนแบ่งของตัวเอง (หรือจ่ายแทนเพื่อน) พร้อมแนบสลิป
  Future<Map<String, dynamic>> paySplitShare({
    required String bookingRef,
    required int shareId,
    String paymentMethod = 'promptpay',
    String? transferDate,
    String? transferTime,
    required String slipImagePath,
  }) async {
    final response = await api.postMultipart(
      ApiEndpoints.bookingSplitSharePay(bookingRef, shareId),
      fields: {
        'payment_method': paymentMethod,
        'transfer_date': ?transferDate,
        'transfer_time': ?transferTime,
      },
      files: {'slip_image': slipImagePath},
    );
    await loadAccountData();
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// เจ้าของกดเตือนสมาชิกที่ยังไม่จ่าย (push ผ่าน FCM)
  Future<void> remindSplitShare(String ref, int shareId) async {
    await api.post(ApiEndpoints.bookingSplitShareRemind(ref, shareId));
  }

  // ─── Group chat ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> chatMessages(
    int scheduleId, {
    int? beforeId,
    int? afterId,
  }) async {
    final response = await api.get(
      ApiEndpoints.chatMessages(scheduleId),
      query: {'per_page': 30, 'before_id': ?beforeId, 'after_id': ?afterId},
    );
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  Future<Map<String, dynamic>> sendChatMessage(
    int scheduleId,
    String body, {
    int? replyToId,
    List<int>? mentions,
  }) async {
    final response = await api.post(
      ApiEndpoints.chatMessages(scheduleId),
      body: {
        'body': body,
        'reply_to_id': ?replyToId,
        if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Edit the body of one's own text message. Returns the updated message.
  Future<Map<String, dynamic>> editChatMessage(
    int scheduleId,
    int messageId,
    String body, {
    List<int>? mentions,
  }) async {
    final response = await api.put(
      ApiEndpoints.chatMessage(scheduleId, messageId),
      body: {
        'body': body,
        if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Soft-delete a message (own message, or any if staff/admin). Returns the
  /// updated message (now flagged deleted).
  Future<Map<String, dynamic>> deleteChatMessage(
    int scheduleId,
    int messageId,
  ) async {
    final response = await api.delete(
      ApiEndpoints.chatMessage(scheduleId, messageId),
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> sendChatImage(
    int scheduleId,
    String imagePath, {
    String? body,
    int? replyToId,
  }) async {
    final response = await api.postMultipart(
      ApiEndpoints.chatMessages(scheduleId),
      fields: {
        if (body != null && body.isNotEmpty) 'body': body,
        if (replyToId != null) 'reply_to_id': '$replyToId',
      },
      files: {'image': imagePath},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Toggle an emoji reaction on a message. Returns the updated reaction set.
  Future<List<dynamic>> reactChatMessage(
    int scheduleId,
    int messageId,
    String emoji,
  ) async {
    final response = await api.post(
      ApiEndpoints.chatReact(scheduleId, messageId),
      body: {'emoji': emoji},
    );
    final data = Map<String, dynamic>.from(api.data(response) ?? {});
    return List<dynamic>.from(data['reactions'] ?? const []);
  }

  /// Pin a message (staff/admin only). Returns the pinned message payload.
  Future<Map<String, dynamic>?> pinChatMessage(
    int scheduleId,
    int messageId,
  ) async {
    final response = await api.post(
      ApiEndpoints.chatPin(scheduleId, messageId),
    );
    final data = Map<String, dynamic>.from(api.data(response) ?? {});
    final pinned = data['pinned_message'];
    return pinned is Map ? Map<String, dynamic>.from(pinned) : null;
  }

  Future<void> unpinChatMessage(int scheduleId, int messageId) async {
    await api.delete(ApiEndpoints.chatPin(scheduleId, messageId));
  }

  /// Fire-and-forget "is typing" ping. Failures are swallowed — it's ephemeral.
  Future<void> sendChatTyping(int scheduleId) async {
    try {
      await api.post(ApiEndpoints.chatTyping(scheduleId));
    } catch (_) {}
  }

  /// Fire-and-forget "joined the room" ping so other members see a brief
  /// "X เข้าห้องแชท" notice. Ephemeral — failures are swallowed.
  Future<void> sendChatJoin(int scheduleId) async {
    try {
      await api.post(ApiEndpoints.chatJoined(scheduleId));
    } catch (_) {}
  }

  Future<void> markChatRead(int scheduleId) async {
    // Clear this room's unread locally first so the bottom-nav badge drops the
    // moment the user opens the room, without waiting for a roster refresh.
    _clearChatUnreadLocally(scheduleId);
    await api.post(ApiEndpoints.chatRead(scheduleId));
  }

  /// Zero out the cached `unread_count` for one conversation and recompute the
  /// bottom-nav total. No-op (beyond recompute) if the room isn't cached yet.
  void _clearChatUnreadLocally(int scheduleId) {
    var changed = false;
    for (final c in chatConversations) {
      if (c is! Map) continue;
      final id = int.tryParse('${c['schedule_id'] ?? c['id']}');
      if (id != scheduleId) continue;
      if ((int.tryParse('${c['unread_count']}') ?? 0) != 0) {
        c['unread_count'] = 0;
        changed = true;
      }
    }
    final newTotal = chatConversations.fold<int>(0, (sum, c) {
      return sum + (int.tryParse('${(c as Map?)?['unread_count']}') ?? 0);
    });
    if (changed || newTotal != chatUnreadTotal) {
      chatUnreadTotal = newTotal;
      notifyListeners();
    }
  }

  Future<int> chatUnreadCount(int scheduleId) async {
    final response = await api.get(ApiEndpoints.chatUnreadCount(scheduleId));
    final data = Map<String, dynamic>.from(api.data(response) ?? {});
    return int.tryParse('${data['count']}') ?? 0;
  }

  /// ตั้งระดับการแจ้งเตือนของห้องแชทนี้ แล้วอัปเดตรายการห้องที่แคชไว้ให้
  /// ไอคอนกระดิ่งในแท็บ "แชท" ตรงกันทันที คืนค่าที่เซิร์ฟเวอร์บันทึกจริง
  Future<ChatNotifyLevel> setChatNotifyLevel(
    int scheduleId,
    ChatNotifyLevel level,
  ) async {
    final response = await api.put(
      ApiEndpoints.chatNotifications(scheduleId),
      body: {'level': level.value},
    );
    final data = Map<String, dynamic>.from(api.data(response) ?? const {});
    final saved = ChatNotifyLevel.fromValue(data['notify_level'] ?? level.value);

    var changed = false;
    for (final c in chatConversations) {
      if (c is! Map) continue;
      final id = int.tryParse('${c['schedule_id'] ?? c['id']}');
      if (id != scheduleId) continue;
      c['notify_level'] = saved.value;
      changed = true;
    }
    if (changed) notifyListeners();

    return saved;
  }

  /// Room metadata for a chat: members (with per-member read positions),
  /// member count and the assigned vehicle. Drives the member roster and
  /// LINE-style "อ่านแล้ว N" read receipts.
  Future<Map<String, dynamic>> chatRoom(int scheduleId) async {
    final response = await api.get(ApiEndpoints.chatRoom(scheduleId));
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  // ── Support inbox (ศูนย์ช่วยเหลือ — ลูกค้าคุยกับทีมงาน) ────────────────────────

  /// The customer's support conversation meta (id, status, unread). Creates the
  /// room server-side on first call.
  Future<Map<String, dynamic>> supportConversation() async {
    final response = await api.get(ApiEndpoints.supportConversation);
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  /// Fetch the customer's support thread. `beforeId` pages older messages,
  /// `afterId` polls only messages newer than the given id.
  Future<Map<String, dynamic>> supportMessages({
    int? beforeId,
    int? afterId,
  }) async {
    final response = await api.get(
      ApiEndpoints.supportMessages,
      query: {'per_page': 30, 'before_id': ?beforeId, 'after_id': ?afterId},
    );
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  Future<Map<String, dynamic>> sendSupportMessage(String body) async {
    final response = await api.post(
      ApiEndpoints.supportMessages,
      body: {'body': body},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> sendSupportImage(
    String imagePath, {
    String? body,
  }) async {
    final response = await api.postMultipart(
      ApiEndpoints.supportMessages,
      fields: {if (body != null && body.isNotEmpty) 'body': body},
      files: {'image': imagePath},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<void> markSupportRead() async {
    // Drop the badge immediately; the server call just persists the pointer.
    if (supportUnread != 0) {
      supportUnread = 0;
      notifyListeners();
    }
    try {
      await api.post(ApiEndpoints.supportRead);
    } catch (_) {}
  }

  Future<int> supportUnreadCount() async {
    final response = await api.get(ApiEndpoints.supportUnreadCount);
    final data = Map<String, dynamic>.from(api.data(response) ?? {});
    final count = int.tryParse('${data['count']}') ?? 0;
    if (count != supportUnread) {
      supportUnread = count;
      notifyListeners();
    }
    return count;
  }

  /// Live updates for the customer's own support thread. Returns a disposer.
  Future<VoidCallback> subscribeSupport(
    int conversationId,
    RealtimeEventHandler handler,
  ) {
    return realtime.subscribe(
      channel: 'private-support.conversation.$conversationId',
      event: 'support.message',
      handler: handler,
    );
  }

  // ── Announcements (ประกาศจากผู้จัด ต่อรอบเดินทาง) ─────────────────────────────

  /// Official announcements for a schedule. Returns the payload as-is:
  /// `{ announcements: [...], can_moderate: bool, unread_count: int }`.
  Future<Map<String, dynamic>> scheduleAnnouncements(int scheduleId) async {
    final response = await api.get(ApiEndpoints.announcements(scheduleId));
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  Future<void> markAnnouncementsRead(int scheduleId) async {
    await api.post(ApiEndpoints.announcementsRead(scheduleId));
  }

  /// กำหนดการของรอบเดินทาง (สตาฟอ่านอย่างเดียว) — คืนรายการ item ตามลำดับ
  /// วัน → เวลา → ลำดับ จาก backend แต่ละ item: { item_date, time, title, detail }.
  static String _itineraryCacheKey(int scheduleId) => 'itinerary.$scheduleId';

  /// กำหนดการที่แคชไว้ครั้งล่าสุด — คืน null เมื่อยังไม่เคยโหลดสำเร็จ
  ///
  /// หน้ากำหนดการถูกเปิดตอนอยู่บนดอยที่มักไม่มีสัญญาณ การเห็นแผนเดินทางเวอร์ชัน
  /// ที่โหลดไว้ก่อนออกเดินทาง ดีกว่าเห็นข้อความ error
  List<Map<String, dynamic>>? cachedScheduleItinerary(int scheduleId) {
    final cached = OfflineCache.instance.readAccount<List>(
      _itineraryCacheKey(scheduleId),
    );
    if (cached == null) return null;
    return cached
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> scheduleItinerary(int scheduleId) async {
    final response = await api.get(ApiEndpoints.scheduleItinerary(scheduleId));
    final data = Map<String, dynamic>.from(api.data(response) ?? {});
    final items = (data['items'] as List? ?? const []);
    final parsed = items
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    OfflineCache.instance.writeAccount(
      _itineraryCacheKey(scheduleId),
      parsed,
    );

    return parsed;
  }

  /// เช็คอิน/ยกเลิกเช็คอินจุดกำหนดการ (สตาฟ) — คืนรายการที่อัปเดตแล้ว
  Future<Map<String, dynamic>> markItineraryReached(
    int scheduleId,
    int itemId, {
    required bool reached,
  }) async {
    final response = await api.post(
      ApiEndpoints.scheduleItineraryReach(scheduleId, itemId),
      body: {'reached': reached},
    );
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  Future<int> announcementsUnreadCount(int scheduleId) async {
    final response = await api.get(
      ApiEndpoints.announcementsUnreadCount(scheduleId),
    );
    final data = Map<String, dynamic>.from(api.data(response) ?? {});
    return int.tryParse('${data['count']}') ?? 0;
  }

  /// Post a new announcement (staff/operator only — gated server-side).
  Future<Map<String, dynamic>> postAnnouncement(
    int scheduleId, {
    required String category,
    required String title,
    required String body,
    bool isPinned = false,
  }) async {
    final response = await api.post(
      ApiEndpoints.announcements(scheduleId),
      body: {
        'category': category,
        'title': title,
        'body': body,
        'is_pinned': isPinned,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<void> deleteAnnouncement(int scheduleId, int announcementId) async {
    await api.delete(ApiEndpoints.announcement(scheduleId, announcementId));
  }

  Future<Map<String, dynamic>> setAnnouncementPinned(
    int scheduleId,
    int announcementId,
    bool pinned,
  ) async {
    final endpoint = ApiEndpoints.announcementPin(scheduleId, announcementId);
    final response = pinned
        ? await api.post(endpoint)
        : await api.delete(endpoint);
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Loads the user's trip chat rooms and refreshes the bottom-nav unread
  /// badge. Returns the list so screens can render it directly.
  Future<List<dynamic>> loadChatConversations() async {
    if (!isLoggedIn) {
      chatConversations = [];
      chatUnreadTotal = 0;
      notifyListeners();
      return chatConversations;
    }
    final response = await api.get(ApiEndpoints.chatMyConversations);
    chatConversations = List<dynamic>.from(api.data(response) ?? const []);
    chatUnreadTotal = chatConversations.fold<int>(0, (sum, c) {
      final n = int.tryParse('${(c as Map?)?['unread_count']}') ?? 0;
      return sum + n;
    });
    notifyListeners();
    return chatConversations;
  }

  /// Subscribe to a schedule's chat channel. Returns a disposer.
  Future<VoidCallback> subscribeChat(
    int scheduleId,
    RealtimeEventHandler handler,
  ) {
    return realtime.subscribe(
      channel: 'private-chat.schedule.$scheduleId',
      event: 'chat.message',
      handler: handler,
    );
  }

  /// Subscribe to a schedule's announcements channel for live "ประกาศใหม่"
  /// pushes while the feed is open. Returns a disposer.
  Future<VoidCallback> subscribeAnnouncements(
    int scheduleId,
    RealtimeEventHandler handler,
  ) {
    return realtime.subscribe(
      channel: 'private-announcements.schedule.$scheduleId',
      event: 'announcement.posted',
      handler: handler,
    );
  }

  /// "ข้อมูลการเดินทางของฉัน" สำหรับปุ่มคำถามด่วนในห้องแชท
  /// (ขึ้นรถกี่โมง / รอที่ไหน / ทะเบียนรถ / เบอร์คนขับ-สตาฟ)
  Future<Map<String, dynamic>> chatTripInfo(int scheduleId) async {
    final response = await api.get(ApiEndpoints.chatTripInfo(scheduleId));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// สตาฟกดส่งสรุปการเดินทางเข้าห้อง — คืนข้อความระบบที่เพิ่งโพสต์
  Future<Map<String, dynamic>> postChatTripSummary(int scheduleId) async {
    final response = await api.post(ApiEndpoints.chatTripSummary(scheduleId));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// สตาฟกดส่งกำหนดการของรอบเข้าห้อง — คืนข้อความระบบที่เพิ่งโพสต์
  Future<Map<String, dynamic>> postChatTripItinerary(int scheduleId) async {
    final response = await api.post(ApiEndpoints.chatTripItinerary(scheduleId));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// สร้างโพลในห้องแชท — คืนข้อความ (การ์ดโพล) ที่เพิ่งถูกสร้าง
  Future<Map<String, dynamic>> createChatPoll(
    int scheduleId, {
    required String question,
    required List<String> options,
    bool allowMultiple = false,
    int? durationHours,
    // 'vote' = โหวตตัดสินเสียงข้างมาก — ปิดเองเมื่อครบ/หมดเวลา แล้วประกาศผลเข้าห้อง
    String kind = 'poll',
    int? durationMinutes,
  }) async {
    final response = await api.post(
      ApiEndpoints.chatPolls(scheduleId),
      body: {
        'kind': kind,
        'question': question,
        'options': options,
        'allow_multiple': allowMultiple,
        'duration_hours': ?durationHours,
        'duration_minutes': ?durationMinutes,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ลงคะแนนโพล — ส่งลิสต์ว่างเพื่อถอนโหวตของตัวเอง คืน payload โพลล่าสุด
  Future<Map<String, dynamic>> voteChatPoll(
    int scheduleId,
    int pollId,
    List<int> optionIds,
  ) async {
    final response = await api.post(
      ApiEndpoints.chatPollVote(scheduleId, pollId),
      body: {'option_ids': optionIds},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ปิดโหวต (ผู้สร้างโพลหรือทีมงานเท่านั้น)
  Future<Map<String, dynamic>> closeChatPoll(int scheduleId, int pollId) async {
    final response = await api.post(
      ApiEndpoints.chatPollClose(scheduleId, pollId),
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  // ── รับออเดอร์อาหารในห้องแชท (แวะร้านตามสั่ง) ───────────────────────────
  // ทุกตัวคืน {message_id, food_round} ยกเว้น openChatFoodRound ที่คืนข้อความใหม่

  /// เปิดรอบรับออเดอร์ (สตาฟ/ทีมงานเท่านั้น) — คืนข้อความการ์ดที่เพิ่งลงห้อง
  Future<Map<String, dynamic>> openChatFoodRound(
    int scheduleId, {
    required String title,
    String? note,
    int? durationMinutes,
  }) async {
    final response = await api.post(
      ApiEndpoints.chatFoodRounds(scheduleId),
      body: {
        'title': title,
        'note': ?note,
        'duration_minutes': ?durationMinutes,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ส่ง/แก้ออเดอร์ของตัวเอง — items = [{name, qty}], skipped = รอบนี้ไม่สั่ง
  Future<Map<String, dynamic>> saveMyFoodOrder(
    int scheduleId,
    int roundId, {
    List<Map<String, dynamic>> items = const [],
    bool skipped = false,
  }) async {
    final response = await api.put(
      ApiEndpoints.chatFoodMyOrder(scheduleId, roundId),
      body: {'items': items, 'skipped': skipped},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> withdrawMyFoodOrder(
    int scheduleId,
    int roundId,
  ) async {
    final response = await api.delete(
      ApiEndpoints.chatFoodMyOrder(scheduleId, roundId),
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// สตาฟจดออเดอร์แทนคนที่ไม่ได้ใช้แอป
  Future<Map<String, dynamic>> addFoodOrderOnBehalf(
    int scheduleId,
    int roundId, {
    required String name,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await api.post(
      ApiEndpoints.chatFoodOrders(scheduleId, roundId),
      body: {'name': name, 'items': items},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> deleteFoodOrder(
    int scheduleId,
    int roundId,
    int orderId,
  ) async {
    final response = await api.delete(
      ApiEndpoints.chatFoodOrder(scheduleId, roundId, orderId),
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> setChatFoodRoundClosed(
    int scheduleId,
    int roundId, {
    required bool closed,
  }) async {
    final response = await api.post(
      closed
          ? ApiEndpoints.chatFoodClose(scheduleId, roundId)
          : ApiEndpoints.chatFoodReopen(scheduleId, roundId),
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// หารบิล: ทีมงานใส่ราคาต่อเมนู + พร้อมเพย์ (notify = ส่งยอดให้ทุกคน)
  Future<Map<String, dynamic>> billChatFoodRound(
    int scheduleId,
    int roundId, {
    required List<Map<String, dynamic>> prices,
    String? promptPayId,
    String? payeeName,
    bool notify = false,
  }) async {
    final response = await api.put(
      '${ApiEndpoints.chatFoodRounds(scheduleId)}/$roundId/bill',
      body: {
        'prices': prices,
        'promptpay_id': ?promptPayId,
        'payee_name': ?payeeName,
        'notify': notify,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// แพ้อาหาร/ฮาลาลของคนในรอบ (เฉพาะทีมงาน)
  Future<List<Map<String, dynamic>>> loadFoodDietary(
    int scheduleId,
    int roundId,
  ) async {
    final response = await api.get(
      '${ApiEndpoints.chatFoodRounds(scheduleId)}/$roundId/dietary',
    );
    final data = Map<String, dynamic>.from(api.data(response) as Map);
    return (data['alerts'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// ลูกค้าแจ้งว่าโอนค่าอาหารแล้ว (claimed=false = ถอนการแจ้ง)
  Future<Map<String, dynamic>> claimFoodPaid(
    int scheduleId,
    int roundId, {
    bool claimed = true,
  }) async {
    final response = await api.post(
      '${ApiEndpoints.chatFoodMyOrder(scheduleId, roundId)}/paid',
      body: {'claimed': claimed},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ทีมงานยืนยันว่าได้รับเงินของออเดอร์นี้แล้ว (หรือยกเลิก)
  Future<Map<String, dynamic>> setFoodOrderPaid(
    int scheduleId,
    int roundId,
    int orderId, {
    required bool paid,
  }) async {
    final response = await api.post(
      '${ApiEndpoints.chatFoodOrder(scheduleId, roundId, orderId)}/paid',
      body: {'paid': paid},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  // ── เก็บเงินหน้างาน ────────────────────────────────────────────────────
  // ทุกตัวคืน {message_id, collection} ยกเว้น openChatCollection ที่คืนข้อความใหม่

  /// รายชื่อผู้เดินทางของรอบ (ทีมงาน) — ไว้เลือกว่าเก็บใคร
  Future<List<Map<String, dynamic>>> loadChatRoster(int scheduleId) async {
    final response = await api.get(ApiEndpoints.chatRoster(scheduleId));
    final data = Map<String, dynamic>.from(api.data(response) as Map);
    return (data['passengers'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> openChatCollection(
    int scheduleId, {
    required String title,
    required double amount,
    String? note,
    List<int>? passengerIds,
    String? promptPayId,
    String? payeeName,
  }) async {
    final response = await api.post(
      ApiEndpoints.chatCollections(scheduleId),
      body: {
        'title': title,
        'amount': amount,
        'note': ?note,
        'passenger_ids': ?passengerIds,
        'promptpay_id': ?promptPayId,
        'payee_name': ?payeeName,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> setChatCollectionPayers(
    int scheduleId,
    int collectionId,
    List<int> passengerIds,
  ) async {
    final response = await api.put(
      '${ApiEndpoints.chatCollections(scheduleId)}/$collectionId/payers',
      body: {'passenger_ids': passengerIds},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ลูกทริปแจ้งว่าโอนแล้ว (claimed=false = ถอน)
  Future<Map<String, dynamic>> claimChatCollection(
    int scheduleId,
    int collectionId, {
    bool claimed = true,
  }) async {
    final response = await api.post(
      '${ApiEndpoints.chatCollections(scheduleId)}/$collectionId/claim',
      body: {'claimed': claimed},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> setChatCollectionPaid(
    int scheduleId,
    int collectionId, {
    required List<int> passengerIds,
    required bool paid,
  }) async {
    final response = await api.post(
      '${ApiEndpoints.chatCollections(scheduleId)}/$collectionId/paid',
      body: {'passenger_ids': passengerIds, 'paid': paid},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> setChatCollectionClosed(
    int scheduleId,
    int collectionId, {
    required bool closed,
  }) async {
    final response = await api.post(
      '${ApiEndpoints.chatCollections(scheduleId)}/$collectionId/${closed ? 'close' : 'reopen'}',
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  // ── ของหาย / ลืมของในทริป ──────────────────────────────────────────────

  /// ของในทุกทริปที่ฉันไป ([scheduleId] null) หรือเฉพาะรอบ — คืน {items, can_manage?}
  Future<Map<String, dynamic>> loadLostItems({int? scheduleId}) async {
    final response = await api.get(
      scheduleId == null
          ? ApiEndpoints.lostItems
          : ApiEndpoints.scheduleLostItems(scheduleId),
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ทีมงานโพสต์ของที่เจอ (รูปไม่บังคับ)
  Future<Map<String, dynamic>> postLostItem(
    int scheduleId, {
    required String description,
    String? photoPath,
  }) async {
    final response = await api.postMultipart(
      ApiEndpoints.scheduleLostItems(scheduleId),
      fields: {'description': description},
      files: {'photo': ?photoPath},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> claimLostItem(int itemId, {String? note}) async {
    final response = await api.post(
      '${ApiEndpoints.lostItem(itemId)}/claim',
      body: {'note': ?note},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> unclaimLostItem(int itemId) async {
    final response = await api.delete('${ApiEndpoints.lostItem(itemId)}/claim');
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> setLostItemReturned(
    int itemId, {
    required bool returned,
    String? note,
  }) async {
    final response = await api.post(
      '${ApiEndpoints.lostItem(itemId)}/returned',
      body: {'returned': returned, 'note': ?note},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<void> deleteLostItem(int itemId) async {
    await api.delete(ApiEndpoints.lostItem(itemId));
  }

  // ── ห้องพักของรอบ ──────────────────────────────────────────────────────
  // ทุกตัวคืน payload หน้าห้องพักทั้งก้อน {stays, rooms, my_room_ids, unassigned?}

  Future<Map<String, dynamic>> loadScheduleRooms(int scheduleId) async {
    final response = await api.get(ApiEndpoints.scheduleRooms(scheduleId));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> createScheduleRoom(
    int scheduleId, {
    required String name,
    String? stayLabel,
    String? note,
    List<int> passengerIds = const [],
  }) async {
    final response = await api.post(
      ApiEndpoints.scheduleRooms(scheduleId),
      body: {
        'name': name,
        'stay_label': ?stayLabel,
        'note': ?note,
        'passenger_ids': passengerIds,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> updateScheduleRoom(
    int scheduleId,
    int roomId, {
    required String name,
    String? note,
  }) async {
    final response = await api.put(
      '${ApiEndpoints.scheduleRooms(scheduleId)}/$roomId',
      body: {'name': name, 'note': ?note},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> deleteScheduleRoom(int scheduleId, int roomId) async {
    final response = await api.delete(
      '${ApiEndpoints.scheduleRooms(scheduleId)}/$roomId',
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> setScheduleRoomGuests(
    int scheduleId,
    int roomId,
    List<int> passengerIds,
  ) async {
    final response = await api.put(
      '${ApiEndpoints.scheduleRooms(scheduleId)}/$roomId/guests',
      body: {'passenger_ids': passengerIds},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> autoAssignScheduleRooms(
    int scheduleId, {
    required int roomSize,
    String? stayLabel,
    String? prefix,
  }) async {
    final response = await api.post(
      '${ApiEndpoints.scheduleRooms(scheduleId)}/auto',
      body: {
        'room_size': roomSize,
        'stay_label': ?stayLabel,
        'prefix': ?prefix,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> announceScheduleRooms(
    int scheduleId, {
    String? stayLabel,
  }) async {
    final response = await api.post(
      '${ApiEndpoints.scheduleRooms(scheduleId)}/announce',
      body: {'stay_label': ?stayLabel},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  // ── จุดพัก (นัดเวลากลับรถ + เช็คชื่อขึ้นรถ) / ขอแวะห้องน้ำ ──────────────

  /// ทีมงานประกาศพัก — คืนข้อความการ์ดที่เพิ่งลงห้อง
  /// ส่ง [minutes] = พักรถตอนนี้, หรือ [meetAt] = นัดรวมพลล่วงหน้า
  Future<Map<String, dynamic>> openChatRestStop(
    int scheduleId, {
    int? minutes,
    DateTime? meetAt,
    String? place,
  }) async {
    final response = await api.post(
      ApiEndpoints.chatRestStops(scheduleId),
      body: {
        'minutes': ?minutes,
        'meet_at': ?meetAt?.toUtc().toIso8601String(),
        'place': ?place,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// การ์ดล่าสุด {message_id, rest_stop} — ทีมงานได้เบอร์โทรมาด้วย
  Future<Map<String, dynamic>> getChatRestStop(int scheduleId, int stopId) async {
    final response = await api.get(ApiEndpoints.chatRestStop(scheduleId, stopId));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> boardChatRestStop(
    int scheduleId,
    int stopId, {
    required List<int> passengerIds,
    required bool boarded,
  }) async {
    final response = await api.post(
      '${ApiEndpoints.chatRestStop(scheduleId, stopId)}/board',
      body: {'passenger_ids': passengerIds, 'boarded': boarded},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> extendChatRestStop(
    int scheduleId,
    int stopId,
    int minutes,
  ) async {
    final response = await api.post(
      '${ApiEndpoints.chatRestStop(scheduleId, stopId)}/extend',
      body: {'minutes': minutes},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> departChatRestStop(int scheduleId, int stopId) async {
    final response = await api.post(
      '${ApiEndpoints.chatRestStop(scheduleId, stopId)}/depart',
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ขอแวะห้องน้ำแบบไม่บอกชื่อ — คืน {pending, urgent, mine}
  /// คำขอแบบไม่บอกชื่อ — [kind]: toilet / too_cold / too_hot / too_fast / music_down
  /// คืน {pending, urgent, kinds, mine, mine_kinds}
  Future<Map<String, dynamic>> requestChatStop(
    int scheduleId, {
    bool urgent = false,
    String kind = 'toilet',
  }) async {
    final response = await api.post(
      ApiEndpoints.chatStopRequests(scheduleId),
      body: {'urgent': urgent, 'kind': kind},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> cancelChatStopRequest(
    int scheduleId, {
    String kind = 'toilet',
  }) async {
    final response = await api.delete(
      '${ApiEndpoints.chatStopRequests(scheduleId)}/mine',
      body: {'kind': kind},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// ทีมงานรับทราบ — ห้องน้ำ: minutes 0 = แวะเลย, null = เร็ว ๆ นี้
  Future<Map<String, dynamic>> acknowledgeChatStopRequests(
    int scheduleId, {
    int? minutes,
    String kind = 'toilet',
  }) async {
    final response = await api.post(
      '${ApiEndpoints.chatStopRequests(scheduleId)}/ack',
      body: {'minutes': ?minutes, 'kind': kind},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  // ── ขอยา / ของจำเป็นจากสตาฟ ───────────────────────────────────────────

  /// ทีมงาน: คิวทั้งรอบ · ลูกทริป: คำขอของฉัน + คนที่ขอแทนได้
  /// คืน {can_manage, pending, requests, passengers}
  Future<Map<String, dynamic>> loadChatSupplies(int scheduleId) async {
    final response = await api.get('schedules/$scheduleId/chat/supplies');
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<void> requestChatSupply(
    int scheduleId, {
    required String item,
    int? passengerId,
    String? note,
  }) async {
    await api.post(
      'schedules/$scheduleId/chat/supplies',
      body: {'item': item, 'passenger_id': ?passengerId, 'note': ?note},
    );
  }

  Future<void> cancelChatSupply(int scheduleId, int requestId) async {
    await api.delete('schedules/$scheduleId/chat/supplies/$requestId');
  }

  Future<void> deliverChatSupply(int scheduleId, int requestId) async {
    await api.post('schedules/$scheduleId/chat/supplies/$requestId/deliver');
  }

  Future<void> declineChatSupply(
    int scheduleId,
    int requestId, {
    String? note,
  }) async {
    await api.post(
      'schedules/$scheduleId/chat/supplies/$requestId/decline',
      body: {'note': ?note},
    );
  }

  /// Subscribe to the auxiliary chat signals (read receipts, typing, reactions,
  /// pinned changes) on the same channel. Returns a single combined disposer.
  Future<VoidCallback> subscribeChatSignals(
    int scheduleId, {
    RealtimeEventHandler? onRead,
    RealtimeEventHandler? onTyping,
    RealtimeEventHandler? onJoined,
    RealtimeEventHandler? onReaction,
    RealtimeEventHandler? onPinned,
    RealtimeEventHandler? onUpdated,
    RealtimeEventHandler? onPoll,
    RealtimeEventHandler? onFood,
    RealtimeEventHandler? onRestStop,
    RealtimeEventHandler? onStopRequests,
    RealtimeEventHandler? onCollection,
    RealtimeEventHandler? onLostItem,
    RealtimeEventHandler? onSupplies,
  }) async {
    final channel = 'private-chat.schedule.$scheduleId';
    final disposers = <VoidCallback>[];

    Future<void> bind(String event, RealtimeEventHandler? h) async {
      if (h == null) return;
      disposers.add(
        await realtime.subscribe(channel: channel, event: event, handler: h),
      );
    }

    await bind('chat.read', onRead);
    await bind('chat.typing', onTyping);
    await bind('chat.joined', onJoined);
    await bind('chat.reaction', onReaction);
    await bind('chat.pinned', onPinned);
    await bind('chat.message.updated', onUpdated);
    await bind('chat.poll', onPoll);
    await bind('chat.food', onFood);
    await bind('chat.rest_stop', onRestStop);
    await bind('chat.stop_requests', onStopRequests);
    await bind('chat.collection', onCollection);
    await bind('chat.lost_item', onLostItem);
    await bind('chat.supplies', onSupplies);

    return () {
      for (final d in disposers) {
        d();
      }
    };
  }

  // ── Group trip invite (host-pays-all) ────────────────────────────────────

  /// Live updates for a group plan room. Returns a disposer.
  Future<VoidCallback> subscribeGroup(
    String code,
    RealtimeEventHandler handler,
  ) {
    return realtime.subscribe(
      channel: 'private-group.$code',
      event: 'group.updated',
      handler: handler,
    );
  }

  Future<Map<String, dynamic>> createGroupPlan(
    int scheduleId,
    int seatCount,
    String? name,
  ) async {
    final response = await api.post(
      ApiEndpoints.scheduleGroupPlans(scheduleId),
      body: {'seat_count': seatCount, 'name': ?name},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> fetchGroupPlan(String code) async {
    final response = await api.get(ApiEndpoints.groupPlan(code));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<List<dynamic>> myGroupPlans() async {
    final response = await api.get(ApiEndpoints.groupPlansMine);
    return List<dynamic>.from(api.data(response) ?? []);
  }

  Future<Map<String, dynamic>> joinGroupPlan(String code) async {
    final response = await api.post(ApiEndpoints.groupPlanJoin(code));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> claimGroupSeat(
    String code,
    Map<String, dynamic> body,
  ) async {
    final response = await api.post(
      ApiEndpoints.groupPlanClaimSeat(code),
      body: body,
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> releaseGroupSeat(String code) async {
    final response = await api.post(ApiEndpoints.groupPlanReleaseSeat(code));
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<void> leaveGroupPlan(String code) async {
    await api.post(ApiEndpoints.groupPlanLeave(code));
  }

  Future<void> cancelGroupPlan(String code) async {
    await api.delete(ApiEndpoints.groupPlan(code));
  }

  Future<Map<String, dynamic>> checkoutGroupPlan(
    String code, {
    int? pickupPointId,
    String? pickupRegion,
  }) async {
    final response = await api.post(
      ApiEndpoints.groupPlanCheckout(code),
      body: {'pickup_point_id': ?pickupPointId, 'pickup_region': ?pickupRegion},
    );
    await loadAccountData();
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> paymentStatus(String ref) async {
    final response = await api.get('payments/$ref');
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> confirmPayment({
    required String bookingRef,
    required num amount,
    String paymentType = 'full',
    String paymentMethod = 'promptpay',
    String? transferDate,
    String? transferTime,
    // จำนวนงวดที่หน้าจอโชว์ไว้ — ต้องส่งไปด้วย ไม่งั้นหลังบ้านใช้จำนวนงวดของรอบ
    // แล้วยอดงวดแรกที่เรียกเก็บจะไม่ตรงกับที่ลูกค้าเห็นบน QR
    int? installmentCount,
    required String slipImagePath,
  }) async {
    final response = await api.postMultipart(
      'payments/charge',
      fields: {
        'booking_ref': bookingRef,
        'amount': amount,
        'payment_type': paymentType,
        'payment_method': paymentMethod,
        'transfer_date': ?transferDate,
        'transfer_time': ?transferTime,
        if (paymentType == 'installment' && installmentCount != null)
          'installment_count': installmentCount,
      },
      files: {'slip_image': slipImagePath},
    );
    await loadAccountData();
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Pay the remaining balance for a deposit booking.
  Future<Map<String, dynamic>> chargeBalance({
    required String bookingRef,
    String paymentMethod = 'promptpay',
    String? transferDate,
    String? transferTime,
    required String slipImagePath,
  }) async {
    final response = await api.postMultipart(
      ApiEndpoints.paymentsChargeBalance,
      fields: {
        'booking_ref': bookingRef,
        'payment_method': paymentMethod,
        'transfer_date': ?transferDate,
        'transfer_time': ?transferTime,
      },
      files: {'slip_image': slipImagePath},
    );
    await loadAccountData();
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Pay a specific installment for an installment booking.
  Future<Map<String, dynamic>> chargeInstallment({
    required String bookingRef,
    required int installmentNo,
    String paymentMethod = 'promptpay',
    String? transferDate,
    String? transferTime,
    required String slipImagePath,
  }) async {
    final response = await api.postMultipart(
      ApiEndpoints.paymentsChargeInstallment,
      fields: {
        'booking_ref': bookingRef,
        'installment_no': '$installmentNo',
        'payment_method': paymentMethod,
        'transfer_date': ?transferDate,
        'transfer_time': ?transferTime,
      },
      files: {'slip_image': slipImagePath},
    );
    await loadAccountData();
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  // ── Beam Checkout ─────────────────────────────────────────────────────────

  /// ออกใบชำระเงินหนึ่งใบ แล้วได้ QR (หรือลิงก์เด้งไปแอปธนาคาร) กลับมา
  ///
  /// ยอดคำนวณที่เซิร์ฟเวอร์ทั้งหมด แอปส่งไปแค่ "จ่ายเพื่ออะไร" — ตรงกันข้ามกับ
  /// confirmPayment() ที่ยังต้องส่ง amount ไปให้หลังบ้านเทียบกับสลิป
  Future<Map<String, dynamic>> createBeamCharge({
    required String bookingRef,
    required String purpose,
    String paymentMethodType = 'QR_PROMPT_PAY',
    int? installmentCount,
    int? shareId,
    int? installmentId,
    String? deviceType,
  }) async {
    final response = await api.post(
      ApiEndpoints.beamCharge,
      body: {
        'booking_ref': bookingRef,
        'purpose': purpose,
        'payment_method_type': paymentMethodType,
        'installment_count': ?installmentCount,
        'share_id': ?shareId,
        'installment_id': ?installmentId,
        'device_type': ?deviceType,
      },
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// สถานะของใบชำระเงิน — ใช้ poll เผื่อ websocket หลุด
  /// สถานะของใบชำระเงินใบหนึ่ง
  ///
  /// [sync] = "ลูกค้าบอกว่าจ่ายไปแล้วและกำลังนั่งดูหน้าจอรออยู่" ให้เซิร์ฟเวอร์ถาม Beam
  /// ตรงๆ แทนที่จะรอ webhook — ฝั่งเซิร์ฟเวอร์คุมจังหวะไว้ที่ 1 ครั้ง/5 วินาที/ใบแล้ว
  Future<Map<String, dynamic>> beamPaymentStatus(
    int paymentId, {
    bool sync = false,
  }) async {
    final response = await api.get(
      ApiEndpoints.beamPayment(paymentId),
      query: sync ? {'sync': 1} : null,
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> validatePromotion(
    String code,
    int tripId,
  ) async {
    final response = await api.post(
      'promotions/validate',
      body: {'code': code, 'trip_id': tripId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> markAllNotificationsRead() async {
    await api.put(ApiEndpoints.notificationsReadAll);
    await loadNotifications();
  }

  Future<void> loadNotifications({int perPage = 50}) async {
    if (!isLoggedIn) return;
    final response = await api.get(
      'notifications',
      query: {'per_page': perPage},
    );
    notifications = List<dynamic>.from(api.data(response) ?? []);
    _syncAppIconBadge();
    notifyListeners();
  }

  Future<void> markNotificationRead(int id) async {
    await api.put('notifications/$id/read');
    notifications = notifications.map((item) {
      final notification = Map<String, dynamic>.from(_asMap(item));
      if (notification['id']?.toString() == id.toString()) {
        notification['is_read'] = true;
        notification['read_at'] = DateTime.now().toIso8601String();
      }
      return notification;
    }).toList();
    _syncAppIconBadge();
    notifyListeners();
  }

  Future<void> deleteNotification(int id) async {
    await api.delete('notifications/$id');
    notifications = notifications
        .where((item) => _asMap(item)['id']?.toString() != id.toString())
        .toList();
    _syncAppIconBadge();
    notifyListeners();
  }

  Future<void> clearAllNotifications() async {
    await api.delete(ApiEndpoints.notifications);
    notifications = [];
    _syncAppIconBadge();
    notifyListeners();
  }

  /// Redeems a reward for points and returns the issued coupon details
  /// ({coupon_code, reward, expires_at, points_remaining}).
  Future<Map<String, dynamic>> redeemReward(int rewardId) async {
    final response = await api.post(
      ApiEndpoints.loyaltyRedeem,
      body: {'reward_id': rewardId},
    );
    await loadAccountData();
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  /// ลิงก์การ์ดนับถอยหลังของการจองหนึ่งใบ สำหรับแนบไปกับโพสต์ที่แชร์
  ///
  /// ปลายทางเป็นหน้าสาธารณะที่มีภาพ OG เป็นการ์ดใบเดียวกัน — ต่างจากลิงก์ชวน
  /// เพื่อนเปล่า ๆ ตรงที่พอโพสต์ลง Facebook/LINE แล้วพรีวิวขึ้นเป็นรูปการ์ด
  Future<String?> fetchBookingStoryLink(String bookingRef) async {
    final response = await api.post(ApiEndpoints.bookingStoryLink(bookingRef));
    final data = Map<String, dynamic>.from(api.data(response) ?? {});
    final url = data['url']?.toString();

    return (url == null || url.isEmpty) ? null : url;
  }

  /// Loads the user's referral snapshot (code, share copy, invited friends).
  /// Fetched on demand when the referral screen opens.
  Future<Map<String, dynamic>> fetchReferral() async {
    final response = await api.get(ApiEndpoints.referral);
    referral = Map<String, dynamic>.from(api.data(response) ?? {});
    notifyListeners();
    return referral!;
  }

  Future<void> submitReview({
    required int bookingId,
    required int rating,
    required String comment,
    List<String> images = const [],
    List<String> videos = const [],
    int? ratingGuide,
    int? ratingVehicle,
    int? ratingFood,
    int? ratingValue,
    int? passengerId,
  }) async {
    await api.post(
      'reviews',
      body: {
        'booking_id': bookingId,
        'rating': rating,
        'comment': comment,
        if (images.isNotEmpty) 'images': images,
        if (videos.isNotEmpty) 'videos': videos,
        'rating_guide': ?ratingGuide,
        'rating_vehicle': ?ratingVehicle,
        'rating_food': ?ratingFood,
        'rating_value': ?ratingValue,
        // แอดมินรีวิวแทนลูกค้า — ผู้เดินทางที่รีวิวนี้จะขึ้นเป็นชื่อ
        'passenger_id': ?passengerId,
      },
    );
    // รีวิวบันทึกแล้วตั้งแต่ POST ผ่าน — รีโหลดพัง (เช่น สัญญาณหลุด) ต้องไม่
    // กลายเป็น "ส่งไม่สำเร็จ" ไม่งั้นลูกค้ากดส่งซ้ำแล้วเจอ "รีวิวไปแล้ว"
    try {
      await loadPublicData();
      await loadMyReviews();
      // รีโหลดรายการจองด้วย เพื่อให้ can_review อัปเดต (ปุ่มรีวิวหายหลังรีวิวแล้ว)
      await loadAccountData();
    } catch (_) {}
    await AnalyticsService.instance.logReviewSubmitted(bookingId, rating);
    if (rating >= 4) {
      unawaited(RatingPromptService.instance.maybeRequest());
    }
  }

  Future<void> loadMyReviews() async {
    if (!isLoggedIn) return;
    final response = await api.get(ApiEndpoints.reviewsMy);
    myReviews = List<dynamic>.from(api.data(response) ?? []);
    notifyListeners();
  }

  Future<void> sendContact(Map<String, dynamic> payload) async {
    await api.post(ApiEndpoints.contacts, body: payload);
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

ThemeMode _themeModeFromStorage(String? value) {
  return switch (value) {
    'dark' => ThemeMode.dark,
    _ => ThemeMode.light,
  };
}

Locale _localeFromStorage(String? value) {
  return switch (value) {
    'en' => const Locale('en'),
    _ => const Locale('th'),
  };
}
