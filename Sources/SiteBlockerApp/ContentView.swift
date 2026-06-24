import SwiftUI
import SiteBlockerCore

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 360)
                    .navigationTitle("SiteBlocker")
                    .toolbar {
                        ToolbarItem {
                            Button(action: model.addBlankSite) {
                                Label("Add Website", systemImage: "plus")
                            }
                            .help("Add a website to block")
                        }
                    }
            } detail: {
                detail
                    .toolbar {
                        ToolbarItem { settingsButton }
                    }
            }
            .disabled(model.busyMessage != nil)

            toastOverlay

            if let message = model.busyMessage {
                LoadingOverlay(message: message)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.toast?.id)
        .animation(.easeInOut(duration: 0.2), value: model.busyMessage)
        .sheet(isPresented: $model.showingSettings) {
            SettingsView().frame(width: 520, height: 460)
        }
        .onReceive(ticker) { _ in model.refresh() }
        .onAppear { model.refresh() }
    }

    // MARK: Sidebar — websites only

    private var sidebar: some View {
        List(selection: $model.selection) {
            if model.config.sites.isEmpty {
                Text("No websites yet — click + above.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(model.config.sites) { site in
                    SiteRow(site: site, state: model.siteState(site),
                            isEnabled: model.binding(for: site.id).isEnabled)
                    .tag(site.id)
                    .contextMenu {
                        Button(role: .destructive) {
                            model.deleteSite(site.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { model.config.sites[$0].id }.forEach(model.deleteSite)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let id = model.selection, let site = model.selectedSite, site.id == id {
            SiteEditorView(
                site: model.binding(for: id),
                state: model.siteState(site),
                onCommitDomain: { model.normalizeDomain(of: id) },
                onFixEnforcement: { model.showingSettings = true }
            )
        } else {
            emptyDetail
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint.opacity(0.7))
            Text("Select a website to edit its schedule")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button(action: model.addBlankSite) {
                Label("Add Website", systemImage: "plus")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Toolbar settings button (gear, where the shield used to be)

    private var settingsButton: some View {
        Button {
            model.showingSettings = true
        } label: {
            Label("Settings", systemImage: needsAttention ? "gearshape.badge.checkmark" : "gearshape")
                .foregroundStyle(needsAttention ? Color.orange : Color.primary)
        }
        .help(needsAttention
              ? "Blocks aren't being enforced — open Settings to install the helper."
              : "Settings")
    }

    /// The gear nudges (amber) when something is scheduled to block but isn't actually enforced.
    private var needsAttention: Bool {
        !model.serviceInstalled && !model.config.sites.filter(\.isEnabled).isEmpty
    }

    // MARK: Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = model.toast {
            ToastView(toast: toast) { model.toast = nil }
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: toast.id) {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    if model.toast?.id == toast.id { model.toast = nil }
                }
        }
    }
}

/// A single row in the sidebar list.
private struct SiteRow: View {
    let site: BlockedSite
    let state: SiteBlockState
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(state: state)
            VStack(alignment: .leading, spacing: 2) {
                Text(site.domain.isEmpty ? "new website" : site.domain)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(site.isEnabled ? .primary : .secondary)
                Text(site.scheduleDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
