# Baseline audit

What every game like this ships with, checked against `dev` (2026-11-25). Re-run before each start ships.
Rule: this list is mine to keep current. Flag gaps before Vishnu has to ask.
Each gap gets its own thread. When it ships, move it to "Have" here.

## Have

- Pause (Esc / P), auto-pause when the window loses focus
- Settings on title + pause: flight assist, mouse steering, fullscreen, music + effects volume, mute
- Main menu: Continue / New career / Settings / Quit, quit confirms
- Autosave on every dock, Continue shows a summary
- Career files: one save per career, New career never overwrites; Careers sheet (open / shred), .bak + damaged-file handling (`saves.md`, 2026-11-25)
- Controls overlay (H / F1), first-flight key prompts
- Controls page in both Settings: full key list, click-to-rebind (keys or mouse), swap on clash, reset to defaults; overlay + prompts show live keys (`controls.md`, 2026-11-25)
- Journal log of chatter, chart, now-playing music credit
- Credits roll from the title menu (`dialogue-credits.md`, 2026-11-25)
- Text speed setting (Slow / Normal / Fast / Instant, calm default), intro beats wait for a click, journal Radio tab rereads every line (`dialogue-credits.md`, 2026-11-25)

## Missing: needed before the Merchant opening is "done"

Ranked. Each one gets a card before it's built.

1. ~~**Losing.**~~ Done 2026-11-25: capture + ransom, rare death. See `losing.md`.
2. ~~**New career overwrites your save**~~ Done 2026-11-25, see Have.
3. ~~**Controls in Settings.**~~ Done 2026-11-25, see Have.
4. ~~**Credits screen.**~~ Done 2026-11-25, see Have.
5. ~~**Dialogue controls.**~~ Done 2026-11-25, see Have.

## Missing: standard, lower priority

- Master volume (have music + effects only)
- Window options: windowed size / borderless, vsync, frame cap
- Accessibility: screen-shake + flash toggle, UI / text scale, colorblind-safe radar and team colors
- Manual save: no, by design (capture sticks, `losing.md` pick 7)
- Version tag on the title screen (helps when friends report bugs)
- Gamepad (Endless Sky and M&B both support it; big job, after crew v1)
- Difficulty or "story" setting (debt pressure, enemy damage)

## Not needed (by design)

- Subtitles: no voice acting
- Time fast-forward: removed by pick (2026-11-20)
- Exports / installer: Vishnu runs from the editor
