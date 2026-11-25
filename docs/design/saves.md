# Saves

Gap #2 of `baseline-audit.md`. Status: **A picked (Vishnu, 2026-11-25), built.**

## Problem

- One file, `user://merchant_save.txt`. New Career starts fresh and the first dock overwrites it. No warning.
- A second start (Scrapper, Miner) would wipe the Merchant.
- A broken file just hides Continue.

## Locks it must respect

- Autosave on every dock (Endless Sky style). Keep.
- `losing.md` pick 7: **capture sticks.** No reload to undo it. So no free manual save / quickload.

## References

| Game | Model | Take |
| --- | --- | --- |
| Endless Sky | One file per pilot, autosave on landing. Load menu lists pilots, each with snapshots. | Career = file. Closest to us. |
| Mount & Blade | Named slots, manual + autosave; ironman option. | Slots, but manual saving undoes losses. Clashes with pick 7. |
| FTL / Disco Elysium | FTL: one run, saves on quit. DE: many slots, autosave + manual. | FTL shows "losing sticks" works with one file per run. |

## Options

- **A. Career files. PICKED.** One autosave file per career, never overwritten by another. Continue = last played. New: "Careers" sheet on the title clipboard lists every file (pilot, rig, start, station, day); open or shred. Fits pick 7, fits the paperwork look.
- **B. Confirm only.** Keep one file; New Career asks "this shreds your career" first. Smallest. Second start still wipes the first.
- **C. Three fixed slots.** Pick a slot at New Career, autosave into it. Familiar, but caps careers at 3 and adds a picker before the opening.

## Defaults (unless Vishnu says otherwise)

- Files: `user://careers/<n>.txt`, plus a `.bak` of the previous dock. Broken file → load the `.bak`, else show it as "damaged" in the list.
- Old `merchant_save.txt` migrates into career 1 on first launch.
- Shred asks once.
- No cap (list scrolls).
