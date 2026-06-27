import AppKit
import Network

@MainActor
final class EventMonitor {
    var onWake: (() -> Void)?
    var onNetworkRestore: (() -> Void)?

    private var wakeObserver: NSObjectProtocol?
    private var pathMonitor: NWPathMonitor?
    private var previousStatus: NWPath.Status?
    private let monitorQueue = DispatchQueue(label: "com.kuninet.Remora.network")

    func start() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                RLog(.info, category: "event", "スリープ復帰を検知")
                self?.onWake?()
            }
        }

        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let prev = self.previousStatus
                self.previousStatus = path.status
                if prev == .unsatisfied && path.status == .satisfied {
                    RLog(.info, category: "event", "ネットワーク復帰を検知")
                    self.onNetworkRestore?()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func stop() {
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }
        pathMonitor?.cancel()
        pathMonitor = nil
    }
}
