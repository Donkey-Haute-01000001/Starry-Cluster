# Sector Secundus

A top-down space fleet RPG built in Godot 4. You captain a flagship, build a fleet, outfit ships and grow from a lone pilot into a fleet commander. The main inspiration is Endless Sky; the names, art and story here are original.

## Play it

1. Install **Godot 4.7.2** (standard, not .NET; the version the game is tested on) from https://godotengine.org/download.
2. Open Godot, click **Import**, and choose this folder's `project.godot`.
3. Press **F5** (or the ▶ button) to play.

## Fonts

UI text uses Big Shoulders (dock signage). Typed text and dialogue use VT323, handwriting Nanum Pen Script, stamps and hull marks Big Shoulders Stencil. Courier Prime remains on screens not yet redone in neon. All are in `fonts/` under the SIL Open Font License, free to ship.

## Sounds

`sounds/` holds real recordings (Kenney CC0 packs, Pixabay clips); sources in `CREDITS.md`. Music is DavidKBD's Pink Bloom pack in `art/music`.

## Art

The ship, planet and station art comes from bought asset packs, which can't be shared publicly, so `art/` is git-ignored. Without it the game draws simple shapes instead.

To install it, unzip `art.zip` into this folder (so you get `art/ships`, `art/planets`, ...). To rebuild it from the original packs, unpack them all into one folder and run `python tools/prepare_art.py <that folder>` (needs Pillow).

## Controls

Thrusters are always relative to where your ship points. The camera never rotates.

| Action | Keys |
| --- | --- |
| Thrust forward / back | W / S (or ↑ / ↓) |
| Strafe left / right | A / D |
| Turn | Q / E (or ← / →); mouse steering on by default |
| Brake assist | Hold X |
| Flight assist on/off | V |
| Fire turrets (aim with mouse) | Left click |
| Fire forward cannons | Space |
| Fire secondary / swap secondary | Right click / R |
| Orders wheel (time slows) | Hold Tab, point, release |
| Escorts focus target under cursor | T |
| Dock / jump (hold still 3 s at a rift) | F |
| Autopilot to job | G |
| Hail ship under cursor | Y |
| Board a disabled ship | B |
| Chart / journal | M / J |
| Pause | Esc or P |
| Help | H or F1 |
| Zoom | Mouse wheel |

## Current state

The Merchant opening is playable end to end on `dev`. Scrapper, Miner and Pirate are teased on the start screen. See `docs/ROADMAP.md` for what's in and what's next, and `CLAUDE.md` for working rules.
