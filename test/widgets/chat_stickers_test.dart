import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/chat_stickers.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _packs = ChatStickerPack.parseList([
  {
    'id': 1,
    'name': 'ลุยเลยเขา',
    'stickers': [
      {
        'id': 10,
        'label': 'รับทราบ',
        'keywords': ['รับทราบ', 'โอเค', 'ok'],
        'url': 'https://example.com/s/10.png',
      },
      {
        'id': 11,
        'label': 'ขึ้นรถแล้ว',
        'keywords': ['ขึ้นรถแล้ว'],
        'url': 'https://example.com/s/11.png',
      },
      {
        'id': 12,
        'label': 'หิว',
        'keywords': ['หิว', 'หิวข้าว'],
        'url': 'https://example.com/s/12.png',
      },
    ],
  },
  // ชุดที่ไม่มีสติกเกอร์ถูกตัดทิ้งตอนแปลง
  {'id': 2, 'name': 'ว่าง', 'stickers': []},
  // ตัวที่ไม่มีรูปใช้ไม่ได้
  {
    'id': 3,
    'name': 'เสีย',
    'stickers': [
      {'id': 30, 'label': 'x', 'url': ''},
    ],
  },
]);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child))),
  );
  await tester.pump();
}

void main() {
  test('parseList drops empty packs and stickers without an image', () {
    expect(_packs.map((p) => p.name), ['ลุยเลยเขา']);
    expect(_packs.first.stickers.map((s) => s.id), [10, 11, 12]);
    expect(_packs.first.stickers.first.fallbackBody, '[สติกเกอร์] รับทราบ');
  });

  group('matchStickers', () {
    List<int> ids(String text) => matchStickers(_packs, text).map((s) => s.id).toList();

    test('exact keyword wins, polite particles are ignored', () {
      expect(ids('รับทราบ'), [10]);
      expect(ids('รับทราบครับ'), [10]);
      expect(ids('  รับทราบค่ะ!! '), [10]);
      expect(ids('OK'), [10]);
    });

    test('prefix and in-sentence matches, exact first', () {
      // "หิว" ตรงทั้งคำของตัว 12 ส่วน "หิวข้าว" ขึ้นต้นด้วย "หิว" — ตัวเดียวกัน ไม่ซ้ำ
      expect(ids('หิว'), [12]);
      expect(ids('ขึ้นรถ'), [11]);
      expect(ids('ขึ้นรถแล้วนะทุกคน'), [11]);
    });

    test('short keywords never match inside other words', () {
      expect(ids('book'), isEmpty);
      expect(ids('o'), isEmpty);
    });

    test('long messages and empty input get nothing', () {
      expect(ids(''), isEmpty);
      expect(ids('รับทราบครับ แล้วพรุ่งนี้เจอกันกี่โมงนะครับทุกคน'), isEmpty);
    });
  });

  test('recents bump the latest to the front without duplicates', () {
    expect(StickerRecents.bump([1, 2, 3], 2), [2, 1, 3]);
    expect(StickerRecents.bump(List.generate(16, (i) => i), 99).length, 16);
    expect(StickerRecents.bump(List.generate(16, (i) => i), 99).first, 99);
  });

  test('recents survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    await StickerRecents.save([12, 10]);
    expect(await StickerRecents.load(), [12, 10]);
  });

  testWidgets('first tap previews, second tap sends', (tester) async {
    final sent = <int>[];
    await _pump(
      tester,
      ChatStickerPanel(
        packs: _packs,
        recentIds: const [],
        loading: false,
        error: null,
        onRetry: () {},
        onSend: (s) => sent.add(s.id),
      ),
    );

    // ยังไม่มีล่าสุด — เปิดชุดแรกให้เลย
    expect(find.bySemanticsLabel('สติกเกอร์ ขึ้นรถแล้ว'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('สติกเกอร์ ขึ้นรถแล้ว'));
    await tester.pump();
    expect(sent, isEmpty);
    expect(find.text('ส่ง'), findsOneWidget);

    await tester.tap(find.text('ส่ง'));
    await tester.pump();
    expect(sent, [11]);
    expect(find.text('ส่ง'), findsNothing);
  });

  testWidgets('tapping outside the preview cancels it', (tester) async {
    final sent = <int>[];
    await _pump(
      tester,
      ChatStickerPanel(
        packs: _packs,
        recentIds: const [12],
        loading: false,
        error: null,
        onRetry: () {},
        onSend: (s) => sent.add(s.id),
      ),
    );

    // มีประวัติ = แท็บล่าสุดก่อน โชว์เฉพาะตัวที่เคยใช้
    expect(find.bySemanticsLabel('สติกเกอร์ หิว'), findsOneWidget);
    expect(find.bySemanticsLabel('สติกเกอร์ รับทราบ'), findsNothing);

    await tester.tap(find.bySemanticsLabel('สติกเกอร์ หิว'));
    await tester.pump();
    expect(find.text('ส่ง'), findsOneWidget);

    // มุมล่างซ้ายของแผง — พื้นที่ว่างของชั้นตัวอย่าง ไม่โดนรูปหรือปุ่มส่ง
    await tester.tapAt(
      tester.getBottomLeft(find.byType(ChatStickerPanel)) + const Offset(12, -12),
    );
    await tester.pump();
    expect(find.text('ส่ง'), findsNothing);
    expect(sent, isEmpty);
  });

  testWidgets('load failure offers a retry', (tester) async {
    var retried = 0;
    await _pump(
      tester,
      ChatStickerPanel(
        packs: const [],
        recentIds: const [],
        loading: false,
        error: 'boom',
        onRetry: () => retried++,
        onSend: (_) {},
      ),
    );

    expect(find.text('โหลดสติกเกอร์ไม่สำเร็จ'), findsOneWidget);
    await tester.tap(find.text('ลองอีกครั้ง'));
    expect(retried, 1);
  });

  testWidgets('suggestion bar sends on one tap and can be dismissed', (tester) async {
    final picked = <int>[];
    var dismissed = false;
    await _pump(
      tester,
      StickerSuggestionBar(
        stickers: matchStickers(_packs, 'รับทราบ'),
        onPick: (s) => picked.add(s.id),
        onDismiss: () => dismissed = true,
      ),
    );

    await tester.tap(find.bySemanticsLabel('ส่งสติกเกอร์ รับทราบ'));
    expect(picked, [10]);
    await tester.tap(find.byTooltip('ไม่ใช้สติกเกอร์'));
    expect(dismissed, isTrue);
  });
}
