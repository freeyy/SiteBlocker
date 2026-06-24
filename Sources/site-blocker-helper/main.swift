import Foundation
import SiteBlockerCore

// site-blocker-helper
//
// A tiny privileged tool, run periodically by a LaunchDaemon (as root), that reconciles the
// managed section of /etc/hosts with the current schedule. Because launchd drives it, blocking
// keeps working even when the GUI app is closed.
//
// Usage:
//   site-blocker-helper reconcile   # default: apply the schedule to /etc/hosts right now
//   site-blocker-helper status      # print which domains are currently active
//   site-blocker-helper clear       # remove the managed section entirely
//
// Environment overrides (used by the integration tests so they need no root):
//   SITEBLOCKER_CONFIG   path to config.json   (default: /Library/Application Support/...)
//   SITEBLOCKER_HOSTS    path to hosts file    (default: /etc/hosts)
//   SITEBLOCKER_NO_FLUSH if set, skip flushing the DNS cache

struct Helper {
    let configPath: String
    let hostsPath: String
    let flushEnabled: Bool

    init(environment: [String: String]) {
        configPath = environment["SITEBLOCKER_CONFIG"] ?? Paths.configFile
        hostsPath = environment["SITEBLOCKER_HOSTS"] ?? Paths.hostsFile
        flushEnabled = environment["SITEBLOCKER_NO_FLUSH"] == nil
    }

    func loadConfig() -> BlockConfig {
        (try? ConfigStore.load(from: URL(fileURLWithPath: configPath))) ?? BlockConfig()
    }

    func readHosts() -> String {
        (try? String(contentsOfFile: hostsPath, encoding: .utf8)) ?? ""
    }

    /// Write the hosts file only if it differs, then flush DNS. Returns true if a write happened.
    @discardableResult
    func writeHostsIfChanged(_ contents: String) throws -> Bool {
        guard readHosts() != contents else { return false }
        do {
            try contents.write(to: URL(fileURLWithPath: hostsPath), atomically: true, encoding: .utf8)
        } catch {
            throw HelperError.message(
                "Failed to write \(hostsPath): \(error.localizedDescription). The helper must run as root."
            )
        }
        if flushEnabled { flushDNS() }
        return true
    }

    func reconcile() throws {
        let blocked = ScheduleEvaluator.domainsToBlock(in: loadConfig(), at: Date())
        let rendered = HostsFile.render(existing: readHosts(), blockedDomains: blocked)
        let changed = try writeHostsIfChanged(rendered)
        log("reconcile: \(blocked.count) host(s) blocked, hosts \(changed ? "updated" : "unchanged")")
    }

    func status() {
        let config = loadConfig()
        let blocked = ScheduleEvaluator.domainsToBlock(in: config, at: Date())
        print("Configured sites: \(config.sites.count)")
        print("Block Secure DNS: \(config.blockSecureDNS)")
        print("Currently blocked: \(blocked.isEmpty ? "(none)" : blocked.joined(separator: ", "))")
    }

    func clear() throws {
        let rendered = HostsFile.render(existing: readHosts(), blockedDomains: [])
        let changed = try writeHostsIfChanged(rendered)
        log("clear: managed section \(changed ? "removed" : "already absent")")
    }
}

enum HelperError: Error, CustomStringConvertible {
    case message(String)
    var description: String { switch self { case .message(let m): return m } }
}

func log(_ message: String) {
    FileHandle.standardError.write(Data("[site-blocker-helper] \(message)\n".utf8))
}

func flushDNS() {
    runQuietly("/usr/bin/dscacheutil", ["-flushcache"])
    runQuietly("/usr/bin/killall", ["-HUP", "mDNSResponder"])
}

func runQuietly(_ launchPath: String, _ args: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = args
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
}

// MARK: - Entry point

let helper = Helper(environment: ProcessInfo.processInfo.environment)
let command = CommandLine.arguments.dropFirst().first ?? "reconcile"
do {
    switch command {
    case "reconcile": try helper.reconcile()
    case "status": helper.status()
    case "clear": try helper.clear()
    default:
        log("unknown command: \(command)")
        exit(2)
    }
} catch {
    log("error: \(error)")
    exit(1)
}
