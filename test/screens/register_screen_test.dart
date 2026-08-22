import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/register_screen.dart';
import 'package:provider/provider.dart';

/// วันเกิดเป็นข้อมูลที่ขั้นตอนจองบังคับกรอกอยู่แล้ว (ประกันการเดินทาง/ออกตั๋ว)
/// หน้าสมัครจึงต้องมีช่องนี้ ไม่ใช่ปล่อยให้ไปเจอเอาตอนจองแล้วค่อยกรอก
Future<void> _pump(WidgetTester tester) async {
  final provider = AppProvider();
  addTearDown(provider.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: provider,
      child: const MaterialApp(home: RegisterScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('มีช่องกรอกวัน/เดือน/ปีเกิด', (tester) async {
    await _pump(tester);

    expect(find.text('วัน/เดือน/ปีเกิด *'), findsOneWidget);
  });

  testWidgets('กดสมัครโดยไม่เลือกวันเกิด ต้องเตือน', (tester) async {
    await _pump(tester);

    // หน้านี้มีรูปพื้นหลังที่โหลดไม่จบในเทสต์ pumpAndSettle จึงค้าง
    final submit = find.text('สมัครสมาชิก');
    await tester.ensureVisible(submit.last);
    await tester.pump();
    await tester.tap(submit.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('กรุณาเลือกวัน/เดือน/ปีเกิด'), findsOneWidget);
  });

  testWidgets('เลือกวันเกิดแล้วแสดงเป็น พ.ศ. พร้อมอายุ', (tester) async {
    await _pump(tester);

    final field = find.text('วัน/เดือน/ปีเกิด *');
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.tap(field);
    await tester.pump(const Duration(milliseconds: 600));

    // ปฏิทินเปิดที่ปีปัจจุบัน - 25 กด OK เพื่อรับวันนั้น
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 600));

    final expectedYear = DateTime.now().year - 25 + 543;
    expect(
      find.textContaining('$expectedYear · อายุ 25 ปี'),
      findsOneWidget,
    );
  });
}
