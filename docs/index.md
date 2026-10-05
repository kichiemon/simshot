---
layout: home

hero:
  name: simshot
  text: App Store screenshots.<br>Zero XCUITest.
  tagline: Capture App Store-ready screenshots from the iOS Simulator with <code>simctl</code> only — no test runner, no flaky element queries, no hangs.
  actions:
    - theme: brand
      text: Install
      link: /guide/installation
    - theme: alt
      text: Quick Start
      link: /guide/quickstart
---

<div class="demo">

![simshot demo](/demo.gif)

</div>

## Why simshot?

`fastlane snapshot` drives the UI through **XCUITest**, which means maintaining test targets, fighting flaky element queries, and dealing with runner crashes. simshot inverts the model: the **app itself** navigates to each scene (reading a documented launch-argument protocol), and simshot just drives `simctl` with a hard timeout on every step.

| | simshot | fastlane snapshot |
|---|---|---|
| UI automation | **None** — `simctl` only | XCUITest runner |
| Hangs | **Hard timeout on every command** | Can hang CI |
| Ruby | **No** | Ruby + fastlane + gems |
| Test target | `#if DEBUG` handler in your app | Dedicated UI test target |
| Status bar override | **Built in** | Plugin |
| Resize to App Store sizes | **Built in** (`--resize`) | Separate tooling |
| Multi-language | `--langs ja,en` | Per-locale setup |
| Dependency footprint | **Zero** | Dozens of gems |

<div class="feature-grid">

<div class="feature-card">
<h3>🚫 No XCUITest</h3>
<p>No test targets, no element queries, no runner crashes. The app navigates itself via a tiny <code>#if DEBUG</code> launch-argument handler.</p>
</div>

<div class="feature-card">
<h3>⏱️ Never hangs</h3>
<p>Every external command runs through a timeout + retry wrapper, so a stuck simulator or crashed app can never stall your CI.</p>
</div>

<div class="feature-card">
<h3>🌐 Multi-language</h3>
<p><code>--langs ja,en</code> re-launches each scene per locale via <code>-AppleLanguages</code> / <code>-AppleLocale</code>.</p>
</div>

<div class="feature-card">
<h3>📐 App Store-ready resize</h3>
<p><code>--resize</code> flattens alpha, matches the exact device aspect ratio, and writes the 1320×2868 / 1290×2796 / 1242×2688 / iPad sizes you submit.</p>
</div>

<div class="feature-card">
<h3>✅ Verifiable output</h3>
<p><code>simshot verify</code> fails CI when a screenshot has the wrong dimensions, an alpha channel, or a language that never got captured.</p>
</div>

<div class="feature-card">
<h3>📦 8 install paths</h3>
<p>Install script, curl one-liner, Homebrew, Nix, mise, npm, Mint, or build from source. A prebuilt binary ships for macOS arm64 + x86_64.</p>
</div>

<div class="feature-card">
<h3>🤖 AI-agent friendly</h3>
<p>Installable as a reusable skill for Claude Code, opencode, and Codex via <code>npx skills add kichiemon/simshot</code>.</p>
</div>

</div>

## Install

```bash
# Fastest: install script (detects arch, verifies sha256)
curl -fsSL https://raw.githubusercontent.com/kichiemon/simshot/main/install.sh | bash
```

<div class="install-grid">

```bash
# Homebrew
brew tap kichiemon/homebrew-tap
brew install simshot
```

```bash
# Single binary (curl)
curl -sL https://github.com/kichiemon/simshot/releases/download/v0.2.0/simshot-macos-arm64 -o /usr/local/bin/simshot && chmod +x /usr/local/bin/simshot
```

</div>

All eight install paths are documented in the [installation guide](/guide/installation).

<div class="badges">

<a href="https://github.com/kichiemon/simshot/actions/workflows/ci.yml">![CI](https://img.shields.io/github/actions/workflow/status/kichiemon/simshot/ci.yml?style=flat-square&label=CI)</a>
<a href="https://github.com/kichiemon/simshot/releases">![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square&logo=swift&logoColor=white)</a>
<a href="https://github.com/kichiemon/simshot">![License](https://img.shields.io/github/license/kichiemon/simshot?style=flat-square&color=blue)</a>
<a href="https://github.com/kichiemon/simshot/stargazers">![Stars](https://img.shields.io/github/stars/kichiemon/simshot?style=social)</a>
<a href="https://github.com/kichiemon/simshot/releases/tag/v0.2.0">![Version](https://img.shields.io/badge/version-v0.2.0-dc2626?style=flat-square)</a>

</div>

<div class="footer-links">

[GitHub repo](https://github.com/kichiemon/simshot)
[Discussions](https://github.com/kichiemon/simshot/discussions)
[Releases](https://github.com/kichiemon/simshot/releases)
[Install as a skill](https://github.com/kichiemon/simshot)
[Report an issue](https://github.com/kichiemon/simshot/issues)

</div>
