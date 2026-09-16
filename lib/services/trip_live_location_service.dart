import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/api_endpoints.dart';
import 'api_client.dart';
import 'location_stream_hub.dart';
import 'realtime_service.dart';

/// เพื่อนร่วมทริปหนึ่งคนบนแผนที่ ณ วินาทีนี้
class TripMemberPin {
  final int userId;
  final String name;
  final String? avatarUrl;
  final LatLng position;
  final double? altitudeM;
  final int? batteryLevel;
  final DateTime? recordedAt;

  const TripMemberPin({
    required this.userId,
    required this.name,
    required this.position,
    this.avatarUrl,
    this.altitudeM,
    this.batteryLevel,
    this.recordedAt,
  });

  static TripMemberPin? fromJson(Map<String, dynamic> json) {
    final lat = double.tryParse('${json['latitude']}');
    final lng = double.tryParse('${json['longitude']}');
    if (lat == null || lng == null) return null;

    return TripMemberPin(
      userId: int.tryParse('${json['user_id']}') ?? 0,
      name: json['name']?.toString() ?? 'เพื่อนร่วมทริป',
      avatarUrl: json['avatar_url']?.toString(),
      position: LatLng(lat, lng),
      altitudeM: double.tryParse('${json['altitude_m']}'),
      batteryLevel: int.tryParse('${json['battery_level']}'),
      recordedAt: DateTime.tryParse('${json['recorded_at']}'),
    );
  }

  /// เห็นครั้งสุดท้ายเมื่อไหร่ — บนดอยที่สัญญาณขาด ๆ หาย ๆ นี่คือข้อมูลสำคัญพอ ๆ
  /// กับตัวหมุด หมุดที่นิ่งมา 20 นาทีไม่ได้แปลว่าคนนั้นยืนอยู่ตรงนั้น
  String get lastSeenLabel {
    final at = recordedAt;
    if (at == null) return 'ไม่ทราบเวลา';

    final minutes = DateTime.now().difference(at).inMinutes;
    if (minutes < 1) return 'เมื่อสักครู่';
    if (minutes < 60) return '$minutes นาทีที่แล้ว';
    return '${(minutes / 60).floor()} ชั่วโมงที่แล้ว';
  }
}

List<TripMemberPin> _parseMembers(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) => TripMemberPin.fromJson(Map<String, dynamic>.from(m)))
      .whereType<TripMemberPin>()
      .toList();
}

/// การแชร์ตำแหน่งของ "เรา" หนึ่งครั้ง — มีอายุยืนกว่าหน้าจอที่กดเปิดมัน
///
/// ตัวนี้แยกออกมาจาก [TripLiveLocationController] ด้วยเหตุผลเดียว: การแชร์ที่
/// หยุดเองตอนผู้ใช้กดย้อนกลับ ไม่ใช่การแชร์ คนที่กดเปิดแล้วเก็บเครื่องลงกระเป๋า
/// เดินต่อ คือพฤติกรรมปกติที่สุดของฟีเจอร์นี้ ไม่ใช่กรณีขอบ
///
/// สองอย่างที่ทำให้มันอยู่รอดจริง: สตรีมตำแหน่งขอผ่าน [LocationStreamHub] แบบ
/// ระบุว่าต้องวิ่งต่อเบื้องหลัง และตัวมันเองเป็น singleton ที่ไม่มีหน้าจอไหน
/// dispose ได้
///
/// ยังคงเป็นการตัดสินใจของเจ้าตัวทุกครั้ง: ไม่เปิดเอง ไม่แชร์ค้างข้ามรอบ และ
/// ปิดเมื่อไหร่ก็ได้ — ปิดแล้วแถวบนเซิร์ฟเวอร์ถูกลบจริง ไม่ใช่แค่ซ่อน
class TripLocationSharing extends ChangeNotifier {
  TripLocationSharing._();

  static final TripLocationSharing instance = TripLocationSharing._();

