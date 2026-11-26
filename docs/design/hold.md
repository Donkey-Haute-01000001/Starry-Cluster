# Hold view (inventory)

Status: **draft spec, picks open.** From the 2026-11-26 playtest: the tester "couldn't understand what she was holding or why" and asked for an inventory.

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

## Open questions (one card each)

1. Where it lives: journal tab, HUD strip, or both
2. What each line shows
3. Key (I?) and whether it pauses
