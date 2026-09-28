import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/models/medal_social.dart';
import 'package:luilaykhao_app/models/trip_medal.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/challenges_screen.dart';
import 'package:luilaykhao_app/screens/year_review_screen.dart';
import 'package:luilaykhao_app/widgets/medal_round_section.dart';
import 'package:provider/provider.dart';

import '../models/trip_medal_test.dart' show medalJson;

Map<String, dynamic> _entry(
  int id,
  String name, {
  bool me = false,
  int kudos = 0,
  bool mine = false,
}) => {
  'medal_id': id,
  'holder_name': name,
  'avatar_url': null,
  'finisher_no': id,
  'finisher_label': 'Finisher #$id',
  'is_me': me,
  'kudos_count': kudos,
  'kudoed_by_me': mine,
};

Map<String, dynamic> _challenge(
  String key,
  double current,
  double target, {
  bool done = false,
}) => {
  'key': key,
  'title': 'ชาเลนจ์ $key',
  'description': 'คำอธิบาย',
  'metric': key == 'year_distance' ? 'distance' : 'trips',
  'icon': 'hiking',
  'current': current,
  'target': target,
  'unit': key == 'year_distance' ? 'กม.' : 'ทริป',
  'progress': (current / target).clamp(0, 1),
  'completed': done,
  'completed_on': done ? '2026-09-05' : null,
};

Map<String, dynamic> _review({int trips = 2}) => {
  'year': 2026,
  'year_label': '2569',
  'available_years': trips == 0 ? <int>[2025] : [2026, 2025],
  'holder_name': 'ต้น',
  'trips_count': trips,
  'distance_km': trips == 0 ? 0 : 52.5,
  'climb_m': trips == 0 ? 0 : 2700,
  'inthanon_multiple': trips == 0 ? 0 : 1.1,
  'days_on_trail': trips == 0 ? 0 : 7,
  'gps_trips': 1,
  'months_active': 2,
  'top_month': 'กันยายน',
  'top_month_trips': 1,
  'places': trips == 0 ? <String>[] : ['ภาคเหนือ', '🇱🇦 ลาว'],
  'longest': trips == 0 ? null : {'name': 'โบลาเวน', 'distance_km': 32.5},
  'highest': trips == 0 ? null : {'name': 'ดอยหลวง', 'elevation_m': 2170},
  'companions_count': 5,
  'kudos_received': 3,
  'challenges_completed': 2,
  'medals': [
    for (var i = 0; i < trips; i++)
      {
        'id': i + 1,
        'finisher_label': 'Finisher #${i + 1}',
        'earned_on': '2026-0${i + 3}-05',
        'design': {'name': 'ทริป $i', 'icon': 'hiking', 'color': '#15803D'},
      },
  ],
};

class _FakeApp extends AppProvider {
  bool failKudos = false;
  int kudosCalls = 0;
  int? requestedYear;
  YearReview review = YearReview.fromJson(_review());

  @override
  Future<MedalRound> fetchMedalRound(int medalId) async => MedalRound.fromJson({
    'trip_name': 'โบลาเวน',
    'finishers': [
      _entry(1, 'ต้น', me: true, kudos: 2),
      _entry(2, 'เจ'),
      _entry(3, 'บี', kudos: 4, mine: true),
    ],
  });

  @override
  Future<({bool kudoed, int count})> toggleMedalKudos(int medalId) async {
    kudosCalls++;
    if (failKudos) throw Exception('offline');
    return medalId == 2 ? (kudoed: true, count: 1) : (kudoed: false, count: 3);
  }

  @override
  Future<ChallengeBoard> fetchChallenges() async => ChallengeBoard.fromJson({
    'month': {
      'period': '2026-09',
      'label': 'กันยายน 2569',
      'days_left': 2,
      'challenges': [_challenge('month_trip', 1, 1, done: true)],
    },
    'year': {
      'period': '2026',
      'label': 'ปี 2569',
      'days_left': 94,
      'challenges': [_challenge('year_distance', 52.5, 100)],
    },
    'history': const [
      {
        'title': 'ลุยประจำเดือน',
        'icon': 'event_available',
        'period_label': 'กันยายน 2569',
        'completed_label': '5 กันยายน 2569',
      },
    ],
  });

  @override
  Future<YearReview> fetchYearReview([int? year]) async {
    requestedYear = year;
    return review;
  }
}

