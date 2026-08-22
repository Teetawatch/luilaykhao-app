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

  /// หน้าเข้าสู่ระบบตัวเดียวกันนี้ถูกฝังอยู่ในแท็บโปรไฟล์ตอนยังไม่ล็อกอิน
  /// เปิดหน้าทริป (push ทับแท็บ) แล้วถอยกลับมา ปุ่มย้อนกลับต้องไม่ติดค้างมา
  ///
  /// จุดตายคือหัวหน้าจอถูก rebuild "ระหว่างที่หน้าทริปยังทับอยู่" (เช่นคีย์บอร์ด
  /// เปิด/ปิดทำให้ padding ของ MediaQuery เปลี่ยน) ของเดิมอ่าน Navigator.canPop
  /// ตอนนั้นได้ true แล้วค้างอยู่อย่างนั้น เพราะ canPop ไม่ทำให้ rebuild เอง
  /// ปุ่มจึงโผล่บนแท็บ และกดแล้ว pop หน้าสุดท้ายทิ้งจนเหลือจอดำ
  testWidgets('ปุ่มย้อนกลับไม่ติดค้างเมื่อหน้าเข้าสู่ระบบอยู่ในแท็บ', (
    tester,
  ) async {
    final provider = AppProvider();
    addTearDown(provider.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();
    late StateSetter rebuildTab;
    var topPadding = 24.0;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuildTab = setState;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: EdgeInsets.only(top: topPadding)),
                child: const LoginScreen(popOnSuccess: false),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final backIcon = find.byIcon(Icons.arrow_back_rounded);
    expect(backIcon, findsNothing, reason: 'แท็บล่างสุดไม่มีอะไรให้ถอย');

    // เปิดหน้าอื่นทับ (เหมือนกดเข้าหน้าทริป) แล้วหัวหน้าจอถูก rebuild ระหว่างนั้น
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('ทริป')),
      ),
    );
    await tester.pumpAndSettle();
    rebuildTab(() => topPadding = 48);
    await tester.pump();

    // ปิดหน้าทริปกลับมาที่แท็บ
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(
      backIcon,
      findsNothing,
      reason: 'ปุ่มย้อนกลับต้องไม่ติดมาจากหน้าทริป',
    );
  });

  testWidgets('หน้าเข้าสู่ระบบที่ถูก push ทับ ยังมีปุ่มย้อนกลับ', (
    tester,
  ) async {
    final provider = AppProvider();
    addTearDown(provider.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('หน้าทริป')),
        ),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });
}
