import Foundation
import Combine

struct ShareConfig: Codable, Identifiable, Sendable, Hashable {
    var id: UUID
    var host: String
    var shareName: String
    var username: String
    var mountPoint: String
    var enabled: Bool
}

struct QuietHourRange: Codable, Sendable, Hashable {
    var start: String
    var end: String
}

struct AppConfig: Codable, Sendable {
    var checkIntervalSeconds: Int
    var consecutiveFailuresBeforeNotify: Int
    var quietHours: [QuietHourRange]
    var shares: [ShareConfig]

    static let `default` = AppConfig(
        checkIntervalSeconds: 60,
        consecutiveFailuresBeforeNotify: 5,
        quietHours: [],
        shares: []
    )
}

@MainActor
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published private(set) var config: AppConfig = .default

    private var fileURL: URL {
        get throws {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = appSupport.appendingPathComponent("Remora", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent("config.json")
        }
    }

    private init() {}

    func load() throws {
        let url = try fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            config = .default
            return
        }
        do {
            let data = try Data(contentsOf: url)
            config = try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            throw RemoraError.configLoadFailed(underlying: error)
        }
    }

    func save() throws {
        let url = try fileURL
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: url, options: .atomic)
        } catch {
            throw RemoraError.configSaveFailed(underlying: error)
        }
    }

    func update(_ newConfig: AppConfig) throws {
        config = newConfig
        try save()
    }

    func addShare(_ share: ShareConfig) throws {
        config.shares.append(share)
        try save()
    }

    func updateShare(_ share: ShareConfig) throws {
        guard let index = config.shares.firstIndex(where: { $0.id == share.id }) else { return }
        config.shares[index] = share
        try save()
    }

    func removeShare(id: UUID) throws {
        config.shares.removeAll { $0.id == id }
        try save()
    }

    func addQuietHour(_ range: QuietHourRange) throws {
        config.quietHours.append(range)
        try save()
    }

    func removeQuietHour(at index: Int) throws {
        guard config.quietHours.indices.contains(index) else { return }
        config.quietHours.remove(at: index)
        try save()
    }
}
