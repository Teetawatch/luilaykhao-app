import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/models/trip_medal.dart';
import 'package:luilaykhao_app/widgets/medal_route.dart';
import 'package:luilaykhao_app/widgets/medal_share_sheet.dart';
import 'package:luilaykhao_app/widgets/medal_story_card.dart';
import 'package:luilaykhao_app/widgets/trip_story_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip_medal_test.dart' show medalJson;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _route({String source = 'recorded'}) => {
  'source': source,
  'aspect': 0.4,
  'points': [
    for (var i = 0; i < 30; i++) [0.3 + (i % 5) * 0.05, 1 - i / 29],
  ],
  'elevations': [for (var i = 0; i < 48; i++) 900 + i * 8],
};

const _personal = {
  'distance_km': 12.4,
  'elevation_gain_m': 1350,
  'moving_seconds': 19800,
  'avg_speed_kmh': 2.3,
  'max_elevation_m': 1780,
};

void main() {
  final withRoute = TripMedal.fromJson(
    medalJson(
      overrides: {
        'route': _route(),
        'personal': _personal,
        'records': ['distance', 'altitude'],
      },
    ),
  );
  final plannedOnly = TripMedal.fromJson(
    medalJson(overrides: {'route': _route(source: 'planned')}),
  );
  final bare = TripMedal.fromJson(medalJson());

  group('model', () {
    test('อ่านเส้นทาง ตัวเลข GPS และสถิติส่วนตัว', () {
      expect(withRoute.route!.isRecorded, isTrue);
      expect(withRoute.route!.points, hasLength(30));
      expect(withRoute.route!.elevations, hasLength(48));
      expect(withRoute.personal!.distanceKm, 12.4);
      expect(withRoute.personal!.movingSeconds, 19800);
      expect(withRoute.records, ['distance', 'altitude']);
      expect(bare.route, isNull);
      expect(bare.personal, isNull);
      expect(bare.records, isEmpty);
    });

    test('ข้อมูลเสียไม่ทำให้พัง', () {
      expect(MedalRoute.fromJson({'points': []}), isNull);
      expect(
        MedalRoute.fromJson({
          'points': [
            [0.1, 0.1],
            'x',
            [5, -3],
          ],
          'elevations': [1],
        })!.points,
        [const Offset(0.1, 0.1), const Offset(1, 0)],
      );
      expect(MedalPersonal.fromJson({'distance_km': 0}), isNull);
    });

    test('เวลาเดินเป็นภาษาไทย', () {
      expect(formatMovingTime(30), isNull);
      expect(formatMovingTime(45 * 60), '45 น.');
      expect(formatMovingTime(2 * 3600), '2 ชม.');
      expect(formatMovingTime(5 * 3600 + 30 * 60), '5 ชม. 30 น.');
      expect(formatMovingTimeShort(5 * 3600 + 30 * 60), '5:30 ชม.');
      expect(formatMovingTimeShort(3600 + 5 * 60), '1:05 ชม.');
      expect(formatMovingTimeShort(45 * 60), '45 น.');
      expect(formatMovingTimeShort(10), isNull);
      expect(medalRecordLabel('distance'), 'เดินไกลที่สุดของฉัน');
      expect(medalRecordLabel('unknown'), 'สถิติใหม่ของฉัน');
    });
  });

  group('การ์ด', () {
    testWidgets('รูปแบบเส้นทาง ทุกพื้นหลัง ไม่ล้น และวาดเส้นทาง+กราฟ', (
      tester,
    ) async {
      _useTallSurface(tester);

      for (final medal in [withRoute, plannedOnly]) {
        for (final backdrop in MedalBackdrop.values) {
          for (final scale in [kMedalScaleMin, kMedalScaleMax]) {
            await tester.pumpWidget(
              _wrap(
                MedalStoryCard(
                  medal: medal,
                  backdrop: backdrop,
                  layout: MedalCardLayout.route,
                  medalScale: scale,
                ),
              ),
            );

            expect(
              tester.getSize(find.byType(MedalStoryCard)),
              const Size(kStoryCardWidth, kStoryCardHeight),
            );
            expect(tester.takeException(), isNull, reason: backdrop.name);
            expect(find.byType(MedalRouteView), findsOneWidget);
            expect(find.byType(MedalElevationView), findsOneWidget);
            if (medal.personal != null) {
              expect(find.text('5:30 ชม.'), findsOneWidget);
            }
          }
        }
      }
    });

    testWidgets('เหรียญไม่มีเส้นทาง เลือกรูปแบบเส้นทาง → ถอยเป็นกลางการ์ด', (
      tester,
    ) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(MedalStoryCard(medal: bare, layout: MedalCardLayout.route)),
      );

      expect(find.byType(MedalRouteView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ใช้ตัวเลขจาก GPS ของตัวเองก่อน พร้อมป้ายสถิติส่วนตัว', (
      tester,
    ) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_wrap(MedalStoryCard(medal: withRoute)));

      expect(find.text('12.4 กม.'), findsOneWidget);
      expect(find.text('5 ชม. 30 น.'), findsOneWidget);
      expect(find.text('1,350 ม.'), findsOneWidget);
      expect(find.text('จาก GPS ที่ฉันบันทึก'), findsOneWidget);
      expect(find.text('เดินไกลที่สุดของฉัน'), findsOneWidget);
      expect(find.text('ขึ้นสูงที่สุดของฉัน'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          MedalStoryCard(
            medal: withRoute,
            parts: const MedalCardParts(records: false),
          ),
        ),
      );
      expect(find.text('เดินไกลที่สุดของฉัน'), findsNothing);
    });

    testWidgets('ไม่มี GPS ใช้ตัวเลขของทริปตามเดิม', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_wrap(MedalStoryCard(medal: plannedOnly)));

      expect(find.text('32.5 กม.'), findsOneWidget);
      expect(find.text('จาก GPS ที่ฉันบันทึก'), findsNothing);
    });

    testWidgets('สติกเกอร์โปร่งใสไม่มีพื้นสีใด ๆ', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(
          MedalStoryCard(
            medal: withRoute,
            backdrop: MedalBackdrop.transparent,
            layout: MedalCardLayout.route,
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(MedalStoryCard),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });
  });

  group('หน้าแชร์', () {
    testWidgets('ชิปเส้นทาง/สถิติส่วนตัวโผล่เฉพาะเหรียญที่มีข้อมูล', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      _useTallSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MedalShareSheet(medal: bare)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('รูปแบบ'));
      await tester.pumpAndSettle();
      expect(find.text('เส้นทาง'), findsNothing);
      await tester.tap(find.text('ข้อมูล'));
      await tester.pumpAndSettle();
      expect(find.text('สถิติส่วนตัว'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MedalShareSheet(medal: withRoute)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('รูปแบบ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เส้นทาง'));
      await tester.pumpAndSettle();
      expect(find.byType(MedalRouteView), findsOneWidget);
      await tester.tap(find.text('ข้อมูล'));
      await tester.pumpAndSettle();
      expect(find.text('สถิติส่วนตัว'), findsOneWidget);
      expect(find.text('ตัวเลขจาก GPS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('เลือกสติกเกอร์โปร่งใสแล้วมีคำแนะนำวิธีใช้กับ IG', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      _useTallSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MedalShareSheet(medal: withRoute)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('สติกเกอร์โปร่งใส'));
      await tester.pumpAndSettle();

      expect(find.textContaining('IG Story'), findsOneWidget);
      expect(
        tester.widget<MedalStoryCard>(find.byType(MedalStoryCard)).backdrop,
        MedalBackdrop.transparent,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
