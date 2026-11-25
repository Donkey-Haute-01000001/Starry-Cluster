# Economy

Loop to protect (Vishnu's favorite part of Endless Sky): fill cargo, first jumps, profit, top off spare space, pay the debt, buy ships. Keep outfitting approachable.

## Rules

- **Comparative advantage:** each station makes some goods (cheap, ×0.8) and buys what it can't make (pays well, ×1.25). Prices drift weekly. No "air" good.
- **Everything recurring is weekly:** loan, wages, upkeep. A day = 60 s of flight.
- Numbers live in `Data` (`LOAN_TOTAL` 40,000, `LOAN_WEEKLY` 1,200, `START_CREDITS` 2,000, `REPO_FEE` 2,500, `OBSTRUCTION_FEE` 2,000); logic in `Career`.

## Goods

water, rations, ore, alloy, parts, electronics, medicine, luxuries (+ `sealed` job crates).

## Hesper March ("the Long Haul")

| System | Role | Stations (makes → wants) |
| --- | --- | --- |
| Aurelia | Safe core | Counter (electronics → luxuries, medicine), Bones (parts → alloy), Drip (water → rations) |
| Tiberine "the Garden" | Mid | Greenhouse (rations, medicine → water, parts, electronics) |
| Marcellus | Rough belt, best profit | Four (ore → rations, water, parts), Saltgate (alloy → ore, water, rations, medicine), Amber's (electronics, parts → medicine, luxuries; black market) |
| Porta Aquila "the Wall" | Fortress gate | Gatehouse (luxuries, really imports → rations, water, medicine) |

Lanes: Aurelia–Tiberine artery > Aurelia–Marcellus > Tiberine–Porta Aquila > Marcellus–Porta Aquila. Miners never leave Marcellus.

## Debt

- Missed payment = strike + 10% of the payment added. Two strikes = Charter repo cutter hunts you (ion only). Caught = cargo seized + 2,500. Driven off = 2,000 obstruction fee. Jumping out shakes it.
- Weekly no-questions job worth one payment (any station but Counter/Gate). Navy customs scans can bust it.
- Run dry past the beacon ring = Charter tow, ~1,500 on the lien, wake docked.

## Traffic

Most haulers are liened owner-operators in Charter amber; big Charter haulers only on the artery. Navy faces the Wall; Marcellus gets one cutter out of Four. Pirates: petty belt raiders + Tally's crew (Charter only) + Dynasty-sponsored raiders paid at Amber's.

## Later

Supply contracts → owned trade fleet with captains on routes → markets shifting with wars. Territory income (M&B fiefs). Outposts deferred.
