import SwiftUI
import SiteBlockerCore

/// The Settings sheet (opened from the toolbar gear). Holds the background-helper status/setup and
/// the Secure-DNS option. There is intentionally no "blocking on/off" switch — to block, you enable
/// individual sites; the helper simply enforces them.
struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
                Button("Done") { model.showingSettings = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    helperCard
                    secureDNSCard
                }
                .padding(20)
            }
        }
    }

    // MARK: Background helper (守护进程)

    private var helperCard: some View {
        card {
            Label("Background helper (守护进程)", systemImage: "gearshape.2")
                .font(.headline)

            Text("A tiny system service that enforces your blocks. It applies your schedule on time, "
                 + "re-applies the block if /etc/hosts is changed, and keeps working even when "
                 + "SiteBlocker is closed or after a reboot.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("Starts automatically at login", systemImage: "power")
                .font(.caption).foregroundStyle(.secondary)
            Label("Runs only for a moment at a time — near-zero memory", systemImage: "bolt")
                .font(.caption).foregroundStyle(.secondary)

            Divider()

            if model.serviceInstalled {
                HStack(spacing: 8) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("Installed and active").font(.callout.weight(.medium))
                    Spacer()
                    Button("Uninstall…", role: .destructive) { model.removeService() }
                        .controlSize(.small)
                }
            } else {
                Text("Not installed yet — your blocks won’t be enforced until you install it. "
                     + "macOS will ask for your admin password once.")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    model.installService()
                } label: {
                    Label("Install helper", systemImage: "arrow.down.circle.fill")
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: Secure DNS

    private var secureDNSCard: some View {
        card {
            Label("Secure DNS (DoH)", systemImage: "lock.shield")
                .font(.headline)

            Toggle(isOn: Binding(
                get: { model.config.blockSecureDNS },
                set: { model.setBlockSecureDNS($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Also block browsers’ Secure DNS bypass")
                    Text("Stops Chrome / Firefox / Zen etc. from using DNS-over-HTTPS to dodge the block.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            Text("Only active while a site is actually being blocked. A browser that bootstraps DoH "
                 + "via a hard-coded IP can still slip through.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Card chrome

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
