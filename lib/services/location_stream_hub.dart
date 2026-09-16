import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// สร้างสตรีมตำแหน่งจริง — แยกเป็น typedef เพื่อให้เทสต์ป้อนสตรีมปลอมเข้ามาแทน
/// ได้ โดยไม่ต้องมี platform channel
typedef PositionStreamFactory =
    Stream<Position> Function(LocationSettings settings);

/// สิ่งที่ผู้ใช้งาน GPS หนึ่งรายต้องการ
@immutable
class LocationNeed {
  /// ความละเอียดที่ต้องการ
  final LocationAccuracy accuracy;

  /// ขยับน้อยกว่านี้ไม่ต้องแจ้ง (เมตร)
  final int distanceFilterM;

  /// ต้องได้ตำแหน่งต่อแม้ผู้ใช้ปิดหน้าจอหรือสลับไปแอปอื่นหรือไม่
  ///
  /// เปิดเมื่อจำเป็นเท่านั้น: มันแลกมาด้วยแบต และด้วยแถบแจ้งเตือนค้างบน
  /// Android กับแถบสีบน iOS ที่ผู้ใช้ต้องเห็นว่ากำลังเกิดอะไรขึ้น
  final bool keepAliveInBackground;

  /// ข้อความบนแจ้งเตือนค้างของ Android — ใช้เมื่อ [keepAliveInBackground]
  final String notificationTitle;
  final String notificationText;

  const LocationNeed({
    required this.accuracy,
    required this.distanceFilterM,
    this.keepAliveInBackground = false,
    this.notificationTitle = '',
    this.notificationText = '',
  }) : assert(
         !keepAliveInBackground ||
             (notificationTitle != '' && notificationText != ''),
         'งานที่วิ่งเบื้องหลังต้องมีข้อความบอกผู้ใช้เสมอว่ากำลังทำอะไรอยู่',
       );
}

/// สิทธิ์การใช้ GPS หนึ่งใบที่ [LocationStreamHub] ออกให้ — คืนด้วย [cancel]
class LocationLease {
  final LocationStreamHub _hub;
  final int _id;
  bool _cancelled = false;

  LocationLease._(this._hub, this._id);

  bool get isActive => !_cancelled;

  /// คืนสิทธิ์ เรียกซ้ำได้ไม่มีผลข้างเคียง
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    await _hub._detach(_id);
  }
}

class _Consumer {
  final LocationNeed need;
  final void Function(Position) onPosition;
  final void Function(Object error)? onError;

  _Consumer({required this.need, required this.onPosition, this.onError});
}

/// สิ่งที่สตรีมจริงถูกตั้งค่าไว้ ณ ตอนนี้ — รวมความต้องการของทุกคนแล้ว
@immutable
class _Requirement {
  final LocationAccuracy accuracy;
  final int distanceFilterM;
  final bool background;
  final String notificationTitle;
  final String notificationText;

  const _Requirement({
    required this.accuracy,
    required this.distanceFilterM,
    required this.background,
    required this.notificationTitle,
    required this.notificationText,
  });

  @override
  bool operator ==(Object other) =>
      other is _Requirement &&
      other.accuracy == accuracy &&
      other.distanceFilterM == distanceFilterM &&
      other.background == background &&
      other.notificationTitle == notificationTitle &&
      other.notificationText == notificationText;

  @override
  int get hashCode => Object.hash(
    accuracy,
    distanceFilterM,
    background,
    notificationTitle,
    notificationText,
  );
}

