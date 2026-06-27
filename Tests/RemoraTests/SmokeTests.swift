import Testing
import Foundation
@testable import Remora

@Suite("QuietHours Tests")
struct QuietHoursTests {
    @Test("日跨ぎなし: 範囲内")
    func withinRangeNoOvernight() {
        let range = QuietHourRange(start: "10:00", end: "18:00")
        let date = Calendar.current.date(from: DateComponents(hour: 14, minute: 0))!
        #expect(QuietHours.isInRange(range, at: date))
    }

    @Test("日跨ぎなし: 範囲外")
    func outsideRangeNoOvernight() {
        let range = QuietHourRange(start: "10:00", end: "18:00")
        let date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0))!
        #expect(!QuietHours.isInRange(range, at: date))
    }

    @Test("日跨ぎあり: 23:00-07:00 の深夜")
    func overnightRangeMidnight() {
        let range = QuietHourRange(start: "23:00", end: "07:00")
        let date = Calendar.current.date(from: DateComponents(hour: 2, minute: 0))!
        #expect(QuietHours.isInRange(range, at: date))
    }

    @Test("日跨ぎあり: 23:00-07:00 の昼間")
    func overnightRangeAfternoon() {
        let range = QuietHourRange(start: "23:00", end: "07:00")
        let date = Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!
        #expect(!QuietHours.isInRange(range, at: date))
    }

    @Test("境界値: ちょうど開始時刻")
    func atStartBoundary() {
        let range = QuietHourRange(start: "10:00", end: "18:00")
        let date = Calendar.current.date(from: DateComponents(hour: 10, minute: 0))!
        #expect(QuietHours.isInRange(range, at: date))
    }

    @Test("境界値: ちょうど終了時刻 (範囲外)")
    func atEndBoundary() {
        let range = QuietHourRange(start: "10:00", end: "18:00")
        let date = Calendar.current.date(from: DateComponents(hour: 18, minute: 0))!
        #expect(!QuietHours.isInRange(range, at: date))
    }

    @Test("start == end: 休止なし扱い")
    func startEqualsEnd() {
        let range = QuietHourRange(start: "12:00", end: "12:00")
        let date = Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!
        #expect(!QuietHours.isInRange(range, at: date))
    }

    @Test("isQuiet: 範囲0個")
    func isQuietNoRanges() {
        let date = Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!
        #expect(!QuietHours.isQuiet(ranges: [], at: date))
    }

    @Test("isQuiet: 複数範囲のOR判定")
    func isQuietMultipleRanges() {
        let ranges = [
            QuietHourRange(start: "00:00", end: "06:00"),
            QuietHourRange(start: "22:00", end: "24:00"),
        ]
        let morning = Calendar.current.date(from: DateComponents(hour: 3, minute: 0))!
        let afternoon = Calendar.current.date(from: DateComponents(hour: 14, minute: 0))!
        #expect(QuietHours.isQuiet(ranges: ranges, at: morning))
        #expect(!QuietHours.isQuiet(ranges: ranges, at: afternoon))
    }
}

@Suite("ConfigStore Round-Trip Tests")
struct ConfigStoreTests {
    @Test("AppConfig.default の encode->decode round-trip")
    func defaultConfigRoundTrip() throws {
        let config = AppConfig.default
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        #expect(decoded.checkIntervalSeconds == config.checkIntervalSeconds)
        #expect(decoded.consecutiveFailuresBeforeNotify == config.consecutiveFailuresBeforeNotify)
        #expect(decoded.quietHours.count == config.quietHours.count)
        #expect(decoded.shares.count == config.shares.count)
    }

    @Test("ShareConfig の UUID, Bool フィールドが保持されること")
    func shareConfigFieldsPreserved() throws {
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
        #expect(decoded.id == id)
        #expect(decoded.enabled == false)
        #expect(decoded.host == "192.168.1.10")
    }

    @Test("QuietHourRange の境界値が保持されること")
    func quietHourRangePreserved() throws {
        let range = QuietHourRange(start: "00:00", end: "23:59")
        let encoder = JSONEncoder()
        let data = try encoder.encode(range)
        let decoded = try JSONDecoder().decode(QuietHourRange.self, from: data)
        #expect(decoded.start == "00:00")
        #expect(decoded.end == "23:59")
    }
}

@Suite("MountManager URL Tests")
struct MountManagerTests {
    @Test("通常ケースの SMB URL 組み立て")
    func normalSMBURL() {
        let url = MountManager.buildSMBURL(username: "user", host: "192.168.1.10", shareName: "share")
        #expect(url != nil)
        #expect(url?.scheme == "smb")
        #expect(url?.host == "192.168.1.10")
        #expect(url?.user == "user")
        #expect(url?.path == "/share")
    }

    @Test("ユーザー名に @ を含む: パーセントエンコード")
    func usernameWithAtSign() {
        let url = MountManager.buildSMBURL(username: "user@domain", host: "192.168.1.10", shareName: "share")
        #expect(url != nil)
        let urlString = url?.absoluteString ?? ""
        #expect(!urlString.contains("@@"))
    }

    @Test("共有名にスペースを含む: %20")
    func shareNameWithSpace() {
        let url = MountManager.buildSMBURL(username: "user", host: "192.168.1.10", shareName: "my share")
        #expect(url != nil)
        let path = url?.path ?? ""
        #expect(path.contains("my") && path.contains("share"))
    }

    @Test("空文字列: nil を返す")
    func emptyStrings() {
        #expect(MountManager.buildSMBURL(username: "", host: "192.168.1.10", shareName: "share") == nil)
        #expect(MountManager.buildSMBURL(username: "user", host: "", shareName: "share") == nil)
        #expect(MountManager.buildSMBURL(username: "user", host: "192.168.1.10", shareName: "") == nil)
    }
}
