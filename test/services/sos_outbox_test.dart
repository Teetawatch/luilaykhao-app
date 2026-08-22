import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/offline_cache.dart';
import 'package:luilaykhao_app/services/sos_outbox.dart';
import 'package:luilaykhao_app/widgets/sos_fallback_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// คิว SOS ที่ค้างอยู่ในเครื่องตอนไม่มีสัญญาณ
///
/// เดิม SOS ที่ส่งไม่ผ่านหายไปเฉย ๆ พร้อมกับความเชื่อของผู้กดว่าส่งไปแล้ว —
/// เทสต์ชุดนี้ล็อกว่ามันถูกเก็บไว้จริง ไม่ซ้ำ และหมดอายุตามกำหนด
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    OfflineCache.instance.resetForTest();
    SosOutbox.instance.resetForTest();
    await OfflineCache.instance.load();
  });

  group('SosOutbox', () {
    test('keeps an alert that could not be sent', () async {
      await SosOutbox.instance.enqueue(
        scheduleId: 7,
        clientToken: 'tok-a',
        occurredAt: DateTime.now(),
        latitude: 16.86,
        longitude: 101.79,
        message: 'ฉันหลงทาง',
      );

      final pending = SosOutbox.instance.pending();
      expect(pending, hasLength(1));
      expect(pending.first['schedule_id'], 7);
      expect(pending.first['message'], 'ฉันหลงทาง');
      expect(SosOutbox.instance.pendingCount.value, 1);
    });

    test('survives an app restart', () async {
      await SosOutbox.instance.enqueue(
        scheduleId: 7,
        clientToken: 'tok-a',
        occurredAt: DateTime.now(),
      );

      // เปิดแอปใหม่: แคชในหน่วยความจำหาย เหลือแต่ของบนเครื่อง
      OfflineCache.instance.resetForTest();
      await OfflineCache.instance.load();

      expect(SosOutbox.instance.pending(), hasLength(1));
    });

    /// ผู้ใช้กด "ลองอีกครั้ง" ด้วยโทเคนเดิมต้องไม่กลายเป็นสองสัญญาณ
    test('re-queueing the same token replaces rather than duplicates', () async {
      await SosOutbox.instance.enqueue(
        scheduleId: 7,
        clientToken: 'tok-a',
        occurredAt: DateTime.now(),
        message: 'ครั้งแรก',
      );
      await SosOutbox.instance.enqueue(
        scheduleId: 7,
        clientToken: 'tok-a',
        occurredAt: DateTime.now(),
        message: 'ลองใหม่',
      );

      final pending = SosOutbox.instance.pending();
      expect(pending, hasLength(1));
      expect(pending.first['message'], 'ลองใหม่');
    });

    /// เซิร์ฟเวอร์ปฏิเสธ occurred_at ที่เก่ากว่า 48 ชม.อยู่แล้ว การเก็บต่อมีแต่จะ
    /// ทำให้แถบ "ยังส่งไม่สำเร็จ" ค้างอยู่บนหน้าจอตลอดไป
    test('drops entries older than the server will accept', () async {
      await SosOutbox.instance.enqueue(
        scheduleId: 7,
        clientToken: 'tok-old',
        occurredAt: DateTime.now().subtract(const Duration(hours: 49)),
      );
      await SosOutbox.instance.enqueue(
        scheduleId: 7,
        clientToken: 'tok-new',
        occurredAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final pending = SosOutbox.instance.pending();
      expect(pending, hasLength(1));
      expect(pending.first['client_token'], 'tok-new');
    });

    test('clear empties the queue and the badge', () async {
      await SosOutbox.instance.enqueue(
        scheduleId: 7,
        clientToken: 'tok-a',
        occurredAt: DateTime.now(),
      );

      await SosOutbox.instance.clear();

      expect(SosOutbox.instance.pending(), isEmpty);
      expect(SosOutbox.instance.pendingCount.value, 0);
    });

    test('tokens are unique per press', () {
      final tokens = List.generate(50, (_) => SosOutbox.newToken());
      expect(tokens.toSet(), hasLength(50));
    });

    /// ไม่มี provider ผูกอยู่ = ยังไม่ได้ล็อกอินหรือแอปเพิ่งเริ่ม — ต้องไม่พัง
    test('flush is a no-op with nothing attached', () async {
      await SosOutbox.instance.enqueue(
        scheduleId: 7,
        clientToken: 'tok-a',
        occurredAt: DateTime.now(),
      );

      expect(await SosOutbox.instance.flush(), 0);
      expect(SosOutbox.instance.pending(), hasLength(1));
    });
  });

  group('SosFallbackSheet.composeSms', () {
    test('carries who, where, and what happened', () {
      final text = SosFallbackSheet.composeSms(
        travellerName: 'สมชาย',
        tripTitle: 'ภูกระดึง',
        message: 'ฉันหลงทาง',
        latitude: 16.8612,
        longitude: 101.7891,
        occurredAt: DateTime(2026, 8, 22, 14, 5),
      );

      expect(text, startsWith('[SOS] สมชาย'));
      expect(text, contains('ทริป ภูกระดึง'));
      expect(text, contains('ฉันหลงทาง'));
      expect(text, contains('https://maps.google.com/?q=16.86120,101.78910'));
      expect(text, contains('เวลา 14:05 น.'));
    });

    /// GPS จับไม่ได้เป็นเรื่องปกติในหุบเขา ข้อความต้องบอกตรง ๆ ว่าไม่มีพิกัด
    /// ไม่ใช่เงียบไปเฉย ๆ จนคนรับคิดว่าลืมแนบ
    test('says so plainly when there is no fix', () {
      final text = SosFallbackSheet.composeSms(travellerName: 'สมชาย');

      expect(text, contains('(ระบุพิกัดไม่ได้)'));
      expect(text, isNot(contains('maps.google.com')));
    });
  });
}
