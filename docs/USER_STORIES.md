# SiteBlocker — User Stories & Behavior Matrix

Each row is a behavior a user can trigger. "Verified by" is how we prove it holds:
**unit** (`make test`), **integration** (`make integration`, real helper binary vs temp files),
**UI** (offscreen render of the real `ContentView`), **live** (the installed system daemon on a
real machine), or **inspection** (plist/process).

## Mental model (aligned with the user)

- **Blocking works by writing `127.0.0.1 <domain>` into `/etc/hosts`.** That entry is persistent —
  it stays until something removes it. Writing `/etc/hosts` requires **root**, which the GUI app
  does not have.
- **The background helper (守护进程)** is the only thing that can write `/etc/hosts`. It is installed
  once (one password). It then: applies time-based schedules on time, syncs your edits in real time,
  re-applies if `/etc/hosts` is tampered with, runs at login, and works while the app is closed.
  It is **spawn-and-exit** (no resident process → near-zero memory). There is **no on/off switch** —
  to block, you enable individual sites.
- **Status is read from the real `/etc/hosts`**, not inferred — so it reflects reality even after
  the app was closed and the file changed underneath it.

## Helper / setup

| # | User story | Expected | Verified by |
|---|------------|----------|-------------|
| US1 | Helper not installed | Toolbar gear shows amber "needs attention"; Settings shows purpose + **Install helper** | UI |
| US2 | Install helper | Full-window loading overlay (not frozen) → password → success toast → status enforces | live |
| US3 | Cancel the password dialog | No change, no error toast (silent) | unit (cancellation path) + live |
| US4 | Uninstall helper | Loading overlay → `/etc/hosts` cleared → info toast → gear amber again | live |
| US5 | Auto-start at login | LaunchDaemon has `RunAtLoad`; loads at boot | inspection |
| US6 | Minimal footprint | No `KeepAlive` → spawn-and-exit → no resident process / ~0 memory between runs | inspection |

## Adding / editing sites

| # | User story | Expected | Verified by |
|---|------------|----------|-------------|
| US7 | Click + (toolbar or empty state) | New "new website" row, editor opens for editing | UI + unit |
| US8 | Type a messy URL and commit | Normalized: `https://www.X.com/p?q` → `x.com` | unit (Domain) |
| US9 | Type an invalid domain | Left as-is (still editable), no crash | unit |
| US10 | Click + again before naming | Reuses the existing blank row (no duplicates) | unit |
| US11 | Pick days / presets | Schedule summary updates ("Weekdays", "Mon Wed Fri"…) | unit + UI |
| US12 | Add/remove time windows | Summary updates; cross-midnight shows "next day" | unit + UI |
| US13 | Delete a site | Removed; selection moves to another site | unit |

## Status (the reported bug)

| # | User story | Expected | Verified by |
|---|------------|----------|-------------|
| US14 | Enabled, in-window, actually in hosts | "Blocked right now" (red) | unit + live |
| US15 | Enabled, in-window, NOT in hosts | "Scheduled now — background blocking is off" (amber) + "Turn on" → Settings | unit + UI |
| US16 | Enabled, out-of-window | "Not blocked right now" | unit |
| US17 | Disabled site | "Disabled" (faint) | unit |
| US18 | hosts changed while app closed | On next read, status reflects the real hosts content | unit (parser) + live |

## Real-time enforcement

| # | User story | Expected | Verified by |
|---|------------|----------|-------------|
| US19 | Toggle a site on | `/etc/hosts` updated by the daemon within ~3s; status → blocked | live |
| US20 | Toggle a site off | hosts entry removed in real time | live |
| US21 | Edit schedule | hosts re-reconciled in real time | live + integration |
| US22 | Secure DNS on, site active | DoH resolvers also null-routed; off → removed | integration + live |

## UI integrity (no anomalies)

| # | User story | Expected | Verified by |
|---|------------|----------|-------------|
| US23 | Open/close Settings | Opens as a sheet, Done closes it, no overlap | UI |
| US24 | During install/uninstall | Loading overlay covers the window and blocks interaction | UI (+ `.disabled`) |
| US25 | A toast appears | Floats at the bottom, auto-dismisses, never overlaps the toolbar | UI |
| US26 | No sites yet | Clear "Add Website" affordance in sidebar and detail | UI |
| US27 | Long domain / many windows | Truncates / scrolls; no layout break | UI |
| US28 | Restart the app | Config persists; old configs load (backward compatible) | unit + live |
