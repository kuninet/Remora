# リリース手順

Remora のリリースは GitHub Actions が引き受けます。手元では **タグを 1 本打って push するだけ**です。

## いつもの流れ

```bash
# main が緑であること、変更が全部マージ済みであることを確認してから

git switch main
git pull --ff-only

git tag v1.2          # ← v + バージョン
git push origin v1.2
```

`v1.2` というタグの push を検知して `.github/workflows/release.yml` が走り、以下を自動でやります。

1. `Resources/Info.plist` の `CFBundleShortVersionString` をタグから `v` を除いた `1.2` に上書き
2. `./scripts/make-app.sh` で `build/Remora.app` を生成
3. `ditto` で `Remora-v1.2.zip` に固める
4. GitHub Release `Remora v1.2` を作成し、ZIP を添付。前回タグからのコミットからリリースノートを自動生成

数分後、リポジトリの Releases に新しいエントリが出ます。

## バージョン番号の付け方 (暫定)

詳細は [Issue #47](https://github.com/kuninet/Remora/issues/47) で議論中ですが、現状の暫定方針:

- `v1.0` から開始
- 機能追加で `v1.1`、`v1.2` ... と 0.1 ずつ上げる
- 大きな仕様変更があれば `v2.0`
- 軽い修正だけのリリースは `v1.2.1` のように patch 桁を追加してもよい

## やってはいけないこと

- **既存タグの強制上書き**: 一度公開したタグ (`v1.0` など) は打ち直さない。修正したい場合は `v1.0.1` で出し直す。古いタグを動かすとダウンロード済みユーザーが混乱する
- **GitHub の Release UI からアセットを手動で差し替える**: 何が入っているか分からなくなる。再ビルドが必要なら新タグを切る

## リリースが失敗したとき

GitHub Actions の Release ワークフローが赤になった場合:

1. Actions のログから失敗箇所を確認 (`build`, `package`, `create release` のどれか)
2. 原因を main で修正してマージ
3. 失敗したタグを削除して打ち直す:
   ```bash
   git push --delete origin v1.2     # リモートから消す
   git tag -d v1.2                   # ローカルからも消す
   # 修正反映後
   git tag v1.2
   git push origin v1.2
   ```
4. ワークフロー再実行を確認

なお、**Release が既に作成されている状態でリラン**すると `softprops/action-gh-release` が既存 Release を更新します。アセットだけ作り直したい場合はこの挙動を活用できます。

## ローカルで .app の中身だけ確認したいとき

リリースを作らずに ZIP の中身だけ見たい場合:

```bash
./scripts/make-app.sh
ditto -c -k --sequesterRsrc --keepParent build/Remora.app /tmp/Remora-test.zip
open /tmp/Remora-test.zip       # Finder が自動で展開
```

CI と同じ ZIP 構造が手元で確認できます。
