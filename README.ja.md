# simcap

iOS シミュレータから **`simctl` だけで** App Store 提出用スクリーンショットを自動撮影する CLI です。**XCUITest 不要**・テストランナー起因のハングなし。

アプリ側は `#if DEBUG` で起動引数プロトコルを解釈する小さなハンドラを実装するだけ。あとは simcap が「ビルド → シミュレータ起動 → ステータスバー上書き → 各シーンへ launch → 撮影 → App Store サイズにリサイズ」までを一手に引き受けます。

```bash
simcap shoot --project Kanapp.xcodeproj --scheme Kanapp \
  --bundle-id dev.kichiemon.kanapp \
  --devices iphone-17-pro-max,ipad-pro-13 \
  --langs ja,en --shots shots.json --resize
```

## なぜ fastlane snapshot ではないのか

`fastlane snapshot` は **XCUITest** で UI を操作するため、テストターゲットの保守・壊れやすい要素クエリ・ランナークラッシュと戦うことになります。simcap はモデルを逆転させています。

- **アプリ自身**が各シーンへ遷移します（公開されている起動引数プロトコルを解釈）。
- simcap は `simctl`（`bootstatus` / `status_bar` / `launch` / `io screenshot`）を呼ぶだけ。全ステップにハードタイムアウト付きなので絶対にハングしません。
- テストバンドルも `XCUITest` も不要。`#if DEBUG` ハンドラと設定ファイルだけです。

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

### ソースからビルド

```bash
git clone https://github.com/kichiemon/simshot.git
cd simcap
swift build -c release
# バイナリは .build/release/simcap
ln -s "$(pwd)/.build/release/simcap" /usr/local/bin/simcap
```

### Homebrew (tap)

```bash
brew tap kichiemon/homebrew-tap
brew install simcap
```

Formula のひな型は [README.md](README.md#homebrew-tap-recommended) を参照してください。

## クイックスタート

1. アプリに[シーン起動引数ハンドラ](#screenshot-scene-protocol)を追加（5 分）。
2. 一度ビルドしてシミュレータを確認:

   ```bash
   simcap devices
   ```

3. `shots.json` を作成（[`examples/shots.json`](examples/shots.json) 参照）するか `--scenes` を使う:

   ```bash
   simcap shoot --project MyApp.xcodeproj --scheme MyApp \
     --bundle-id com.example.myapp \
     --devices iphone-17-pro-max,ipad-pro-13 \
     --langs ja,en --scenes home,detail,settings \
     --output appstore --resize
   ```

撮影結果は `appstore/<device>/<lang>/NN_name.png` に保存されます。

## コマンド

| コマンド | 説明 |
|---|---|
| `simcap shoot <options>` | ビルド・起動・撮影・リサイズを一括実行 |
| `simcap devices` | 利用可能なシミュレータ一覧（名前 + UDID） |
| `simcap version` | バージョン表示 |
| `simcap help` | ヘルプ表示 |

## `simcap shoot` オプション

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
  --derived-data <dir>             DerivedData パス（デフォルト: ~/.simcap/DerivedData）

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
simcap shoot ... --devices iphone-17-pro-max,ipad-pro-13
simcap shoot ... --devices 67DF6727-31BC-4246-9FC0-313A22FB2A6C
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

simcap はアプリを固定の引数セット付きで launch します。**シーン名とその動作はアプリ側の自由** — simcap は素通しするだけです。

| 引数 | 意味 |
|---|---|
| `--ui-testing` | 自動撮影セッションであることを伝える（オンボーディング等をスキップ）。 |
| `--screenshot-scene <scene>` | 起動直後に指定シーンへ遷移。 |
| `--screenshot-strokes <N>` | N 回のインタラクションを実行（例: なぞり N 画）。省略可。 |
| `--screenshot-scroll-bottom` | シーンを最下部までスクロールしてから撮影。省略可。 |

さらに simcap は常に `-AppleLanguages (lang)` と `-AppleLocale locale` も渡すため、アプリは指定言語で表示されます。

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
    /// スクリーンショット撮影専用: simcap の起動引数を解釈して該当画面へ直行する。
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
swift run simcap shoot --help
```

## ライセンス

[MIT](LICENSE)
