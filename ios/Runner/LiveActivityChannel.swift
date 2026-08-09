import ActivityKit
import Flutter
import Foundation

/// สะพานระหว่าง Flutter กับ ActivityKit
///
/// iOS ไม่ยอมให้เซิร์ฟเวอร์เปิด Live Activity ลอย ๆ — ต้องมีแอปเปิดให้ก่อนหนึ่งครั้ง
/// (หรือมี push-to-start token ซึ่งก็ต้องให้แอปส่งมาให้อยู่ดี) หน้าที่ของคลาสนี้จึง
/// มีสองอย่างเท่านั้น: เปิด/ปิดการ์ด และส่ง token กลับไปให้ฝั่ง Dart เอาไปฝากไว้ที่
/// เซิร์ฟเวอร์ หลังจากนั้นการ์ดจะอัปเดตเองผ่าน APNs โดยไม่ต้องพึ่งแอปอีกเลย
///
/// ตั้งใจไม่ทำ `update` จากฝั่งแอป: ถ้าทำ จะมีสองแหล่งที่เขียนการ์ดเดียวกัน แล้ว
/// เวลาที่ทั้งสองไม่ตรงกัน (แอปค้างข้อมูลเก่า) ผู้ใช้จะเห็นเลขกระพริบไปมา
enum LiveActivityChannel {
  private static let channelName = "luilaykhao/live_activity"

