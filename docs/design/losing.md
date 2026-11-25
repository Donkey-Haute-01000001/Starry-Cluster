# Losing (capture, ransom, rare death)

Status: **DRAFT, not signed.** Gap #1 of `baseline-audit.md`. Thread: "Design losing and capture".

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

## Draft shape (recommendation, pending cards)

1. **Player can be disabled.** At 15% hull your rig goes dead in space like any NPC. Turrets go quiet. Escorts fight on; if they drive the attacker off, you get towed or limp home.
2. **Whoever beat you boards.** What happens depends on who:
   - Raiders: take cargo + credits on hand, hold you for ransom.
   - Tallyman: takes nothing. He counts. (Scene, not a fee.)
   - Charter Recovery: already built (seize + fee + tow).
   - Navy: already built as customs bust.
3. **The Charter pays your ransom and bills the lien.** You are collateral. Losing makes you *more owned*, not dead. A **RANSOM RECEIPT** printout, same paper family as TOW SLIP.
4. **Time passes** while you're held (days). A payment can fall due. Strikes ripple into the repo cutter.
5. **Wake docked** at the nearest friendly station, with a line from Charlie / Dez.
6. **Death is rare and earned.** Only if you're destroyed outright (e.g. still taking fire while disabled, or a specific killer). Then an authored death card, and reload from last dock.

## Open questions (cards, one at a time)

1. ~~Core~~ **PICKED (2026-11-25): Captured, Charter ransoms you.** Disabled, victor boards and robs you, Charter pays ransom onto the lien, RANSOM RECEIPT, wake docked.
2. ~~Death~~ **PICKED (2026-11-25): only if you resist boarders.** When boarded: surrender or fight the breach. Fight and lose = death card, reload last dock.
3. ~~Take~~ **PICKED (2026-11-25): raiders take cargo + cash on hand.** Rig and outfits stay. Tallyman takes nothing (locked lore).
4. ~~Wing~~ **PICKED (2026-11-25): flyers flee, downed ones taken.** Escorts still flying break off and meet you at the dock. Disabled escorts are taken, their ransom on the receipt. Dez is aboard, taken with you.
8. Ransom amount (flat, or scales with rig/wing?).
5. Time cost: how many days, and does it trigger payments/strikes?
6. The defeat moment: look and sound (printout, stamp, Katana Zero-style line).
7. Reload: allowed always, only on death, or an ironman setting?

## Out of scope

Prison/escape gameplay, slavery, player-as-captor ransom economy (combat-fitting.md covers prisoners you take), Scrapper/Miner variants. Revisit after Merchant ships.
