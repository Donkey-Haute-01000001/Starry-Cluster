# Dialogue controls + credits

Audit gaps #4 and #5 (`baseline-audit.md`). Picks 2026-11-25.

## Text speed (pick: calm + wait per beat)

- Settings (title sheet + pause): **Text** Slow 14 / **Normal 20** / Fast 35 / Instant, chars per second. Was 55 (comms) and ~25 (intro).
- One pace for everything that types: comms, intro beats. `Neon.pace`, saved in `settings.cfg [text] speed`.
- Intro beats wait for you: click / Space finishes the beat typing, the next click starts the next one. A caret blinks where the next beat lands.
- Click / Space still finishes a comms line.
- Refs: Katana Zero (fast type, skip to finish), Disco Elysium (one line at a time, continue to advance), Hades (text speed setting).

## Credits (pick: film roll)

- CREDITS in the title menu row, before QUIT. Menu steps aside; white names roll up over the station, music keeps playing. Esc / click / any key: back.
- Content mirrors `CREDITS.md`: Vishnu, Music by DavidKBD (required), Kenney + Pixabay sounds, Foozle art, fonts (OFL), Godot.
- Code: `scripts/credits_roll.gd`. Shot: `--credits-shot=DIR`.

## Reread (pick: journal Radio tab)

- Journal tab 6 **RADIO**: every logged line, a day per entry (10 lines per page), newest day first; right page shows who + line in order.
- People pages keep each person's own lines.
- Log keeps the last 200 lines (`Career.say`).
