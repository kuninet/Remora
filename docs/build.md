# ビルド手順

ソースから Remora をビルドする手順をまとめます。

## 前提

- macOS 13 (Ventura) 以降
- Xcode Command Line Tools (約 1.5 GB) がインストール済み
  - 確認: `xcode-select -p` がパスを返す
  - 未インストールの場合: `xcode-select --install`
- **Xcode 本体 (10 GB+) は不要です**

## 確認

```bash
swift --version
# Apple Swift version 6.x が表示されればOK
```

## クローン

```bash
git clone https://github.com/kuninet/Remora.git
cd Remora
```

## 開発ビルド & 起動 (動作確認用)

```bash
swift run
```

- 起動するとメニューバーにアイコンが出現します (Dock には出ません)
- Ctrl-C で終了

## リリースビルド (`.app` バンドル生成)

```bash
./scripts/make-app.sh
```

実行内容:

1. `swift build -c release` でバイナリを生成
2. `build/Remora.app/Contents/{MacOS,Resources}` を組み立て
3. ビルドされたバイナリと `Info.plist`、`AppIcon.icns` を配置

成功すると `build/Remora.app` ができます。動作確認は次のとおり:

```bash
open build/Remora.app
```

## トラブルシュート

### `xcrun: error: invalid active developer path`

Command Line Tools が壊れているか未インストール。

```bash
sudo xcode-select --reset
xcode-select --install
```

### `error: missing required module`

`.build` キャッシュが壊れている可能性。

```bash
rm -rf .build
swift build
```

### `Code signing failed`

`.app` バンドルを `/Applications` 以外で `open` する場合、Gatekeeper が拒否することがあります。詳細は [install.md](install.md#初回起動時の-gatekeeper-対応) を参照。

## CI でのビルド

`.github/workflows/build.yml` が PR ごとに `swift build -c release` と `swift test` を実行し、緑/赤で結果を返します。手元でも同じ手順で動作を保証できます。
