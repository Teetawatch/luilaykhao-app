import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/screens/payment_screen.dart';

/// เส้นตายชำระเงินต้องมาจากหลังบ้าน ไม่ใช่สูตรของหน้าจอ
///
/// ExpirePendingBookingsJob ยกเลิกการจองที่ค้างเกิน Booking::PENDING_TTL_MINUTES
/// นับจาก created_at เท่ากันทุกใบ และข้ามใบที่มีสลิปแล้ว BookingResource สรุปสองข้อ
/// นี้มาเป็น expires_at ให้แล้ว หน้าจอจึงมีหน้าที่แค่เดินตาม
void main() {
  Map<String, dynamic> booking({
    String? expiresAt,
    String? createdAt,
    String? slipOcrStatus,
  }) => <String, dynamic>{
    'created_at': createdAt,
    'expires_at': expiresAt,
    'slip_ocr_status': slipOcrStatus,
  };

  test('follows the expires_at the API sends', () {
    final deadline = paymentDeadline(
      booking(
        createdAt: '2026-08-20T10:00:00.000000Z',
        expiresAt: '2026-08-20T10:10:00.000000Z',
      ),
    );

    expect(deadline, isNotNull);
    expect(
      deadline!.toUtc(),
      DateTime.utc(2026, 8, 20, 10, 10),
    );
  });

  test('a booking with a slip in has no deadline at all', () {
    // ที่นั่งถูกถือไว้รอแอดมินตรวจ — หลังบ้านส่ง expires_at = null มาด้วย แต่ถึง
    // payload เก่าจะมี created_at ให้คำนวณได้ ก็ต้องไม่นับถอยหลัง
    expect(
      paymentDeadline(
        booking(
          createdAt: '2026-08-20T10:00:00.000000Z',
          slipOcrStatus: 'mismatch',
        ),
      ),
      isNull,
    );
  });

  test('falls back to created_at + 10 นาที when expires_at is missing', () {
    final deadline = paymentDeadline(
      booking(createdAt: '2026-08-20T10:00:00.000000Z'),
    );

    expect(deadline!.toUtc(), DateTime.utc(2026, 8, 20, 10, 10));
  });

  test('no created_at and no expires_at means nothing to count', () {
    expect(paymentDeadline(booking()), isNull);
  });

  test('the window minutes describe the server window, not the fallback', () {
    final b = booking(
      createdAt: '2026-08-20T10:00:00.000000Z',
      expiresAt: '2026-08-20T10:15:00.000000Z',
    );

    expect(paymentWindowMinutes(b, paymentDeadline(b)!), 15);
  });

  test('a deadline already in the past never reads as a negative window', () {
    final b = booking(
      createdAt: '2026-08-20T10:00:00.000000Z',
      expiresAt: '2026-08-20T09:50:00.000000Z',
    );

    expect(paymentWindowMinutes(b, paymentDeadline(b)!), 10);
  });
}
