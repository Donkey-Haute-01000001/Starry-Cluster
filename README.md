# Sector Secundus

A top-down space fleet RPG built in Godot 4. You captain a flagship, build a fleet, outfit ships and grow from a lone pilot into a fleet commander. The main inspiration is Endless Sky; the names, art and story here are original.

## Play it

1. Install **Godot 4.3** (the standard version, not .NET) from https://godotengine.org/download.
2. Open Godot, click **Import**, and choose this folder's `project.godot`.
3. Press **F5** (or the ▶ button) to play.

## Fonts

UI text uses Big Shoulders (dock signage). The paperwork uses Courier Prime (typed forms), Nanum Pen Script (handwriting) and Big Shoulders Stencil (rubber stamps, hull marks). All are in `fonts/` under the SIL Open Font License, free to ship.

## Sounds

`sounds/` holds the paper and dock foley (stamp, pen, paper, page flip, tick, hydraulic hiss, PA chime, dock hum). They're synthesized from scratch by `python tools/make_sounds.py .`, so they're ours to ship. Music comes later.

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
- The title screen is a live shot of your rig in its Charter berth at the Counter, with the paperwork on a clipboard. Sign the loan, then fill in the Charter's emergency-contact form: your old friend Dez Okafor. You pick how you know him (rift pilot, ex-navy gunner, yard mechanic, dock hustler); each background sets his ship, bonuses and callback lines. You meet him at the Greenhouse after the first delivery and he flies with you as a free escort, following you through jumps, and comments on what you do. If his ship goes down he pods out and rejoins at your next dock.
- Your first jump into Marcellus: the Tallyman is waiting at the exit. An ion bolt kills your engines, and you fight three ships you can't beat (nobody on your side dies). He hails you; pick a reply. How well you fought changes what he says. He spares you and leaves, and Lt. Kessler's patrol arrives, gets your engines running and heads for Four.
- At Four, Kessler is counting the Tallyman's marks and pins a bounty notice: the pirate skiff Mud Lark near Amber's. Kill it and collect at Four. Come back again and he makes the navy pitch.
- At Saltgate's bar, Fay and Mersham pitch themselves. Hire them on weekly contracts (wages come out with the loan; no pay, and they walk). Hire both and Mersham takes Fay under his wing.
- Pay off the loan and your papers come through. At the Wall's gate, customs stamps your Writ of Passage, you jump, and the crossroads open up under the Dynasty's gate fortress while their fleet drifts past. One line, then the title card. The demo ends there.
- Lines marked DRAFT in `scripts/data.gd` are placeholders; the script doc wins.
- Not in yet: boarding (the bounty's "alive" price), cruise, saving.

Scripted check: `godot --headless --fixed-fps 60 -- --merchant-test` runs the opening end to end and prints each step. Add `--friend-bg=rift_pilot|navy_gunner|yard_mechanic|dock_hustler` (or `--friend-role=pilot|gunner|engineer|trader`) to test Dez's backgrounds. It plays through the Tallyman, the bounty, the bar and the ending too. `--shots=DIR` saves screenshots along the way (with `--fast` for 4x time steps under slow software rendering). `-- --start-shot=out.png` and `-- --creator-shot=out.png` screenshot the title and the contact form.

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
