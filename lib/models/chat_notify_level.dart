import 'package:flutter/material.dart';

/// ระดับการแจ้งเตือนของห้องแชททริป — ตั้งรายห้อง รายคน
///
/// ค่าตรงกับ `ChatRoomPreference::LEVELS` ฝั่ง Laravel และมีผลกับ push ของ
/// ห้องแชทเท่านั้น ประกาศ แจ้งเตือนรถ และ SOS ยังมาตามปกติ
enum ChatNotifyLevel {
  all(
    'all',
    'ทุกข้อความ',
    'แจ้งเตือนเมื่อมีข้อความใหม่ในห้อง',
    Icons.notifications_none_rounded,
  ),
  important(
    'important',
    'เฉพาะทีมงานและแท็กถึงฉัน',
    'แจ้งเตือนเฉพาะข้อความจากสตาฟ/ทีมงาน และเมื่อมีคน @ ถึงคุณ',
    Icons.notifications_paused_rounded,
  ),
  off(
    'off',
    'ปิดการแจ้งเตือน',
    'ไม่แจ้งเตือนจากห้องนี้เลย เปิดเข้ามาอ่านเองได้ตามปกติ',
    Icons.notifications_off_rounded,
  );

  const ChatNotifyLevel(this.value, this.label, this.description, this.icon);

  final String value;
  final String label;
  final String description;
  final IconData icon;

  /// ค่าที่ไม่รู้จัก (หรือ payload จากเซิร์ฟเวอร์รุ่นเก่า) = ทุกข้อความ
  static ChatNotifyLevel fromValue(Object? value) {
    for (final level in ChatNotifyLevel.values) {
      if (level.value == value?.toString()) return level;
    }
    return ChatNotifyLevel.all;
  }
}
