import Foundation
import os

enum LogLevel: String, Codable, CaseIterable, Sendable {
    case info
    case notice
    case error
}

struct LogEntry: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let level: LogLevel
    let category: String
    let message: String
}

actor LogStore {
    static let shared = LogStore()

    private(set) var entries: [LogEntry] = []
    private let maxEntries = 500

    private var continuations: [UUID: AsyncStream<[LogEntry]>.Continuation] = [:]

    private let osLog = Logger(subsystem: "com.kuninet.Remora", category: "general")

    private init() {}

    func append(level: LogLevel, category: String, message: String) {
        let entry = LogEntry(
            id: UUID(),
            date: Date(),
            level: level,
            category: category,
            message: message
        )

        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        let categoryLogger = Logger(subsystem: "com.kuninet.Remora", category: category)
        switch level {
        case .info:
            categoryLogger.info("\(message, privacy: .public)")
        case .notice:
            categoryLogger.notice("\(message, privacy: .public)")
        case .error:
            categoryLogger.error("\(message, privacy: .public)")
        }

        let snapshot = entries
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    func clear() {
        entries = []
        let snapshot: [LogEntry] = []
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    func makeStream() -> AsyncStream<[LogEntry]> {
        let id = UUID()
        let currentEntries = entries
        return AsyncStream { continuation in
            continuation.yield(currentEntries)
            self.continuations[id] = continuation
            continuation.onTermination = { [id] _ in
                Task { await self.removeContinuation(id: id) }
            }
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}

func RLog(_ level: LogLevel, category: String = "general", _ message: String) {
    Task {
        await LogStore.shared.append(level: level, category: category, message: message)
    }
}
