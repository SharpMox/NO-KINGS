# 37 — Split `test_items.gd`

Status: todo — INDEPENDENT

## Parent

`.scratch/gdd-gaps/PRD.md`

## Problem

`game/tests/test_items.gd` is **2682 lines** — 3.5x the next largest test file — and its
entire body is one flat `_init()` scope holding **254+ `var` declarations**.

That has cost real time. Three separate merges this session hit **variable-name collisions**
between branches that both appended a test block: `ark`/`arkb`, `full`, and one more. Git
does not flag them as conflicts because the lines do not overlap; Godot's parser catches them
only at run time. Every artefact slice now appends here, so the collision rate grows with
each one.

It is also the file most often reported flaky, simply because it is the biggest surface.

## What to build

Split by area, mirroring how the suite is already organised (`test_shop`, `test_box`,
`test_tiers`…): items, piece buffs, artefacts-by-group, tariffs. Each file gets its own
`_boot()`/`check()` helpers or a shared one via preload.

Register the new files in `run_all.sh`. Behaviour must not change — this is a pure move, so
every assertion should survive verbatim. If an assertion turns out to depend on state left by
an earlier one in the same file, that is a latent bug the split has just found: report it.

Coordinate with slice 36 — doing 36 first is probably easier, since seeding removes the
cross-test state coupling that would otherwise make the split risky.

## Acceptance criteria

- [ ] `test_items.gd` split into area files, none over ~600 lines
- [ ] Every assertion preserved verbatim; count them before and after and report both
- [ ] Any cross-test state dependency found is reported, not silently patched
- [ ] `run_all.sh` all green

## Blocked by

- ideally 36 first
