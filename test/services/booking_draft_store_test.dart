import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/booking_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, dynamic> draft({String name = 'สมชาย'}) => {
    'schedule_id': 12,
    'pickup_point_id': 3,
    'group_notes': 'ขอที่นั่งใกล้กัน',
    'passengers': [
      {'name': name, 'phone': '0812345678'},
    ],
    'addons': [0, 2],
    'rentals': {'1': 2},
  };

  group('BookingDraftStore', () {
    test('saves and reads a draft back for the same trip', () async {
      await BookingDraftStore.save(tripSlug: 'doi-luang', draft: draft());

      final loaded = await BookingDraftStore.load('doi-luang');

      expect(loaded, isNotNull);
      expect(loaded!['schedule_id'], 12);
      expect(loaded['group_notes'], 'ขอที่นั่งใกล้กัน');
      expect((loaded['passengers'] as List).first['name'], 'สมชาย');
      expect(loaded['addons'], [0, 2]);
    });

    test('keeps drafts separate per trip', () async {
      await BookingDraftStore.save(tripSlug: 'trip-a', draft: draft(name: 'เอ'));
      await BookingDraftStore.save(tripSlug: 'trip-b', draft: draft(name: 'บี'));

      final a = await BookingDraftStore.load('trip-a');
      final b = await BookingDraftStore.load('trip-b');

      expect((a!['passengers'] as List).first['name'], 'เอ');
      expect((b!['passengers'] as List).first['name'], 'บี');
    });

    test('returns null when there is no draft', () async {
      expect(await BookingDraftStore.load('never-opened'), isNull);
    });

    test('drops a draft older than a week instead of resurrecting it', () async {
      SharedPreferences.setMockInitialValues({
        'booking_draft_v1.old-trip':
            '{"schedule_id":1,"passengers":[{"name":"เก่า"}],'
                '"saved_at":"2020-01-01T00:00:00.000"}',
      });

      expect(await BookingDraftStore.load('old-trip'), isNull);

      // and it is deleted on the way out, not left to accumulate
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('booking_draft_v1.old-trip'), isNull);
    });

    test('survives a corrupted payload without throwing', () async {
      SharedPreferences.setMockInitialValues({
        'booking_draft_v1.broken': 'not json at all',
      });

      expect(await BookingDraftStore.load('broken'), isNull);
    });

    test('clear removes only the trip asked for', () async {
      await BookingDraftStore.save(tripSlug: 'trip-a', draft: draft());
      await BookingDraftStore.save(tripSlug: 'trip-b', draft: draft());

      await BookingDraftStore.clear('trip-a');

      expect(await BookingDraftStore.load('trip-a'), isNull);
      expect(await BookingDraftStore.load('trip-b'), isNotNull);
    });

    test('clearAll wipes every draft, as logout must', () async {
      await BookingDraftStore.save(tripSlug: 'trip-a', draft: draft());
      await BookingDraftStore.save(tripSlug: 'trip-b', draft: draft());

      await BookingDraftStore.clearAll();

      expect(await BookingDraftStore.load('trip-a'), isNull);
      expect(await BookingDraftStore.load('trip-b'), isNull);
    });

    test('an untouched form is not worth offering back', () {
      expect(
        BookingDraftStore.isWorthRestoring({
          'passengers': [
            {'name': '', 'phone': ''},
          ],
        }),
        isFalse,
      );
      expect(BookingDraftStore.isWorthRestoring({'passengers': []}), isFalse);
      expect(BookingDraftStore.isWorthRestoring(const {}), isFalse);
    });

    test('a form with any name or phone typed is worth offering back', () {
      expect(BookingDraftStore.isWorthRestoring(draft()), isTrue);
      expect(
        BookingDraftStore.isWorthRestoring({
          'passengers': [
            {'name': '', 'phone': '0899999999'},
          ],
        }),
        isTrue,
      );
    });

    test('an empty trip slug is ignored rather than writing a stray key', () async {
      await BookingDraftStore.save(tripSlug: '', draft: draft());

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('booking_draft_v1.')), isEmpty);
    });
  });
}
