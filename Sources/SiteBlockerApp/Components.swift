import SwiftUI
import SiteBlockerCore

/// A small status indicator reflecting the site's combined schedule + enforcement state:
/// solid red = blocked now, amber = scheduled now but not enforced, hollow green = enabled & idle,
/// faint = disabled.
struct StatusDot: View {
    let state: SiteBlockState

    var body: some View {
        Circle()
            .fill(fillColor)
            .overlay(Circle().strokeBorder(strokeColor, lineWidth: 1.5))
            .frame(width: 10, height: 10)
            .help(helpText)
    }

    private var fillColor: Color {
        switch state {
        case .disabled: return Color.secondary.opacity(0.15)
        case .inactive: return .clear
        case .blocked: return .red
        case .scheduledNotEnforced: return .orange
        }
    }
    private var strokeColor: Color {
        switch state {
        case .disabled: return Color.secondary.opacity(0.3)
        case .inactive: return Color.green.opacity(0.8)
        case .blocked: return .red
        case .scheduledNotEnforced: return .orange
        }
    }
    private var helpText: String {
        switch state {
        case .disabled: return "Disabled"
        case .inactive: return "Enabled — not in a blocking window right now"
        case .blocked: return "Blocked right now"
        case .scheduledNotEnforced: return "Scheduled to block now — not enforced yet"
        }
    }
}

/// One tappable circular day-of-week chip (M T W …).
struct DayChip: View {
    let weekday: Weekday
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(isOn ? Color.accentColor : Color.secondary.opacity(0.12))
                )
                .foregroundStyle(isOn ? Color.white : Color.primary.opacity(0.7))
        }
        .buttonStyle(.plain)
        .help(weekday.shortName)
    }

    /// First letter of the short name (Tue/Thu and Sat/Sun share letters but position disambiguates).
    private var letter: String { String(weekday.shortName.prefix(1)) }
}
