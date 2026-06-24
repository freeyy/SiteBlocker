import SwiftUI
import SiteBlockerCore

struct SiteEditorView: View {
    @Binding var site: BlockedSite
    let state: SiteBlockState
    var onCommitDomain: () -> Void = {}
    var onFixEnforcement: () -> Void = {}

    @FocusState private var domainFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                Divider()
                daysSection
                timeWindowsSection
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                TextField("domain.com", text: $site.domain)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .focused($domainFocused)
                    .onSubmit { onCommitDomain() }
                    .onChange(of: domainFocused) { focused in
                        if !focused { onCommitDomain() }
                    }
                liveStatus
            }
            Spacer()
            Toggle("", isOn: $site.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(site.isEnabled ? "Enabled" : "Disabled")
        }
    }

    @ViewBuilder
    private var liveStatus: some View {
        HStack(spacing: 6) {
            StatusDot(state: state)
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if state == .scheduledNotEnforced {
                Button("Open Settings", action: onFixEnforcement)
                    .buttonStyle(.link)
                    .font(.subheadline)
            }
        }
    }

    private var statusText: String {
        switch state {
        case .disabled: return "Disabled"
        case .inactive: return "Not blocked right now"
        case .blocked: return "Blocked right now"
        case .scheduledNotEnforced: return "Scheduled now — not enforced yet"
        }
    }

    // MARK: Days

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Active days")
            HStack(spacing: 8) {
                ForEach(Weekday.mondayFirst, id: \.self) { day in
                    DayChip(weekday: day, isOn: site.days.contains(day)) {
                        toggle(day)
                    }
                }
            }
            HStack(spacing: 8) {
                presetButton("Every day") { site.days = Set(Weekday.allCases) }
                presetButton("Weekdays") { site.days = [.monday, .tuesday, .wednesday, .thursday, .friday] }
                presetButton("Weekends") { site.days = [.saturday, .sunday] }
            }
            .font(.caption)
        }
    }

    private func toggle(_ day: Weekday) {
        if site.days.contains(day) { site.days.remove(day) } else { site.days.insert(day) }
    }

    private func presetButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderless)
            .foregroundStyle(.tint)
    }

    // MARK: Time windows

    private var timeWindowsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Time windows")
                Spacer()
                Button {
                    site.ranges.append(TimeRange(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0))
                } label: {
                    Label("Add window", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }

            if site.ranges.isEmpty {
                Text("No windows — blocked all day on the selected days.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach($site.ranges) { $range in
                        TimeWindowRow(range: $range) {
                            site.ranges.removeAll { $0.id == range.id }
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

/// A single start–end time window row.
private struct TimeWindowRow: View {
    @Binding var range: TimeRange
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            timeField(timeBinding(\.start))
            Text("to").foregroundStyle(.secondary)
            timeField(timeBinding(\.end))

            if range.crossesMidnight {
                Label("next day", systemImage: "moon.stars")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("This window spans midnight into the next morning.")
            }

            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func timeField(_ binding: Binding<Date>) -> some View {
        DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .datePickerStyle(.field)
            .frame(width: 90)
    }

    /// Bridge a `TimeOfDay` keypath to a `Date` for `DatePicker`, using today's date as the carrier.
    private func timeBinding(_ keyPath: WritableKeyPath<TimeRange, TimeOfDay>) -> Binding<Date> {
        Binding(
            get: { TimeConversion.date(from: range[keyPath: keyPath]) },
            set: { range[keyPath: keyPath] = TimeConversion.timeOfDay(from: $0) }
        )
    }
}

/// Converts between `TimeOfDay` (minutes since midnight) and a `Date` for the time pickers.
enum TimeConversion {
    private static let calendar = Calendar.current

    static func date(from time: TimeOfDay) -> Date {
        let start = calendar.startOfDay(for: Date())
        // Clamp to 23:59 so the picker (which can't show 24:00) stays valid.
        let minutes = min(time.minutes, 23 * 60 + 59)
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }

    static func timeOfDay(from date: Date) -> TimeOfDay {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
    }
}
