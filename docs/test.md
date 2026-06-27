# テスト手順

> ⚠ **`swift test` のローカル実行には Xcode 本体が必要です**。Command Line Tools (CLT) 単体には `XCTest.framework` が含まれないため、CLT のみの環境ではテストが起動しません。Xcode を入れたくない場合は、CI (GitHub Actions) の緑/赤を信用する運用にしてください。詳細は [build.md の「テストを実行する場合」](build.md#テストを実行する場合) を参照。

## ユニットテスト

```bash
# Xcode を有効化済みであることが前提
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer  # 一度だけ
swift test
```

CI でも同じコマンドが走り、PR ごとに緑/赤で判定されます。CI ランナー (`macos-latest`) には Xcode が同梱されているので、ローカルで動かなくても CI が緑なら品質保証はされています。

### テスト対象の範囲

純粋ロジックのみを対象とします。NetFS / Keychain / NSStatusBar の統合テストは環境依存のため書きません。

| テスト | ねらい |
|---|---|
| `QuietHours.isQuiet(at:)` | 単一範囲・複数範囲・日跨ぎ (23:00-07:00) ・境界値 (start 含む / end 含まない) |
| `AppConfig` の JSON round-trip | encode → decode で同値性を保つこと |
| `MountManager.buildSMBURL(...)` | URL エンコードのエッジケース (スペース・記号・日本語・@) |

### 個別実行

```bash
# 個別テスト
swift test --filter QuietHoursTests
swift test --filter ConfigStoreTests
swift test --filter MountManagerTests

# 詳細出力
swift test --verbose
```

### カバレッジ

明示的な目標値は設けていません。「純粋ロジックが壊れていないこと」をビルド緑/赤で保証することがゴールです。

## 手動検証

統合テストの代わりに、実機での手動チェックリストを用意します。リリースビルド (`make-app.sh` 後) で実施してください。

### 基本動作

- [ ] `swift build` が CLT のみで成功する
- [ ] `swift run` でメニューバーにアイコンが出現する
- [ ] 設定ウィンドウから共有を 1 件登録し、1 分以内に `/Volumes/<name>` がマウントされる
- [ ] Finder で手動で eject すると、1 分以内に再マウントされる

### 異常系

- [ ] Windows PC をシャットダウン → アイコンが「一部欠落」状態に。リトライは継続するが通知は出ない
- [ ] Windows PC を再起動 → 1 分以内に再マウントされる (スリープ復帰時は即時)

### 休止時間帯

- [ ] 現在時刻を含む休止時間帯を設定 → アイコンがグレー化、アプリ内ログに「inQuietHours」記録、マウント試行が走らない
- [ ] 日跨ぎの範囲 (例: 23:00-07:00) が深夜 1:00 で休止と判定される

### イベント駆動

- [ ] Wi-Fi を OFF/ON → ON 直後にアプリ内ログでマウント試行が走る
- [ ] スリープから復帰 → 復帰直後にアプリ内ログでマウント試行が走る

### UI

- [ ] メニュー「ログを表示…」でアプリ内ログウィンドウが開き、時刻付きで履歴が見える
- [ ] ログのフィルタ (INFO/NOTICE/ERROR) が機能する
- [ ] ログのコピー / クリア / Console.app を開く ボタンが機能する
- [ ] メニュー「Remoraを終了」で 1 クリックで終了し、アイコンが消える

### `.app` 配布

- [ ] `make-app.sh` で `build/Remora.app` が生成される
- [ ] `/Applications` にコピーし、初回起動で右クリック→開くで許可できる
- [ ] メニュー「ログイン時に自動起動」を ON → ログアウト/ログインで Remora が自動起動している

## ベンチマーク (任意)

CPU 負荷の指標として、Activity Monitor で常駐時の CPU 使用率を確認します。期待値:

- アイドル時: 0.0-0.1%
- マウント試行時: 一瞬上がるがすぐ収束

明らかに張り付いている場合はバグの可能性があります。
