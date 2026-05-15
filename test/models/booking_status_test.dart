import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/models/booking_status.dart';

void main() {
  group('BookingStatus.parse', () {
    test('maps known strings', () {
      expect(BookingStatus.parse('pending'), BookingStatus.pending);
      expect(BookingStatus.parse('confirmed'), BookingStatus.confirmed);
      expect(BookingStatus.parse('cancelled'), BookingStatus.cancelled);
      expect(BookingStatus.parse('canceled'), BookingStatus.cancelled);
      expect(BookingStatus.parse('refunded'), BookingStatus.refunded);
      expect(BookingStatus.parse('completed'), BookingStatus.completed);
    });

    test('returns unknown for null or junk', () {
      expect(BookingStatus.parse(null), BookingStatus.unknown);
      expect(BookingStatus.parse(''), BookingStatus.unknown);
      expect(BookingStatus.parse('nope'), BookingStatus.unknown);
    });

    test('trims and lowercases', () {
      expect(BookingStatus.parse('  CONFIRMED  '), BookingStatus.confirmed);
    });
  });

  test('isTerminal categorises correctly', () {
    expect(BookingStatus.pending.isTerminal, isFalse);
    expect(BookingStatus.confirmed.isTerminal, isFalse);
    expect(BookingStatus.cancelled.isTerminal, isTrue);
    expect(BookingStatus.refunded.isTerminal, isTrue);
    expect(BookingStatus.completed.isTerminal, isTrue);
    expect(BookingStatus.failed.isTerminal, isTrue);
  });

  test('extension reads from map', () {
    final booking = {'status': 'confirmed'};
    expect(booking.bookingStatus, BookingStatus.confirmed);
  });
}
