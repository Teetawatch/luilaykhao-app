import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/screens/trip_detail_screen.dart';

/// ตัวหาว่าเลื่อนอยู่กลุ่มไหนในหน้าทริป
///
/// เคยใช้ `localToGlobal` อ่านพิกัดบนจอ แล้วพัง: ตัวเรียกคือ scroll listener
/// ซึ่งทำงานก่อน layout ของเฟรมใหม่ ค่าที่ได้จึงเป็นของเฟรมก่อนหน้า และถ้า
/// กระโดดทีเดียวโดยไม่มี event ตามมา ค่าจะค้างผิดไปเลย — บนเครื่องจริงทำให้
/// แท็บค้างที่ "รายละเอียด" ทั้งที่เลื่อนถึงกลุ่มรีวิวแล้ว
///
/// เทสนี้จึงยืนยันว่าค่าที่คืนมา **ไม่ขึ้นกับตำแหน่ง scroll ปัจจุบัน**
const _pinned = 160.0;
const _anchorTop = 1200.0;

Widget _wrap(GlobalKey anchorKey, ScrollController controller) => MaterialApp(
  home: Scaffold(
    body: CustomScrollView(
      controller: controller,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: _anchorTop),
              SizedBox(key: anchorKey, height: 12),
              const SizedBox(height: 3000),
            ],
          ),
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('คืนตำแหน่งเดิมไม่ว่าจะเลื่อนอยู่ตรงไหน', (tester) async {
    final anchorKey = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(anchorKey, controller));
    await tester.pump();

    const expected = _anchorTop - _pinned;
    expect(
      tripSectionAnchorOffset(anchorKey, _pinned),
      moreOrLessEquals(expected, epsilon: 0.5),
    );

    // จุดตายของบั๊กเดิม: กระโดดแล้วอ่านทันทีโดยยังไม่ได้ pump เฟรมใหม่
    controller.jumpTo(2000);
    expect(
      tripSectionAnchorOffset(anchorKey, _pinned),
      moreOrLessEquals(expected, epsilon: 0.5),
      reason: 'ค่าต้องไม่เลื่อนตามตำแหน่ง scroll ปัจจุบัน',
    );

    await tester.pump();
    expect(
      tripSectionAnchorOffset(anchorKey, _pinned),
      moreOrLessEquals(expected, epsilon: 0.5),
    );

    controller.jumpTo(0);
    await tester.pump();
    expect(
      tripSectionAnchorOffset(anchorKey, _pinned),
      moreOrLessEquals(expected, epsilon: 0.5),
    );
  });

  testWidgets('จุดยึดที่ยังไม่ได้เรนเดอร์คืน null ไม่ใช่พัง', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(tripSectionAnchorOffset(GlobalKey(), _pinned), isNull);
  });
}
