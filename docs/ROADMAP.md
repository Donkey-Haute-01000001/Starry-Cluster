# Roadmap

Updated 2026-11-26. Edit this file when something ships or a pick changes the plan.

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
- UI look redo in progress (`docs/design/ui-look.md`, signed): all neon, no paper. Done: Careers register, Pause, Settings, Controls (title + flight share `neon_settings.gd`), New career start picker, start files (opening types in neon, sign line, pink pen note), Form ID-1, Form NK-2, launch ID card, dispatch slip, ransom receipt, sector bulletin
- Comms ticker, quiet HUD, neon text, VT323 dialogue
- Real-recording sounds, Pink Bloom music
- Playtest fixes (sister, 2026-11-26): pinned job line, named nav pips, Charlie walkthrough, story lines pause in a centre window, Charter briefing (`docs/design/briefing.md`), shield-break sound, Tallyman ambush readability, hold view (HUD strip + HOLD tab, I; `docs/design/hold.md`)

## Next (pick order with Vishnu)

1. **Merchant playtest**: Vishnu playing 2026-11-26 (`docs/playtest/merchant.md`). Crew v1 waits on it
2. **Code split** right after the playtest notes, before Crew: `main.gd` and `data.gd` (see `docs/ARCHITECTURE.md`)
3. **Crew v1** (all starts): scope locked, see `docs/design/combat-fitting.md`
4. **Busy bars**: crew and captains for hire in every bar
5. **Scrapper start**: decisions locked, see `docs/design/story-cast.md`
6. **Open-world piracy + fence**: board, rob, sell. Tally is a contact, not a quest

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
