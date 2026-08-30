# 65 — Rename to Apocrypha; delete the Box Pick Tariff

Status: done (2026-08-30) — one Notion row left, needs delete access

## Parent

`.scratch/gdd-gaps/PRD.md`

Two small user rulings, one of which has a larger blast radius than it looks.

---

## 1. Bible Gag Reel Scroll -> **Apocrypha**

Issue 58 gave it a new effect (*"Bishop, Cardinal and Archbishop gain Shield when they
capture"*) but kept the old name, since "gag reel" described the reroll that was removed. The
user picked **Apocrypha** — short, and books excluded from the canon fits both the Vatican
Secret Archives anchor and the joke.

Display name only; **the key stays**. Same reasoning as issue 50's `bounty` -> "Skip Tracer's
Rolodex": keys are load-bearing (saves, `data/scenarios.gd`, the Shop), no player sees them,
and the problem being solved is what the card *displays*.

Update `data/artefacts.js`, re-export with `node tools/export-game-artefacts.mjs`, and update
the Notion row.

---

## 2. Delete the "Tariff on Box Pick" Tariff entirely

> User, 2026-08-30: *"the tariff on box pick shouldn't exist at all."*

Not re-costed, not deprecated — removed.

### Everything it touches

- `game/data/tariffs.gd:22` — the definition
- `game/scripts/artefact_hooks.gd:896` — its REGISTRY entry
- `game/scripts/artefact_hooks.gd:1908` — its `on_charge` dispatch case (it shares a match arm
  with five other cost Tariffs; remove only its key)
- `game/scripts/game.gd:2661` — `Economy.charge(self, "box_cost")` in `_open_box_pick`
- `game/scripts/game.gd:2748` — a comment about not re-charging it on Reroll
- **7 test references** across `test_items_artefacts_3.gd` (6) and `test_game_clicks.gd` (1)

### The tests are the interesting part — do not just delete them

Those assertions exist to prove **a Box Reroll does not re-charge the Box** (issues 46 and 47).
They were the guard on a real bug class. Removing `box_cost` removes the only thing that
*could* double-charge — so they become genuinely moot, not merely inconvenient.

**Say that explicitly in the commit** rather than quietly deleting proof. If any of them can be
repointed at a surviving once-per-Box property, prefer that to deletion; if not, delete them
with a comment recording what invariant they used to protect and why it no longer applies.

### The knock-on: the Mild tier drops from 7 entries to 6

`Tariffs.TARIFFS` currently has 7 Mild-tagged entries (move / ability / capture / pass /
long-range / box / inflation). Removing `box_cost` leaves **6**.

That invalidates arithmetic on the Notion **King Tariffs** page, which was corrected *twice*
this session — first from 8 to 7 entries (117,649 = 7^6), then its downstream "~94.9 billion
total sequences" recomputed to match. Both need updating again to **6 entries / 46,656 (6^6)**
and a re-derived total.

**Update those numbers as part of this change**, not before it — the drift agent has been told
to hold off precisely so they get fixed once against the real post-removal `tariffs.gd`.

Also check `Tariffs.SCHEDULE` and anything else that assumes a Mild-tier count or samples from
the Mild pool.

### Context worth knowing

Tariffs are currently paused (`TARIFFS_SCHEDULED := false`) and a **full Tariff rework is
coming**. This deletion is still worth doing now — it is a design decision, not a tuning one,
and leaving a Tariff the user has said should not exist would mislead the rework.

## Acceptance

- Apocrypha renamed in `data/artefacts.js`, exported, and updated in Notion.
- No reference to `box_cost` survives in `game/`, and its Notion row is gone.
- Opening a Box costs no Gold under any Tariff state.
- The retired reroll assertions are either repointed or deleted **with their reasoning
  recorded**.
- King Tariffs' entry count and both derived figures updated to the post-removal reality.
- Tests in the split suites, seeds pinned. `run_all.sh` ALL GREEN — run with
  `timeout: 600000`, blocking, alone.

## Blocked by

- nothing

## Outcome

Shipped in PR #226.

**Apocrypha** renamed, key `bible-gag-reel-scroll` retained. This needed a small architectural
addition: `tools/export-game-artefacts.mjs` derived keys by slugifying the name, so a display
name diverging from its key was previously impossible. It now reads `a.key || slugify(a.name)`,
with the existing collision check preserved. Apocrypha is the only real user of the override.

**`box_cost` is gone from the entire repo** — verified by `grep -rn` returning nothing. Sites
removed: the definition, the REGISTRY entry, its key in the shared `on_charge` match arm, the
`Economy.charge` call, two comments, and **`data/scenarios.gd:245`** — a tariff fixture that
was not in the issue's list and would have silently no-op'd.

**The six reroll assertions were repointed, not deleted.** They existed to prove a Box Reroll
does not re-charge the Box (issues 46/47). With `box_cost` gone nothing can double-charge, so
the original guard was moot — but rather than delete the proof, the block now holds **every
remaining Mild-tier Tariff at once** and asserts Gold is unchanged across an open plus two
rerolls. That is a strictly stronger property than the one it replaced, and a comment records
what the old invariant was and why it lapsed.

**Mild tier 7 -> 6.** King Tariffs' arithmetic recomputed (not estimated) to **46,656 (6^6)**
sequences, and the derived total to **~37.6 billion** (46,656 x 6,720 x 120).

### Left undone — needs a human or an agent with delete access

The **Tariffs Catalog's "Tariff on Box Pick" row** could not be removed:
https://app.notion.com/p/36ef1559c99b812b9722d328a410c989

The Notion MCP exposes no delete or archive command, and `agent-browser`'s Chrome has no
authenticated Notion session. The row was left **completely untouched** rather than
half-edited into an inconsistent state — the right call, but it means Notion still lists a
Tariff the game no longer has. **Delete it manually.**
