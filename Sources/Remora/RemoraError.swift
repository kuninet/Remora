import Foundation

enum RemoraError: Error, LocalizedError {
    case hostUnreachable(host: String)
    case authFailed(share: String)
    case shareNotFound(share: String)
    case mountFailed(OSStatus)
    case unmountFailed(OSStatus)
    case keychainReadFailed(OSStatus)
    case keychainWriteFailed(OSStatus)
    case configLoadFailed(underlying: Error)
    case configSaveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .hostUnreachable(let host):
            return "ホスト \(host) に到達できません"
        case .authFailed(let share):
            return "認証失敗: \(share)"
        case .shareNotFound(let share):
            return "共有フォルダが見つかりません: \(share)"
        case .mountFailed(let status):
            return "マウント失敗 (OSStatus: \(status))"
        case .unmountFailed(let status):
            return "アンマウント失敗 (OSStatus: \(status))"
        case .keychainReadFailed(let status):
            return "キーチェーン読み取り失敗 (OSStatus: \(status))"
        case .keychainWriteFailed(let status):
            return "キーチェーン書き込み失敗 (OSStatus: \(status))"
        case .configLoadFailed(let underlying):
            return "設定読み込み失敗: \(underlying.localizedDescription)"
        case .configSaveFailed(let underlying):
            return "設定保存失敗: \(underlying.localizedDescription)"
        }
    }
}
