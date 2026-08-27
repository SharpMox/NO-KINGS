# PRD: GDD gap bridge

Status: in progress

## Problem Statement

A full sweep of the Notion GDD against the Godot prototype on 2026-08-27 (every page and
database under <https://app.notion.com/p/367f1559c99b8102bb9ccf0914992eeb>, artefacts
excluded) found three distinct kinds of gap:

1. **Specced but unbuilt** — whole systems the GDD describes that have no code at all:
   Piece Buffs and the Buff Box that delivers them, the 16-King cast, Difficulty Ranks,
   Arrow Planning, the Game Seed System, Settings, and cloud saves.
2. **Built but diverged** — where the prototype and the doc disagree. Most of these are
   *deliberate* and already logged on the GDD's own
   [Fable Prototype Test](https://app.notion.com/p/391f1559c99b8160ac40e2fe5a47000f) page
   (13 entries). Those are decisions, not debt, and this PRD does not undo them.
3. **Doc-vs-doc contradictions** — pages that newer pages have silently superseded. The
   `Score` page still says placements and tariffs cost Score, which the 2026-08-27 `Shop`
   and `Reward Economy` pages explicitly reversed (everything debits Gold; Score never
   falls). `Captured Stock` still describes 3-piece merges. `Board` and `Overview` still
   say 6×8. Two entries on the divergence list itself are now stale.

Left alone the doc keeps drifting from the build, and the drift is now bidirectional —
which is exactly how the Blitz and Demote item drift went unnoticed for a month.

## Solution

Bridge the gaps as independently-grabbable vertical slices, ordered so that the cheap
correctness fixes and the doc reconciliation land first (they stop further drift), the
biggest missing *player-facing* system second (Piece Buffs), and the large or
externally-dependent work last (Shop UI, cloud saves, hook architecture).

Every slice is a tracer bullet: it goes end to end through data → logic → UI → tests
rather than building a layer at a time.

## Scope

| Slice | What | Size | Blocked by |
| --- | --- | --- | --- |
| 01 | Run seed & deterministic resume | S | — |
| 02 | Notion reconciliation (doc only, no code) | S | — |
| 03 | Piece Buffs: delivery path + 3 buffs | L | — |
| 04 | Piece Buffs: the remaining 9 | M | 03 |
| 05 | Menus & Settings shell | M | — |
| 06 | Animations toggle + OS-background pause | S | 05 |
| 07 | Difficulty Ranks | M | 05 |
| 08 | Shop right-edge drawer UI | L | — |
| 09 | The 16-King cast | M | — |
| 10 | Arrow Planning | S | — |
| 11 | Enemy AI parity (2 actions, protect the King) | M | — |
| 12 | Accounts & cloud saves | XL | 05 |
| 13 | Hook architecture | L | — |

## Out of scope

- **Artefacts** — excluded by explicit user instruction 2026-08-27; the 180-entry catalog
  and its shop/box wiring are tracked separately.
- **The 13 deliberate divergences** on the Fable Prototype Test page. Slice 11 revisits
  exactly one of them (enemy actions) because the GDD number was never actually tried;
  the rest stand.
- **Procedural waves past 150** — divergence #8, a standing decision.

## Open questions

- [ ] `Pieces & Movement` says a failed attacker "bounces back to its starting position."
      Nothing in the prototype does this and no other page mentions it. Dead text from an
      older combat model, or a missing rule? Slice 02 asks.
- [ ] `Stock` says capacity depends on team + bonuses. The prototype has no cap and none
      of the three armies implies one. Confirm the cap is genuinely unwanted before
      deleting the line.
- [ ] Slice 12 needs a product decision (cross-platform account vs platform-siloed saves)
      before any code; it is a spike first, not an implementation slice.
