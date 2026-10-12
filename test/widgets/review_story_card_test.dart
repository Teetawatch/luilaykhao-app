import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/utils/share_card.dart';
import 'package:luilaykhao_app/widgets/review_story_card.dart';
import 'package:luilaykhao_app/widgets/trip_story_card.dart';

/// การ์ดคำรีวิว — คำของลูกค้าเองต้องพอดีการ์ดทุกพื้น ไม่ว่าจะเขียนยาวแค่ไหน
void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  group('reviewQuoteExcerpt', () {
    test('คำสั้นคงเดิม ช่องว่างซ้อนถูกยุบ', () {
      expect(reviewQuoteExcerpt('  วิวสวย\n\nมาก  '), 'วิวสวย มาก');
    });

    test('คำยาวถูกตัดที่ช่องว่างก่อนเพดาน แล้วต่อด้วย …', () {
      final long = List.filled(80, 'สนุกมาก').join(' ');
      final cut = reviewQuoteExcerpt(long);

      expect(cut.length, lessThanOrEqualTo(kReviewQuoteMaxLength + 1));
      expect(cut, endsWith('…'));
      expect(cut, isNot(contains('สนุกม…')));
    });

    test('ภาษาไทยติดกันยาวไม่มีช่องว่าง ตัดตรงเพดาน', () {
      final cut = reviewQuoteExcerpt('ก' * 400);
      expect(cut.length, kReviewQuoteMaxLength + 1);
    });
  });

  test('คำบรรยายมีคำรีวิว ดาว ชื่อทริป ลิงก์ และแฮชแท็ก', () {
    final caption = reviewShareCaption(
      comment: 'ทะเลหมอกสวยที่สุด',
      rating: 5,
      tripTitle: 'ภูกระดึง',
      tripUrl: 'https://luilaykhao.com/trips/phu-kradueng',
    );

    expect(caption, contains('“ทะเลหมอกสวยที่สุด”'));
    expect(caption, contains('⭐⭐⭐⭐⭐'));
    expect(caption, contains('รีวิวทริป ภูกระดึง'));
    expect(caption, contains('https://luilaykhao.com/trips/phu-kradueng'));
    expect(caption, endsWith('#ลุยเลเขา'));

    expect(
      reviewShareCaption(comment: 'ดี', rating: 4, tripTitle: 'x'),
      isNot(contains('http')),
    );
  });

  testWidgets('ทุกพื้นวาดได้ คำยาวสุดก็ไม่ล้น การ์ดเต็ม 360×640', (
    tester,
  ) async {
    tall(tester);
    final longest = 'ท' * kReviewQuoteMaxLength;

    for (final backdrop in ReviewBackdrop.values) {
      for (final comment in ['ดีมาก', longest]) {
        await tester.pumpWidget(
          wrap(
            ReviewStoryCard(
              comment: comment,
              rating: 5,
              tripTitle: 'ดอยหลวงเชียงดาว ' * 4,
              reviewerName: 'สมศรี',
              backdrop: backdrop,
            ),
          ),
        );

        expect(tester.takeException(), isNull, reason: backdrop.name);
        final size = tester.getSize(find.byType(ReviewStoryCard));
        expect(size.width, kStoryCardWidth, reason: backdrop.name);
        if (backdrop == ReviewBackdrop.sticker) {
          expect(size.height, lessThan(kStoryCardHeight));
        } else {
          expect(size.height, kStoryCardHeight, reason: backdrop.name);
        }
      }
    }
  });

  testWidgets('ปิดชื่อ = ไม่มีบรรทัดลงชื่อ', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      wrap(
        const ReviewStoryCard(
          comment: 'สนุก',
          rating: 5,
          tripTitle: 'ภูกระดึง',
          reviewerName: 'สมศรี',
        ),
      ),
    );
    expect(find.text('— สมศรี'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        const ReviewStoryCard(
          comment: 'สนุก',
          rating: 5,
          tripTitle: 'ภูกระดึง',
          reviewerName: 'สมศรี',
          showName: false,
        ),
      ),
    );
    expect(find.text('— สมศรี'), findsNothing);
  });

  testWidgets('ดาวเต็มเท่าคะแนนที่ให้', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      wrap(
        const ReviewStoryCard(comment: 'ดี', rating: 4, tripTitle: 'ภูกระดึง'),
      ),
    );

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
  });

  testWidgets('การ์ดเต็มใบได้ PNG 1080×1920 มุมทึบ สติกเกอร์มุมใส', (
    tester,
  ) async {
    tall(tester);

    Future<(ui.Image, List<int>)> capture(ReviewBackdrop backdrop) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        wrap(
          RepaintBoundary(
            key: key,
            child: ReviewStoryCard(
              comment: 'ทะเลหมอกสวยที่สุด',
              rating: 5,
              tripTitle: 'ภูกระดึง',
              backdrop: backdrop,
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;

      return (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: kShareCardPixelRatio);
        final bytes = await image.toByteData();
        final w = image.width;
        return (image, [bytes!.getUint8(3), bytes.getUint8((w - 1) * 4 + 3)]);
      }))!;
    }

    final (card, cardCorners) = await capture(ReviewBackdrop.forest);
    expect(card.width, 1080);
    expect(card.height, 1920);
    expect(cardCorners, everyElement(255));
    card.dispose();

    final (sticker, stickerCorners) = await capture(ReviewBackdrop.sticker);
    expect(sticker.width, 1080);
    expect(sticker.height, lessThan(1920));
    expect(stickerCorners, everyElement(0));
    sticker.dispose();
  });
}
