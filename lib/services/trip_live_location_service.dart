import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/api_endpoints.dart';
import 'api_client.dart';
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

/// "เพื่อนร่วมทริปอยู่ตรงไหน" — ตัวจัดการฝั่งแอป
///
/// พอขึ้นดอยจริงคนกระจายกันเป็นกิโล คำถามที่ดังที่สุดในหัวทุกคนคือ "หัวแถวถึงยัง"
/// กับ "น้องคนนั้นหายไปไหน" ซึ่งเดิมแอปตอบไม่ได้เลย เพราะเห็นแค่รถ ไม่เห็นคน
///
/// การแชร์เป็นการตัดสินใจของเจ้าตัวทุกครั้ง: ไม่มีการเปิดให้อัตโนมัติ ไม่มีการ
/// แชร์ค้างข้ามทริป และปิดเมื่อไหร่ก็ได้ — ปิดแล้วแถวบนเซิร์ฟเวอร์ถูกลบทิ้งจริง
/// ไม่ใช่แค่ซ่อน
class TripLiveLocationController extends ChangeNotifier {
  /// ส่งตำแหน่งขึ้นเซิร์ฟเวอร์อย่างมากทุกกี่วินาที
  ///
  /// ตำแหน่งคนเดินป่าเปลี่ยนช้ากว่ารถมาก และแบตคือทรัพยากรที่หายากที่สุดบนดอย
  static const Duration _uploadInterval = Duration(seconds: 25);

  /// ขยับน้อยกว่านี้ไม่ต้องส่ง (เมตร) — กันการส่งรัวจากความคลาดเคลื่อนของ GPS
  static const int _distanceFilterM = 15;

  final ApiClient api;
  final int scheduleId;

  TripLiveLocationController({required this.api, required this.scheduleId});

  StreamSubscription<Position>? _positionSub;
  VoidCallback? _unsubscribe;
  DateTime? _lastUpload;

  List<TripMemberPin> members = const [];
  LatLng? myPosition;
  bool sharing = false;
  bool loading = true;
  bool busy = false;
  String? error;

  Future<void> start() async {
    await refreshMembers();
    await _listen();
    loading = false;
    notifyListeners();
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
      sharing = data?['sharing'] == true;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'โหลดตำแหน่งเพื่อนไม่สำเร็จ';
    }
    notifyListeners();
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
    notifyListeners();
  }

  /// เปิดแชร์ — ขอสิทธิ์ GPS แล้วเริ่มส่งตำแหน่ง
  Future<bool> startSharing() async {
    if (busy) return sharing;
    busy = true;
    notifyListeners();

    try {
      if (!await _ensurePermission()) {
        error = 'ต้องอนุญาตให้เข้าถึงตำแหน่งก่อน จึงจะแชร์กับเพื่อนร่วมทริปได้';
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _upload(position, force: true);

      _positionSub?.cancel();
      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: _distanceFilterM,
            ),
          ).listen(
            (position) => _upload(position),
            onError: (Object e) =>
                debugPrint('[TripLiveLocation] stream error: $e'),
          );

      sharing = true;
      error = null;
      return true;
    } catch (e) {
      error = e is ApiException ? e.message : 'เปิดแชร์ตำแหน่งไม่สำเร็จ';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// ปิดแชร์ — ลบตำแหน่งของตัวเองออกจากเซิร์ฟเวอร์ทันที
  Future<void> stopSharing() async {
    if (busy) return;
    busy = true;
    notifyListeners();

    _positionSub?.cancel();
    _positionSub = null;
    _lastUpload = null;

    try {
      await api.delete(ApiEndpoints.scheduleLiveLocation(scheduleId));
      sharing = false;
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'ปิดแชร์ตำแหน่งไม่สำเร็จ';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _upload(Position position, {bool force = false}) async {
    myPosition = LatLng(position.latitude, position.longitude);
    notifyListeners();

    final last = _lastUpload;
    if (!force && last != null && DateTime.now().difference(last) < _uploadInterval) {
      return;
    }
    _lastUpload = DateTime.now();

    try {
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
      members = _parseMembers(data?['members']);
      notifyListeners();
    } catch (e) {
      // บนดอยเน็ตหลุดเป็นเรื่องปกติ — เก็บเงียบแล้วรอรอบถัดไป ไม่ต้องเด้ง error
      // ใส่หน้าจอที่กำลังดูแผนที่อยู่
      debugPrint('[TripLiveLocation] upload failed: $e');
    }
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

  List<TripMemberPin> _parseMembers(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => TripMemberPin.fromJson(Map<String, dynamic>.from(m)))
        .whereType<TripMemberPin>()
        .toList();
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _unsubscribe?.call();
    super.dispose();
  }
}
