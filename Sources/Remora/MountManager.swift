import Foundation
import NetFS
import AppKit

actor MountManager {
    static let shared = MountManager()

    private(set) var states: [UUID: ShareMountState] = [:]

    private init() {}

    func isMounted(_ share: ShareConfig) -> Bool {
        var statfsPtr: UnsafeMutablePointer<statfs>? = nil
        let count = getmntinfo(&statfsPtr, MNT_NOWAIT)
        guard count > 0, let stats = statfsPtr else { return false }

        let mountPoint = share.mountPoint
        for i in 0..<Int(count) {
            let stat = stats[i]
            let fstypename = withUnsafeBytes(of: stat.f_fstypename) { ptr in
                String(bytes: ptr.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
            }
            let mntonname = withUnsafeBytes(of: stat.f_mntonname) { ptr in
                String(bytes: ptr.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
            }
            if fstypename == "smbfs" && mntonname == mountPoint {
                return true
            }
        }
        return false
    }

    func mount(_ share: ShareConfig) async throws {
        guard let url = MountManager.buildSMBURL(
            username: share.username,
            host: share.host,
            shareName: share.shareName
        ) else {
            throw RemoraError.mountFailed(-1)
        }

        let password = try KeychainStore.password(for: KeychainKey(host: share.host, shareName: share.shareName))

        let capturedShare = share
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let openOptions: NSMutableDictionary = [
                kNetFSAllowLoopbackKey as String: false,
                kNetFSUseGuestKey as String: false,
                kNetFSUseKerberosKey as String: false,
            ]
            let mountOptions: NSMutableDictionary = [:]

            if let pw = password {
                openOptions[kNetFSPasswordKey as String] = pw
            }

            Task.detached(priority: .background) {
                let result = NetFSMountURLSync(
                    url as CFURL,
                    nil,
                    capturedShare.username as CFString,
                    nil,
                    openOptions,
                    mountOptions,
                    nil
                )

                if result == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: Self.mapNetFSError(result, share: capturedShare))
                }
            }
        }
    }

    func unmount(_ share: ShareConfig) throws {
        let result = Darwin.unmount(share.mountPoint, 0)
        if result != 0 {
            throw RemoraError.unmountFailed(OSStatus(errno))
        }
    }

    func checkAll(config: AppConfig, isQuietNow: Bool) async -> [ShareMountState] {
        var results: [ShareMountState] = []

        for share in config.shares where share.enabled {
            var state = states[share.id] ?? ShareMountState(share: share, status: .unmounted)

            if isQuietNow {
                state.status = .inQuietHours
                states[share.id] = state
                results.append(state)
                continue
            }

            let mounted = isMounted(share)
            state.lastAttempt = Date()

            if mounted {
                state.status = .mounted
                state.lastError = nil
                states[share.id] = state
                results.append(state)
                continue
            }

            do {
                try await mount(share)
                state.status = .mounted
                state.lastError = nil
                RLog(.info, category: "mount", "マウント成功: \(share.host)/\(share.shareName)")
            } catch {
                let prevCount: Int
                if case .failing(let c) = state.status {
                    prevCount = c
                } else {
                    prevCount = 0
                }
                let newCount = prevCount + 1
                state.status = .failing(consecutiveCount: newCount)
                state.lastError = error.localizedDescription
                RLog(.error, category: "mount", "マウント失敗 (\(newCount)回目): \(share.host)/\(share.shareName) - \(error.localizedDescription)")
            }

            states[share.id] = state
            results.append(state)
        }

        return results
    }

    nonisolated static func buildSMBURL(username: String, host: String, shareName: String) -> URL? {
        guard !username.isEmpty, !host.isEmpty, !shareName.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "smb"
        components.host = host
        components.user = username
        components.path = "/\(shareName)"

        return components.url
    }

    nonisolated static func openInFinder(mountPoint: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: mountPoint))
    }

    private nonisolated static func mapNetFSError(_ status: Int32, share: ShareConfig) -> RemoraError {
        switch status {
        // NetFS framework errors
        case -6003:
            return .authFailed(share: share.shareName)
        case -6002:
            return .hostUnreachable(host: share.host)
        case -6004:
            return .shareNotFound(share: share.shareName)
        // POSIX errno values surfaced by mount_smbfs / kernel
        case EACCES, EPERM:
            return .authFailed(share: share.shareName)
        case ENOENT:
            return .shareNotFound(share: share.shareName)
        case EHOSTUNREACH, EHOSTDOWN, ENETUNREACH, ETIMEDOUT, ECONNREFUSED:
            return .hostUnreachable(host: share.host)
        default:
            return .mountFailed(OSStatus(status))
        }
    }
}
