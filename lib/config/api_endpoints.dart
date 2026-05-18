/// Centralised path constants for backend API calls. Keep this in sync with
/// the Laravel routes defined under `/api/v1`.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const authLogin = 'auth/login';
  static const authRegister = 'auth/register';
  static const authLogout = 'auth/logout';
  static const authMe = 'auth/me';
  static const authProfile = 'auth/profile';
  static String authSocialRedirect(String provider) => 'auth/$provider/redirect';

  // Catalog
  static const trips = 'trips';
  static const tripsFeatured = 'trips/featured';
  static String trip(String slug) => 'trips/$slug';
  static String tripSchedules(String slug) => 'trips/$slug/schedules';
  static const categories = 'categories';
  static const stats = 'stats';

  // Reviews
  static const reviews = 'reviews';
  static const reviewsMy = 'reviews/my';

  // Promotions
  static const promotionsActive = 'promotions/active';
  static const promotionsValidate = 'promotions/validate';

  // Schedules / seats
  static String scheduleSeats(int scheduleId) => 'schedules/$scheduleId/seats';
  static String scheduleSeatLock(int scheduleId) =>
      'schedules/$scheduleId/seats/lock';
  static const seatLocksActive = 'seat-locks/active';
  static String seatLock(int scheduleId) => 'seat-locks/$scheduleId';

  // Bookings
  static const bookings = 'bookings';
  static const bookingsGuestLookup = 'bookings/guest-lookup';
  static String booking(String ref) => 'bookings/$ref';
  static String bookingCancel(String ref) => 'bookings/$ref/cancel';

  // Payments
  static const paymentsCharge = 'payments/charge';
  static const paymentsChargeBalance = 'payments/charge-balance';
  static const paymentsChargeInstallment = 'payments/charge-installment';
  static String paymentStatus(String ref) => 'payments/$ref';

  // Notifications
  static const notifications = 'notifications';
  static const notificationsReadAll = 'notifications/read-all';
  static String notificationRead(int id) => 'notifications/$id/read';
  static String notification(int id) => 'notifications/$id';
  static const notificationsPushToken = 'notifications/push-token';

  // Loyalty
  static const loyaltyAccount = 'loyalty/account';
  static const loyaltyRewards = 'loyalty/rewards';
  static const loyaltyCoupons = 'loyalty/coupons';
  static const loyaltyRedeem = 'loyalty/redeem';

  // Misc
  static const contacts = 'contacts';
  static const broadcastingAuth = 'broadcasting/auth';
  static const appVersion = 'app/version';

  // Staff
  static const staffCheckInLookup = 'staff/check-in/lookup';
  static const staffCheckInConfirm = 'staff/check-in/confirm';
}