/// เจ้าของ `Geolocator.getPositionStream` เพียงรายเดียวของแอป
///
/// ## ทำไมต้องมีชั้นนี้
///
/// `geolocator` แคชสตรีมตำแหน่งไว้ในตัวปลั๊กอินเอง: ถ้ามีสตรีมเปิดค้างอยู่แล้ว
/// การเรียก `getPositionStream(locationSettings: ...)` ครั้งถัดไปจะ **คืนสตรีม
/// เดิมและทิ้ง settings ที่เพิ่งส่งไปทั้งชุดอย่างเงียบ ๆ** (ดู
/// `geolocator_android/lib/src/geolocator_android.dart` — `if (_positionStream
/// != null) return _positionStream!;`)
///
/// แอปนี้มีผู้ใช้ GPS สามราย: หมุดของเราบนแผนที่ติดตามรถ, การบันทึกเส้นทาง
/// เดินป่า และการแชร์ตำแหน่งให้เพื่อนร่วมทริป สองรายหลังต้องวิ่งต่อตอนปิดหน้าจอ
/// รายแรกไม่ต้อง ถ้าต่างคนต่างเรียก geolocator เอง ผลลัพธ์จะขึ้นกับว่า "ใครเปิด
/// ก่อน" ล้วน ๆ — เปิดหน้าติดตามรถไว้ก่อนแล้วค่อยกดบันทึกเส้นทาง จะได้ค่าของ
/// หน้าติดตามรถคือไม่มี foreground service แล้วการบันทึกก็ตายตอนล็อกหน้าจอ
/// โดยไม่มี error ให้เห็นสักบรรทัด
///
/// ชั้นนี้จึงถือสตรีมไว้ใบเดียว รวมความต้องการของทุกคนเป็นค่าที่แรงที่สุด
/// (ละเอียดที่สุด / ระยะกรองสั้นที่สุด / เบื้องหลังถ้ามีใครสักคนต้องการ) แล้ว
/// สร้างสตรีมใหม่เมื่อค่ารวมเปลี่ยนเท่านั้น
class LocationStreamHub {
  LocationStreamHub._();

  static final LocationStreamHub instance = LocationStreamHub._();

  /// ลำดับความละเอียด — เขียนเองเพราะลำดับใน enum เชื่อไม่ได้: `reduced` อยู่
  /// ท้ายสุดแต่หยาบที่สุด ถ้าใช้ `index` เทียบจะกลายเป็นว่ามันชนะทุกตัว
  static const Map<LocationAccuracy, int> _accuracyRank = {
    LocationAccuracy.reduced: 0,
    LocationAccuracy.lowest: 1,
    LocationAccuracy.low: 2,
    LocationAccuracy.medium: 3,
    LocationAccuracy.high: 4,
    LocationAccuracy.best: 5,
    LocationAccuracy.bestForNavigation: 6,
  };

  /// ชื่อช่องแจ้งเตือนที่ผู้ใช้จะเห็นในตั้งค่าระบบของ Android
  static const String androidChannelName = 'ตำแหน่งระหว่างทริป';

  /// กันลูป: ถ้าสตรีมปิดตัวเองซ้ำ ๆ ให้ยอมแพ้แล้วบอกผู้ใช้งาน ดีกว่าวนสร้างใหม่
  /// ไม่รู้จบจนแบตหมด
  static const int _maxRestarts = 3;

  final Map<int, _Consumer> _consumers = <int, _Consumer>{};
  int _nextId = 1;

  StreamSubscription<Position>? _sub;
  _Requirement? _active;
  int _restarts = 0;
  Future<void> _queue = Future<void>.value();

  PositionStreamFactory _factory =
      (settings) => Geolocator.getPositionStream(locationSettings: settings);

  /// ให้เทสต์เปลี่ยนที่มาของตำแหน่งได้ เรียก [resetForTesting] เพื่อคืนค่าเดิม
  @visibleForTesting
  set factory(PositionStreamFactory value) => _factory = value;

  @visibleForTesting
  Future<void> resetForTesting() async {
    _consumers.clear();
    await _stopStream();
    _active = null;
    _restarts = 0;
    _nextId = 1;
    _factory = (settings) =>
        Geolocator.getPositionStream(locationSettings: settings);
  }

  /// มีใครใช้ GPS อยู่กี่ราย
  int get leaseCount => _consumers.length;

