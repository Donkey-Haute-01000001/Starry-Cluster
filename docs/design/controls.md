# Controls

Gap #3 of `baseline-audit.md`. Status: **card out (2026-11-25).**

## Problem

- Settings (title clipboard + Esc) has no key list. Only the H overlay shows keys.
- No rebinding. Keys are hardcoded in `main.gd` (`_setup_input` + raw keycodes for R, V, G, Y, M, J, B, C).
- Prompts (H overlay, first-flight key caps) print fixed letters.

## References

| Game | Model | Take |
| --- | --- | --- |
| Endless Sky | Preferences > Controls: one list, click a row, press a key. Clash shows red, both kept. | One key per action, simple. |
| Mount & Blade | Options > Controls: one key per action, reset to defaults. | Same, plus a reset. |
| FTL | Controls tab: click to rebind; clash unbinds the other action. | Clash handling that can't leave you stuck. |

## Actions

| Group | Action | Default |
| --- | --- | --- |
| Flight | Forward / back / strafe L / strafe R | W S A D (arrows Up/Down also) |
| Flight | Turn L / R | Q E (arrows Left/Right also) |
| Flight | Brake, flight assist | X, V |
| Flight | Dock / jump, autopilot | F, G |
| Combat | Fire turrets, fire secondary | Left click, right click |
| Combat | Forward guns, swap secondary | Space, R |
| Combat | Tactics wheel (hold), attack target | Tab, T |
| Comms | Hail, board, answer call | Y, B, C |
| Screens | Chart, journal, controls overlay | M, J, H (F1 also) |

Fixed (shown, not rebindable): Esc / P pause, Space / Enter next comms line, 1-5 choices, mouse aim, wheel zoom.

## Options

- **A. Full list + rebind (rec).** Controls page in both Settings. Every action above rebindable, keys or mouse buttons. Click row, press key. Clash: swap with the other action, note it on the sheet. "Reset to defaults". Prompts and H overlay read live keys.
- **B. Rebind flight + combat only.** Screens/comms keys fixed. Smaller, but players who move M/J can't.
- **C. Read-only list.** Key list in Settings, no rebinding. Smallest, fails the gap.

## Defaults (unless Vishnu says otherwise)

- One key per action; arrow keys and F1 stay as fixed extras.
- Saved in `user://settings.cfg` under `[keys]`.
