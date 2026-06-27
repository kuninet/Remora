# Remora

> Keep your SMB shares mounted on macOS.

Remora は、Mac から Windows / NAS の SMB 共有フォルダを「離さない」ためのメニューバー常駐アプリケーションです。コバンザメ (英: *remora*) のように、対象の共有にぴたりとくっつき、外れたら静かに再接続を試み続けます。

## なぜ作ったのか

- Mac mini から Windows PC の共有フォルダにつないでも、しばらくすると外れる
- Windows PC をシャットダウン/再起動するとマウントが消える
- macOS の Login Items や Finder サイドバーだけでは、使用中のドロップアウトや相手側再起動からの自動復帰までは面倒を見てくれない

Remora は 1 分ごとに状態をチェックし、スリープ復帰やネットワーク復帰の瞬間にも再マウントを試みます。普段は通知も音もなく、メニューバーで静かに動き続けます。

## 主な特徴

- 複数の SMB 共有をまとめて監視・自動マウント
- スリープ復帰 / ネットワーク復帰で即座にマウント試行
- メニューバーアイコンで状態を一目で確認 (全マウント済み / 一部欠落 / 全失敗 / 休止中)
- 休止時間帯 (例: 23:00-07:00) を複数登録可能。夜間は静かに何もしない
- パスワードは macOS キーチェーンに分離保管
- 設定はすべて GUI から (CLI や設定ファイル手書きは不要)
- アプリ内ログビューワー + Console.app への詳細ログ出力
- ログイン時に自動起動 (SMAppService)
- Python などのランタイム非同梱の単体 `.app`

## ダウンロード

ビルド済みの `.app` がほしい場合は [Releases](https://github.com/kuninet/Remora/releases) から最新の `Remora-vX.Y.zip` を取得してください。展開した `Remora.app` を `/Applications` にドラッグするだけで使えます (初回起動時の流れは下記「初回起動時の注意」参照)。

## 必要環境

- macOS 13 (Ventura) 以降
- `.app` をビルドする場合: Xcode Command Line Tools (Xcode フル本体は不要)
- ローカルで `swift test` を走らせる場合のみ: Xcode 本体が必要 (`XCTest.framework` が CLT に同梱されないため)

## 初回起動時の注意

未署名アプリのため、初回起動・初回マウント時に macOS から次のダイアログが順に出ます。

- Gatekeeper の「開発元未確認」 — 右クリック → 開く で許可
- macOS の SMB 接続ダイアログ — 「パスワードをキーチェーンに保管」にチェックして接続
- キーチェーンアクセス許可 — **「常に許可」を選ぶ** (「許可」だとマウント試行のたびに再表示)

詳しい流れと「気にしなくていいログメッセージ」は [docs/install.md の 4 章](docs/install.md#4-初回マウント時に表示されるダイアログ) を参照してください。

## 使い方

| やりたいこと | ドキュメント |
|---|---|
| ソースからビルドしたい | [docs/build.md](docs/build.md) |
| `/Applications` に置いて使いたい | [docs/install.md](docs/install.md) |
| テストを実行したい | [docs/test.md](docs/test.md) |
| 内部構造を知りたい | [docs/architecture.md](docs/architecture.md) |
| リリースを切りたい (メンテナ向け) | [docs/release.md](docs/release.md) |

## ライセンス

MIT License — 詳細は [LICENSE](LICENSE) を参照。
