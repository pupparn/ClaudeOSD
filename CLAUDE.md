# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

SwiftUI macOS menu-bar app (`MenuBarExtra`) that shows a dropdown panel ("OSD") of Claude
subscription usage (today/week %, reset countdown, spend) via a tabbed ring gauge —
**Design 02 (Tabbed Ring Gauge)** from the original design exploration. Full visual/
behavioral spec (colors, spacing, radii, countdown formats, state machine) lives in
`README.md` — consult it before changing layout, tokens, or interaction details, since
values there (e.g. `#D97757` coral, `#E0A458` amber, 312px panel width, 158px gauge,
segmented-pill animation timing) are intentional pixel-fidelity targets, not arbitrary.

## Commands

```bash
swift build              # build
swift run                 # run the menu-bar app
swift build -c release    # release build
./build_app.sh             # release build + package as Claude Usage OSD.app, install to ~/Applications, ad-hoc codesign, register login item
```

No test target is defined in `Package.swift`. There is no lint config.

`build_app.sh` is the packaging path for double-click/login-item use (Finder/Dock/Spotlight,
auto-launch at login) — `swift run` is fine for dev iteration but doesn't produce an
installed `.app` or register a login item.

## Architecture

Single executable target `ClaudeUsageOSD` (Swift 5.9, macOS 13+), entry point
`Sources/ClaudeUsageOSD/ClaudeUsageOSDApp.swift`.

- **`UsageViewModel`** (`ObservableObject`) — single source of truth. Holds `tab`
  (`.today`/`.week`), drives a 1s clock `Timer` (`now`) for live countdowns, and a 3s poll
  `Timer` that re-reads `UsageDataSource` (skips re-parsing if the cache file's mtime hasn't
  changed). `dailyPct`/`weeklyPct`/`dailySpend`/`weeklySpend` are real values once a snapshot
  has arrived; `hasDailyData`/`hasWeeklyData` are `false` (UI shows "—") until then. Reset
  countdowns count down to the real `resets_at` epoch from the snapshot — there is no
  midnight/Monday math anymore, since Anthropic's actual windows are a rolling 5-hour and
  7-day window, not calendar-aligned.
- **`UsageDataSource`** — reads `~/.claude/usage-osd-cache.json` (latest `rate_limits`/`cost`
  snapshot) and `~/.claude/usage-osd-events.jsonl` (per-tick cost log, pruned to 8 days) to
  compute spend totals as max-cost-per-session within the trailing 24h/7d window (cost in
  each event is a session's *cumulative* total at that tick, so summing every line would
  double-count).
- **`OSDPanelView`** — top-level panel layout (header → segmented control → ring+tiles
  content → divider → quit row), composes the pieces below and owns the vibrancy
  background/shadow/corner-radius chrome. The quit row calls
  `NSApplication.shared.terminate(nil)` — the only way to exit the app, since
  `MenuBarExtra` apps have no Dock icon/Cmd-Q and no default quit affordance.
- **`RingGaugeView`** — the radial gauge, built from a fixed 132×132 viewBox scaled to a
  158×158 display size via `scaleEffect` (not native frame size) to match the HTML's SVG
  viewBox scaling approach.
- **`SegmentedControlView`** — Today/This Week pill switcher; pill position driven by
  `GeometryReader`-computed segment width and an explicit `timingCurve` animation matching
  the original CSS `cubic-bezier`. Each segment's `Button` label uses
  `.frame(maxWidth: .infinity, maxHeight: .infinity)` + `.contentShape(Rectangle())` so the
  whole pill area is tappable, not just the text glyphs.
- **`StatTileView`** — small reusable label/value tile used twice per tab (reset countdown,
  spend).
- **`VisualEffectBlur`** — `NSViewRepresentable` wrapping `NSVisualEffectView` for the panel's
  dark vibrancy/blur material.

Data flow is one-directional: `OSDPanelView` reads `model.tab` to switch which gauge/tiles
render, and binds `SegmentedControlView`'s tab directly to `model.tab`.

## Real usage data (no public API exists)

Claude.ai subscription rate-limit % (`rate_limits.five_hour`/`seven_day` `used_percentage` +
`resets_at`) is never persisted to disk by Claude Code and has no public API — the only
place it's exposed is the JSON piped to a configured `statusLine` command's stdin, during an
active Claude Code session. To get it into this app, the user's **global**
`~/.claude/statusline-command.sh` was extended (outside this repo) with a block that, on
every statusline tick, also writes:

- `~/.claude/usage-osd-cache.json` — latest `five_hour`/`seven_day` `used_percentage` +
  `resets_at`, plus `session_id` and `cost.total_cost_usd`.
- `~/.claude/usage-osd-events.jsonl` — one line per tick (`ts`, `session_id`, `cost_usd`),
  pruned to the trailing 8 days each write.

This app never talks to Claude Code directly; it only polls those two files. Consequence:
gauges show "—" until some Claude Code session makes an API call (statusline only ticks on
API responses), and if `~/.claude/statusline-command.sh` is ever regenerated/overwritten,
the "Usage OSD cache" block must be re-added or this app goes stale silently.

No subscription plan tier (Pro/Max5/Max20/Team) is obtainable either: the statusLine stdin
payload has no `plan` field and no absolute rate-limit numbers (only normalized
`used_percentage`), so a plan name can't be read or back-derived from any data this app has
access to. `UsageViewModel.planName` (was hardcoded `"MAX"`) and the header's plan-badge
`Text` in `OSDPanelView` have been removed rather than show a fake/static value — re-add only
if Anthropic ever exposes plan tier to the statusLine payload (tracked upstream, unshipped as
of this writing).
