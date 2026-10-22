import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/animated_checkmark.dart';
import 'package:luilaykhao_app/widgets/chat_bubble_entrance.dart';
import 'package:luilaykhao_app/widgets/count_up_text.dart';
import 'package:luilaykhao_app/widgets/fade_through_indexed_stack.dart';
import 'package:luilaykhao_app/widgets/staggered_entrance.dart';
import 'package:luilaykhao_app/widgets/vehicle_seat_map.dart';
import 'package:luilaykhao_app/widgets/wishlist_button.dart' show HeartBounce;

/// อนิเมชันเล็กๆ ทั่วแอป — สลับแท็บ, หัวใจ, ตัวเลขวิ่ง, ข้อความใหม่, ที่นั่ง,
/// การ์ดไล่เข้ามา, เครื่องหมายถูก
Widget _app(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: child),
  ),
);

class _Counter extends StatefulWidget {
  const _Counter(this.label);

  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => taps++),
    child: Text('${widget.label} $taps'),
  );
}

void main() {
  group('สลับแท็บ (FadeThroughIndexedStack)', () {
    Widget tabs(int index, {bool disableAnimations = false}) => _app(
      FadeThroughIndexedStack(
        index: index,
        children: const [_Counter('หน้าแรก'), _Counter('การจอง')],
      ),
      disableAnimations: disableAnimations,
    );

    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(FadeThroughIndexedStack),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;

    testWidgets('เปิดแอปครั้งแรกไม่จาง', (tester) async {
      await tester.pumpWidget(tabs(0));
      expect(opacity(tester), 1);
    });

    testWidgets('สลับแท็บ = หน้าใหม่จางขึ้น และ state ของแท็บเดิมยังอยู่', (
      tester,
    ) async {
      await tester.pumpWidget(tabs(0));
      await tester.tap(find.text('หน้าแรก 0'));
      await tester.pump();
      expect(find.text('หน้าแรก 1'), findsOneWidget);

      await tester.pumpWidget(tabs(1));
      expect(opacity(tester), lessThan(0.05));
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);

      await tester.pumpWidget(tabs(0));
      await tester.pumpAndSettle();
      // ยังเป็นตัวเดิม ไม่ถูกสร้างใหม่ตอนสลับไปมา
      expect(find.text('หน้าแรก 1'), findsOneWidget);
    });

    testWidgets('ลดการเคลื่อนไหว = ไม่จาง', (tester) async {
      await tester.pumpWidget(tabs(0, disableAnimations: true));
      await tester.pumpWidget(tabs(1, disableAnimations: true));
      expect(opacity(tester), 1);
    });
  });

  group('หัวใจ (HeartBounce)', () {
    Widget heart(bool favourite) => _app(
      Center(
        child: HeartBounce(
          favourite: favourite,
          size: 22,
          color: favourite ? Colors.red : Colors.grey,
        ),
      ),
    );

    double scale(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find.ancestor(
            of: find.byType(Icon),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    testWidgets('กดถูกใจ = เด้งเกินขนาดแล้วกลับมาที่ 1', (tester) async {
      await tester.pumpWidget(heart(false));
      await tester.pumpWidget(heart(true));
      await tester.pump(const Duration(milliseconds: 140));
      expect(scale(tester), greaterThan(1.15));
      await tester.pumpAndSettle();
      expect(scale(tester), 1);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('ถูกใจไว้ตั้งแต่แรก = ไม่เด้ง', (tester) async {
      await tester.pumpWidget(heart(true));
      await tester.pump(const Duration(milliseconds: 140));
      expect(scale(tester), 1);
    });

    testWidgets('เอาออก = ไม่เด้ง', (tester) async {
      await tester.pumpWidget(heart(true));
      await tester.pumpWidget(heart(false));
      await tester.pump(const Duration(milliseconds: 140));
      expect(scale(tester), 1);
    });
  });

  group('ตัวเลขวิ่ง (CountUpText)', () {
    Widget count(num value, {num? from, bool disableAnimations = false}) =>
        _app(
          CountUpText(value: value, from: from, format: (n) => '฿$n'),
          disableAnimations: disableAnimations,
        );

    int shown(WidgetTester tester) => int.parse(
      tester.widget<Text>(find.byType(Text)).data!.substring(1),
    );

    testWidgets('ค่าแรกไม่วิ่ง — ราคาไม่นับจาก 0 ทุกครั้งที่เปิดหน้า', (
      tester,
    ) async {
      await tester.pumpWidget(count(3200));
      expect(shown(tester), 3200);
    });

    testWidgets('ยอดเปลี่ยน = วิ่งผ่านจำนวนเต็มระหว่างทางไปถึงค่าใหม่', (
      tester,
    ) async {
      await tester.pumpWidget(count(3200));
      await tester.pumpWidget(count(3700));
      await tester.pump(const Duration(milliseconds: 150));
      final mid = shown(tester);
      expect(mid, greaterThan(3200));
      expect(mid, lessThan(3700));
      await tester.pumpAndSettle();
      expect(shown(tester), 3700);
    });

    testWidgets('from = วิ่งจากค่านั้นตอนโผล่ (นับถอยลงได้)', (tester) async {
      await tester.pumpWidget(count(12, from: 19));
      expect(shown(tester), 19);
      await tester.pumpAndSettle();
      expect(shown(tester), 12);
    });

    testWidgets('ลดการเคลื่อนไหว = โชว์ค่าจริงทันที', (tester) async {
      await tester.pumpWidget(count(12, from: 0, disableAnimations: true));
      expect(shown(tester), 12);
    });
  });

  group('ข้อความใหม่ในแชท (ChatBubbleEntrance)', () {
    Widget bubble(bool animate, {bool sticker = false}) => _app(
      ChatBubbleEntrance(
        animate: animate,
        sticker: sticker,
        child: const Text('สวัสดี'),
      ),
    );

    Finder opacity() => find.ancestor(
      of: find.text('สวัสดี'),
      matching: find.byType(Opacity),
    );

    testWidgets('ประวัติแชท = ไม่มีชั้นอนิเมชันเพิ่ม', (tester) async {
      await tester.pumpWidget(bubble(false));
      expect(opacity(), findsNothing);
    });

    testWidgets('ข้อความใหม่จางขึ้น และ build ซ้ำด้วย false ไม่ตัดกลางทาง', (
      tester,
    ) async {
      await tester.pumpWidget(bubble(true));
      expect(tester.widget<Opacity>(opacity()).opacity, lessThan(0.05));

      // ห้องส่ง false ใน build ถัดไปเสมอ — อนิเมชันต้องเล่นต่อจนจบ
      await tester.pumpWidget(bubble(false));
      await tester.pump(const Duration(milliseconds: 120));
      final mid = tester.widget<Opacity>(opacity()).opacity;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacity()).opacity, 1);
    });

    testWidgets('สติกเกอร์เด้งเกินขนาดจริงเล็กน้อย', (tester) async {
      await tester.pumpWidget(bubble(true, sticker: true));
      var peak = 0.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        final transform = tester.widget<Transform>(
          find
              .ancestor(of: find.text('สวัสดี'), matching: find.byType(Transform))
              .first,
        );
        peak = transform.transform.getMaxScaleOnAxis() > peak
            ? transform.transform.getMaxScaleOnAxis()
            : peak;
      }
      expect(peak, greaterThan(1.0));
      await tester.pumpAndSettle();
    });
  });

  group('ที่นั่งในผังรถ', () {
    Widget seats(Set<String> picked) => _app(
      SingleChildScrollView(
        child: VehicleSeatMap(
          seatMap: {
            'layout_kind': 'van',
            'rows': 2,
            'columns': const ['A', 'B'],
            'front_seat': null,
            'last_row_center': const <String>[],
            'seats': [
              for (final id in ['A1', 'B1', 'A2', 'B2'])
                {'id': id, 'label': id, 'status': 'available'},
            ],
          },
          toneFor: (_, id) =>
              picked.contains(id) ? SeatTone.picking : SeatTone.available,
          selectableFor: (_, _) => true,
          onSeatTap: (_, _) {},
        ),
      ),
    );

    List<double> scales(WidgetTester tester) => tester
        .widgetList<ScaleTransition>(
          find.descendant(
            of: find.byType(VehicleSeatMap),
            matching: find.byType(ScaleTransition),
          ),
        )
        .map((s) => s.scale.value)
        .toList();

    testWidgets('กดเลือก = ที่นั่งนั้นเด้ง ที่เหลือนิ่ง', (tester) async {
      await tester.pumpWidget(seats({}));
      await tester.pumpWidget(seats({'B1'}));
      await tester.pump(const Duration(milliseconds: 110));

      final now = scales(tester);
      expect(now.where((s) => s > 1.05), hasLength(1));
      expect(now.where((s) => s == 1), hasLength(now.length - 1));
      await tester.pumpAndSettle();
      expect(scales(tester).every((s) => s == 1), isTrue);
    });

    testWidgets('เปิดผังมาพร้อมที่นั่งที่เลือกไว้แล้ว = ไม่เด้ง', (tester) async {
      await tester.pumpWidget(seats({'A1', 'B2'}));
      await tester.pump(const Duration(milliseconds: 110));
      expect(scales(tester).every((s) => s == 1), isTrue);
    });
  });

  group('การ์ดไล่เข้ามา (StaggeredEntrance)', () {
    // แท็บที่ซ่อนใน IndexedStack นับเป็น offstage — ต้องหาแบบไม่ข้าม
    double opacityOf(WidgetTester tester, String label) => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.text(label, skipOffstage: false),
            matching: find.byType(Opacity, skipOffstage: false),
          ),
        )
        .opacity;

    testWidgets('หน้าต่างเปิดแค่เฟรมแรกที่เนื้อหาโผล่', (tester) async {
      final window = EntranceWindow();
      await tester.pumpWidget(_app(const SizedBox()));
      expect(window.isOpen, isTrue);
      expect(window.isOpen, isTrue); // ยังเฟรมเดิม
      await tester.pump();
      expect(window.isOpen, isFalse);
    });

    testWidgets('ใบหลังเริ่มช้ากว่าใบแรก แล้วเห็นครบทุกใบ', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              StaggeredEntrance(index: 0, animate: true, child: Text('ใบแรก')),
              StaggeredEntrance(index: 4, animate: true, child: Text('ใบห้า')),
            ],
          ),
        ),
      );
      // timer ของใบแรกยิงในเฟรมนี้ อนิเมชันเริ่มเดินเฟรมถัดไป
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacityOf(tester, 'ใบแรก'), greaterThan(opacityOf(tester, 'ใบห้า')));
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'ใบแรก'), 1);
      expect(opacityOf(tester, 'ใบห้า'), 1);
    });

    testWidgets('แท็บที่ยังไม่ถูกเปิด = รอจนเห็นค่อยเล่น', (tester) async {
      Widget stack(int index) => _app(
        IndexedStack(
          index: index,
          children: const [
            Text('หน้าแรก'),
            StaggeredEntrance(index: 0, animate: true, child: Text('การจอง')),
          ],
        ),
      );

      await tester.pumpWidget(stack(0));
      await tester.pump(const Duration(seconds: 2));
      // ยังซ่อนอยู่ทั้งที่ผ่านไปนาน — ไม่ได้เล่นจบไปตอนอยู่หน้าแรก
      expect(opacityOf(tester, 'การจอง'), 0);

      await tester.pumpWidget(stack(1));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 120));
      expect(opacityOf(tester, 'การจอง'), greaterThan(0));
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'การจอง'), 1);
    });

    testWidgets('animate = false (เลื่อนลงมาเจอทีหลัง) ไม่มีชั้นเพิ่ม', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const StaggeredEntrance(index: 2, animate: false, child: Text('x')),
        ),
      );
      expect(
        find.ancestor(of: find.text('x'), matching: find.byType(Opacity)),
        findsNothing,
      );
    });
  });

  group('เครื่องหมายถูก (AnimatedCheckmark)', () {
    testWidgets('วาดจนจบแล้วสั่นเบาๆ ครั้งเดียว', (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        _app(
          const AnimatedCheckmark(size: 92, color: Colors.green, haptic: true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(haptics, isEmpty);
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(find.bySemanticsLabel('สำเร็จ'), findsOneWidget);
    });
  });
}
