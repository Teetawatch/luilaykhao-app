import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/offline_banner.dart';

/// แจ้งเน็ตหลุด: หลุดแวบเดียวไม่ต้องโชว์ หลุดจริงเด้งป้ายลอยแล้วเหลือแถบบางใต้แถบสถานะ
/// (ดันเนื้อหาลง ไม่บังหัวข้อ) กลับมาออนไลน์ขึ้นป้ายเขียวแป๊บเดียวแล้วหายไป
void main() {
  const toastTitle = 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต';
  const stripTitle = 'ออฟไลน์อยู่';
  const back = 'กลับมาออนไลน์แล้ว';
  final pageKey = GlobalKey();

  Future<ValueNotifier<bool>> pump(
    WidgetTester tester, {
    bool online = true,
  }) async {
    final isOnline = ValueNotifier<bool>(online);
    await tester.pumpWidget(
      MaterialApp(
        home: OfflineBanner(
          isOnline: isOnline,
          child: Scaffold(body: SizedBox(key: pageKey)),
        ),
      ),
    );
    return isOnline;
  }

  // The pill stays in the tree while hidden (it slides out), so "shown"
  // means fully opaque.
  bool pillShown(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity == 1;

  bool stripShown() => find.textContaining(stripTitle).evaluate().isNotEmpty;

  double pageTopPadding() => MediaQuery.paddingOf(pageKey.currentContext!).top;

  Future<void> goOffline(
    WidgetTester tester,
    ValueNotifier<bool> isOnline,
  ) async {
    isOnline.value = false;
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  }

  testWidgets('a brief flap never shows anything', (tester) async {
    final isOnline = await pump(tester);
    isOnline.value = false;
    await tester.pump(const Duration(milliseconds: 400));
    isOnline.value = true;
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(pillShown(tester), isFalse);
    expect(stripShown(), isFalse);
    expect(find.text(back), findsNothing);
  });

  testWidgets('going offline toasts first, then settles into the strip', (
    tester,
  ) async {
    final isOnline = await pump(tester);
    await goOffline(tester, isOnline);
    expect(pillShown(tester), isTrue);
    expect(find.text(toastTitle), findsOneWidget);
    expect(stripShown(), isFalse);
    expect(pageTopPadding(), 0);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(pillShown(tester), isFalse);
    expect(stripShown(), isTrue);
    // The strip makes room for itself instead of covering the app bar.
    expect(pageTopPadding(), OfflineBanner.stripHeight);
  });

  testWidgets('tapping the toast dismisses it into the strip', (tester) async {
    final isOnline = await pump(tester);
    await goOffline(tester, isOnline);
    await tester.tap(find.text(toastTitle));
    await tester.pumpAndSettle();
    expect(pillShown(tester), isFalse);
    expect(stripShown(), isTrue);
  });

  testWidgets('starting offline shows the toast without a change event', (
    tester,
  ) async {
    await pump(tester, online: false);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(pillShown(tester), isTrue);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('reconnecting flashes "back online" and gives the space back', (
    tester,
  ) async {
    final isOnline = await pump(tester);
    await goOffline(tester, isOnline);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    isOnline.value = true;
    await tester.pumpAndSettle();
    expect(find.text(back), findsOneWidget);
    expect(pillShown(tester), isTrue);
    expect(stripShown(), isFalse);
    expect(pageTopPadding(), 0);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();
    expect(pillShown(tester), isFalse);
  });

  testWidgets('dropping again right after recovering skips the second toast', (
    tester,
  ) async {
    final isOnline = await pump(tester);
    await goOffline(tester, isOnline);
    isOnline.value = true;
    await tester.pumpAndSettle();

    await goOffline(tester, isOnline);
    expect(pillShown(tester), isFalse);
    expect(stripShown(), isTrue);
  });

  testWidgets('the hidden pill does not swallow taps on the page beneath', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OfflineBanner(
          isOnline: ValueNotifier<bool>(true),
          child: Scaffold(
            body: SizedBox.expand(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(400, 24));
    expect(tapped, isTrue);
  });
}
