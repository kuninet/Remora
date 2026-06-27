import AppKit
import SwiftUI

@MainActor
final class LogWindowController: NSWindowController {
    init() {
        let view = LogView()
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Remora ログ"
        window.setContentSize(NSSize(width: 720, height: 400))
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
