import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../providers/app_provider.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'offline_cache.dart';

/// SOS ที่ยังส่งไม่ออก — เก็บไว้บนเครื่องแล้วส่งเองเมื่อสัญญาณกลับมา
///
/// เดิม [AppProvider.triggerSos] ลองใหม่สี่ครั้งในราว 14 วินาทีแล้วยอมแพ้
/// ขึ้น SnackBar ให้กด "ลองอีกครั้ง" เอง ซึ่งแปลว่าถ้าคนกดอยู่ในจุดอับสัญญาณ
/// — ซึ่งคือสถานการณ์ปกติของทริปเดินป่า ไม่ใช่กรณีพิเศษ — สัญญาณขอความช่วยเหลือ
/// นั้นหายไปเฉย ๆ พร้อมกับความเชื่อของผู้กดว่า "ส่งไปแล้ว"
///
/// ตัวนี้รับไม้ต่อ: เก็บคำขอลง [OfflineCache] แล้วพยายามส่งใหม่ทุกครั้งที่
/// สัญญาณกลับมา เปิดแอปใหม่ หรือกลับเข้าแอป จนกว่าจะสำเร็จหรือเกินอายุ
///
/// ข้อจำกัดที่ต้องพูดตรง ๆ กับผู้ใช้ในหน้าจอ: **คิวเดินเฉพาะตอนแอปทำงานอยู่**
/// ยังไม่มี background task บน iOS ฉะนั้นข้อความในแอปต้องไม่สัญญาว่าจะส่งให้เอง
/// แม้ปิดแอป — ต้องบอกว่า "เปิดแอปค้างไว้" เพราะนั่นคือสิ่งที่มันทำได้จริง
class SosOutbox {
  SosOutbox._();
  static final SosOutbox instance = SosOutbox._();

  static const _key = 'sos_outbox';

  /// เกินเท่านี้ถือว่าหมดอายุ ทิ้งจากคิว — ตรงกับ MAX_BACKDATE_HOURS ฝั่ง
  /// เซิร์ฟเวอร์ ซึ่งจะปฏิเสธ occurred_at ที่เก่ากว่านี้อยู่แล้ว การเก็บต่อจึงมี
  /// แต่จะทำให้ผู้ใช้เห็นแถบ "ยังส่งไม่สำเร็จ" ค้างไปตลอดกาล
  static const Duration maxAge = Duration(hours: 48);

  /// เว้นระยะระหว่างการพยายามส่งแต่ละรอบ — กันไม่ให้สัญญาณที่ติด ๆ ดับ ๆ
  /// (ปกติของบนดอย) ยิงคำขอรัวจนแบตหมดเร็วกว่าเดิม
  static const Duration minRetryInterval = Duration(seconds: 20);

  /// จำนวนรายการค้างที่แสดงผลอยู่ — หน้าจอฟังค่านี้เพื่อขึ้น/ปิดแถบเตือน
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  AppProvider? _app;
  bool _flushing = false;
  DateTime? _lastAttempt;
  VoidCallback? _connectivityListener;

  /// ผูกกับ provider หนึ่งตัวและเริ่มเฝ้าสัญญาณ — เรียกครั้งเดียวตอนแอปเริ่ม
  void attach(AppProvider app) {
    _app = app;
    _refreshCount();

    if (_connectivityListener != null) return;

    _connectivityListener = () {
      if (ConnectivityService.instance.isOnline.value) {
        unawaited(flush());
      }
    };
    ConnectivityService.instance.isOnline.addListener(_connectivityListener!);
  }

  void detach() {
    if (_connectivityListener != null) {
      ConnectivityService.instance.isOnline.removeListener(
        _connectivityListener!,
      );
      _connectivityListener = null;
    }
    _app = null;
  }

