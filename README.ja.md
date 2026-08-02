# simshot

**[English](README.md) · [日本語](README.ja.md) · [한국어](README.ko.md)**

![CI](https://img.shields.io/github/actions/workflow/status/kichiemon/simshot/ci.yml?style=flat-square&label=CI)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square&logo=swift&logoColor=white)
![License](https://img.shields.io/github/license/kichiemon/simshot?style=flat-square&color=blue)
![Stars](https://img.shields.io/github/stars/kichiemon/simshot?style=social)

iOS シミュレータから **`simctl` だけで** App Store 提出用スクリーンショットを自動撮影する CLI です。**XCUITest 不要**・テストランナー起因のハングなし。

![simshot demo](assets/demo.gif)

アプリ側は `#if DEBUG` で起動引数プロトコルを解釈する小さなハンドラを実装するだけ。あとは simshot が「ビルド → シミュレータ起動 → ステータスバー上書き → 各シーンへ launch → 撮影 → App Store サイズにリサイズ」までを一手に引き受けます。

```bash
simshot shoot --project Kanapp.xcodeproj --scheme Kanapp \
  --bundle-id dev.kichiemon.kanapp \
  --devices iphone-17-pro-max,ipad-pro-13 \
  --langs ja,en --shots shots.json --resize
```

## なぜ simshot なのか

`fastlane snapshot` は **XCUITest** で UI を操作するため、テストターゲットの保守・壊れやすい要素クエリ・ランナークラッシュと戦うことになります。simshot はモデルを逆転させています。**アプリ自身**が各シーンへ遷移し（公開されている起動引数プロトコルを解釈）、simshot は全ステップにハードタイムアウト付きの `simctl` を叩くだけです。

| | simshot | fastlane snapshot |
|---|---|---|
| UI 自動操作 | **不要** — `simctl` のみ | XCUITest ランナー |
| ハング | **全コマンドにハードタイムアウト** | CI を止めうる |
| Ruby | **不要** | Ruby + fastlane + gem |
| テストターゲット | アプリ内の `#if DEBUG` ハンドラ | 専用 UI テストターゲット |
| ステータスバー上書き | **内蔵** | プラグイン |
| App Store サイズへのリサイズ | **内蔵**（`--resize`） | 別ツール |
| 多言語 | `--langs ja,en` | ロケールごとの設定 |
| 依存の大きさ | **ゼロ** | gem 多数 |

## 動作の仕組み

1. `xcodebuild` で generic simulator 向けにビルド（`--app-path` で既存 `.app` も可）。
2. デバイス × 言語ごとに:
   - `simctl bootstatus <udid> -b` で起動＆待機。
   - `simctl status_bar <udid> override --time "9:41" --batteryState charged --batteryLevel 100 ...` でステータスバーを整える。
   - アプリをインストール（前回分はアンインストールしてクリーンに）。
   - ショットごとにシーン起動引数付きで launch → シーンが落ち着くまで待機 → `simctl io <udid> screenshot`。
3. 生データは `<output>/raw/<device>/<lang>/`、`--resize` 指定時はアルファ除去・リサイズ済みの提出用画像を `<output>/<device>/<lang>/` に出力。

外部コマンドはすべて **タイムアウト＋リトライ** 付きのラッパーを通すため、クラッシュやシミュレータ固着でも CI を止めません。

## インストール

### エージェントスキルとしてインストール (npx)

```bash
npx skills add kichiemon/simshot
```

simshot を再利用可能なエージェントスキルとして導入します（Claude Code / opencode 等のスキル対応エージェント向け）。インストール後はエージェントが自動で利用できます。「App Store スクリーンショットを撮影して」と頼むだけで、エージェントが `simshot shoot` を組み立てて実行します（詳細は [`skills/simshot/SKILL.md`](skills/simshot/SKILL.md) 参照）。

### ソースからビルド

```bash
git clone https://github.com/kichiemon/simshot.git
cd simshot
swift build -c release
# バイナリは .build/release/simshot
ln -s "$(pwd)/.build/release/simshot" /usr/local/bin/simshot
```

### 単体バイナリ (curl, macOS)

GitHub Releases から対応アーキテクチャのプリビルドバイナリを直接取得します（Swift ツールチェイン不要）:

```bash
# Apple Silicon (arm64)
curl -sL https://github.com/kichiemon/simshot/releases/download/v0.1.1/simshot-macos-arm64 -o /usr/local/bin/simshot && chmod +x /usr/local/bin/simshot

# Intel (x86_64)
curl -sL https://github.com/kichiemon/simshot/releases/download/v0.1.1/simshot-macos-x86_64 -o /usr/local/bin/simshot && chmod +x /usr/local/bin/simshot
```

### Nix

リポジトリには [`flake.nix`](flake.nix) が同梱されており、プリビルド単体バイナリを取得します（ソースビルドなし）:

```bash
nix run github:kichiemon/simshot          # インストールせず実行
nix profile install github:kichiemon/simshot   # プロファイルへインストール
```

### mise

[mise](https://mise.jdx.dev/) は GitHub Releases のアセットから simshot をインストールできます。**github backend** が推奨です（SLSA の出自・artifact attestation も検証します）:

```bash
mise use -g github:kichiemon/simshot   # グローバル設定へインストール
simshot --version                      # v0.1.1
```

従来の `ubi` backend（`mise use ubi:kichiemon/simshot`）も同じ `simshot-macos-{os}-{arch}` アセットを解決して動作しますが、mise で deprecated となり mise 2027.1.0 で削除予定です。

### Homebrew (tap)

```bash
brew tap kichiemon/homebrew-tap
brew install simshot
```

リリース済みバイナリをインストールする Formula は [`kichiemon/homebrew-tap`](https://github.com/kichiemon/homebrew-tap)（`Formula/simshot.rb`）にあります。

### npm（npmjs.com）

```bash
npm i -g simshot
npx simshot shoot
```

macOS（arm64 / x86_64）+ Node.js 14+ が必要です。`postinstall` で GitHub Releases から対応アーキテクチャのプリビルド単体バイナリをダウンロードし、sha256 を検証します（実装は [`npm/`](npm/)）。npm 版は publish 準備のみで、npm アカウントログインが必要なため未公開です。公開までは curl ワンライナー・Homebrew・Nix・mise を利用してください。

## クイックスタート

1. アプリに[シーン起動引数ハンドラ](#screenshot-scene-protocol)を追加（5 分）。
2. 環境確認とシミュレータ一覧:

   ```bash
   simshot doctor     # xcode-select / Xcode / simctl / ランタイムを診断
   simshot devices    # 利用可能なシミュレータ一覧
   ```

3. `shots.json` を作成（[`examples/shots.json`](examples/shots.json) 参照）するか `--scenes` を使う:

   ```bash
   simshot shoot --project MyApp.xcodeproj --scheme MyApp \
     --bundle-id com.example.myapp \
     --devices iphone-17-pro-max,ipad-pro-13 \
     --langs ja,en --scenes home,detail,settings \
     --output appstore --resize
   ```

撮影結果は `appstore/<device>/<lang>/NN_name.png` に保存されます。

## コマンド

| コマンド | 説明 |
|---|---|
| `simshot shoot <options>` | ビルド・起動・撮影・リサイズを一括実行 |
| `simshot devices` | 利用可能なシミュレータ一覧（名前 + UDID） |
| `simshot doctor` | ローカルの Xcode / シミュレータ環境を診断（問題があれば exit 1） |
| `simshot init` | コメント付き `simshot.yml` の雛形を生成 |
| `simshot version` | バージョン表示 |
| `simshot help` | ヘルプ表示 |

### `simshot doctor`

`xcode-select` / Xcode / `simctl` / iOS ランタイム / 利用可能シミュレータを検査し、異常があれば exit `1` を返します。新規マシンのセットアップ時や不具合報告の前に実行してください。

```text
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

## `simshot shoot` オプション

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

### デバイス指定

`--devices` はデバイス名でも UDID でも指定できます:

```bash
simshot shoot ... --devices iphone-17-pro-max,ipad-pro-13
simshot shoot ... --devices 67DF6727-31BC-4246-9FC0-313A22FB2A6C
```

名前は大文字小文字・ハイフン区切りを無視してマッチします。複数の iOS ランタイムに同名デバイスがある場合は **新しいランタイム** を優先します。出力サブディレクトリは渡した名前（UDID の場合はデバイス名のスラッグ）になります。

### ショット設定

`shots.json` でファイル名・シーン・待機秒を細かく制御できます。`name` と `scene` 以外は省略可能です。

```json
{
  "shots": [
    { "name": "04_home.png", "scene": "home", "wait": 8 },
    { "name": "01_trace.png", "scene": "trace", "strokes": 1, "wait": 6 },
    { "name": "06_store.png", "scene": "store", "wait": 8 },
    { "name": "07_store_tip.png", "scene": "store", "scrollBottom": true, "wait": 8 }
  ]
}
```

| フィールド | 型 | デフォルト | 意味 |
|---|---|---|---|
| `name` | string | — | 出力ファイル名（例 `04_home.png`） |
| `scene` | string | — | `--screenshot-scene` に渡すシーン名 |
| `strokes` | int | `nil` | `--screenshot-strokes` に渡す値 |
| `scrollBottom` | bool | `false` | `--screenshot-scroll-bottom` を渡す |
| `wait` | int | `6` | launch 後に撮影するまでの待機秒 |
| `uiTesting` | bool | `true` | `--ui-testing` を渡すか |

ファイル形式はショットの素の配列でも `{ "shots": [...] }` でも OK です。

## Screenshot scene protocol（シーン起動引数プロトコル）

simshot はアプリを固定の引数セット付きで launch します。**シーン名とその動作はアプリ側の自由** — simshot は素通しするだけです。

| 引数 | 意味 |
|---|---|
| `--ui-testing` | 自動撮影セッションであることを伝える（オンボーディング等をスキップ）。 |
| `--screenshot-scene <scene>` | 起動直後に指定シーンへ遷移。 |
| `--screenshot-strokes <N>` | N 回のインタラクションを実行（例: なぞり N 画）。省略可。 |
| `--screenshot-scroll-bottom` | シーンを最下部までスクロールしてから撮影。省略可。 |

さらに simshot は常に `-AppleLanguages (lang)` と `-AppleLocale locale` も渡すため、アプリは指定言語で表示されます。

### アプリ側の実装例（SwiftUI）

```swift
import SwiftUI

struct HomeView: View {
    @State private var path: [Character] = []
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            content
                .onAppear {
                    #if DEBUG
                    handleScreenshotScene()
                    #endif
                }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    #if DEBUG
    /// スクリーンショット撮影専用: simshot の起動引数を解釈して該当画面へ直行する。
    private func handleScreenshotScene() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--screenshot-scene"),
              index + 1 < args.count else { return }
        let scene = args[index + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch scene {
            case "detail":
                if let first = characters.first {
                    path = [first]
                }
            case "settings":
                showSettings = true
            default:
                break // "home" は初期画面
            }
        }
    }
    #endif
}
```

ハンドラは `#if DEBUG` の中にあるため、リリースビルドに混入しません。

## リサイズ

`--resize` で App Store 提出用画像を `<output>/<device>/<lang>/` に出力します:

1. 生画像の縦横比から対応する App Store サイズを選択（まず正確なピクセル一致を試み、次に縦横比で判定 — 同じ縦横比の iPad Pro 13" と iPad 10.2" を区別するため）。
2. アルファチャンネルを白背景に合成して除去。
3. 高品質補間（LANCZOS 相当）でリサイズし PNG で保存。

対応サイズ:

| サイズ | デバイス |
|---|---|
| 1320×2868 | iPhone 16 Pro Max / 17 Pro Max（6.9インチ） |
| 1290×2796 | iPhone 15 Pro Max（6.7インチ） |
| 1242×2688 | iPhone 11 Pro Max（6.5インチ） |
| 2064×2752 | iPad Pro 13インチ |
| 2048×2732 | iPad Pro 12.9インチ |
| 2266×1488 | iPad Pro 11インチ |
| 2160×1620 | iPad 10.2インチ |

該当するサイズがない場合（縦横比が 1% 以上ずれる場合）は警告して生画像のままにします。

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

## 信頼性

- **タイムアウト**: すべての外部コマンド（xcodebuild / simctl 等）は `--timeout` を超えると強制終了。シミュレータ固着でも CI を止めません。
- **リトライ**: `launch` / `install` / `screenshot` は失敗時に自動リトライ。
- **デバイスごとの分離**: 失敗したデバイスは報告してスキップし、マトリクス全体は続行します。
- **クリーンな状態**: インストール前にアンインストール。状態を残したい場合は `--no-clean` / `--keep-running`。

## 開発

```bash
swift build   # ビルド
swift test    # テスト実行
swift format lint --recursive Sources Tests   # コードスタイル
swift run simshot shoot --help
```

## ライセンス

[MIT](LICENSE)
