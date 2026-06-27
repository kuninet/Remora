# アーキテクチャ

Remora の内部構造とモジュール責務をまとめます。

## 全体像

Remora は単一の `.app` バンドルとして動作するメニューバー常駐アプリケーションです。アクティビティを駆動するのは以下の 3 種類のトリガーです。

1. **定期ポーリング**: 1 分ごとに各共有のマウント状態を確認
2. **システムイベント**: スリープ復帰・ネットワーク復帰の通知を受けて即時マウント試行
3. **ユーザー操作**: メニューや設定ウィンドウからの即時試行・切断・終了

```
┌─────────────────────────────────────────────────────────────────┐
│                         AppDelegate                              │
│  (NSApplication ライフサイクル、依存性のオーナーシップ)          │
└──────┬────────────────────────────────────────────────┬─────────┘
       │                                                │
       ▼                                                ▼
┌──────────────────┐                          ┌──────────────────┐
│ StatusItemCtrl   │ ◀─── 状態変化通知 ───── │  MountManager    │
│ (メニューバー)   │                          │  (NetFS 呼び出し) │
└──────┬───────────┘                          └────┬─────────────┘
       │                                            │
       │ メニュー項目クリック                       │ 1分ごと / 即時試行
       │                                            │
       ▼                                            ▼
┌──────────────────┐                          ┌──────────────────┐
│ SettingsWindow   │                          │   Scheduler      │
│ LogViewerWindow  │                          │   (Timer)        │
└──────┬───────────┘                          └────┬─────────────┘
       │                                            │
       ▼                                            ▼
┌──────────────────┐                          ┌──────────────────┐
│  ConfigStore     │ ◀──── 設定読み書き ──── │  EventMonitor    │
│  (JSON永続化)    │                          │ (Wake / Network) │
└──────┬───────────┘                          └──────────────────┘
       │
       ▼
┌──────────────────┐
│ KeychainStore    │
│ (パスワード分離)  │
└──────────────────┘
```

ログは横断的な存在です:

```
全モジュール ───▶ Log.shared ───▶ os.Logger (Console.app)
                              └─▶ リングバッファ (LogViewerWindow)
```

## モジュール一覧

| モジュール (ファイル) | 責務 |
|---|---|
| `main.swift` | `NSApplication` のエントリポイント。`AppDelegate` を結線して起動 |
| `AppDelegate.swift` | アプリのライフサイクル管理。各サービスのインスタンス化と結線 |
| `StatusItemController.swift` | メニューバーアイコン (`NSStatusItem`) とメニュー構築。状態に応じた SF Symbols アイコン切替 |
| `MountManager.swift` | `NetFSMountURLAsync` を用いた SMB マウント。`getmntinfo(3)` でのマウント済み判定 |
| `MountState.swift` | 共有ごとの状態モデル (`mounted` / `unmounted` / `failing(count)` / `inQuietHours`) |
| `Scheduler.swift` | `Timer` による定期ポーリングと、`EventMonitor` イベントを受けた即時試行のオーケストレーション |
| `EventMonitor.swift` | `NSWorkspace.didWakeNotification` と `NWPathMonitor` を購読してイベント発火 |
| `QuietHours.swift` | 時刻範囲の集合に対して「現在時刻が休止帯か」を判定 (日跨ぎ・複数範囲対応) |
| `ConfigStore.swift` | `AppConfig` / `ShareConfig` / `QuietHours` の JSON 永続化 (`~/Library/Application Support/Remora/config.json`) |
| `KeychainStore.swift` | パスワードの Keychain 保管 (`Service: "Remora"`, `Account: "<host>/<shareName>"`) |
| `LoginItemManager.swift` | `SMAppService.mainApp` を用いたログイン時自動起動の登録/解除 |
| `Notifier.swift` | UserNotifications による連続失敗通知 |
| `Log.swift` | `os.Logger` 出力 + インメモリリングバッファ (500 件) を保持。Combine/AsyncStream で UI へ配信 |
| `Settings/SettingsWindowController.swift` | 設定ウィンドウのライフサイクル |
| `Settings/SettingsView.swift` | SwiftUI: 共有 / 休止時間帯 / チェック間隔 / 自動起動の編集 UI |
| `LogViewer/LogWindowController.swift` | ログウィンドウのライフサイクル |
| `LogViewer/LogView.swift` | SwiftUI: リングバッファのライブ表示・フィルタ・コピー |
| `RemoraError.swift` | プロジェクト横断のエラー型 |

## データフロー

### 共有マウントの試行

```
Scheduler ─tick─▶ MountManager.checkAll()
                  ├─ QuietHours.isQuiet(now) なら全共有を inQuietHours 状態にして終了
                  ├─ getmntinfo(3) でマウント済みなら mounted 状態に更新
                  └─ 未マウントなら:
                     ├─ KeychainStore からパスワード取得
                     ├─ NetFSMountURLAsync("smb://user@host/share", mountPath)
                     ├─ 成功 → mounted、失敗 → failing(count++)
                     └─ Log.shared に経過を記録
```

### 設定変更

```
SettingsView 編集 ─▶ ConfigStore.save()
                    ├─ JSON ファイルに書き出し
                    ├─ Keychain にパスワード保存
                    └─ NotificationCenter または @Published で全購読者へ通知
                       ├─ StatusItemController がメニュー再構築
                       └─ Scheduler が新しい間隔/対象を再認識
```

## 並行性

- UI 層 (`StatusItemController`, `SettingsView`, `LogView`) は `@MainActor`
- `MountManager` および `Log` 内部状態は `actor` でスレッド安全
- ネットワーク I/O は `withCheckedThrowingContinuation` で NetFS の C コールバックを `async` 関数に変換
- `Timer` は `@MainActor` で発火し、`Task { await mountManager.checkAll() }` で actor 境界を越える

## 設定とデータ

設定ファイル: `~/Library/Application Support/Remora/config.json`

```json
{
  "checkIntervalSeconds": 60,
  "consecutiveFailuresBeforeNotify": 5,
  "quietHours": [
    { "start": "23:00", "end": "07:00" }
  ],
  "shares": [
    {
      "id": "uuid-...",
      "host": "192.168.1.10",
      "shareName": "shared",
      "username": "kuninet",
      "mountPoint": "/Volumes/shared",
      "enabled": true
    }
  ]
}
```

パスワードはこのファイルには含めず、Keychain に分離保管します。

## 設計判断のメモ

- **NetFS を選んだ理由**: macOS 標準。Keychain との親和性が高い。`mount_smbfs(8)` を `Process` で叩く実装よりエラーハンドリングが綺麗
- **SwiftUI を AppKit にホストする方針**: メニューバー常駐用のシェルは AppKit が安定。設定/ログの編集 UI はフォームベースで SwiftUI が圧倒的に短く書ける
- **休止時間帯を時刻範囲だけにした理由**: 曜日指定や祝日対応まで広げると設定 UI が複雑化する。当面は「夜は静かにしたい」程度のニーズに集中
- **Notarization をスコープ外にした理由**: 個人利用前提。配布範囲を広げる場合は別途検討
