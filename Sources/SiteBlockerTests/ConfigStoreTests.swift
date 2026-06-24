import Foundation
import SiteBlockerCore

private func sampleConfig() -> BlockConfig {
    BlockConfig(sites: [
        BlockedSite(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            domain: "reddit.com",
            isEnabled: true,
            days: [.monday, .wednesday, .friday],
            ranges: [TimeRange(
                id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
                startHour: 9, startMinute: 0, endHour: 17, endMinute: 30
            )]
        ),
        BlockedSite(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            domain: "news.ycombinator.com",
            days: Set(Weekday.allCases),
            ranges: []
        ),
    ])
}

func runConfigStoreTests() {
    section("ConfigStore — encode/decode")

    test("Encode/decode round trip") {
        do {
            let config = sampleConfig()
            let data = try ConfigStore.encode(config)
            let decoded = try ConfigStore.decode(data)
            expectEqual(decoded, config)
        } catch { fail("threw: \(error)") }
    }

    test("Loading a missing file returns an empty config") {
        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("does-not-exist-\(UUID().uuidString).json")
            let config = try ConfigStore.load(from: url)
            expectEqual(config.sites.count, 0)
            expectEqual(config.version, BlockConfig.currentVersion)
        } catch { fail("threw: \(error)") }
    }

    test("Save then load round trip via the filesystem") {
        do {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("siteblocker-test-\(UUID().uuidString)", isDirectory: true)
            let url = dir.appendingPathComponent("config.json")
            defer { try? FileManager.default.removeItem(at: dir) }

            let config = sampleConfig()
            try ConfigStore.save(config, to: url)
            expectTrue(FileManager.default.fileExists(atPath: url.path))
            let loaded = try ConfigStore.load(from: url)
            expectEqual(loaded, config)
        } catch { fail("threw: \(error)") }
    }

    test("Empty data loads as an empty config") {
        do {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("siteblocker-test-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("config.json")
            defer { try? FileManager.default.removeItem(at: dir) }
            try Data().write(to: url)
            let loaded = try ConfigStore.load(from: url)
            expectEqual(loaded.sites.count, 0)
        } catch { fail("threw: \(error)") }
    }
}
