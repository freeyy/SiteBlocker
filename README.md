<div align="center">

# SiteBlocker

**A native macOS app that blocks distracting websites on a schedule — enforced in the background, even when the app is closed.**

[English](README.md) · [中文](README.zh-CN.md)

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-2396F3)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

<img src="docs/screenshot.png" width="760" alt="SiteBlocker">

</div>

## Features

- 🗓️ **Per-site schedules** — block by time window and day of week (multiple windows, cross-midnight supported).
- 🛡️ **Enforced in the background** — a one-time-installed helper keeps blocking after you quit the app or reboot.
- ⚡ **Real-time** — edits apply to `/etc/hosts` within a couple of seconds.
- 🔒 **Secure DNS (DoH) blocking** — optionally stop browsers bypassing the block via DNS-over-HTTPS.
- 🪶 **Near-zero footprint** — the helper is spawn-and-exit; no resident process, near-zero memory.
- ✨ **Minimal, native SwiftUI** — a clean two-pane window; the only thing to configure is your sites.

<p align="center"><img src="docs/scheduling.png" width="640" alt="Scheduling a site"></p>

## How it works

SiteBlocker blocks a site by adding `127.0.0.1 <domain>` to `/etc/hosts`. Writing that file needs
root, so a tiny **background helper (守护进程)** — installed once with your password — does the
writing. It applies your schedules on time, re-applies if the file is changed, syncs your edits in
real time (via `launchd` `WatchPaths`), starts at login, and runs only for a moment at a time. The
GUI just edits a JSON config — quit it and blocking keeps working.

| Component | Role |
|---|---|
| `SiteBlockerCore` | Pure, fully-tested logic: schedule evaluation, hosts rendering, config |
| `site-blocker-helper` | The root tool the daemon runs to reconcile `/etc/hosts` |
| `SiteBlocker.app` | The SwiftUI GUI |
| LaunchDaemon | Runs the helper at login, on a short interval, and the instant the config changes |

Per-site status reads the **real `/etc/hosts`**, so it stays honest even if the file changed while
the app was closed: 🔴 blocked now · 🟠 scheduled but not enforced yet · ⚪️ idle · faint = disabled.

## Install

1. Download `SiteBlocker.app.zip` from the [latest release](../../releases/latest) and unzip it into **Applications**.
2. The app isn't notarized, so the first launch needs **right-click → Open** (or run
   `xattr -dr com.apple.quarantine /Applications/SiteBlocker.app`).
3. Open the **gear** (top-right) → **Install helper** — macOS asks for your admin password once.
4. Click **+** to add sites, then set their days and time windows.

## Build from source

Requires macOS 13+ and a Swift 6 toolchain (Xcode **Command Line Tools** is enough — no full Xcode).

```sh
make check   # run all tests (unit + integration)
make app     # build & package build/SiteBlocker.app
make run     # build, package, and launch
```

See [`docs/USER_STORIES.md`](docs/USER_STORIES.md) for the full behavior matrix.

## License

[MIT](LICENSE) © freeyy
