# Charter briefing (first-launch tutorial)

Status: **draft spec, picks open.** Asked by Vishnu 2026-11-26 after the first outside playtest: a non-gamer couldn't read the HUD, couldn't tell what to do, and got lost.

## The idea (Vishnu)

The opening is a tutorial. Charlie gives the Charter's required briefing ("Hey captain, I know you don't need the briefing, but the Charter requires me to give it to you") and explains each part of the HUD as it pops up.

## How others do it

- **Firewatch:** Delilah teaches the map and compass over the radio while you walk. The tutorial is the relationship.
- **FTL:** an optional tutorial ship. Each panel is highlighted and explained in order, and you can skip it.
- **Endless Sky:** no tutorial ship. A one-line help popup appears the first time each thing happens (first jump, first landing, first fight).
- **Katana Zero:** the tutorial is framed in the story and stays in the voice, never a pop-up.

## What the HUD has today

| Part | Where | Teaches |
| --- | --- | --- |
| System plate | top left | system, danger, credits, hold, loan and due day |
| Job line + arrow | top centre, screen edge | what to do next, where, distance, [G] autopilot |
| Station and jump names | screen edge | where everything in the system is |
| Ship panel | bottom centre | shields, hull, energy, speed, secondary weapon |
| Radar | bottom right | ships around you |
| Comms box | bottom left | who's talking (portrait, name, channel) |
| Key prompts | centre | fly, guns, travel, tactics (first flight only) |

## Genre baseline

- A skip for players who know it
- A way to replay it (Settings)
- A controls reference afterwards (exists: [H] controls)

## Open questions (one card each)

1. ~~Pacing~~ locked: mix
2. ~~Skip~~ locked: reply choice
3. ~~Key prompts~~ locked: Charlie + key caps together
4. Lines: 2–3 takes per beat, Vishnu picks

## Locked

- **Pacing: mix** (Vishnu 2026-11-26). Parked at launch for the basics: system plate, job line + arrow, comms box. The rest (radar, ship panel, guns, orders) gets a Charlie line the first time each matters.
- **Skip: a reply to Charlie** (Vishnu 2026-11-26). After her opener: "Go ahead" or "I've flown before, Charlie. Thanks though." (his line), shown with a small "(skip tutorial)" tag. Skipping drops the parked briefing; Charlie answers in character.
- **Dialogue: story lines pause the game in a centre window** (Vishnu 2026-11-26). Big window above the ship panel, world dimmed, "CLICK / SPACE ▸ continue". Chatter stays in the corner ticker and never pauses. Built in `hud.gd` (`_dialogue_pause_step`).
- **Key prompts: Charlie + key caps together** (Vishnu 2026-11-26). Charlie gives the what and why; the key-cap strip shows the keys under her line and fades once you've done it.

## Beats

Parked at launch (engines held; each HUD part fades in as she names it):
1. Opener (Vishnu's line) + reply: "Go ahead" / "I've flown before, Charlie. Thanks though." (skip tutorial)
2. Skip answer (only if skipped)
3. System plate: where you are, how rough, money, hold, the loan
4. Job line + green arrow, [G] autopilot
5. Station and jump names at the edge
6. The comms window ("that's me")
7. Flight keys (caps: W / mouse / X), engines released

First time it matters (one line each, then never again):
8. Radar: first ship on the scope
9. Ship panel: first hit on your shields
10. Guns: first hostile in range (caps: turrets / ion / swap)
11. Orders: first fight with an escort (caps: hold Tab)
