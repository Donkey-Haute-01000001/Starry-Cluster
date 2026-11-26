# UI look: neon everywhere

Status: **signed by Vishnu 2026-11-25.** Pick 2026-11-25: "A + B mix". **Changed 2026-11-26: all neon.** The pixel-paper contract mock was rejected ("way too illegible and ugly"); the neon contract was approved ("this is perfect"), then "Build it, all neon".
Mocks: `/mnt/project-files/sector-secundus/ui-look/` (A, B, C, now).

## Why the old look read as slop

1. Smooth vector paper on top of a pixel-art world. This is the biggest one.
2. Chatbot voice: a headline plus a helper line ("Pick up where you left off." / "Each career saves at every dock.").
3. Middot crumbs: "BERTH 14 · CAREERS · CONTROLS".
4. A full-size clipboard with 2 rows on it, so the sheet is mostly blank.
5. Lowercase twee buttons: "back to menu", "shred", "void".
6. Title, clipboard and pause menus all speak different languages.

## The split

Everything is neon: menus and documents alike. No paper, no clipboard.
Each screen is mocked, shown, and built only after Vishnu OKs it.

| Screen | State |
| --- | --- |
| Careers register, start picker, Settings, Controls, Pause | built |
| Start files (contract + sealed starts) | built |
| Title menu row | **unchanged** (locked) |
| Form ID-1 (name, rig, photo) | built |
| Form NK-2 (Dez contact) | built |
| Launch ID card | built |
| Ransom receipt, sector bulletin, dispatch slip | built |
| Journal | built: neon sections, list, pages (2026-11-26) |
| Chart | atlas on paper, kept by pick: territories, zoom, auto-placed names (2026-11-26) |

## Neon rules (menus)

- Dark fade from the right edge. No panel box and no border. The world stays visible on the left.
- Header: one word in tracked white Big Shoulders, the same style as the title row. No subtitle.
- Rows: VT323, uppercase. White when idle. The **selected row is gold with a glow and a caret**. Numbers are green. Danger is red. Disabled rows are dim.
- Light scanlines on the dark side only.
- On open, rows flicker on one by one (about 0.25 s total).
- Footer: key hints, also clickable (ENTER OPEN, DEL VOID, ESC BACK).
- Input: up/down or the mouse to select, Enter or a click to open, Esc to go back. Selection is remembered. Hover and selection play the same tick.
- Anything destructive takes two presses: the row turns red and reads "VOID? DEL AGAIN". The second press deletes it.

## Documents in neon

- The issuer in tracked white Big Shoulders, the form name and file number dim beneath.
- Typed content in VT323 on the dark; neon words glow in their colours.
- Numbers and terms green. Handwriting (pen notes, signatures) stays Nanum Pen, glowing pink like a sign in a window.
- One action row at the bottom (SIGN HERE, FILE IT), selected like any menu row.

## Copy rules (everywhere)

- No headline plus helper line, and no middot crumbs.
- Actions are caps verbs: BACK, OPEN, VOID, SIGN.
- The world doesn't explain itself. If a line only tells you how the UI works, cut it or move it to the footer key hints.

## Fonts

Courier Prime leaves the UI. Typed text is VT323. Big Shoulders, Stencil and Nanum Pen stay.

## References

- **Katana Zero:** menus as glowing text over the scene, a gold or red highlight, scanlines, flicker on open. We already use its word effects in the openings.
- **Citizen Sleeper:** menus stay out of the art's way. Text on a dark wash, never a box.

## Genre baseline check

- Keyboard navigation of every menu: missing today (mouse only). It's added with the neon menus.
- Gamepad: not supported anywhere yet. Flagged, not in scope.
- Confirm on destructive actions: yes (two-press void).
- Esc always backs out one level: partial today. Neon menus make it uniform.

## Build order

Mock, show, build, one screen at a time, in the table's order.
