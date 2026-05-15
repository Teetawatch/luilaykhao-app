import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/providers/wishlist_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WishlistProvider', () {
    test('starts empty after load', () async {
      final provider = WishlistProvider();
      await provider.load();
      expect(provider.count, 0);
      expect(provider.items, isEmpty);
    });

    test('toggle adds a trip on first call', () async {
      final provider = WishlistProvider();
      await provider.load();
      final added = await provider.toggle({
        'slug': 'koh-tao',
        'title': 'เกาะเต่า',
        'price_per_person': 4500,
      });
      expect(added, isTrue);
      expect(provider.count, 1);
      expect(provider.contains('koh-tao'), isTrue);
    });

    test('toggle removes a trip on second call', () async {
      final provider = WishlistProvider();
      await provider.load();
      await provider.toggle({'slug': 'koh-tao', 'title': 'เกาะเต่า'});
      final stillFav = await provider.toggle({'slug': 'koh-tao', 'title': 'เกาะเต่า'});
      expect(stillFav, isFalse);
      expect(provider.count, 0);
    });

    test('rejects entries without a slug', () async {
      final provider = WishlistProvider();
      await provider.load();
      final added = await provider.toggle({'title': 'ไม่มี slug'});
      expect(added, isFalse);
      expect(provider.count, 0);
    });

    test('persists across provider instances', () async {
      final first = WishlistProvider();
      await first.load();
      await first.toggle({'slug': 'doi-inthanon', 'title': 'ดอยอินทนนท์'});

      final second = WishlistProvider();
      await second.load();
      expect(second.contains('doi-inthanon'), isTrue);
      expect(second.count, 1);
    });

    test('remove drops the slug', () async {
      final provider = WishlistProvider();
      await provider.load();
      await provider.toggle({'slug': 'koh-tao', 'title': 'เกาะเต่า'});
      await provider.remove('koh-tao');
      expect(provider.contains('koh-tao'), isFalse);
    });
  });
}
