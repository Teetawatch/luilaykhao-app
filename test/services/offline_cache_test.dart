import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/offline_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

      // Force reload by clearing in-memory then loading again — but since
      // OfflineCache is a singleton, the in-memory state stays. The persisted
      // copy is what we really care about; verify by inspecting raw prefs.
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
  });
}