  /// ส่งตำแหน่งขึ้นเซิร์ฟเวอร์อย่างมากทุกกี่วินาที
  ///
  /// ตำแหน่งคนเดินป่าเปลี่ยนช้ากว่ารถมาก และแบตคือทรัพยากรที่หายากที่สุดบนดอย
  static const Duration uploadInterval = Duration(seconds: 25);

  /// ขยับน้อยกว่านี้ไม่ต้องส่ง (เมตร) — กันการส่งรัวจากความคลาดเคลื่อนของ GPS
  static const int distanceFilterM = 15;

  static const LocationNeed _need = LocationNeed(
    accuracy: LocationAccuracy.high,
    distanceFilterM: distanceFilterM,
    keepAliveInBackground: true,
    notificationTitle: 'กำลังแชร์ตำแหน่งกับเพื่อนร่วมทริป',
    notificationText: 'เพื่อนในรอบเดียวกันเห็นตำแหน่งของคุณอยู่',
  );

  ApiClient? _api;
  int? _scheduleId;
  LocationLease? _lease;
  DateTime? _lastUpload;
  bool _busy = false;

  /// ชุดเพื่อนล่าสุดที่ได้ติดมากับผลของการส่งตำแหน่ง — หน้าจอที่เปิดอยู่หยิบไป
  /// ใช้ได้เลยโดยไม่ต้องยิง API ซ้ำ
  List<TripMemberPin>? _membersFromUpload;
  int? _membersScheduleId;

  LatLng? myPosition;
  String? error;

  bool get busy => _busy;
  bool get isSharing => _lease != null;
  int? get scheduleId => _scheduleId;
  bool isSharingFor(int id) => _lease != null && _scheduleId == id;

  List<TripMemberPin>? membersFor(int id) =>
      _membersScheduleId == id ? _membersFromUpload : null;

  /// ให้เทสต์ข้ามคาบ 25 วินาทีไปได้ โดยไม่ต้องรอเวลาจริง
  @visibleForTesting
  void debugClearUploadThrottle() => _lastUpload = null;

