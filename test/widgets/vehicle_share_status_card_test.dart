import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/models/trip_calendar.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/services/location_stream_hub.dart';
import 'package:luilaykhao_app/services/vehicle_location_sharing.dart';
import 'package:luilaykhao_app/widgets/vehicle_share_status_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGeolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;

  /// สิ่งที่สตาฟเลือกในกล่องขอสิทธิ์
  LocationPermission answer = LocationPermission.whileInUse;
  bool serviceEnabled = true;
  int prompts = 0;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    prompts++;
    permission = answer;
    return permission;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 13.7563,
    longitude: 100.5018,
    timestamp: DateTime(2026, 10, 22, 6),
    accuracy: 5,
    altitude: 10,
    altitudeAccuracy: 3,
    heading: 90,
    headingAccuracy: 1,
    speed: 12,
    speedAccuracy: 0.5,
  );
}

/// การ์ดแชร์ตำแหน่งรถบนหน้าแรกของแท็บงานสตาฟ — สถานะต้องตรงความจริง และ
/// ปุ่มต้องพาไปแก้ที่ถูกที่ในแตะเดียว
void main() {
  final sharing = VehicleLocationSharing.instance;
  final hub = LocationStreamHub.instance;

  late _FakeGeolocator gps;
  late List<http.Request> requests;
  late List<StreamController<Position>> sources;

  setUpAll(() async {
    await initializeDateFormatting('th_TH');
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    gps = _FakeGeolocator();
    GeolocatorPlatform.instance = gps;
    requests = [];
    sources = [];
    await hub.resetForTesting();
    hub.factory = (settings) {
      final source = StreamController<Position>.broadcast();
      sources.add(source);
      return source.stream;
    };
    await sharing.abandonLocally();
    await sharing.checkAccess();
  });

  tearDown(() async {
    await sharing.abandonLocally();
    await hub.resetForTesting();
    for (final source in sources) {
      unawaited(source.close());
    }
  });

  String thaiWallClock(DateTime day, String hhmm) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')} $hhmm:00';

  Map<String, dynamic> round({
    int id = 7,
    String? mode,
    Map<String, dynamic>? sharer,
    String? startsAt,
    bool vehicle = true,
    String? departureDate,
  }) => {
    'id': id,
    'trip': {'title': 'ยอดดอยหลวง'},
    'vehicle': vehicle ? {'id': 3, 'license_plate': 'ฮก 8899'} : null,
    'share_location_mode': mode,
    'vehicle_sharer': sharer,
    'share_auto_starts_at': startsAt,
    'departure_date': departureDate,
  };

  MockClient client() => MockClient((r) async {
    requests.add(r);
    return http.Response(
      jsonEncode({'success': true, 'data': {}}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic> schedule, {
    Future<void> Function()? then,
    VoidCallback? onOpenManifest,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final app = AppProvider();
    app.api.token = 'test-token';

    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: VehicleShareStatusCard(
                  schedule: schedule,
                  onOpenManifest: onOpenManifest,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (then != null) await then();
    }, client);
  }

  /// แตะปุ่มที่ไปเริ่ม/หยุด GPS จริง — งานในบริการ (คิวของ hub, การยกเลิกสตรีม,
  /// HTTP) เดินด้วย async จริง นาฬิกาจำลองของ widget test จะไม่ flush ให้
  Future<void> tapAndWait(WidgetTester tester, Finder target) async {
    await tester.runAsync(
      () => http.runWithClient(() async {
        await tester.tap(target);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }, client),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ถึงเวลาแล้วแต่ยังไม่แชร์ — แตะครั้งเดียวเปิดแชร์ได้', (
    tester,
  ) async {
    await pump(
      tester,
      round(mode: 'pickup'),
      then: () async {
        expect(find.text('ยังไม่ได้แชร์ตำแหน่งรถ'), findsOneWidget);
        await tapAndWait(tester, find.text('เปิดแชร์'));

        expect(find.text('กำลังแชร์ตำแหน่งรถให้ลูกค้า'), findsOneWidget);
        expect(sharing.isSharingFor(7), isTrue);
      },
    );

    expect(
      requests.map((r) => r.url.path),
      contains(endsWith('/staff/schedules/7/vehicle-location')),
    );
  });

  testWidgets('สิทธิ์ถูกปิดถาวร — ปุ่มพาไปหน้าการตั้งค่าแทนการส่งพิกัด', (
    tester,
  ) async {
    gps.permission = LocationPermission.deniedForever;

    await pump(
      tester,
      round(mode: 'pickup'),
      then: () async {
        expect(find.textContaining('การตั้งค่าของเครื่อง'), findsOneWidget);
        await tapAndWait(tester, find.text('เปิดในการตั้งค่า'));
      },
    );

    expect(gps.appSettingsOpened, 1);
    expect(requests, isEmpty);
    expect(sharing.isSharing, isFalse);
  });

  testWidgets('GPS ของเครื่องปิดอยู่ — ปุ่มพาไปเปิด GPS', (tester) async {
    gps.serviceEnabled = false;

    await pump(
      tester,
      round(mode: 'pickup'),
      then: () async {
        await tapAndWait(tester, find.text('เปิด GPS'));
      },
    );

    expect(gps.locationSettingsOpened, 1);
    expect(requests, isEmpty);
  });

  testWidgets('เพื่อนสตาฟแชร์อยู่ — บอกชื่อ และให้เครื่องนี้แชร์แทนได้', (
    tester,
  ) async {
    await pump(
      tester,
      round(sharer: {'id': 9, 'name': 'พี่ดี'}),
      then: () async {
        expect(find.text('พี่ดี กำลังแชร์ตำแหน่งรถอยู่'), findsOneWidget);
        expect(find.text('ยังไม่ได้แชร์ตำแหน่งรถ'), findsNothing);

        await tapAndWait(tester, find.text('ให้เครื่องนี้แชร์แทน'));
        expect(find.text('กำลังแชร์ตำแหน่งรถให้ลูกค้า'), findsOneWidget);
      },
    );

    final post = requests.firstWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body)['takeover'], isTrue);
  });

  testWidgets('กำลังแชร์อยู่ — แตะการ์ดเพื่อไปจัดการในหน้ารายชื่อ', (
    tester,
  ) async {
    var opened = 0;
    await pump(
      tester,
      round(mode: 'pickup'),
      onOpenManifest: () => opened++,
      then: () async {
        await tapAndWait(tester, find.text('เปิดแชร์'));
        await tester.tap(find.text('กำลังแชร์ตำแหน่งรถให้ลูกค้า'));
        await tester.pumpAndSettle();
      },
    );

    expect(opened, 1);
  });

  testWidgets('พรุ่งนี้มีรอบ สิทธิ์พร้อมแล้ว — บอกเวลาที่จะเริ่มเอง', (
    tester,
  ) async {
    final tomorrow = bangkokToday().add(const Duration(days: 1));
    await pump(tester, round(startsAt: thaiWallClock(tomorrow, '04:30')));

    expect(find.text('พร้อมแชร์ตำแหน่งรถแล้ว'), findsOneWidget);
    expect(find.textContaining('พรุ่งนี้ 04:30 น.'), findsOneWidget);
  });

  testWidgets('รอบที่ไม่ได้กรอกเวลารถออก — ไม่พิมพ์เวลาที่เดาเอา', (
    tester,
  ) async {
    await pump(tester, round());

    expect(find.textContaining('ก่อนรถออก'), findsOneWidget);
    expect(find.textContaining('น.'), findsNothing);
  });

  testWidgets(
    'ยังไม่อนุญาตตำแหน่ง — ขอไว้ก่อนวันเดินทาง แล้วการ์ดเปลี่ยนเป็นพร้อม',
    (tester) async {
      gps.permission = LocationPermission.denied;

      await pump(
        tester,
        round(),
        then: () async {
          expect(find.text('อนุญาตตำแหน่งไว้ก่อนวันเดินทาง'), findsOneWidget);
          await tapAndWait(tester, find.text('อนุญาตตำแหน่ง'));
          expect(find.text('พร้อมแชร์ตำแหน่งรถแล้ว'), findsOneWidget);
        },
      );

      expect(gps.prompts, 1);
      expect(requests, isEmpty, reason: 'ยังไม่ถึงเวลา — ห้ามเริ่มส่งพิกัด');
      expect(sharing.isSharing, isFalse);
    },
  );

  testWidgets('กลับมาจากหน้าการตั้งค่า — การ์ดเช็คสิทธิ์ใหม่เอง', (
    tester,
  ) async {
    gps.permission = LocationPermission.deniedForever;

    await pump(
      tester,
      round(),
      then: () async {
        expect(find.text('เปิดในการตั้งค่า'), findsOneWidget);

        gps.permission = LocationPermission.whileInUse;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(find.text('พร้อมแชร์ตำแหน่งรถแล้ว'), findsOneWidget);
      },
    );
  });

  group('pickRound', () {
    final today = DateTime(2026, 10, 22);

    Map<String, dynamic> r(
      int id, {
      String? mode,
      Object? sharer,
      String? date,
      bool vehicle = true,
    }) => {
      'id': id,
      'vehicle': vehicle ? {'id': id} : null,
      'share_location_mode': mode,
      'vehicle_sharer': sharer,
      'departure_date': date,
    };

    int? pick(
      List<Map<String, dynamic>> active,
      List<Map<String, dynamic>> upcoming, {
      int? sharingId,
    }) {
      final picked = VehicleShareStatusCard.pickRound(
        active,
        upcoming,
        isSharingFor: (id) => id == sharingId,
        today: today,
      );
      return picked == null ? null : picked['id'] as int;
    }

    test('the round this phone is sending for wins', () {
      expect(pick([r(1, mode: 'pickup'), r(2)], [], sharingId: 2), 2);
    });

    test('then the round the server says is due', () {
      expect(pick([r(1), r(2, mode: 'pickup')], []), 2);
    });

    test('then a round a friend is sharing', () {
      expect(
        pick([
          r(1),
          r(2, sharer: {'id': 9}),
        ], []),
        2,
      );
    });

    test('then today, then only tomorrow — never a trip next week', () {
      expect(pick([r(1)], [r(2, date: '2026-10-23')]), 1);
      expect(pick([], [r(2, date: '2026-10-23')]), 2);
      expect(pick([], [r(3, date: '2026-10-28')]), isNull);
    });

    test('a round without a van has nothing to share', () {
      expect(pick([r(1, vehicle: false, mode: 'pickup')], []), isNull);
    });
  });
}
