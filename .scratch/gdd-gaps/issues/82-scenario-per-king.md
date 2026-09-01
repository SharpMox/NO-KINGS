# 82 — A sandbox per King (16)

Status: todo — UNBLOCKED 2026-09-01 (all 16 kits shipped in slice 93)

## Parent

`.scratch/gdd-gaps/issues/73-scenario-coverage.md` (the King set)

## Scope

One board per King: that King as the boss, reachable immediately rather than at wave 50, with
its Power active and its Abilities triggerable — so the kit can be seen without playing a
50-wave run to get there.

This is the highest-value part of 73 and the only part that is blocked. Kings appear at waves
50 / 100 / 150; before slice 78 no run had ever reached one. A sandbox is the only practical
way to look at a King's kit at all.

## Why it is blocked

`game/data/kings.gd` is identity and selection only — *"no per-King mechanics are specced
anywhere, so none are invented here."* There is nothing to build a sandbox around until the
design session assigns Powers and Abilities.

**Only one mechanic is assigned today:** Tariff is Donald Trump's King Power (slice 66).

## Acceptance

- One entry per King, boss present from the first turn, Power visibly active.
- Each Ability reachable — whatever trigger the design session settles on, the board must be
  able to produce it on demand.
- Boots under `test_scenarios.gd`.
- `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

- the Kings design session (`.scratch/gdd-gaps/KINGS-DESIGN-WORKSHEET.md`)
- the slices that session produces — a sandbox cannot precede the mechanics
- 79 (menu grouping)
