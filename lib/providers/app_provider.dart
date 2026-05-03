import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/push_notification_service.dart';

class AppProvider extends ChangeNotifier {
  static const _tokenKey = 'auth_token';
  static const _themeModeKey = 'theme_mode';

  final ApiClient api = ApiClient();

  ThemeMode _themeMode = ThemeMode.light;
  bool booting = true;
  bool busy = false;
  String? error;
  Map<String, dynamic>? user;

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
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString(_tokenKey);
    _themeMode = _themeModeFromStorage(prefs.getString(_themeModeKey));
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
      }
    } catch (e) {
      error = e.toString();
    } finally {
      booting = false;
      notifyListeners();
    }
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

  Future<void> loadPublicData({String? search}) async {
    final results = await Future.wait([
      api.get('trips', query: {'per_page': 30, 'search': search}),
      api.get('trips/featured'),
      api.get('categories'),
      api.get('reviews', query: {'per_page': 8}),
      api.get('stats'),
      api.get('promotions/active'),
    ]);
    trips = List<dynamic>.from(api.data(results[0]) ?? []);
    featuredTrips = List<dynamic>.from(api.data(results[1]) ?? []);
    categories = List<dynamic>.from(api.data(results[2]) ?? []);
    reviews = List<dynamic>.from(api.data(results[3]) ?? []);
    stats = Map<String, dynamic>.from(api.data(results[4]) ?? {});
    promotions = List<dynamic>.from(api.data(results[5]) ?? []);
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
    final response = await api.get('seat-locks/active');
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
    _activeSeatLockTimer = Timer.periodic(
      const Duration(seconds: 5),
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
        if (pickupPointId != null) 'pickup_point_id': pickupPointId,
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
          api.post('auth/login', body: {'email': email, 'password': password}),
    );
  }

  Future<void> register(Map<String, dynamic> payload) async {
    await _auth(() => api.post('auth/register', body: payload));
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await loadAccountData();
      await loadActiveSeatLocks();
      startActiveSeatLockPolling();
      await PushNotificationService.instance.syncToken(api);
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, api.token ?? '');
      await loadAccountData();
      await loadActiveSeatLocks();
      startActiveSeatLockPolling();
      await PushNotificationService.instance.syncToken(api);
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshMe() async {
    final response = await api.get('auth/me');
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
          ? await api.post('auth/profile', body: payload)
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
      if (isLoggedIn) await api.post('auth/logout');
    } catch (_) {
      // Keep local logout responsive even if token is already expired.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    api.token = null;
    user = null;
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
    super.dispose();
  }

  Future<void> loadAccountData() async {
    if (!isLoggedIn) return;
    final results = await Future.wait([
      api.get('bookings'),
      api.get('notifications', query: {'per_page': 20}),
      api.get('loyalty/account'),
      api.get('loyalty/rewards'),
      api.get('loyalty/coupons'),
    ]);
    bookings = List<dynamic>.from(api.data(results[0]) ?? []);
    notifications = List<dynamic>.from(api.data(results[1]) ?? []);
    loyalty = Map<String, dynamic>.from(api.data(results[2]) ?? {});
    rewards = List<dynamic>.from(api.data(results[3]) ?? []);
    coupons = List<dynamic>.from(api.data(results[4]) ?? []);
    notifyListeners();
  }

  Future<Map<String, dynamic>> booking(String ref) async {
    final response = await api.get('bookings/$ref');
    return Map<String, dynamic>.from(api.data(response) as Map);
  }

  Future<Map<String, dynamic>> createBooking(
    Map<String, dynamic> payload,
  ) async {
    final response = await api.post('bookings', body: payload);
    final booking = Map<String, dynamic>.from(api.data(response) as Map);
    await loadAccountData();
    await loadActiveSeatLocks(silent: true);
    return booking;
  }

  Future<void> cancelBooking(String ref, String reason) async {
    await api.post('bookings/$ref/cancel', body: {'reason': reason});
    await loadAccountData();
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
        if (transferDate != null) 'transfer_date': transferDate,
        if (transferTime != null) 'transfer_time': transferTime,
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
    await api.put('notifications/read-all');
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
    await api.post('loyalty/redeem', body: {'reward_id': rewardId});
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
  }

  Future<void> loadMyReviews() async {
    if (!isLoggedIn) return;
    final response = await api.get('reviews/my');
    myReviews = List<dynamic>.from(api.data(response) ?? []);
    notifyListeners();
  }

  Future<void> sendContact(Map<String, dynamic> payload) async {
    await api.post('contacts', body: payload);
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
