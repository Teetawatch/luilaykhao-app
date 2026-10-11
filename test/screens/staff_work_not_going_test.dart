import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/profile_screen.dart';
import 'package:provider/provider.dart';

/// หน้า "งานสตาฟ" ต้องไม่นับคนที่แจ้งไปไม่ได้เป็นคนที่ต้องรอ — เดิมหลอดเช็คอิน
/// ค้างที่ 8/10 ทั้งวันในรอบที่มีคนไม่ไปสองคน และรายชื่อตามจุดรับโชว์คนไม่ไป
/// เป็นวงกลมว่างเหมือนคนที่ยังไม่มา
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  String ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> schedule({
    required int id,
    required String title,
    required DateTime date,
    required int total,
    required int checkedIn,
    int? notGoing,
  }) {
    return {
      'id': id,
      'trip': {'id': id, 'title': title, 'location': 'น่าน'},
      'departure_date': ymd(date),
      'return_date': ymd(date),
      'status': 'confirmed',
      'total_seats': 10,
      'total_confirmed': total,
      'checked_in_count': checkedIn,
      'not_going_count': ?notGoing,
      'pickup_breakdown': [
        {
          'id': 1,
          'label': 'BTS หมอชิต',
          'passenger_count': 3,
          'passengers': [
            {'name': 'ต้น', 'phone': '', 'checked_in': true, 'not_going': false},
            {'name': 'ฝน', 'phone': '', 'checked_in': false, 'not_going': true},
            {'name': 'บี', 'phone': '', 'checked_in': false, 'not_going': false},
          ],
        },
      ],
    };
  }

  Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> data) async {
    tester.view.physicalSize = const Size(2400, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final provider = AppProvider();
    provider.staffSchedules = data;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const MaterialApp(home: StaffWorkScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('today hero leaves not-going travellers out of the count', (
    tester,
  ) async {
    await pump(tester, [
      schedule(
        id: 1,
        title: 'ดอยหลวง',
        date: DateTime.now(),
        total: 10,
        checkedIn: 8,
        notGoing: 2,
      ),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('8 / 8 คน'), findsOneWidget);
    expect(find.text('แจ้งไม่ไป 2 คน · ไม่ต้องรอ'), findsOneWidget);
    expect(find.text('เช็คอินครบแล้ว · เปิดสแกน'), findsOneWidget);
  });

  testWidgets('schedule card counts the people still to board', (
    tester,
  ) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await pump(tester, [
      schedule(
        id: 2,
        title: 'ภูชี้ฟ้า',
        date: tomorrow,
        total: 3,
        checkedIn: 1,
        notGoing: 1,
      ),
    ]);

    expect(find.text('1 / 2 คน'), findsOneWidget);
    expect(
      find.text('เหลือ 1 คน ยังไม่เช็คอิน · แจ้งไม่ไป 1 คน'),
      findsOneWidget,
    );

    // กางจุดรับ → กางรายชื่อ: คนไม่ไปติดป้าย ไม่ใช่วงกลมว่างเหมือนคนที่ยังรอ
    await tester.tap(find.text('จุดรับผู้โดยสาร'));
    await tester.pump();
    await tester.tap(find.text('BTS หมอชิต'));
    await tester.pump();

    expect(find.text('ฝน'), findsOneWidget);
    expect(find.text('แจ้งไม่ไป'), findsOneWidget);
    expect(find.byIcon(Icons.event_busy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
  });

  testWidgets('older server without not_going_count still renders', (
    tester,
  ) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await pump(tester, [
      schedule(id: 3, title: 'เขาช้างเผือก', date: tomorrow, total: 4, checkedIn: 4),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('4 / 4 คน'), findsOneWidget);
    expect(find.text('เช็คอินครบแล้ว'), findsOneWidget);
  });
}
