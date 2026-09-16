import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luilaykhao_app/config/api_config.dart';
import 'package:luilaykhao_app/services/api_client.dart';
import 'package:luilaykhao_app/services/location_stream_hub.dart';
import 'package:luilaykhao_app/services/trip_live_location_service.dart';

Position _fix({double lat = 18.79}) => Position(
  latitude: lat,
  longitude: 98.98,
  timestamp: DateTime(2026, 9, 14, 8),
  accuracy: 5,
  altitude: 1200,
  altitudeAccuracy: 3,
  heading: 12,
  headingAccuracy: 1,
  speed: 1.2,
  speedAccuracy: 0.5,
);

/// GPS ปลอม — จริงพอที่จะเดินผ่านด่านสิทธิ์กับตำแหน่งแรก โดยไม่ต้องมีเครื่อง
class _FakeGeolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  bool serviceEnabled = true;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async =>
      _fix();
}

/// คำขอหนึ่งครั้งที่แอปยิงออกไป
class _Call {
  final String method;
  final String path;
  const _Call(this.method, this.path);

  @override
  bool operator ==(Object other) =>
      other is _Call && other.method == method && other.path == path;

  @override
  int get hashCode => Object.hash(method, path);

  @override
  String toString() => '$method $path';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sharing = TripLocationSharing.instance;
  final hub = LocationStreamHub.instance;

  late _FakeGeolocator gps;
  late List<_Call> calls;
  late List<StreamController<Position>> sources;

  /// ตัวตอบ API — เปลี่ยนได้รายเทสต์
  late Future<http.Response> Function(http.Request) respond;

  http.Response okBody([String data = '{"members":[]}']) =>
      http.Response('{"success":true,"data":$data}', 200);

  http.Response refused(int status, String message) => http.Response(
    // Laravel escape ไทยเป็น \uXXXX บนสาย — เลียนแบบให้ตรงของจริง
    '{"message":"${message.runes.map((r) => '\\u${r.toRadixString(16).padLeft(4, '0')}').join()}"}',
    status,
  );

  Future<T> withApi<T>(Future<T> Function(ApiClient api) body) {
    return http.runWithClient(() {
      final api = ApiClient()..token = 'test-token';
      return body(api);
    }, () => MockClient((request) {
      // ตัด prefix ของ base URL ออก ให้เทสต์พูดถึงเส้นทางของ API ล้วน ๆ
      final basePath = Uri.parse(ApiConfig.baseUrl).path;
      calls.add(
        _Call(request.method, request.url.path.substring(basePath.length)),
      );
      return respond(request);
    }));
  }

