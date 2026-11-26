# Hold view (inventory)

Status: **signed and built** (Vishnu 2026-11-26). From the 2026-11-26 playtest: the tester "couldn't understand what she was holding or why" and asked for an inventory.

## What's there today

- System plate: `Hold 20/40 t` (a number, no contents)
- Pinned job line: with no job, a TRADE hint lists hold contents + where they're needed
- Station market: an "in hold" column, only while docked
- Goods have a name, slang and a one-line `desc` in `Data.goods`, shown nowhere in flight

## How others do it

- **Endless Sky:** cargo shows only on the trade screen and the ship info panel (I). Missions in the hold are listed by name with destination.
- **Elite Dangerous:** a cargo tab in the left cockpit panel. Each line: good, tons, mission or own, stolen flag. Select one for a description.
- **Mount & Blade:** a full inventory screen (I), with item cards that show what it's worth and where.
- **FTL:** no hold. Cargo is a small strip on the ship screen.

## Genre baseline

- See your cargo in flight, not only when docked
- Job cargo told apart from your own
- What it's worth / where it sells
- A line of flavour on what the thing is

## Locked

- **Where: both** (Vishnu 2026-11-26). HUD strip under the system plate while you carry cargo; HOLD tab in the journal for detail.
- **Lines: where + money** (Vishnu 2026-11-26). Good, tons, JOB → station or who wants it, what you paid, today's best price where it's wanted, profit. Tracking what you paid is new (average cost per ton, kept in the save).

## Built

- **Strip:** one row per good, at most 4, then "+N more". `WATER 20 t  JOB → Greenhouse` / `PARTS 10 t  paid 52  Greenhouse 71  +190`. Profit green, loss red.
- **Tab:** HOLD, first tab in the journal. `I` opens the journal on it (rebindable). Pauses, like the journal. Each good: name + slang, tons, paid/t, best price and station, profit, the `desc` line. Job cargo lists the job, its pay and the due station.
- Buying more of a good averages the paid price. Selling doesn't change it. Job cargo has no paid price.
