---
name: simshot
description: App Store スクリーンショット撮影 CLI「simshot」の使い方。simctl のみで XCUITest 不要・ハングなし。iOS シミュレータでアプリをビルド・起動し、シーン起動引数プロトコルで各画面へ遷移させて撮影し、App Store サイズへリサイズする。simshot shoot / simshot doctor / simshot init / simshot devices の実行、または「App Store スクリーンショット撮影」「simctl」「simshot shoot」に関連する依頼を受けたらこのスキルをロードする。
metadata:
  author: kichiemon
  version: "1.0.0"
---

# simshot — App Store スクリーンショット撮影 CLI

simshot は iOS シミュレータから App Store 提出用スクリーンショットを自動撮影する CLI です。**XCUITest を使わず `simctl` だけで**全自動で撮影するため、テストランナー起因のハングやフレークがありません。

- Repo: <https://github.com/kichiemon/simshot>
- macOS 13+ / Swift 5.9+ / 依存ゼロ（Foundation / CoreGraphics / ImageIO のみ）
- 対象: リリース前の iOS アプリの App Store スクリーンショット生成

ワークフローは「ビルド → シミュレータ起動 → ステータスバー上書き → 各シーンへ launch → 撮影 → App Store サイズへリサイズ」です。アプリ側は `#if DEBUG` で起動引数プロトコルを解釈する小さなハンドラを実装するだけです。

## インストール

エージェントがこのスキルを使う場合、通常は既にインストール済みです。手元で simshot CLI 自体が必要なら以下から:

### npx（エージェントスキルとして導入）

```bash
npx skills add kichiemon/simshot
```

Claude Code / opencode 等のスキル対応エージェントが自動利用できるようになります。インストール後は「App Store スクリーンショットを撮影して」と頼むだけで、エージェントが `simshot shoot` を組み立てて実行します。

### Homebrew（tap）

```bash
brew tap kichiemon/homebrew-tap
brew install simshot
```

### ソースからビルド

```bash
git clone https://github.com/kichiemon/simshot.git
cd simshot
swift build -c release
ln -s "$(pwd)/.build/release/simshot" /usr/local/bin/simshot
```

## クイックスタート

```bash
# 1. 環境診断（Xcode / simctl / ランタイム / シミュレータ）
simshot doctor

# 2. 利用可能なシミュレータを確認
simshot devices

# 3. 撮影実行（シーン名を直接指定する場合）
simshot shoot --project MyApp.xcodeproj --scheme MyApp \
  --bundle-id com.example.myapp \
  --devices iphone-17-pro-max,ipad-pro-13 \
  --langs ja,en --scenes home,detail,settings \
  --output appstore --resize
```

撮影結果は `appstore/<device>/<lang>/NN_name.png` に保存されます。

## simshot.yml 設定

`simshot init`（`--yes` で非対話）がコメント付き `simshot.yml` の雛形を生成します。これは `simshot shoot` に渡すオプションをドキュメント化したスキャフォールドです。**各キーは `simshot shoot` のフラグと 1:1 対応**しており、`simshot shoot` はこのファイルを自動では読み込みません。値を CLI フラグとして渡してください。

```bash
simshot init --yes   # → コメント付き simshot.yml が生成される
```

生成される雛形の抜粋:

```yaml
# simshot configuration
project: MyApp.xcodeproj              # Xcode project to build
# workspace: MyApp.xcworkspace        # Alternative: Xcode workspace
scheme: MyApp                         # Scheme to build
bundle-id: com.example.myapp          # App bundle identifier (required)
output: appstore                      # Output directory
resize: true                          # Also write App Store-ready resized copies

# Simulator names or UDIDs to capture.
devices:
  - iphone-17-pro-max
  - ipad-pro-13

# Languages to capture (locale is derived, or use --locales for overrides).
langs:
  - ja
  - en

# Scenes captured as one shot each. For per-shot control (wait, strokes,
# scrollBottom), use --shots <shots.json> instead (see examples/shots.json).
scenes:
  - home
  - detail
  - settings
```

