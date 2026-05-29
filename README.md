# ghostty-claude-bar

A native macOS menu-bar app that **shows you all of your open Claude Code sessions** and tells you, at a glance, **which of your running Claude Code sessions need you right now** across every open [Ghostty](https://ghostty.org) window.

As you run more parallel Claude Code agents, the real problem stops being "what am I working on" and becomes "which of these six terminals is *waiting on me*?" This puts that answer in your menu bar:

- 🔴 **Working** — a turn is actively running
- 🟠 **Needs reply** — Claude finished and is waiting on you
- 🟡 **Idle** — alive but quiet
- 🟢 **Safe to close** — done and stale
- ⚪ **Other** — a Ghostty window with no Claude session

Click any row to jump straight to that window.

> **Status: early development.** Being built in public, phase by phase. It began
> life as a Python + SwiftBar Claude Code skill; this is the ground-up native
> Swift rewrite. The menu-bar UI and colored status dots already render — the
> session-detection brains are being ported next.

## Why native (vs the SwiftBar original)

Going native erases a whole class of bugs the SwiftBar version fought: menu **vibrancy** desaturating status colors, the `sfconfig` palette workaround, focus-stealing `open -g` refresh pings, and a separate HTTP server just to make report rows clickable. A real `NSStatusItem` draws its own icons and handles its own clicks — none of that machinery is needed.

## Build & run (dev)

Requires macOS 14+ and a Swift 6 toolchain (Xcode 16+).

```sh
swift build
swift run ghostty-claude-bar   # a window glyph + count appears in your menu bar
swift test                     # core unit tests
```

The dev binary uses `.accessory` activation (no Dock icon) without needing an app bundle. A signed, notarized `.app` with auto-update is a later phase.

## Roadmap

- [x] **P0** — Package scaffold + runnable menu bar with native colored dots (demo data)
- [x] **P1** — Core data layer: parse `~/.claude/sessions`, enumerate Ghostty via AppleScript, match windows ↔ sessions
- [x] **P2** — Wire real data into the menu; click-to-focus by terminal UUID
- [x] **P3** — Live refresh (30s timer + FSEvents on `~/.claude/sessions/` + fresh-on-open); model-judged done/waiting verdicts read from Stop-hook sidecars
- [ ] **P4** — HTML report export + settings (refresh cadence, judging model)
- [ ] **P5** — Packaged `.app`, signing, README demo, distribution
- [ ] **Later** — abstract the terminal backend (iTerm2, WezTerm, …)

## License

MIT © 2026 Douwe van Loenen