  /// เปิดแชร์ คืน true เมื่อเริ่มส่งแล้ว — ถ้าไม่สำเร็จดูเหตุผลที่ [error]
  ///
  /// [promptForPermission] เป็น false เมื่อเป็นการ "ต่อของเดิม" ไม่ใช่การกดเปิด
  /// ของผู้ใช้ การเปิดหน้าจอไม่ควรเด้งกล่องขอสิทธิ์ GPS ขึ้นมาเอง
  Future<bool> start({
    required ApiClient api,
    required int scheduleId,
    bool promptForPermission = true,
  }) async {
    if (isSharingFor(scheduleId)) return true;
    if (_busy) return false;

    _busy = true;
    error = null;
    notifyListeners();

    try {
      // ย้ายรอบ: ปิดของเดิมให้เรียบร้อยก่อน ไม่งั้นเพื่อนในรอบก่อนหน้าจะเห็น
      // หมุดของเราค้างอยู่ทั้งที่เราไปอยู่อีกทริปแล้ว
      if (_lease != null) {
        await _teardown(tellServer: true).catchError((_) {});
      }

      if (!await _ensurePermission(prompt: promptForPermission)) {
        error = 'ต้องอนุญาตให้เข้าถึงตำแหน่งก่อน จึงจะแชร์กับเพื่อนร่วมทริปได้';
        return false;
      }

      _api = api;
      _scheduleId = scheduleId;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _remember(position);

      // ยิงครั้งแรกแบบรอผล เพื่อให้รู้เดี๋ยวนี้ว่าเซิร์ฟเวอร์ให้แชร์ไหม (อยู่ใน
      // ช่วงทริปหรือเปล่า เป็นรอบของเราหรือเปล่า) — ยกเว้นกรณีเน็ตไม่มา ซึ่งบน
      // ดอยเป็นเรื่องปกติ กรณีนั้นเปิดไว้ก่อนแล้วให้รอบถัดไปส่งแทน
      try {
        await _send(position);
      } on ApiException catch (e) {
        if (!e.isNetworkError) rethrow;
      }

      _lease = await LocationStreamHub.instance.attach(
        need: _need,
        onPosition: _onPosition,
        onError: (Object e) =>
            debugPrint('[TripLocationSharing] stream error: $e'),
      );
      return true;
    } on ApiException catch (e) {
      error = e.message;
      _forgetSession();
      return false;
    } catch (e) {
      debugPrint('[TripLocationSharing] start failed: $e');
      error = 'เปิดแชร์ตำแหน่งไม่สำเร็จ';
      _forgetSession();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// ปิดแชร์ — หยุดส่งทันที แล้วลบตำแหน่งของเราออกจากเซิร์ฟเวอร์
  ///
  /// การหยุดส่งเกิดขึ้นเสมอแม้คำสั่งลบจะไปไม่ถึง: หมุดที่ไม่มีใครอัปเดตแล้วจะ
  /// หมดอายุเองฝั่งเซิร์ฟเวอร์ ดีกว่าค้างส่งต่อทั้งที่ผู้ใช้สั่งปิดไปแล้ว
  Future<bool> stop() async {
    if (_busy || _lease == null) return !isSharing;

    _busy = true;
    notifyListeners();

    try {
      await _teardown(tellServer: true);
      error = null;
      return true;
    } catch (e) {
      debugPrint('[TripLocationSharing] stop failed: $e');
      error = 'หยุดส่งตำแหน่งแล้ว แต่ยังลบหมุดบนเซิร์ฟเวอร์ไม่สำเร็จ '
          'เพื่อนอาจเห็นหมุดเดิมอีกสักครู่';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// เลิกแชร์โดยไม่แตะเซิร์ฟเวอร์ — ใช้ตอนออกจากระบบหรือลบบัญชี ซึ่งโทเคนอาจ
  /// ใช้ไม่ได้แล้ว การยิง API ตรงนั้นมีแต่จะได้ 401 กลับมา
  Future<void> abandonLocally() async {
    if (_lease == null && _scheduleId == null) return;
    await _teardown(tellServer: false);
    error = null;
    notifyListeners();
  }

  /// ลบแถวของเราบนเซิร์ฟเวอร์ทิ้ง ทั้งที่เครื่องนี้ไม่ได้กำลังแชร์อยู่
  ///
  /// ใช้เมื่อเซิร์ฟเวอร์ยังจำได้ว่าเราแชร์อยู่ แต่เรากลับส่งต่อไม่ได้แล้ว —
  /// หมุดที่ไม่มีวันขยับอีกคือหมุดที่บอกเพื่อนผิด
  Future<void> forgetServerRow({
    required ApiClient api,
    required int scheduleId,
  }) async {
    try {
      await api.delete(ApiEndpoints.scheduleLiveLocation(scheduleId));
    } catch (e) {
      debugPrint('[TripLocationSharing] could not clear stale row: $e');
    }
  }

  void _onPosition(Position position) {
    _remember(position);
    notifyListeners();

    final last = _lastUpload;
    if (last != null && DateTime.now().difference(last) < uploadInterval) {
      return;
    }
    unawaited(_sendGuarded(position));
  }

  void _remember(Position position) {
    myPosition = LatLng(position.latitude, position.longitude);
  }

  Future<void> _sendGuarded(Position position) async {
    try {
      await _send(position);
    } on ApiException catch (e) {
      // บนดอยเน็ตหลุดเป็นเรื่องปกติ — เก็บเงียบแล้วรอรอบถัดไป
      if (e.isNetworkError) return;

      // 404 = ไม่ใช่รอบของเราแล้ว, 422 = เลยช่วงเวลาทริปไปแล้ว ทั้งคู่ไม่มีทาง
      // หายเองในรอบหน้า ปล่อยสตรีมวิ่งต่อคือเปิด GPS กินแบตทิ้งเปล่า ๆ
      if (e.statusCode == 404 || e.statusCode == 422) {
        error = e.message;
        await _teardown(tellServer: true).catchError((_) {});
        notifyListeners();
        return;
      }

      debugPrint('[TripLocationSharing] upload rejected: ${e.message}');
    } catch (e) {
      debugPrint('[TripLocationSharing] upload failed: $e');
    }
  }

  Future<void> _send(Position position) async {
    final api = _api;
    final scheduleId = _scheduleId;
    if (api == null || scheduleId == null) return;

    _lastUpload = DateTime.now();

    final response = await api.post(
      ApiEndpoints.scheduleLiveLocation(scheduleId),
      body: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy_m': position.accuracy,
        'heading': position.heading >= 0 ? position.heading : null,
        'speed_kmh': position.speed >= 0 ? position.speed * 3.6 : null,
        'altitude_m': position.altitude,
        'battery_level': ?await _batteryLevel(),
      },
    );

    final data = api.data(response) as Map?;
    _membersFromUpload = _parseMembers(data?['members']);
    _membersScheduleId = scheduleId;
    notifyListeners();
  }

  Future<void> _teardown({required bool tellServer}) async {
    final lease = _lease;
    final api = _api;
    final scheduleId = _scheduleId;

    // เคลียร์สถานะก่อนรอ I/O เสมอ: ถ้าคำสั่งลบค้างอยู่ ผู้ใช้ต้องเห็นว่าหยุด
    // แล้วจริง ไม่ใช่ปุ่มที่ยังบอกว่ากำลังแชร์
    _forgetSession();
    await lease?.cancel();

    if (!tellServer || api == null || scheduleId == null) return;
    await api.delete(ApiEndpoints.scheduleLiveLocation(scheduleId));
  }

  void _forgetSession() {
    _lease = null;
    _api = null;
    _scheduleId = null;
    _lastUpload = null;
    myPosition = null;
    _membersFromUpload = null;
    _membersScheduleId = null;
  }

  /// แบตของเพื่อนคือข้อมูลความปลอดภัย: หมุดที่หายไปเพราะแบตหมด ต่างจากหมุดที่
  /// หายไปเพราะเดินเข้าอับสัญญาณ — คนที่ตามหาต้องแยกสองอย่างนี้ออก
  Future<int?> _batteryLevel() async {
    try {
      return await Battery().batteryLevel;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensurePermission({required bool prompt}) async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (!prompt) return false;
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}

/// "เพื่อนร่วมทริปอยู่ตรงไหน" — ตัวจัดการฝั่งหน้าจอ
///
/// พอขึ้นดอยจริงคนกระจายกันเป็นกิโล คำถามที่ดังที่สุดในหัวทุกคนคือ "หัวแถวถึงยัง"
/// กับ "น้องคนนั้นหายไปไหน" ซึ่งเดิมแอปตอบไม่ได้เลย เพราะเห็นแค่รถ ไม่เห็นคน
///
/// ตัวนี้ถือเฉพาะสิ่งที่ตายไปพร้อมหน้าจอได้: รายชื่อเพื่อน การ subscribe socket
/// และสถานะโหลด ส่วนการแชร์ของเราเองอยู่ที่ [TripLocationSharing] เพราะมันต้อง
/// อยู่ต่อหลังผู้ใช้กดย้อนกลับ
class TripLiveLocationController extends ChangeNotifier {
  final ApiClient api;
  final int scheduleId;

  TripLiveLocationController({required this.api, required this.scheduleId}) {
    _sharing.addListener(_onSharingChanged);
  }

  TripLocationSharing get _sharing => TripLocationSharing.instance;

  VoidCallback? _unsubscribe;
  bool _serverSaysSharing = false;
  bool _disposed = false;

  List<TripMemberPin> members = const [];
  bool loading = true;
  String? error;

  bool get sharing => _sharing.isSharingFor(scheduleId);
  bool get busy => _sharing.busy;
  String? get sharingError => _sharing.error;

  /// หมุดของเราแสดงเฉพาะตอนที่เรากำลังแชร์จริง — ไม่งั้นมันคือหมุดที่คนอื่นไม่
  /// เห็น แต่เรานึกว่าเขาเห็น
  LatLng? get myPosition =>
      _sharing.isSharingFor(scheduleId) ? _sharing.myPosition : null;

  Future<void> start() async {
    await refreshMembers();
    await _resumeSharingIfServerStillExpectsIt();
    await _listen();
    loading = false;
    _notify();
  }

  /// ดึงรายชื่อใหม่ทั้งชุด — หน้าจอเรียกเป็นระยะเผื่อ socket หลุด ซึ่งบนดอยเกิดบ่อย
  /// กว่าที่คิด และหน้าจอที่ค้างหมุดเก่าไว้เงียบ ๆ อันตรายกว่าหน้าจอที่บอกว่าไม่รู้
  Future<void> refreshMembers() async {
    try {
      final response = await api.get(
        ApiEndpoints.scheduleLiveLocation(scheduleId),
      );
      final data = api.data(response) as Map?;
      members = _parseMembers(data?['members']);
      _serverSaysSharing = data?['sharing'] == true;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'โหลดตำแหน่งเพื่อนไม่สำเร็จ';
    }
    _notify();
  }

  /// เซิร์ฟเวอร์ยังมีแถวของเราอยู่ แต่เครื่องนี้ไม่ได้ส่งแล้ว — เกิดเมื่อระบบ
  /// ปิดแอปทิ้งระหว่างทางหรือเครื่องรีสตาร์ต หมุดที่ค้างอยู่กำลังบอกเพื่อนผิด
  /// จึงต้องเลือกอย่างใดอย่างหนึ่ง: กลับไปส่งต่อ หรือลบมันทิ้ง
  Future<void> _resumeSharingIfServerStillExpectsIt() async {
    if (!_serverSaysSharing) return;
    // กำลังแชร์รอบอื่นอยู่ อย่าไปดึงสตรีมมาจากรอบนั้น
    if (_sharing.isSharing) return;

    final resumed = await _sharing.start(
      api: api,
      scheduleId: scheduleId,
      promptForPermission: false,
    );
    if (resumed) return;

    await _sharing.forgetServerRow(api: api, scheduleId: scheduleId);
    _serverSaysSharing = false;
    _notify();
  }

  Future<void> _listen() async {
    try {
      _unsubscribe = await RealtimeService.instance.subscribe(
        channel: 'private-trip-members.$scheduleId',
        event: 'member.location',
        handler: _onRealtime,
      );
    } catch (e) {
      debugPrint('[TripLiveLocation] subscribe failed: $e');
    }
  }

  void _onRealtime(Map<String, dynamic> payload) {
    final raw = payload['member'];
    if (raw is! Map) return;
    final member = Map<String, dynamic>.from(raw);
    final userId = int.tryParse('${member['user_id']}') ?? 0;
    if (userId == 0) return;

    final next = List<TripMemberPin>.from(members)
      ..removeWhere((m) => m.userId == userId);

    if (member['stopped'] != true) {
      final pin = TripMemberPin.fromJson(member);
      if (pin != null) next.add(pin);
    }

    members = next;
    _notify();
  }

  /// การส่งตำแหน่งแต่ละครั้งได้รายชื่อเพื่อนชุดใหม่ติดกลับมาด้วย หยิบมาใช้เลย
  /// ไม่ต้องยิง API ซ้ำ
  void _onSharingChanged() {
    final fresh = _sharing.membersFor(scheduleId);
    if (fresh != null) members = fresh;
    _notify();
  }

  Future<bool> startSharing() =>
      _sharing.start(api: api, scheduleId: scheduleId);

  Future<void> stopSharing() async {
    await _sharing.stop();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sharing.removeListener(_onSharingChanged);
    _unsubscribe?.call();
    // ตั้งใจไม่หยุดการแชร์ตรงนี้: ผู้ใช้กดย้อนกลับออกจากแผนที่ ไม่ได้แปลว่า
    // เลิกแชร์ — เขาแค่เก็บเครื่องแล้วเดินต่อ
    super.dispose();
  }
}
