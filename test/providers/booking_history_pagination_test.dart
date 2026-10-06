import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ประวัติการจองโหลดทีละหน้า — ตัวเลขต้องนับครบทั้งชุด และหน้าที่โหลดค้างจาก
/// รายการชุดเก่าต้องไม่ถูกต่อท้ายรายการชุดใหม่
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, dynamic> booking(int id, String status) => {
    'id': id,
    'booking_ref': 'LLK-20250101-${id.toString().padLeft(4, '0')}',
    'status': status,
  };

  Map<String, dynamic> meta({
    required int page,
    required int lastPage,
    int historyCount = 45,
    int travelled = 40,
    int cancelled = 5,
  }) => {
    'current_page': page,
    'last_page': lastPage,
    'per_page': 20,
    'total': historyCount,
    'history_count': historyCount,
    'travelled_count': travelled,
    'cancelled_count': cancelled,
    'destinations_count': 7,
  };

  http.Response page(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> m,
  ) => http.Response(
    jsonEncode({'success': true, 'data': items, 'meta': m}),
    200,
    headers: {'content-type': 'application/json'},
  );

  AppProvider seeded() {
    final app = AppProvider();
    app.api.token = 'test-token';
    app.debugApplyBookingsFirstPage(
      current: [booking(1, 'confirmed'), booking(2, 'pending')],
      history: [
        for (var i = 100; i < 119; i++) booking(i, 'confirmed'),
        booking(119, 'cancelled'),
      ],
      historyMeta: meta(page: 1, lastPage: 3),
    );
    return app;
  }

  test('counts include the history pages that are not loaded yet', () {
    final app = seeded();

    expect(app.bookings, hasLength(22));
    expect(app.bookingHistoryHasMore, isTrue);
    // 2 ใบที่ยังไม่จบ + ประวัติทั้งชุด 45 ใบ
    expect(app.bookingsTotalCount, 47);
    // โหลดแล้ว 19 เดินทางแล้ว + 1 ยกเลิก → เหลือ 21 + 4 ที่ยังไม่โหลด
    expect(app.unloadedTravelledCount, 21);
    expect(app.unloadedCancelledCount, 4);
    expect(app.travelledDestinationsCount, 7);
  });

  test('without server meta the loaded list is treated as everything', () {
    final app = AppProvider();
    app.bookings = [booking(1, 'confirmed'), booking(2, 'cancelled')];

    expect(app.bookingHistoryHasMore, isFalse);
    expect(app.bookingsTotalCount, 2);
    expect(app.unloadedTravelledCount, 0);
    expect(app.unloadedCancelledCount, 0);
    expect(app.travelledDestinationsCount, isNull);
  });

  test(
    'loading the next page appends it, skips duplicates and stops at the end',
    () async {
      final app = seeded();
      final requested = <Uri>[];

      await http.runWithClient(
        () async {
          await app.loadMoreBookingHistory();
          await app.loadMoreBookingHistory();
          // ครบแล้ว — ไม่ยิงเพิ่ม
          await app.loadMoreBookingHistory();
        },
        () => MockClient((request) async {
          requested.add(request.url);
          final p = int.parse(request.url.queryParameters['page']!);
          if (p == 2) {
            // ทริปที่เพิ่งจบทำให้รายการขยับ — ใบสุดท้ายของหน้าแรกโผล่ซ้ำ
            return page([
              booking(119, 'cancelled'),
              for (var i = 120; i < 139; i++) booking(i, 'confirmed'),
            ], meta(page: 2, lastPage: 3));
          }
          return page([
            for (var i = 139; i < 143; i++) booking(i, 'confirmed'),
            for (var i = 143; i < 147; i++) booking(i, 'cancelled'),
          ], meta(page: 3, lastPage: 3));
        }),
      );

      expect(requested, hasLength(2));
      expect(requested.first.queryParameters, {
        'scope': 'history',
        'per_page': '20',
        'page': '2',
      });
      final ids = app.bookings.map((b) => b['id']).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'no duplicates');
      expect(app.bookings, hasLength(2 + 47));
      expect(app.bookingHistoryHasMore, isFalse);
      expect(app.bookingHistoryLoading, isFalse);
      expect(app.unloadedTravelledCount, 0);
      expect(app.unloadedCancelledCount, 0);
    },
  );

  test(
    'a page that arrives after the list was reloaded is thrown away',
    () async {
      final app = seeded();
      final gate = Completer<void>();

      late Future<void> pending;
      await http.runWithClient(
        () async {
          pending = app.loadMoreBookingHistory();
          await Future<void>.delayed(Duration.zero);
          expect(app.bookingHistoryLoading, isTrue);

          // ผู้ใช้ดึงลงรีเฟรช — ได้หน้าแรกชุดใหม่ก่อนที่หน้าเก่าจะกลับมา
          app.debugApplyBookingsFirstPage(
            current: [booking(1, 'confirmed')],
            history: [booking(500, 'confirmed')],
            historyMeta: meta(
              page: 1,
              lastPage: 1,
              historyCount: 1,
              travelled: 1,
              cancelled: 0,
            ),
          );
          gate.complete();
          await pending;
        },
        () => MockClient((request) async {
          await gate.future;
          return page([booking(999, 'confirmed')], meta(page: 2, lastPage: 3));
        }),
      );

      expect(app.bookings.map((b) => b['id']), [1, 500]);
      expect(app.bookingHistoryHasMore, isFalse);
      expect(app.bookingHistoryLoading, isFalse);
    },
  );

  test(
    'a failed page keeps the list, reports the error and can be retried',
    () async {
      final app = seeded();
      var fail = true;

      await http.runWithClient(
        () async {
          await app.loadMoreBookingHistory();
          expect(app.bookingHistoryError, isNotNull);
          expect(app.bookings, hasLength(22));
          expect(app.bookingHistoryHasMore, isTrue);

          fail = false;
          await app.loadMoreBookingHistory();
        },
        () => MockClient((request) async {
          if (fail) return http.Response('{"message":"x"}', 500);
          return page([booking(200, 'confirmed')], meta(page: 2, lastPage: 3));
        }),
      );

      expect(app.bookingHistoryError, isNull);
      expect(app.bookings.last['id'], 200);
    },
  );

  test('loadAllBookingHistory walks every remaining page', () async {
    final app = seeded();
    var calls = 0;

    await http.runWithClient(
      app.loadAllBookingHistory,
      () => MockClient((request) async {
        calls++;
        final p = int.parse(request.url.queryParameters['page']!);
        return page([
          booking(1000 + p, 'confirmed'),
        ], meta(page: p, lastPage: 3));
      }),
    );

    expect(calls, 2);
    expect(app.bookingHistoryHasMore, isFalse);
  });

  test(
    'loadAllBookingHistory gives up on an error instead of spinning',
    () async {
      final app = seeded();
      var calls = 0;

      await http.runWithClient(
        app.loadAllBookingHistory,
        () => MockClient((request) async {
          calls++;
          return http.Response('{"message":"x"}', 500);
        }),
      );

      expect(calls, lessThanOrEqualTo(3)); // GET retries อยู่ใน ApiClient เอง
      expect(app.bookingHistoryError, isNotNull);
    },
  );
}
