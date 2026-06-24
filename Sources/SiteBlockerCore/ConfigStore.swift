import Foundation

/// Well-known filesystem locations shared between the GUI app and the privileged helper.
public enum Paths {
    /// System-wide support directory, created during install and owned by the installing user
    /// so the GUI can write it while the root helper can read it.
    public static let supportDirectory = "/Library/Application Support/SiteBlocker"
    public static let configFile = supportDirectory + "/config.json"
    public static let helperBinary = supportDirectory + "/site-blocker-helper"

    public static let hostsFile = "/etc/hosts"

    public static let launchDaemonLabel = "com.siteblocker.helper"
    public static let launchDaemonPlist = "/Library/LaunchDaemons/com.siteblocker.helper.plist"
}

/// Loads and saves `BlockConfig` as pretty-printed, stably-ordered JSON.
public enum ConfigStore {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    public static func encode(_ config: BlockConfig) throws -> Data {
        try makeEncoder().encode(config)
    }

    public static func decode(_ data: Data) throws -> BlockConfig {
        try makeDecoder().decode(BlockConfig.self, from: data)
    }

    /// Read config from `url`. A missing file yields an empty config rather than an error,
    /// so first-run is friction-free.
    public static func load(from url: URL) throws -> BlockConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return BlockConfig()
        }
        let data = try Data(contentsOf: url)
        if data.isEmpty { return BlockConfig() }
        return try decode(data)
    }

    /// Atomically write config to `url`, creating intermediate directories if needed.
    public static func save(_ config: BlockConfig, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try encode(config)
        try data.write(to: url, options: .atomic)
    }

    public static var defaultConfigURL: URL {
        URL(fileURLWithPath: Paths.configFile)
    }
}
