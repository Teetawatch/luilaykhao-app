import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/review_dialog.dart';

void main() {
  group('bookingNeedsReview', () {
    test('returns true when booking has no matching review', () {
      final booking = {'id': 7};
      final reviews = [
        {'booking_id': 3, 'rating': 4},
        {'booking_id': 4, 'rating': 5},
      ];
      expect(bookingNeedsReview(booking, reviews), isTrue);
    });

    test('returns false when a review already exists', () {
      final booking = {'id': 7};
      final reviews = [
        {'booking_id': 7, 'rating': 5},
      ];
      expect(bookingNeedsReview(booking, reviews), isFalse);
    });

    test('matches even when review id is a string', () {
      final booking = {'id': 7};
      final reviews = [
        {'booking_id': '7'},
      ];
      expect(bookingNeedsReview(booking, reviews), isFalse);
    });

    test('returns false when booking id is missing', () {
      expect(bookingNeedsReview({}, [{'booking_id': 1}]), isFalse);
    });
  });
}
