import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/trip_day_pack.dart';

/// เลือกรอบผิด = ไปดึงข้อมูลของทริปที่ยังอีกสองเดือน (เปลืองเน็ตลูกค้า) หรือ
/// แย่กว่านั้นคือไม่ดึงของรอบพรุ่งนี้ แล้วคนขึ้นดอยไปโดยไม่มีอะไรติดเครื่อง
void main() {
  String day(int offset) {
    final d = DateTime.now().add(Duration(days: offset));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> booking({
    required int departsInDays,
    int? returnsInDays,
    String status = 'confirmed',
    int scheduleId = 7,
  }) {
    return {
      'booking_ref': 'LLK-TEST-0001',
      'status': status,
      'schedule': {
        'id': scheduleId,
        'departure_date': day(departsInDays),
        'return_date': day(returnsInDays ?? departsInDays),
      },
    };
  }

  group('TripDayPack.dueBookings', () {
    test('รอบพรุ่งนี้และวันนี้อยู่ในชุดที่ต้องเตรียม', () {
      final due = TripDayPack.dueBookings([
        booking(departsInDays: 1, scheduleId: 1),
        booking(departsInDays: 0, scheduleId: 2),
      ]);

      expect(due, hasLength(2));
    });

    test('รอบที่ยังอีกไกลยังไม่ต้องเตรียม', () {
      expect(TripDayPack.dueBookings([booking(departsInDays: 9)]), isEmpty);
    });

    test('ทริปหลายวันยังอยู่ในชุดจนถึงวันกลับ', () {
      final due = TripDayPack.dueBookings([
        booking(departsInDays: -1, returnsInDays: 1),
      ]);

      expect(due, hasLength(1));
    });

    test('ทริปที่จบไปแล้วหลุดออกจากชุด', () {
      expect(
        TripDayPack.dueBookings([booking(departsInDays: -5, returnsInDays: -4)]),
        isEmpty,
      );
    });

    test('การจองที่ยกเลิกแล้วไม่ถูกเตรียม', () {
      expect(
        TripDayPack.dueBookings([
          booking(departsInDays: 1, status: 'cancelled'),
        ]),
        isEmpty,
      );
    });

    test('ข้อมูลที่ไม่มีรอบ/ไม่มีวันเดินทางถูกข้ามโดยไม่ throw', () {
      expect(
        TripDayPack.dueBookings([
          {'status': 'confirmed'},
          {
            'status': 'confirmed',
            'schedule': {'id': 3},
          },
          'ไม่ใช่ map',
        ]),
        isEmpty,
      );
    });
  });
}
