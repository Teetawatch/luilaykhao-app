import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/screens/trip_detail_screen.dart';
import 'package:luilaykhao_app/theme/app_theme.dart';

/// เนื้อหาอ้างอิงในหน้าทริปถูกพับเก็บไว้ให้กดกาง เพื่อไม่ให้ 22 section
/// กินหน้าจอตอนคนกำลังตัดสินใจ — เทสนี้กันไม่ให้มันกลับไปกางค้างทั้งหมด
/// และกันไม่ให้ของที่ต้องรู้ก่อนจ่ายเงิน (วีซ่า/คำเตือน) ถูกพับตามไปด้วย
Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  testWidgets('"ค่าใช้จ่ายนี้รวมอะไรบ้าง" พับไว้ กดแล้วกาง กดซ้ำแล้วพับ', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const IncludedSection(
          trip: {
            'inclusions': ['รถตู้ไป-กลับ', 'อาหาร 3 มื้อ', 'ประกันการเดินทาง'],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // หัวข้อกับจำนวนรายการเห็นได้ตั้งแต่ยังพับ จะได้รู้ว่ามีอะไรให้กาง
    expect(find.text('ค่าใช้จ่ายนี้รวมอะไรบ้าง'), findsOneWidget);
    expect(find.text('3 รายการ'), findsOneWidget);

    final collapsed = tester.getSize(find.byType(IncludedSection)).height;

    await tester.tap(find.text('ค่าใช้จ่ายนี้รวมอะไรบ้าง'));
    await tester.pumpAndSettle();
    final expanded = tester.getSize(find.byType(IncludedSection)).height;
    expect(expanded, greaterThan(collapsed));

    await tester.tap(find.text('ค่าใช้จ่ายนี้รวมอะไรบ้าง'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(IncludedSection)).height,
      moreOrLessEquals(collapsed, epsilon: 0.5),
    );
  });

  testWidgets('คำเตือน "สิ่งที่ควรรู้ก่อนเดินทาง" กางไว้ตั้งแต่แรก', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const MustKnowSection(
          trip: {
            'must_know': {'remarks': 'เส้นทางชันมาก ไม่เหมาะกับผู้มีโรคหัวใจ'},
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final expanded = tester.getSize(find.byType(MustKnowSection)).height;

    // กดแล้วต้องพับได้ = สูงลดลง พิสูจน์ว่าตอนแรกคือสถานะกาง ไม่ใช่พับ
    await tester.tap(find.text('สิ่งที่ควรรู้ก่อนเดินทาง'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(MustKnowSection)).height,
      lessThan(expanded),
    );
  });

  testWidgets('กล่องสถิติของหัวเรื่องเป็นการ์ดขาว ไม่ใช่กรอบเปล่าสีพื้น', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: DestinationInfoSection(
                trip: {
                  'title': 'เขาหลวง สุโขทัย',
                  'duration_days': 2,
                  'difficulty': 'medium',
                },
                reviews: [],
                isLoading: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(DestinationInfoSection));
    final fill = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.byType(QuickInfoChips),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color)
        .whereType<Color>()
        .first;

    // สีเดียวกับการ์ด section ข้างล่าง — ไม่ใช่สีพื้นของหน้า ซึ่งจะทำให้กล่อง
    // นี้เหลือแค่เส้นขอบ มองไม่เห็นว่าเป็นก้อนข้อมูล
    expect(fill, AppTheme.surface(context));
    expect(fill, isNot(AppTheme.background(context)));
  });

  testWidgets('หัวเรื่องทริปไม่มีกรอบการ์ด — เป็นหัวหน้า ไม่ใช่ section', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DestinationInfoSection(
          trip: {'title': 'เขาหลวง สุโขทัย', 'location': 'สุโขทัย'},
          reviews: [],
          isLoading: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('เขาหลวง สุโขทัย'), findsOneWidget);
    // ไม่มี Material ที่เป็นกรอบการ์ดของตัวเองครอบอยู่
    expect(
      find.descendant(
        of: find.byType(DestinationInfoSection),
        matching: find.byType(Material),
      ),
      findsNothing,
    );
  });
}
