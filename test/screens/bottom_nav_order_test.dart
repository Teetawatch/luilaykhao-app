import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/providers/wishlist_provider.dart';
import 'package:luilaykhao_app/screens/customer_app_screen.dart';
import 'package:luilaykhao_app/screens/wishlist_screen.dart';
import 'package:provider/provider.dart';

/// แถบเมนูล่าง — ข้างละ 3 รอบปุ่ม QR และเลขหน้าเดิมไม่เลื่อน
/// (แจ้งเตือนสลับแท็บด้วยเลข 0–4 ถ้าเลื่อน กดแจ้งเตือนจะไปผิดหน้า)
void main() {
  Future<List<int>> pumpNav(
    WidgetTester tester, {
    required bool staff,
    int index = 0,
  }) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CustomBottomNav(
            index: index,
            showStaffCheckIn: staff,
            onChanged: tapped.add,
            onCheckInPass: () {},
          ),
        ),
      ),
    );
    return tapped;
  }

  /// ป้ายบนแถบเรียงซ้ายไปขวา + ป้ายไหนอยู่ซ้าย/ขวาของปุ่ม QR
  List<String> labelsInOrder(WidgetTester tester, List<String> labels) {
    final xs = {for (final l in labels) l: tester.getCenter(find.text(l)).dx};
    return [...labels]..sort((a, b) => xs[a]!.compareTo(xs[b]!));
  }

  const customerOrder = ['หน้าหลัก', 'ทริป', 'การจอง', 'แชท', 'ถูกใจ', 'บัญชี'];

  testWidgets('ลูกค้า: เรียงตามความสำคัญ ข้างละ 3 รอบปุ่ม QR', (tester) async {
    await pumpNav(tester, staff: false);

    expect(labelsInOrder(tester, customerOrder), customerOrder);
    final qrX = tester.getCenter(find.text('เช็คอิน')).dx;
    final leftOfQr = customerOrder
        .where((l) => tester.getCenter(find.text(l)).dx < qrX)
        .toList();
    expect(leftOfQr, ['หน้าหลัก', 'ทริป', 'การจอง']);
    expect(find.text('งานสตาฟ'), findsNothing);
  });

  testWidgets('ลูกค้า: กดแต่ละแท็บได้เลขหน้าเดิม ถูกใจ = หน้า 5', (
    tester,
  ) async {
    final tapped = await pumpNav(tester, staff: false);

    for (final label in customerOrder) {
      await tester.tap(find.text(label));
    }
    // หน้าหลัก 0, ทริป 1, การจอง 2, แชท 3, ถูกใจ 5, บัญชี 4
    expect(tapped, [0, 1, 2, 3, 5, 4]);
  });

  testWidgets('สตาฟ: งานสตาฟมาแทนถูกใจ ยังข้างละ 3', (tester) async {
    final tapped = await pumpNav(tester, staff: true);

    const staffOrder = [
      'หน้าหลัก',
      'ทริป',
      'การจอง',
      'แชท',
      'งานสตาฟ',
      'บัญชี',
    ];
    expect(labelsInOrder(tester, staffOrder), staffOrder);
    expect(find.text('ถูกใจ'), findsNothing);

    await tester.tap(find.text('งานสตาฟ'));
    expect(tapped, [5]);
  });

  testWidgets('แท็บที่เลือกอยู่ไฮไลต์ตามเลขหน้า ไม่ใช่ตำแหน่งบนแถบ', (
    tester,
  ) async {
    // หน้า 4 (บัญชี) อยู่ช่องขวาสุด — ต้องได้ไอคอนแบบเลือกอยู่ ไม่ใช่ช่องที่ 5
    await pumpNav(tester, staff: false, index: 4);

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  testWidgets('จอแคบสุด 320pt: 6 แท็บไม่ล้น', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final staff in [false, true]) {
      await pumpNav(tester, staff: staff);
      expect(tester.takeException(), isNull);
    }
  });

  group('แท็บถูกใจ', () {
    Future<void> pumpWishlist(
      WidgetTester tester,
      WishlistProvider wishlist, {
      VoidCallback? onBrowseTrips,
    }) {
      return tester.pumpWidget(
        ChangeNotifierProvider<WishlistProvider>.value(
          value: wishlist,
          child: MaterialApp(
            home: WishlistScreen(onBrowseTrips: onBrowseTrips),
          ),
        ),
      );
    }

    testWidgets('ยังไม่มีทริปที่ชอบ: มีปุ่มพาไปหน้าทริป', (tester) async {
      var browsed = false;
      await pumpWishlist(
        tester,
        WishlistProvider(),
        onBrowseTrips: () => browsed = true,
      );

      expect(find.text('ยังไม่มีทริปที่บันทึกไว้'), findsOneWidget);
      // เป็นหน้าหลักของแท็บ — ไม่มีปุ่มย้อนกลับ
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.text('ดูทริปทั้งหมด'));
      expect(browsed, isTrue);
    });

    testWidgets('เปิดจากเมนูบัญชี (ไม่ส่ง callback) ไม่มีปุ่มดูทริป', (
      tester,
    ) async {
      await pumpWishlist(tester, WishlistProvider());

      expect(find.text('ยังไม่มีทริปที่บันทึกไว้'), findsOneWidget);
      expect(find.text('ดูทริปทั้งหมด'), findsNothing);
    });
  });
}
