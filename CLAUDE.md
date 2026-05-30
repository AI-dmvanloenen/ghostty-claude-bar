# ghostty-claude-bar — context & engineering memory

For whoever (Claude or Douwe) next develops this. Captures **why** the code is
the way it is, the dead-ends already explored, and the rules that must not
regress. `README.md` is the user-facing pitch; this is the engineering memory.

## What this is

A native **macOS menu-bar app** that shows which live **Claude Code** sessions
(running in **Ghostty** windows) need you right now — color-coded
working / needs-reply / idle / safe-to-close — and lets you act on them
(focus, close, rename, launch new) without leaving the dashboard.

- Repo: https://github.com/AI-dmvanloenen/ghostty-claude-bar (public, MIT), under the `AI-dmvanloenen` GitHub account.
- It is a **ground-up Swift rewrite** of an earlier Python + SwiftBar Claude Code skill that lives at `~/.claude/skills/tabs` (its `CLAUDE.md` has the original Python-era hard-won facts — some now outdated, see below). That skill stays untouched.

## Dev workflow

Requires macOS 14+ and a Swift 6 toolchain (Xcode 16+). SwiftPM, no Xcode project.

```sh
swift build            # build
swift test             # core unit tests (12, all in Tests/GhosttyClaudeBarCoreTests)
swift run ghostty-claude-bar          # run the menu-bar app
```

The repo lives at `~/GitHub/ghostty-claude-bar`. The app reads from `~/.claude`.

**Debug / utility flags on the binary** (run `$(swift build --show-bin-path)/ghostty-claude-bar <flag>`):
- `--print` — dump collected rows to stdout (no GUI). Best way to verify the data/matching layer fast.
- `--fonts` — list the registered bundled font families.
- `--open-report` — launch and immediately open the report window (handy for eyeballing UI).
- `--stop-hook` / `--notify-hook` — Claude Code hook entry points (read stdin, write a verdict sidecar, exit). Wired into `~/.claude/settings.json`.
- `--install-hooks` / `--uninstall-hooks` — register/remove the hooks in settings.json.
- `GCB_DEBUG=1` env → logs each refresh via NSLog.

**Relaunch pattern used during dev** (the menu-bar app has no Dock presence unless a window is open):
```sh
pkill -f "ghostty-claude-bar"; sleep 1
nohup "$(swift build --show-bin-path)/ghostty-claude-bar" --open-report >/tmp/gcb-run.log 2>&1 & disown
```

**Cannot be verified headlessly** (no terminal-content reads): whether injected
`/close` / `/rename` actually land, and whether notifications display. Test by
running the app and watching.

## Architecture

SwiftPM, two targets:
- **`GhosttyClaudeBarCore`** — pure data layer, no AppKit. Unit-testable. The port of the Python tool's brains.
- **`GhosttyClaudeBar`** — the AppKit/SwiftUI app (menu bar, windows, hooks, model calls).

