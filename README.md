# Sector Secundus

A top-down space fleet RPG built in Godot 4. You captain a flagship, build a fleet, outfit ships and grow from a lone pilot into a fleet commander. The main inspiration is Endless Sky; the names, art and story here are original.

## Play it

1. Install **Godot 4.3** (the standard version, not .NET) from https://godotengine.org/download.
2. Open Godot, click **Import**, and choose this folder's `project.godot`.
3. Press **F5** (or the ▶ button) to play.

## Controls

| Action | Keys |
| --- | --- |
| Thrust | W / ↑ |
| Turn | A, D / ←, → |
| Face against your motion (to brake) | S / ↓ |
| Aim turrets and gun gimbals | Mouse |
| Fire | Left click / Space |
| Tactics wheel (time slows) | Hold Q, point, release |
| Wingmen attack target under cursor | T |
| Zoom | Mouse wheel |
| Toggle help | H |
| Restart after defeat | R |

## Current state: step 1, combat sandbox

- Weighty rotate-and-thrust flight with inertia.
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
