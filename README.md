# Sector Secundus

A top-down space fleet RPG built in Godot 4. You captain a flagship, build a fleet, outfit ships and grow from a lone pilot into a fleet commander. The main inspiration is Endless Sky; the names, art and story here are original.

## Play it

1. Install **Godot 4.3** (the standard version, not .NET) from https://godotengine.org/download.
2. Open Godot, click **Import**, and choose this folder's `project.godot`.
3. Press **F5** (or the ▶ button) to play.

## Art

The ship, planet and station art comes from bought asset packs, which can't be shared publicly, so `art/` is git-ignored. Without it the game draws simple shapes instead.

To install it, unzip `art.zip` into this folder (so you get `art/ships`, `art/planets`, ...). To rebuild it from the original packs, unpack them all into one folder and run `python tools/prepare_art.py <that folder>` (needs Pillow).

## Controls

Thrusters are always relative to where your ship points. The camera never rotates.

| Action | Keys |
| --- | --- |
| Thrust forward / back | W / S (or ↑ / ↓) |
| Strafe left / right | A / D |
| Turn | Q / E (or ← / →) |
| Brake assist (fires your real thrusters against your drift) | Hold X |
| Aim turrets and gun gimbals | Mouse |
| Fire turrets | Left click |
| Fire forward cannons | Space |
| Tactics wheel (time slows) | Hold Tab, point, release |
| Wingmen attack target under cursor | T |
| Zoom | Mouse wheel |
| Toggle help | H |
| Dock at a station / jump through a rift | F (slow down near it; hold still 3 s to jump) |
| Restart after defeat (sandbox) / back to start screen (merchant) | R |

## Current state: Merchant opening

The game opens on a start screen with four starts. Merchant is playable; Scrapper, Miner and Pirate are teased. A **Combat sandbox** button opens the old combat test.

- Four systems (Aurelia, Tiberine, Marcellus, Porta Aquila) linked by jump rifts, eight stations to dock at. The crossroads gate is locked until you have papers.
- Docking pauses time. Each station has a market: green goods are made there (cheap), orange goods are needed there (pays well). Prices drift weekly.
- You start docked at the Counter in debt to the Charter Company. Charlie gives you a starter run: 20 tons of water from the Drip to the Greenhouse.
- Loan payments come out every week (a day is 60 s of flight). Miss one and interest is added. Pay extra or pay it off at the Counter.
- Marcellus is the rough system: more profit, pirate raiders.
- After picking Merchant you design an old friend: name, face, role (pilot, gunner, engineer, trader) and a shared memory. You meet them at the Greenhouse after the first delivery and they fly with you as a free escort, following you through jumps. Each role and memory gives a bonus and callback lines; they comment on what you do. If their ship goes down they pod out and rejoin at your next dock.
- Not in yet: the Tallyman and Franz, the ending, cruise, saving.

Scripted check: `godot --headless --fixed-fps 60 -- --merchant-test` runs the opening end to end and prints each step. Add `--friend-role=pilot|gunner|engineer|trader` and `--friend-memory=drip|four|lost|gate` to test the old friend's options.

### Combat sandbox

- Newtonian flight with no drag: you coast until you burn against your motion.
- A hard top speed per hull. Thrust past it only changes your direction.
- A strong main engine plus weaker side and reverse thrusters (20 to 60% of the main engine, set per hull). Fighters have strong side thrusters, big ships weak ones.
- A built-in reactor per hull feeds one energy bar. Guns, shield recharge and thrusters all draw from it.
- Fixed cannons (forward, small gimbal, more damage) and turrets (follow the mouse at a limited traverse speed).
- Shields that recharge after a delay, then hull.
- Pirate raiders make gun runs, and pirate marauders orbit and use turrets. Waves escalate.
- Two wingmen with formations (wedge, line abreast, screen) and orders (engage at will, attack my target, hold formation).
- A combat indicator when enemies are close.

## Roadmap for the demo

1. **Combat sandbox** (done)
2. Disable, board and capture ships
3. Outfits with limited outfit/weapon/engine space, a station with an outfitter and a shipyard
4. Vertical slice: 3–4 star systems, opening scenario, title screen, packaged build

## Project layout

- `scripts/data.gd`: all ships and weapons as data (add new content here)
- `scripts/ship.gd`: flight, damage, weapon mounts, drawing
- `scripts/player_controller.gd`, `scripts/ai_controller.gd`: who flies the ship
- `scripts/main.gd`: the sandbox, waves, fleet orders and formations
- `scripts/fx.gd`: projectiles, particles and explosions
- `scripts/hud.gd`, `scripts/tactics_wheel.gd`, `scripts/starfield.gd`: UI and background

Automated check: `godot --headless --fixed-fps 60 -- --autotest` runs a 2-minute AI-vs-AI fight and prints stats.
