# Architecture

~13.4k lines GDScript, no scene tree to speak of: scenes are thin, scripts build their nodes in code.

## Boot

`scenes/start.tscn` → `start_screen.gd` (title scene, main menu, loan file, ID form, Dez background pick) → `scenes/main.tscn` → `main.gd`.
`Data.mode` = `"merchant"` (the opening) or `"sandbox"` (combat test).

## Autoloads

| Autoload | File | Owns |
| --- | --- | --- |
| `Data` | `data.gd` | Fonts + theme, all stats (hulls, weapons, goods, systems, stations, traffic), cast, every line, neon colors, chart text |
| `Career` | `career.gd` | Credits, loan, strikes, cargo, jobs, flags, crew, comms log, prices, save/load (`user://merchant_save.txt`, autosave on dock) |
| `Music` | `music.gd` | Shuffle Pink Bloom, now-playing tag |

## Flight scene (built by `main.gd`)

| System | File | Notes |
| --- | --- | --- |
| Hub | `main.gd` | Builds world/fx/camera/UI layers; loads one star system at a time; dock/undock, jumps, autopilot (G), fleet orders, input, sandbox waves, autotest |
| Ships | `ship.gd` | Physics, shields/hull, mounts, drawing, disable at ~15% hull |
| Pilots | `player_controller.gd`, `ai_controller.gd` | Ship is driven by a controller (co-op-friendly) |
| Projectiles / particles | `fx.gd` | Bulk-simulated, one draw pass |
| Bodies | `body.gd`, `rift.gd` | Planets, belts, stations, jump rifts |
| Traffic | `traffic.gd` | Lane freighters, patrols, raids, persistent wrecks, hails (Y) |
| System edge | `edge.gd` | Beacon ring, reserve tank, Charter tow |
| Debt in flight | `debt.gd` | Strikes, repo cutter, customs scans |
| Losing | `capture.gd` | Rig dead in space, airlock or breach card, ransom receipt, death card |
| Story | `story.gd` | Rig-ahead, Tallyman ambush, Franz, bounty, forks, ending |
| Boarding | `boarding.gd` | Plan card + live breach |
| HUD | `hud.gd`, `neon.gd` | Quiet/fight layouts, comms + ticker, Katana Zero neon text |
| Overlays | `station_ui.gd`, `sector_map.gd` (M), `journal.gd` (J), `pause_menu.gd`, `tactics_wheel.gd` (Tab), `launch_card.gd` |
| Look | `ui_style.gd`, `paper_sheet.gd`, `starfield.gd`, `shaders/` |
| Art/sound loaders | `art.gd`, `sfx.gd` |

## Known coupling (fix in the code-cleanup thread, not ad hoc)

- **`main.gd` is a god object.** Sandbox + merchant loop + autopilot + autotest in one 1,700-line file. `hud.gd` (~80 refs) and `story.gd` (~80 refs) reach straight into `main.*`; `traffic`, `ai_controller`, `edge`, `boarding` also do.
- **`data.gd` mixes three jobs:** theme/fonts, tuning numbers, and the script. A line edit and a balance tweak touch the same file.
- **`career.gd`** holds both state and rules (economy, crew, forks). OK at current size.
- **Content keys are strings** across Data/Career/Story (`"fay"`, `"four"`, flags). A typo fails silently.

Suggested split when Vishnu okays it: `main.gd` → `flight.gd` (world) + `merchant_loop.gd` + `autotest.gd`; `data.gd` → `theme.gd` + `stats.gd` + `script_lines.gd`.

## Tools (`tools/`)

`prepare_art.py` (build `art/` from bought packs), `vox_to_sprite.py`, `make_portraits.py`, `import_void_fleets.py`, `livery_sheet.gd`. `make_sounds.py` / `make_combat_sounds.py` are legacy synth placeholders: don't use for new sounds.