  private static var channel: FlutterMethodChannel?
  private static var tokenTasks: [String: Task<Void, Never>] = [:]
  private static var startTokenTask: Task<Void, Never>?

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "LuilaykhaoLiveActivity") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    self.channel = channel

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported":
        result(isSupported())
      case "start":
        start(arguments: call.arguments, result: result)
      case "endAll":
        endAll(result: result)
      case "activeTokens":
        activeTokens(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    observeStartToken()
  }

  private static func isSupported() -> Bool {
    guard #available(iOS 16.2, *) else { return false }
    return ActivityAuthorizationInfo().areActivitiesEnabled
  }

  /// เปิดการ์ดสำหรับใบจองหนึ่งใบ — ถ้าใบเดิมเปิดค้างอยู่แล้วก็คืนของเดิมไป ไม่เปิดซ้อน
  private static func start(arguments: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(FlutterError(code: "unsupported", message: "ต้องใช้ iOS 16.2 ขึ้นไป", details: nil))
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(FlutterError(code: "disabled", message: "ผู้ใช้ปิด Live Activities ไว้", details: nil))
      return
    }
    guard
      let args = arguments as? [String: Any],
      let bookingRef = args["bookingRef"] as? String,
      let stateMap = args["state"] as? [String: Any]
    else {
      result(FlutterError(code: "bad_args", message: "ข้อมูลไม่ครบ", details: nil))
      return
    }

    let attributes = TripActivityAttributes(
      bookingRef: bookingRef,
      tripTitle: args["tripTitle"] as? String ?? "ทริปของคุณ",
      scheduleId: args["scheduleId"] as? Int ?? 0
    )

    if let existing = Activity<TripActivityAttributes>.activities.first(where: {
      $0.attributes.bookingRef == bookingRef
    }) {
      observeToken(of: existing, bookingRef: bookingRef)
      result(payload(activityId: existing.id, pushToken: hex(existing.pushToken)))
      return
    }

    do {
      let activity = try Activity.request(
        attributes: attributes,
        content: .init(state: contentState(from: stateMap), staleDate: Date().addingTimeInterval(30 * 60)),
        pushType: .token
      )
      observeToken(of: activity, bookingRef: bookingRef)
      result(payload(activityId: activity.id, pushToken: hex(activity.pushToken)))
    } catch {
      result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
    }
  }

  private static func endAll(result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(nil)
      return
    }

    let activities = Activity<TripActivityAttributes>.activities
    Task {
      for activity in activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      await MainActor.run { result(nil) }
    }
  }

  /// token ของการ์ดที่เปิดค้างอยู่ตอนนี้ — แอปเรียกตอนเปิดขึ้นมาใหม่ เพื่อฝากซ้ำ
  /// เผื่อครั้งก่อนฝากไม่สำเร็จ (เน็ตหลุดตอนกดจอง)
  private static func activeTokens(result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result([])
      return
    }

    let tokens = Activity<TripActivityAttributes>.activities.map { activity in
      payload(
        activityId: activity.id,
        pushToken: hex(activity.pushToken),
        bookingRef: activity.attributes.bookingRef
      )
    }
    result(tokens)
  }

  // MARK: - Tokens

  /// สิ่งที่ส่งกลับไปฝั่ง Dart ต้องเป็น `[String: Any]` ที่ไม่มี Optional โผล่มาเป็น
  /// ค่าเด็ดขาด — FlutterStandardWriter เข้ารหัส `Optional.none` (ที่ถูกห่อเป็น
  /// `__SwiftValue`) ไม่ได้ แล้วมันไม่ได้โยน error ให้ Dart จับ แต่ abort ทั้ง
  /// โปรเซสทิ้ง ซึ่งผู้ใช้เห็นเป็น "จองเสร็จแล้วแอปเด้ง"
  ///
  /// เคสที่เจอจริงคือ `pushToken` — ตอน `request()` เพิ่งคืนค่า token ยังไม่ออก
  /// เสมอ (มันมาทีหลังทาง `pushTokenUpdates`) จึงเป็น nil แทบทุกครั้ง
  ///
  /// เปิดให้ internal เพื่อให้ `RunnerTests` ยืนยันได้ว่าไม่มี Optional หลุดเข้าไป
  static func payload(
    activityId: String,
    pushToken: String?,
    bookingRef: String? = nil
  ) -> [String: Any] {
    var payload: [String: Any] = ["activityId": activityId]
    if let bookingRef { payload["bookingRef"] = bookingRef }
    if let pushToken { payload["pushToken"] = pushToken }
    return payload
  }

  /// token ของ Activity ออกมาหลัง `request()` คืนค่าไปแล้วเสมอ (บางครั้งช้าเป็นวินาที)
  /// จึงต้องเฝ้าสตรีมไว้ ไม่ใช่อ่านครั้งเดียวตอนเปิด
  @available(iOS 16.2, *)
  private static func observeToken(of activity: Activity<TripActivityAttributes>, bookingRef: String) {
    tokenTasks[activity.id]?.cancel()
    tokenTasks[activity.id] = Task {
      for await tokenData in activity.pushTokenUpdates {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        await MainActor.run {
          channel?.invokeMethod(
            "onPushToken",
            arguments: [
              "bookingRef": bookingRef,
              "activityId": activity.id,
              "pushToken": token,
            ]
          )
        }
      }
    }
  }

  /// push-to-start token เป็นของแอปทั้งแอป ไม่ผูกกับการ์ดใบไหน — มันคือสิ่งที่ทำให้
  /// เซิร์ฟเวอร์เปิดการ์ดเองได้เช้าวันเดินทางโดยลูกค้าไม่ต้องเปิดแอปเลย (iOS 17.2+)
  private static func observeStartToken() {
    guard #available(iOS 17.2, *) else { return }

    startTokenTask?.cancel()
    startTokenTask = Task {
      for await tokenData in Activity<TripActivityAttributes>.pushToStartTokenUpdates {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        await MainActor.run {
          channel?.invokeMethod("onStartToken", arguments: ["startToken": token])
        }
      }
    }
  }

  @available(iOS 16.2, *)
  private static func hex(_ data: Data?) -> String? {
    guard let data else { return nil }
    return data.map { String(format: "%02x", $0) }.joined()
  }

  @available(iOS 16.2, *)
  private static func contentState(from map: [String: Any]) -> TripActivityAttributes.ContentState {
    TripActivityAttributes.ContentState(
      stage: map["stage"] as? String ?? "countdown",
      headline: map["headline"] as? String ?? "ทริปของคุณ",
      detail: map["detail"] as? String ?? "",
      etaMinutes: map["etaMinutes"] as? Int,
      progress: (map["progress"] as? NSNumber)?.doubleValue ?? 0,
      pickupName: map["pickupName"] as? String,
      vehicleLabel: map["vehicleLabel"] as? String,
      departsAt: map["departsAt"] as? String,
      updatedAt: map["updatedAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
    )
  }
}
