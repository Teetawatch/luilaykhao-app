// สคริปต์ดีบักที่มีหน้าที่พิมพ์ผลลัพธ์ออกมาอ่านโดยตรง ไม่ใช่โค้ดที่ขึ้นแอป
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:luilaykhao_app/models/home_widget_snapshot.dart';

/// พิมพ์ payload จริงที่ฝั่ง Dart ส่งข้าม MethodChannel ไปให้ native
void main() {
  final full = HomeWidgetSnapshot.fromJson({
    'version': 1,
    'generated_at': '2026-08-19T10:00:00+07:00',
    'trip': {
      'booking_ref': 'LLK-20260905-0001',
      'trip_title': 'เขาช้างเผือก',
      'departure_date': '2026-09-05',
      'valid_until': '2026-09-06',
      'date_label': '5 ก.ย. 2569',
      'depart_time': '05:30',
      'countdown_days': 17,
      'headline': 'อีก 17 วันออกเดินทาง',
      'detail': '5 ก.ย. 2569 · 05:30 น. · ปั๊ม ปตท. รังสิต',
      'stage': 'countdown',
      'eta_minutes': null,
      'progress': 0,
      'is_live': false,
    },
    'payment': {
      'booking_ref': 'LLK-20260820-0009',
      'trip_title': 'ภูกระดึง',
      'label': 'งวดที่ 2/3',
      'amount': '1000.00',
      'amount_label': '1,000 บาท',
      'due_date': '2026-08-25',
      'due_label': 'ครบกำหนด 25 ส.ค. 2569',
      'days_left': 6,
      'overdue': false,
      'slip_pending': false,
    },
  })!;

  final live = HomeWidgetSnapshot.fromJson({
    'version': 1,
    'trip': {
      'booking_ref': 'LLK-1',
      'trip_title': 'ภูชี้ฟ้า',
      'departure_date': '2026-08-20',
      'valid_until': '2026-08-21',
      'date_label': '20 ส.ค. 2569',
      'depart_time': '05:00',
      'countdown_days': 0,
      'headline': 'รถถึงใน 8 นาที',
      'detail': 'กำลังมาที่จุดรับ ปั๊ม ปตท. รังสิต',
      'stage': 'approaching',
      'eta_minutes': 8,
      'progress': 0.73,
      'is_live': true,
    },
    'payment': null,
  })!;

  final empty = HomeWidgetSnapshot.fromJson({'version': 1})!;
  final minimal = HomeWidgetSnapshot.fromJson({
    'version': 1,
    'trip': {'booking_ref': 'A'},
    'payment': {'booking_ref': 'A'},
  })!;
  final future = HomeWidgetSnapshot.fromJson({'version': 99})!;

  for (final s in [full, live, empty, minimal, future]) {
    print(jsonEncode(s.toNativeJson()));
  }
}
