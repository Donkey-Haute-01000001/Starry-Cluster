# UI look: neon menus, pixel paper

Status: **signed by Vishnu 2026-11-25.** Pick 2026-11-25: "A + B mix".
Mocks: `/mnt/project-files/sector-secundus/ui-look/` (A, B, C, now).

## Why the old look read as slop

1. Smooth vector paper on top of a pixel-art world. This is the biggest one.
2. Chatbot voice: a headline plus a helper line ("Pick up where you left off." / "Each career saves at every dock.").
3. Middot crumbs: "BERTH 14 · CAREERS · CONTROLS".
4. A full-size clipboard with 2 rows on it, so the sheet is mostly blank.
5. Lowercase twee buttons: "back to menu", "shred", "void".
6. Title, clipboard and pause menus all speak different languages.

## The split

**Menus are neon (B).** These are things you operate, not things in the world.

| Screen | Now | Becomes |
| --- | --- | --- |
| Careers register | clipboard sheet | neon list |
| New career: pick a start | clipboard "Who were you?" | neon list of starts |
| Settings, Controls (title) | clipboard sheets | neon |
| Pause, Settings, Controls (Esc) | white caps | same neon as the title |
| Title menu row | white Big Shoulders, hover underline | **unchanged** (locked) |

**Documents are pixel paper (A).** These are things in the world that someone printed.

| Screen | Order |
| --- | --- |
| Start contract (Financing Agreement) | 1 |
| Form ID-1, Form NK-2 (contact) | 2 |
| Launch ID card | 3 |
| Ransom receipt, sector bulletin, dispatch slip | 4 |
| Journal and chart | 5 (biggest; last) |

## Neon rules (menus)

- Dark fade from the right edge. No panel box and no border. The world stays visible on the left.
- Header: one word in tracked white Big Shoulders, the same style as the title row. No subtitle.
- Rows: VT323, uppercase. White when idle. The **selected row is gold with a glow and a caret**. Numbers are green. Danger is red. Disabled rows are dim.
- Light scanlines on the dark side only.
- On open, rows flicker on one by one (about 0.25 s total).
- Footer: key hints, also clickable (ENTER OPEN, DEL VOID, ESC BACK).
- Input: up/down or the mouse to select, Enter or a click to open, Esc to go back. Selection is remembered. Hover and selection play the same tick.
- Anything destructive takes two presses: the row turns red and reads "VOID? DEL AGAIN". The second press deletes it.

## Pixel paper rules (documents)

- Draw at the art's pixel scale (2 screen px per paper px), nearest filter, no anti-aliasing.
- Small palette: 4 paper tones, plus ink black, form green, stamp red and pen blue.
- Dithered hard shadow, a torn or perforated edge, a little wear (speckle, one coffee ring at most).
- Pre-printed parts in form green: headers, rules, column heads. Filled-in parts in black.
- Print font: VT323. Handwriting: Nanum Pen, rendered at pixel scale. Stamps: Big Shoulders Stencil at pixel scale.
- Each sheet is sized to its content. No clipboard.

## Copy rules (everywhere)

- No headline plus helper line, and no middot crumbs.
- Actions are caps verbs: BACK, OPEN, VOID, SIGN.
- The world doesn't explain itself. If a line only tells you how the UI works, cut it or move it to the footer key hints.

## Font lock change

Courier Prime leaves the UI. Print on paper is VT323. Big Shoulders, Stencil and Nanum Pen stay.

## References

- **Papers Please:** pixel documents in a cramped palette. Every form looks printed by a bureaucracy, and nothing on it explains itself.
- **Katana Zero:** menus as glowing text over the scene, a gold or red highlight, scanlines, flicker on open. We already use its word effects in the openings.
- **Citizen Sleeper:** menus stay out of the art's way. Text on a dark wash, never a box.

## Genre baseline check

- Keyboard navigation of every menu: missing today (mouse only). It's added with the neon menus.
- Gamepad: not supported anywhere yet. Flagged, not in scope.
- Confirm on destructive actions: yes (two-press void).
- Esc always backs out one level: partial today. Neon menus make it uniform.

## Build order

1. Careers register (neon). Show it.
2. Pause, Settings and Controls (neon, title and in-flight sharing one script). Show them.
3. New career start picker (neon).
4. Documents to pixel paper, one per step as in the table above.