Widget _host(_FakeApp app, Widget child) =>
    ChangeNotifierProvider<AppProvider>.value(
      value: app,
      child: MaterialApp(home: child),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('models', () {
    test('ชาเลนจ์แสดงความคืบหน้าอ่านง่าย', () {
      final distance = ChallengeItem.fromJson(
        _challenge('year_distance', 52.5, 100),
      );
      expect(distance.progressLabel, '52.5 / 100 กม.');
      expect(distance.progress, 0.525);

      final climb = ChallengeItem.fromJson({
        ..._challenge('year_climb', 5400, 5000, done: true),
        'metric': 'climb',
        'unit': 'ม.',
      });
      // ทำเกินเป้าแล้วแสดงแค่เป้า ไม่ใช่ 5,400 / 5,000
      expect(climb.progressLabel, '5,000 / 5,000 ม.');
      expect(climb.completedOn, DateTime(2026, 9, 5));
    });

    test('สรุปปีอ่านครบ และปีว่างไม่พัง', () {
      final r = YearReview.fromJson(_review());
      expect(r.tripsCount, 2);
      expect(r.longest!.distanceKm, 32.5);
      expect(r.highest!.elevationM, 2170);
      expect(r.medals.first.buddhistYear, 2569);

      final empty = YearReview.fromJson(_review(trips: 0));
      expect(empty.isEmpty, isTrue);
      expect(empty.longest, isNull);
    });

    test('ตัวอักษรแทนรูปโปรไฟล์ข้ามสระหน้า', () {
      expect(avatarInitial('เจ'), 'จ');
      expect(avatarInitial('ไผ่'), 'ผ่');
      expect(avatarInitial('ต้น'), 'ต้');
      expect(avatarInitial('Ann'), 'A');
      expect(avatarInitial('  '), '?');
    });

    test('เหรียญในตู้มีจำนวนปรบมือ', () {
      final medal = TripMedal.fromJson(
        medalJson(
          overrides: {
            'kudos_count': 3,
            'kudos_recent': ['เจ', 'บี'],
          },
        ),
      );
      expect(medal.kudosCount, 3);
      expect(medal.kudosRecent, ['เจ', 'บี']);
    });
  });

  group('ปรบมือ', () {
    final medal = TripMedal.fromJson(
      medalJson(
        overrides: {
          'kudos_count': 2,
          'kudos_recent': ['เจ'],
        },
      ),
    );

    Widget section(_FakeApp app) => _host(
      app,
      Scaffold(
        backgroundColor: Colors.black,
        body: SingleChildScrollView(child: MedalRoundSection(medal: medal)),
      ),
    );

    testWidgets('แสดงเพื่อนร่วมรอบ และปรบมือแล้วนับทันที', (tester) async {
      _tall(tester);
      final app = _FakeApp();
      await tester.pumpWidget(section(app));
      await tester.pumpAndSettle();

      expect(find.text('คนที่พิชิตรอบนี้ (3)'), findsOneWidget);
      expect(find.text('ต้น (คุณ)'), findsOneWidget);
      expect(find.textContaining('เจ และอีก 1 คนปรบมือให้คุณ'), findsOneWidget);

      await tester.tap(find.text('ปรบมือ'));
      await tester.pumpAndSettle();

      expect(app.kudosCalls, 1);
      expect(find.text('ปรบมือ'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('ส่งไม่สำเร็จ ค่าย้อนกลับ', (tester) async {
      _tall(tester);
      final app = _FakeApp()..failKudos = true;
      await tester.pumpWidget(section(app));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ปรบมือ'));
      await tester.pumpAndSettle();

      expect(find.text('ปรบมือ'), findsOneWidget);
      expect(find.text('ปรบมือไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    });
  });

  testWidgets('หน้าชาเลนจ์แสดงเดือน/ปี และประวัติ', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(_FakeApp(), const ChallengesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('เดือนนี้ · กันยายน 2569'), findsOneWidget);
    expect(find.text('ปีนี้ · ปี 2569'), findsOneWidget);
    expect(find.text('52.5 / 100 กม.'), findsOneWidget);
    expect(find.text('สำเร็จแล้ว'), findsOneWidget);
    expect(find.text('เหลืออีก 94 วัน'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ลุยประจำเดือน'), 200);
    expect(find.text('ลุยประจำเดือน'), findsOneWidget);
  });

  group('สรุปทั้งปี', () {
    testWidgets('ไล่สไลด์ได้จนถึงการ์ดแชร์ ไม่มีอะไรล้น', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_host(_FakeApp(), const YearReviewScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ปีนี้ของต้น'), findsOneWidget);

      // intro, ระยะทาง, เวลา, ไฮไลต์, เพื่อน, เหรียญ, แชร์
      for (var i = 0; i < 6; i++) {
        await tester.tapAt(const Offset(400, 400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'slide ${i + 1}');
      }

      expect(find.text('แชร์สรุปปีนี้'), findsOneWidget);
      expect(find.text('ม. ที่ไต่'), findsOneWidget);
    });

    testWidgets('ปีที่ยังไม่มีทริป มีสไลด์เดียวและชิปเลือกปีอื่น', (
      tester,
    ) async {
      _tall(tester);
      final app = _FakeApp()..review = YearReview.fromJson(_review(trips: 0));
      await tester.pumpWidget(_host(app, const YearReviewScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่มีทริปที่พิชิต'), findsOneWidget);
      expect(find.text('ปี 2568'), findsOneWidget);

      await tester.tap(find.text('ปี 2568'));
      await tester.pumpAndSettle();
      expect(app.requestedYear, 2025);
    });
  });
}
