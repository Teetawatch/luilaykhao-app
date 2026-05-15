import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/search_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add inserts queries newest-first and dedupes', () async {
    final svc = SearchHistoryService.instance;
    await svc.clear();
    await svc.add('โดดดอย');
    await svc.add('เกาะเต่า');
    await svc.add('โดดดอย'); // duplicate moves to front

    final history = await svc.read();
    expect(history, ['โดดดอย', 'เกาะเต่า']);
  });

  test('caps history at 8 entries', () async {
    final svc = SearchHistoryService.instance;
    await svc.clear();
    for (var i = 0; i < 12; i++) {
      await svc.add('q$i');
    }
    final history = await svc.read();
    expect(history.length, 8);
    expect(history.first, 'q11');
  });

  test('rejects blank queries', () async {
    final svc = SearchHistoryService.instance;
    await svc.clear();
    await svc.add('   ');
    expect(await svc.read(), isEmpty);
  });
}
