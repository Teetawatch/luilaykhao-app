import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/models/trip_medal.dart';
import 'package:luilaykhao_app/screens/medals_screen.dart';
import 'package:luilaykhao_app/widgets/medal_art.dart';
import 'package:luilaykhao_app/widgets/medal_story_card.dart';
import 'package:luilaykhao_app/widgets/trip_story_card.dart';

import '../models/trip_medal_test.dart' show medalJson;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  final medal = TripMedal.fromJson(medalJson());

  test('ไอคอนทุกชื่อที่เซิร์ฟเวอร์ส่งมามีตัวจริง ชื่อแปลกได้ภูเขา', () {
    const names = [
      'hiking',
      'landscape',
      'terrain',
      'flag',
      'forest',
      'water',
      'coffee',
      'local_fire_department',
      'wb_sunny',
      'waves',
      'scuba_diving',
      'kayaking',
      'ac_unit',
      'temple_buddhist',
    ];

    for (final name in names.where((n) => n != 'landscape')) {
      expect(medalIconFor(name), isNot(Icons.landscape_rounded), reason: name);
    }
    expect(medalIconFor('something-new'), Icons.landscape_rounded);
  });

  testWidgets('เหรียญแม่แบบวาดชื่อกับไอคอน ในกรอบสัดส่วนเหรียญ', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(MedalArt(design: medal.design, size: 200, year: 2569)),
    );

    expect(find.text('เดินป่าลาวใต้ ที่ราบสูงโบลาเวน'), findsOneWidget);
    expect(find.byIcon(Icons.coffee_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(MedalArt)), const Size(200, 236));
    expect(tester.takeException(), isNull);
  });

  test('ตัวอักษรรอบขอบตรงกับ MedalGeometry::ringText และใช้ปี พ.ศ.', () {
    expect(medal.buddhistYear, 2569);
    expect(medalRingText(2569), 'LUILAYKHAO  •  FINISHER  •  2569');
    expect(medalRingText(null), 'LUILAYKHAO  •  FINISHER');
  });

  testWidgets('ชื่อยาวมากไม่ล้นดวงเหรียญ', (tester) async {
    final long = MedalDesign(
      name: 'เดินป่าข้ามสามจังหวัด ผ่านทะเลหมอกและน้ำตกเจ็ดชั้นกลางป่าดิบ',
      icon: 'hiking',
      color: medal.design.color,
    );

    await tester.pumpWidget(_wrap(MedalArt(design: long, size: 120)));

    expect(tester.takeException(), isNull);
  });

  testWidgets('แตะเหรียญแล้วพลิกไปเห็นเลข Finisher กับชื่อเจ้าของ', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(MedalFlip(medal: medal, size: 220)));

    expect(find.text('#27'), findsNothing);

    await tester.tap(find.byType(MedalFlip));
    await tester.pumpAndSettle();

    expect(find.text('#27'), findsOneWidget);
    expect(find.text('ต้น'), findsOneWidget);
    expect(find.text('32.5 กม.  ·  +1,200 ม.'), findsOneWidget);

    await tester.tap(find.byType(MedalFlip));
    await tester.pumpAndSettle();

    expect(find.text('#27'), findsNothing);
  });

  testWidgets('การ์ดสตอรี่เป็น 360×640 เสมอ และบอกว่ามาครั้งที่เท่าไร', (
    tester,
  ) async {
    _useTallSurface(tester);

    for (final backdrop in MedalBackdrop.values) {
      await tester.pumpWidget(
        _wrap(MedalStoryCard(medal: medal, backdrop: backdrop)),
      );

      expect(
        tester.getSize(find.byType(MedalStoryCard)),
        const Size(kStoryCardWidth, kStoryCardHeight),
      );
      expect(tester.takeException(), isNull, reason: backdrop.name);
    }

    expect(
      find.textContaining('ครั้งที่ 2', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('ต้น'), findsOneWidget);
    expect(find.text('ระยะทาง'), findsOneWidget);
  });

  testWidgets('การ์ดสตอรี่ไม่มีเลขที่จอง', (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(MedalStoryCard(medal: medal)));

    expect(find.textContaining('LLK-'), findsNothing);
  });

  testWidgets('ฉากฉลองคืน true เมื่อกดแชร์ และ false เมื่อเก็บเข้าตู้', (
    tester,
  ) async {
    _useTallSurface(tester);
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showMedalUnlock(context, [
                  medal,
                  TripMedal.fromJson(medalJson(overrides: {'id': 8})),
                ]);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text('ยินดีด้วย! คุณได้รับเหรียญพิชิต'), findsOneWidget);
    expect(find.textContaining('และอีก 1 เหรียญ'), findsOneWidget);

    await tester.tap(find.text('แชร์ความภูมิใจ'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, isTrue);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.tap(find.text('เก็บเข้าตู้เหรียญ'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, isFalse);
  });
}
