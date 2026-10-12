import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
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

  /// ผู้ใช้ไม่ให้สิทธิ์บันทึกลงคลังรูป — ต้องไปเปิดในตั้งค่าเอง
  galleryDenied,

  /// เครื่องเต็ม บันทึกรูปไม่ลง
  galleryFull,
}

/// ข้อความแจ้งผู้ใช้ตามสาเหตุ — ทุกหน้าที่บันทึก/แชร์การ์ดใช้ชุดเดียวกัน
String shareCardFailureMessage(ShareCardFailure reason, {bool saving = false}) {
  return switch (reason) {
    ShareCardFailure.galleryDenied =>
      'แอปยังไม่ได้รับอนุญาตให้บันทึกรูป — เปิดสิทธิ์ "รูปภาพ" ในตั้งค่าของเครื่อง',
    ShareCardFailure.galleryFull => 'พื้นที่ในเครื่องเต็ม บันทึกรูปไม่ได้',
    _ =>
      saving
          ? 'บันทึกรูปไม่สำเร็จ ลองใหม่อีกครั้ง'
          : 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง',
  };
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
///
/// คืน true เมื่อระบบยืนยันว่าผู้ใช้เลือกแอปปลายทางแล้วจริง ๆ — กดปิด share
/// sheet ของระบบ หรือระบบบอกไม่ได้ (บาง Android) ได้ false ผู้เรียกที่จะปิดหน้า
/// ตัวเองหลังแชร์จึงไม่ปิดใส่หน้าคนที่ยังไม่ได้แชร์
Future<bool> shareWidgetAsPng({
  required GlobalKey boundaryKey,
  required String fileName,
  String? text,
  double pixelRatio = kShareCardPixelRatio,
}) async {
  final bytes = await renderWidgetAsPng(
    boundaryKey: boundaryKey,
    pixelRatio: pixelRatio,
  );

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);

  final result = await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: text),
  );

  return result.status == ShareResultStatus.success;
}

/// แปลงซับทรีใต้ [boundaryKey] เป็นไบต์ PNG — ทางเดียวที่ทั้งแชร์และบันทึกใช้
/// จึงได้ภาพละเอียดเท่ากันทุกทาง
Future<Uint8List> renderWidgetAsPng({
  required GlobalKey boundaryKey,
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

  return bytes.buffer.asUint8List();
}

/// บันทึกการ์ดลงคลังรูปของเครื่อง (ไม่ผ่าน share sheet)
///
/// คนที่จะแปะสติกเกอร์ใน IG Story ต้องมีรูปอยู่ในคลังก่อน (สติกเกอร์ → รูปภาพ)
/// และ share sheet ของ Android หลายรุ่นไม่มีปุ่ม "บันทึกรูป" ให้กด
///
/// ไม่ใส่อัลบั้ม: บน iOS การสร้างอัลบั้มต้องขอสิทธิ์อ่านคลังรูปทั้งหมด ส่วนการ
/// เพิ่มรูปอย่างเดียวขอแค่สิทธิ์ "เพิ่มรูป" ซึ่งคนยอมกดง่ายกว่ามาก
///
/// โยน [ShareCardException] เมื่อทำไม่สำเร็จ
Future<void> saveWidgetToGallery({
  required GlobalKey boundaryKey,
  required String fileName,
  double pixelRatio = kShareCardPixelRatio,
}) async {
  final bytes = await renderWidgetAsPng(
    boundaryKey: boundaryKey,
    pixelRatio: pixelRatio,
  );

  try {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      throw const ShareCardException(ShareCardFailure.galleryDenied);
    }

    // gal ใส่นามสกุลจากชนิดไฟล์ให้เอง — ส่งชื่อเปล่า ๆ ไม่งั้นได้ .png.png
    final name = fileName.replaceAll(RegExp(r'\.png$'), '');
    await Gal.putImageBytes(bytes, name: name);
  } on GalException catch (e) {
    throw ShareCardException(switch (e.type) {
      GalExceptionType.accessDenied => ShareCardFailure.galleryDenied,
      GalExceptionType.notEnoughSpace => ShareCardFailure.galleryFull,
      _ => ShareCardFailure.encodeFailed,
    });
  }
}
