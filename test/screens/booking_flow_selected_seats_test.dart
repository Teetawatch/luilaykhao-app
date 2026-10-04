import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/screens/booking_flow_screen.dart';

/// การ์ด "ที่นั่งที่เลือก" ใต้ผัง — ชิปเคยถูกห่อด้วยกล่อง 44×44 ตายตัวจนล้น
/// และเรียงตามตัวอักษร (A1, A10, A2) ไม่ตรงกับลำดับบนผัง
void main() {
  Map<String, dynamic> seat(String id, int row, int column, {String? status}) =>
      {
        'id': id,
        'label': id,
        'row': row,
        'column': column,
        'col': id.substring(0, 1),
        'status': status ?? 'available',
      };

  final seatMap = <String, dynamic>{
    'has_seat_map': true,
    'total_seats': 6,
    'available_seats': 5,
    'seats': [
      seat('A1', 1, 1),
      seat('A2', 2, 1),
      seat('D2', 2, 5),
      seat('E2', 2, 6),
      seat('A10', 10, 1),
      seat('B10', 10, 2, status: 'booked'),
    ],
  };

  Future<List<String>> pump(
    WidgetTester tester,
    Set<String> selected,
  ) async {
    final removed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SeatSelectionSection(
              seatMap: seatMap,
              isLoading: false,
              error: null,
              selectedSeatIds: selected,
              onSeatTap: (seat) => removed.add(seat['id'].toString()),
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return removed;
  }

  Finder chip(String label) => find.bySemanticsLabel('เอาที่นั่ง $label ออก');

  testWidgets('chips render whole, in seat-map order', (tester) async {
    await pump(tester, {'A10', 'D2', 'A2', 'A1'});

    expect(tester.takeException(), isNull);
    expect(find.text('ที่นั่งที่เลือก 4 ที่'), findsOneWidget);

    final xs = [
      for (final id in ['A1', 'A2', 'D2', 'A10'])
        tester.getTopLeft(chip(id)),
    ];
    for (var i = 1; i < xs.length; i++) {
      final prev = xs[i - 1];
      final cur = xs[i];
      expect(
        cur.dy > prev.dy || (cur.dy == prev.dy && cur.dx > prev.dx),
        isTrue,
        reason: 'chip $i should come after chip ${i - 1}',
      );
    }
    // ชิปกว้างกว่ากล่อง 44 ได้ — ไม่ถูกบีบ
    expect(tester.getSize(chip('A10')).width, greaterThan(44));
    expect(tester.getSize(chip('A10')).height, greaterThanOrEqualTo(44));
  });

  testWidgets('tapping a chip asks to remove that seat', (tester) async {
    final removed = await pump(tester, {'A2', 'D2'});

    await tester.tap(chip('D2'));
    expect(removed, ['D2']);
  });

  testWidgets('a seat missing from the reloaded map can still be removed', (
    tester,
  ) async {
    final removed = await pump(tester, {'A1', 'Z9'});

    await tester.tap(chip('Z9'));
    expect(removed, ['Z9']);
  });
}
