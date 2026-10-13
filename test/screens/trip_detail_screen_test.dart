import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/providers/trip_alert_provider.dart';
import 'package:luilaykhao_app/providers/wishlist_provider.dart';
import 'package:luilaykhao_app/screens/trip_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApp extends AppProvider {
  bool tripFails = false;
  int scheduleCalls = 0;
  Map<String, dynamic> tripData = {};
  List<dynamic> scheduleData = [];
  List<dynamic> reviewData = [];
  Map<String, dynamic> reviewStatsData = {};

  // Round-trip through JSON so the data has the same runtime types the API
  // gives (List<dynamic>, Map<String, dynamic>), not narrower literal types.
  static T _json<T>(Object data) => jsonDecode(jsonEncode(data)) as T;

  @override
  Future<Map<String, dynamic>> trip(String slug) async {
    if (tripFails) throw Exception('offline');
    return _json(tripData);
  }

  @override
  Future<List<dynamic>> schedules(String slug) async {
    scheduleCalls++;
    return _json(scheduleData);
  }

  @override
  Future<List<dynamic>> tripReviews(int tripId) async => _json(reviewData);

  @override
  Future<Map<String, dynamic>> reviewStats({int? tripId}) async =>
      _json(reviewStatsData);

  @override
  Future<void> ensurePickupVehicleClasses({bool force = false}) async {}

  @override
  void recordRecentTrip(Map<String, dynamic> trip) {}
}

