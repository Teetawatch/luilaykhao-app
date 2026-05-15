import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/api_endpoints.dart';
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
  VoidCallback? _userChannelDisposer;
  VoidCallback? _onSessionExpired;
  bool _handlingUnauthorized = false;
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

  bool get canUseStaffCheckIn {
    final roles = roleNames;
    return roles.contains('staff') ||
        roles.contains('operator') ||
        roles.contains('admin');
  }

  void setOnSessionExpired(VoidCallback callback) {
    _onSessionExpired = callback;
  }

  Future<void> _handleUnauthorized() async {
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
    await PushNotificationService.instance.initialize(
      onRefreshRequested: () {
        if (isLoggedIn) loadAccountData();
      },
    );
    try {
      await Future.wait([loadPublicData(), if (isLoggedIn) refreshMe()]);
      if (isLoggedIn) {
        await loadAccountData();
        await loadActiveSeatLocks();
        startActiveSeatLockPolling();
        await PushNotificationService.instance.syncToken(api);
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
    _userChannelDisposer?.call();
    _userChannelDisposer = await realtime.subscribe(
      channel: 'private-user.$userId',
      event: 'PaymentConfirmed',
      handler: (_) => loadAccountData(),
    );
  }

  Future<void> _unbindUserChannel() async {
    _userChannelDisposer?.call();
    _userChannelDisposer = null;
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
    final results = await Future.wait([
      api.get(ApiEndpoints.trips, query: {'per_page': 30, 'search': search, 'type': type}),
      api.get(ApiEndpoints.tripsFeatured),
      api.get(ApiEndpoints.categories),
      api.get(ApiEndpoints.reviews, query: {'per_page': 8}),
      api.get(ApiEndpoints.stats),
      api.get(ApiEndpoints.promotionsActive),
    ]);
    trips = List<dynamic>.from(api.data(results[0]) ?? []);
    featuredTrips = List<dynamic>.from(api.data(results[1]) ?? []);
    categories = List<dynamic>.from(api.data(results[2]) ?? []);
    reviews = List<dynamic>.from(api.data(results[3]) ?? []);
    stats = Map<String, dynamic>.from(api.data(results[4]) ?? {});
    promotions = List<dynamic>.from(api.data(results[5]) ?? []);
    final cache = OfflineCache.instance;
    cache.writePublic('trips', trips);
    cache.writePublic('featured', featuredTrips);
    cache.writePublic('categories', categories);
    cache.writePublic('reviews', reviews);
    cache.writePublic('stats', stats);
    cache.writePublic('promotions', promotions);
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
      () =>
          api.post(ApiEndpoints.authLogin, body: {'email': email, 'password': password}),
    );
    await AnalyticsService.instance.logLogin('password');
  }

  Future<void> register(Map<String, dynamic> payload) async {
    await _auth(() => api.post(ApiEndpoints.authRegister, body: payload));
    await AnalyticsService.instance.logSignUp('password');
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
    final results = await Future.wait([
      api.get(ApiEndpoints.bookings),
      api.get(ApiEndpoints.notifications, query: {'per_page': 20}),
      api.get(ApiEndpoints.loyaltyAccount),
      api.get(ApiEndpoints.loyaltyRewards),
      api.get(ApiEndpoints.loyaltyCoupons),
      api.get(ApiEndpoints.reviewsMy),
    ]);
    bookings = List<dynamic>.from(api.data(results[0]) ?? []);
    notifications = List<dynamic>.from(api.data(results[1]) ?? []);
    loyalty = Map<String, dynamic>.from(api.data(results[2]) ?? {});
    rewards = List<dynamic>.from(api.data(results[3]) ?? []);
    coupons = List<dynamic>.from(api.data(results[4]) ?? []);
    myReviews = List<dynamic>.from(api.data(results[5]) ?? []);
    final cache = OfflineCache.instance;
    if (user != null) cache.writeAccount('user', user);
    cache.writeAccount('bookings', bookings);
    cache.writeAccount('notifications', notifications);
    cache.writeAccount('loyalty', loyalty);
    cache.writeAccount('rewards', rewards);
    cache.writeAccount('coupons', coupons);
    cache.writeAccount('myReviews', myReviews);
    notifyListeners();
  }

  Future<Map<String, dynamic>> booking(String ref) async {
    final response = await api.get('bookings/$ref');
    return Map<String, dynamic>.from(api.data(response) as Map);
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
    notifyListeners();
  }

  Future<void> deleteNotification(int id) async {
    await api.delete('notifications/$id');
    notifications = notifications
        .where((item) => _asMap(item)['id']?.toString() != id.toString())
        .toList();
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
  }) async {
    await api.post(
      'reviews',
      body: {'booking_id': bookingId, 'rating': rating, 'comment': comment},
    );
    await loadPublicData();
    await loadMyReviews();
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
