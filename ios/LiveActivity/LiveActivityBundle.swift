import SwiftUI
import WidgetKit

/// จุดเข้าของ widget extension
///
/// เป้าหมายนี้มีอยู่เพื่อ Live Activity อย่างเดียว (deployment target 16.2) — ยัง
/// ไม่มีวิดเจ็ตหน้าโฮม ถ้าจะเพิ่มทีหลังก็มาต่อในบันเดิลนี้ ไม่ต้องสร้างเป้าหมายใหม่
@main
struct LiveActivityBundle: WidgetBundle {
  var body: some Widget {
    TripActivityWidget()
  }
}