Map<String, dynamic> _schedule({int id = 11, int seats = 8, String? opensAt}) {
  final date = DateTime.now().add(const Duration(days: 20));
  final day =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  return {
    'id': id,
    'departure_date': day,
    'return_date': day,
    'available_seats': seats,
    'bookable_seats': seats,
    'price': 3200,
    'effective_price': 3200,
    'transport_type': 'van',
    'status': 'open',
    'booking_opens_at': opensAt,
    'pickup_points': [
      {
        'id': 1,
        'region': 'bangkok',
        'region_label': 'กรุงเทพฯ',
        'pickup_location': 'BTS หมอชิต',
      },
    ],
  };
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
    // ฟอนต์จริงของแอป — ฟอนต์ทดสอบวาดอักษรไทยกว้างเกินจริง
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

  late _FakeApp app;
  final navigatorKey = GlobalKey<NavigatorState>();

  setUp(() {
    app = _FakeApp()
      ..tripData = {
        'id': 7,
        'slug': 'phu-kradueng',
        'title': 'ภูกระดึง 3 วัน 2 คืน',
        'price_per_person': 3200,
        'rating': 4.6,
        'review_count': 50,
      }
      ..scheduleData = [_schedule()];
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: app),
            ChangeNotifierProvider(create: (_) => WishlistProvider()),
            ChangeNotifierProvider(create: (_) => TripAlertProvider()),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const TripDetailScreen(slug: 'phu-kradueng'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }, () => MockClient((_) async => http.Response('{"data":[]}', 200)));
  }

  /// The page polls on a 25s Timer forever; take it down with the tree so the
  /// test doesn't end with a pending timer.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  testWidgets(
    'a failed trip load stays on the retry screen even after the seat poll succeeds',
    (tester) async {
      app.tripFails = true;
      await pump(tester);
      expect(find.text('โหลดข้อมูลไม่สำเร็จ'), findsOneWidget);

      // Before the fix the 25s poll filled in schedules and swapped the error
      // for an empty trip page with a live "จองเลย".
      await tester.pump(const Duration(seconds: 26));
      await tester.pump();
      expect(find.text('โหลดข้อมูลไม่สำเร็จ'), findsOneWidget);
      expect(find.text('จองเลย'), findsNothing);
      expect(app.scheduleCalls, 0);

      await unmount(tester);
    },
  );

  testWidgets('a round that has not opened yet cannot be booked', (
    tester,
  ) async {
    final opens = DateTime.now().add(const Duration(days: 2));
    app.scheduleData = [_schedule(opensAt: opens.toUtc().toIso8601String())];
    await pump(tester);

    final bar = find.byType(StickyBookingBar);
    expect(
      find.descendant(of: bar, matching: find.text('เปิดจอง')),
      findsOneWidget,
    );
    // …with the opening time under it ("20 ต.ค. 10:00").
    expect(
      find.descendant(of: bar, matching: find.textContaining(':')),
      findsOneWidget,
    );
    expect(find.text('จองเลย'), findsNothing);
    // The date chip says when it opens instead of how many seats are free.
    expect(find.textContaining('เปิด '), findsWidgets);

    await tester.tap(find.descendant(of: bar, matching: find.text('เปิดจอง')));
    await tester.pump();
    // No booking flow / login pushed.
    expect(find.byType(StickyBookingBar), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsNothing);

    await unmount(tester);
  });

  testWidgets('an open round keeps the normal booking button', (tester) async {
    app.scheduleData = [
      _schedule(
        opensAt: DateTime.now()
            .subtract(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      ),
    ];
    await pump(tester);

    expect(find.text('จองเลย'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StickyBookingBar),
        matching: find.text('เปิดจอง'),
      ),
      findsNothing,
    );

    await unmount(tester);
  });

  testWidgets('the star bars count every review, not just the first page', (
    tester,
  ) async {
    app.reviewData = [
      for (var i = 1; i <= 3; i++)
        {
          'id': i,
          'user_id': i,
          'rating': 5,
          'comment': 'ดีมาก $i',
          'images': const [],
          'videos': const [],
          'user': {'name': 'คนที่ $i'},
        },
    ];
    app.reviewStatsData = {
      'distribution': {'5': 31, '4': 17, '3': 2, '2': 0, '1': 0},
    };
    await pump(tester);

    await tester.scrollUntilVisible(
      find.text('50 รีวิว').last,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // The old bars counted only the 3 loaded reviews (5★ = 3, the rest 0).
    expect(find.text('31'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the last section ends just above the floating booking bar', (
    tester,
  ) async {
    await pump(tester);
    final scroll = find.byType(Scrollable).first;
    for (var i = 0; i < 30; i++) {
      await tester.drag(scroll, const Offset(0, -800));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 1));

    final lastBottom = tester.getRect(find.byType(ReviewSection)).bottom;
    final barTop = tester.getRect(find.byType(StickyBookingBar)).top;
    // Never hidden under the bar, and no empty band the height of a second
    // bar (the old padding added the bar's height on top of the Scaffold's).
    expect(lastBottom, lessThanOrEqualTo(barTop));
    expect(barTop - lastBottom, lessThan(64));

    // At the very bottom the reviews tab is the active one, even though the
    // reviews group is too short to scroll up under the tab bar.
    final handle = tester.ensureSemantics();
    final reviewsTab = find.descendant(
      of: find.byType(TripSectionTabs),
      matching: find.text('รีวิว'),
    );
    expect(tester.getSemantics(reviewsTab), isSemantics(isSelected: true));
    handle.dispose();

    await unmount(tester);
  });

  testWidgets('switching pickup region does not rebuild the sections below', (
    tester,
  ) async {
    // The itinerary only exists for the north, so picking the north inserts a
    // section above the video gallery. Before sections were keyed, the gallery
    // was handed a fresh State: its video previews reloaded and it faded in
    // again from blank.
    app.tripData = {
      ...app.tripData,
      'itinerary': [
        {'title': 'ขึ้นรถที่เชียงใหม่', 'region': 'north'},
      ],
      'videos': ['https://example.test/trip.mp4'],
    };
    final schedule = _schedule();
    schedule['pickup_points'] = [
      {
        'id': 1,
        'region': 'bangkok',
        'region_label': 'กรุงเทพฯ',
        'pickup_location': 'หมอชิต',
      },
      {
        'id': 2,
        'region': 'north',
        'region_label': 'ภาคเหนือ',
        'pickup_location': 'เชียงใหม่',
      },
    ];
    app.scheduleData = [schedule];
    await pump(tester);

    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byType(VideoGallerySection),
      300,
      scrollable: scroll,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    final before = tester.element(find.byType(VideoGallerySection));
    expect(find.byType(ItinerarySection), findsNothing);

    await tester.scrollUntilVisible(
      find.text('ภาคเหนือ').first,
      -300,
      scrollable: scroll,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.text('ภาคเหนือ').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(ItinerarySection), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(VideoGallerySection),
      300,
      scrollable: scroll,
    );
    expect(
      identical(tester.element(find.byType(VideoGallerySection)), before),
      isTrue,
    );

    await unmount(tester);
  });

  testWidgets('a seat refresh keeps the pickup the customer chose', (
    tester,
  ) async {
    final schedule = _schedule();
    schedule['pickup_points'] = [
      {
        'id': 1,
        'region': 'bangkok',
        'region_label': 'กรุงเทพฯ',
        'pickup_location': 'หมอชิต',
      },
      {
        'id': 2,
        'region': 'north',
        'region_label': 'ภาคเหนือ',
        'pickup_location': 'เชียงใหม่',
      },
    ];
    app.scheduleData = [schedule];

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: app),
            ChangeNotifierProvider(create: (_) => WishlistProvider()),
            ChangeNotifierProvider(create: (_) => TripAlertProvider()),
          ],
          child: const MaterialApp(
            home: TripDetailScreen(
              slug: 'phu-kradueng',
              initialPickupRegionKey: 'north',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }, () => MockClient((_) async => http.Response('{"data":[]}', 200)));

    final bar = find.byType(StickyBookingBar);
    expect(
      find.descendant(of: bar, matching: find.text('ราคาสำหรับ ภาคเหนือ')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('กรุงเทพฯ').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.text('กรุงเทพฯ').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(
      find.descendant(of: bar, matching: find.text('ราคาสำหรับ กรุงเทพฯ')),
      findsOneWidget,
    );

    // Seats move, the poll brings a new list.
    final refreshed = _schedule(seats: 5);
    refreshed['pickup_points'] = schedule['pickup_points'];
    app.scheduleData = [refreshed];
    await tester.pump(const Duration(seconds: 26));
    await tester.pump();

    expect(
      find.descendant(of: bar, matching: find.text('ราคาสำหรับ กรุงเทพฯ')),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('tapping the rating under the title jumps to the reviews', (
    tester,
  ) async {
    await pump(tester);

    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('ดูรีวิวทั้ง 50 รายการ'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final reviewsTab = find.descendant(
      of: find.byType(TripSectionTabs),
      matching: find.text('รีวิว'),
    );
    expect(tester.getSemantics(reviewsTab), isSemantics(isSelected: true));
    expect(find.byType(ReviewSection).hitTestable(), findsOneWidget);
    handle.dispose();

    await unmount(tester);
  });

  testWidgets('the seat poll pauses while another page covers the trip', (
    tester,
  ) async {
    await pump(tester);
    final before = app.scheduleCalls;

    navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('จอง'))),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 60));
    expect(app.scheduleCalls, before);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 26));
    expect(app.scheduleCalls, before + 1);

    await unmount(tester);
  });
}
