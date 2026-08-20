import Foundation

/// สัญญาข้อมูลของวิดเจ็ตหน้าโฮม ระหว่างแอป ↔ วิดเจ็ต
///
/// ไฟล์นี้อยู่ในทั้งสองเป้าหมาย (Runner กับ LiveActivityExtension) โดยตั้งใจ — แอป
/// เป็นฝ่ายเขียน วิดเจ็ตเป็นฝ่ายอ่าน ทั้งคู่ต้องใช้ชื่อ App Group และคีย์เดียวกันเป๊ะ
/// ถ้าแยกเป็นสองไฟล์ วันหนึ่งจะพิมพ์ไม่ตรงกันแล้ววิดเจ็ตจะว่างเปล่าโดยไม่มี error
/// ให้เห็นเลย
///
/// ⚠️ ชื่อฟิลด์ต้องตรงกับที่ `HomeWidgetService` ฝั่ง Laravel ส่งมา (snake_case →
/// camelCase ด้วย `.convertFromSnakeCase`) ถ้าไม่ตรงแม้แต่ตัวเดียว การถอดรหัสจะล้ม
/// ทั้งก้อนแล้ววิดเจ็ตจะขึ้นสถานะว่าง
enum HomeWidgetStore {
  /// ต้องตรงกับที่ประกาศไว้ใน Runner.entitlements และ
  /// LiveActivityExtension.entitlements — และต้องเปิด App Group นี้ไว้ใน
  /// Apple Developer portal ด้วย ไม่งั้น `UserDefaults(suiteName:)` คืน nil เงียบ ๆ
  static let appGroup = "group.com.luilaykhao.app"

  static let snapshotKey = "home_widget_snapshot"

  /// ต้องตรงกับ `HomeWidgetService::SNAPSHOT_VERSION` ฝั่ง Laravel และ
  /// `HomeWidgetSnapshot.contractVersion` ฝั่ง Dart
  static let contractVersion = 1

  /// nil เมื่อ App Group ยังไม่ถูกเปิดให้บิลด์นี้ — ทุกผู้เรียกต้องรับ nil ได้
  /// โดยไม่ล้ม เพราะนี่คือสภาพของบิลด์ที่ profile ยังไม่มี capability
  private static var store: UserDefaults? {
    UserDefaults(suiteName: appGroup)
  }

  /// เขียน snapshot ก้อนใหม่ (JSON ดิบ ตามที่ฝั่ง Dart ประกอบมา)
  ///
  /// ตั้งใจไม่แกะ JSON ตรงนี้: ฝั่ง Dart ล้างชนิดข้อมูลมาแล้ว และการแกะซ้ำที่นี่
  /// หมายถึงมีสองที่ที่ต้องแก้ทุกครั้งที่สัญญาเปลี่ยน
  @discardableResult
  static func write(json: String) -> Bool {
    guard let store else { return false }
    store.set(json, forKey: snapshotKey)
    return true
  }

  @discardableResult
  static func clear() -> Bool {
    guard let store else { return false }
    store.removeObject(forKey: snapshotKey)
    return true
  }

  /// snapshot ล่าสุดที่แอปเขียนไว้ — nil เมื่อยังไม่มี, อ่านไม่ได้, หรือคนละเวอร์ชัน
  static func read() -> HomeWidgetSnapshot? {
    guard let json = store?.string(forKey: snapshotKey) else { return nil }
    return decode(json)
  }

  /// แยกออกมาจาก [read] เพื่อให้ทดสอบได้โดยไม่ต้องมี App Group
  ///
  /// นี่คือจุดที่สัญญาระหว่าง Dart กับ Swift พังได้เงียบที่สุด — ชื่อฟิลด์เพี้ยนตัวเดียว
  /// ก็คืน nil ทั้งก้อนแล้ววิดเจ็ตขึ้นสถานะว่างโดยไม่มี error ให้เห็น
  /// (`ios/scripts/check_home_widget_contract.swift` ยิง JSON จริงจากฝั่ง Dart เข้ามาที่นี่)
  static func decode(_ json: String) -> HomeWidgetSnapshot? {
    guard let data = json.data(using: .utf8) else { return nil }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    guard let snapshot = try? decoder.decode(HomeWidgetSnapshot.self, from: data) else {
      return nil
    }

    // เวอร์ชันที่บิลด์นี้ไม่รู้จัก = วาดไปก็เสี่ยงแปลผิด ยอมขึ้นสถานะว่างดีกว่า
    guard snapshot.version == contractVersion else { return nil }

    return snapshot
  }
}