### Core file map (`Sources/GhosttyClaudeBarCore/`)
| File | Role |
|---|---|
| `Models.swift` | `TabRow` (one display row) + `SessionState` enum (working/needsReply/idle/safeToClose/other; case order = sort order). |
| `Session.swift` | `Session` (parsed `~/.claude/sessions/<pid>.json`) + `GhosttyTab`. |
| `Paths.swift` | `~/.claude` locations; `encodeCwd` (maps `/ _ space & .` → `-` — the `.` is ESSENTIAL or dotted cwds break); `collapseHome`/`expandHome`. |
| `SessionStore.swift` | Loads live (PID-filtered) sessions; skips `IgnoredPIDs`; sweeps orphan `.state` sidecars. |
| `Shell.swift` | Tiny process runner with a polling **timeout watchdog** (so a hung osascript/claude can't freeze refreshes). |
| `GhosttyClient.swift` | All Ghostty AppleScript: `tabs()` (enumerate, with one-frame keep-last-good anti-flicker), `focus`, `sendText` (input text + `send key "enter"`), `newSession` (surface configuration). |
| `TextAnalysis.swift` | title keyword extraction, message flattening, glyph stripping. |
| `Transcript.swift` | single-pass scan of a `.jsonl` → fingerprint + last-assistant text + usage. |
| `TranscriptCache.swift` | mtime+size keyed cache so only changed transcripts are re-scanned. |
| `Usage.swift` | token/cost accounting (cost currently NOT displayed — see UI notes). |
| `Recommender.swift` | session → `SessionState` + reason + verdict sidecar read. **busy always wins.** |
| `Matcher.swift` | IDF-weighted window↔session matching + leftover/elimination pairing. |
| `Collector.swift` | orchestrates everything → `[TabRow]`. **Session-centric.** |
| `VerdictStore.swift` | read/write `<sid>.state` sidecars `{state, ts, needsJudge, lastMessage}`. |
| `IgnoredPIDs.swift` | PIDs to hide (the judge's transient `claude -p`). |

### App file map (`Sources/GhosttyClaudeBar/`)
| File | Role |
|---|---|
| `main.swift` | entry: handles hook/util flags, registers fonts, sets `.accessory`, runs. |
| `AppDelegate.swift` | wires monitor + status item + window controllers; sets app icon. |
| `SessionMonitor.swift` | `ObservableObject` single source of truth. Owns FSEvents + timer, coalesces refreshes, fires notifications on transitions, drives JudgeService. |
| `StatusItemController.swift` | `NSStatusItem` + menu (fresh-on-open, cache-rendered). |
| `IconRenderer.swift` | menu-bar glyph + (legacy) dot images; `NSColor(hex:)`. |
| `ReportView.swift` | the SwiftUI report window (header, status strip, rows, actions, motion). |
| `ReportWindowController.swift` / `SettingsWindowController.swift` | host SwiftUI in dark `NSWindow`s; wire the action closures. |
| `SettingsView.swift` / `AppSettings.swift` | refresh-cadence setting (UserDefaults). |
| `FSEventsWatcher.swift` | FSEvents on `~/.claude/sessions/`, debounced. |
| `Theme.swift` / `StateStyle.swift` / `AmbientBackground.swift` / `StatusDot.swift` | design system: tokens, per-state styling, glow+grain background, pulsing dot. |
| `ClaudeCLI.swift` | shared headless `claude -p --model haiku` runner (recursion guard + PID-ignore). |
| `Judge.swift` / `JudgeService.swift` | classify finished turns DONE/WAITING/ACTIVE; refine sidecars. |
| `NameSuggester.swift` | Haiku title for the fix-name action. |
| `HookRunner.swift` / `HookInstaller.swift` | hook entry points + safe settings.json install. |
| `Notifier.swift` | macOS notifications via osascript (dev). |
| `SessionLauncher.swift` | folder picker → `GhosttyClient.newSession`. |
| `WindowActivation.swift` | flips `.regular`↔`.accessory` so an open window is Cmd-Tab-able. |
| `FontLoader.swift` / `AppIcon.swift` | register bundled fonts; draw the runtime Dock/Cmd-Tab icon. |
| `Resources/Fonts/` | bundled OFL fonts (Martian Mono, IBM Plex Mono) + OFL licenses. |

## Hard-won facts — Ghostty AppleScript (verified via full sdef dump, current Ghostty)

The original Python skill's notes are **partly outdated**. Current truth:
- `terminal` exposes only `id`, `name`, `working directory`. **`working directory` is empty.** No pid/tty/process. → there is **NO reliable window↔session join key**; matching is necessarily fuzzy.
- Window/tab **indices are unstable** (reorder on focus). Always act by the stable terminal **`id` (UUID)**.
- Ghostty **DOES expose** (newer versions): `input text`, `send key`, `send mouse …`, `new window`/`new tab`/`split` (with a `surface configuration`), `focus`, `close`, `perform action`. The old "no injection possible" note is wrong.
- **Claude Code submits on a real Enter KEY, not a CR char.** `input text "x" & return` types but does NOT submit — you must follow with `send key "enter" to theTerm`. (`GhosttyClient.sendText(submit:)` does this.)
- `surface configuration` (record-type) has `initial working directory`, `command`, `initial input`, `wait after command`, `environment variables`. `newSession` opens a window directly in a cwd via this (no `cd` detour). Douwe's environment auto-starts `claude` in new windows, so `newSession` only sets the cwd — injecting `claude` would double it.

## Key design decisions (don't relitigate without reason)

- **Full native Swift app**, not a Claude Code plugin — accepted separate distribution (Homebrew/Sparkle, Apple Dev account for notarization). Going native killed the SwiftBar-era bug class (menu vibrancy desaturating colors, `sfconfig`, focus-stealing `open -g`, the HTTP focus server).
- **SESSION-CENTRIC** rows (the original Python tool was deliberately *tab-centric* — this diverges). One row per live session; status/cwd/tokens always come from the session, so a bad window match can't corrupt status. Windows with no live session are NOT shown (this killed the "ghost row" class). The window is matched best-effort for **title label + focus/close/rename target only**.
- **`busy` always wins** in `Recommender`. Background agents / a running workflow keep a session `busy` while its session-file `updatedAt` goes stale; a Notification `WAITING` (noisy: session-limit warnings etc.) must NOT override that. Needs-reply only applies when not busy.
- **IDF-weighted matching** + a process-of-elimination pairing round so every session gets a window. Residual limit: two same-cwd, same-topic sessions can swap *titles* (status stays correct).
- **Model-judged done/waiting** via Haiku through the `claude` CLI (no API key; uses existing auth). Instant heuristic first, refined a few seconds later.
- **Own the Ghostty niche** for now; `Core` is structured so other terminals could be added later.

## Status engine (how a dot turns green)

Event-driven, near-zero idle cost:
1. `~/.claude/sessions/<pid>.json` writes → FSEvents → refresh (working/idle/open/close, ~1s).
2. **Stop hook** (`--stop-hook`, the app binary) on turn end → writes an instant heuristic verdict sidecar flagged `needsJudge`. Never calls a model → never delays the session.
3. **Notification hook** (`--notify-hook`) → writes `WAITING` (blocked on you).
4. The running app's `JudgeService` sees `needsJudge` → calls Haiku (`ClaudeCLI`) off-main → rewrites the sidecar with the model verdict → UI upgrades.
5. **Recursion guard:** the app sets `GCB_JUDGE=1` on its `claude` call; `--stop-hook` no-ops when it sees that. The transient `claude -p` session PID is registered in `IgnoredPIDs` so it doesn't ghost the UI.

**Hooks are installed live** in `~/.claude/settings.json` (pointing at the `.build` debug binary), and the **legacy `tabs-on-stop.py` Stop hook was removed** (it wrote the same sidecar → would race). Backup: `~/.claude/settings.json.bak-gcb-*`. Re-run `--install-hooks` after packaging to repoint at `/Applications`.

## UI / design system

"Mission control" dark aesthetic. **Martian Mono** (display: title + section labels) + **IBM Plex Mono** (telemetry/body), registered at launch by `FontLoader` from `Bundle.module`. `Theme` is the single source for color/type/spacing. `AmbientBackground` glow tracks the most urgent state. Working rows are visually dominant + get a pulsing dot (`StatusDot`) and a shimmer on the accent edge; rows animate on reorder. **Cost display was removed** (summing tokens at API rates wildly overstated real spend vs the subscription) — token counts kept.

## Dev-binary vs bundle gotchas

- **`Bundle.module`** works when running the built binary from `.build/.../debug/` (SwiftPM copies the resource bundle next to it). Fonts load fine in dev.
- **`UNUserNotificationCenter` needs a bundle identifier** (would crash a bare binary) → `Notifier` uses `osascript display notification` for now. Switch to `UserNotifications` once packaged (P5).
- **App icon**: dev binary has no `.icns` → macOS shows a generic "EXEC" placeholder. `AppIcon` draws one and sets `NSApp.applicationIconImage` at launch.
- **Cmd-Tab**: `.accessory` apps are excluded. `WindowActivation` flips to `.regular` while a window is open (Dock icon + Cmd-Tab) and back when it closes.

## Known issues — deferred (from the 2026-05-30 max code review)

Full plan in `docs/code-review-2026-05-30.md`. Fixes were **deferred, not
rejected** — address before P5 / public release. Two **P0 (harmful)**:

1. **Matcher Round 3 can send `/close` & `/rename` to the WRONG window.** The
   process-of-elimination pairing (`Matcher.swift`, round 3) binds an arbitrary
   leftover session↔window with no guard; that `terminalID` drives the
   destructive actions. Two unkeyable sessions ⇒ a `/close` can hit a *different*
   live session (silent, irreversible). **Fix:** carry an `isGuessed` flag on
   `TabRow` for Round-3 binds; keep Focus, but gate `onClose`/`onFixName` to
   confident matches only.
2. **`ClaudeCLI.exec` has no timeout and never drains stderr** → the judge /
   name-suggester task can hang forever on a stuck/chatty `claude -p` (and pins
   its PID in `IgnoredPIDs`). **Fix:** make `Shell` public + add `env:`, route
   `ClaudeCLI.exec` and `Notifier.post` through its watchdog.

P1 (notification correctness): completed-turn double-fire (heuristic WAITING →
Haiku DONE), needsReply re-fire on busy flicker, NameSuggester renaming a refusal
verbatim, fix-name firing on empty sessions. See the plan for all 15 findings.

## Status & next

P0–P4 ✓, redesign ✓, perf ✓, status engine ✓, control surface ✓ (close / fix-name / new-session / notifications). **Next: P5 — package the signed `.app`**: bundle a real `.icns`, set `LSUIElement`, switch to `UserNotifications`, ad-hoc sign (notarization needs an Apple Dev account), launch-at-login, re-point installed hooks at `/Applications`, README demo. Possible follow-ups: interrupt (Esc) button, quick-reply field on needs-reply rows, broadcast commands, the terminal-backend abstraction.
