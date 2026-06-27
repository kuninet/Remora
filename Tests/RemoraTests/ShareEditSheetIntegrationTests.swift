import XCTest
import AppKit
import SwiftUI
@testable import Remora

/// Integration tests that host `ShareEditSheet` in a real `NSHostingController`
/// and walk the resulting AppKit view tree. The idea is to catch the
/// "edit sheet shows empty fields even though existingShare was passed"
/// class of bugs which the pure data tests in `ShareFormStateTests` cannot see.
@MainActor
final class ShareEditSheetIntegrationTests: XCTestCase {

    func testEditSheetExposesExistingShareValuesInTextFields() throws {
        let share = ShareConfig(
            id: UUID(),
            host: "192.168.11.105",
            shareName: "share",
            username: "kuninet",
            mountPoint: "/Volumes/share",
            enabled: true
        )

        let sheet = ShareEditSheet(
            existingShare: share,
            onSave: { _, _ in },
            onCancel: {}
        )

        let host = NSHostingController(rootView: sheet)
        host.view.frame = NSRect(x: 0, y: 0, width: 600, height: 600)
        host.view.layoutSubtreeIfNeeded()

        let texts = collectTextValues(in: host.view)

        XCTAssertTrue(
            texts.contains("192.168.11.105"),
            "host field should expose 192.168.11.105 to the rendered view tree. Found: \(texts)"
        )
        XCTAssertTrue(
            texts.contains("share"),
            "shareName field should expose 'share'. Found: \(texts)"
        )
        XCTAssertTrue(
            texts.contains("kuninet"),
            "username field should expose 'kuninet'. Found: \(texts)"
        )
        XCTAssertTrue(
            texts.contains("/Volumes/share"),
            "mountPoint field should expose '/Volumes/share'. Found: \(texts)"
        )
    }

    func testNewShareSheetHasBlankFields() throws {
        let sheet = ShareEditSheet(
            existingShare: nil,
            onSave: { _, _ in },
            onCancel: {}
        )

        let host = NSHostingController(rootView: sheet)
        host.view.frame = NSRect(x: 0, y: 0, width: 600, height: 600)
        host.view.layoutSubtreeIfNeeded()

        let texts = collectTextValues(in: host.view)
        let plausibleHosts = ["192.168.11.105", "share", "kuninet", "/Volumes/share"]
        for unwanted in plausibleHosts {
            XCTAssertFalse(
                texts.contains(unwanted),
                "new-share sheet must not show \(unwanted)"
            )
        }
    }

    // MARK: - View tree traversal

    /// Walks the AppKit view tree under `root` and returns every string
    /// surface we can find: NSTextField stringValue, NSTextField placeholder,
    /// NSText (text editing field) string, NSButton title, etc.
    private func collectTextValues(in root: NSView) -> Set<String> {
        var out: Set<String> = []
        traverse(root, into: &out)
        return out
    }

    private func traverse(_ view: NSView, into out: inout Set<String>) {
        if let tf = view as? NSTextField {
            let s = tf.stringValue
            if !s.isEmpty { out.insert(s) }
        }
        if let text = view as? NSText {
            let s = text.string
            if !s.isEmpty { out.insert(s) }
        }
        if let button = view as? NSButton {
            if !button.title.isEmpty { out.insert(button.title) }
        }
        for sub in view.subviews {
            traverse(sub, into: &out)
        }
    }
}