struct HomeWidgetSnapshot: Codable {
  let version: Int
  let generatedAt: String?
  let trip: HomeWidgetTrip?
  let payment: HomeWidgetPayment?

  var isEmpty: Bool { trip == nil && payment == nil }
}

struct HomeWidgetTrip: Codable {
  let bookingRef: String
  let tripTitle: String

  /// "2026-09-05" — วิดเจ็ตนับ "อีกกี่วัน" ใหม่จากค่านี้ทุกครั้งที่วาด
  let departureDate: String?

  /// วันกลับ — เลยวันนี้ไปแล้วถือว่าก้อนนี้หมดอายุ วิดเจ็ตเก็บการ์ดออกเอง
  let validUntil: String?

  let dateLabel: String
  let departTime: String?
  let countdownDays: Int
  let headline: String
  let detail: String
  let stage: String
  let etaMinutes: Int?
  let progress: Double

  /// true = อยู่ในช่วงที่การ์ดหน้าจอล็อกทำงาน ให้ใช้ [headline] ที่เซิร์ฟเวอร์เขียนมา
  /// ทั้งดุ้น (มันรู้เรื่องรถและ ETA ซึ่งวิดเจ็ตไม่รู้)
  let isLive: Bool
}

struct HomeWidgetPayment: Codable {
  let bookingRef: String
  let tripTitle: String
  let label: String
  let amount: Double
  let amountLabel: String
  let dueDate: String?
  let dueLabel: String
  let daysLeft: Int?
  let overdue: Bool
  let slipPending: Bool
}

/// การนับวันของฝั่งวิดเจ็ต
///
/// นี่คือที่เดียวที่ยอมให้ฝั่ง native คิดเลขเอง เพราะวิดเจ็ตต้องนับถอยหลังถูกต้อง
/// ข้ามคืนโดยไม่มีเน็ตและไม่มีใครเปิดแอป (ถ้ารอค่าจากเซิร์ฟเวอร์ คนที่ไม่เปิดแอป
/// สามวันจะเห็น "อีก 17 วัน" ค้างอยู่ทั้งสามวัน)
///
/// ⚠️ ปฏิทินและ locale ต้องกำหนดเองทั้งคู่ เครื่องคนไทยจำนวนมากตั้งปฏิทินเป็นพุทธ
/// ศักราช ถ้าใช้ค่าเริ่มต้นของเครื่อง DateFormatter จะอ่าน "2026-09-05" เป็นปี พ.ศ.
/// แล้วนับถอยหลังผิดไปห้าร้อยกว่าปี
enum HomeWidgetClock {
  static let bangkok: TimeZone =
    TimeZone(identifier: "Asia/Bangkok") ?? TimeZone(secondsFromGMT: 7 * 3600) ?? .current

  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = bangkok
    return calendar
  }

  private static let dayParser: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = bangkok
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  static func day(from string: String?) -> Date? {
    guard let string, !string.isEmpty else { return nil }
    return dayParser.date(from: string)
  }

  /// จำนวนวันเต็มจาก "วันนี้ที่กรุงเทพ" ถึงวันเป้าหมาย (ติดลบ = ผ่านไปแล้ว)
  static func daysUntil(_ dateString: String?, from now: Date = Date()) -> Int? {
    guard let target = day(from: dateString) else { return nil }
    let calendar = self.calendar

    return calendar.dateComponents(
      [.day],
      from: calendar.startOfDay(for: now),
      to: calendar.startOfDay(for: target)
    ).day
  }

  /// เที่ยงคืนถัดไปตามเวลาไทย — จุดที่ตัวเลขนับถอยหลังต้องเปลี่ยน
  static func nextMidnight(after date: Date) -> Date? {
    calendar.nextDate(
      after: date,
      matching: DateComponents(hour: 0, minute: 0, second: 0),
      matchingPolicy: .nextTime
    )
  }
}