  /// โทเคนกันซ้ำที่ผูกกับ "การกดหนึ่งครั้ง" และคงเดิมตลอดอายุของรายการในคิว
  ///
  /// เซิร์ฟเวอร์ใช้ค่านี้ตัดสินว่าคำขอที่มาถึงสองรอบคือเหตุเดียวกัน — สำคัญเพราะ
  /// คิวอาจถูกส่งซ้ำหลังผู้ใช้ปิดแอปแล้วเปิดใหม่ ซึ่งพ้นหน้าต่างกันซ้ำ 2 นาที
  /// ของเซิร์ฟเวอร์ไปแล้ว
  static String newToken() {
    final rand = Random();
    final suffix = List.generate(
      8,
      (_) => rand.nextInt(16).toRadixString(16),
    ).join();
    return 'sos-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  /// เก็บ SOS ที่ส่งไม่ผ่านลงคิว
  Future<void> enqueue({
    required int scheduleId,
    required String clientToken,
    required DateTime occurredAt,
    double? latitude,
    double? longitude,
    String? message,
    String? photoPath,
  }) async {
    final items = _read();

    // กดซ้ำด้วยโทเคนเดิม (เช่นผู้ใช้กด "ลองอีกครั้ง") ต้องไม่กลายเป็นสองรายการ
    items.removeWhere((item) => item['client_token'] == clientToken);

    items.add({
      'client_token': clientToken,
      'schedule_id': scheduleId,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'message': message,
      // รูปไม่ถูกส่งตามในรอบ retry: ไฟล์ชั่วคราวของ image_picker อาจถูกระบบลบ
      // ไปแล้วตอนคิวเดิน และ SOS ที่ไปถึงช้าเพราะรอรูปอัปโหลดบน EDGE แย่กว่า
      // SOS ที่ไปถึงโดยไม่มีรูป — เก็บ path ไว้เพื่อบอกผู้ใช้ว่ารูปไม่ได้ไปด้วย
      'photo_path': photoPath,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    });

    OfflineCache.instance.writeAccount(_key, items);
    await OfflineCache.instance.flush();
    _refreshCount();
  }

  /// รายการที่ยังค้างอยู่ (ตัดของหมดอายุออกแล้ว)
  List<Map<String, dynamic>> pending() {
    final items = _read();
    final fresh = items.where(_isFresh).toList();

    if (fresh.length != items.length) {
      OfflineCache.instance.writeAccount(_key, fresh);
      unawaited(OfflineCache.instance.flush());
    }

    return fresh;
  }

  /// พยายามส่งทุกรายการที่ค้าง — เรียกได้บ่อยเท่าที่ต้องการ ตัวมันกันซ้อนเอง
  ///
  /// คืนจำนวนรายการที่ส่งสำเร็จในรอบนี้
  Future<int> flush({bool force = false}) async {
    final app = _app;
    if (app == null || !app.isLoggedIn || _flushing) return 0;

    final items = pending();
    if (items.isEmpty) {
      _refreshCount();
      return 0;
    }

    if (!force && _lastAttempt != null) {
      final since = DateTime.now().difference(_lastAttempt!);
      if (since < minRetryInterval) return 0;
    }

    _flushing = true;
    _lastAttempt = DateTime.now();
    var sent = 0;

    try {
      for (final item in List<Map<String, dynamic>>.from(items)) {
        final scheduleId = item['schedule_id'] as int? ?? 0;
        final token = item['client_token']?.toString() ?? '';
        if (scheduleId <= 0 || token.isEmpty) {
          _remove(token);
          continue;
        }

        try {
          await app.triggerSos(
            scheduleId: scheduleId,
            latitude: (item['latitude'] as num?)?.toDouble(),
            longitude: (item['longitude'] as num?)?.toDouble(),
            message: item['message']?.toString(),
            occurredAt: DateTime.tryParse('${item['occurred_at']}'),
            clientToken: token,
            // คิวมีกลไก retry ของตัวเองอยู่แล้ว ไม่ต้องให้แต่ละรายการนั่งลอง
            // ซ้ำ 14 วินาทีจนรายการถัดไปไม่ได้คิว
            retry: false,
          );
          _remove(token);
          sent++;
        } catch (e) {
          // ยังส่งไม่ได้ — เก็บไว้รอบหน้า ยกเว้นกรณีที่เซิร์ฟเวอร์ปฏิเสธถาวร
          // (นอกช่วงทริป, ไม่มีสิทธิ์) ซึ่งลองอีกกี่ครั้งก็ได้คำตอบเดิม
          if (e is ApiException &&
              e.statusCode != null &&
              e.statusCode! >= 400 &&
              e.statusCode! < 500) {
            debugPrint('SosOutbox: dropping $token — ${e.statusCode}');
            _remove(token);
          } else {
            debugPrint('SosOutbox: $token still stuck — $e');
          }
        }
      }
    } finally {
      _flushing = false;
      await OfflineCache.instance.flush();
      _refreshCount();
    }

    return sent;
  }

  /// ล้างคิวทั้งหมด — ใช้ตอนออกจากระบบ
  Future<void> clear() async {
    OfflineCache.instance.writeAccount(_key, null);
    await OfflineCache.instance.flush();
    _refreshCount();
  }

  void _remove(String clientToken) {
    final items = _read()
      ..removeWhere((item) => item['client_token'] == clientToken);
    OfflineCache.instance.writeAccount(_key, items);
  }

  List<Map<String, dynamic>> _read() {
    final raw = OfflineCache.instance.readAccount<List>(_key);
    if (raw == null) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  bool _isFresh(Map<String, dynamic> item) {
    final occurred = DateTime.tryParse('${item['occurred_at']}');
    if (occurred == null) return false;
    return DateTime.now().toUtc().difference(occurred.toUtc()) < maxAge;
  }

  void _refreshCount() => pendingCount.value = _read().where(_isFresh).length;

  @visibleForTesting
  void resetForTest() {
    _app = null;
    _flushing = false;
    _lastAttempt = null;
    pendingCount.value = 0;
  }
}