  setUp(() async {
    gps = _FakeGeolocator();
    GeolocatorPlatform.instance = gps;
    calls = [];
    sources = [];
    respond = (_) async => okBody();

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

  group('เปิดแชร์', () {
    test('ขอสตรีมแบบวิ่งต่อเบื้องหลัง ไม่ใช่แบบธรรมดา', () async {
      await withApi((api) => sharing.start(api: api, scheduleId: 7));

      expect(sharing.isSharing, isTrue);
      expect(sharing.isSharingFor(7), isTrue);
      expect(
        hub.isBackgroundActive,
        isTrue,
        reason: 'แชร์ตำแหน่งที่หยุดตอนล็อกหน้าจอ ไม่ใช่การแชร์',
      );
      final settings = hub.activeSettings! as AndroidSettings;
      expect(settings.foregroundNotificationConfig, isNotNull);
    });

    test('ยิงตำแหน่งแรกทันที ไม่รอให้ขยับก่อน', () async {
      await withApi((api) => sharing.start(api: api, scheduleId: 7));

      expect(calls, [const _Call('POST', '/schedules/7/live-location')]);
    });

    test('ไม่มีสิทธิ์ GPS = ไม่เปิด และไม่ยึดสตรีมไว้', () async {
      gps.permission = LocationPermission.deniedForever;

      final ok = await withApi((api) => sharing.start(api: api, scheduleId: 7));

      expect(ok, isFalse);
      expect(sharing.isSharing, isFalse);
      expect(hub.leaseCount, 0);
      expect(sharing.error, contains('อนุญาต'));
      expect(calls, isEmpty);
    });

    test('เซิร์ฟเวอร์ปฏิเสธ = ไม่เปิด GPS ทิ้งไว้เฉย ๆ', () async {
      respond = (_) async => refused(422, 'แชร์ตำแหน่งได้เฉพาะช่วงเวลาทริปเท่านั้น');

      final ok = await withApi((api) => sharing.start(api: api, scheduleId: 7));

      expect(ok, isFalse);
      expect(sharing.isSharing, isFalse);
      expect(hub.leaseCount, 0, reason: 'สตรีมที่ไม่มีใครรับปลายทางคือแบตที่หายไปเปล่า');
      expect(sharing.error, contains('ช่วงเวลาทริป'));
    });

    test('เน็ตไม่มาตอนกดเปิด = เปิดไว้ก่อน แล้วค่อยส่งรอบหน้า', () async {
      respond = (_) => Future<http.Response>.error(const SocketException('Failed host lookup'));

      final ok = await withApi((api) => sharing.start(api: api, scheduleId: 7));

      expect(ok, isTrue, reason: 'บนดอยเน็ตหลุดตอนกดเปิดเป็นเรื่องปกติ');
      expect(sharing.isSharing, isTrue);
      expect(hub.isBackgroundActive, isTrue);
    });

    test('ย้ายรอบ ปิดของเดิมให้เรียบร้อยก่อน', () async {
      await withApi((api) async {
        await sharing.start(api: api, scheduleId: 7);
        calls.clear();
        await sharing.start(api: api, scheduleId: 9);
      });

      expect(sharing.isSharingFor(9), isTrue);
      expect(sharing.isSharingFor(7), isFalse);
      expect(
        calls.first,
        const _Call('DELETE', '/schedules/7/live-location'),
        reason: 'ไม่งั้นเพื่อนในรอบเดิมเห็นหมุดเราค้างอยู่ทั้งที่ไปทริปอื่นแล้ว',
      );
      expect(hub.leaseCount, 1, reason: 'ต้องเหลือสตรีมเดียว ไม่ใช่ค้างสองเส้น');
    });
  });

  group('ปิดแชร์', () {
    test('หยุดส่งและลบหมุดบนเซิร์ฟเวอร์', () async {
      await withApi((api) async {
        await sharing.start(api: api, scheduleId: 7);
        calls.clear();
        await sharing.stop();
      });

      expect(sharing.isSharing, isFalse);
      expect(hub.leaseCount, 0);
      expect(calls, [const _Call('DELETE', '/schedules/7/live-location')]);
    });

    test('ลบไม่สำเร็จ ก็ยังต้องหยุดส่งจริง', () async {
      await withApi((api) async {
        await sharing.start(api: api, scheduleId: 7);
        respond = (_) async => refused(500, 'เซิร์ฟเวอร์ขัดข้อง');
        await sharing.stop();
      });

      expect(sharing.isSharing, isFalse);
      expect(hub.leaseCount, 0);
      expect(sharing.error, isNotNull);
    });

    test('ออกจากระบบ ไม่ยิง API แต่ต้องปล่อย GPS', () async {
      await withApi((api) async {
        await sharing.start(api: api, scheduleId: 7);
        calls.clear();
        await sharing.abandonLocally();
      });

      expect(sharing.isSharing, isFalse);
      expect(hub.leaseCount, 0);
      expect(calls, isEmpty);
    });
  });

  group('ระหว่างแชร์', () {
    test('ตำแหน่งใหม่ถูกส่งขึ้นไป', () async {
      await withApi((api) async {
        await sharing.start(api: api, scheduleId: 7);
        calls.clear();
        sharing.debugClearUploadThrottle();

        sources.last.add(_fix(lat: 18.80));
        await pumpEventQueue();
      });

      expect(calls, [const _Call('POST', '/schedules/7/live-location')]);
      expect(sharing.myPosition!.latitude, 18.80);
    });

    test('หมดช่วงเวลาทริปแล้ว ต้องเลิกเปิด GPS ทิ้งไว้', () async {
      await withApi((api) async {
        await sharing.start(api: api, scheduleId: 7);
        sharing.debugClearUploadThrottle();
        respond = (_) async =>
            refused(422, 'แชร์ตำแหน่งได้เฉพาะช่วงเวลาทริปเท่านั้น');

        sources.last.add(_fix(lat: 18.81));
        await pumpEventQueue();
      });

      expect(sharing.isSharing, isFalse);
      expect(
        hub.leaseCount,
        0,
        reason: 'ถ้าไม่หยุด สตรีมจะวิ่งกินแบตต่อไปโดยไม่มีใครรับปลายทาง',
      );
      expect(sharing.error, contains('ช่วงเวลาทริป'));
    });

    test('เน็ตหลุดชั่วคราว ไม่ทำให้เลิกแชร์', () async {
      await withApi((api) async {
        await sharing.start(api: api, scheduleId: 7);
        sharing.debugClearUploadThrottle();
        respond = (_) => Future<http.Response>.error(const SocketException('Failed host lookup'));

        sources.last.add(_fix(lat: 18.82));
        await pumpEventQueue();
      });

      expect(sharing.isSharing, isTrue, reason: 'อับสัญญาณเป็นเรื่องปกติบนดอย');
      expect(hub.isBackgroundActive, isTrue);
    });
  });

  group('อายุของการแชร์เทียบกับหน้าจอ', () {
    // บั๊กเดิม: TripLiveLocationController ถูกสร้างใน State ของหน้าแผนที่ พอกด
    // ย้อนกลับ dispose() ก็ตัดสตรีมทิ้ง ทั้งที่ผู้ใช้ไม่ได้สั่งปิดแชร์ — คนที่
    // กดเปิดแล้วเก็บเครื่องเดินต่อ (ซึ่งคือวิธีใช้ปกติ) จะกลายเป็นหมุดค้าง
    test('ปิดหน้าจอแผนที่แล้ว การแชร์ยังเดินต่อ', () async {
      await withApi((api) async {
        await sharing.start(api: api, scheduleId: 7);

        final screen = TripLiveLocationController(api: api, scheduleId: 7);
        expect(screen.sharing, isTrue);
        expect(screen.myPosition, isNotNull);

        calls.clear();
        screen.dispose();
      });

      expect(sharing.isSharing, isTrue);
      expect(hub.leaseCount, 1);
      expect(hub.isBackgroundActive, isTrue);
      expect(calls, isEmpty, reason: 'กดย้อนกลับไม่ใช่การสั่งเลิกแชร์');
    });

    test('หน้าจอของรอบอื่น ไม่แสดงว่ากำลังแชร์', () async {
      await withApi((api) async {
        await sharing.start(api: api, scheduleId: 7);

        final other = TripLiveLocationController(api: api, scheduleId: 9);
        expect(other.sharing, isFalse);
        expect(other.myPosition, isNull);
        other.dispose();
      });
    });
  });
}

