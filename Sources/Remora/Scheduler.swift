import Foundation
import Combine

@MainActor
final class Scheduler {
    let statesPublisher: AnyPublisher<[ShareMountState], Never>

    private let statesSubject = PassthroughSubject<[ShareMountState], Never>()
    private let configStore: ConfigStore
    private let mountManager: MountManager
    private let eventMonitor: EventMonitor
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var checkInFlight = false

    init(configStore: ConfigStore, mountManager: MountManager, eventMonitor: EventMonitor) {
        self.configStore = configStore
        self.mountManager = mountManager
        self.eventMonitor = eventMonitor
        self.statesPublisher = statesSubject.eraseToAnyPublisher()
    }

    func start() {
        scheduleTimer()

        eventMonitor.onWake = { [weak self] in
            self?.triggerNow()
        }
        eventMonitor.onNetworkRestore = { [weak self] in
            self?.triggerNow()
        }
        eventMonitor.start()

        configStore.$config
            .dropFirst()
            .sink { [weak self] _ in
                self?.rescheduleTimer()
            }
            .store(in: &cancellables)

        // Timer.scheduledTimer only fires after `withTimeInterval`, leaving an
        // empty first checkIntervalSeconds window where nothing is mounted.
        // Run a check immediately so the menu bar reflects reality from
        // launch instead of after the first tick.
        triggerNow()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        eventMonitor.stop()
        cancellables.removeAll()
    }

    func triggerNow() {
        guard !checkInFlight else { return }
        checkInFlight = true
        Task { @MainActor [weak self] in
            defer { self?.checkInFlight = false }
            await self?.runCheck()
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(configStore.config.checkIntervalSeconds)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.triggerNow()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func rescheduleTimer() {
        scheduleTimer()
    }

    private func runCheck() async {
        let config = configStore.config
        let isQuietNow = QuietHours.isQuiet(ranges: config.quietHours)

        RLog(.info, category: "scheduler", "チェック開始 (quiet=\(isQuietNow))")

        let states = await mountManager.checkAll(config: config, isQuietNow: isQuietNow)
        statesSubject.send(states)

        for state in states {
            if state.shouldNotify(threshold: config.consecutiveFailuresBeforeNotify) {
                if case .failing(let count) = state.status {
                    Notifier.notifyFailure(share: state.share, consecutiveCount: count)
                }
            }
        }
    }
}
