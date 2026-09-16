import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/trip_story_card.dart';

/// หน้าตาการ์ดสตอรี่ที่เจ้าของเลือกไว้ล่าสุด
@immutable
class StoryLook {
  final StoryStyle style;

  /// ความชัดของรูป 0–1 ดู [TripStoryCard.photoOpacity]
  final double photoOpacity;

  const StoryLook({required this.style, required this.photoOpacity});

  static const defaults = StoryLook(
    style: StoryStyle.classic,
    photoOpacity: kStoryPhotoOpacityDefault,
  );
}

/// จำสไตล์กับความโปร่งใสที่เลือกไว้ข้ามการแชร์แต่ละครั้ง
///
/// คนที่ชอบการ์ดขาวดำมักชอบทุกใบ ไม่ใช่ใบเดียว — ถ้าต้องมาเลือกใหม่ทุกครั้ง
/// สไตล์ก็จะกลายเป็นของเล่นที่ไม่มีใครใช้จริง
///
/// เก็บใน SharedPreferences ล้วน ๆ ไม่แตะเซิร์ฟเวอร์ เพราะเป็นรสนิยมของเครื่อง
/// นี้ ไม่ใช่ข้อมูลบัญชี และอ่านไม่ได้เมื่อไรก็แค่กลับไปใช้ค่าตั้งต้น
class StoryLookStorage {
  StoryLookStorage._();

  static final StoryLookStorage instance = StoryLookStorage._();

  static const _key = 'story_look_v1';

  Future<StoryLook> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return StoryLook.defaults;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return StoryLook.defaults;

      final opacity = decoded['photo_opacity'];

      return StoryLook(
        style: StoryStyle.fromName(decoded['style']?.toString()),
        photoOpacity: opacity is num
            ? opacity.toDouble().clamp(0.0, 1.0)
            : kStoryPhotoOpacityDefault,
      );
    } catch (_) {
      return StoryLook.defaults;
    }
  }

  Future<void> write(StoryLook look) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'style': look.style.name,
          'photo_opacity': look.photoOpacity,
        }),
      );
    } catch (_) {
      // จำไม่ได้ก็ไม่เป็นไร ครั้งหน้าแค่เริ่มที่ค่าตั้งต้น
    }
  }
}
