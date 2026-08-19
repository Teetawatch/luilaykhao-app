import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/login_screen.dart';
import 'package:provider/provider.dart';

/// หน้าเข้าสู่ระบบถูกจัดใหม่เป็นหน้าเดียวไหลยาว
///
/// เดิมเป็นรูปเต็มจอแล้วมีแผ่นกระจกฝ้า (BackdropFilter) เลื่อนขึ้นมาทับ พร้อม
/// ขีดจับแบบ bottom sheet เทสนี้กันไม่ให้แผ่นทับกลับมา
Future<void> _pump(WidgetTester tester) async {
  final provider = AppProvider();
  addTearDown(provider.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: provider,
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('เป็นหน้าเดียว ไม่มีแผ่นกระจกฝ้าทับ', (tester) async {
    await _pump(tester);

    // แผ่นเดิมใช้ BackdropFilter เบลอพื้นหลัง — ต้องไม่มีแล้วในตัวหน้า
    // (ปุ่มย้อนกลับยังใช้เบลอของตัวเองได้ จึงเช็คว่ามีไม่เกินหนึ่ง)
    expect(
      tester.widgetList(find.byType(BackdropFilter)).length,
      lessThanOrEqualTo(1),
      reason: 'เหลือได้แค่ของปุ่มย้อนกลับ ไม่ใช่แผ่นครอบทั้งหน้า',
    );
    expect(find.byType(ImageFiltered), findsNothing);

    // เนื้อหาทั้งหน้าอยู่ในสกรอลล์เดียว
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('หัวเรื่องอยู่บนแถบรูป และมีทางไปสมัคร/ลืมรหัสผ่าน', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('เข้าสู่ระบบ'), findsWidgets);
    expect(find.text('ยินดีต้อนรับกลับ พร้อมออกเดินทางอีกครั้งหรือยัง'), findsOneWidget);
    expect(find.text('สมัครสมาชิกฟรี'), findsOneWidget);
    expect(find.text('ลืมรหัสผ่าน?'), findsOneWidget);
    expect(find.text('หรือใช้อีเมล'), findsOneWidget);
  });
}
