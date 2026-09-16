import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/utils/share_card.dart';
import 'package:luilaykhao_app/widgets/trip_story_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// จอเริ่มต้นของ flutter_test สูง 600 ซึ่งเตี้ยกว่าการ์ด — ขยายให้พอ ไม่งั้น
/// การ์ดถูกบีบจนวัดขนาดจริงไม่ได้ (ของจริงอยู่ใต้ FittedBox ที่ไม่จำกัดความสูง)
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// รูปปกจิ๋ว 1×1 — มีไว้ให้พื้นหลังการ์ดเป็น Image ไม่ใช่ไล่เฉดสำรอง ซึ่งจะ
/// ไปปนกับไล่เฉดของเงาทับรูปตอนวัดความทึบ
final MemoryImage _pixelCover = MemoryImage(
  Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, //
    1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, //
    65, 84, 120, 218, 99, 168, 88, 208, 243, 31, 0, 5, 220, 2, 164, 95, 115, //
    186, 239, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130, //
  ]),
);

/// ความทึบสูงสุดของไล่เฉดทุกชั้นบนการ์ด — ใช้แทน "เงาทับรูปเข้มแค่ไหน"
double _maxGradientAlpha(WidgetTester tester) {
  var maxAlpha = 0.0;

  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(TripStoryCard),
      matching: find.byType(DecoratedBox),
    ),
  )) {
    final gradient = (box.decoration as BoxDecoration).gradient;
    if (gradient is! LinearGradient) continue;

    for (final color in gradient.colors) {
      if (color.a > maxAlpha) maxAlpha = color.a;
    }
  }

  return maxAlpha;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  group('StoryCountdown.fromDaysLeft', () {
    test('ตัวเลขยืนเดี่ยว หน่วยแยกออกมา เมื่อเหลือตั้งแต่ 2 วันขึ้นไป', () {
      final c = StoryCountdown.fromDaysLeft(12);

      expect(c.headline, '12');
      expect(c.unit, 'วัน');
      expect(c.kicker, 'อีก');
    });

    test('วันนี้/พรุ่งนี้ใช้คำเป็นตัวเด่น ไม่มีหน่วยห้อย', () {
      expect(StoryCountdown.fromDaysLeft(0).headline, 'วันนี้!');
      expect(StoryCountdown.fromDaysLeft(0).unit, isNull);
      expect(StoryCountdown.fromDaysLeft(1).headline, 'พรุ่งนี้!');
      expect(StoryCountdown.fromDaysLeft(1).unit, isNull);
    });

    test('ระหว่างเดินทางและรอบที่ยังไม่ระบุวันมีคำของตัวเอง', () {
      expect(StoryCountdown.fromDaysLeft(-2).headline, 'กำลังลุย');
      expect(StoryCountdown.fromDaysLeft(null).headline, 'เร็ว ๆ นี้');
    });

    test('ตัวเลขสามหลักย่อลงไม่ให้ล้นขอบการ์ด', () {
      expect(
        StoryCountdown.fromDaysLeft(120).headlineSize,
        lessThan(StoryCountdown.fromDaysLeft(12).headlineSize),
      );
    });
  });

  group('StoryStyle', () {
    test('ชื่อสไตล์ที่ไม่รู้จักตกมาที่คลาสสิก แทนที่จะพัง', () {
      expect(StoryStyle.fromName('mono'), StoryStyle.mono);
      expect(StoryStyle.fromName('ของที่ยังไม่มี'), StoryStyle.classic);
      expect(StoryStyle.fromName(null), StoryStyle.classic);
    });
  });

  group('TripStoryCard', () {
    testWidgets('วาดที่ 360×640 พอดี — เป็นที่มาของ PNG 1080×1920', (
      tester,
    ) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: TripStoryCard(
              tripTitle: 'เขาหลวงสุโขทัย',
              location: 'สุโขทัย',
              departureDate: null,
              daysLeft: 5,
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(TripStoryCard));

      expect(size.width, kStoryCardWidth);
      expect(size.height, kStoryCardHeight);
      expect(size.width / size.height, closeTo(9 / 16, 0.001));
    });

    testWidgets('แสดงชื่อทริป จุดหมาย และวันที่แบบไทย', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: TripStoryCard(
              tripTitle: 'เขาหลวงสุโขทัย',
              location: 'สุโขทัย',
              departureDate: DateTime(2026, 9, 5),
              daysLeft: 5,
            ),
          ),
        ),
      );

      expect(find.text('เขาหลวงสุโขทัย'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('วัน'), findsOneWidget);
      // วันที่เป็น พ.ศ. เสมอ ตามที่ thaiDateFull กำหนด
      expect(find.textContaining('2569'), findsOneWidget);
      expect(find.textContaining('สุโขทัย'), findsWidgets);
    });

    testWidgets('ไม่มีเลขที่จองอยู่บนการ์ด แม้จะส่งอะไรเข้ามาก็ตาม', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: TripStoryCard(
              tripTitle: 'เขาหลวงสุโขทัย',
              location: 'สุโขทัย',
              departureDate: null,
              daysLeft: 5,
            ),
          ),
        ),
      );

      // การ์ดตั้งใจไม่รับ booking_ref เข้ามาเลย — เทสนี้กันไม่ให้มีใครเติมทีหลัง
      expect(find.textContaining('LLK-'), findsNothing);
    });

    testWidgets('ไม่มี QR หรือคำชวนจองอยู่บนการ์ดอีกแล้ว', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: TripStoryCard(
              tripTitle: 'เขาหลวงสุโขทัย',
              location: 'สุโขทัย',
              departureDate: null,
              daysLeft: 5,
            ),
          ),
        ),
      );

      // การ์ดเป็นของเจ้าของทริป ไม่ใช่ป้ายโฆษณา — เทสนี้กันไม่ให้บล็อกชวนเพื่อน
      // กลับมาอยู่บนภาพที่คนเอาไปลงสตอรี่
      expect(find.text('สแกนมาลุยด้วยกัน'), findsNothing);
      expect(find.textContaining('ส่วนลด'), findsNothing);
      expect(find.byType(StoryLogo), findsOneWidget);
    });

    testWidgets('ทุกสไตล์วาดครบ ขนาดเท่าเดิม และยังบอกชื่อทริป', (
      tester,
    ) async {
      _useTallSurface(tester);

      for (final style in StoryStyle.values) {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: TripStoryCard(
                tripTitle: 'เขาหลวงสุโขทัย',
                location: 'สุโขทัย',
                departureDate: DateTime(2026, 9, 5),
                daysLeft: 5,
                style: style,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull, reason: style.name);
        expect(
          tester.getSize(find.byType(TripStoryCard)),
          const Size(kStoryCardWidth, kStoryCardHeight),
          reason: style.name,
        );
        expect(find.text('เขาหลวงสุโขทัย'), findsOneWidget, reason: style.name);
        expect(find.byType(StoryLogo), findsOneWidget, reason: style.name);
      }
    });

    testWidgets('ยิ่งเลื่อนความโปร่งใสขึ้น เงาที่ทับรูปยิ่งบาง', (
      tester,
    ) async {
      _useTallSurface(tester);

      Future<double> scrimAlphaAt(double photoOpacity) async {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: TripStoryCard(
                tripTitle: 'เขาหลวงสุโขทัย',
                location: 'สุโขทัย',
                departureDate: null,
                daysLeft: 5,
                coverImage: _pixelCover,
                photoOpacity: photoOpacity,
              ),
            ),
          ),
        );

        return _maxGradientAlpha(tester);
      }

      final dark = await scrimAlphaAt(0.0);
      final mid = await scrimAlphaAt(kStoryPhotoOpacityDefault);
      final clear = await scrimAlphaAt(1.0);

      expect(dark, greaterThan(mid));
      expect(mid, greaterThan(clear));
      // บางสุดก็ยังต้องมีเงาเหลือ ไม่งั้นตัวอักษรขาวบนท้องฟ้าจ้าอ่านไม่ออก
      expect(clear, greaterThan(0));
    });

    testWidgets('ชื่อทริปยาวถูกตัดท้าย ไม่ดันองค์ประกอบอื่นล้นการ์ด', (
      tester,
    ) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(
          Center(
            child: TripStoryCard(
              tripTitle: 'ทริปเดินป่า' * 20,
              location: 'จังหวัดที่มีชื่อยาวมาก' * 5,
              departureDate: DateTime(2026, 9, 5),
              daysLeft: 5,
              style: StoryStyle.poster,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TripStoryCard)).height, 640);
    });
  });

  group('StoryCountdown.recap', () {
    String fmt(num n) => n.toString();

    test('เชิดระยะทางก่อน เพราะเป็นตัวเลขที่คนอวดกัน', () {
      final c = StoryCountdown.recap(format: fmt, distanceKm: 12.4, days: 3);

      expect(c.headline, '12.4');
      expect(c.unit, 'กม.');
      expect(c.kicker, 'พิชิตแล้ว');
    });

    test('รอบที่ไม่ได้วัดระยะทางไว้ ใช้จำนวนวันแทน', () {
      final c = StoryCountdown.recap(format: fmt, days: 3);

      expect(c.headline, '3');
      expect(c.unit, 'วัน');
    });

    test('ไม่มีสถิติอะไรเลยก็ยังมีคำยืนเป็นตัวเด่น ไม่ปล่อยการ์ดโล่ง', () {
      final c = StoryCountdown.recap(format: fmt);

      expect(c.headline, 'พิชิตแล้ว');
      expect(c.unit, isNull);
    });
  });

  group('StoryPhotoFraming', () {
    const frame = Size(kStoryCardWidth, kStoryCardHeight);

    test(
      'รูปแนวนอนเลื่อนซ้ายขวาได้ตั้งแต่ยังไม่ซูม เพราะถูก cover ตัดข้างอยู่แล้ว',
      () {
        // รูป 4:3 ที่ cover ลงกรอบ 9:16 จะสูงพอดีกรอบแล้วล้นออกด้านข้าง —
        // ความสูงทั้งรูปยังอยู่ครบ หัวคนจึงไม่โดนตัด แต่เลือกได้ว่าจะเอาข้างไหน
        const framing = StoryPhotoFraming(aspectRatio: 4 / 3);

        final overflow = framing.overflowIn(frame);

        expect(overflow.dx, greaterThan(0));
        expect(overflow.dy, 0);
      },
    );

    test('รูป 9:16 พอดีกรอบ เลื่อนไม่ได้จนกว่าจะซูม', () {
      const fit = StoryPhotoFraming(aspectRatio: 9 / 16);
      const zoomed = StoryPhotoFraming(aspectRatio: 9 / 16, scale: 2);

      expect(fit.overflowIn(frame), Offset.zero);
      expect(zoomed.overflowIn(frame).dx, closeTo(kStoryCardWidth / 2, 0.01));
    });

    test('ลากเกินขอบถูกดึงกลับ ไม่ปล่อยให้ขอบว่างโผล่', () {
      const framing = StoryPhotoFraming(
        aspectRatio: 4 / 3,
        offset: Offset(500, 9999),
      );

      final clamped = framing.clampOffset(frame);
      final limit = framing.overflowIn(frame);

      expect(clamped.dx, limit.dx);
      expect(clamped.dy, 0);
    });

    test('ไม่รู้สัดส่วนรูป ก็ยังเลื่อนได้เท่าที่ซูมไว้', () {
      const framing = StoryPhotoFraming(scale: 1.5);

      final overflow = framing.overflowIn(frame);

      expect(overflow.dx, closeTo(kStoryCardWidth * 0.25, 0.01));
      expect(overflow.dy, closeTo(kStoryCardHeight * 0.25, 0.01));
    });
  });

  group('TripStoryCard.recap', () {
    testWidgets('ทุกสไตล์วาดการ์ดจบทริปได้ครบ พร้อมตัวเลขสรุป', (tester) async {
      _useTallSurface(tester);

      for (final style in StoryStyle.values) {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: TripStoryCard.recap(
                tripTitle: 'เขาหลวงสุโขทัย',
                location: 'สุโขทัย',
                dateLabel: '5 – 7 กันยายน 2569',
                highlight: StoryCountdown.recap(
                  format: (n) => '$n',
                  distanceKm: 12.4,
                ),
                stats: const [
                  StoryStat('1,240 ม.', 'ความสูงสะสม'),
                  StoryStat('8 คน', 'เพื่อนร่วมทาง'),
                ],
                style: style,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull, reason: style.name);
        expect(
          tester.getSize(find.byType(TripStoryCard)),
          const Size(kStoryCardWidth, kStoryCardHeight),
          reason: style.name,
        );
        // สไตล์ "เรียบ" รวมตัวนับเป็นบรรทัดเดียว ตัวเลขจึงอยู่ในข้อความยาว
        expect(find.textContaining('12.4'), findsOneWidget, reason: style.name);
        expect(find.text('1,240 ม.'), findsOneWidget, reason: style.name);
        expect(
          find.textContaining('5 – 7 กันยายน 2569'),
          findsOneWidget,
          reason: style.name,
        );
      }
    });

    testWidgets('การ์ดนับถอยหลังไม่มีแถวตัวเลขสรุปมาปน', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: TripStoryCard(
              tripTitle: 'เขาหลวงสุโขทัย',
              location: 'สุโขทัย',
              departureDate: null,
              daysLeft: 5,
            ),
          ),
        ),
      );

      expect(find.textContaining('ความสูงสะสม'), findsNothing);
    });
  });

  group('shareWidgetAsPng', () {
    testWidgets('จับภาพได้ 1080×1920 ที่ pixelRatio 3.0', (tester) async {
      _useTallSurface(tester);
      final key = GlobalKey();

      await tester.pumpWidget(
        _wrap(
          Center(
            child: RepaintBoundary(
              key: key,
              child: const TripStoryCard(
                tripTitle: 'เขาหลวงสุโขทัย',
                location: 'สุโขทัย',
                departureDate: null,
                daysLeft: 5,
              ),
            ),
          ),
        ),
      );

      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(
        pixelRatio: kShareCardPixelRatio,
      );

      expect(image.width, 1080);
      expect(image.height, 1920);
      image.dispose();
    });

    testWidgets('ย่อการ์ดให้พอดีจอแล้ว PNG ยังออกมา 1080×1920 เท่าเดิม', (
      tester,
    ) async {
      final key = GlobalKey();

      // เหมือนที่ share sheet ทำ: FittedBox ย่อเฉพาะตอนแสดงผล ส่วน
      // RepaintBoundary ยังจับภาพตามขนาด layout จริงของการ์ด
      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              height: 200,
              child: FittedBox(
                child: RepaintBoundary(
                  key: key,
                  child: const TripStoryCard(
                    tripTitle: 'เขาหลวงสุโขทัย',
                    location: 'สุโขทัย',
                    departureDate: null,
                    daysLeft: 5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(
        pixelRatio: kShareCardPixelRatio,
      );

      expect(image.width, 1080);
      expect(image.height, 1920);
      image.dispose();
    });

    testWidgets('บอกได้ว่าการ์ดยังไม่ถูกวาด แทนที่จะพังเงียบ ๆ', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));

      await expectLater(
        shareWidgetAsPng(boundaryKey: GlobalKey(), fileName: 'x.png'),
        throwsA(
          isA<ShareCardException>().having(
            (e) => e.reason,
            'reason',
            ShareCardFailure.notRendered,
          ),
        ),
      );
    });
  });
}
