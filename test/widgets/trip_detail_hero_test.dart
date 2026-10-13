import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/screens/trip_detail_screen.dart';

/// ขอบโค้งหัวการ์ดเนื้อหาหน้ารายละเอียดทริป
///
/// เคยประกาศไว้ที่ sliver ของเนื้อหาแล้วดันขึ้นไปทับรูปปกด้วย Transform —
/// แต่ viewport วาด sliver แรกทับ sliver ที่ตามมา รูปปกจึงบังมุมโค้งจนหมด
/// เหลือเป็นขอบตรง เทสนี้กันไม่ให้ย้ายมันกลับไปอยู่ฝั่งเนื้อหาอีก
const _expandedHeight = 360.0;

/// ความสูงของหัวการ์ด = _contentOverlap
const _capHeight = 40.0;

Widget _wrap(
  ScrollController controller, {
  bool isCollapsed = false,
  int? activeTab,
  ValueChanged<int>? onTabSelected,
  List<bool>? tabHasContent,
}) => MaterialApp(
  home: Scaffold(
    body: CustomScrollView(
      controller: controller,
      slivers: [
        TravelSliverAppBar(
          trip: const {'title': 'ทริปทดสอบ'},
          isLoading: false,
          isCollapsed: isCollapsed,
          expandedHeight: _expandedHeight,
          isFavorite: false,
          isAlertOn: false,
          onSharePressed: () {},
          onFavoritePressed: () {},
          onAlertPressed: () {},
          activeTab: activeTab,
          onTabSelected: onTabSelected,
          tabHasContent: tabHasContent,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 2000)),
      ],
    ),
  ),
);

Finder get _cap => find.descendant(
  of: find.byType(SliverAppBar),
  matching: find.byKey(const Key('tripDetailContentCap')),
);

