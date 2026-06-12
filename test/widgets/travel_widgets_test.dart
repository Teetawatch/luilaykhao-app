import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/widgets/travel_widgets.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  group('scheduleDepartsAt', () {
    test('parses departs_at as local datetime', () {
      final departsAt = scheduleDepartsAt({
        'departure_date': '2026-06-13',
        'departs_at': '2026-06-12 23:30:00',
      });

      expect(departsAt, DateTime(2026, 6, 12, 23, 30));
    });

    test('returns null when departs_at missing or empty', () {
      expect(scheduleDepartsAt({'departure_date': '2026-06-13'}), isNull);
      expect(scheduleDepartsAt({'departs_at': ''}), isNull);
    });
  });

  group('departureText', () {
    test('shows real departure date and time when departs_at is set', () {
      final text = departureText({
        'departure_date': '2026-06-13',
        'departs_at': '2026-06-12 23:30:00',
      });

      expect(text, contains('12'));
      expect(text, contains('23:30 น.'));
      expect(text, isNot(contains('13 ')));
    });

    test('falls back to trip date when departs_at is absent', () {
      final text = departureText({'departure_date': '2026-06-13'});

      expect(text, contains('13'));
      expect(text, isNot(contains('น.')));
    });
  });
}
