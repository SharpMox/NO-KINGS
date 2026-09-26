# NO-264: Guide images, plan (step 1)

Options: **A** = crop of a real capture (`game/tools/guide_captures.gd`, driven by the `--screenshot` seam in `tools/capture.md`). **B** = image generated from the game's own assets off-screen (`game/tools/guide_images.gd`: piece tokens, board theme, `COL_*`/hatch/outline constants, Buff badges, Pixel Operator).

Rule of thumb used below: **A** when the section teaches a piece of real UI the player has to find (HUD, drawers, Shop, menus); **B** when it teaches a concept or a board mark, where a clean picture beats a busy real board.

Guide structure is from `game/scripts/guide.gd` (hub + 7 pages + one shared detail panel); Rules sections are from `game/data/guide_text.gd`.

| Page | Section | What it explains | Image idea | A/B | Why |
|---|---|---|---|---|---|
| Hub | (7 page buttons) | Navigation only | None; at most a small board-strip header | B | Decorative at most, nothing to teach |
| Rules | Objective | Win on the wave-50 King; three ways to lose | Win screen crop (`--show-screen win`) beside the loss screen (`--show-screen gameover`) | A | The end screens are real UI with exact wording; a generated mock would drift |
| Rules | Board | 8x12; free placement on two back rows; later deploys onto those rows or beside your pieces | Board outline, back two rows tinted, deploy dots on the rows and next to a mid-board piece | B | One picture shows both placement rules; the SETUP capture shows only the first |
| Rules | Turns | 2 Actions, each piece moves once, PASS ends the turn | Deck crop: Action pips + PASS button | A | Points at the real controls |
| Rules | Merging | Tap/drag onto a twin to promote, onto a partner to fuse | **Built:** `merge-pawns` (Pawn + Pawn → Sergeant, B) and `rules-merging` (a Ferz selected, its twin ringed, A) | B | The strip states the rule; the board crop shows the cue. Compare both |
| Rules | Stock | Captured Stock, Convert, Sell for half | Stock drawer open (`--open-drawer stock`), Captured row visible | A | A drawer the player has to find |
| Rules | Shop & Boxes | Restock timing; Box choices | Box pick (`--show-screen box`) and the open Shop (`--open-shop`) | A | Real modals, real prices |
| Rules | Army | Power always on; Ability 1 Action per wave; Reinforcements | Armies carousel card (`--show-screen armies --army-name Crown`) | A | The card already lays out Power and Ability |
| Rules | Kings | Kings on waves 50/100/150/200; King Power | King Wave header chip + King Abilities overview (`--show-screen king-abilities`) | A | Real HUD chip the player must recognise |
| Rules | Clock | 15 min, +5 s a turn, bonuses | Header crop around the Clock | A | Real HUD element |
| Pieces | list | 38 pieces, token + value | None; rows already show tokens | — | Nothing to add |
| Pieces | detail panel | Movement diagram + chain, twin, fusions | "How to read a diagram": three small diagrams (Knight dots, Pawn ring + cross, Rook arrows), labelled, drawn with `PieceDiagram.draw` itself | B | The one-line LEGEND is cryptic; the diagram code is reusable as-is |
| Promotions | list | 8 Families | One chain strip, base → top, captioned "merge two of the same" | B | Reads straight off `pieces.json` `next` |
| Promotions | detail panel | Same as piece detail | None (shares the piece detail) | — | Covered above |
| Fusions | list | A + B → C | One fusion strip from `fusions.json`, same layout as `merge-pawns` | B | Same generator as Merging, different data |
| Fusions | detail panel | Same as piece detail | None | — | Covered above |
| Artefacts | list | 180 Artefacts, rarity dot | Inventory drawer holding several Artefacts ("Artefacts: sixteen held" scenario, `--open-drawer inventory`) | A | Teaches where Artefacts live in play |
| Artefacts | detail panel | Art, rarity, effect | None (already shows 128px art) | — | Nothing to add |
| Items | tier note | Tactical/Strategic/Decisive prices | None | — | Text is enough |
| Items | Items section | Usable Items and their targeting | An armed Item's red target zone on the board (`--arm-item <key> --anchor x,y`) | A | Real targeting UI, prompt included |
| Items | Piece Buffs section | Buffs ride on a piece | **Built:** `buff-badges` (a Rook with 1 Buff, 2 Buffs, Stunned) | B | Exact badge layout, no board clutter |
| Items | Item / Buff detail | One entry | Buff detail: one tile carrying that Buff's badge (13 images, one loop in the B tool) | B | Shows what that Buff looks like on the board |
| Indicators | Move, Capture, Selected, Merge partner, Reachable zone, Zone overlap, Blast zone, Placement, Your/Enemy pieces, Inverted | The board's visual language | One small slice per row showing the mark in context; **built:** `knight-moves` covers Move, Capture, Selected, Reachable zone | B | Exact palette from the constants; captures would need a scenario per mark |

## Built in step 1

- B: `knight-moves` (5x5 slice), `merge-pawns`, `buff-badges`, written to `game/assets/guide/<name>.png` at 2x.
- A: `rules-merging` ("Merge: on the board", `--select 2,1`, cropped to board tiles x 0-6, y 0-2), written to `game/assets/guide/rules-merging.png`.

The ticket's example "two Pawns → Ranger" does not match the data: `pieces.json` gives `pawn.next = sergeant`. The image reads the data, so it shows a Sergeant.
