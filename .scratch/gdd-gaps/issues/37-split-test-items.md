# 37 — Split `test_items.gd`

Status: done — INDEPENDENT

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

- [x] `test_items.gd` split into area files, none over ~600 lines
- [x] Every assertion preserved verbatim; count them before and after and report both
- [x] Any cross-test state dependency found is reported, not silently patched
- [x] `run_all.sh` all green

## Blocked by

- ideally 36 first (done — `_boot()`/`DEFAULT_SEED` pinning from slice 36 was preserved
  identically in every split file)

## Outcome

Split into 7 files: `test_items.gd` (core item abilities), `test_items_tariffs.gd`,
`test_items_buffs.gd`, `test_items_artefacts_1.gd` through `_4.gd` (the bulk, by
issue-cluster). 340 assertions before, 340 after — verified by a script-checked multiset
diff of every non-blank statement line against the original, not just a count match.
Largest file is 568 lines.

**No latent cross-test state dependency was found.** Each of the 7 files also passes when
run standalone (`godot --headless -s tests/test_X.gd`), so nothing in the original file was
silently relying on state left behind by an earlier assertion in the same `_init()` scope —
the seeding from slice 36 evidently did remove that coupling, as this issue predicted.

One structural note, not a behavior change: the file's only inline mid-`_init()` const
(`const BuffLogic := preload(...)`) was hoisted to a top-level const in the 3 files that
use it, since a local const from one split file isn't visible in another.

PR: https://github.com/SharpMox/NO-KINGS/pull/154
