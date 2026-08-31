# 79 — Scenario generator + the 180 Artefact sandboxes + a menu that survives them

Status: done (2026-08-31)

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

## Outcome (2026-08-31)

**180 generated sandboxes, one per Artefact; 240 scenarios total; the menu is now 17 headers
on a single screen with no scrolling at all.**

### The generator

`game/data/scenarios_artefacts.gd`. Boards are authored per **trigger family** (nine of them),
not per Artefact — `ArtefactHooks.REGISTRY` maps each key to its hooks, so the board that makes
it fire is derived rather than guessed. Each entry is `template + the Artefact held + a pinned
seed` (`abs(hash(key))`, so a sandbox lays out identically every time and a future diff of the
file reads as a real change). `scenarios.gd` keeps its hand-written list in `_hand_written()`
and `all()` returns that plus the generated set.

| Family | Count | Family | Count |
| --- | --- | --- | --- |
| Passive | 41 | Shop | 16 |
| Wave clear | 35 | Turn | 16 |
| Capture | 23 | Items | 7 |
| Losses | 19 | Buffs | 5 |
| Economy | 18 | | |

**41 land in Passive, not the ~33 issue 73 estimated.** 139 Artefacts carry a REGISTRY entry,
not 147. The estimate predates slice 69 removing the 7 game-native core effects; the generator
reads the live REGISTRY, so the split is accurate to the code rather than to the note.

Passive entries are **labelled "Passive" in their own name** and get a board where their
condition is visibly true (Gold, Score, Stock, Captured and an Item all populated) — the
issue's requirement that a scenario which cannot be made to fire says so, rather than silently
doing nothing.

Names are `"Artefact <Family>: <Name>"` **deliberately**: `menu.gd` derives sections from the
text before the first `:` or `(`, so this groups all 180 into nine sections with **no menu-side
special case at all**. The prefix contains neither character, so an Artefact name containing
`(` cannot break the cut.

### The menu: sections collapse, and start collapsed

77's sectioning was right for 53 entries and insufficient for 240 — the last section would
have been minutes of dragging away. Headers became flat Buttons that toggle their rows;
everything starts closed. The whole catalog is one screenful of headers, at the cost of one
click to reach any entry. **That trade is only worth it at this size, which is why 77 did not
make it.**

### The probe change matters more than it looks

Reachability is now a **two-step** property, and the probe asserts both steps: headers exist,
every section starts collapsed (0 rows showing), a header click expands and re-labels, and the
last entry of the last section is then reachable. **A probe that only searched for the button
by text would have passed against a list that never expands** — `_find_button` is
visible-first, so it would simply have found nothing and the old assertion would have failed
for the wrong reason. The final config-staging click reuses that same entry, which also proves
the expanded state survives Back-and-reopen (Back hides the list, it does not rebuild it).

### Suite runtime — reported as the issue asked

| | Before | After | Delta |
| --- | --- | --- | --- |
| `test_scenarios.gd` | 17.9s (60 cases) | **75.9s (240 cases)** | **+58s** |
| `run_all.sh` total | — | **132.9s** | — |

~0.3s per scenario, unchanged per-case — the cost is purely the 180 extra boots. At 133s for
the whole suite this does **not** warrant splitting `scenarios.gd` into swept and sandbox-only
sets; issue 73's trigger for that split ("if the count ever grows enough to slow the suite")
is not met. Revisit if slices 80-82 push it past a few minutes.

`game/tests/run_all.sh` — **ALL GREEN**, foreground, alone.
