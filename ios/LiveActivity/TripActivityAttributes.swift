import ActivityKit
import Foundation

/// สัญญาระหว่างเซิร์ฟเวอร์ ↔ แอป ↔ วิดเจ็ต ของการ์ด "วันเดินทาง"
///
/// ไฟล์นี้อยู่ในทั้งสองเป้าหมาย (Runner กับ LiveActivityExtension) โดยตั้งใจ —
/// ทั้งคู่ต้องถอดรหัส struct ตัวเดียวกันเป๊ะ ๆ
///
/// ⚠️ ชื่อฟิลด์ใน `ContentState` ต้องตรงกับที่ `TripActivityService::contentState()`
/// ฝั่ง Laravel ส่งมา (camelCase) ถ้าไม่ตรงแม้แต่ตัวเดียว APNs จะตอบ 200 ตามปกติ
/// แต่ iOS ถอดรหัสไม่ผ่านเงียบ ๆ แล้วการ์ดจะค้างข้อมูลเดิมไว้โดยไม่มี error ให้เห็น
@available(iOS 16.2, *)
struct TripActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    /// countdown | preparing | enroute | approaching | arriving | arrived | onboard | ended
    var stage: String
    /// บรรทัดใหญ่ — "รถถึงใน 8 นาที"
    var headline: String
    /// บรรทัดรอง — "กำลังมาที่จุดรับ ปั๊ม ปตท. รังสิต"
    var detail: String
    var etaMinutes: Int?
    /// 0..1 สำหรับแถบความคืบหน้า (ก่อนรถถึง = รถวิ่งมาใกล้แค่ไหน)
    var progress: Double
    var pickupName: String?
    var vehicleLabel: String?
    var departsAt: String?
    var updatedAt: String
  }

  /// ค่าที่ไม่เปลี่ยนตลอดอายุการ์ด
  var bookingRef: String
  var tripTitle: String
  var scheduleId: Int
}
