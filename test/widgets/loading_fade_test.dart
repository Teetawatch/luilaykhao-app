import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/loading_fade.dart';

/// โครงร่าง → เนื้อหาจริง: จางขึ้นทางเดียว และไม่ทำให้ state ของเนื้อหาหาย
Widget _wrap(bool loading, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(
      body: LoadingFade(
        loading: loading,
        child: loading
            ? const Text('skeleton')
            : const _Content(key: ValueKey('content')),
      ),
    ),
  ),
);

class _Content extends StatefulWidget {
  const _Content({super.key});

  static int created = 0;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  @override
  void initState() {
    super.initState();
    _Content.created++;
  }

  @override
  Widget build(BuildContext context) => const Text('content');
}

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: find.byType(Text), matching: find.byType(Opacity)),
    )
    .opacity;

void main() {
  setUp(() => _Content.created = 0);

  testWidgets('มีข้อมูลตั้งแต่แรก (แคช) = ไม่จาง เห็นเต็มทันที', (tester) async {
    await tester.pumpWidget(_wrap(false));
    expect(_opacity(tester), 1);
  });

  testWidgets('โหลดเสร็จ = เนื้อหาค่อยๆ จางขึ้นจนเต็ม', (tester) async {
    await tester.pumpWidget(_wrap(true));
    expect(find.text('skeleton'), findsOneWidget);
    expect(_opacity(tester), 1);

    await tester.pumpWidget(_wrap(false));
    // ไม่ครอสเฟด — โครงร่างออกจากต้นไม้ทันที เหลือเนื้อหาชุดเดียว
    expect(find.text('skeleton'), findsNothing);
    expect(_opacity(tester), lessThan(0.05));

    await tester.pump(const Duration(milliseconds: 130));
    final mid = _opacity(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));

    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });

  testWidgets('จางเสร็จแล้ว state ของเนื้อหาไม่ถูกสร้างใหม่', (tester) async {
    await tester.pumpWidget(_wrap(true));
    await tester.pumpWidget(_wrap(false));
    await tester.pumpAndSettle();
    expect(_Content.created, 1);

    // rebuild ปกติหลังจางเสร็จ — โครงต้นไม้ต้องคงที่
    await tester.pumpWidget(_wrap(false));
    await tester.pump(const Duration(seconds: 1));
    expect(_Content.created, 1);
  });

  testWidgets('กลับไปโหลดใหม่ = ตัดเป็นโครงร่างทันที ไม่ค้างเนื้อหาเก่า', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(false));
    await tester.pumpWidget(_wrap(true));
    expect(find.text('content'), findsNothing);
    expect(find.text('skeleton'), findsOneWidget);
    expect(_opacity(tester), 1);
  });

  testWidgets('เครื่องตั้ง "ลดการเคลื่อนไหว" = ไม่จาง', (tester) async {
    await tester.pumpWidget(_wrap(true, disableAnimations: true));
    await tester.pumpWidget(_wrap(false, disableAnimations: true));
    expect(_opacity(tester), 1);
  });

  testWidgets('แบบ sliver ใช้ใน CustomScrollView ได้และจางขึ้นเหมือนกัน', (
    tester,
  ) async {
    Widget sliverWrap(bool loading) => MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            LoadingFade.sliver(
              loading: loading,
              sliver: loading
                  ? const SliverToBoxAdapter(child: Text('skeleton'))
                  : const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Text('content'),
                    ),
            ),
          ],
        ),
      ),
    );

    SliverFadeTransition fade() =>
        tester.widget<SliverFadeTransition>(find.byType(SliverFadeTransition));

    await tester.pumpWidget(sliverWrap(true));
    await tester.pumpWidget(sliverWrap(false));
    expect(fade().opacity.value, lessThan(0.05));

    await tester.pumpAndSettle();
    expect(fade().opacity.value, 1);
    expect(find.text('content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
