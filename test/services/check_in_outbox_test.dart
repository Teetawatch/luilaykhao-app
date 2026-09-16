import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/check_in_outbox.dart';
import 'package:luilaykhao_app/services/offline_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// คิวเช็คอินที่สตาฟกดตอนไม่มีสัญญาณ
///
/// สิ่งที่ต้องไม่หายไปคือ "ใครขึ้นรถแล้วบ้าง" — ถ้ารายการหลุดจากคิว สตาฟจะรู้
/// ก็ต่อเมื่อรถออกไปแล้วและมีคนหาย เทสต์ชุดนี้ล็อกว่ามันอยู่ครบ ไม่ซ้ำ
/// ข้ามการเปิดแอปใหม่ได้ และหมดอายุตามกรอบเดียวกับที่เซิร์ฟเวอร์ยอมรับ
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    OfflineCache.instance.resetForTest();
    CheckInOutbox.instance.resetForTest();
    await OfflineCache.instance.load();
  });

  group('CheckInOutbox', () {
    test('เก็บเช็คอินที่ส่งไม่ออกไว้พร้อมเวลาที่กดจริง', () async {
      final at = DateTime.now().subtract(const Duration(minutes: 5));

      await CheckInOutbox.instance.enqueue(
        scheduleId: 7,
        bookingRef: 'LLK-20260916-0001',
        qrCode: 'LLK-20260916-0001',
        name: 'คุณลูกค้า',
        occurredAt: at,
      );

      final pending = CheckInOutbox.instance.pending();
      expect(pending, hasLength(1));
      expect(pending.first['booking_ref'], 'LLK-20260916-0001');
      expect(pending.first['schedule_id'], 7);
      expect(
        DateTime.parse('${pending.first['occurred_at']}')
            .difference(at.toUtc())
            .inSeconds
            .abs(),
        lessThan(2),
      );
      expect(CheckInOutbox.instance.pendingCount.value, 1);
    });

    test('อยู่รอดข้ามการเปิดแอปใหม่', () async {
      await CheckInOutbox.instance.enqueue(
        scheduleId: 7,
        bookingRef: 'LLK-20260916-0001',
        qrCode: 'LLK-20260916-0001',
      );

      OfflineCache.instance.resetForTest();
      await OfflineCache.instance.load();

      expect(CheckInOutbox.instance.pending(), hasLength(1));
    });

    /// สตาฟกดซ้ำเพราะไม่แน่ใจว่าครั้งแรกติดไหม — ต้องไม่กลายเป็นสองรายการ
    test('กดซ้ำใบเดิมแทนที่รายการเดิม ไม่ใช่เพิ่มใหม่', () async {
      await CheckInOutbox.instance.enqueue(
        scheduleId: 7,
        bookingRef: 'LLK-20260916-0001',
        qrCode: 'LLK-20260916-0001',
        name: 'ครั้งแรก',
      );
      await CheckInOutbox.instance.enqueue(
        scheduleId: 7,
        bookingRef: 'LLK-20260916-0001',
        qrCode: 'LLK-20260916-0001',
        name: 'ครั้งที่สอง',
      );

      final pending = CheckInOutbox.instance.pending();
      expect(pending, hasLength(1));
      expect(pending.first['name'], 'ครั้งที่สอง');
    });

    test('รายการที่เก่าเกินหนึ่งวันถูกทิ้ง', () async {
      await CheckInOutbox.instance.enqueue(
        scheduleId: 7,
        bookingRef: 'LLK-OLD',
        qrCode: 'LLK-OLD',
        occurredAt: DateTime.now().subtract(const Duration(hours: 30)),
      );
      await CheckInOutbox.instance.enqueue(
        scheduleId: 7,
        bookingRef: 'LLK-NEW',
        qrCode: 'LLK-NEW',
        occurredAt: DateTime.now(),
      );

      final pending = CheckInOutbox.instance.pending();
      expect(pending, hasLength(1));
      expect(pending.first['booking_ref'], 'LLK-NEW');
    });

    /// หน้ารายชื่อของรอบหนึ่งต้องไม่ติดป้าย "รอส่ง" ให้คนของอีกรอบหนึ่ง
    test('pendingRefs คืนเฉพาะของรอบที่ถาม', () async {
      await CheckInOutbox.instance.enqueue(
        scheduleId: 7,
        bookingRef: 'LLK-A',
        qrCode: 'LLK-A',
      );
      await CheckInOutbox.instance.enqueue(
        scheduleId: 9,
        bookingRef: 'LLK-B',
        qrCode: 'LLK-B',
      );

      expect(CheckInOutbox.instance.pendingRefs(7), {'LLK-A'});
      expect(CheckInOutbox.instance.pendingRefs(9), {'LLK-B'});
      expect(CheckInOutbox.instance.pendingRefs(11), isEmpty);
    });

    test('clear ล้างคิวและตัวนับ (ใช้ตอนออกจากระบบ)', () async {
      await CheckInOutbox.instance.enqueue(
        scheduleId: 7,
        bookingRef: 'LLK-A',
        qrCode: 'LLK-A',
      );

      await CheckInOutbox.instance.clear();

      expect(CheckInOutbox.instance.pending(), isEmpty);
      expect(CheckInOutbox.instance.pendingCount.value, 0);
    });
  });
}
