import Flutter
import UIKit
import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  /// ค่าที่ส่งข้าม method channel ต้องผ่าน FlutterStandardMessageCodec ได้ทุกตัว
  ///
  /// ถ้ามี `Optional.none` หลุดเข้าไปในผลลัพธ์ (เช่น `["pushToken": someString?]`
  /// ซึ่ง Swift อนุมานชนิดเป็น `[String: String?]`) ตัวเข้ารหัสจะเจอ `__SwiftValue`
  /// ที่มันไม่รู้จัก แล้ว **abort ทั้งโปรเซส** — ไม่ใช่โยน error ให้ Dart จับ
  /// อาการที่ผู้ใช้เห็นคือจองเสร็จ การ์ดวันเดินทางขึ้นมา แล้วแอปเด้งทันที
  func testStartPayloadEncodesWhenPushTokenIsMissing() {
    // token ยังไม่ออกตอน Activity.request() คืนค่า — นี่คือเคสปกติ ไม่ใช่เคสขอบ
    let payload = LiveActivityChannel.payload(
      activityId: "692AEBAD-859B-4FBF-B503-E839EA65C99C",
      pushToken: nil
    )

    XCTAssertNil(payload["pushToken"], "ไม่มี token ก็ต้องไม่ใส่คีย์ ไม่ใช่ใส่ nil")
    XCTAssertEqual(payload.count, 1)

    let encoded = FlutterStandardMessageCodec.sharedInstance().encode(payload)
    XCTAssertNotNil(encoded)
  }

  func testPayloadCarriesTokenAndBookingRefWhenPresent() {
    let payload = LiveActivityChannel.payload(
      activityId: "activity-1",
      pushToken: "deadbeef",
      bookingRef: "LLK-20260810-0001"
    )

    XCTAssertEqual(payload["activityId"] as? String, "activity-1")
    XCTAssertEqual(payload["pushToken"] as? String, "deadbeef")
    XCTAssertEqual(payload["bookingRef"] as? String, "LLK-20260810-0001")

    let codec = FlutterStandardMessageCodec.sharedInstance()
    let roundTripped = codec.decode(codec.encode(payload)) as? [String: Any]
    XCTAssertEqual(roundTripped?["pushToken"] as? String, "deadbeef")
  }
}
