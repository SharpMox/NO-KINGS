# 79 — Scenario generator + the 180 Artefact sandboxes + a menu that survives them

Status: todo

## Parent

`.scratch/gdd-gaps/issues/73-scenario-coverage.md` (split (a), plus the menu prerequisite)

## Scope

The generator, the board templates, one sandbox entry per Artefact, and the menu sub-grouping
that lands in the same slice **because 180 new entries arrive in it**. Shipping the generator
without the grouping would leave the scenario menu unusable at the exact moment it matters.

### The generator

Per **trigger family**, not per Artefact — `artefact_hooks.gd`'s `REGISTRY` already maps each
key to the hooks it listens on, so the board that makes it fire is derivable rather than
hand-authored. Roughly eight templates (see 73's table). Each entry is
**template + the Artefact held + a pinned seed**.

The 33 Artefacts with no `REGISTRY` entry are passive reads; give them a board where their
condition is **visibly true** rather than a board where nothing happens.

**Where a template genuinely cannot make one fire, say so in the generated name** (e.g. needs
a King). A scenario that silently does nothing is worse than one labelled as needing setup.

### The menu

Slice 77 sectioned by name prefix, which handled 53 entries. The Artefacts section alone is
now 180. Sub-group it — the generator knows both rarity and trigger family, so either axis is
free — or make sections collapsible, which 77 was built to allow without restructuring.

## Watch out

- **`test_scenarios.gd` boots and bot-plays everything in `game/data/scenarios.gd`.** These
  entries get a free smoke test whether or not anyone wants one: they must boot and not crash.
  That is the acceptance bar, not "the Artefact fires".
- **Report the suite-runtime delta.** 180 extra boots is the first thing in this repo with a
  real chance of making `run_all.sh` slow. If it does, that — not before — is the moment to
  split `scenarios.gd` into swept and sandbox-only sets.
- Generated entries must be **deterministic**: pinned seeds, stable ordering, stable ids.
  A generator that reshuffles on every run makes every future diff unreadable.

## Acceptance

- One entry per Artefact, loadable from the menu and playable by hand.
- The menu is navigable at 480x800 — grouped and scrollable, never a flat 180-row list.
- Menu click probes extended to cover the grouping (open a group, reach an entry).
- Everything boots under `test_scenarios.gd`'s sweep.
- `run_all.sh` ALL GREEN, foreground, alone — **with the runtime delta reported**.

## Blocked by

- nothing
