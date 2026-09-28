import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip_medal.dart';
import '../widgets/medal_story_card.dart';

/// หน้าตาการ์ดแชร์เหรียญที่เจ้าของเลือกไว้ล่าสุด — ทุกอย่างยกเว้นรูปของตัวเอง
/// (รูปเป็นของเหรียญใบนั้น ไม่ใช่รสนิยม และไฟล์ชั่วคราวอาจหายไปแล้วด้วย)
@immutable
class MedalLook {
  final MedalBackdrop backdrop;
  final MedalCardLayout layout;

  /// ความชัดของรูป 0–1 (พื้นหลังแบบรูป) ดู [MedalStoryCard.photoOpacity]
  final double photoOpacity;

  /// ความเข้มของพื้นสี 0–1 (พื้นหลังสีเหรียญ) ดู [MedalStoryCard.tone]
  final double tone;

  /// ขนาดเหรียญเทียบกับขนาดปกติของรูปแบบนั้น
  final double medalScale;

  final MedalCardParts parts;

  /// ทรงเหรียญแม่แบบที่ชอบ — ใช้เป็นจุดเริ่มเฉพาะเหรียญที่ยังไม่เคยเลือกทรง
  /// บนทริปแม่แบบ เหรียญที่บันทึกทรงไว้แล้ว (TripMedal.shape) หรือทริปที่มีภาพ
  /// ออกแบบเองจะเปิดมาตามนั้นก่อนเสมอ (ดู MedalShareSheet)
  final MedalShape shape;

  const MedalLook({
    required this.backdrop,
    required this.layout,
    required this.photoOpacity,
    required this.tone,
    required this.medalScale,
    required this.parts,
    this.shape = MedalShape.rosette,
  });

  static const defaults = MedalLook(
    backdrop: MedalBackdrop.color,
    layout: MedalCardLayout.centered,
    photoOpacity: kMedalPhotoOpacityDefault,
    tone: kMedalToneDefault,
    medalScale: 1,
    parts: MedalCardParts.all,
  );

  Map<String, Object> toJson() => {
    'backdrop': backdrop.name,
    'layout': layout.name,
    'photo_opacity': photoOpacity,
    'tone': tone,
    'medal_scale': medalScale,
    'parts': parts.toJson(),
    'shape': shape.name,
  };

  /// อ่านของที่เก็บไว้ — ค่าที่ไม่รู้จัก/เสีย (เวอร์ชันเก่า/ใหม่กว่า) ตกไปใช้ค่าตั้งต้น
  /// ทีละช่อง ไม่ทิ้งทั้งชุด
  factory MedalLook.fromJson(Map<dynamic, dynamic> json) {
    double number(Object? v, double fallback, double min, double max) =>
        v is num ? v.toDouble().clamp(min, max) : fallback;

    T byName<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      return fallback;
    }

    final parts = json['parts'];

    return MedalLook(
      backdrop: byName(
        MedalBackdrop.values,
        json['backdrop'],
        defaults.backdrop,
      ),
      layout: byName(MedalCardLayout.values, json['layout'], defaults.layout),
      photoOpacity: number(json['photo_opacity'], defaults.photoOpacity, 0, 1),
      tone: number(json['tone'], defaults.tone, 0, 1),
      medalScale: number(
        json['medal_scale'],
        defaults.medalScale,
        kMedalScaleMin,
        kMedalScaleMax,
      ),
      parts: parts is Map ? MedalCardParts.fromJson(parts) : MedalCardParts.all,
      shape: byName(MedalShape.values, json['shape'], defaults.shape),
    );
  }
}

/// จำหน้าตาการ์ดเหรียญข้ามการแชร์แต่ละครั้ง — SharedPreferences ล้วน ๆ
/// เพราะเป็นรสนิยมของเครื่องนี้ ไม่ใช่ข้อมูลบัญชี (แบบเดียวกับ StoryLookStorage)
class MedalLookStorage {
  MedalLookStorage._();

  static final MedalLookStorage instance = MedalLookStorage._();

  static const _key = 'medal_look_v1';

  Future<MedalLook> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return MedalLook.defaults;

      final decoded = jsonDecode(raw);
      return decoded is Map ? MedalLook.fromJson(decoded) : MedalLook.defaults;
    } catch (_) {
      return MedalLook.defaults;
    }
  }

  Future<void> write(MedalLook look) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(look.toJson()));
    } catch (_) {
      // จำไม่ได้ก็แค่เริ่มที่ค่าตั้งต้นครั้งหน้า
    }
  }
}
