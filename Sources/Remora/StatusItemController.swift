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

    // MARK: - Icon

    private func updateIcon(states: [ShareMountState], isQuiet: Bool) {
        guard let button = statusItem?.button else { return }

        let base = baseMenuBarIcon()
        let badge: NSImage?

        if isQuiet {
            badge = badgeImage(systemName: "moon.fill", color: .systemGray)
        } else if states.isEmpty || states.allSatisfy({ $0.status == .mounted }) {
            badge = nil
        } else if states.allSatisfy({
            if case .failing = $0.status { return true }
            return $0.status == .unmounted
        }) {
            badge = badgeImage(systemName: "xmark.circle.fill", color: .systemRed)
        } else {
            badge = badgeImage(systemName: "exclamationmark.circle.fill", color: .systemYellow)
        }

        button.image = badge == nil ? base : compositeIcon(base: base, badge: badge!)
        button.contentTintColor = nil
        button.imagePosition = .imageOnly
    }

    private func baseMenuBarIcon() -> NSImage {
        if let img = NSImage(named: "MenuBarIcon") {
            img.isTemplate = true
            return img
        }
        return drawnMenuBarIcon()
    }

    private func drawnMenuBarIcon() -> NSImage {
        let size: CGFloat = 22
        let image = NSImage(size: NSSize(width: size, height: size))
        image.isTemplate = true
        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        ctx.setShouldAntialias(true)

        let f = size / 22.0
        let black = CGColor(gray: 0.0, alpha: 1.0)
        let white = CGColor(gray: 1.0, alpha: 1.0)

        let headX = 4.5 * f, tailX = 19.5 * f
        let bodyY = 9.0 * f, bodyHH = 3.8 * f
        let bulgeX = headX + (tailX - headX) * 0.38

        ctx.setFillColor(black)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: headX, y: bodyY))
        ctx.addCurve(
            to: CGPoint(x: tailX, y: bodyY + 2.5 * f),
            control1: CGPoint(x: bulgeX, y: bodyY + bodyHH),
            control2: CGPoint(x: tailX - 5 * f, y: bodyY + 3.8 * f)
        )
        ctx.addLine(to: CGPoint(x: tailX, y: bodyY - 2.5 * f))
        ctx.addCurve(
            to: CGPoint(x: headX, y: bodyY),
            control1: CGPoint(x: tailX - 5 * f, y: bodyY - 3.8 * f),
            control2: CGPoint(x: bulgeX, y: bodyY - bodyHH)
        )
        ctx.closePath()
        ctx.fillPath()

        // Tail fins
        ctx.beginPath()
        ctx.move(to: CGPoint(x: tailX, y: bodyY + 2.5 * f))
        ctx.addLine(to: CGPoint(x: tailX + 3.5 * f, y: bodyY + 7 * f))
        ctx.addLine(to: CGPoint(x: tailX + 1.5 * f, y: bodyY + 1.5 * f))
        ctx.closePath()
        ctx.fillPath()
        ctx.beginPath()
        ctx.move(to: CGPoint(x: tailX, y: bodyY - 2.5 * f))
        ctx.addLine(to: CGPoint(x: tailX + 3.5 * f, y: bodyY - 7 * f))
        ctx.addLine(to: CGPoint(x: tailX + 1.5 * f, y: bodyY - 1.5 * f))
        ctx.closePath()
        ctx.fillPath()

        // Suction disc
        let discCX = 6.2 * f, discCY = 14.5 * f
        let discRX = 2.5 * f, discRY = 5.5 * f
        ctx.setFillColor(black)
        ctx.beginPath()
        ctx.addEllipse(in: CGRect(
            x: discCX - discRX, y: discCY - discRY,
            width: discRX * 2, height: discRY * 2
        ))
        ctx.fillPath()

        ctx.setStrokeColor(white)
        ctx.setLineWidth(max(0.5, 0.9 * f))
        ctx.setLineCap(.round)
        for i in 0..<4 {
            let t = CGFloat(i) / 3.0
            let y = discCY - (discRY - 1.2 * f) + t * (discRY - 1.2 * f) * 2
            let dy = (y - discCY) / discRY
            guard abs(dy) <= 1.0 else { continue }
            let hw = discRX * sqrt(1.0 - dy * dy) - 0.8 * f
            if hw > 0.5 * f {
                ctx.beginPath()
                ctx.move(to: CGPoint(x: discCX - hw, y: y))
                ctx.addLine(to: CGPoint(x: discCX + hw, y: y))
                ctx.strokePath()
            }
        }

        image.unlockFocus()
        return image
    }

    private func badgeImage(systemName: String, color: NSColor) -> NSImage {
        let cfg = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
        guard let sym = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) else {
            return NSImage()
        }
        let tinted = NSImage(size: sym.size)
        tinted.lockFocus()
        color.set()
        sym.draw(at: .zero, from: NSRect(origin: .zero, size: sym.size),
                 operation: .sourceOver, fraction: 1.0)
        tinted.unlockFocus()
        return tinted
    }

    private func compositeIcon(base: NSImage, badge: NSImage) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let composite = NSImage(size: size)
        composite.lockFocus()
        base.draw(in: NSRect(x: 0, y: 2, width: 20, height: 18),
                  from: .zero, operation: .sourceOver, fraction: 1.0)
        let bSize = badge.size
        badge.draw(in: NSRect(x: size.width - bSize.width,
                              y: 0,
                              width: bSize.width,
                              height: bSize.height),
                   from: .zero, operation: .sourceOver, fraction: 1.0)
        composite.unlockFocus()
        return composite
    }

    // MARK: - Menu

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

        let quitItem = NSMenuItem(title: "Remoraを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Actions

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
