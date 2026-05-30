# Code Review — Remediation Plan (ghostty-claude-bar)

## Context

Max-effort `/code-review` of the two most recent commits on `main`:
`b82f4d6..HEAD` = `eb2487a` ("Submit fix + notifications + new-session launcher
+ AI fix-name") and `071b2a9` ("New session: open directly in the chosen
folder"). 247 insertions / 62 deletions across 14 Swift files.

Method: 9 independent finder angles + a gap sweep, then direct source
verification of every uncertain claim (Matcher rounds, Transcript fingerprint,
Shell watchdog, ReportWindowController action wiring, and the **Ghostty `.sdef`**
— which confirmed `send key` / `new surface configuration` / `initial input`
all exist, so the submit fix and new-session launcher are valid).

Refuted / dropped: "submit silently broken" (sdef has `send key`),
`prevStates` unbounded growth (it's replaced each tick), the old `newSession`
front-window race (rewritten in `071b2a9`). The Judge→ClaudeCLI extraction is
behavior-preserving (recursion guard + PID-ignore intact for both consumers).

This plan is the proposed **fix list** if you want remediation; the review
findings themselves are in the chat message. Nothing here is applied yet.

---

## P0 — destructive / robustness (fix first)

### 1. Matcher Round 3 sends `/close` & `/rename` to the wrong window
`Sources/GhosttyClaudeBarCore/Matcher.swift:108-116`. Round 1 binds only on
cwd-basename-in-title; Round 2 only generic-titled windows; **Round 3 binds an
arbitrary leftover session→window with no guard**, and that `terminalID` drives
the destructive actions in `ReportWindowController.swift:22-35`. Two unkeyable
sessions ⇒ a `/close`/`/rename` can hit a *different* live session. Silent,
irreversible.

**Fix (design choice — see chat question):** carry a confidence/`isGuessed`
flag on `TabRow` (set true for Round-3 binds), keep `onFocus` enabled (harmless)
but gate `onClose`/`onFixName` on a confident match in `ReportView.swift:307`
(currently only `row.terminalID != nil`). Optionally badge guessed rows.

### 2. `ClaudeCLI.exec` has no timeout watchdog and never drains stderr
`Sources/GhosttyClaudeBar/ClaudeCLI.swift:30-47`. `Shell.run` (Core) already
solves this — watchdog + `terminate()` after `timeout` (`Shell.swift:33-40`,
comment literally names "a hung … claude"). `ClaudeCLI.exec` has neither and
leaves `standardError` undrained → a hung or chatty (>64 KB stderr) `claude -p`
blocks the detached judge/name-suggester task forever and keeps its PID pinned
in `IgnoredPIDs`. Root cause: `enum Shell` is **internal**, so the app target
can't reuse it.

**Fix:** make `Shell` `public`, add an optional `env:` param, and route
`ClaudeCLI.exec` (and `Notifier.post`, #7) through it. Collapses three Process
spawners into one watchdog-protected path (also fixes #7/#11).

---

## P1 — notification feature correctness

### 3. Completed turn double-fires "Needs reply" then "Done"
`Sources/GhosttyClaudeBar/SessionMonitor.swift:90-100`. `apply` runs first on the
instant heuristic state, then again after Haiku refines it. A turn the heuristic
guesses as WAITING fires "Needs reply", then Haiku says DONE → next apply fires
"Done". False ping, immediately contradicted.
**Fix:** only notify on judged/stable states — e.g. skip notifying rows still
flagged `needsJudge`, or debounce a state for one refine cycle before notifying.

### 4. "Needs reply" re-fires on every busy→needsReply flicker
`SessionMonitor.swift:90-100`. Compares only to the immediately-previous state,
no per-session debounce, so a needsReply session that blips to `.working` and
back re-notifies. **Fix:** track "already notified for this needsReply episode"
per session id; reset when it leaves needsReply.

### 5. NameSuggester `/rename`s a claude refusal / non-title verbatim
`Sources/GhosttyClaudeBar/NameSuggester.swift:22-26` → `ReportWindowController.swift:34`.
`ClaudeCLI.run` returns stdout regardless of exit code / content; a refusal or
clarifying sentence (exit 0) becomes the title and is typed as `/rename <text>`.
**Fix:** validate the candidate (word count ≤ ~8, no sentence punctuation, not
starting with "I "/"Sorry"); bail to nil otherwise.

### 6. Fix-name fires on empty sessions (guard always true)
`NameSuggester.swift:11`. `Transcript.scan` seeds `fingerprintParts = [cwd]`
(`Transcript.swift:16`), so `fingerprint` always starts with the cwd and
`content.count > 20` passes even with no transcript. **Fix:** measure transcript
content excluding the cwd seed (e.g. require ≥1 user/assistant message, or check
`fingerprintParts.count > 1`).

---

## P2 — escaping / robustness / cleanup

### 7. Notifier: silent spawn + AppleScript escaping gaps
`Sources/GhosttyClaudeBar/Notifier.swift`. `try? process.run()` with no
`waitUntilExit` swallows failure and doesn't reap; `esc` (and the twin escapers
in `GhosttyClient.sendText`/`newSession`) escape only `\` and `"`, so a newline
in a title/path breaks the script → silent no-op. **Fix:** route through the now-
public `Shell.run`; add `\n`→space (or `\\n`) to one shared AppleScript escaper.

### 8. `sendText` submit timing race
`Sources/GhosttyClaudeBarCore/GhosttyClient.swift:96-101`. Fixed `delay 0.1`
between `input text` and `send key "enter"`; on a loaded session Enter can fire
before the paste lands. Low-frequency, load-dependent. **Fix (optional):** small
bump or a readiness check; acceptable to leave with a note.

### 9. Smaller cleanups (batch)
- `Notifier.post` title/subtitle inverted: every notification headline is the
  constant "Ghostty Claude Bar"; the state is demoted to subtitle
  (`Notifier.swift:8`). Swap so the state is the headline.
- `SessionMonitor.notifyTransitions` temp `next` dict + `hasBaseline` flag are
  derivable — `prevStates = Dictionary(rows.map{($0.id,$0.state)})`, gate on
  `!prevStates.isEmpty` (`SessionMonitor.swift:90-100`).
- `ReportView.swift:104`: `var onNewSession = {}` declared after `body` with a
  dead default — make it a plain `let` with the other stored props.
- `ClaudeCLI.path()` not cached → `zsh -lc command -v claude` subprocess per
  call on a miss; and `Judge.classify` builds the 4 KB prompt even when the CLI
  is absent. Cache the resolved path; early-out when unavailable.

---

## Verification

- `swift build` after each P0/P1 change; `swift test` (the suite the commit
  cites — "12 tests pass").
- Matcher: add a unit test — 2 unkeyable sessions + 2 leftover tabs ⇒ Round-3
  binds are flagged guessed and destructive actions are gated.
- Notifications: simulate heuristic-WAITING→Haiku-DONE and a busy flicker;
  assert exactly one notification per real episode.
- Manual: trigger `/close`, `/rename`, "New session…" against a live Ghostty to
  confirm the fixes don't regress the (verified-working) osascript paths.
