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
  static const authAccount = 'auth/account';
  static const authAppleNative = 'auth/apple/native';
  static String authSocialRedirect(String provider) =>
      'auth/$provider/redirect';

  // Catalog
  static const trips = 'trips';
  static const tripsFeatured = 'trips/featured';
  static String trip(String slug) => 'trips/$slug';
  static String tripSchedules(String slug) => 'trips/$slug/schedules';
  static const categories = 'categories';
  static const stats = 'stats';
  static const heroSlides = 'hero-slides';

  // Reviews
  static const reviews = 'reviews';
  static const reviewsMy = 'reviews/my';

  // Promotions
  static const promotionsActive = 'promotions/active';
  static const promotionsValidate = 'promotions/validate';

  // Chat (group chat per schedule)
  static String chatMessages(int scheduleId) =>
      'schedules/$scheduleId/chat/messages';
  static String chatMessage(int scheduleId, int messageId) =>
      'schedules/$scheduleId/chat/messages/$messageId';
  static String chatRead(int scheduleId) => 'schedules/$scheduleId/chat/read';
  static String chatUnreadCount(int scheduleId) =>
      'schedules/$scheduleId/chat/unread-count';
  static String chatRoom(int scheduleId) => 'schedules/$scheduleId/chat/room';
  static const chatMyConversations = 'chat/my-conversations';
  static String chatTyping(int scheduleId) =>
      'schedules/$scheduleId/chat/typing';
  static String chatPin(int scheduleId, int messageId) =>
      'schedules/$scheduleId/chat/messages/$messageId/pin';
  static String chatReact(int scheduleId, int messageId) =>
      'schedules/$scheduleId/chat/messages/$messageId/react';

  // Announcements (ประกาศจากผู้จัด ต่อรอบเดินทาง)
  static String announcements(int scheduleId) =>
      'schedules/$scheduleId/announcements';
  static String announcement(int scheduleId, int announcementId) =>
      'schedules/$scheduleId/announcements/$announcementId';
  static String announcementsRead(int scheduleId) =>
      'schedules/$scheduleId/announcements/read';
  static String announcementsUnreadCount(int scheduleId) =>
      'schedules/$scheduleId/announcements/unread-count';
  static String announcementPin(int scheduleId, int announcementId) =>
      'schedules/$scheduleId/announcements/$announcementId/pin';

  // Schedules / seats
  static String scheduleSeats(int scheduleId) => 'schedules/$scheduleId/seats';
  static String scheduleSeatLock(int scheduleId) =>
      'schedules/$scheduleId/seats/lock';
  static const seatLocksActive = 'seat-locks/active';
  static String seatLock(int scheduleId) => 'seat-locks/$scheduleId';

  // Bookings
  static const bookings = 'bookings';
  static const bookingsGuestLookup = 'bookings/guest-lookup';
  static const bookingsGuestLookupByName = 'bookings/guest-lookup-by-name';
  static const reviewsUploadImage = 'reviews/upload-image';
  static String booking(String ref) => 'bookings/$ref';
  static String bookingCancel(String ref) => 'bookings/$ref/cancel';
  static String bookingReschedule(String ref) => 'bookings/$ref/reschedule';
  static String bookingChangePickup(String ref) =>
      'bookings/$ref/change-pickup';

  // Booking members / companion invites (เชิญเพื่อนเข้าการจองเดียวกัน)
  static String bookingMembers(String ref) => 'bookings/$ref/members';
  static String bookingInvites(String ref) => 'bookings/$ref/invites';
  static String bookingMember(String ref, int id) =>
      'bookings/$ref/members/$id';
  static String bookingInvite(String token) => 'booking-invites/$token';
  static String bookingInviteAccept(String token) =>
      'booking-invites/$token/accept';

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

  // Trip price & availability alerts (per-trip bell)
  static const tripAlerts = 'trip-alerts';
  static String tripAlert(String slug) => 'trips/$slug/alerts';

  // Group trip invite (host-pays-all)
  static String scheduleGroupPlans(int scheduleId) =>
      'schedules/$scheduleId/group-plans';
  static const groupPlansMine = 'group-plans/mine';
  static String groupPlan(String code) => 'group-plans/$code';
  static String groupPlanJoin(String code) => 'group-plans/$code/join';
  static String groupPlanClaimSeat(String code) =>
      'group-plans/$code/claim-seat';
  static String groupPlanReleaseSeat(String code) =>
      'group-plans/$code/release-seat';
  static String groupPlanLeave(String code) => 'group-plans/$code/leave';
  static String groupPlanCheckout(String code) => 'group-plans/$code/checkout';

  // Loyalty
  static const loyaltyAccount = 'loyalty/account';
  static const loyaltyRewards = 'loyalty/rewards';
  static const loyaltyCoupons = 'loyalty/coupons';
  static const loyaltyRedeem = 'loyalty/redeem';

  // Referral
  static const referral = 'referral';

  // Misc
  static const contacts = 'contacts';
  static const broadcastingAuth = 'broadcasting/auth';
  static const appVersion = 'app/version';

  // Staff
  static const staffCheckInLookup = 'staff/check-in/lookup';
  static const staffCheckInConfirm = 'staff/check-in/confirm';
  static const staffSchedulesMy = 'staff/schedules/my';
  static const staffReviewsMy = 'staff/reviews/my';
}
