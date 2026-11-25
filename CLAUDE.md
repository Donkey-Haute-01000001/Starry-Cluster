# Sector Secundus — working rules

Top-down real-time space fleet RPG, Godot 4 (GDScript, GL Compatibility). Repo name is still Starry-Cluster.
Vishnu writes and directs; Claude designs systems and builds. Read this file, then the doc for the system you're touching.

## Rules (locked)

- **Branch:** all work on `dev`. Vishnu pulls `dev` with GitHub Desktop and tests there. "Merge" = fold `dev` into `main`.
- **Scaffold first.** Design changes (content, mechanics, names, geography) go on a decision card with options + a recommendation. Wait for the pick. One question at a time. Bug fixes and polish he asked for can go straight in.
- **Plan before build.** Every new system: (1) one-page spec in `docs/design`, (2) how 2-3 reference games solve it, (3) genre-baseline check (what every game like this has that we lack; flag it, don't wait to be asked), (4) open questions on cards one at a time, (5) Vishnu signs the spec, then build small.
- **Don't overdo.** Build only what the pick said. No new named characters, fees or sub-mechanics without asking. Build small, show, expand.
- **No playtest asks.** Don't ask Vishnu to playtest until he says so.
- **Talk to Vishnu tersely.** Short lines, whitespace, no filler. In-game dialogue is the opposite: real writing, rhythm, subtext. Check lines against the voice bible.
- **Say "opening" / "start", never "demo".** Each start is the real beginning of the game.
- **Sounds are real recordings** (Kenney CC0, Pixabay), never synth. Credit every source in `CREDITS.md`. No radio static.
- **Fonts:** Big Shoulders (UI), Big Shoulders Stencil (stamps, hull marks), Courier Prime (print/forms), Nanum Pen Script (handwriting), VT323 (dialogue). No Exo-style "AI" fonts.
- **Music:** DavidKBD "Pink Bloom" only, now-playing credit "Music by DavidKBD" required.
- **No .exe / exports.** Vishnu runs from the editor.
- **Art is git-ignored** (`art/`, bought packs; repo is public). New art = send an updated art-pack zip via project files.
- **Script lines:** lines marked `DRAFT` in `scripts/data.gd` are placeholders; the script doc wins.
- **Line method:** offer 2-3 takes plus a pick; Vishnu picks. Tally-job lines (`tally_offer`, `tally_done`, `charter_heat`, `tally_heat`, Notch) are kept for the Scrapper.
- **Inspiration check:** Endless Sky loop, Mount & Blade loop, Katana Zero look. Original names/art/story only.

## Where things live

| What | Where |
| --- | --- |
| All content: ships, weapons, goods, stations, cast, every line | `scripts/data.gd` (autoload `Data`) |
| Career state, economy, weekly payments, save/load | `scripts/career.gd` (autoload `Career`) |
| Flight scene hub (spawning, docking, jumps, input, combat) | `scripts/main.gd` |
| Scripted scenes (ambush, bounty, forks, ending) | `scripts/story.gd` |
| System map | `docs/ARCHITECTURE.md` |
| What's done / next / parked | `docs/ROADMAP.md` |
| Design by system | `docs/design/*.md` |

## Run and test

- Editor: open `project.godot` with **Edit** once after new sounds/art (reimport), then F5. Vishnu uses Godot 4.7.2 on Windows.
- Headless (container): `godot --headless --fixed-fps 60 -- --autotest` runs a 2-min AI fight and prints stats.
- Screenshots: `xvfb-run -a godot --rendering-driver opengl3 -- <flag> --shots=DIR`.
- Flags: `--merchant-test`, `--new-career-test`, `--look=map,journal,launch,comms`, `--menu-shot`, `--id-shot=`, `--tally-ignore`, `--tally-silent`, `--fast`.

## Code gotchas

- New scripts: `preload` them, don't rely on `class_name`.
- Content keys are plain strings across Data/Career/Story; grep before renaming.

## Commits

Small, one change each. Credit Vishnu's lines in the message ("Script: ... (Vishnu)").
