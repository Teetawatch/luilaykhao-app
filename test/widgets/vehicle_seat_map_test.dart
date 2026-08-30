import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/theme/app_theme.dart';
import 'package:luilaykhao_app/widgets/vehicle_seat_map.dart';

/// ผังรถตู้ VIP ตั้งต้นแบบเดียวกับที่ `App\Support\SeatLayoutFactory` ส่งมา
Map<String, dynamic> vanSeatMap() => {
  'layout_kind': 'van',
  'rows': 4,
  'columns': ['A', 'B', 'C', '', 'D', 'E'],
  'front_seat': 'A1',
  'last_row_center': ['A4', 'B4', 'C4'],
  'seats': [
    for (final id in [
      'A1',
      'A2',
      'D2',
      'E2',
      'A3',
      'D3',
      'E3',
      'A4',
      'B4',
      'C4',
    ])
      {'id': id, 'label': id, 'status': 'available'},
  ],
};

/// รถบัส 2+2 แถวหลังยาว 5 ที่
Map<String, dynamic> busSeatMap({int rows = 11}) {
  final seats = <Map<String, dynamic>>[];
  for (var r = 1; r < rows; r++) {
    for (final c in ['A', 'B', 'C', 'D']) {
      seats.add({'id': '$c$r', 'label': '$c$r', 'status': 'available'});
    }
  }
  for (final c in ['A', 'B', 'C', 'D', 'E']) {
    seats.add({'id': '$c$rows', 'label': '$c$rows', 'status': 'available'});
  }

  return {
    'layout_kind': 'bus',
    'rows': rows,
    'columns': ['A', 'B', '', 'C', 'D', 'E'],
    'front_seat': null,
    'last_row_center': [
      for (final c in ['A', 'B', 'C', 'D', 'E']) '$c$rows',
    ],
    'seats': seats,
  };
}

/// ผังเล็กแบบไม่มีทางเดินและไม่มีที่นั่งคู่คนขับ (รถเก๋ง/ผังที่แอดมินวาดเอง)
Map<String, dynamic> gridSeatMap() => {
  'layout_kind': 'van',
  'rows': 3,
  'columns': ['A', 'B', 'C'],
  'front_seat': null,
  'last_row_center': [
    for (final r in [1, 2, 3])
      for (final c in ['A', 'B', 'C']) '$c$r',
  ],
  'seats': [
    for (final r in [1, 2, 3])
      for (final c in ['A', 'B', 'C'])
        {'id': '$c$r', 'label': '$c$r', 'status': 'available'},
  ],
};

Widget host(
  Map<String, dynamic> seatMap, {
  double width = 360,
  Set<String> selected = const {},
  void Function(String id)? onTap,
  void Function(String id)? onBlocked,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: VehicleSeatMap(
              seatMap: seatMap,
              toneFor: (seat, id) => selected.contains(id)
                  ? SeatTone.picking
                  : seat['status'] == 'booked'
                  ? SeatTone.booked
                  : SeatTone.available,
              selectableFor: (seat, _) => seat['status'] != 'booked',
              onSeatTap: (_, id) => onTap?.call(id),
              onBlockedSeatTap: (_, id) => onBlocked?.call(id),
            ),
          ),
        ),
      ),
    ),
  );
}

/// จุดกึ่งกลางแนวนอนของที่นั่ง
double centreX(WidgetTester tester, String seatId) {
  final rect = tester.getRect(find.text(seatId));
  return rect.center.dx;
}

/// จุดกึ่งกลางแนวนอนของบล็อกคนของรถ วัดจากป้ายใต้บล็อก
double crewCentreX(WidgetTester tester, String label) =>
    tester.getRect(find.text(label)).center.dx;

