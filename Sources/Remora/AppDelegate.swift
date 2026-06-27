import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var scheduler: Scheduler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let configStore = ConfigStore.shared
        do {
            try configStore.load()
        } catch {
            RLog(.error, category: "config", "設定ファイルの読み込みに失敗しました: \(error.localizedDescription)")
        }

        let mountManager = MountManager.shared
        let loginItemManager = LoginItemManager.shared
        let eventMonitor = EventMonitor()
        let scheduler = Scheduler(
            configStore: configStore,
            mountManager: mountManager,
            eventMonitor: eventMonitor
        )
        self.scheduler = scheduler

        let statusItemController = StatusItemController(
            scheduler: scheduler,
            configStore: configStore,
            mountManager: mountManager,
            loginItemManager: loginItemManager
        )
        self.statusItemController = statusItemController
        statusItemController.setup()

        Task {
            await Notifier.requestAuthorization()
        }

        scheduler.start()

        RLog(.info, category: "general", "Remora 起動完了")
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler?.stop()
        RLog(.info, category: "general", "Remora 終了")
    }
}
