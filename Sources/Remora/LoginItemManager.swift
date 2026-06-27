import ServiceManagement
import Combine

@MainActor
final class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    @Published private(set) var isEnabled: Bool = false

    private init() {
        updateStatus()
    }

    private func updateStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func enable() throws {
        try SMAppService.mainApp.register()
        updateStatus()
    }

    func disable() throws {
        try SMAppService.mainApp.unregister()
        updateStatus()
    }

    func toggle() throws {
        if isEnabled {
            try disable()
        } else {
            try enable()
        }
    }
}
