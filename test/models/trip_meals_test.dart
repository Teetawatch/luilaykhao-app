import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/models/trip_meals.dart';

/// รูปร่างเดียวกับ TripMealPlan::present() ฝั่ง PHP
Map<String, dynamic> mealsPayload() => {
  'days': [
    {
      'day': 1,
      'label': 'วันที่ 1',
      'date': '2026-09-12',
      'date_label': '12 ก.ย. 2569',
      'meals': [
        {
          'key': 'breakfast',
          'label': 'เช้า',
          'status': 'none',
          'status_label': 'ไม่มี',
          'note': null,
        },
        {
          'key': 'lunch',
          'label': 'กลางวัน',
          'status': 'self',
          'status_label': 'จ่ายเอง',
          'note': 'แวะร้านริมทาง',
        },
        {
          'key': 'dinner',
          'label': 'เย็น',
          'status': 'included',
          'status_label': 'รวมในราคา',
          'note': 'หมูกระทะ',
        },
      ],
      'line': 'กลางวัน – แวะร้านริมทาง (จ่ายเอง) · เย็น – หมูกระทะ',
    },
    {
      'day': 2,
      'label': 'วันที่ 2',
      'date': '2026-09-13',
      'date_label': '13 ก.ย. 2569',
      'meals': [
        {
          'key': 'breakfast',
          'label': 'เช้า',
          'status': 'included',
          'status_label': 'รวมในราคา',
          'note': null,
        },
        {
          'key': 'lunch',
          'label': 'กลางวัน',
          'status': 'included',
          'status_label': 'รวมในราคา',
          'note': 'ข้าวกล่อง',
        },
        {
          'key': 'dinner',
          'label': 'เย็น',
          'status': 'none',
          'status_label': 'ไม่มี',
          'note': null,
        },
      ],
      'line': 'เช้า · กลางวัน – ข้าวกล่อง',
    },
  ],
  'included_count': 3,
  'self_count': 1,
  'label': 'อาหาร 3 มื้อ',
  'summary': 'รวมอาหาร 3 มื้อ · จ่ายเอง 1 มื้อ',
  'note': 'มีเมนูมังสวิรัติ แจ้งทีมงานล่วงหน้า',
};

void main() {
  test('อ่าน payload ของ backend ครบทุกช่อง', () {
    final meals = TripMeals.tryParse(mealsPayload())!;

    expect(meals.days, hasLength(2));
    expect(meals.includedCount, 3);
    expect(meals.selfCount, 1);
    expect(meals.label, 'อาหาร 3 มื้อ');
    expect(meals.summary, 'รวมอาหาร 3 มื้อ · จ่ายเอง 1 มื้อ');
    expect(meals.note, 'มีเมนูมังสวิรัติ แจ้งทีมงานล่วงหน้า');
    expect(meals.showDates, isTrue);
    expect(meals.days.first.meals[1].status, TripMealStatus.selfPay);
    expect(meals.days.first.meals[2].note, 'หมูกระทะ');
  });

  test(
    'ทริปที่ยังไม่ระบุ หรือ backend รุ่นเก่า = null ไม่ใช่ "ไม่รวมอาหาร"',
    () {
      expect(TripMeals.tryParse(null), isNull);
      expect(TripMeals.tryParse('meals'), isNull);
      expect(
        TripMeals.tryParse({'days': [], 'summary': 'ไม่รวมอาหาร'}),
        isNull,
      );
    },
  );

  test('สถานะที่ไม่รู้จักไม่กลายเป็นมื้อที่รวมในราคา', () {
    final payload = mealsPayload();
    (payload['days'] as List).first['meals'][0] = {
      'key': 'breakfast',
      'label': 'เช้า',
      'status': 'free',
      'note': 'บุฟเฟต์',
    };

    final meal = TripMeals.tryParse(payload)!.days.first.meals.first;

    expect(meal.status, TripMealStatus.none);
    expect(meal.statusLabel, 'ไม่มี');
    // มื้อที่ไม่มี ไม่ควรมีเมนูโชว์
    expect(meal.note, isNull);
  });

  test('ทริปวันเดียวไม่ต่อวันที่ท้ายหัววัน', () {
    final payload = mealsPayload();
    payload['days'] = [(payload['days'] as List).first];

    expect(TripMeals.tryParse(payload)!.showDates, isFalse);
  });
}
