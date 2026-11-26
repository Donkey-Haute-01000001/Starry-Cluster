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
- Losing (`capture.gd`, docs/design/losing.md): rig goes dead at 15%, open the airlock (3 days, ransom receipt) or fight the breach (death card, load last dock); Tallyman/driven off = tow. Lines DRAFT
- Debt bites: strikes, repo cutter, customs scans, weekly no-questions job
- Merchant script complete (all lines locked, 2026-11-25)
- Story: rig ahead (Alejandra, Hollis), Tallyman ambush + Franz, Red Stork bounty + boarding, Saltgate bar (Fay, Mersham), Navy offer + Mbeki, four forks with gate payoffs, ending + title card
- Chart (M), journal (J), pause menu, autosave on dock, career files (neon Careers register on title)
- UI look redo in progress (`docs/design/ui-look.md`, signed): neon menus, pixel-paper documents. Done: Careers register, Pause, Settings, Controls (title + flight share `neon_settings.gd`)
- Comms ticker, quiet HUD, neon text, VT323 dialogue
- Real-recording sounds, Pink Bloom music

## Next (pick order with Vishnu)

1. **Merchant playtest**: only when Vishnu says. Crew v1 waits on it
2. **Crew v1** (all starts): scope locked, see `docs/design/combat-fitting.md`
3. **Busy bars**: crew and captains for hire in every bar
4. **Scrapper start**: decisions locked, see `docs/design/story-cast.md`
5. **Open-world piracy + fence**: board, rob, sell. Tally is a contact, not a quest
6. Code cleanup: split `main.gd` and `data.gd` (see `docs/ARCHITECTURE.md`)

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
- Play your own music (Spotify / Apple Music / playlists). Spotify API only remote-controls the Spotify app (Premium); Apple Music has no desktop hook. Cheap version: "Game music: On / Off (play your own)" setting
