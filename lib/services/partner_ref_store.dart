import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// โค้ดพาร์ทเนอร์ช่วยขายที่ลูกค้าเปิดลิงก์เข้ามา (`?partner=CODE`) หรือพิมพ์เอง
///
/// เก็บในเครื่อง 30 วัน — ลูกค้ามักเปิดลิงก์วันนี้แล้วกลับมาจองอีกหลายวันต่อมา
/// ส่งไปกับ POST /bookings เป็น `partner_code` เซิร์ฟเวอร์ตัดสินว่าผูกได้ไหม
/// (โค้ดผิด/หยุดใช้/จองให้ตัวเอง แค่ไม่ผูก การจองไม่ล้ม) — กติกาเดียวกับเว็บ
/// `resources/js/lib/partnerRef.js` และ LIFF
class PartnerRef {
  final String code;

  /// `link` = มาจากลิงก์ · `code` = ลูกค้าพิมพ์เอง
  final String source;

  const PartnerRef(this.code, this.source);
}

class PartnerRefStore {
  static const String _key = 'partner_ref_v1';
  static const Duration _maxAge = Duration(days: 30);

  static String normalize(String? code) {
    final cleaned = (code ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final upper = cleaned.toUpperCase();
    return upper.length > 20 ? upper.substring(0, 20) : upper;
  }

  static Future<void> remember(String? code, {String source = 'link'}) async {
    final normalized = normalize(code);
    if (normalized.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'code': normalized,
          'source': source == 'code' ? 'code' : 'link',
          'at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('[PartnerRef] save failed: $e');
    }
  }

  static Future<PartnerRef?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final at = DateTime.tryParse('${decoded['at']}');
      final code = normalize('${decoded['code'] ?? ''}');
      if (code.isEmpty ||
          at == null ||
          DateTime.now().difference(at) > _maxAge) {
        await forget();
        return null;
      }
      return PartnerRef(code, decoded['source'] == 'code' ? 'code' : 'link');
    } catch (_) {
      return null;
    }
  }

  static Future<void> forget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
