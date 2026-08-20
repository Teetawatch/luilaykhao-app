import SwiftUI
import WidgetKit

/// วิดเจ็ตหน้าโฮม "อีก 17 วันไปเขาช้างเผือก"
///
/// การ์ดวันเดินทาง ([TripActivityWidget]) อยู่บนหน้าจอล็อกเฉพาะวันเดินทาง ตัวนี้อยู่
/// บนหน้าโฮมทุกวันที่เหลือ — ทริปถัดไปที่จองไว้ กับยอดที่ต้องจ่ายงวดหน้า
///
/// ไม่ต่อเน็ตเอง อ่านแต่ snapshot ที่แอปเขียนไว้ใน App Group (ดู [HomeWidgetStore])
/// ข้อความไทยเกือบทุกบรรทัดมาจาก `HomeWidgetService` ฝั่ง Laravel ยกเว้นตัวเลขวันที่
/// นับใหม่ที่นี่ (ดูเหตุผลใน [HomeWidgetClock]) — ถ้อยคำที่ประกอบกับตัวเลขนั้นเขียน
/// ไว้ทั้งสองฝั่งให้ตรงกัน และมีเทสต์คุมไว้ทั้งคู่
struct TripCountdownWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TripCountdownWidget", provider: TripCountdownProvider()) { entry in
      TripCountdownView(entry: entry)
    }
    .configurationDisplayName("ทริปถัดไป")
    .description("นับถอยหลังทริปที่จองไว้ และยอดที่ต้องจ่ายงวดหน้า")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - Timeline

struct TripCountdownEntry: TimelineEntry {
  let date: Date
  let snapshot: HomeWidgetSnapshot?
}

struct TripCountdownProvider: TimelineProvider {
  /// จำนวนวันข้างหน้าที่เตรียมเฟรมไว้ล่วงหน้า
  ///
  /// วิดเจ็ตต้องนับถอยหลังลดลงทุกเที่ยงคืนแม้ไม่มีใครเปิดแอปเลย ซึ่งทำได้ด้วยการ
  /// บอก WidgetKit ไว้ล่วงหน้าว่าเฟรมถัดไปเริ่มตอนไหน — เตรียมไว้หนึ่งสัปดาห์แล้ว
  /// ให้มันมาขอชุดใหม่เอง (`.atEnd`)
  private let daysAhead = 7