void main() {
  group('VehicleSeatMap · รถตู้', () {
    testWidgets('วาดครบทุกที่นั่ง คนขับ และท้ายรถ', (tester) async {
      await tester.pumpWidget(host(vanSeatMap()));

      for (final id in ['A1', 'A2', 'D2', 'E2', 'A3', 'A4', 'B4', 'C4']) {
        expect(find.text(id), findsOneWidget, reason: 'ที่นั่ง $id หายไป');
      }
      expect(find.text('คนขับ'), findsOneWidget);
      expect(find.text('หน้ารถ'), findsOneWidget);
    });

    testWidgets(
      'แถวหลังที่นั่งเรียงกลางต้องอยู่กึ่งกลางคัน ไม่เบี้ยวไปข้างใดข้างหนึ่ง',
      (tester) async {
        await tester.pumpWidget(host(vanSeatMap()));

        // A4,B4,C4 เรียงกลาง — จุดกึ่งกลางของ B4 ควรตรงกับกึ่งกลางของช่วงที่นั่ง
        // แถวบน (A2 ซ้ายสุด ถึง E2 ขวาสุด) ภายในไม่กี่พิกเซล
        final rowCentre = (centreX(tester, 'A2') + centreX(tester, 'E2')) / 2;
        expect((centreX(tester, 'B4') - rowCentre).abs(), lessThan(2));
      },
    );

    testWidgets('ไม่มีเลขแถวเมื่อแถวน้อย', (tester) async {
      await tester.pumpWidget(host(vanSeatMap()));

      // '2' เดี่ยว ๆ จะมีก็ต่อเมื่อมีคอลัมน์เลขแถว
      expect(find.text('2'), findsNothing);
    });
  });

  group('VehicleSeatMap · รถบัส', () {
    testWidgets('ผังทั้งคันพอดีความกว้างจอ ไม่ต้องเลื่อนซ้ายขวา', (
      tester,
    ) async {
      await tester.pumpWidget(host(busSeatMap()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byType(SingleChildScrollView),
        findsOneWidget,
        reason: 'ควรเหลือแค่ scroll แนวตั้งของหน้า ไม่มี scroll แนวนอนของผัง',
      );
    });

    testWidgets('มีเลขแถวช่วยนับเมื่อรถยาว', (tester) async {
      await tester.pumpWidget(host(busSeatMap()));

      expect(find.text('1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
    });

    testWidgets('แถวหลัง 5 ที่อยู่กึ่งกลาง และแถว 2+2 คร่อมทางเดิน', (
      tester,
    ) async {
      await tester.pumpWidget(host(busSeatMap()));

      final rowCentre = (centreX(tester, 'A1') + centreX(tester, 'D1')) / 2;
      expect((centreX(tester, 'C11') - rowCentre).abs(), lessThan(2));
      // ช่องทางเดินกว้างกว่าระยะห่างระหว่างที่นั่งข้างกัน
      final seatGap = centreX(tester, 'B1') - centreX(tester, 'A1');
      final aisleGap = centreX(tester, 'C1') - centreX(tester, 'B1');
      expect(aisleGap, greaterThan(seatGap * 1.4));
    });

    testWidgets('บัสคันเล็กบนจอแคบก็ยังไม่ overflow', (tester) async {
      await tester.pumpWidget(host(busSeatMap(rows: 6), width: 300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('VehicleSeatMap · หัวรถ', () {
    testWidgets('สตาฟอยู่ฝั่งซ้ายของคนขับ', (tester) async {
      await tester.pumpWidget(host(gridSeatMap()));

      expect(find.text('สตาฟ'), findsOneWidget);
      expect(
        crewCentreX(tester, 'สตาฟ'),
        lessThan(crewCentreX(tester, 'คนขับ')),
        reason: 'พวงมาลัยขวาแบบไทย สตาฟจึงต้องอยู่ซ้ายของคนขับเสมอ',
      );
    });

    testWidgets('สตาฟกับคนขับยืนตรงกับคอลัมน์ริมของผัง ไม่ลอยออกไปริมกล่อง', (
      tester,
    ) async {
      await tester.pumpWidget(host(gridSeatMap()));

      expect(
        (crewCentreX(tester, 'สตาฟ') - centreX(tester, 'A1')).abs(),
        lessThan(2),
      );
      expect(
        (crewCentreX(tester, 'คนขับ') - centreX(tester, 'C1')).abs(),
        lessThan(2),
      );
    });

    testWidgets('ป้ายหน้ารถอยู่กึ่งกลางคันจริง', (tester) async {
      await tester.pumpWidget(host(gridSeatMap()));

      final rowCentre = (centreX(tester, 'A1') + centreX(tester, 'C1')) / 2;
      expect(
        (crewCentreX(tester, 'หน้ารถ') - rowCentre).abs(),
        lessThan(2),
        reason: 'ป้ายอยู่คนละบรรทัดกับสตาฟ/คนขับ จึงไม่ควรถูกดันให้เยื้อง',
      );
    });

    testWidgets('รถตู้ยังวางที่นั่งคู่คนขับไว้ริมซ้ายเหมือนเดิม', (
      tester,
    ) async {
      await tester.pumpWidget(host(vanSeatMap()));

      expect(centreX(tester, 'A1'), lessThan(crewCentreX(tester, 'สตาฟ')));
      expect(
        crewCentreX(tester, 'สตาฟ'),
        lessThan(crewCentreX(tester, 'คนขับ')),
      );
      // คนขับอยู่ริมขวาของผัง ตรงกับที่นั่งริมขวาของแถว 2+ทางเดิน
      expect(
        (crewCentreX(tester, 'คนขับ') - centreX(tester, 'E2')).abs(),
        lessThan(2),
      );
    });

    testWidgets('ผังที่สั่งซ่อนสตาฟก็ต้องไม่วาด', (tester) async {
      final map = gridSeatMap()..['show_staff'] = false;
      await tester.pumpWidget(host(map));

      expect(find.text('สตาฟ'), findsNothing);
      expect(find.text('คนขับ'), findsOneWidget);
    });
  });

  group('VehicleSeatMap · การแตะ', () {
    testWidgets('แตะที่นั่งว่างเรียก onSeatTap', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(host(vanSeatMap(), onTap: tapped.add));

      await tester.tap(find.text('D2'));
      expect(tapped, ['D2']);
    });

    testWidgets('แตะที่นั่งที่จองแล้วเรียก onBlockedSeatTap แทนที่จะเงียบ', (
      tester,
    ) async {
      final map = vanSeatMap();
      (map['seats'] as List).firstWhere((s) => s['id'] == 'D2')['status'] =
          'booked';
      final blocked = <String>[];
      final tapped = <String>[];

      await tester.pumpWidget(
        host(map, onTap: tapped.add, onBlocked: blocked.add),
      );

      await tester.tap(find.text('D2'));
      expect(blocked, ['D2']);
      expect(tapped, isEmpty);
    });
  });
}
