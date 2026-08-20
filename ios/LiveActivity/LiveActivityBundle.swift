import SwiftUI
import WidgetKit

/// จุดเข้าของ widget extension (deployment target 16.2)
///
/// สองอย่างที่คนละหน้าจอกัน แต่อยู่เป้าหมายเดียวกันเพราะเป็น widget extension ทั้งคู่:
///
///   [TripActivityWidget]  การ์ด "วันเดินทาง" บนหน้าจอล็อก/Dynamic Island — อัปเดต
///                         จาก APNs ตรง ๆ ระหว่างวันเดินทาง
///   [TripCountdownWidget] วิดเจ็ตนับถอยหลังบนหน้าโฮม — อ่าน snapshot ที่แอปเขียน
///                         ไว้ใน App Group ทำงานทุกวันที่ไม่ใช่วันเดินทาง
@main
struct LiveActivityBundle: WidgetBundle {
  var body: some Widget {
    TripActivityWidget()
    TripCountdownWidget()
  }
}