  func placeholder(in context: Context) -> TripCountdownEntry {
    TripCountdownEntry(date: Date(), snapshot: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (TripCountdownEntry) -> Void) {
    completion(TripCountdownEntry(date: Date(), snapshot: HomeWidgetStore.read()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TripCountdownEntry>) -> Void) {
    let snapshot = HomeWidgetStore.read()
    let now = Date()

    var entries = [TripCountdownEntry(date: now, snapshot: snapshot)]
    var cursor = now

    for _ in 0..<daysAhead {
      guard let midnight = HomeWidgetClock.nextMidnight(after: cursor) else { break }
      entries.append(TripCountdownEntry(date: midnight, snapshot: snapshot))
      cursor = midnight
    }

    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

// MARK: - ข้อความ

/// สิ่งที่บรรทัดใหญ่ควรขึ้น ณ เวลาที่วาด
enum TripCountdownCopy {
  /// นับถอยหลังเป็นวัน — ตัวเลขใหญ่ + "วัน"
  case number(days: Int)
  /// วันนี้ / พรุ่งนี้ — ไม่ต้องมีตัวเลข
  case phrase(big: String, small: String)
  /// ข้อความจากเซิร์ฟเวอร์ทั้งดุ้น (วันเดินทาง — มันรู้เรื่องรถซึ่งวิดเจ็ตไม่รู้)
  case headline(String)

  static func of(_ trip: HomeWidgetTrip, now: Date = Date()) -> TripCountdownCopy {
    if trip.isLive {
      return .headline(trip.headline)
    }

    // นับใหม่จากวันที่เสมอ ถ้าอ่านไม่ได้จึงถอยไปใช้เลขที่เซิร์ฟเวอร์ส่งมา
    let days = HomeWidgetClock.daysUntil(trip.departureDate, from: now) ?? trip.countdownDays

    switch days {
    case ..<0: return .headline(trip.headline)
    case 0: return .phrase(big: "วันนี้", small: "ออกเดินทาง")
    case 1: return .phrase(big: "พรุ่งนี้", small: "ออกเดินทาง")
    default: return .number(days: days)
    }
  }
}

enum HomeWidgetCopy {
  /// ทริปที่จบไปแล้วต้องหายจากหน้าโฮมเองโดยไม่ต้องรอให้ใครเปิดแอป
  static func isExpired(_ trip: HomeWidgetTrip, now: Date = Date()) -> Bool {
    guard let days = HomeWidgetClock.daysUntil(trip.validUntil ?? trip.departureDate, from: now)
    else { return false }

    return days < 0
  }

  /// บรรทัดสถานะของยอดค้าง
  ///
  /// สามวลีที่อ้างอิง "วันนี้/พรุ่งนี้/เกินกำหนด" นับใหม่ที่นี่เพราะมันเก่าได้ในหนึ่ง
  /// คืน ส่วนวันที่แบบมีเดือนไทย (`ครบกำหนด 25 ส.ค. 2569`) ใช้ของเซิร์ฟเวอร์ตรง ๆ —
  /// ชื่อเดือนไทยกับปี พ.ศ. ไม่ควรมีสูตรอยู่ในวิดเจ็ต
  ///
  /// ⚠️ ถ้อยคำสามวลีนี้ต้องตรงกับ `HomeWidgetService::dueLabel()` ฝั่ง Laravel
  static func dueLine(_ payment: HomeWidgetPayment, now: Date = Date()) -> String {
    // แนบสลิปแล้วมาก่อนทุกอย่าง คนที่โอนเมื่อคืนแล้วเห็นวิดเจ็ตทวงว่าเกินกำหนดจะ
    // เข้าใจว่าเงินหาย
    if payment.slipPending {
      return payment.dueLabel
    }

    guard let days = HomeWidgetClock.daysUntil(payment.dueDate, from: now) else {
      return payment.dueLabel
    }

    switch days {
    case ..<0: return "เกินกำหนด \(-days) วัน"
    case 0: return "ครบกำหนดวันนี้"
    case 1: return "ครบกำหนดพรุ่งนี้"
    default: return payment.dueLabel
    }
  }

  /// สีแดงเตือนต้องเดินตามวันที่นับใหม่ ไม่ใช่ธงที่เซิร์ฟเวอร์ส่งมาเมื่อสามวันก่อน
  static func isOverdue(_ payment: HomeWidgetPayment, now: Date = Date()) -> Bool {
    if payment.slipPending { return false }
    guard let days = HomeWidgetClock.daysUntil(payment.dueDate, from: now) else {
      return payment.overdue
    }

    return days < 0
  }
}

// MARK: - หน้าตา

struct TripCountdownView: View {
  let entry: TripCountdownEntry

  @Environment(\.widgetFamily) private var family

  private var trip: HomeWidgetTrip? {
    guard let trip = entry.snapshot?.trip else { return nil }
    return HomeWidgetCopy.isExpired(trip, now: entry.date) ? nil : trip
  }

  private var payment: HomeWidgetPayment? { entry.snapshot?.payment }

  var body: some View {
    // การกางเต็มพื้นที่กับระยะขอบอยู่ใน homeWidgetBackground ทั้งคู่ เพราะสองระบบ
    // ปฏิบัติกับมันไม่เหมือนกัน (iOS 17 ใส่ระยะขอบให้เอง iOS 16 ไม่ใส่)
    content
      .widgetURL(tapTarget)
      .homeWidgetBackground(HomeWidgetPalette.background)
  }

  @ViewBuilder
  private var content: some View {
    if let trip {
      if family == .systemMedium, let payment {
        HStack(alignment: .top, spacing: 14) {
          TripColumn(trip: trip, now: entry.date, compact: false)
          Rectangle()
            .fill(HomeWidgetPalette.hairline)
            .frame(width: 1)
          PaymentColumn(payment: payment, now: entry.date)
            .frame(width: 108)
        }
      } else {
        TripColumn(trip: trip, now: entry.date, compact: family == .systemSmall)
      }
    } else if let payment {
      // ไม่มีทริปข้างหน้าแล้วแต่ยังมียอดค้าง (จ่ายไม่ครบหลังกลับจากทริป) — เรื่องนี้
      // ยังต้องบอก ไม่ใช่ปล่อยวิดเจ็ตว่าง
      PaymentOnly(payment: payment, now: entry.date)
    } else {
      EmptyStateView()
    }
  }

  /// แตะแล้วไปไหน — ทริปมาก่อน ถ้าไม่มีทริปก็ไปที่ใบที่ต้องจ่าย
  ///
  /// คืน nil เมื่อไม่มีอะไรให้ไป ซึ่ง WidgetKit แปลว่า "เปิดแอปเฉย ๆ" — ถูกต้องแล้ว
  /// สำหรับสถานะว่าง
  private var tapTarget: URL? {
    if let ref = trip?.bookingRef ?? payment?.bookingRef {
      return URL(string: "luilaykhao://booking/\(ref)")
    }
    return nil
  }
}

private struct TripColumn: View {
  let trip: HomeWidgetTrip
  let now: Date
  let compact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 5) {
        Image(systemName: HomeWidgetPalette.icon(for: trip.stage))
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(HomeWidgetPalette.accent)
        Text(trip.tripTitle)
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(HomeWidgetPalette.muted)
          .lineLimit(1)
      }

      Spacer(minLength: 6)

      headline

      if trip.isLive, trip.progress > 0 {
        ProgressStrip(value: trip.progress)
          .padding(.top, 8)
      }

      Spacer(minLength: 6)

      Text(trip.detail)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(HomeWidgetPalette.faint)
        .lineLimit(compact ? 2 : 3)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var headline: some View {
    switch TripCountdownCopy.of(trip, now: now) {
    case .number(let days):
      VStack(alignment: .leading, spacing: -2) {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
          Text("\(days)")
            .font(.system(size: compact ? 40 : 44, weight: .heavy))
            .foregroundColor(HomeWidgetPalette.accent)
          Text("วัน")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(HomeWidgetPalette.accent)
        }
        Text("ก่อนออกเดินทาง")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(HomeWidgetPalette.muted)
      }

    case .phrase(let big, let small):
      VStack(alignment: .leading, spacing: 0) {
        Text(big)
          .font(.system(size: compact ? 26 : 30, weight: .heavy))
          .foregroundColor(HomeWidgetPalette.accent)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Text(small)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(HomeWidgetPalette.muted)
      }

    case .headline(let text):
      Text(text)
        .font(.system(size: compact ? 17 : 19, weight: .heavy))
        .foregroundColor(.white)
        .lineLimit(2)
        .minimumScaleFactor(0.75)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct PaymentColumn: View {
  let payment: HomeWidgetPayment
  let now: Date

  var body: some View {
    let overdue = HomeWidgetCopy.isOverdue(payment, now: now)

    return VStack(alignment: .leading, spacing: 0) {
      Text(payment.label)
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(HomeWidgetPalette.muted)
        .lineLimit(1)

      Spacer(minLength: 4)

      Text(payment.amountLabel)
        .font(.system(size: 19, weight: .heavy))
        .foregroundColor(overdue ? HomeWidgetPalette.warning : .white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      Spacer(minLength: 4)

      Text(HomeWidgetCopy.dueLine(payment, now: now))
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(overdue ? HomeWidgetPalette.warning : HomeWidgetPalette.faint)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxHeight: .infinity, alignment: .topLeading)
  }
}

private struct PaymentOnly: View {
  let payment: HomeWidgetPayment
  let now: Date

  var body: some View {
    let overdue = HomeWidgetCopy.isOverdue(payment, now: now)

    return VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 5) {
        Image(systemName: "creditcard.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(overdue ? HomeWidgetPalette.warning : HomeWidgetPalette.accent)
        Text(payment.tripTitle)
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(HomeWidgetPalette.muted)
          .lineLimit(1)
      }

      Spacer(minLength: 6)

      Text(payment.amountLabel)
        .font(.system(size: 30, weight: .heavy))
        .foregroundColor(overdue ? HomeWidgetPalette.warning : .white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(payment.label)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(HomeWidgetPalette.muted)
        .lineLimit(1)

      Spacer(minLength: 6)

      Text(HomeWidgetCopy.dueLine(payment, now: now))
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(overdue ? HomeWidgetPalette.warning : HomeWidgetPalette.faint)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// ยังไม่ได้จองอะไร หรือยังไม่ได้ล็อกอิน
///
/// ข้อความชุดนี้เป็นของวิดเจ็ตเอง ไม่ได้มาจากเซิร์ฟเวอร์ — เพราะตอนที่ยังไม่มี
/// snapshot ก็ยังไม่มีเซิร์ฟเวอร์คนไหนได้พูดอะไรเลย
private struct EmptyStateView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 5) {
        Image(systemName: "mountain.2.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(HomeWidgetPalette.accent)
        Text("ลุยเลเขา")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(HomeWidgetPalette.muted)
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      Text("ยังไม่มีทริปที่จะไป")
        .font(.system(size: 17, weight: .heavy))
        .foregroundColor(.white)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 6)

      Text("แตะเพื่อดูรอบที่เปิดรับ")
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(HomeWidgetPalette.faint)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ProgressStrip: View {
  let value: Double

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(HomeWidgetPalette.hairline)
        Capsule()
          .fill(HomeWidgetPalette.accent)
          .frame(width: max(4, geometry.size.width * min(max(value, 0), 1)))
      }
    }
    .frame(height: 4)
  }
}

// MARK: - สี

/// จานสีของวิดเจ็ต — ตัวเดียวกับที่ [TripActivityStyle] ใช้ เพื่อให้การ์ดหน้าจอล็อก
/// กับวิดเจ็ตหน้าโฮมดูเป็นของชุดเดียวกัน
///
/// ไม่ใส่ `@available` เพื่อให้ทั้งโค้ดที่ต้องการ iOS 16.2 (Live Activity) และวิดเจ็ต
/// ธรรมดาเรียกได้จากที่เดียว
enum HomeWidgetPalette {
  /// Emerald 500 — ตัวเดียวกับ AppTheme.accentColor ในแอป
  static let accent = Color(red: 0.063, green: 0.725, blue: 0.506)
  /// Slate 950 — พื้นหลังโหมดมืดของแอป
  static let background = Color(red: 0.043, green: 0.071, blue: 0.125)
  /// Rose 400 — ใช้เฉพาะยอดที่เกินกำหนด ไม่ใช้เป็นสีตกแต่ง
  static let warning = Color(red: 0.984, green: 0.443, blue: 0.443)

  static let muted = Color.white.opacity(0.72)
  static let faint = Color.white.opacity(0.55)
  static let hairline = Color.white.opacity(0.14)

  static func icon(for stage: String) -> String {
    switch stage {
    case "arrived": return "figure.wave"
    case "arriving", "approaching": return "bus.fill"
    case "onboard": return "checkmark.seal.fill"
    case "enroute": return "location.fill"
    case "preparing": return "backpack.fill"
    case "meetup": return "person.2.wave.2.fill"
    case "boarding": return "airplane.departure"
    default: return "mountain.2.fill"
    }
  }
}

extension View {
  /// พื้นหลัง + ระยะขอบ + การกางเต็มพื้นที่ของวิดเจ็ต
  ///
  /// iOS 17 ย้ายไปใช้ `containerBackground` (วิดเจ็ตที่ไม่ประกาศจะได้พื้นขาวของระบบ
  /// แทนสีที่ตั้งไว้) และใส่ระยะขอบมาตรฐานให้เนื้อหาเอง ส่วน iOS 16 ไม่มีทั้งสองอย่าง
  /// จึงต้องวางพื้นด้วย ZStack และเว้นขอบเอง
  ///
  /// ลำดับสำคัญในสาขา iOS 16: `padding` ต้องมาก่อน `frame` — ถ้าสลับกัน เนื้อหาจะ
  /// ถูกกางเต็มพื้นที่ก่อนแล้วค่อยถูกห่อด้วยขอบ ทำให้ล้นกรอบวิดเจ็ตออกไป 14pt
  @ViewBuilder
  func homeWidgetBackground(_ color: Color) -> some View {
    if #available(iOS 17.0, *) {
      self
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(color, for: .widget)
    } else {
      ZStack {
        color
        self
          .padding(14)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
    }
  }
}