  /// ตอนนี้สตรีมถูกตั้งให้วิ่งต่อเบื้องหลังหรือไม่
  bool get isBackgroundActive => _active?.background ?? false;

  @visibleForTesting
  LocationSettings? get activeSettings =>
      _active == null ? null : _settingsFor(_active!);

  /// ขอใช้ GPS ตามเงื่อนไขใน [need]
  ///
  /// สตรีมจริงอาจถูกสร้างใหม่ถ้าความต้องการรวมของทั้งแอปเปลี่ยนไป ผู้เรียกไม่
  /// ต้องรู้เรื่องนั้น — เห็นแค่ [onPosition] ที่เดินต่อไปเรื่อย ๆ
  Future<LocationLease> attach({
    required LocationNeed need,
    required void Function(Position position) onPosition,
    void Function(Object error)? onError,
  }) async {
    final id = _nextId++;
    _consumers[id] = _Consumer(
      need: need,
      onPosition: onPosition,
      onError: onError,
    );

    try {
      await _enqueue(_reconcile);
    } catch (_) {
      // เปิดสตรีมไม่ขึ้น — อย่าทิ้งผู้ใช้งานค้างไว้ในทะเบียน ไม่งั้นครั้งหน้าที่
      // มีคนอื่นมา attach จะคำนวณความต้องการรวมจากรายที่ไม่มีอยู่จริง
      _consumers.remove(id);
      unawaited(_enqueue(_reconcile).catchError((_) {}));
      rethrow;
    }

    return LocationLease._(this, id);
  }

  Future<void> _detach(int id) async {
    if (_consumers.remove(id) == null) return;
    await _enqueue(_reconcile).catchError((Object e) {
      debugPrint('[LocationHub] reconcile after detach failed: $e');
    });
  }

