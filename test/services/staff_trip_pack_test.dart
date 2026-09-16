import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/staff_trip_pack.dart';

/// เลือกรอบผิด = สตาฟไปถึงจุดรับโดยไม่มีรายชื่อติดเครื่อง ซึ่งเป็นปัญหาเดิม
/// ที่ชุดข้อมูลนี้ตั้งใจแก้ตั้งแต่แรก
void main() {
  String day(int offset) {
    final d = DateTime.now().add(Duration(days: offset));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> schedule({
    required int departsInDays,
    int? returnsInDays,
    int id = 7,
    String status = 'open',
  }) {
    return {
      'id': id,
      'status': status,
      'departure_date': day(departsInDays),
      'return_date': day(returnsInDays ?? departsInDays),
    };
  }

  group('StaffTripPack.dueScheduleIds', () {
    test('รอบพรุ่งนี้และวันนี้ต้องมีของติดเครื่อง', () {
      final due = StaffTripPack.dueScheduleIds([
        schedule(departsInDays: 1, id: 1),
        schedule(departsInDays: 0, id: 2),
      ]);

      expect(due, [1, 2]);
    });

    test('รอบที่ยังอีกไกลยังไม่ต้องเตรียม', () {
      expect(StaffTripPack.dueScheduleIds([schedule(departsInDays: 5)]), isEmpty);
    });

    test('ทริปหลายวันยังอยู่ในชุดจนถึงวันกลับ', () {
      final due = StaffTripPack.dueScheduleIds([
        schedule(departsInDays: -1, returnsInDays: 1),
      ]);

      expect(due, [7]);
    });

    test('ทริปที่จบไปแล้วหลุดออกจากชุด', () {
      expect(
        StaffTripPack.dueScheduleIds([
          schedule(departsInDays: -4, returnsInDays: -3),
        ]),
        isEmpty,
      );
    });

    test('รอบที่ถูกยกเลิกไม่ต้องแบกไว้', () {
      expect(
        StaffTripPack.dueScheduleIds([
          schedule(departsInDays: 0, status: 'cancelled'),
        ]),
        isEmpty,
      );
    });

    test('ข้อมูลที่อ่านไม่ออกไม่ทำให้ทั้งชุดพัง', () {
      final due = StaffTripPack.dueScheduleIds([
        'ไม่ใช่ map',
        {'id': 0, 'departure_date': day(0)},
        {'id': 3, 'departure_date': 'ไม่ใช่วันที่'},
        schedule(departsInDays: 0, id: 4),
      ]);

      expect(due, [4]);
    });
  });
}
