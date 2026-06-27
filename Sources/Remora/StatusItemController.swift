import AppKit
import Combine

@MainActor
final class StatusItemController {
    private let scheduler: Scheduler
    private let configStore: ConfigStore
    private let mountManager: MountManager
    private let loginItemManager: LoginItemManager

    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private var logWindowController: LogWindowController?
    private var cancellables: Set<AnyCancellable> = []

    private var currentStates: [ShareMountState] = []
    private var isQuietNow: Bool = false

    init(
        scheduler: Scheduler,
        configStore: ConfigStore,
        mountManager: MountManager,
        loginItemManager: LoginItemManager
    ) {
        self.scheduler = scheduler
        self.configStore = configStore
        self.mountManager = mountManager
        self.loginItemManager = loginItemManager
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(states: [], isQuiet: false)

        scheduler.statesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] states in
                guard let self else { return }
                self.currentStates = states
                self.isQuietNow = states.contains { $0.status == .inQuietHours }
                self.updateIcon(states: states, isQuiet: self.isQuietNow)
                self.rebuildMenu(states: states)
            }
            .store(in: &cancellables)

        configStore.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu(states: self?.currentStates ?? [])
            }
            .store(in: &cancellables)

        rebuildMenu(states: [])
    }

    private func updateIcon(states: [ShareMountState], isQuiet: Bool) {
        guard let button = statusItem?.button else { return }

        let symbolName: String
        let tintColor: NSColor?

        if isQuiet {
            symbolName = "externaldrive.badge.minus"
            tintColor = .systemGray
        } else if states.isEmpty || states.allSatisfy({ $0.status == .mounted }) {
            symbolName = "externaldrive.connected.to.line.below"
            tintColor = nil
        } else if states.allSatisfy({ if case .failing = $0.status { return true }; return $0.status == .unmounted }) {
            symbolName = "externaldrive.badge.xmark"
            tintColor = .systemRed
        } else {
            symbolName = "externaldrive.badge.exclamationmark"
            tintColor = .systemYellow
        }

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Remora")?
            .withSymbolConfiguration(config)

        button.image = image
        button.contentTintColor = tintColor
        button.imagePosition = .imageOnly
    }

    private func rebuildMenu(states: [ShareMountState]) {
        let menu = NSMenu()

        if configStore.config.shares.isEmpty {
            let emptyItem = NSMenuItem(title: "共有が登録されていません", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for state in states {
                let share = state.share
                let title: String
                switch state.status {
                case .mounted:
                    title = "✓ \(share.host)/\(share.shareName)"
                case .failing(let count):
                    title = "✗ \(share.host)/\(share.shareName) (失敗 \(count)回)"
                case .unmounted:
                    title = "○ \(share.host)/\(share.shareName)"
                case .inQuietHours:
                    title = "－ \(share.host)/\(share.shareName)"
                }

                let shareItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let submenu = NSMenu()

                let openItem = NSMenuItem(title: "Finderで開く", action: #selector(openInFinder(_:)), keyEquivalent: "")
                openItem.target = self
                openItem.representedObject = share.mountPoint
                submenu.addItem(openItem)

                let retryItem = NSMenuItem(title: "いま試行", action: #selector(retryNow(_:)), keyEquivalent: "")
                retryItem.target = self
                submenu.addItem(retryItem)

                let disconnectItem = NSMenuItem(title: "切断", action: #selector(disconnect(_:)), keyEquivalent: "")
                disconnectItem.target = self
                disconnectItem.representedObject = share
                submenu.addItem(disconnectItem)

                shareItem.submenu = submenu
                menu.addItem(shareItem)
            }
        }

        menu.addItem(.separator())

        let retryAllItem = NSMenuItem(title: "すべて試行", action: #selector(retryAll), keyEquivalent: "")
        retryAllItem.target = self
        menu.addItem(retryAllItem)

        let disconnectAllItem = NSMenuItem(title: "すべて切断", action: #selector(disconnectAll), keyEquivalent: "")
        disconnectAllItem.target = self
        menu.addItem(disconnectAllItem)

        menu.addItem(.separator())

        let logItem = NSMenuItem(title: "ログを表示…", action: #selector(openLogViewer), keyEquivalent: "")
        logItem.target = self
        menu.addItem(logItem)

        let settingsItem = NSMenuItem(title: "設定…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "ログイン時に自動起動",
            action: #selector(toggleLoginItem),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = loginItemManager.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "Remora について…", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Remoraを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func openInFinder(_ sender: NSMenuItem) {
        guard let mountPoint = sender.representedObject as? String else { return }
        MountManager.openInFinder(mountPoint: mountPoint)
    }

    @objc private func retryNow(_ sender: NSMenuItem) {
        scheduler.triggerNow()
    }

    @objc private func disconnect(_ sender: NSMenuItem) {
        guard let share = sender.representedObject as? ShareConfig else { return }
        Task {
            do {
                try await mountManager.unmount(share)
            } catch {
                RLog(.error, category: "menu", "切断失敗 \(share.host)/\(share.shareName): \(error.localizedDescription)")
            }
        }
    }

    @objc private func retryAll() {
        scheduler.triggerNow()
    }

    @objc private func disconnectAll() {
        Task {
            for share in configStore.config.shares {
                do {
                    try await mountManager.unmount(share)
                } catch {
                    RLog(.error, category: "menu", "切断失敗 \(share.host)/\(share.shareName): \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func openLogViewer() {
        if logWindowController == nil {
            logWindowController = LogWindowController()
        }
        logWindowController?.show()
    }

    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                configStore: configStore,
                loginItemManager: loginItemManager
            )
        }
        settingsWindowController?.show()
    }

    @objc private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Remora",
            .credits: NSAttributedString(string: "MIT License\nhttps://github.com/kuninet/Remora"),
        ])
    }

    @objc private func toggleLoginItem() {
        do {
            try loginItemManager.toggle()
        } catch {
            let alert = NSAlert()
            alert.messageText = "ログイン項目の変更に失敗しました"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
        rebuildMenu(states: currentStates)
    }
}
