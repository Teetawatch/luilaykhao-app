import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/api_endpoints.dart';
import '../models/home_widget_snapshot.dart';
import 'api_client.dart';

/// วิดเจ็ตหน้าโฮม "อีก 17 วันไปเขาช้างเผือก" — บนหน้าจอที่คนดูวันละหลายสิบครั้ง
///
/// การ์ดวันเดินทาง ([TripActivityService]) ดูแลวันเดียว คลาสนี้ดูแลวันที่เหลือ:
/// ทริปถัดไปที่จองไว้ กับยอดที่ต้องจ่ายงวดหน้า
///
/// วิดเจ็ตของทั้งสองแพลตฟอร์มอ่านไฟล์ที่แอปเขียนไว้ ไม่ได้ต่อเน็ตเอง หน้าที่ของ
/// คลาสนี้จึงมีอย่างเดียว: ไปเอา snapshot มาเขียนลงที่ที่วิดเจ็ตอ่านได้ แล้วบอกให้
/// มันวาดใหม่
///
///   iOS      → App Group UserDefaults + WidgetCenter.reloadAllTimelines()
///   Android  → SharedPreferences + broadcast ให้ AppWidgetProvider
///
/// ทุกทางออกเงียบเสมอ วิดเจ็ตเป็นของประดับที่ดีมาก ไม่ใช่ระบบที่ธุรกิจแขวนอยู่ —
/// การเรียกที่ล้มเหลวต้องไม่ทำให้อะไรในแอปสะดุด
class HomeWidgetService {
  HomeWidgetService._();

  static final instance = HomeWidgetService._();

  static const _channel = MethodChannel('luilaykhao/home_widget');

  /// ช่วงเวลาที่สั้นที่สุดระหว่างการดึงข้อมูลสองครั้ง (ยกเว้นเรียกแบบ `force`)
  ///
  /// `refresh()` ถูกเรียกทุกครั้งที่แอปกลับมาหน้าจอ ซึ่งคนสลับแอปไปมาทำได้สิบครั้ง
  /// ในนาทีเดียว ข้อมูลชุดนี้ขยับเป็นวัน ไม่ใช่เป็นวินาที
  static const _minInterval = Duration(minutes: 2);

  ApiClient? _api;
  DateTime? _lastFetch;

  /// payload ก้อนล่าสุดที่เขียนลงฝั่ง native สำเร็จ
  ///
  /// เขียนซ้ำด้วยข้อความเดิมไม่ได้ทำให้จออัปเดตอะไร แต่ทำให้ WidgetKit เสีย
  /// โควตาการรีเฟรชรายวันไปฟรี ๆ (iOS จำกัดจำนวนครั้งที่วิดเจ็ตวาดใหม่ต่อวัน)
  String? _lastPayload;

  bool _inFlight = false;

  static bool get _supported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  void attachApi(ApiClient api) {
    _api = api;
  }

  /// ดึง snapshot ใหม่แล้วส่งให้วิดเจ็ต
  ///
  /// [force] ข้ามการหน่วงเวลา ใช้ตอนที่มีเหตุการณ์ทำให้ข้อมูลเปลี่ยนแน่ ๆ (จองเสร็จ
  /// แนบสลิป ล็อกอิน หรือได้ push ของการ์ดวันเดินทาง)
  Future<void> refresh({bool force = false}) async {
    if (!_supported) return;

    final api = _api;
    // ยังไม่ได้ผูก ApiClient = ยังไม่รู้อะไรเลย ไม่ใช่ "ออกจากระบบแล้ว" — ห้ามล้าง
    // วิดเจ็ตตรงนี้เด็ดขาด ไม่งั้นทุก entry point ที่วิ่งมาก่อน AppProvider จะลบ
    // ทริปทิ้งจากหน้าโฮมโดยที่ผู้ใช้ไม่ได้ทำอะไรผิด (การออกจากระบบเรียก [clear] เอง)
    if (api == null) return;

    if (api.token == null || api.token!.isEmpty) {
      // ออกจากระบบแล้วยังปล่อยทริปของคนก่อนไว้บนหน้าโฮมคือเรื่องความเป็นส่วนตัว
      // ไม่ใช่แค่ข้อมูลเก่า
      await clear();
      return;
    }

    if (_inFlight) return;
    if (!force &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _minInterval) {
      return;
    }

    _inFlight = true;
    try {
      final response = await api.get(ApiEndpoints.homeWidget);
      final snapshot = HomeWidgetSnapshot.fromJson(
        api.data(response) is Map
            ? Map<String, dynamic>.from(api.data(response) as Map)
            : null,
      );
      if (snapshot == null) return;

      _lastFetch = DateTime.now();
      await _write(snapshot);
    } catch (e) {
      debugPrint('[HomeWidget] refresh failed: $e');
    } finally {
      _inFlight = false;
    }
  }

  /// เก็บวิดเจ็ตกลับไปเป็นสถานะว่าง — ใช้ตอนออกจากระบบ
  Future<void> clear() async {
    if (!_supported) return;

    _lastPayload = null;
    _lastFetch = null;

    try {
      // ฝั่ง native ตอบ false เมื่อเขียนไม่ได้ (iOS: App Group ยังไม่เปิด)
      // ซึ่งไม่มีอะไรให้ทำต่อ — วิดเจ็ตเป็นของประดับ ไม่ใช่ทางหลัก
      await _channel.invokeMethod<bool>('clear');
    } catch (e) {
      debugPrint('[HomeWidget] clear failed: $e');
    }
  }

  Future<void> _write(HomeWidgetSnapshot snapshot) async {
    final payload = jsonEncode(snapshot.toNativeJson());
    if (payload == _lastPayload) return;

    try {
      await _channel.invokeMethod<bool>('save', {'json': payload});
      _lastPayload = payload;
    } catch (e) {
      // ไม่จำว่าเขียนแล้ว — ครั้งหน้าที่แอปกลับมาหน้าจอจะได้ลองใหม่
      debugPrint('[HomeWidget] save failed: $e');
    }
  }

  /// เปิดให้เทสต์ยืนยันได้ว่าเขียนซ้ำด้วยข้อมูลเดิมแล้วไม่ยิงไปฝั่ง native อีก
  @visibleForTesting
  void resetForTest() {
    _api = null;
    _lastPayload = null;
    _lastFetch = null;
    _inFlight = false;
  }
}
