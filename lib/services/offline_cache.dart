import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight JSON-blob cache backed by SharedPreferences.
///
/// Entries are namespaced ("public", "account") so a logout can wipe only
/// the account-scoped portion. Each write is debounced to coalesce bursts
/// (e.g. several setters firing during a single API round trip).
///
/// สองข้อจำกัดที่ต้องไม่ลืม เพราะที่เก็บข้างล่างคือ SharedPreferences/NSUserDefaults
/// ไม่ใช่ฐานข้อมูล:
///
///   1. มันอ่านทั้งไฟล์เข้าหน่วยความจำและ "เขียนทั้งไฟล์ใหม่" ทุกครั้งที่บันทึก
///      เพราะฉะนั้นการเขียนทับทุกคีย์ทุกรอบ (ซึ่งเป็นพฤติกรรมเดิมของ [flush])
///      แพงขึ้นเรื่อย ๆ ตามของที่สะสมไว้ ตอนนี้จึงเขียนเฉพาะคีย์ที่เปลี่ยนจริง
///   2. ไม่มีใครมาไล่เก็บกวาดให้ คีย์ที่งอกได้เรื่อย ๆ อย่าง `booking.<ref>`
///      ต้องมีเพดานของตัวเอง — ดู [_boundedPrefixes]
class OfflineCache {
  OfflineCache._();
  static final OfflineCache instance = OfflineCache._();

  static const _prefix = 'offline_cache_v1.';
  static const _accountPrefix = '${_prefix}account.';
  static const _publicPrefix = '${_prefix}public.';

  /// เพดานจำนวนรายการของคีย์ที่งอกตามการใช้งาน
  ///
  /// `booking.<ref>` เพิ่มหนึ่งรายการต่อหนึ่งใบจอง และเป็น payload ที่อ้วนที่สุด
  /// ในแอป ส่วน `tripday_*` เพิ่มหนึ่งชุดต่อหนึ่งรอบเดินทาง เดิมทั้งสองกลุ่มนี้
  /// ไม่เคยถูกลบจนกว่าจะออกจากระบบ — ลูกค้าที่เดินทางกับเรามาสองปีจึงต้องถอด
  /// รหัสใบจองเก่าทุกใบใหม่ทุกครั้งที่เปิดแอป ทั้งที่ไม่มีหน้าจอไหนอ่านมันแล้ว
  ///
  /// ตัวเลขเลือกให้ครอบ "ทริปที่ยังเกี่ยวข้องอยู่" ได้สบาย ๆ ของที่ถูกทิ้งไป
  /// ดึงใหม่ได้เสมอเมื่อมีสัญญาณ
  static const Map<String, int> _boundedPrefixes = {
    'booking.': 12,
    'itinerary.': 8,
    'trip_progress.': 12,
    'tripday_announcements.': 8,
    'tripday_pack.': 8,
    'sos_contacts.': 8,
  };

  final Map<String, dynamic> _public = {};
  final Map<String, dynamic> _account = {};

  /// คีย์เต็ม (พร้อม prefix) ที่ค่าในหน่วยความจำยังไม่ตรงกับที่เขียนลงเครื่อง
  final Set<String> _dirty = {};

  /// คีย์เต็มที่ต้องลบออกจากเครื่อง — เดิมการเขียนค่า null ลบแค่ในหน่วยความจำ
  /// ของบนเครื่องจึงค้างอยู่แล้วฟื้นกลับมาเองตอน [load] รอบถัดไป
  final Set<String> _stale = {};

