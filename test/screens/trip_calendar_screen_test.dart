import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/models/trip_calendar.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/providers/trip_alert_provider.dart';
import 'package:luilaykhao_app/providers/wishlist_provider.dart';
import 'package:luilaykhao_app/screens/trip_calendar_screen.dart';
import 'package:luilaykhao_app/screens/trip_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// หน้าเปิดทริปจริงขอข้อมูลผ่านเมธอดเหล่านี้ — ตอบเปล่า ๆ ให้หน้าเปิดได้
class _FakeApp extends AppProvider {
  @override
  Future<Map<String, dynamic>> trip(String slug) async => {
    'id': 7,
    'slug': slug,
    'title': 'ภูกระดึง',
  };

  @override
  Future<List<dynamic>> schedules(String slug) async => [];

  @override
  Future<List<dynamic>> tripReviews(int tripId) async => [];

  @override
  Future<Map<String, dynamic>> reviewStats({int? tripId}) async => {};

  @override
  Future<void> ensurePickupVehicleClasses({bool force = false}) async {}

  @override
  void recordRecentTrip(Map<String, dynamic> trip) {}
}

/// ปฏิทินทริป — ตารางเดือน แตะวัน เปลี่ยนเดือน กรองปลายทาง และพาไปหน้าทริป
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
    // ฟอนต์จริงของแอป — ฟอนต์ทดสอบวาดอักษรไทยกว้างเกินจริง และเทสต์จอแคบ
    // ต้องวัดด้วยความกว้างที่ลูกค้าเห็น
    Future<void> load(String family, List<String> assets) async {
      final loader = FontLoader(family);
      for (final asset in assets) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }

    await load('Inter', ['assets/fonts/Inter-Variable.ttf']);
    await load('LINE Seed Sans TH', [
      'assets/fonts/LINESeedSansTH_A_Rg.ttf',
      'assets/fonts/LINESeedSansTH_A_Bd.ttf',
    ]);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  String dateKey(DateTime d) =>
      '${calendarMonthKey(d)}-${d.day.toString().padLeft(2, '0')}';

  final today = bangkokToday();
  // เดือนอนาคตที่ไม่ใช่เดือนนี้ — วันในเดือนนี้บางวันผ่านไปแล้วตามวันที่รันเทสต์
  final future = DateTime(today.year, today.month + 2, 1);
  final futureNext = DateTime(today.year, today.month + 3, 1);
  final futureKey = calendarMonthKey(future);
  final futureNextKey = calendarMonthKey(futureNext);
  final currentKey = calendarMonthKey(today);

  Map<String, dynamic> round({
    required int id,
    required DateTime date,
    String title = 'ภูกระดึง',
    int tripId = 10,
    bool international = false,
    int seats = 8,
    bool full = false,
    String? daysLeft,
  }) => {
    'id': id,
    'trip': {
      'id': tripId,
      'title': title,
      'slug': 'trip-$tripId',
      'duration_days': 3,
      'cover_image': null,
      'is_international': international,
    },
    'departure_date': dateKey(date),
    'return_date': dateKey(date.add(const Duration(days: 2))),
    'date_label': '${date.day} – ${date.day + 2} เดือนทดสอบ',
    'price': 2990,
    'original_price': 3490,
    'on_flash_sale': true,
    'seats_left': full ? 0 : seats,
    'is_full': full,
    'is_low': !full && seats <= 3,
    'status_label': full
        ? 'เต็มแล้ว · จองคิวรอได้'
        : seats <= 3
        ? 'เหลือ $seats ที่'
        : 'ว่าง $seats ที่',
    'days_left_label': daysLeft,
  };

  Map<String, dynamic> day(DateTime date, List<Map<String, dynamic>> rounds) =>
      {
        'date': dateKey(date),
        'date_label': '${date.day} เดือนทดสอบ',
        'weekday': 'ส.',
        'rounds': rounds,
      };

  List<Map<String, dynamic>> months() => [
    {'value': currentKey, 'label': 'เดือนปัจจุบัน', 'is_current': true},
    {
      'value': calendarMonthKey(DateTime(today.year, today.month + 1, 1)),
      'label': 'เดือนหน้า',
    },
    {'value': futureKey, 'label': 'เดือนอนาคต'},
    {'value': futureNextKey, 'label': 'เดือนถัดไปอีก'},
  ];

  Map<String, dynamic> month(
    String key, {
    List<Map<String, dynamic>> days = const [],
    List<Map<String, dynamic>> hot = const [],
  }) => {
    'month': key,
    'month_label': 'เดือน $key',
    'is_current_month': key == currentKey,
    'months': months(),
    'days': days,
    'summary': {},
    'hot': hot,
    'hot_days': 10,
  };

  final d6 = DateTime(future.year, future.month, 6);
  final d14 = DateTime(future.year, future.month, 14);
  final d20 = DateTime(future.year, future.month, 20);

  Map<String, dynamic> futureMonth() => month(
    futureKey,
    days: [
      day(d6, [
        round(id: 1, date: d6, title: 'ดอยหลวงเชียงดาว', tripId: 10),
        round(id: 2, date: d6, title: 'ภูชี้ฟ้า', tripId: 11, seats: 2),
      ]),
      day(d14, [
        round(
          id: 3,
          date: d14,
          title: 'ฟูจิซัง',
          tripId: 12,
          international: true,
          full: true,
        ),
      ]),
      day(d20, [
        for (var i = 0; i < 4; i++)
          round(id: 40 + i, date: d20, title: 'รอบเยอะ $i', tripId: 20 + i),
      ]),
    ],
  );

  http.Response ok(Object? data) => http.Response(
    jsonEncode({'success': true, 'data': data, 'message': 'สำเร็จ'}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<List<http.Request>> pump(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler, {
    String? initialMonth,
    Size size = const Size(390, 844),
    double textScale = 1,
    Future<void> Function()? then,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final requests = <http.Request>[];
    final app = _FakeApp();

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppProvider>.value(value: app),
              ChangeNotifierProvider(create: (_) => WishlistProvider()),
              ChangeNotifierProvider(create: (_) => TripAlertProvider()),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: TripCalendarScreen(initialMonth: initialMonth),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (then != null) await then();
      },
      () => MockClient((r) {
        requests.add(r);
        return handler(r);
      }),
    );
    return requests;
  }

  Finder dayCell(int dayNumber) => find.text('$dayNumber');

  /// ชิปเดือนเป็นแถบเลื่อนแนวนอน — ชิปท้าย ๆ อยู่นอกจอจนกว่าจะปัดไปถึง
  Future<void> tapMonth(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(ChoiceChip, label);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
  }

  testWidgets('ตารางเดือนบอกวันที่มีรอบ แตะวันแล้วเห็นเฉพาะรอบของวันนั้น', (
    tester,
  ) async {
    final requests = await pump(
      tester,
      (r) async => ok(futureMonth()),
      initialMonth: futureKey,
      then: () async {
        expect(find.text('ดอยหลวงเชียงดาว'), findsOneWidget);
        expect(find.text('ภูชี้ฟ้า'), findsOneWidget);
        expect(find.text('เหลือ 2 ที่'), findsOneWidget);
        expect(find.text('7 ทริป · 7 รอบ'), findsOneWidget);
        // วันที่มีรอบเกินสามจุดย่อเป็นสองจุด + ตัวเลข
        expect(find.text('+2'), findsOneWidget);

        await tester.tap(dayCell(14));
        await tester.pumpAndSettle();
        expect(find.text('ฟูจิซัง'), findsOneWidget);
        expect(find.text('เต็มแล้ว · จองคิวรอได้'), findsWidgets);
        expect(find.text('ดอยหลวงเชียงดาว'), findsNothing);
        expect(find.text('ออกเดินทางวันที่เลือก · 1 รอบ'), findsOneWidget);

        // แตะวันเดิมซ้ำ = กลับไปดูทั้งเดือน
        await tester.tap(dayCell(14));
        await tester.pumpAndSettle();
        expect(find.text('ดอยหลวงเชียงดาว'), findsOneWidget);

        await tester.tap(dayCell(6));
        await tester.pumpAndSettle();
        expect(find.text('ฟูจิซัง'), findsNothing);
        await tester.tap(find.text('ดูทั้งเดือน'));
        await tester.pumpAndSettle();
        expect(find.text('ฟูจิซัง'), findsOneWidget);

        // วันที่ไม่มีรอบแตะแล้วไม่มีอะไรเปลี่ยน
        await tester.tap(dayCell(10));
        await tester.pumpAndSettle();
        expect(find.text('ดูทั้งเดือน'), findsNothing);
      },
    );

    expect(requests, hasLength(1));
    expect(requests.single.url.path, endsWith('/trips/calendar'));
    expect(requests.single.url.queryParameters['month'], futureKey);
  });

  testWidgets(
    'ไม่ระบุเดือน = ขอเดือนนี้โดยไม่ส่งพารามิเตอร์ และเห็นโซนไฟไหม้',
    (tester) async {
      final requests = await pump(
        tester,
        (r) async => ok(
          month(
            currentKey,
            days: [
              day(today, [round(id: 1, date: today, title: 'ออกวันนี้')]),
            ],
            hot: [
              round(id: 9, date: today, title: 'ทริปด่วน', daysLeft: 'วันนี้'),
            ],
          ),
        ),
      );

      expect(requests.single.url.queryParameters.containsKey('month'), isFalse);
      expect(find.text('ทริปด่วน'), findsOneWidget);
      expect(find.text('ออกวันนี้'), findsOneWidget);
      // ป้าย "วันนี้" ทั้งบนการ์ดไฟไหม้และบนหัววันในรายการ
      expect(find.text('วันนี้'), findsNWidgets(2));
    },
  );

  testWidgets('เปลี่ยนเดือนด้วยชิปและลูกศร เดือนที่โหลดแล้วไม่โหลดซ้ำ', (
    tester,
  ) async {
    final requests = await pump(
      tester,
      (r) async {
        final key = r.url.queryParameters['month'];
        if (key == futureNextKey) {
          return ok(
            month(
              futureNextKey,
              days: [
                day(DateTime(futureNext.year, futureNext.month, 3), [
                  round(
                    id: 77,
                    date: DateTime(futureNext.year, futureNext.month, 3),
                    title: 'ทริปเดือนถัดไป',
                  ),
                ]),
              ],
            ),
          );
        }
        return ok(futureMonth());
      },
      initialMonth: futureKey,
      then: () async {
        await tester.tap(find.byTooltip('เดือนถัดไป'));
        await tester.pumpAndSettle();
        expect(find.text('ทริปเดือนถัดไป'), findsOneWidget);
        expect(find.text('ดอยหลวงเชียงดาว'), findsNothing);
        // เดือนสุดท้ายในรายการ — ลูกศรถัดไปกดไม่ได้
        final next = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
        );
        expect(next.onPressed, isNull);

        await tapMonth(tester, 'เดือนอนาคต');
        await tester.pumpAndSettle();
        expect(find.text('ดอยหลวงเชียงดาว'), findsOneWidget);

        await tapMonth(tester, 'เดือนถัดไปอีก');
        await tester.pumpAndSettle();
        expect(find.text('ทริปเดือนถัดไป'), findsOneWidget);
      },
    );

    expect(requests.map((r) => r.url.queryParameters['month']), [
      futureKey,
      futureNextKey,
    ]);
  });

  testWidgets('คำตอบของเดือนที่กดไว้ก่อนมาช้า ไม่ทับเดือนที่เลือกล่าสุด', (
    tester,
  ) async {
    final slow = Completer<http.Response>();
    await pump(
      tester,
      (r) {
        final key = r.url.queryParameters['month'];
        if (key == futureKey) return Future.value(ok(futureMonth()));
        if (key == futureNextKey) {
          return Future.value(
            ok(
              month(
                futureNextKey,
                days: [
                  day(DateTime(futureNext.year, futureNext.month, 3), [
                    round(
                      id: 77,
                      date: DateTime(futureNext.year, futureNext.month, 3),
                      title: 'ทริปเดือนถัดไป',
                    ),
                  ]),
                ],
              ),
            ),
          );
        }
        return slow.future;
      },
      initialMonth: futureKey,
      then: () async {
        await tapMonth(tester, 'เดือนหน้า');
        await tester.pump();
        await tapMonth(tester, 'เดือนถัดไปอีก');
        await tester.pumpAndSettle();
        expect(find.text('ทริปเดือนถัดไป'), findsOneWidget);

        final lateKey = calendarMonthKey(
          DateTime(today.year, today.month + 1, 1),
        );
        slow.complete(
          ok(
            month(
              lateKey,
              days: [
                day(DateTime(future.year, future.month - 1, 2), [
                  round(
                    id: 5,
                    date: DateTime(future.year, future.month - 1, 2),
                    title: 'ทริปที่มาช้า',
                  ),
                ]),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('ทริปเดือนถัดไป'), findsOneWidget);
        expect(find.text('ทริปที่มาช้า'), findsNothing);
      },
    );
  });

  testWidgets('กรองต่างประเทศ เหลือเฉพาะรอบต่างประเทศ ทั้งตารางและรายการ', (
    tester,
  ) async {
    await pump(
      tester,
      (r) async => ok(futureMonth()),
      initialMonth: futureKey,
      then: () async {
        await tester.tap(find.text('ต่างประเทศ'));
        await tester.pumpAndSettle();
        expect(find.text('ฟูจิซัง'), findsOneWidget);
        expect(find.text('ดอยหลวงเชียงดาว'), findsNothing);
        expect(find.text('+2'), findsNothing);

        // เลือกวันไว้แล้วเปลี่ยนตัวกรองจนวันนั้นไม่เหลือรอบ = กลับไปดูทั้งเดือน
        await tester.tap(dayCell(14));
        await tester.pumpAndSettle();
        expect(find.text('ดูทั้งเดือน'), findsOneWidget);
        await tester.tap(find.text('ในประเทศ'));
        await tester.pumpAndSettle();
        expect(find.text('ดูทั้งเดือน'), findsNothing);
        expect(find.text('ฟูจิซัง'), findsNothing);
        expect(find.text('ดอยหลวงเชียงดาว'), findsOneWidget);
      },
    );
  });

  testWidgets('ตัวกรองค้างจากเดือนก่อน แต่เดือนใหม่ไม่มีฝั่งนั้น ยังกดออกได้', (
    tester,
  ) async {
    await pump(
      tester,
      (r) async => r.url.queryParameters['month'] == futureNextKey
          ? ok(
              month(
                futureNextKey,
                days: [
                  day(DateTime(futureNext.year, futureNext.month, 3), [
                    round(
                      id: 77,
                      date: DateTime(futureNext.year, futureNext.month, 3),
                      title: 'ทริปในประเทศอย่างเดียว',
                    ),
                  ]),
                ],
              ),
            )
          : ok(futureMonth()),
      initialMonth: futureKey,
      then: () async {
        await tester.tap(find.text('ต่างประเทศ'));
        await tester.pumpAndSettle();
        await tapMonth(tester, 'เดือนถัดไปอีก');
        await tester.pumpAndSettle();

        expect(find.text('เดือนนี้ยังไม่มีทริปต่างประเทศ'), findsOneWidget);
        await tester.ensureVisible(find.text('ดูทั้งหมด'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ดูทั้งหมด'));
        await tester.pumpAndSettle();
        expect(find.text('ทริปในประเทศอย่างเดียว'), findsOneWidget);
        // เดือนนี้มีฝั่งเดียว ล้างตัวกรองแล้วชิปก็หายไป
        expect(find.text('ต่างประเทศ'), findsNothing);
      },
    );
  });

  testWidgets('เดือนที่ยังไม่มีรอบ ชวนไปดูเดือนถัดไป', (tester) async {
    final requests = await pump(
      tester,
      (r) async => r.url.queryParameters['month'] == futureNextKey
          ? ok(month(futureNextKey))
          : ok(month(futureKey)),
      initialMonth: futureKey,
      then: () async {
        expect(find.text('เดือนนี้ยังไม่มีรอบเปิดจอง'), findsOneWidget);
        expect(find.textContaining('ลองดูเดือนถัดไป'), findsOneWidget);
        await tester.ensureVisible(find.text('ดูเดือนถัดไปอีก'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ดูเดือนถัดไปอีก'));
        await tester.pumpAndSettle();
        // เดือนสุดท้ายแล้ว ไม่มีปุ่มไปต่อ
        expect(find.text('เดือนนี้ยังไม่มีรอบเปิดจอง'), findsOneWidget);
        expect(find.textContaining('ดูเดือน'), findsNothing);
        expect(find.textContaining('รอบใหม่จะขึ้นที่นี่'), findsOneWidget);
      },
    );
    expect(requests.last.url.queryParameters['month'], futureNextKey);
  });

  testWidgets('โหลดไม่สำเร็จ แตะลองอีกครั้งแล้วโหลดใหม่ได้', (tester) async {
    var calls = 0;
    await pump(
      tester,
      (r) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            jsonEncode({'success': false, 'message': 'ระบบขัดข้อง'}),
            500,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return ok(futureMonth());
      },
      initialMonth: futureKey,
      then: () async {
        expect(find.text('ลองอีกครั้ง'), findsOneWidget);
        await tester.tap(find.text('ลองอีกครั้ง'));
        await tester.pumpAndSettle();
        expect(find.text('ดอยหลวงเชียงดาว'), findsOneWidget);
      },
    );
  });

  testWidgets('แตะรอบแล้วเปิดหน้าทริปโดยเลือกรอบนั้นไว้ให้', (tester) async {
    await pump(
      tester,
      (r) async => ok(futureMonth()),
      initialMonth: futureKey,
      then: () async {
        await tester.tap(find.text('ภูชี้ฟ้า'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final detail = tester.widget<TripDetailScreen>(
          find.byType(TripDetailScreen),
        );
        expect(detail.slug, 'trip-11');
        expect(detail.initialScheduleId, 2);

        // หน้าทริปมีตัวจับเวลาโพลที่นั่ง — ถอดทั้งต้นไม้ออกก่อนจบเทสต์
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 30));
      },
    );
  });

  testWidgets('จอแคบและตัวอักษรใหญ่สุด ไม่มีอะไรล้นจอ', (tester) async {
    await pump(
      tester,
      (r) async => ok(
        month(
          currentKey,
          days: [
            day(today, [
              round(
                id: 1,
                date: today,
                title:
                    'ทริปชื่อยาวมาก ๆ เดินป่าขึ้นยอดดอยสูงสุดในสยามสามวันสองคืน',
                seats: 1,
              ),
            ]),
          ],
          hot: [
            round(
              id: 9,
              date: today,
              title: 'ทริปด่วนชื่อยาวมากจนต้องตัดคำทิ้งบนการ์ด',
              daysLeft: 'พรุ่งนี้',
            ),
          ],
        ),
      ),
      size: const Size(320, 640),
      textScale: 1.3,
      then: () async {
        await tester.tap(find.text('${today.day}').first);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await tester.pumpAndSettle();
      },
    );
    expect(tester.takeException(), isNull);
  });
}
