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
  List<dynamic> categories = [];
  List<dynamic> bookings = [];
  List<dynamic> notifications = [];
  List<dynamic> reviews = [];
  List<dynamic> myReviews = [];
  List<dynamic> rewards = [];
  List<dynamic> coupons = [];
  List<dynamic> promotions = [];
  List<dynamic> activeSeatLocks = [];
  List<dynamic> staffSchedules = [];
  Map<String, dynamic> staffSummary = {};
  Map<String, dynamic>? loyalty;
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
    categories = List<dynamic>.from(
      cache.readPublic<List>('categories') ?? const [],
    );
    reviews = List<dynamic>.from(cache.readPublic<List>('reviews') ?? const []);
    promotions = List<dynamic>.from(
      cache.readPublic<List>('promotions') ?? const [],
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
      safe(api.get(
        ApiEndpoints.trips,
        query: {'per_page': 30, 'search': search, 'type': type},
      )),
      safe(api.get(ApiEndpoints.tripsFeatured)),
      safe(api.get(ApiEndpoints.categories)),
      safe(api.get(ApiEndpoints.reviews, query: {'per_page': 8})),
      safe(api.get(ApiEndpoints.stats)),
      safe(api.get(ApiEndpoints.promotionsActive)),
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
    notifyListeners();
  }

  Future<Map<String, dynamic>> trip(String slug) async {
    final response = await api.get('trips/$slug');
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<List<dynamic>> schedules(String slug) async {
    final response = await api.get('trips/$slug/schedules');
    return List<dynamic>.from(api.data(response) ?? []);
  }

  Future<List<dynamic>> tripReviews(int tripId) async {
    final response = await api.get(
      'reviews',
      query: {'trip_id': tripId, 'per_page': 10},
    );
    return List<dynamic>.from(api.data(response) ?? []);
  }

  Future<Map<String, dynamic>> seats(int scheduleId) async {
    final response = await api.get('schedules/$scheduleId/seats');
    return Map<String, dynamic>.from(api.data(response) ?? {});
  }

  Future<List<dynamic>> fetchActiveSeatLocks() async {
    final response = await api.get(ApiEndpoints.seatLocksActive);
    return List<dynamic>.from(api.data(response) ?? []);
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
    if (hasStaff && results.length > 6 && results[6] != null) {
      final staffData = api.data(results[6]) as Map?;
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

  Future<Map<String, dynamic>> lookupStaffCheckIn(String qrCode) async {
    final response = await api.post(
      'staff/check-in/lookup',
      body: {'qr_code': qrCode},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> confirmStaffCheckIn(String qrCode) async {
    final response = await api.post(
      'staff/check-in/confirm',
      body: {'qr_code': qrCode},
    );
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  /// Full passenger manifest for a schedule the staff is assigned to —
  /// contact name, callable phone, pickup point/map/notes per booking.
  /// Backed by the driver manifest endpoint, which grants staff access.
  Future<Map<String, dynamic>> loadStaffManifest(int scheduleId) async {
    final response = await api.get('driver/schedules/$scheduleId/manifest');
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
  }) async {
    final response = await api.post(
      ApiEndpoints.chatMessages(scheduleId),
      body: {'body': body, 'reply_to_id': ?replyToId},
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
    final response = await api.post(ApiEndpoints.chatPin(scheduleId, messageId));
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

  Future<void> markChatRead(int scheduleId) async {
    await api.post(ApiEndpoints.chatRead(scheduleId));
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

  /// Subscribe to the auxiliary chat signals (read receipts, typing, reactions,
  /// pinned changes) on the same channel. Returns a single combined disposer.
  Future<VoidCallback> subscribeChatSignals(
    int scheduleId, {
    RealtimeEventHandler? onRead,
    RealtimeEventHandler? onTyping,
    RealtimeEventHandler? onReaction,
    RealtimeEventHandler? onPinned,
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
    await bind('chat.reaction', onReaction);
    await bind('chat.pinned', onPinned);

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

  Future<void> redeemReward(int rewardId) async {
    await api.post(ApiEndpoints.loyaltyRedeem, body: {'reward_id': rewardId});
    await loadAccountData();
  }

  Future<void> submitReview({
    required int bookingId,
    required int rating,
    required String comment,
    List<String> images = const [],
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
