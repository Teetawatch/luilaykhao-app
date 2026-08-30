import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// การ์ดรูปภาพที่ผู้ใช้แชร์ออกไปเอง (Trip Recap / Passport / การ์ดนับถอยหลัง)
/// ทุกใบใช้ทางเดียวกัน: [RepaintBoundary] → PNG → ไฟล์ชั่วคราว → share sheet
///
/// เดิมโค้ดชุดนี้ถูกก็อปไว้ในแต่ละหน้าจอ พอมีการ์ดใบที่สามก็ย้ายมารวมที่นี่
/// เพื่อให้ความละเอียดและการจัดการข้อผิดพลาดเหมือนกันหมด

/// ความละเอียดตอนแปลงเป็น PNG
///
/// 3.0 ทำให้การ์ดที่วาดด้วยหน่วย logical กลายเป็นภาพความละเอียดพอสำหรับสตอรี่
/// (การ์ด 360×640 → 1080×1920 ซึ่งเป็นขนาดที่ IG/FB ใช้พอดี)
const double kShareCardPixelRatio = 3.0;

/// ทำไมแชร์ไม่สำเร็จ — ผู้เรียกเอาไปตัดสินใจว่าจะขึ้นข้อความอะไร
enum ShareCardFailure {
  /// การ์ดยังไม่ถูกวาดลงจอ (ผู้ใช้กดเร็วกว่าเฟรมแรก) — ลองใหม่ได้
  notRendered,

  /// เข้ารหัส PNG หรือเขียนไฟล์ไม่ผ่าน
  encodeFailed,
}

class ShareCardException implements Exception {
  final ShareCardFailure reason;

  const ShareCardException(this.reason);

  @override
  String toString() => 'ShareCardException($reason)';
}

/// แปลงซับทรีใต้ [boundaryKey] เป็น PNG แล้วเปิด share sheet ของระบบ
///
/// [fileName] ควรไม่ซ้ำกันในแต่ละชนิดการ์ด เพราะไฟล์อยู่ในโฟลเดอร์ชั่วคราว
/// ร่วมกันและถูกเขียนทับทุกครั้งที่แชร์
///
/// โยน [ShareCardException] เมื่อทำไม่สำเร็จ เพื่อให้หน้าจอที่เรียกเลือกเองว่า
/// จะแจ้งผู้ใช้ด้วย snackbar แบบไหน
Future<void> shareWidgetAsPng({
  required GlobalKey boundaryKey,
  required String fileName,
  String? text,
  double pixelRatio = kShareCardPixelRatio,
}) async {
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

  if (boundary == null) {
    throw const ShareCardException(ShareCardFailure.notRendered);
  }

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final ByteData? bytes;

  try {
    bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  } finally {
    // ภาพดิบกินหน่วยความจำหลายสิบเมกะที่ pixelRatio 3.0 — ปล่อยทันทีที่เข้ารหัส
    // เสร็จ ไม่รอ GC เพราะการ์ดใบต่อไปอาจถูกกดแชร์ทันที
    image.dispose();
  }

  if (bytes == null) {
    throw const ShareCardException(ShareCardFailure.encodeFailed);
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes.buffer.asUint8List());

  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: text),
  );
}
