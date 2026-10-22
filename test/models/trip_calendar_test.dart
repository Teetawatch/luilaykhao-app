import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/models/trip_calendar.dart';

/// ปฏิทินทริป — แปลงข้อมูลจาก GET /trips/calendar และคิดตารางเดือนฝั่งแอป
void main() {
  Map<String, dynamic> round({
    int id = 1,
    int tripId = 10,
    String date = '2026-11-06',
    bool international = false,
    int seats = 8,
    bool isFull = false,
    bool isLow = false,
    num price = 2990,
    num? original,
  }) => {
    'id': id,
    'trip': {
      'id': tripId,
      'title': 'ภูกระดึง',
      'slug': 'phu-kradueng-$tripId',
      'duration_days': 3,
      'cover_image': '/storage/trips/a.jpg',
      'is_international': international,
    },
    'departure_date': date,
    'return_date': '2026-11-08',
    'date_label': '6 – 8 พฤศจิกายน 2569',
    'price': price,
    'original_price': original,
    'on_flash_sale': false,
    'seats_left': seats,
    'is_full': isFull,
    'is_low': isLow,
    'status_label': isFull ? 'เต็มแล้ว · จองคิวรอได้' : 'ว่าง $seats ที่',
  };

  group('parseCalendarDate', () {
    test('อ่านวันที่ล้วนเป็นเที่ยงคืนของวันนั้น ไม่เลื่อนวันตามโซน', () {
      expect(parseCalendarDate('2026-11-06'), DateTime(2026, 11, 6));
      expect(parseCalendarDate('2026-11-06T23:30:00Z'), DateTime(2026, 11, 6));
    });

    test('วันที่ไม่มีจริงหรืออ่านไม่ออกคืน null แทนการปัดไปเดือนถัดไป', () {
      expect(parseCalendarDate('2026-02-31'), isNull);
      expect(parseCalendarDate('2026-13-01'), isNull);
      expect(parseCalendarDate(''), isNull);
      expect(parseCalendarDate(null), isNull);
    });
  });

  test('bangkokToday นับวันตามเวลาไทย ไม่ใช่โซนของเครื่อง', () {
    // 17:30 UTC = 00:30 ของวันถัดไปที่ไทย
    expect(
      bangkokToday(DateTime.utc(2026, 11, 5, 17, 30)),
      DateTime(2026, 11, 6),
    );
    expect(
      bangkokToday(DateTime.utc(2026, 11, 5, 16, 59)),
      DateTime(2026, 11, 5),
    );
  });

  group('monthGridCells', () {
    test('เริ่มสัปดาห์วันอาทิตย์ และยาวเป็นจำนวนเต็มสัปดาห์', () {
      // 1 ส.ค. 2569 เป็นวันเสาร์ → เว้นหกช่อง และ 31 วันกินหกแถว
      final august = monthGridCells(2026, 8);
      expect(august.take(6), everyElement(isNull));
      expect(august[6], DateTime(2026, 8, 1));
      expect(august.length, 42);
      expect(august.whereType<DateTime>().length, 31);

      // ก.พ. 2569 เริ่มวันอาทิตย์และมี 28 วันพอดีสี่แถว
      final february = monthGridCells(2026, 2);
      expect(february.first, DateTime(2026, 2, 1));
      expect(february.length, 28);
    });

    test('ธันวาคมไม่ล้นไปปีหน้า', () {
      final december = monthGridCells(2026, 12);
      expect(december.whereType<DateTime>().last, DateTime(2026, 12, 31));
      expect(december.length % 7, 0);
    });
  });

  group('TripCalendarMonth.fromJson', () {
    Map<String, dynamic> payload({List<dynamic>? days}) => {
      'month': '2026-11',
      'month_label': 'พฤศจิกายน 2569',
      'is_current_month': false,
      'months': [
        {'value': '2026-10', 'label': 'ตุลาคม 2569', 'is_current': true},
        {'value': '2026-11', 'label': 'พฤศจิกายน 2569'},
        {'value': 'oops', 'label': 'อ่านไม่ออก'},
      ],
      'days':
          days ??
          [
            {
              'date': '2026-11-14',
              'date_label': '14 พ.ย. 2569',
              'weekday': 'ส.',
              'rounds': [round(id: 3, date: '2026-11-14', international: true)],
            },
            {
              'date': '2026-11-06',
              'date_label': '6 พ.ย. 2569',
              'weekday': 'ศ.',
              'rounds': [round(id: 1), round(id: 2, tripId: 11)],
            },
          ],
      'hot': [round(id: 9)],
      'hot_days': 10,
    };

    test('เรียงวัน แยกรอบ และตัดเดือนที่อ่านไม่ออกทิ้ง', () {
      final month = TripCalendarMonth.fromJson(payload())!;
      expect(month.year, 2026);
      expect(month.monthNumber, 11);
      expect(month.days.map((d) => d.date.day), [6, 14]);
      expect(month.days.first.rounds.map((r) => r.id), [1, 2]);
      expect(month.months.map((m) => m.value), ['2026-10', '2026-11']);
      expect(month.months.first.chipLabel, 'เดือนนี้');
      expect(month.months.last.chipLabel, 'พฤศจิกายน 2569');
      expect(month.hot.single.id, 9);
      expect(month.nextMonth, isNull);
    });

    test('วันนอกเดือนและวันที่ไม่มีรอบที่ใช้ได้ไม่ขึ้นในตาราง', () {
      final month = TripCalendarMonth.fromJson(
        payload(
          days: [
            {
              'date': '2026-12-01',
              'rounds': [round(date: '2026-12-01')],
            },
            {
              'date': '2026-11-20',
              'rounds': [
                {
                  'id': 5,
                  'trip': {'slug': ''},
                },
              ],
            },
            {
              'date': 'bad',
              'rounds': [round()],
            },
          ],
        ),
      )!;
      expect(month.days, isEmpty);
    });

    test('ไม่มีเดือนที่อ่านได้ = วาดไม่ได้ คืน null', () {
      expect(TripCalendarMonth.fromJson({'month': '2026-13'}), isNull);
      expect(TripCalendarMonth.fromJson(null), isNull);
    });

    test('กรองในประเทศ/ต่างประเทศ วันที่ไม่เหลือรอบหายไปทั้งวัน', () {
      final month = TripCalendarMonth.fromJson(payload())!;
      expect(month.hasBothDestinations, isTrue);
      expect(
        month.daysFor(CalendarDestination.international).map((d) => d.date.day),
        [14],
      );
      expect(
        month.daysFor(CalendarDestination.domestic).map((d) => d.date.day),
        [6],
      );
      expect(month.daysFor(CalendarDestination.all), hasLength(2));
      expect(month.hotFor(CalendarDestination.international), isEmpty);
    });

    test('เดือนถัดไปมาจากรายการเดือน', () {
      final json = payload()..['month'] = '2026-10';
      expect(TripCalendarMonth.fromJson(json)!.nextMonth?.value, '2026-11');
    });
  });

  group('TripCalendarRound', () {
    test('ที่นั่งหมดถือว่าเต็ม แม้สถานะจะยังไม่บอก', () {
      final r = TripCalendarRound.fromJson(round(seats: 0, isLow: true));
      expect(r.isFull, isTrue);
      expect(r.isLow, isFalse);
    });

    test('ราคาเดิมที่ไม่สูงกว่าราคาขายไม่ถือว่าลด', () {
      expect(
        TripCalendarRound.fromJson(
          round(price: 2990, original: 2990),
        ).originalPrice,
        isNull,
      );
      expect(
        TripCalendarRound.fromJson(
          round(price: 2990, original: 3490),
        ).originalPrice,
        3490,
      );
    });

    test('ไม่มีข้อความสถานะจากเซิร์ฟเวอร์ก็ยังมีป้ายที่นั่ง', () {
      final json = round(seats: 2, isLow: true)..remove('status_label');
      expect(TripCalendarRound.fromJson(json).seatLabel, 'เหลือ 2 ที่');
      final full = round(isFull: true)..remove('status_label');
      expect(
        TripCalendarRound.fromJson(full).seatLabel,
        'เต็มแล้ว · จองคิวรอได้',
      );
    });
  });
}
