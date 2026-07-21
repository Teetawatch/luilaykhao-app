import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/api_endpoints.dart';
import '../models/sos_alert.dart';
import '../services/analytics_service.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/notification_navigator.dart';
import '../services/offline_cache.dart';
import '../services/push_notification_service.dart';
import '../services/rating_prompt_service.dart';
import '../services/realtime_service.dart';
import '../services/secure_storage.dart';
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
  List<dynamic> categories = [];
  List<dynamic> bookings = [];
  // True once account data (incl. bookings) has been loaded at least once —
  // from the network or a cache restore. Lets screens show a skeleton on the
  // very first load instead of flashing an empty state.
  bool accountLoaded = false;
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

  Future<void> _handleUnauthorized() async {
    // While deleting the account the token is intentionally invalidated
    // server-side; ignore the resulting 401s so the session-expired handler
    // does not tear down the navigation stack mid-flow.
    if (_deletingAccount) return;
    if (_handlingUnauthorized) return;
    if (!isLoggedIn) return;
    _handlingUnauthorized = true;
    try {
      await AnalyticsService.instance.log('session_expired_auto_logout');
      await logout();
      _onSessionExpired?.call();
    } finally {
      _handlingUnauthorized = false;
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
    unawaited(ConnectivityService.instance.initialize());
    unawaited(
      VersionGateService.instance.check(api).then((result) {
        _versionGate = result;
        notifyListeners();
      }),
    );
    await OfflineCache.instance.load();
    _hydrateFromCache();
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
    categories = List<dynamic>.from(
      cache.readPublic<List>('categories') ?? const [],
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
    notifyListeners();
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

  Future<Map<String, dynamic>> seats(int scheduleId) async {
    final response = await api.get('schedules/$scheduleId/seats');
    return Map<String, dynamic>.from(api.data(response) ?? {});
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
  }) async {
    final response = await api.post(
      'schedules/$scheduleId/seats/lock',
      body: {
        'seat_ids': seatIds,
        'pickup_point_id': ?pickupPointId,
        if (pickupRegion != null && pickupRegion.isNotEmpty)
          'pickup_region': pickupRegion,
      },
    );
    final result = Map<String, dynamic>.from(api.data(response) ?? {});
    await loadActiveSeatLocks(silent: true);
    return result;
  }

  Future<void> unlockSeats(int scheduleId, List<String> seatIds) async {
    await api.delete(
      'schedules/$scheduleId/seats/lock',
      body: {'seat_ids': seatIds},
    );
    await loadActiveSeatLocks(silent: true);
  }

  Future<void> cancelActiveSeatLock(
    int scheduleId, {
    List<String> seatIds = const [],
  }) async {
    await api.delete(
      'seat-locks/$scheduleId',
      body: {if (seatIds.isNotEmpty) 'seat_ids': seatIds},
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
    await OfflineCache.instance.clearAccount();
    await _unbindUserChannel();
    await AnalyticsService.instance.setUser(id: null);
    stopActiveSeatLockPolling();
    bookings = [];
    notifications = [];
    activeSeatLocks = [];
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
    final results = await Future.wait([
      api.get(ApiEndpoints.bookings),
      safe(api.get(ApiEndpoints.notifications, query: {'per_page': 20})),
      safe(api.get(ApiEndpoints.loyaltyAccount)),
      safe(api.get(ApiEndpoints.loyaltyRewards)),
      safe(api.get(ApiEndpoints.loyaltyCoupons)),
      safe(api.get(ApiEndpoints.reviewsMy)),
      safe(api.get(ApiEndpoints.chatMyConversations)),
      safe(api.get(ApiEndpoints.supportUnreadCount)),
      if (hasStaff) safe(api.get(ApiEndpoints.staffSchedulesMy)),
    ]);

    bookings = List<dynamic>.from(api.data(results[0]) ?? []);
    if (results[1] != null) {
      notifications = List<dynamic>.from(api.data(results[1]) ?? []);
    }
    if (results[2] != null) {
      loyalty = Map<String, dynamic>.from(api.data(results[2]) ?? {});
    }
    if (results[3] != null) {
      rewards = List<dynamic>.from(api.data(results[3]) ?? []);
    }
    if (results[4] != null) {
      coupons = List<dynamic>.from(api.data(results[4]) ?? []);
    }
    if (results[5] != null) {
      myReviews = List<dynamic>.from(api.data(results[5]) ?? []);
    }
    if (results[6] != null) {
      chatConversations = List<dynamic>.from(api.data(results[6]) ?? []);
      chatUnreadTotal = chatConversations.fold<int>(0, (sum, c) {
        final n = int.tryParse('${(c as Map?)?['unread_count']}') ?? 0;
        return sum + n;
      });
    }
    if (results[7] != null) {
      final supportData = api.data(results[7]) as Map?;
      supportUnread = int.tryParse('${supportData?['count']}') ?? 0;
    }
    if (hasStaff && results.length > 8 && results[8] != null) {
      final staffData = api.data(results[8]) as Map?;
      staffSchedules = List<dynamic>.from(staffData?['schedules'] ?? []);
      staffSummary = Map<String, dynamic>.from(staffData?['summary'] ?? {});
    }

    final cache = OfflineCache.instance;
    if (user != null) cache.writeAccount('user', user);
    cache.writeAccount('bookings', bookings);
    cache.writeAccount('notifications', notifications);
    cache.writeAccount('loyalty', loyalty);
    cache.writeAccount('rewards', rewards);
    cache.writeAccount('coupons', coupons);
    cache.writeAccount('myReviews', myReviews);
    _syncAppIconBadge();
    accountLoaded = true;
    notifyListeners();
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
  }) async {
    final body = {
      'schedule_id': scheduleId,
      'latitude': ?latitude,
      'longitude': ?longitude,
      if (message != null && message.isNotEmpty) 'message': message,
    };

    // A photo can take longer to upload on a weak connection, so give multipart
    // attempts more headroom than a plain JSON trigger.
    final hasPhoto = photoPath != null && photoPath.isNotEmpty;
    final attemptTimeout = hasPhoto
        ? const Duration(seconds: 30)
        : const Duration(seconds: 15);
    const backoff = [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ];

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

  Future<void> resolveSos(int id) async {
    await api.post('sos/$id/resolve');
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
  confirmStaffCheckIn(String qrCode) async {
    final response = await api.post(
      'staff/check-in/confirm',
      body: {'qr_code': qrCode},
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

  /// Full passenger manifest for a schedule the staff is assigned to —
  /// contact name, callable phone, pickup point/map/notes per booking.
  /// Backed by the driver manifest endpoint, which grants staff access.
  Future<Map<String, dynamic>> loadStaffManifest(int scheduleId) async {
    final response = await api.get('driver/schedules/$scheduleId/manifest');
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
  Future<List<Map<String, dynamic>>> scheduleItinerary(int scheduleId) async {
    final response = await api.get(ApiEndpoints.scheduleItinerary(scheduleId));
    final data = Map<String, dynamic>.from(api.data(response) ?? {});
    final items = (data['items'] as List? ?? const []);
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
      },
    );
    await loadPublicData();
    await loadMyReviews();
    // รีโหลดรายการจองด้วย เพื่อให้ can_review อัปเดต (ปุ่มรีวิวหายหลังรีวิวแล้ว)
    await loadAccountData();
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
