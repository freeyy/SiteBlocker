import Foundation
import SwiftUI
import SiteBlockerCore

/// Observable application state: the config, the current selection, live status, the
/// background-service install state, a busy indicator for privileged work, and a transient toast.
@MainActor
final class AppModel: ObservableObject {
    @Published var config: BlockConfig
    @Published var selection: BlockedSite.ID?
    @Published var serviceInstalled: Bool
    @Published var now: Date = Date()
    @Published var toast: ToastInfo?
    /// Non-nil while a privileged operation is running; drives the full-window loading overlay.
    @Published var busyMessage: String?
    /// Whether the Settings sheet is presented.
    @Published var showingSettings: Bool = false
    /// The hostnames actually present in /etc/hosts right now — the source of truth for status.
    @Published var blockedHosts: Set<String> = []

    private var saveWorkItem: DispatchWorkItem?

    init() {
        let loaded = (try? ConfigStore.load(from: AppPaths.configURL)) ?? BlockConfig()
        self.config = loaded
        self.serviceInstalled = ServiceStatus.isInstalled
        self.selection = loaded.sites.first?.id
        self.blockedHosts = AppModel.readBlockedHosts()
    }

    // MARK: Live status

    /// Re-read the world: the clock, whether the daemon is installed, and the real hosts state.
    func refresh() {
        now = Date()
        serviceInstalled = ServiceStatus.isInstalled
        blockedHosts = AppModel.readBlockedHosts()
    }

    private static func readBlockedHosts() -> Set<String> {
        guard let content = try? String(contentsOfFile: Paths.hostsFile, encoding: .utf8) else { return [] }
        return HostsFile.blockedHostnames(in: content)
    }

    /// The daemon being installed is what makes enforcement happen.
    var isEnforcing: Bool { serviceInstalled }

    /// Per-site display state — uses the real /etc/hosts contents as the source of truth.
    func siteState(_ site: BlockedSite) -> SiteBlockState {
        ScheduleEvaluator.displayState(
            of: site,
            isActuallyBlocked: blockedHosts.contains(site.domain),
            at: now
        )
    }

    /// True if any enabled site's schedule is active right now but it isn't actually blocked yet.
    var hasUnenforcedSchedule: Bool {
        config.sites.contains {
            ScheduleEvaluator.isBlocked($0, at: now) && !blockedHosts.contains($0.domain)
        }
    }

    // MARK: Selection helpers

    var selectedSite: BlockedSite? {
        guard let selection else { return nil }
        return config.sites.first { $0.id == selection }
    }

    // MARK: Mutations

    func addBlankSite() {
        if let blank = config.sites.first(where: { $0.domain.isEmpty }) {
            selection = blank.id
            return
        }
        let site = BlockedSite(
            domain: "",
            days: [.monday, .tuesday, .wednesday, .thursday, .friday],
            ranges: [TimeRange(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)]
        )
        config.sites.append(site)
        selection = site.id
        saveNow()
    }

    func normalizeDomain(of id: BlockedSite.ID) {
        guard let index = config.sites.firstIndex(where: { $0.id == id }) else { return }
        let raw = config.sites[index].domain
        if let normalized = Domain.normalize(raw), normalized != raw {
            config.sites[index].domain = normalized
            saveNow()
        }
    }

    func deleteSite(_ id: BlockedSite.ID) {
        config.sites.removeAll { $0.id == id }
        if selection == id { selection = config.sites.first?.id }
        saveNow()
    }

    func binding(for id: BlockedSite.ID) -> Binding<BlockedSite> {
        Binding(
            get: { self.config.sites.first(where: { $0.id == id }) ?? BlockedSite(domain: "") },
            set: { newValue in
                guard let index = self.config.sites.firstIndex(where: { $0.id == id }) else { return }
                self.config.sites[index] = newValue
                self.scheduleSave()
            }
        )
    }

    // MARK: Settings flags (saved immediately so the daemon reconciles in real time)

    func setBlockSecureDNS(_ value: Bool) {
        config.blockSecureDNS = value
        saveNow()
    }

    // MARK: Persistence

    /// Debounced save — avoids a flurry of writes while a user drags a time picker.
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.writeConfig() }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Save right now (used for discrete actions like toggles, add, delete).
    func saveNow() {
        saveWorkItem?.cancel()
        writeConfig()
    }

    private func writeConfig() {
        do {
            try ConfigStore.save(config, to: AppPaths.configURL)
            // The daemon applies the change to /etc/hosts within a couple of seconds; re-read then
            // so the live status catches up to reality.
            scheduleHostsRecheck()
        } catch {
            toast = ToastInfo(kind: .error, message: "Couldn't save: \(error.localizedDescription)")
        }
    }

    private func scheduleHostsRecheck() {
        for delay in [2.0, 5.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.refresh() }
        }
    }

    // MARK: Background service (privileged, run off the main thread so the UI stays responsive)

    func installService() {
        runPrivileged(message: "Installing the helper…", action: { try ServiceController.enableService() }) {
            self.refresh()
            self.toast = ToastInfo(kind: .success,
                message: "Helper installed — your blocks are enforced, even when SiteBlocker is closed.")
        }
    }

    func removeService() {
        runPrivileged(message: "Removing the helper…", action: { try ServiceController.disableService() }) {
            self.refresh()
            self.toast = ToastInfo(kind: .info, message: "Helper removed. Nothing is blocked now.")
        }
    }

    private enum PrivilegedOutcome: Sendable {
        case success
        case cancelled
        case failure(String)
    }

    private func runPrivileged(
        message: String,
        action: @escaping @Sendable () throws -> Void,
        onSuccess: @escaping () -> Void
    ) {
        busyMessage = message
        Task {
            let outcome: PrivilegedOutcome = await Task.detached(priority: .userInitiated) {
                do {
                    try action()
                    return .success
                } catch let error as ServiceController.ControllerError where error.isCancellation {
                    return .cancelled
                } catch {
                    return .failure(error.localizedDescription)
                }
            }.value

            busyMessage = nil
            switch outcome {
            case .success:
                onSuccess()
            case .cancelled:
                serviceInstalled = ServiceStatus.isInstalled
            case .failure(let message):
                toast = ToastInfo(kind: .error, message: message)
            }
        }
    }
}
