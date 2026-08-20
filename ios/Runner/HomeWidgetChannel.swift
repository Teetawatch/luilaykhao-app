import Flutter
import Foundation
import WidgetKit

/// สะพานระหว่าง Flutter กับ WidgetKit
///
/// วิดเจ็ตหน้าโฮมอ่านข้อมูลจาก App Group ไม่ได้ต่อเน็ตเอง หน้าที่ของคลาสนี้จึงมีแค่
/// สองอย่าง: รับ JSON จากฝั่ง Dart ไปวางไว้ที่ที่วิดเจ็ตอ่านได้ แล้วบอก WidgetKit
/// ให้วาดใหม่
///
/// ⚠️ ค่าที่ส่งกลับไปฝั่ง Dart ต้องไม่มี Optional โผล่มาเป็นค่าเด็ดขาด —
/// FlutterStandardWriter เข้ารหัส `Optional.none` (ที่ถูกห่อเป็น `__SwiftValue`)
/// ไม่ได้ แล้วมันไม่ได้โยน error ให้ Dart จับ แต่ abort ทั้งโปรเซสทิ้ง ซึ่งผู้ใช้เห็น
/// เป็น "แอปเด้งเฉย ๆ" (เคยเจอจริงกับ Live Activity — ดู [LiveActivityChannel.payload])
/// ที่นี่จึงส่งกลับได้แค่ `Bool` กับ `nil` เท่านั้น
enum HomeWidgetChannel {
  private static let channelName = "luilaykhao/home_widget"

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "LuilaykhaoHomeWidget") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "save":
        guard
          let args = call.arguments as? [String: Any],
          let json = args["json"] as? String,
          !json.isEmpty
        else {
          result(FlutterError(code: "bad_args", message: "ไม่มี json ที่จะเขียน", details: nil))
          return
        }
        // false = App Group ยังไม่ถูกเปิดให้บิลด์นี้ ฝั่ง Dart แค่บันทึก log
        // ไม่ต้องแสดงอะไรกับผู้ใช้ — วิดเจ็ตเป็นของประดับ ไม่ใช่ทางหลัก
        result(persist(json: json))

      case "clear":
        result(wipe())

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func persist(json: String) -> Bool {
    let written = HomeWidgetStore.write(json: json)
    if written {
      reload()
    }
    return written
  }

  private static func wipe() -> Bool {
    let cleared = HomeWidgetStore.clear()
    if cleared {
      reload()
    }
    return cleared
  }

  /// สั่งให้วิดเจ็ตทุกตัววาดใหม่จากข้อมูลที่เพิ่งเขียนไป
  ///
  /// iOS จำกัดจำนวนครั้งที่วิดเจ็ตวาดใหม่ต่อวัน ฝั่ง Dart จึงกันการเขียนซ้ำด้วย
  /// ข้อมูลเดิมไว้ก่อนแล้ว (ดู `HomeWidgetService._write`) — ที่นี่ยิงได้เลย
  private static func reload() {
    WidgetCenter.shared.reloadTimelines(ofKind: "TripCountdownWidget")
  }
}
