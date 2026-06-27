import XCTest
import Foundation
@testable import Remora

final class QuietHoursTests: XCTestCase {
    func testWithinRangeNoOvernight() {
        let range = QuietHourRange(start: "10:00", end: "18:00")
        let date = Calendar.current.date(from: DateComponents(hour: 14, minute: 0))!
        XCTAssertTrue(QuietHours.isInRange(range, at: date))
    }

    func testOutsideRangeNoOvernight() {
        let range = QuietHourRange(start: "10:00", end: "18:00")
        let date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0))!
        XCTAssertFalse(QuietHours.isInRange(range, at: date))
    }

    func testOvernightRangeMidnight() {
        let range = QuietHourRange(start: "23:00", end: "07:00")
        let date = Calendar.current.date(from: DateComponents(hour: 2, minute: 0))!
        XCTAssertTrue(QuietHours.isInRange(range, at: date))
    }

    func testOvernightRangeAfternoon() {
        let range = QuietHourRange(start: "23:00", end: "07:00")
        let date = Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!
        XCTAssertFalse(QuietHours.isInRange(range, at: date))
    }

    func testAtStartBoundary() {
        let range = QuietHourRange(start: "10:00", end: "18:00")
        let date = Calendar.current.date(from: DateComponents(hour: 10, minute: 0))!
        XCTAssertTrue(QuietHours.isInRange(range, at: date))
    }

    func testAtEndBoundary() {
        let range = QuietHourRange(start: "10:00", end: "18:00")
        let date = Calendar.current.date(from: DateComponents(hour: 18, minute: 0))!
        XCTAssertFalse(QuietHours.isInRange(range, at: date))
    }

    func testStartEqualsEnd() {
        let range = QuietHourRange(start: "12:00", end: "12:00")
        let date = Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!
        XCTAssertFalse(QuietHours.isInRange(range, at: date))
    }

    func testIsQuietNoRanges() {
        let date = Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!
        XCTAssertFalse(QuietHours.isQuiet(ranges: [], at: date))
    }

    func testIsQuietMultipleRanges() {
        let ranges = [
            QuietHourRange(start: "00:00", end: "06:00"),
            QuietHourRange(start: "22:00", end: "23:59"),
        ]
        let morning = Calendar.current.date(from: DateComponents(hour: 3, minute: 0))!
        let afternoon = Calendar.current.date(from: DateComponents(hour: 14, minute: 0))!
        XCTAssertTrue(QuietHours.isQuiet(ranges: ranges, at: morning))
        XCTAssertFalse(QuietHours.isQuiet(ranges: ranges, at: afternoon))
    }
}

final class ConfigStoreTests: XCTestCase {
    func testDefaultConfigRoundTrip() throws {
        let config = AppConfig.default
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(decoded.checkIntervalSeconds, config.checkIntervalSeconds)
        XCTAssertEqual(decoded.consecutiveFailuresBeforeNotify, config.consecutiveFailuresBeforeNotify)
        XCTAssertEqual(decoded.quietHours.count, config.quietHours.count)
        XCTAssertEqual(decoded.shares.count, config.shares.count)
    }

    func testShareConfigFieldsPreserved() throws {
        let id = UUID()
        let share = ShareConfig(
            id: id,
            host: "192.168.1.10",
            shareName: "testshare",
            username: "user",
            mountPoint: "/Volumes/testshare",
            enabled: false
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(share)
        let decoded = try JSONDecoder().decode(ShareConfig.self, from: data)
        XCTAssertEqual(decoded.id, id)
        XCTAssertFalse(decoded.enabled)
        XCTAssertEqual(decoded.host, "192.168.1.10")
    }

    func testQuietHourRangePreserved() throws {
        let range = QuietHourRange(start: "00:00", end: "23:59")
        let encoder = JSONEncoder()
        let data = try encoder.encode(range)
        let decoded = try JSONDecoder().decode(QuietHourRange.self, from: data)
        XCTAssertEqual(decoded.start, "00:00")
        XCTAssertEqual(decoded.end, "23:59")
    }
}

final class MountManagerTests: XCTestCase {
    func testNormalSMBURL() {
        let url = MountManager.buildSMBURL(username: "user", host: "192.168.1.10", shareName: "share")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "smb")
        XCTAssertEqual(url?.host, "192.168.1.10")
        XCTAssertEqual(url?.user, "user")
        XCTAssertEqual(url?.path, "/share")
    }

    func testUsernameWithAtSign() {
        let url = MountManager.buildSMBURL(username: "user@domain", host: "192.168.1.10", shareName: "share")
        XCTAssertNotNil(url)
        let urlString = url?.absoluteString ?? ""
        XCTAssertFalse(urlString.contains("@@"))
    }

    func testShareNameWithSpace() {
        let url = MountManager.buildSMBURL(username: "user", host: "192.168.1.10", shareName: "my share")
        XCTAssertNotNil(url)
        let path = url?.path ?? ""
        XCTAssertTrue(path.contains("my") && path.contains("share"))
    }

    func testEmptyStrings() {
        XCTAssertNil(MountManager.buildSMBURL(username: "", host: "192.168.1.10", shareName: "share"))
        XCTAssertNil(MountManager.buildSMBURL(username: "user", host: "", shareName: "share"))
        XCTAssertNil(MountManager.buildSMBURL(username: "user", host: "192.168.1.10", shareName: ""))
    }
}
