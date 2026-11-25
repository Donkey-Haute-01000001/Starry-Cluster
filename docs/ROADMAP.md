# Roadmap

Updated 2026-11-25. Edit this file when something ships or a pick changes the plan.

## Done (Merchant opening, playable end to end on `dev`)

- Title scene, main menu, loan file, Charter ID form, Dez background pick, launch card
- Flight: ship-relative thrusters, mouse steering + flight assist, G autopilot, no cruise
- Combat: turrets (left click), blasters (Space), secondaries (right click, R swaps), disable at ~15% hull
- Orders wheel (Tab): Engage / Focus / Screen me / Bait / Break off + Wedge / Line / Ring; Fay hesitates, Mersham presses
- Four systems, eight stations, makes/wants market, weekly prices, weekly loan
- Living traffic: liened haulers, patrols, raids, persistent wrecks, hails
- Beacon ring, reserve tank, Charter tow slip
- Debt bites: strikes, repo cutter, customs scans, weekly no-questions job
- Story: rig ahead (Alejandra, Hollis), Tallyman ambush + Franz, Red Stork bounty + boarding, Saltgate bar (Fay, Mersham), Navy offer + Mbeki, four forks with gate payoffs, ending + title card
- Chart (M), journal (J), pause menu, autosave on dock
- Comms ticker, quiet HUD, neon text, VT323 dialogue
- Real-recording sounds, Pink Bloom music

## Next (pick order with Vishnu)

1. **Merchant gate lines**: four old drafts left in `data.gd` forks (`charlie_vouch`, `flagged`, `navy_papers`, `halloran_gate`). Everything else in the Merchant script is locked
2. **Merchant playtest**: only when Vishnu says. Crew v1 waits on it
3. **Crew v1** (all starts): scope locked, see `docs/design/combat-fitting.md`
4. **Busy bars**: crew and captains for hire in every bar
5. **Scrapper start**: decisions locked, see `docs/design/story-cast.md`
6. **Open-world piracy + fence**: board, rob, sell. Tally is a contact, not a quest
7. Code cleanup: split `main.gd` and `data.gd` (see `docs/ARCHITECTURE.md`)

## Open questions (raise when relevant)

- Who Hollis hauls for, and who has a beef with them
- Miner allegiance: Compact, Franz as friend (pending)
- Rift look (Vishnu not happy yet)
- Interrupt dialogue
- Named elite crew + hull origin marks (explained, not approved)

## Parked low-prio (don't build unprompted)

- Red strike paint on the player's rig + repaint at a yard
- Fleet ships take colors from crew origin mix
- VCR OSD Mono for now-playing / day readouts (license check)
- Fighters / carrier sorties (designed, build after crew v1)
- Outposts, co-op (long term)
