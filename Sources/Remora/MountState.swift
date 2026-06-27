import Foundation

enum MountStatus: Sendable, Equatable {
    case mounted
    case unmounted
    case failing(consecutiveCount: Int)
    case inQuietHours
}

struct ShareMountState: Sendable {
    let share: ShareConfig
    var status: MountStatus
    var lastAttempt: Date?
    var lastError: String?

    func shouldNotify(threshold: Int) -> Bool {
        if case .failing(let count) = status {
            return count >= threshold
        }
        return false
    }
}
