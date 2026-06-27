import XCTest
import Foundation
@testable import Remora

final class ShareFormStateTests: XCTestCase {

    // MARK: - init(from:)

    func testInitFromShareCopiesAllFields() {
        let id = UUID()
        let share = ShareConfig(
            id: id,
            host: "192.168.11.105",
            shareName: "share",
            username: "kuninet",
            mountPoint: "/Volumes/share",
            enabled: true
        )

        let form = ShareFormState(from: share)

        XCTAssertEqual(form.host, "192.168.11.105")
        XCTAssertEqual(form.shareName, "share")
        XCTAssertEqual(form.username, "kuninet")
        XCTAssertEqual(form.mountPoint, "/Volumes/share")
        XCTAssertTrue(form.enabled)
    }

    func testInitFromDisabledSharePreservesEnabledFalse() {
        let share = ShareConfig(
            id: UUID(),
            host: "h",
            shareName: "s",
            username: "u",
            mountPoint: "/Volumes/s",
            enabled: false
        )

        let form = ShareFormState(from: share)

        XCTAssertFalse(form.enabled)
    }

    func testEmptyInitProducesEmptyEnabledForm() {
        let form = ShareFormState()

        XCTAssertEqual(form.host, "")
        XCTAssertEqual(form.shareName, "")
        XCTAssertEqual(form.username, "")
        XCTAssertEqual(form.mountPoint, "")
        XCTAssertTrue(form.enabled, "new share should default to enabled")
    }

    // MARK: - isValid

    func testIsValidRequiresHostShareNameUsername() {
        var form = ShareFormState()
        XCTAssertFalse(form.isValid)

        form.host = "h"
        XCTAssertFalse(form.isValid)

        form.shareName = "s"
        XCTAssertFalse(form.isValid)

        form.username = "u"
        XCTAssertTrue(form.isValid)
    }

    func testIsValidDoesNotRequireMountPoint() {
        var form = ShareFormState()
        form.host = "h"; form.shareName = "s"; form.username = "u"
        form.mountPoint = ""
        XCTAssertTrue(form.isValid)
    }

    // MARK: - toShare()

    func testToShareUsesExistingIDWhenProvided() {
        let id = UUID()
        var form = ShareFormState()
        form.host = "h"; form.shareName = "s"; form.username = "u"

        let share = form.toShare(existingID: id)

        XCTAssertEqual(share.id, id, "edits must preserve the original UUID")
    }

    func testToShareGeneratesNewIDWhenNoneProvided() {
        var form = ShareFormState()
        form.host = "h"; form.shareName = "s"; form.username = "u"

        let a = form.toShare()
        let b = form.toShare()

        XCTAssertNotEqual(a.id, b.id, "each new-add call must mint a fresh UUID")
    }

    func testToShareFillsMountPointFromShareNameWhenEmpty() {
        var form = ShareFormState()
        form.host = "h"; form.shareName = "movies"; form.username = "u"
        form.mountPoint = ""

        let share = form.toShare()

        XCTAssertEqual(share.mountPoint, "/Volumes/movies")
    }

    func testToSharePreservesCustomMountPoint() {
        var form = ShareFormState()
        form.host = "h"; form.shareName = "movies"; form.username = "u"
        form.mountPoint = "/Users/me/mnt/movies"

        let share = form.toShare()

        XCTAssertEqual(share.mountPoint, "/Users/me/mnt/movies")
    }

    func testToShareCopiesScalarFields() {
        var form = ShareFormState()
        form.host = "192.168.11.105"
        form.shareName = "share"
        form.username = "kuninet"
        form.mountPoint = "/Volumes/share"
        form.enabled = false

        let share = form.toShare()

        XCTAssertEqual(share.host, "192.168.11.105")
        XCTAssertEqual(share.shareName, "share")
        XCTAssertEqual(share.username, "kuninet")
        XCTAssertEqual(share.mountPoint, "/Volumes/share")
        XCTAssertFalse(share.enabled)
    }

    // MARK: - autoFillMountPoint(forNewShareName:)

    func testAutoFillMountPointPopulatesWhenEmpty() {
        var form = ShareFormState()
        form.shareName = "foo"
        form.mountPoint = ""

        form.autoFillMountPoint(forNewShareName: "bar")

        XCTAssertEqual(form.mountPoint, "/Volumes/bar")
    }

    func testAutoFillMountPointUpdatesWhenMatchesPreviousShareName() {
        var form = ShareFormState()
        form.shareName = "foo"
        form.mountPoint = "/Volumes/foo"

        form.autoFillMountPoint(forNewShareName: "bar")

        XCTAssertEqual(form.mountPoint, "/Volumes/bar",
                       "mount point that mirrors the previous share name should track the rename")
    }

    func testAutoFillMountPointPreservesUserOverride() {
        var form = ShareFormState()
        form.shareName = "foo"
        form.mountPoint = "/Users/me/mnt/elsewhere"

        form.autoFillMountPoint(forNewShareName: "bar")

        XCTAssertEqual(form.mountPoint, "/Users/me/mnt/elsewhere",
                       "user-customised mount point must not be overwritten")
    }

    // MARK: - End-to-end roundtrip

    func testRoundtripSharePreservesEverything() {
        let original = ShareConfig(
            id: UUID(),
            host: "192.168.11.105",
            shareName: "share",
            username: "kuninet",
            mountPoint: "/Volumes/share",
            enabled: true
        )

        let form = ShareFormState(from: original)
        let restored = form.toShare(existingID: original.id)

        XCTAssertEqual(restored, original)
    }
}
