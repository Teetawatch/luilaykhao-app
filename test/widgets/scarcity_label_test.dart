import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/screens/customer_app_screen.dart';

void main() {
  group('tripScarcityLabel', () {
    test('states the seat count without urgency wording', () {
      expect(
        tripScarcityLabel({'seats_left': 2}),
        'เหลือ 2 ที่นั่ง',
      );
      expect(
        tripScarcityLabel({'seats_left': 5}),
        'เหลือ 5 ที่นั่ง',
      );
    });

    test('says nothing when there is no shortage to report', () {
      expect(tripScarcityLabel({'seats_left': 6}), isNull);
      expect(tripScarcityLabel({'seats_left': 0}), isNull);
      expect(tripScarcityLabel(const {}), isNull);
    });

    test('still tiers internally so styling can differ', () {
      expect(tripScarcityLevel({'seats_left': 2}), 'last');
      expect(tripScarcityLevel({'seats_left': 4}), 'soon');
      expect(tripScarcityLevel({'seats_left': 9}), isNull);
    });
  });
}
