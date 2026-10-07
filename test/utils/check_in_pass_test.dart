import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/utils/check_in_pass.dart';

/// ปุ่ม QR กลางแถบเมนูต้องหยิบใบจองถูกใบ — ใบที่ยังไม่ยืนยันห้ามมี QR ทริปที่จบแล้ว
/// ต้องหายไป และทริปที่ใกล้ที่สุดต้องขึ้นก่อน
void main() {
  final now = DateTime(2026, 10, 7, 9, 30);

  Map<String, dynamic> booking({
    required int id,
    String status = 'confirmed',
    String? departureDate = '2026-10-10',
    String? returnDate,
    String? departsAt,
    bool awaitingNewRound = false,
  }) => {
    'id': id,
    'booking_ref': 'LLK-20261010-000$id',
    'status': status,
    'qr_code': 'QR-$id',
    if (awaitingNewRound) 'force_majeure': {'awaiting': true},
    'schedule': {
      'departure_date': departureDate,
      'return_date': returnDate ?? departureDate,
      'departs_at': departsAt,
    },
  };

  List<int> ids(List<Map<String, dynamic>> list) => [
    for (final b in list) b['id'] as int,
  ];

  test('เฉพาะใบที่ยืนยันแล้ว — ใบรอชำระ/ยกเลิก/คืนเงินไม่มี QR', () {
    final result = checkInPassBookings([
      booking(id: 1),
      booking(id: 2, status: 'pending'),
      booking(id: 3, status: 'cancelled'),
      booking(id: 4, status: 'refunded'),
      booking(id: 5, status: 'completed'),
    ], now: now);
    expect(ids(result), [1]);
  });

  test('รอบที่ออกไม่ได้และยังรอเลือกรอบใหม่ ไม่โชว์ QR', () {
    final result = checkInPassBookings([
      booking(id: 1, awaitingNewRound: true),
      booking(id: 2),
    ], now: now);
    expect(ids(result), [2]);
  });

  test('ทริปหลายวันยังอยู่จนถึงวันกลับ แล้วหายไปวันถัดไป', () {
    final trip = booking(
      id: 1,
      departureDate: '2026-10-05',
      returnDate: '2026-10-07',
    );
    expect(ids(checkInPassBookings([trip], now: now)), [1]);
    expect(
      checkInPassBookings([trip], now: DateTime(2026, 10, 8, 0, 1)),
      isEmpty,
    );
  });

  test('เรียงจากทริปที่ใกล้ที่สุด ใบที่ไม่มีวันไปต่อท้าย', () {
    final result = checkInPassBookings([
      booking(id: 1, departureDate: '2026-12-01'),
      booking(id: 2, departureDate: null, returnDate: ''),
      booking(id: 3, departureDate: '2026-10-08'),
      booking(id: 4, departureDate: '2026-11-01'),
    ], now: now);
    expect(ids(result), [3, 4, 1, 2]);
  });

  test('รถออกคืนก่อนวันทริป (departs_at) นับจากวันที่รถออกจริง', () {
    final night = booking(
      id: 1,
      departureDate: '2026-10-11',
      departsAt: '2026-10-10T23:30:00',
    );
    final morning = booking(id: 2, departureDate: '2026-10-10');
    final result = checkInPassBookings([morning, night], now: now);
    // วันเดียวกัน (10 ต.ค.) — ลำดับเดิมคงไว้
    expect(ids(result), [2, 1]);
    expect(checkInPassWhenLabel(night, now: now), 'อีก 3 วัน');
  });

  test('ใบจองเดียวกันที่ซ้ำจากหน้าประวัติ ขึ้นแค่ครั้งเดียว', () {
    final result = checkInPassBookings([
      booking(id: 1),
      booking(id: 1),
    ], now: now);
    expect(result, hasLength(1));
  });

  test('ข้อมูลเพี้ยน (ไม่ใช่ Map) ถูกข้ามไป ไม่ throw', () {
    final result = checkInPassBookings([
      null,
      'x',
      3,
      booking(id: 1),
    ], now: now);
    expect(ids(result), [1]);
  });

  test('ป้ายระยะห่างของทริป', () {
    expect(
      checkInPassWhenLabel(
        booking(id: 1, departureDate: '2026-10-07'),
        now: now,
      ),
      'วันนี้',
    );
    expect(
      checkInPassWhenLabel(
        booking(id: 1, departureDate: '2026-10-08'),
        now: now,
      ),
      'พรุ่งนี้',
    );
    expect(
      checkInPassWhenLabel(
        booking(id: 1, departureDate: '2026-10-20'),
        now: now,
      ),
      'อีก 13 วัน',
    );
    expect(
      checkInPassWhenLabel(
        booking(id: 1, departureDate: '2026-10-06', returnDate: '2026-10-08'),
        now: now,
      ),
      'ระหว่างทริป',
    );
    expect(
      checkInPassWhenLabel(booking(id: 1, departureDate: null), now: now),
      '',
    );
  });

  test('มีใบรอยืนยันที่ยังไม่ถึงวัน — หน้าว่างบอกว่า QR จะมาหลังยืนยัน', () {
    expect(
      hasPendingUpcomingBooking([booking(id: 1, status: 'pending')], now: now),
      isTrue,
    );
    expect(
      hasPendingUpcomingBooking([
        booking(id: 1, status: 'pending', departureDate: '2026-09-01'),
      ], now: now),
      isFalse,
    );
    expect(hasPendingUpcomingBooking([booking(id: 1)], now: now), isFalse);
  });
}