  /// ทำงานทีละคำสั่ง — attach/detach เป็น async ทั้งคู่ ถ้าปล่อยให้ reconcile
  /// สองรอบซ้อนกันจะได้สตรีมค้างสองเส้นและแถบแจ้งเตือนที่ปิดไม่ลง
  Future<void> _enqueue(Future<void> Function() op) {
    final next = _queue.then((_) => op());
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> _reconcile() async {
    final next = _requirementFor(_consumers.values);
    final streamMatchesState = (_sub != null) == (next != null);
    if (next == _active && streamMatchesState) return;

    await _stopStream();
    _active = next;
    _restarts = 0;
    if (next == null) return;

    _listen(next);
  }

  void _listen(_Requirement requirement) {
    _sub = _factory(_settingsFor(requirement)).listen(
      _emit,
      onError: _emitError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  void _emit(Position position) {
    // คัดลอกก่อนวน: handler มีสิทธิ์ยกเลิก lease ของตัวเองระหว่างถูกเรียก
    for (final consumer in _consumers.values.toList()) {
      consumer.onPosition(position);
    }
  }

  void _emitError(Object error) {
    debugPrint('[LocationHub] position stream error: $error');
    for (final consumer in _consumers.values.toList()) {
      consumer.onError?.call(error);
    }
  }

  /// สตรีมปิดตัวเองทั้งที่ยังมีคนใช้อยู่ — ลองต่อใหม่แบบมีเพดาน ถ้ายังไม่ได้
  /// ค่อยส่ง error ออกไปให้เห็น ดีกว่าหยุดส่งตำแหน่งเงียบ ๆ ทั้งที่หน้าจอยัง
  /// บอกว่ากำลังบันทึกอยู่
  void _onDone() {
    _sub = null;
    if (_consumers.isEmpty) {
      _active = null;
      return;
    }

    final requirement = _active;
    if (requirement == null) return;

    if (_restarts >= _maxRestarts) {
      _active = null;
      _emitError(
        StateError('ระบบหยุดส่งตำแหน่งเอง หลังพยายามต่อใหม่ $_maxRestarts ครั้ง'),
      );
      return;
    }

    _restarts++;
    debugPrint('[LocationHub] stream closed unexpectedly, restart #$_restarts');
    _listen(requirement);
  }

  Future<void> _stopStream() async {
    final sub = _sub;
    _sub = null;
    if (sub == null) return;
    await sub.cancel();
    // ปล่อยให้ปลั๊กอินเคลียร์สตรีมที่มันแคชไว้ให้เสร็จก่อน ไม่งั้นการ listen
    // รอบถัดไปจะได้สตรีมเก่าที่ settings ชุดเดิมกลับมาแทน
    await Future<void>.delayed(Duration.zero);
  }

  static _Requirement? _requirementFor(Iterable<_Consumer> consumers) {
    if (consumers.isEmpty) return null;

    var accuracy = LocationAccuracy.reduced;
    var distanceFilterM = -1;
    var background = false;
    _Consumer? notifier;

    for (final consumer in consumers) {
      final need = consumer.need;

      if (_rank(need.accuracy) > _rank(accuracy)) accuracy = need.accuracy;

      if (distanceFilterM < 0 || need.distanceFilterM < distanceFilterM) {
        distanceFilterM = need.distanceFilterM;
      }

      if (!need.keepAliveInBackground) continue;
      background = true;
      // เสมอกันให้รายที่มาก่อนชนะ — Map เรียงตามลำดับที่ใส่ ผลจึงคงที่เสมอ
      if (notifier == null ||
          _rank(need.accuracy) > _rank(notifier.need.accuracy)) {
        notifier = consumer;
      }
    }

    return _Requirement(
      accuracy: accuracy,
      distanceFilterM: distanceFilterM < 0 ? 0 : distanceFilterM,
      background: background,
      notificationTitle: notifier?.need.notificationTitle ?? '',
      notificationText: notifier?.need.notificationText ?? '',
    );
  }

  static int _rank(LocationAccuracy accuracy) => _accuracyRank[accuracy] ?? 0;

  static LocationSettings _settingsFor(_Requirement requirement) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: requirement.accuracy,
          distanceFilter: requirement.distanceFilterM,
          // foreground service คือสิ่งเดียวที่ทำให้ Android ส่งตำแหน่งต่อหลัง
          // ผู้ใช้กดล็อกหน้าจอ — และเป็นเหตุผลที่แอปนี้ไม่ต้องขอสิทธิ์
          // ACCESS_BACKGROUND_LOCATION (ซึ่งต้องยื่นแบบฟอร์มกับ Play Store)
          foregroundNotificationConfig: requirement.background
              ? ForegroundNotificationConfig(
                  notificationTitle: requirement.notificationTitle,
                  notificationText: requirement.notificationText,
                  notificationChannelName: androidChannelName,
                  notificationIcon: const AndroidResource(
                    name: 'ic_stat_location',
                    defType: 'drawable',
                  ),
                  enableWakeLock: true,
                  setOngoing: true,
                )
              : null,
        );

      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: requirement.accuracy,
          distanceFilter: requirement.distanceFilterM,
          activityType: ActivityType.fitness,
          // ต้องระบุตรง ๆ ทุกครั้ง: ค่าเริ่มต้นของ AppleSettings คือ true
          // ปล่อยว่างไว้เท่ากับเปิด GPS เบื้องหลังให้หน้าจอที่ไม่ได้ขอ
          allowBackgroundLocationUpdates: requirement.background,
          // iOS หยุดส่งเองเมื่อคิดว่าเราอยู่นิ่ง ซึ่งบนเส้นทางเดินป่าคือการ
          // ตัดเส้นทางหายไปหนึ่งช่วงทุกครั้งที่หยุดพัก
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: requirement.background,
        );

      default:
        return LocationSettings(
          accuracy: requirement.accuracy,
          distanceFilter: requirement.distanceFilterM,
        );
    }
  }
}