ショットごとの制御（待機秒・strokes・scrollBottom）が必要なら `simshot shoot` に `--shots <shots.json>` を渡します。`examples/shots.json` を参照してください。

## シーン起動引数プロトコル仕様

simshot はアプリを固定の引数セット付きで launch します。**シーン名とその動作はアプリ側の自由** — simshot は素通しするだけです。このプロトコルは公開契約であり、変更時は `README.md` / `README.ja.md` / `README.ko.md` / `Sources/SimshotCore/ShotSpec.swift` を更新すること。

| 引数 | 意味 |
|---|---|
| `--ui-testing` | 自動撮影セッションであることを伝える（オンボーディング等をスキップ）。 |
| `--screenshot-scene <scene>` | 起動直後に指定シーンへ遷移。 |
| `--screenshot-strokes <N>` | N 回のインタラクションを実行（例: なぞり N 画）。省略可。 |
| `--screenshot-scroll-bottom` | シーンを最下部までスクロールしてから撮影。省略可。 |

さらに simshot は常に `-AppleLanguages (lang)` と `-AppleLocale locale` も渡すため、アプリは指定言語で表示されます（アプリ側の実装は不要）。

### アプリ側の実装例（SwiftUI）

完全なサンプルは `examples/DemoSceneHandler.swift` にあります。要点はルートビューの `onAppear` で起動引数を解釈し、該当シーンへ遷移するだけです:

```swift
#if DEBUG
private func handleScreenshotScene() {
    let args = ProcessInfo.processInfo.arguments
    guard let index = args.firstIndex(of: "--screenshot-scene"),
          index + 1 < args.count else { return }
    let scene = args[index + 1]
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        switch scene {
        case "detail":
            path = [first]
        case "settings":
            showSettings = true
        default:
            break // "home" は初期画面
        }
        if args.contains("--screenshot-strokes") { drawStrokes() }
        if args.contains("--screenshot-scroll-bottom") { scrollToBottom() }
    }
}
#endif
```

ハンドラは `#if DEBUG` の中にあるため、リリースビルドに混入しません。

## コマンドリファレンス

| コマンド | 説明 |
|---|---|
| `simshot shoot <options>` | ビルド・起動・撮影・リサイズを一括実行。 |
| `simshot devices` | 利用可能なシミュレータ一覧（名前 + UDID）。 |
| `simshot doctor` | ローカルの Xcode / シミュレータ環境を診断（問題があれば exit 1）。 |
| `simshot init [--yes] [--output <path>]` | コメント付き `simshot.yml` の雛形を生成。 |
| `simshot version` | バージョン表示。 |
| `simshot help` | ヘルプ表示。 |

### `simshot shoot`

```
BUILD
  --project <path.xcodeproj>       Xcode プロジェクト（--workspace と排他）
  --workspace <path.xcworkspace>   Xcode ワークスペース
  --scheme <name>                  Scheme 名
  --app-path <path.app>            ビルドせず既存 .app を使用

REQUIRED
  --bundle-id <id>                 バンドル ID
  --devices <list>                 シミュレータ名 or UDID（カンマ区切り）

SHOTS
  --shots <config.json>            ショット設定ファイル（{ "shots": [...] }）
  --scenes <list>                  ショートカット: シーンごとに 1 枚（例 home,trace）
  --wait <secs>                    --scenes 用の待機秒（デフォルト: 6）

LOCALIZATION
  --langs <list>                   言語（デフォルト: en）例: ja,en
  --locales <map>                  lang=locale 上書き（例 ja=ja_JP,en=en_US）

OUTPUT
  --output <dir>                   出力ディレクトリ（デフォルト: appstore）
  --resize                         App Store 提出用画像も出力（アルファ除去）
  --derived-data <dir>             DerivedData パス（デフォルト: ~/.simshot/DerivedData）

SIMULATOR
  --timeout <secs>                 外部コマンドのタイムアウト（デフォルト: 300）
  --status-bar-time <t>            ステータスバーの時計（デフォルト: 9:41）
  --status-bar-battery <n>         ステータスバーのバッテリー%（デフォルト: 100）
  --no-ui-testing                  --ui-testing を渡さない
  --no-clean                       インストール前にアンインストールしない
  --keep-running                   撮影後にシミュレータをシャットダウンしない

MISC
  --verbose, -v                    詳細出力
  --help, -h                       ヘルプ表示
```

