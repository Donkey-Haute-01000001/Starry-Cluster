# Losing (capture, ransom, rare death)

Status: **ALL PICKS IN (2026-11-25), awaiting Vishnu's signature.** Gap #1 of `baseline-audit.md`. Thread: "Design losing and capture".

## Problem

Today: player hull hits 0, ship explodes, screen says FREIGHTER DESTROYED, R dumps you to the title. Nothing since the last dock survives, and nothing in the world reacts.
Pillar (world-lore): you and your companions are usually **captured**, rarely killed.

## What we already have to build on

- `Ship.disabled`: NPCs go dead in space at 15% hull and can be boarded. Player is excluded today.
- Boarding (`boarding.gd`): plan card, live breach, prize taken.
- Charter Recovery (`debt.gd`): ions you, boards, seizes cargo, bills a fee, tows you home with a printout.
- Charter tow (`edge.gd`): run dry, TOW SLIP adds to the lien, you wake docked.
- Autosave on every dock. Pause menu already says "your career picks up from that dock".
- Weekly payments, strikes, repo cutter. Time in captivity can land on a payment.

So capture can reuse disable → board → printout → wake docked. Small build.

## How the references do it

| Game | When you lose | What it costs | Takeaway |
| --- | --- | --- | --- |
| **Mount & Blade** | Party beaten → you're taken prisoner, dragged along with the victor's party | Gold + gear taken, troops lost, days pass; escape after a while or get ransomed; companions scatter to taverns, find them later | Losing is a **detour**, not an end. The world keeps moving while you're held. [ransom](https://mountandblade.fandom.com/wiki/Rescue_or_Ransom_Prisoner) |
| **Endless Sky** | Flagship destroyed = pilot dies | Game over; load the last landing snapshot | Clean, but losing = reload. No story. The thing Vishnu checked out of. |
| **FTL** | Hull 0 = run over | Everything | Permadeath works because runs are 2 hours. Ours is a career. Not a fit, but its **loss screen with run stats** is a good beat. |
| **Disco Elysium** | Failed checks branch the story; deaths are rare, authored, often absurd | Usually nothing mechanical; it's content | **Failure is content.** Losing should give you a scene and a line, not a menu. [PC Gamer](https://www.pcgamer.com/one-lesson-i-hope-baldurs-gate-3-has-taken-from-disco-elyisum-make-failing-fun) |
| **Kenshi** | Knocked out → robbed, jailed or enslaved | Gear, freedom; escape is play | Who beat you decides what happens. [slavery](https://www.kenshi.wiki/w/Slavery) |
| **Katana Zero** (look) | Death = "No, that won't work." rewind | Nothing; it's planning | Reload can be **in voice**, not a menu. |

## Locked design

**Flow**
1. Your rig hits 15% hull → **disabled** (same as NPCs). Engines and turrets dead. You drift.
2. Escorts still flying keep fighting. If they drive the attacker off: no capture, Charter tow home (TOW SLIP, existing).
3. Otherwise the attacker pulls alongside. Card: **SURRENDER** / **FIGHT THE BREACH**.
4. **Surrender** → capture:
   - Hull clangs (real recordings), fade to black.
   - Hand-ticked **Day 1, Day 2, Day 3**. Loan clock runs; a payment due while held can strike you.
   - **RANSOM RECEIPT** (Courier Prime, red Charter stamp): cargo seized, cash taken, ransom **2,500 + 500 per downed escort** added to the lien.
   - Wake docked at nearest station in that system. Autosaves (it's a dock). Charlie line.
   - Escorts that were still flying are waiting there. Disabled escorts come back with you (ransomed). Dez is aboard, comes back with you.
5. **Fight the breach** → reverse of player boarding (your crew vs theirs). Lose = **death card**, reload last dock. Win = they cut loose; you're still dead in space, Charter tow home.
6. **No reload to undo a capture.** Quit-to-menu still loads last dock mid-fight (already true).

**By captor**
- Raiders: as above.
- Charter Recovery: already built (seize + fee + tow). Unchanged.
- Navy: customs bust, already built. Navy doesn't fight you in the opening.
- Tallyman: locked lore, he takes nothing. **Not covered by picks** — see below.

**Lines needed (Vishnu writes, take method):** boarder hail at the SURRENDER card, Charlie on waking, death card line, Dez on waking (if aboard).

**Not covered yet (flag, decide before or after build):**
- Tallyman beats you: no take; does the Charter still bill a ransom? Rec: no ransom, he lets you go, tow home. Paint a tally mark on your hull later (parked).
- "Win the breach" outcome above is my fill-in, not a pick.

**Build order (small)**
1. Player disable at 15% + attacker closes + SURRENDER / FIGHT card.
2. Capture: fade, day ticks, RANSOM RECEIPT, wake docked, escorts.
3. Fight the breach + death card + reload.
4. Lines in as DRAFT until Vishnu writes them.

## Open questions (cards, one at a time)

1. ~~Core~~ **PICKED (2026-11-25): Captured, Charter ransoms you.** Disabled, victor boards and robs you, Charter pays ransom onto the lien, RANSOM RECEIPT, wake docked.
2. ~~Death~~ **PICKED (2026-11-25): only if you resist boarders.** When boarded: surrender or fight the breach. Fight and lose = death card, reload last dock.
3. ~~Take~~ **PICKED (2026-11-25): raiders take cargo + cash on hand.** Rig and outfits stay. Tallyman takes nothing (locked lore).
4. ~~Wing~~ **PICKED (2026-11-25): flyers flee, downed ones taken.** Escorts still flying break off and meet you at the dock. Disabled escorts are taken, their ransom on the receipt. Dez is aboard, taken with you.
8. ~~Ransom~~ **PICKED (2026-11-25): 2,500 + 500 per downed escort**, onto the lien.
5. ~~Time~~ **PICKED (2026-11-25): held 3 days, loan clock runs.** A payment due while held can mean a strike, and the cutter.
6. ~~Look~~ **PICKED (2026-11-25): paper trail.** Rig goes dark, hull clangs as they board (real recordings), fade to black, hand-ticked Day 1..3, RANSOM RECEIPT with red Charter stamp, wake docked, Charlie line.
7. ~~Reload~~ **PICKED (2026-11-25): capture sticks.** Only death offers reload of last dock.

## Out of scope

Prison/escape gameplay, slavery, player-as-captor ransom economy (combat-fitting.md covers prisoners you take), Scrapper/Miner variants. Revisit after Merchant ships.
