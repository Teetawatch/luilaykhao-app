import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:luilaykhao_app/services/location_stream_hub.dart';

Position _fix() => Position(
  latitude: 18.79,
  longitude: 98.98,
  timestamp: DateTime(2026, 9, 14, 8),
  accuracy: 5,
  altitude: 1200,
  altitudeAccuracy: 3,
  heading: 0,
  headingAccuracy: 0,
  speed: 1.2,
  speedAccuracy: 0.5,
);

/// หน้าติดตามรถ: ละเอียดปานกลาง ไม่ต้องวิ่งต่อตอนปิดหน้าจอ
const _mapNeed = LocationNeed(
  accuracy: LocationAccuracy.high,
  distanceFilterM: 10,
);

/// บันทึกเส้นทางเดินป่า: ละเอียดที่สุด และต้องวิ่งต่อเบื้องหลัง
const _trekNeed = LocationNeed(
  accuracy: LocationAccuracy.best,
  distanceFilterM: 5,
  keepAliveInBackground: true,
  notificationTitle: 'กำลังบันทึกเส้นทางของคุณ',
  notificationText: 'บันทึกต่อแม้ปิดหน้าจอ',
);

void main() {
  final hub = LocationStreamHub.instance;

  late List<LocationSettings> built;
  late List<StreamController<Position>> sources;

  setUp(() async {
    await hub.resetForTesting();
    built = [];
    sources = [];
    hub.factory = (settings) {
      built.add(settings);
      final source = StreamController<Position>.broadcast();
      sources.add(source);
      return source.stream;
    };
  });

  tearDown(() async {
    // คืนสถานะก่อนปิด source ไม่งั้นการปิดจะไปกระตุ้นการต่อใหม่ของ hub
    await hub.resetForTesting();
    for (final source in sources) {
      unawaited(source.close());
    }
    debugDefaultTargetPlatformOverride = null;
  });

  group('รวมความต้องการของทุกคนให้เหลือสตรีมเดียว', () {
    test('เอาค่าที่ละเอียดที่สุดและระยะกรองสั้นที่สุด', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await hub.attach(need: _mapNeed, onPosition: (_) {});
      await hub.attach(need: _trekNeed, onPosition: (_) {});

      expect(hub.activeSettings!.accuracy, LocationAccuracy.best);
      expect(hub.activeSettings!.distanceFilter, 5);
    });

    test('reduced ไม่ชนะ high แม้ index ใน enum จะมากกว่า', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await hub.attach(
        need: const LocationNeed(
          accuracy: LocationAccuracy.reduced,
          distanceFilterM: 50,
        ),
        onPosition: (_) {},
      );
      await hub.attach(need: _mapNeed, onPosition: (_) {});

      expect(hub.activeSettings!.accuracy, LocationAccuracy.high);
    });

    test('ความต้องการเท่าเดิม ไม่สร้างสตรีมใหม่', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await hub.attach(need: _mapNeed, onPosition: (_) {});
      await hub.attach(need: _mapNeed, onPosition: (_) {});

      expect(built, hasLength(1));
    });
  });

  group('Android: งานเบื้องหลังต้องได้ foreground service เสมอ', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    // นี่คือบั๊กที่ชั้นนี้ถูกสร้างมาแก้: geolocator แคชสตรีมไว้ในตัวมันเอง ถ้า
    // หน้าติดตามรถเปิดสตรีมค้างไว้ก่อน การกดบันทึกเส้นทางทีหลังจะได้สตรีมเดิม
    // ที่ไม่มี foreground service แล้วตายเงียบ ๆ ตอนผู้ใช้ล็อกหน้าจอ
    test('เปิดหน้าติดตามรถไว้ก่อน แล้วกดบันทึกเส้นทาง ต้องสร้างสตรีมใหม่', () async {
      await hub.attach(need: _mapNeed, onPosition: (_) {});
      expect(
        (built.single as AndroidSettings).foregroundNotificationConfig,
        isNull,
        reason: 'ดูแผนที่อยู่เฉย ๆ ไม่ควรมีแจ้งเตือนค้าง',
      );

      await hub.attach(need: _trekNeed, onPosition: (_) {});

      expect(
        built,
        hasLength(2),
        reason: 'ต้องสร้างใหม่ ไม่ใช่ใช้สตรีมเดิมที่ไม่มี foreground service',
      );
      final latest = built.last as AndroidSettings;
      expect(latest.foregroundNotificationConfig, isNotNull);
      expect(
        latest.foregroundNotificationConfig!.notificationTitle,
        _trekNeed.notificationTitle,
      );
      expect(latest.foregroundNotificationConfig!.setOngoing, isTrue);
      expect(latest.accuracy, LocationAccuracy.best);
    });

    test('ปล่อยงานเบื้องหลังแล้ว แจ้งเตือนค้างต้องหายไป', () async {
      final map = await hub.attach(need: _mapNeed, onPosition: (_) {});
      final trek = await hub.attach(need: _trekNeed, onPosition: (_) {});
      expect((built.last as AndroidSettings).foregroundNotificationConfig, isNotNull);

      await trek.cancel();

      expect((built.last as AndroidSettings).foregroundNotificationConfig, isNull);
      expect(hub.isBackgroundActive, isFalse);
      expect(map.isActive, isTrue);
    });

    test('ยกเลิกคนสุดท้ายแล้ว สตรีมต้องปิด', () async {
      final lease = await hub.attach(need: _trekNeed, onPosition: (_) {});
      await lease.cancel();

      expect(hub.leaseCount, 0);
      expect(hub.activeSettings, isNull);
      expect(hub.isBackgroundActive, isFalse);
    });

    test('ยกเลิกซ้ำไม่มีผลข้างเคียง', () async {
      final lease = await hub.attach(need: _mapNeed, onPosition: (_) {});
      await lease.cancel();
      await lease.cancel();

      expect(hub.leaseCount, 0);
      expect(lease.isActive, isFalse);
    });
  });

  group('iOS: ต้องระบุโหมดเบื้องหลังตรง ๆ ทั้งสองทาง', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    // ค่าเริ่มต้นของ AppleSettings.allowBackgroundLocationUpdates คือ true
    // ปล่อยว่างไว้เท่ากับแจก GPS เบื้องหลังให้หน้าจอที่ไม่ได้ขอ
    test('งานที่ไม่ได้ขอเบื้องหลัง ต้องถูกปิดไว้', () async {
      await hub.attach(need: _mapNeed, onPosition: (_) {});

      final settings = built.single as AppleSettings;
      expect(settings.allowBackgroundLocationUpdates, isFalse);
      expect(settings.showBackgroundLocationIndicator, isFalse);
    });

    test('งานที่ขอเบื้องหลัง ต้องเปิดพร้อมแถบสีให้ผู้ใช้เห็น', () async {
      await hub.attach(need: _trekNeed, onPosition: (_) {});

      final settings = built.single as AppleSettings;
      expect(settings.allowBackgroundLocationUpdates, isTrue);
      expect(settings.showBackgroundLocationIndicator, isTrue);
      // iOS หยุดส่งเองเมื่อคิดว่าเราอยู่นิ่ง = เส้นทางขาดทุกครั้งที่หยุดพัก
      expect(settings.pauseLocationUpdatesAutomatically, isFalse);
      expect(settings.activityType, ActivityType.fitness);
    });
  });

  group('การส่งต่อตำแหน่ง', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('ตำแหน่งเดียวถึงทุกคนที่ขอไว้', () async {
      final seenByMap = <Position>[];
      final seenByTrek = <Position>[];

      await hub.attach(need: _mapNeed, onPosition: seenByMap.add);
      await hub.attach(need: _trekNeed, onPosition: seenByTrek.add);

      sources.last.add(_fix());
      await pumpEventQueue();

      expect(seenByMap, hasLength(1));
      expect(seenByTrek, hasLength(1));
    });

    test('คนที่ยกเลิกตัวเองระหว่างถูกเรียก ไม่ทำให้คนอื่นพลาดตำแหน่ง', () async {
      late LocationLease selfCancelling;
      var hits = 0;
      final other = <Position>[];

      selfCancelling = await hub.attach(
        need: _mapNeed,
        onPosition: (_) {
          hits++;
          selfCancelling.cancel();
        },
      );
      await hub.attach(need: _mapNeed, onPosition: other.add);

      sources.last.add(_fix());
      await pumpEventQueue();

      expect(hits, 1);
      expect(other, hasLength(1));
    });

    test('error ถึงทุกคน โดยสตรีมไม่ตาย', () async {
      final errors = <Object>[];
      await hub.attach(
        need: _mapNeed,
        onPosition: (_) {},
        onError: errors.add,
      );

      sources.single.addError(StateError('GPS หาย'));
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect(hub.leaseCount, 1);
    });
  });

  group('สตรีมที่ปิดตัวเองทั้งที่ยังมีคนใช้', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('ต่อใหม่ให้ ไม่หยุดส่งเงียบ ๆ', () async {
      await hub.attach(need: _trekNeed, onPosition: (_) {});
      expect(built, hasLength(1));

      await sources.first.close();
      await pumpEventQueue();

      expect(built, hasLength(2));
      expect(
        (built.last as AndroidSettings).foregroundNotificationConfig,
        isNotNull,
        reason: 'สตรีมที่ต่อใหม่ต้องยังวิ่งเบื้องหลังได้เหมือนเดิม',
      );
    });

    test('ต่อใหม่ได้ไม่เกินเพดาน แล้วบอกให้รู้', () async {
      Object? reported;
      await hub.attach(
        need: _trekNeed,
        onPosition: (_) {},
        onError: (e) => reported = e,
      );

      // ปิดซ้ำจนเกินเพดาน — 1 ครั้งแรก + ต่อใหม่ได้อีก 3
      for (var i = 0; i < 4; i++) {
        await sources.last.close();
        await pumpEventQueue();
      }

      expect(built, hasLength(4));
      expect(reported, isNotNull, reason: 'ยอมแพ้แล้วต้องไม่เงียบ');
    });

    test('ไม่ต่อใหม่ถ้าไม่มีใครใช้แล้ว', () async {
      final lease = await hub.attach(need: _trekNeed, onPosition: (_) {});
      await lease.cancel();

      await sources.first.close();
      await pumpEventQueue();

      expect(built, hasLength(1));
    });
  });

  test('งานเบื้องหลังที่ไม่มีข้อความบอกผู้ใช้ สร้างไม่ได้', () {
    expect(
      () => LocationNeed(
        accuracy: LocationAccuracy.best,
        distanceFilterM: 5,
        keepAliveInBackground: true,
      ),
      throwsAssertionError,
    );
  });
}
