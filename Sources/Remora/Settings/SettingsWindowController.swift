import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(configStore: ConfigStore, loginItemManager: LoginItemManager) {
        let view = SettingsView(configStore: configStore, loginItemManager: loginItemManager)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Remora 設定"
        window.setContentSize(NSSize(width: 560, height: 480))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
