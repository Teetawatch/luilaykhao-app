import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/profile_screen.dart';
import 'package:luilaykhao_app/screens/staff_reviews_screen.dart';
import 'package:provider/provider.dart';

/// "คะแนนเฉลี่ย" ในแท็บงานสตาฟ — เดิมเห็นแค่ตัวเลข ตอนนี้แตะแล้วอ่านรีวิว
/// พร้อมคอมเมนต์ได้
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  http.Response page(
    List<Map<String, dynamic>> data, {
    int current = 1,
    int last = 1,
  }) => http.Response(
    jsonEncode({
      'success': true,
      'data': data,
      'message': 'สำเร็จ',
      'meta': {
        'current_page': current,
        'last_page': last,
        'per_page': 20,
        'total': 3,
        'summary': {
          'total_reviews': 3,
          'avg_rating': 4.33,
          'breakdown': {'5': 2, '4': 0, '3': 0, '2': 1, '1': 0},
        },
      },
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, dynamic> review(int id, int rating, String? comment) => {
    'id': id,
    'rating': rating,
    'comment': comment,
    'reviewer_name': 'สมศรี $id',
    'trip_title': 'ภูชี้ฟ้า',
    'departure_date': '2026-10-01',
    'created_at': '2026-10-03T02:00:00.000000Z',
  };

  Future<List<http.Request>> pump(
    WidgetTester tester,
    Widget home,
    Future<http.Response> Function(http.Request) handler, {
    Future<void> Function()? then,
    void Function(AppProvider app)? setup,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final requests = <http.Request>[];
    final app = AppProvider();
    app.api.token = 'test-token';
    setup?.call(app);

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: app,
            child: MaterialApp(home: home),
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

  testWidgets('shows the summary and every review with its comment', (
    tester,
  ) async {
    final requests = await pump(
      tester,
      const StaffReviewsScreen(),
      (_) async => page([
        review(1, 5, 'พี่ดูแลดีมาก ใส่ใจทุกคน'),
        review(2, 2, 'รอรถนาน'),
        review(3, 5, null),
      ]),
    );

    expect(requests.single.url.path, endsWith('/staff/reviews/my'));
    expect(find.text('4.3'), findsOneWidget);
    expect(find.text('3 รีวิว'), findsOneWidget);
    expect(find.text('พี่ดูแลดีมาก ใส่ใจทุกคน'), findsOneWidget);
    expect(find.text('รอรถนาน'), findsOneWidget);
    expect(
      find.text('ให้คะแนนอย่างเดียว ไม่ได้เขียนความคิดเห็น'),
      findsOneWidget,
    );
    expect(find.textContaining('สมศรี 1 · ภูชี้ฟ้า'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state when nobody has reviewed yet', (tester) async {
    await pump(
      tester,
      const StaffReviewsScreen(),
      (_) async => http.Response(
        jsonEncode({
          'success': true,
          'data': [],
          'meta': {
            'current_page': 1,
            'last_page': 1,
            'total': 0,
            'summary': {'total_reviews': 0, 'avg_rating': null},
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    expect(find.text('ยังไม่มีรีวิว'), findsOneWidget);
  });

  testWidgets('loads the next page when scrolled to the end', (tester) async {
    final requests = await pump(
      tester,
      const StaffReviewsScreen(),
      (r) async {
        final p = r.url.queryParameters['page'];
        return p == '2'
            ? page([review(99, 4, 'หน้าสอง')], current: 2, last: 2)
            : page([
                for (var i = 1; i <= 20; i++) review(i, 5, 'รีวิว $i'),
              ], last: 2);
      },
      then: () async {
        await tester.scrollUntilVisible(
          find.text('หน้าสอง'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      },
    );

    expect(requests.map((r) => r.url.queryParameters['page']).toList(), [
      '1',
      '2',
    ]);
    expect(find.text('หน้าสอง'), findsOneWidget);
  });

  testWidgets('tapping คะแนนเฉลี่ย on the staff tab opens the reviews', (
    tester,
  ) async {
    await pump(
      tester,
      const StaffWorkScreen(),
      (r) async => r.url.path.endsWith('/staff/reviews/my')
          ? page([review(1, 5, 'พี่ดูแลดีมาก')])
          : http.Response('{"success":true,"data":{}}', 200),
      setup: (app) {
        app.staffSummary = {'total_reviews': 3, 'avg_rating': 4.33};
      },
      then: () async {
        await tester.tap(find.text('คะแนนเฉลี่ย'));
        await tester.pumpAndSettle();
      },
    );

    expect(find.text('รีวิวจากลูกค้า'), findsOneWidget);
    expect(find.text('พี่ดูแลดีมาก'), findsOneWidget);
  });
}
