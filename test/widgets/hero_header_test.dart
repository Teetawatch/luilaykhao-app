import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/screens/customer_app_screen.dart';

/// สไลด์ฮีโร่หน้าแรก — เคยค้างอยู่รูปเดียวเพราะ timer เลื่อนสไลด์ถูกถอดออกไป
/// แต่จุดบอกสไลด์ยังอยู่ (commit d5bddbd) เทสนี้กันไม่ให้กลับไปเป็นแบบนั้นอีก
Widget _wrap(List<Map<String, dynamic>> slides) => MaterialApp(
  home: Scaffold(body: HeroHeader(slides: slides, showSearch: false)),
);

List<Map<String, dynamic>> _slides(int count) => List.generate(
  count,
  (i) => {'image_url': 'https://example.com/hero-$i.jpg', 'alt_text': 'ภาพ $i'},
);

void main() {
  testWidgets('หลายสไลด์ = ปัดเปลี่ยนรูปได้', (tester) async {
    await tester.pumpWidget(_wrap(_slides(3)));
    await tester.pump();

    final pager = find.byType(PageView);
    expect(pager, findsOneWidget);

    final controller = tester.widget<PageView>(pager).controller!;
    expect(controller.page?.round(), 0);

    // ปัดไปทางซ้าย = ไปสไลด์ถัดไป (ปัดเกินครึ่งจอเพื่อให้ snap ไปใบถัดไป)
    await tester.fling(pager, const Offset(-500, 0), 1200);
    await tester.pumpAndSettle();
    expect(controller.page?.round(), 1);
  });

  testWidgets('สไลด์เลื่อนเองเมื่อถึงเวลา', (tester) async {
    await tester.pumpWidget(_wrap(_slides(3)));
    await tester.pump();

    final controller = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(controller.page?.round(), 0);

    // จังหวะเลื่อนอัตโนมัติคือ 6 วินาที
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(controller.page?.round(), 1);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(controller.page?.round(), 2);

    // ใบสุดท้ายแล้ววนกลับใบแรก
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(controller.page?.round(), 0);
  });

  testWidgets('สไลด์เดียวไม่ต้องมี pager และไม่มีจุดบอกสไลด์', (tester) async {
    await tester.pumpWidget(_wrap(_slides(1)));
    await tester.pump();

    expect(find.byType(PageView), findsNothing);
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('ไม่มีสไลด์เลยก็ยังเรนเดอร์ได้ (ใช้ภาพสำรอง)', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pump();

    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
