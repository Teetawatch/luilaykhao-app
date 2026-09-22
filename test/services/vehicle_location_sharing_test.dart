import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luilaykhao_app/config/api_config.dart';
import 'package:luilaykhao_app/services/api_client.dart';
import 'package:luilaykhao_app/services/location_stream_hub.dart';
import 'package:luilaykhao_app/services/vehicle_location_sharing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position _fix() => Position(
  latitude: 13.7563,
  longitude: 100.5018,
  timestamp: DateTime(2026, 9, 22, 6),
  accuracy: 5,
  altitude: 10,
  altitudeAccuracy: 3,
  heading: 90,
  headingAccuracy: 1,
  speed: 12,
  speedAccuracy: 0.5,
);

class _FakeGeolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  bool serviceEnabled = true;
  int prompts = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    prompts++;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async =>
      _fix();
}

/// มือถือของสตาฟคือ GPS ของรถ และต้องเป็นเองโดยไม่เพิ่มงานให้สตาฟ —
/// เขากำลังเช็คอินลูกค้าอยู่ตอนรถออกพอดี
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sharing = VehicleLocationSharing.instance;
  final hub = LocationStreamHub.instance;

  late _FakeGeolocator gps;
  late List<String> calls;
  late List<StreamController<Position>> sources;

  Future<T> withApi<T>(Future<T> Function(ApiClient api) body) {
    return http.runWithClient(() {
      final api = ApiClient()..token = 'test-token';
      return body(api);
    }, () => MockClient((request) async {
      final basePath = Uri.parse(ApiConfig.baseUrl).path;
      calls.add('${request.method} ${request.url.path.substring(basePath.length)}');
      return http.Response('{"success":true,"data":{}}', 200);
    }));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    gps = _FakeGeolocator();
    GeolocatorPlatform.instance = gps;
    calls = [];
    sources = [];

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await hub.resetForTesting();
    hub.factory = (settings) {
      final source = StreamController<Position>.broadcast();
      sources.add(source);
      return source.stream;
    };
    await sharing.abandonLocally();
  });

  tearDown(() async {
    await sharing.abandonLocally();
    await hub.resetForTesting();
    for (final source in sources) {
      unawaited(source.close());
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('a round that is due starts sharing on its own', () async {
    await withApi((api) => sharing.syncAuto(api: api, dueScheduleId: 7));

    expect(sharing.isSharingFor(7), isTrue);
    expect(calls, contains('POST /staff/schedules/7/vehicle-location'));
  });

  test('it never opens a permission dialog by itself', () async {
    gps.permission = LocationPermission.denied;

    await withApi((api) => sharing.syncAuto(api: api, dueScheduleId: 7));

    expect(gps.prompts, 0, reason: 'สตาฟกำลังทำงานอยู่ ห้ามเด้งกล่องขึ้นมาเอง');
    expect(sharing.isSharing, isFalse);
    expect(sharing.needsPermission, isTrue);
  });

  test('tapping the card is allowed to ask for permission', () async {
    gps.permission = LocationPermission.denied;

    await withApi(
      (api) => sharing.startManually(api: api, scheduleId: 7),
    );

    expect(gps.prompts, 1);
  });

  test('turning it off keeps it off for that round', () async {
    await withApi((api) => sharing.syncAuto(api: api, dueScheduleId: 7));
    await sharing.stop(remember: true);

    await withApi((api) => sharing.syncAuto(api: api, dueScheduleId: 7));

    expect(sharing.isSharing, isFalse, reason: 'ปิดแล้วต้องปิดจริง');
  });

  test('turning it back on by hand clears that memory', () async {
    await sharing.stop(remember: false);
    await withApi((api) => sharing.syncAuto(api: api, dueScheduleId: 7));
    await sharing.stop(remember: true);

    await withApi((api) => sharing.startManually(api: api, scheduleId: 7));
    expect(sharing.isSharingFor(7), isTrue);

    await sharing.stop();
    await withApi((api) => sharing.syncAuto(api: api, dueScheduleId: 7));
    expect(sharing.isSharingFor(7), isTrue, reason: 'ไม่ได้สั่งปิดถาวรไว้แล้ว');
  });

  test('it stops itself once no round is travelling', () async {
    await withApi((api) => sharing.syncAuto(api: api, dueScheduleId: 7));
    expect(sharing.isSharing, isTrue);

    await withApi((api) => sharing.syncAuto(api: api, dueScheduleId: null));

    expect(sharing.isSharing, isFalse, reason: 'รอบจบแล้วต้องเลิกกินแบตเอง');
  });

  test('a second sync on the same round does not restart it', () async {
    await withApi((api) => sharing.syncAuto(api: api, dueScheduleId: 7));
    final before = calls.length;

    await withApi((api) => sharing.syncAuto(api: api, dueScheduleId: 7));

    expect(calls.length, before);
  });
}
