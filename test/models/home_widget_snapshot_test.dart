import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/models/home_widget_snapshot.dart';

/// สิ่งที่เทสต์ชุดนี้ล็อกไว้: ก้อนที่ข้ามไปฝั่ง native ต้องมีชนิดข้อมูลที่แน่นอน
///
/// ตัวถอดรหัสฝั่ง Swift ล้มทั้งก้อนถ้าฟิลด์ไหนผิดชนิด แล้ววิดเจ็ตจะว่างเปล่าโดยไม่มี
/// error ให้เห็นเลย — นั่นคือบั๊กที่ตามหาไม่ได้ ตรงนี้จึงต้องกันไว้ตั้งแต่ฝั่ง Dart
void main() {
  Map<String, dynamic> decoded(HomeWidgetSnapshot snapshot) =>
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(snapshot.toNativeJson())),
      );

  group('การถอดรหัส', () {
    test('อ่านก้อนเต็มได้ครบทุกฟิลด์', () {
      final snapshot = HomeWidgetSnapshot.fromJson({
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
          'booking_ref': 'LLK-20260905-0001',
          'trip_title': 'เขาช้างเผือก',
          'label': 'งวดที่ 2/3',
          'amount': 1000,
          'amount_label': '1,000 บาท',
          'due_date': '2026-08-25',
          'due_label': 'ครบกำหนด 25 ส.ค. 2569',
          'days_left': 6,
          'overdue': false,
          'slip_pending': false,
        },
      })!;

      expect(snapshot.trip!.tripTitle, 'เขาช้างเผือก');
      expect(snapshot.trip!.countdownDays, 17);
      expect(snapshot.trip!.validUntil, '2026-09-06');
      expect(snapshot.trip!.isLive, isFalse);
      expect(snapshot.payment!.amount, 1000.0);
      expect(snapshot.payment!.daysLeft, 6);
      expect(snapshot.isEmpty, isFalse);
    });

    test('ก้อนว่างคือก้อนว่าง ไม่ใช่ก้อนที่มีค่าเริ่มต้นปลอม ๆ', () {
      final snapshot = HomeWidgetSnapshot.fromJson({
        'version': 1,
        'generated_at': '2026-08-19T10:00:00+07:00',
        'trip': null,
        'payment': null,
      })!;

      expect(snapshot.trip, isNull);
      expect(snapshot.payment, isNull);
      expect(snapshot.isEmpty, isTrue);
    });

    test('บล็อกที่ไม่มีเลขการจองถูกทิ้ง — ไม่มีที่ให้แตะไปก็ไม่ควรวาด', () {
      final snapshot = HomeWidgetSnapshot.fromJson({
        'version': 1,
        'trip': {'trip_title': 'ไม่มี ref', 'countdown_days': 3},
        'payment': {'label': 'ไม่มี ref', 'amount': 100},
      })!;

      expect(snapshot.trip, isNull);
      expect(snapshot.payment, isNull);
    });

    test('เวอร์ชันที่เซิร์ฟเวอร์บอกถูกส่งต่อ ไม่ถูกทับด้วยเวอร์ชันของแอป', () {
      // ฝั่ง native เป็นคนตัดสินว่าอ่านเวอร์ชันนี้ได้หรือไม่ ถ้า Dart ทับเป็น 1
      // แอปเก่าจะแกล้งทำเป็นเข้าใจข้อมูลรูปแบบใหม่แล้ววาดผิด
      final snapshot = HomeWidgetSnapshot.fromJson({'version': 99})!;

      expect(snapshot.version, 99);
    });
  });

  group('การล้างชนิดข้อมูลก่อนข้ามไปฝั่ง native', () {
    test('ตัวเลขที่มาเป็นสตริงกลายเป็นตัวเลข', () {
      // PHP ส่ง decimal มาเป็นสตริงได้เมื่อคอลัมน์เป็น decimal cast
      final snapshot = HomeWidgetSnapshot.fromJson({
        'version': 1,
        'trip': {
          'booking_ref': 'A',
          'countdown_days': '5',
          'progress': '0.42',
          'eta_minutes': '8',
        },
        'payment': {'booking_ref': 'A', 'amount': '2500.00', 'days_left': '-2'},
      })!;

      final json = decoded(snapshot);
      expect(json['trip']['countdown_days'], isA<int>());
      expect(json['trip']['countdown_days'], 5);
      expect(json['trip']['eta_minutes'], 8);
      expect(json['trip']['progress'], closeTo(0.42, 0.0001));
      expect(json['payment']['amount'], 2500.0);
      expect(json['payment']['days_left'], -2);
    });

    test('progress ถูกบีบให้อยู่ใน 0..1 เสมอ', () {
      for (final entry in {'-3': 0.0, '5': 1.0, 'ไม่ใช่เลข': 0.0}.entries) {
        final snapshot = HomeWidgetSnapshot.fromJson({
          'version': 1,
          'trip': {'booking_ref': 'A', 'progress': entry.key},
        })!;

        expect(snapshot.trip!.progress, entry.value, reason: entry.key);
      }
    });

    test(
      'สตริงว่างกลายเป็น null ฝั่ง native จึงไม่ต้องเช็ค isEmpty ทุกจุด',
      () {
        final snapshot = HomeWidgetSnapshot.fromJson({
          'version': 1,
          'trip': {
            'booking_ref': 'A',
            'departure_date': '',
            'depart_time': '   ',
          },
        })!;

        expect(snapshot.trip!.departureDate, isNull);
        expect(snapshot.trip!.departTime, isNull);
      },
    );

    test('ฟิลด์ที่ฝั่ง native ประกาศเป็น non-optional ต้องไม่เคยเป็น null', () {
      // ก้อนที่เหลือแต่ booking_ref — โครงที่แย่ที่สุดที่ยังถูกส่งต่อ
      final json = decoded(
        HomeWidgetSnapshot.fromJson({
          'version': 1,
          'trip': {'booking_ref': 'A'},
          'payment': {'booking_ref': 'A'},
        })!,
      );

      for (final key in [
        'booking_ref',
        'trip_title',
        'date_label',
        'countdown_days',
        'headline',
        'detail',
        'stage',
        'progress',
        'is_live',
      ]) {
        expect(json['trip'][key], isNotNull, reason: 'trip.$key');
      }

      for (final key in [
        'booking_ref',
        'trip_title',
        'label',
        'amount',
        'amount_label',
        'due_label',
        'overdue',
        'slip_pending',
      ]) {
        expect(json['payment'][key], isNotNull, reason: 'payment.$key');
      }
    });

    test('คีย์ที่ส่งไปเป็น snake_case ชุดเดียวกับที่เซิร์ฟเวอร์ส่งมา', () {
      // คำศัพท์ชุดเดียวตลอดสาย Laravel → Dart → Swift/Kotlin ไม่มีชั้นแปลชื่อ
      final json = decoded(
        HomeWidgetSnapshot.fromJson({
          'version': 1,
          'trip': {'booking_ref': 'A'},
        })!,
      );

      expect(
        json.keys,
        containsAll(['version', 'generated_at', 'trip', 'payment']),
      );
      expect(
        (json['trip'] as Map).keys,
        containsAll([
          'booking_ref',
          'departure_date',
          'valid_until',
          'is_live',
        ]),
      );
    });
  });
}
