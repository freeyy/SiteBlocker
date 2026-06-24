import Foundation
import SiteBlockerCore

/// Filesystem locations used by the GUI.
///
/// The config lives in the *user's* home so the GUI (running as the user) can always write it
/// without any privileges. The background service (running as root) reads this same path — it is
/// told where to look via an environment variable baked into the LaunchDaemon at install time.
enum AppPaths {
    static var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/SiteBlocker/config.json")
    }

    /// The LaunchDaemon plist; its presence is how we detect whether the service is installed.
    static let daemonPlist = "/Library/LaunchDaemons/com.siteblocker.helper.plist"
}

/// Whether the background enforcement service is currently installed.
enum ServiceStatus {
    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: AppPaths.daemonPlist)
    }
}

/// Runs the bundled privileged scripts via an authenticated `osascript` prompt.
enum ServiceController {
    enum ControllerError: LocalizedError {
        case scriptMissing(String)
        case failed(String)
        case cancelled
        var errorDescription: String? {
            switch self {
            case .scriptMissing(let name): return "Bundled script \(name) is missing."
            case .failed(let output): return output
            case .cancelled: return "Cancelled."
            }
        }
        var isCancellation: Bool {
            if case .cancelled = self { return true }
            return false
        }
    }

    static func enableService() throws { try runPrivilegedScript("install-service") }
    static func disableService() throws { try runPrivilegedScript("uninstall-service") }

    /// Locate a script inside the app bundle's Resources directory.
    private static func scriptURL(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "sh")
    }

    private static func runPrivilegedScript(_ name: String) throws {
        guard let url = scriptURL(name) else { throw ControllerError.scriptMissing("\(name).sh") }

        // Build a shell command, single-quoting the path so spaces are safe, then wrap it in an
        // AppleScript `do shell script … with administrator privileges` to get the system auth dialog.
        let shellCommand = "/bin/bash '\(url.path)'"
        let appleScript = "do shell script \"\(escapeForAppleScript(shellCommand))\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            // User cancelling the auth dialog yields code -128; treat that quietly.
            if message.contains("-128") || message.contains("User canceled") {
                throw ControllerError.cancelled
            }
            throw ControllerError.failed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
