# 09 — The 16-King cast

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

The [Kings](https://app.notion.com/p/3b0f1559c99b8092b2d3e4d0570bd59a) page defines a cast
of **16 named Kings** across four costume tiers — 🌿 Laurel, 🎩 Hat, 🎖️ Uniform, 👔 Suit —
each with its own Notion page, plus 13 documented reserves and a ratified casting rule.

The game has one anonymous `king` piece. Waves 50, 100 and 150 spawn the identical thing.
The entire cast, the tiers and the conspiracy lore the artefact catalogue leans on are
absent, and the King is also the one piece with no painted art (it still renders as the
old cream disc beside 38 painted tokens).

1. **King identity as data** — id, display name, tier, per the Notion cast.
2. **Selection** — which King shows up on a King wave. The GDD does not say; simplest
   coherent rule is tier-ordered by depth (wave 50 / 100 / 150 escalate), with the roster
   sampled within a tier. Decide and record it.
3. **Surfacing** — the King wave banner names the King; the end screens report which were
   defeated. `kings_defeated` is already a count, not a roster.
4. **Art** — `king-light.png` / `king-dark.png` per King. The loader already picks these
   up with no code change (`mono_art` falls back until they exist), so art can land
   independently of the mechanics.

Per-King *mechanics* are not specced anywhere — do not invent them here. This slice is
identity, selection, presentation and art only.

## Acceptance criteria

- [ ] All 16 Kings exist as data with name and tier
- [ ] A King wave spawns a named King by a recorded rule
- [ ] The wave banner names it; end screens list which were defeated
- [ ] Save/load preserves which King is on the board
- [ ] King art wired (or cleanly absent, still falling back)
- [ ] `run_all.sh` all green

## Blocked by

- nothing
