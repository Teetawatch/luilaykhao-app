import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/offline_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineCache.instance.resetForTest();
  });

  group('OfflineCache', () {
    test('returns null for unknown keys', () async {
      final cache = OfflineCache.instance;
      await cache.load();
      expect(cache.readPublic<List>('missing'), isNull);
      expect(cache.readAccount<Map>('missing'), isNull);
    });

    test('round-trips a public list through flush', () async {
      final cache = OfflineCache.instance;
      await cache.load();
      cache.writePublic('trips', [
        {'slug': 'a', 'title': 'A'},
      ]);
      await cache.flush();

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('offline_cache_v1.public.trips');
      expect(raw, isNotNull);
      expect(raw, contains('"slug":"a"'));
    });

    test('clearAccount removes only account-scoped keys', () async {
      final cache = OfflineCache.instance;
      await cache.load();
      cache.writePublic('trips', ['x']);
      cache.writeAccount('bookings', ['y']);
      await cache.flush();

      await cache.clearAccount();
      expect(cache.readAccount<List>('bookings'), isNull);
      expect(cache.readPublic<List>('trips'), isNotNull);
    });

    test('flush rewrites only the keys that changed', () async {
      final cache = OfflineCache.instance;
      await cache.load();
      cache.writePublic('trips', ['first']);
      await cache.flush();

      // แก้ค่าบนเครื่องตรง ๆ ให้ต่างจากในหน่วยความจำ ถ้า flush รอบถัดไปยัง
      // เขียนทับทุกคีย์เหมือนเดิม ค่าที่แอบใส่ไว้จะถูกลบหายไป
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_cache_v1.public.trips', '"TAMPERED"');

      cache.writePublic('reviews', ['unrelated']);
      await cache.flush();

      expect(
        prefs.getString('offline_cache_v1.public.trips'),
        '"TAMPERED"',
        reason: 'คีย์ที่ไม่ได้แตะต้องไม่ถูกเขียนใหม่',
      );
      expect(prefs.getString('offline_cache_v1.public.reviews'), isNotNull);
    });

    test('a no-op flush touches nothing', () async {
      final cache = OfflineCache.instance;
      await cache.load();
      cache.writeAccount('bookings', ['y']);
      await cache.flush();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_cache_v1.account.bookings', '"TAMPERED"');
      await cache.flush();

      expect(
        prefs.getString('offline_cache_v1.account.bookings'),
        '"TAMPERED"',
      );
    });

    test(
      'writing null erases the key from disk, not just from memory',
      () async {
        final cache = OfflineCache.instance;
        await cache.load();
        cache.writeAccount('loyalty', {'tier': 'gold'});
        await cache.flush();

        cache.writeAccount('loyalty', null);
        await cache.flush();

        final prefs = await SharedPreferences.getInstance();
        expect(cache.readAccount<Map>('loyalty'), isNull);
        expect(prefs.getString('offline_cache_v1.account.loyalty'), isNull);
      },
    );

    test('caps per-booking entries and drops the oldest', () async {
      final cache = OfflineCache.instance;
      await cache.load();

      for (var i = 1; i <= 20; i++) {
        cache.writeAccount('booking.LLK-$i', {'ref': 'LLK-$i'});
      }
      await cache.flush();

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs
          .getKeys()
          .where((k) => k.startsWith('offline_cache_v1.account.booking.'))
          .toList();

      expect(stored, hasLength(12));
      // ใบแรก ๆ ถูกทิ้ง ใบล่าสุดต้องอยู่ครบ
      expect(cache.readAccount<Map>('booking.LLK-1'), isNull);
      expect(cache.readAccount<Map>('booking.LLK-20'), isNotNull);
      expect(prefs.getString('offline_cache_v1.account.booking.LLK-1'), isNull);
    });

    test(
      're-writing an existing booking keeps it from being evicted',
      () async {
        final cache = OfflineCache.instance;
        await cache.load();

        cache.writeAccount('booking.KEEP', {'ref': 'KEEP'});
        for (var i = 1; i <= 11; i++) {
          cache.writeAccount('booking.LLK-$i', {'ref': 'LLK-$i'});
        }
        // แตะใบเดิมอีกครั้ง — มันควรถูกนับว่า "ใหม่ที่สุด" ไม่ใช่เก่าที่สุด
        cache.writeAccount('booking.KEEP', {'ref': 'KEEP'});
        cache.writeAccount('booking.LLK-12', {'ref': 'LLK-12'});
        await cache.flush();

        expect(cache.readAccount<Map>('booking.KEEP'), isNotNull);
        expect(cache.readAccount<Map>('booking.LLK-1'), isNull);
      },
    );

    test('load prunes a cache that overflowed under an older build', () async {
      final seeded = <String, Object>{};
      for (var i = 1; i <= 30; i++) {
        seeded['offline_cache_v1.account.booking.OLD-$i'] = '{"ref":"OLD-$i"}';
      }
      seeded['offline_cache_v1.account.bookings'] = '[]';
      SharedPreferences.setMockInitialValues(seeded);
      OfflineCache.instance.resetForTest();

      final cache = OfflineCache.instance;
      await cache.load();
      await cache.flush();

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs
          .getKeys()
          .where((k) => k.startsWith('offline_cache_v1.account.booking.'))
          .toList();

      expect(stored, hasLength(12));
      // คีย์ที่ไม่มีเพดานต้องไม่ถูกแตะ
      expect(cache.readAccount<List>('bookings'), isNotNull);
    });
  });
}
