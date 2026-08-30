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

    testWidgets('บล็อก QR ชวนเพื่อนโผล่เมื่อมีลิงก์ และหายไปเมื่อไม่มี', (
      tester,
    ) async {
      Future<void> pumpWith(String? url) => tester.pumpWidget(
        _wrap(
          Center(
            child: TripStoryCard(
              tripTitle: 'เขาหลวงสุโขทัย',
              location: 'สุโขทัย',
              departureDate: null,
              daysLeft: 5,
              shareUrl: url,
            ),
          ),
        ),
      );

      await pumpWith(null);
      expect(find.text('สแกนมาลุยด้วยกัน'), findsNothing);

      await pumpWith('https://luilaykhao.com/join/ABC123');
      expect(find.text('สแกนมาลุยด้วยกัน'), findsOneWidget);
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
              shareUrl: 'https://luilaykhao.com/join/ABC123',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TripStoryCard)).height, 640);
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
