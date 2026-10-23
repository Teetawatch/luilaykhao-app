import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/models/trip_meals.dart';
import 'package:luilaykhao_app/screens/booking_flow_screen.dart';
import 'package:luilaykhao_app/screens/trip_detail_screen.dart';
import 'package:luilaykhao_app/theme/app_theme.dart';
import 'package:luilaykhao_app/widgets/trip_meal_table.dart';

import '../models/trip_meals_test.dart' show mealsPayload;

/// "อาหารกี่มื้อ" บนหน้าทริป — ต้องตอบได้ทั้งจำนวน มื้อไหน และมื้อไหนจ่ายเอง
/// และต้องหายไปทั้งก้อนเมื่อทริปยังไม่ได้ระบุ (ไม่ใช่โชว์ "ไม่รวมอาหาร")
Widget _wrap(Widget child, {double width = 390, double textScale = 1}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => initializeDateFormatting('th_TH'));

  testWidgets('section มื้ออาหารบอกสรุป รายมื้อ เมนู และหมายเหตุ', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(MealPlanSection(trip: {'meals': mealsPayload()})),
    );
    await tester.pumpAndSettle();

    expect(find.text('มื้ออาหาร'), findsOneWidget);
    expect(find.text('รวมอาหาร 3 มื้อ · จ่ายเอง 1 มื้อ'), findsOneWidget);
    expect(find.text('หมูกระทะ'), findsOneWidget);
    expect(find.text('ข้าวกล่อง'), findsOneWidget);
    expect(find.text('จ่ายเอง'), findsOneWidget);
    expect(find.text('รวมในราคา'), findsNWidgets(3));
    expect(find.text('มีเมนูมังสวิรัติ แจ้งทีมงานล่วงหน้า'), findsOneWidget);
    // กางไว้เสมอ ไม่ต้องกดหา
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
  });

  testWidgets('ทริปที่ยังไม่ระบุมื้ออาหาร ไม่มี section เลย', (tester) async {
    await tester.pumpWidget(
      _wrap(const MealPlanSection(trip: {'meals': null})),
    );

    expect(find.text('มื้ออาหาร'), findsNothing);
    expect(find.byType(TripMealTable), findsNothing);
  });

  testWidgets('กล่องสถิติหัวเรื่องมี "อาหาร 3 มื้อ" ข้างระยะเวลา', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        QuickInfoChips(
          trip: {
            'duration_days': 2,
            'type': 'trekking',
            'difficulty': 'medium',
            'max_participants': 12,
            'meals': mealsPayload(),
          },
        ),
      ),
    );

    expect(find.text('อาหาร 3 มื้อ'), findsOneWidget);
    expect(find.text('ระยะเวลา 2 วัน'), findsOneWidget);
    expect(find.text('สูงสุด 12 คน'), findsOneWidget);
  });

  testWidgets('จอแคบ + ตัวอักษรใหญ่สุด ตารางไม่ล้น', (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        TripMealTable(meals: TripMeals.tryParse(mealsPayload())!),
        width: 320,
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('วันที่ 1'),
      findsNothing,
    ); // หัววันเป็น Text.rich มีวันที่ต่อท้าย
    expect(
      find.textContaining('12 ก.ย. 2569', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('ชีตรายมื้อจากใบจองเปิดได้และปิดได้', (tester) async {
    final meals = TripMeals.tryParse(mealsPayload())!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTripMealsSheet(context, meals),
              child: const Text('เปิด'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    expect(find.text('มื้ออาหาร'), findsOneWidget);
    expect(find.text('หมูกระทะ'), findsOneWidget);

    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    expect(find.text('หมูกระทะ'), findsNothing);
  });

  testWidgets('สรุปก่อนจ่ายเงินบอกว่ารวมอาหารกี่มื้อและจ่ายเองกี่มื้อ', (
    tester,
  ) async {
    Widget card(Map<String, dynamic> trip) => _wrap(
      TripSummaryCard(
        trip: trip,
        schedule: const {'departure_date': '2026-09-12'},
        pickupPoint: const {
          'region_label': 'กรุงเทพฯ',
          'pickup_location': 'ปั๊ม ปตท. วิภาวดี',
        },
        pricePerTraveler: 3200,
        isJoinTrip: false,
      ),
    );

    await tester.pumpWidget(
      card({'title': 'ภูกระดึง', 'meals': mealsPayload()}),
    );
    expect(find.text('รวมอาหาร 3 มื้อ · จ่ายเอง 1 มื้อ'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);

    await tester.pumpWidget(card({'title': 'ภูกระดึง'}));
    expect(find.byIcon(Icons.restaurant_rounded), findsNothing);
  });
}