- `--devices` はデバイス名（大文字小文字・ハイフン区切りを無視）でも UDID でも指定可能。同名が複数ランタイムにある場合は新しいランタイムを優先。
- `--shots` の JSON は `{ "shots": [...] }` 形式（素の配列でも可）。各ショットは `name` / `scene` 必須、`strokes` / `scrollBottom` / `wait`（既定 6） / `uiTesting`（既定 true）が任意。

### `simshot doctor`

`xcode-select` / Xcode / `simctl` / iOS ランタイム / 利用可能シミュレータを検査し、異常があれば exit `1` を返します。新規マシンのセットアップ時や不具合報告の前に実行してください。

```
$ simshot doctor
✅ xcode-select: /Applications/Xcode.app/Contents/Developer
✅ Xcode: Xcode 26.5
✅ simctl: found
✅ iOS runtimes: 7 installed
✅ Available simulators: 36 available

✅ All checks passed.
```

### `simshot init`

`simshot shoot` に渡すオプションをドキュメント化したコメント付き `simshot.yml` の雛形を生成します。デフォルトは対話式、`--yes` でプレースホルダ値のまま書き出します。

```bash
simshot init --yes   # → simshot.yml（コメント付きテンプレート）
```

## 出力ディレクトリ

```
appstore/
├── raw/
│   └── iphone-17-pro-max/
│       ├── ja/
│       │   ├── 04_home.png
│       │   └── 01_trace.png
│       └── en/
│           └── 04_home.png
└── iphone-17-pro-max/            # --resize: App Store 提出用
    └── ja/
        └── 04_home.png
```

`--resize` は生画像の縦横比から App Store サイズを選択し、アルファを白に合成して除去し、LANCZOS 相当の補間でリサイズして PNG で保存します。対応サイズは iPhone 1320×2868 / 1290×2796 / 1242×2688、iPad 2064×2752 / 2048×2732 / 2266×1488 / 2160×1620。縦横比が 1% 以上ずれる場合は警告して生画像のままにします。

## トラブルシューティング

### `simshot doctor` が失敗する（exit 1）

- **xcode-select / Xcode で fail**: Xcode 本体（コマンドライン・ツールだけではない）が入っているか確認。`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。
- **iOS runtimes で fail**: Xcode > Settings > Platforms から iOS ランタイムを追加。
- **Available simulators で warn**: `xcrun simctl create` か Xcode > Window > Devices and Simulators でデバイスを作成。

### `simshot shoot` がエラーになる

- **「Unknown device」**: `simshot devices` で名前/UDID を確認。`--devices` は新しいランタイム優先でマッチするが、明示的に UDID を渡すと確実。
- **画面が撮れない / 真っ黒**: アプリがシーン起動引数プロトコルを `#if DEBUG` で解釈しているか確認。`--no-ui-testing` を付けていると `--ui-testing` が渡らないため、オンボーディングが表示されることがある。
- **撮影が途中で固まる**: 全外部コマンドは `--timeout`（既定 300 秒）で強制終了され、launch / install / screenshot は自動リトライされます。`--timeout 600` に上げるか `--verbose` でどこで止まっているか確認。
- **リサイズされない**: `--resize` を付け忘れていないか。対応サイズから縦横比が 1% 以上ずれる場合も警告してスキップされます。
- **ビルドをスキップしたい**: `--app-path <path.app>` で既存の .app を使えます。

### クリーンな状態で撮影したい

デフォルトでアプリはアンインストール→インストールされ、撮影後にシミュレータはシャットダウンされます。状態を残したい場合は `--no-clean` / `--keep-running` を使います。

## 開発

```bash
swift build   # ビルド
swift test    # テスト実行
swift format lint --recursive Sources Tests   # コードスタイル
swift run simshot shoot --help
```
