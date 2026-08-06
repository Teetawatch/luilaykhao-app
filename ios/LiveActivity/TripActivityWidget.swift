import ActivityKit
import SwiftUI
import WidgetKit

/// การ์ด "วันเดินทาง" บนหน้าจอล็อกและ Dynamic Island
///
/// ทั้งหมดนี้เป็นแค่การ "วาด" — ไม่มีตรรกะว่าเมื่อไหร่ควรขึ้นข้อความอะไรอยู่ที่นี่
/// เลย เพราะถ้ามี วันหนึ่ง iOS กับ Android จะบอกเวลารถถึงไม่ตรงกัน ทุกข้อความ
/// มาจาก `TripActivityService` ฝั่ง Laravel ที่เดียว
@available(iOS 16.2, *)
struct TripActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TripActivityAttributes.self) { context in
      LockScreenView(context: context)
        .activityBackgroundTint(TripActivityStyle.background)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 6) {
            Image(systemName: TripActivityStyle.icon(for: context.state.stage))
              .foregroundColor(TripActivityStyle.accent)
            Text(context.attributes.tripTitle)
              .font(.caption)
              .fontWeight(.semibold)
              .lineLimit(1)
          }
          .padding(.leading, 4)
        }

        DynamicIslandExpandedRegion(.trailing) {
          if let minutes = context.state.etaMinutes, minutes > 0 {
            VStack(alignment: .trailing, spacing: 0) {
              Text("\(minutes)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(TripActivityStyle.accent)
              Text("นาที")
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.trailing, 4)
          }
        }

        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            Text(context.state.headline)
              .font(.headline)
              .lineLimit(1)
            Text(context.state.detail)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(2)
            ProgressBar(value: context.state.progress)
          }
          .padding(.top, 2)
        }
      } compactLeading: {
        Image(systemName: TripActivityStyle.icon(for: context.state.stage))
          .foregroundColor(TripActivityStyle.accent)
      } compactTrailing: {
        if let minutes = context.state.etaMinutes, minutes > 0 {
          Text("\(minutes) น.")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(TripActivityStyle.accent)
        }
      } minimal: {
        Image(systemName: TripActivityStyle.icon(for: context.state.stage))
          .foregroundColor(TripActivityStyle.accent)
      }
      .widgetURL(URL(string: "luilaykhao://booking/\(context.attributes.bookingRef)"))
      .keylineTint(TripActivityStyle.accent)
    }
  }
}

@available(iOS 16.2, *)
private struct LockScreenView: View {
  let context: ActivityViewContext<TripActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: TripActivityStyle.icon(for: context.state.stage))
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(TripActivityStyle.accent)
        Text(context.attributes.tripTitle)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.white.opacity(0.75))
          .lineLimit(1)
        Spacer(minLength: 4)
        if let vehicle = context.state.vehicleLabel, !vehicle.isEmpty {
          Text(vehicle)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.55))
            .lineLimit(1)
        }
      }

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(context.state.headline)
          .font(.system(size: 20, weight: .heavy))
          .foregroundColor(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Spacer(minLength: 0)
      }

      ProgressBar(value: context.state.progress)

      Text(context.state.detail)
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.white.opacity(0.7))
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(16)
  }
}

@available(iOS 16.2, *)
private struct ProgressBar: View {
  let value: Double

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.white.opacity(0.18))
        Capsule()
          .fill(TripActivityStyle.accent)
          .frame(width: max(6, geometry.size.width * min(max(value, 0), 1)))
      }
    }
    .frame(height: 6)
  }
}

@available(iOS 16.2, *)
enum TripActivityStyle {
  /// Emerald 500 — ตัวเดียวกับ AppTheme.accentColor ในแอป
  static let accent = Color(red: 0.063, green: 0.725, blue: 0.506)
  /// Slate 950 — พื้นหลังโหมดมืดของแอป การ์ดจึงดูเป็นของเดียวกันกับตัวแอป
  static let background = Color(red: 0.043, green: 0.071, blue: 0.125)

  static func icon(for stage: String) -> String {
    switch stage {
    case "arrived": return "figure.wave"
    case "arriving", "approaching": return "bus.fill"
    case "onboard": return "checkmark.seal.fill"
    case "enroute": return "location.fill"
    case "preparing": return "backpack.fill"
    case "ended": return "flag.checkered"
    default: return "hourglass"
    }
  }
}