  bool _loaded = false;
  Timer? _flushTimer;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        final name = key.startsWith(_accountPrefix)
            ? key.substring(_accountPrefix.length)
            : key.startsWith(_publicPrefix)
            ? key.substring(_publicPrefix.length)
            : null;
        if (name == null) continue;
        if (key.startsWith(_accountPrefix)) {
          _account[name] = decoded;
        } else {
          _public[name] = decoded;
        }
      } catch (e) {
        debugPrint('OfflineCache decode error for $key: $e');
      }
    }
    _loaded = true;
    _pruneOverflow();
  }

  T? readPublic<T>(String key) {
    final value = _public[key];
    if (value is T) return value;
    return null;
  }

  T? readAccount<T>(String key) {
    final value = _account[key];
    if (value is T) return value;
    return null;
  }

  void writePublic(String key, Object? value) =>
      _write(_publicPrefix, _public, key, value);

  void writeAccount(String key, Object? value) =>
      _write(_accountPrefix, _account, key, value);

  void _write(
    String prefix,
    Map<String, dynamic> store,
    String key,
    Object? value,
  ) {
    final prefKey = '$prefix$key';
    if (value == null) {
      store.remove(key);
      _dirty.remove(prefKey);
      _stale.add(prefKey);
    } else {
      // ลบก่อนใส่ใหม่ เพื่อให้คีย์ที่เพิ่งถูกแตะไปอยู่ท้ายสุด — ลำดับของ Map
      // คือลำดับที่ [_trim] ใช้เลือกว่าจะทิ้งอันไหน
      store.remove(key);
      store[key] = value;
      _stale.remove(prefKey);
      _dirty.add(prefKey);
      _trim(prefix, store, key);
    }
    _scheduleFlush();
  }

  /// ตัดรายการเก่าสุดของกลุ่มที่มีเพดานทิ้ง หลังเพิ่งเขียนคีย์ในกลุ่มนั้นเข้าไป
  void _trim(String prefix, Map<String, dynamic> store, String writtenKey) {
    for (final bound in _boundedPrefixes.entries) {
      if (!writtenKey.startsWith(bound.key)) continue;
      final keys = store.keys
          .where((k) => k.startsWith(bound.key))
          .toList(growable: false);
      for (var i = 0; i < keys.length - bound.value; i++) {
        store.remove(keys[i]);
        final prefKey = '$prefix${keys[i]}';
        _dirty.remove(prefKey);
        _stale.add(prefKey);
      }
      return;
    }
  }

  /// เก็บกวาดของที่สะสมมาจากเวอร์ชันก่อนหน้า ตอนโหลดครั้งแรก
  ///
  /// ลำดับที่ได้จาก `prefs.getKeys()` ไม่ได้เรียงตามเวลา รอบนี้จึงเลือกทิ้ง
  /// แบบไม่เจาะจง — ยอมได้ เพราะสิ่งที่ยังต้องใช้จริงจะถูกดึงกลับมาเองโดย
  /// `TripDayPack` ทันทีที่มีสัญญาณ ส่วนรอบต่อ ๆ ไปลำดับจะถูกต้องตาม [_write]
  void _pruneOverflow() {
    for (final bound in _boundedPrefixes.entries) {
      for (final entry in [
        (_publicPrefix, _public),
        (_accountPrefix, _account),
      ]) {
        final (prefix, store) = entry;
        final keys = store.keys
            .where((k) => k.startsWith(bound.key))
            .toList(growable: false);
        for (var i = 0; i < keys.length - bound.value; i++) {
          store.remove(keys[i]);
          _stale.add('$prefix${keys[i]}');
        }
      }
    }
    if (_stale.isNotEmpty) _scheduleFlush();
  }

  Future<void> clearAccount() async {
    _account.clear();
    _dirty.removeWhere((k) => k.startsWith(_accountPrefix));
    _stale.removeWhere((k) => k.startsWith(_accountPrefix));
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_accountPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  Future<void> flush() async {
    _flushTimer?.cancel();
    if (_dirty.isEmpty && _stale.isEmpty) return;

    // ถ่ายคิวออกมาก่อนเริ่มเขียน — ระหว่าง await มีการเขียนรอบใหม่เข้ามาได้
    // และของรอบหน้าต้องไม่ถูกล้างไปพร้อมกับรอบนี้
    final dirty = _dirty.toList(growable: false);
    final stale = _stale.toList(growable: false);
    _dirty.clear();
    _stale.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final prefKey in stale) {
        await prefs.remove(prefKey);
      }
      for (final prefKey in dirty) {
        final value = _valueOf(prefKey);
        // ถูกลบไปแล้วหลังจากเข้าคิว — ตัวลบเข้าคิว _stale ของมันเองไว้แล้ว
        if (value == null) continue;
        await prefs.setString(prefKey, jsonEncode(value));
      }
    } catch (e) {
      debugPrint('OfflineCache flush error: $e');
      // เขียนไม่สำเร็จ — เอากลับเข้าคิวไว้ลองใหม่รอบหน้า ไม่ใช่ทิ้งเงียบ ๆ
      // แล้วปล่อยให้ของบนเครื่องไม่ตรงกับที่แอปคิดว่าบันทึกไปแล้ว
      _dirty.addAll(dirty);
      _stale.addAll(stale);
    }
  }

  Object? _valueOf(String prefKey) {
    if (prefKey.startsWith(_accountPrefix)) {
      return _account[prefKey.substring(_accountPrefix.length)];
    }
    if (prefKey.startsWith(_publicPrefix)) {
      return _public[prefKey.substring(_publicPrefix.length)];
    }
    return null;
  }

  /// คืนสถานะให้เหมือนเพิ่งเปิดแอป — มีไว้ให้เทสต์เท่านั้น เพราะคลาสนี้เป็น
  /// singleton ที่อยู่ข้ามเทสต์ด้วยกัน
  @visibleForTesting
  void resetForTest() {
    _flushTimer?.cancel();
    _public.clear();
    _account.clear();
    _dirty.clear();
    _stale.clear();
    _loaded = false;
  }
}
