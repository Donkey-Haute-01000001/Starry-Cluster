# Baseline audit

What every game like this ships with, checked against `dev` (2026-11-25). Re-run before each start ships.
Rule: this list is mine to keep current. Flag gaps before Vishnu has to ask.
Each gap gets its own thread. When it ships, move it to "Have" here.

## Have

- Pause (Esc / P), auto-pause when the window loses focus
- Settings on title + pause: flight assist, mouse steering, fullscreen, music + effects volume, mute
- Main menu: Continue / New career / Settings / Quit, quit confirms
- Autosave on every dock, Continue shows a summary
- Controls overlay (H / F1), first-flight key prompts
- Journal log of chatter, chart, now-playing music credit

## Missing: needed before the Merchant opening is "done"

Ranked. Each one gets a card before it's built.

1. **Losing.** Player destroyed = blank screen, R dumps you to the title. No defeat scene, no reload. Design pillar says you're usually *captured*, rarely killed. Biggest gap. *(design call)*
2. **New career overwrites your save** with no warning. One save file only (`merchant_save`), so a Scrapper start would wipe the Merchant.
3. **Controls in Settings.** No key list or rebinding there; only the H overlay.
4. **Credits screen.** `CREDITS.md` exists, not reachable in game.
5. **Dialogue controls.** Typing speed, and no way to reread a story scene after it closes. *(check journal covers it)*

## Missing: standard, lower priority

- Master volume (have music + effects only)
- Window options: windowed size / borderless, vsync, frame cap
- Accessibility: screen-shake + flash toggle, UI / text scale, colorblind-safe radar and team colors
- Manual save / save slots, safe handling of a broken save file
- Version tag on the title screen (helps when friends report bugs)
- Gamepad (Endless Sky and M&B both support it; big job, after crew v1)
- Difficulty or "story" setting (debt pressure, enemy damage)

## Not needed (by design)

- Subtitles: no voice acting
- Time fast-forward: removed by pick (2026-11-20)
- Exports / installer: Vishnu runs from the editor