void main() {
  testWidgets('ขอบโค้งหัวการ์ดถูกวาดในแถบรูป ไม่ใช่ใน sliver เนื้อหา', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller));
    await tester.pump();

    expect(_cap, findsOneWidget);

    // เกาะขอบล่างของแถบรูปพอดี ซึ่งเป็นตำแหน่งเดียวกับหัวการ์ดเนื้อหา
    final capRect = tester.getRect(_cap);
    expect(capRect.bottom, moreOrLessEquals(_expandedHeight, epsilon: 0.5));
    expect(capRect.height, moreOrLessEquals(_capHeight, epsilon: 0.5));
    // เต็มความกว้าง — ขอบล่างของหัวการ์ดต้องต่อกับการ์ดเนื้อหาได้สนิท
    expect(
      capRect.width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
  });

  testWidgets('หัวการ์ดไม่มีขีดจับ — หน้านี้ไม่ใช่แผงที่ลากได้', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller));
    await tester.pump();

    // ขีดจับแบบ bottom sheet บอกว่าแผงลากขึ้นลงได้ ซึ่งทำไม่ได้ และทิ้งแถบว่าง
    // ไว้เหนือชื่อทริป หัวการ์ดจึงเป็นแค่ขอบโค้งเปล่า
    expect(
      find.descendant(of: _cap, matching: find.byType(Container)),
      findsNothing,
    );
  });

  testWidgets('ไม่มีฝ้าสีการ์ดไล่ขึ้นไปในรูปปก — รูปจบคมที่ขอบการ์ด', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller));
    await tester.pump();

    final context = tester.element(find.byType(CustomScrollView));
    final background = Theme.of(context).scaffoldBackgroundColor;

    // เฉดดำบาง ๆ ที่หัวรูป (ให้ปุ่มอ่านออก) ยังมีได้ — ที่ห้ามคือเฉด "สีการ์ด"
    // ไล่ขึ้นไปในรูป เพราะมันอ่านเป็นแสงเรืองที่หัวการ์ด ไม่ใช่รอยต่อ
    final gradients = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(SliverAppBar),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.gradient)
        .whereType<LinearGradient>();

    expect(
      gradients.any(
        (gradient) => gradient.colors.any(
          (color) => color.withValues(alpha: 1) == background,
        ),
      ),
      isFalse,
    );
  });

  testWidgets('พอแถบหุบจนเหลือ toolbar ขอบโค้งหายไป ไม่ค้างทับเนื้อหา', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller));
    await tester.pump();

    controller.jumpTo(_expandedHeight);
    await tester.pump();

    expect(_cap, findsNothing);
  });

  testWidgets('แถบแท็บจองที่ในแถบรูปไว้ตลอด แต่โปร่งใสตอนยังไม่หุบ', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller, activeTab: 0));
    await tester.pumpAndSettle();

    expect(find.byType(TripSectionTabs), findsOneWidget);
    expect(find.text('วันเดินทาง'), findsOneWidget);
    expect(find.text('รีวิว'), findsOneWidget);

    final faded = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(TripSectionTabs),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(faded.opacity, 0);
    // กดไม่ติดตอนมองไม่เห็น ไม่งั้นจะโดนกดโดนทั้งที่เป็นรูปปกอยู่
    expect(
      tester
          .widget<IgnorePointer>(
            find.descendant(
              of: find.byType(TripSectionTabs),
              matching: find.byType(IgnorePointer),
            ),
          )
          .ignoring,
      isTrue,
    );
  });

  testWidgets('พอหุบแล้วแท็บโผล่และกดได้', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    int? tapped;

    await tester.pumpWidget(
      _wrap(
        controller,
        isCollapsed: true,
        activeTab: 0,
        onTabSelected: (i) => tapped = i,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('เตรียมตัว'));
    expect(tapped, 2);
  });

  testWidgets('ระหว่างหุบ ขอบโค้งย่อลงแต่ยังทึบ — ไม่เกิดรอยต่อเหนือชื่อทริป', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller));
    await tester.pump();

    // ครึ่งทางของช่วง 40 สุดท้ายก่อนหุบ (toolbar 56, ไม่มีแท็บ, ไม่มี notch)
    controller.jumpTo(_expandedHeight - kToolbarHeight - _capHeight / 2);
    await tester.pump();

    expect(_cap, findsOneWidget);
    expect(
      tester.getSize(_cap).height,
      moreOrLessEquals(_capHeight / 2, epsilon: 0.5),
    );
    // เดิมหัวการ์ดจางลงด้วย Opacity — รูปปกทะลุออกมาแต่เนื้อหาข้างใต้ทึบ
    // จึงเห็นเป็นขีดยาวเต็มความกว้างเหนือชื่อทริป
    final faded = tester
        .widgetList<Opacity>(
          find.ancestor(of: _cap, matching: find.byType(Opacity)),
        )
        .where((o) => o.opacity < 1);
    expect(faded, isEmpty);
    // ขอบล่างยังเกาะขอบล่างแถบรูป ต่อกับการ์ดเนื้อหาได้สนิท
    expect(
      tester.getRect(_cap).bottom,
      moreOrLessEquals(kToolbarHeight + _capHeight / 2, epsilon: 0.5),
    );
  });

  testWidgets('ความสูงของแท็บถูกนับรวมในจุดที่ขอบโค้งต้องจางหมด', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(controller, activeTab: 0));
    await tester.pumpAndSettle();

    // เลื่อนจนเหลือแค่ toolbar — ถ้าไม่นับความสูงแท็บ ขอบโค้งจะยังค้างอยู่
    controller.jumpTo(_expandedHeight);
    await tester.pump();
    expect(_cap, findsNothing);
  });

  testWidgets('กลุ่มที่ไม่มีเนื้อหาไม่ถูกแสดงเป็นแท็บ', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        controller,
        isCollapsed: true,
        activeTab: 0,
        // ทริปในประเทศที่ไม่มีสิ่งที่ควรรู้/ควรเตรียม/FAQ/นโยบายเลย
        tabHasContent: const [true, true, false, true],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('เตรียมตัว'), findsNothing);
    expect(find.text('วันเดินทาง'), findsOneWidget);
    expect(find.text('รายละเอียด'), findsOneWidget);
    expect(find.text('รีวิว'), findsOneWidget);
  });

  testWidgets('แท็บที่เหลือขยายเต็มความกว้าง ไม่ทิ้งช่องว่างของแท็บที่ซ่อน', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        controller,
        isCollapsed: true,
        activeTab: 0,
        tabHasContent: const [true, true, false, true],
      ),
    );
    await tester.pumpAndSettle();

    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final widths = ['วันเดินทาง', 'รายละเอียด', 'รีวิว']
        .map(
          (label) => tester
              .getSize(
                find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byType(InkWell),
                    )
                    .first,
              )
              .width,
        )
        .toList();

    for (final width in widths) {
      expect(width, moreOrLessEquals(screenWidth / 3, epsilon: 0.5));
    }
  });
}
