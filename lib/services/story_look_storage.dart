import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/trip_story_card.dart';

/// หน้าตาการ์ดสตอรี่ที่เจ้าของเลือกไว้ล่าสุด
///
/// จำเฉพาะ *รสนิยม* (สไตล์ ความชัดของรูป ชิ้นส่วนที่โชว์ รูปแบบวันที่ แนบลิงก์ไหม)
/// ส่วนคำที่พิมพ์ลงการ์ด (ชื่อทริป จุดหมาย ข้อความของคุณ) เป็นของทริปนั้น ๆ
/// จึงไม่จำ — ข้อความวันเกิดของทริปที่แล้วไม่ควรโผล่บนการ์ดทริปหน้า
@immutable
class StoryLook {
  final StoryStyle style;

  /// ความชัดของรูป 0–1 ดู [TripStoryCard.photoOpacity]
  final double photoOpacity;

  final StoryCardParts parts;

  final StoryDateFormat dateFormat;

  /// แนบลิงก์การ์ดสาธารณะ (/s/{token}) ไปกับคำบรรยายไหม — ปลายทางเปิดเผย
  /// ชื่อทริปกับวันเดินทาง คนที่ซ่อนวันที่บนการ์ดจึงอาจไม่อยากแนบ
  final bool includeLink;

  const StoryLook({
    required this.style,
    required this.photoOpacity,
    this.parts = StoryCardParts.all,
    this.dateFormat = StoryDateFormat.full,
    this.includeLink = true,
  });

  static const defaults = StoryLook(
    style: StoryStyle.classic,
    photoOpacity: kStoryPhotoOpacityDefault,
  );

  StoryLook copyWith({
    StoryStyle? style,
    double? photoOpacity,
    StoryCardParts? parts,
    StoryDateFormat? dateFormat,
    bool? includeLink,
  }) {
    return StoryLook(
      style: style ?? this.style,
      photoOpacity: photoOpacity ?? this.photoOpacity,
      parts: parts ?? this.parts,
      dateFormat: dateFormat ?? this.dateFormat,
      includeLink: includeLink ?? this.includeLink,
    );
  }

  Map<String, Object> toJson() => {
    'style': style.name,
    'photo_opacity': photoOpacity,
    'parts': parts.toJson(),
    'date_format': dateFormat.name,
    'include_link': includeLink,
  };

  /// ค่าที่ไม่รู้จัก/เสีย (รุ่นเก่า/ใหม่กว่า) ตกไปใช้ค่าตั้งต้นทีละช่อง ไม่ทิ้งทั้งชุด
  factory StoryLook.fromJson(Map<dynamic, dynamic> json) {
    final opacity = json['photo_opacity'];
    final parts = json['parts'];
    final link = json['include_link'];

    return StoryLook(
      style: StoryStyle.fromName(json['style']?.toString()),
      photoOpacity: opacity is num
          ? opacity.toDouble().clamp(0.0, 1.0)
          : kStoryPhotoOpacityDefault,
      parts: parts is Map ? StoryCardParts.fromJson(parts) : StoryCardParts.all,
      dateFormat: StoryDateFormat.fromName(json['date_format']?.toString()),
      includeLink: link is bool ? link : true,
    );
  }
}

/// จำหน้าตาการ์ดที่เลือกไว้ข้ามการแชร์แต่ละครั้ง
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

      return decoded is Map ? StoryLook.fromJson(decoded) : StoryLook.defaults;
    } catch (_) {
      return StoryLook.defaults;
    }
  }

  Future<void> write(StoryLook look) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(look.toJson()));
    } catch (_) {
      // จำไม่ได้ก็ไม่เป็นไร ครั้งหน้าแค่เริ่มที่ค่าตั้งต้น
    }
  }
}
