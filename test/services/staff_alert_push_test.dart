import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/push_notification_service.dart';

void main() {
  test('channel คำขอถึงทีมงานตรงกับ FcmService::STAFF_ALERT_CHANNEL และสั่นยาว', () {
    final channel = PushNotificationService.staffAlertChannel;
    expect(channel.id, 'staff_alerts');
    expect(channel.importance, Importance.max);
    expect(channel.enableVibration, isTrue);
    expect(
      channel.vibrationPattern?.toList(),
      PushNotificationService.staffAlertVibration,
    );
    // ยาวกว่าการสั่นสั้น ๆ ของแจ้งเตือนทั่วไปชัดเจน
    final total = PushNotificationService.staffAlertVibration
        .fold<int>(0, (sum, ms) => sum + ms);
    expect(total, greaterThanOrEqualTo(3000));
  });

  test('อ่านธง staff_alert จาก data ของ FCM', () {
    expect(PushNotificationService.isStaffAlert({'staff_alert': '1'}), isTrue);
    expect(
      PushNotificationService.isStaffAlert({'type': 'stop_request'}),
      isFalse,
    );
    expect(PushNotificationService.isStaffAlert({'staff_alert': '0'}), isFalse);
  });
}
