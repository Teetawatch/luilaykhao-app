import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/profile_screen.dart';
import 'package:provider/provider.dart';

/// หน้าการแจ้งเตือน — จัดใหม่เป็นการ์ดเดียวต่อกลุ่มวัน + ตัวกรอง
///
/// เดิมทุกรายการเป็นการ์ดของตัวเองที่มีขอบและพื้นสีตามประเภท เลื่อนดูแล้วเป็น
/// สายรุ้ง เทสนี้กันไม่ให้ตัวกรองพัง และกันไม่ให้ข้อความตอนกรองแล้วว่าง
/// กลับไปใช้ข้อความ "ยังไม่มีการแจ้งเตือน" ซึ่งไม่จริง
Map<String, dynamic> _notification({
  required int id,
  required String title,
  required String type,
  required bool isRead,
  required Duration ago,
}) => {
  'id': id,
  'type': type,
  'title': title,
  'body': 'รายละเอียดของ $title',
  'is_read': isRead,
  'created_at': DateTime.now().subtract(ago).toIso8601String(),
  'data': const <String, dynamic>{},
};

Future<AppProvider> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> items,
) async {
  final provider = AppProvider()..notifications = items;
  addTearDown(provider.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: provider,
      child: const MaterialApp(home: NotificationsScreen()),
    ),
  );
  await tester.pump();
  return provider;
}

void main() {
  testWidgets('แบ่งกลุ่มตามวัน และกรองเฉพาะที่ยังไม่อ่านได้', (tester) async {
    await _pump(tester, [
      _notification(
        id: 1,
        title: 'ยืนยันการจองแล้ว',
        type: 'booking_confirmed',
        isRead: false,
        ago: const Duration(minutes: 6),
      ),
      _notification(
        id: 2,
        title: 'ได้รับชำระเงินแล้ว',
        type: 'payment_confirmed',
        isRead: true,
        ago: const Duration(hours: 3),
      ),
      _notification(
        id: 3,
        title: 'ถึงกำหนดผ่อนงวดที่ 2',
        type: 'installment_due',
        isRead: true,
        ago: const Duration(days: 1, hours: 2),
      ),
    ]);

    expect(find.text('วันนี้'), findsOneWidget);
    expect(find.text('เมื่อวาน'), findsOneWidget);
    expect(find.text('ยืนยันการจองแล้ว'), findsOneWidget);
    expect(find.text('ถึงกำหนดผ่อนงวดที่ 2'), findsOneWidget);

    // ตัวกรองบอกจำนวนที่ยังไม่อ่านไว้บนปุ่มเลย — เจาะเฉพาะเลขในปุ่ม เพราะ
    // หัวข้อกลุ่มก็มีเลขนับของตัวเองเหมือนกัน
    expect(find.text('ยังไม่อ่าน'), findsOneWidget);
    expect(
      find.descendant(
        of: find
            .ancestor(of: find.text('ยังไม่อ่าน'), matching: find.byType(Row))
            .first,
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('ยังไม่อ่าน'));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันการจองแล้ว'), findsOneWidget);
    expect(find.text('ได้รับชำระเงินแล้ว'), findsNothing);
    expect(find.text('ถึงกำหนดผ่อนงวดที่ 2'), findsNothing);
    // กลุ่มที่ไม่เหลือรายการต้องหายไปทั้งหัวข้อ ไม่ใช่เหลือหัวข้อลอย
    expect(find.text('เมื่อวาน'), findsNothing);

    await tester.tap(find.text('ทั้งหมด'));
    await tester.pumpAndSettle();
    expect(find.text('ถึงกำหนดผ่อนงวดที่ 2'), findsOneWidget);
  });

  testWidgets('กรองแล้วไม่เหลืออะไร บอกว่าอ่านครบ ไม่ใช่ว่าไม่มีแจ้งเตือน', (
    tester,
  ) async {
    await _pump(tester, [
      _notification(
        id: 1,
        title: 'ได้รับชำระเงินแล้ว',
        type: 'payment_confirmed',
        isRead: true,
        ago: const Duration(hours: 2),
      ),
    ]);

    await tester.tap(find.text('ยังไม่อ่าน'));
    await tester.pumpAndSettle();

    expect(find.text('อ่านครบทุกรายการแล้ว'), findsOneWidget);
    expect(find.text('ยังไม่มีการแจ้งเตือน'), findsNothing);
  });

  testWidgets('ไม่มีการแจ้งเตือนเลย = ไม่มีตัวกรองให้กด', (tester) async {
    await _pump(tester, []);

    expect(find.text('ยังไม่มีการแจ้งเตือน'), findsOneWidget);
    expect(find.text('ยังไม่อ่าน'), findsNothing);
  });
}
