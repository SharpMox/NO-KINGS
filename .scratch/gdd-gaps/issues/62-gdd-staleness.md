# 62 — GDD staleness found by the 2026-08-30 audit

Status: done (2026-08-30) — 1, 2, 3, 4, 6 fixed; 5 resolved as "documented, deliberately not renumbered"

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

After the 23-page GDD sweep, a read-only audit checked the wider document against the actual
constants in `tuning.gd`, `tariffs.gd`, `box.gd`, `items.gd` and the generated catalogs. Six
findings, ranked by how likely each is to mislead someone building from the doc.

**These are Notion edits, not code.** The code is right in every case below; the document is
wrong.

## 1. Tariffs are switched off, but four pages present them as live

`Tuning.TARIFFS_SCHEDULED := false` gates off both the wave-1 Inflation and the every-10-wave
tier draw. That is a **temporary pause** (user, 2026-08-28, pending a combined Kings + Tariffs
pass) — the design is not being challenged. It is honestly recorded on **Fable Prototype
Test**, and nowhere else.

These state Tariffs as current behaviour with no pointer to the pause:
[Overview](https://app.notion.com/p/367f1559c99b81fb93bed84ca15e035b) ·
[King Tariffs](https://app.notion.com/p/367f1559c99b8196910ccbf10bb56c7c) (a full page of
precise math presented as running now) ·
[Wave Catalog](https://app.notion.com/p/367f1559c99b810d997de389af8920cf) ·
[Score](https://app.notion.com/p/367f1559c99b812ab1e8c4feafef14bd)

Add a pause pointer to each. Do not rewrite the design — it is coming back.

## 2. Turn mechanics described with the pre-unification model — highest impact

[Pieces & Movement](https://app.notion.com/p/367f1559c99b81b394b8faa429cf8151) and
[Game Flow — Player Turn](https://app.notion.com/p/367f1559c99b81d6a29cf9d567472ffe) both
describe **move-count and placement-count as independent per-turn pools**
("total move count per turn = basic move count + active bonuses", "place a number of pieces
equal to basic piece-placement count + bonuses").

The shipped game unified these on 2026-07-06/07: **one `ACTIONS_PER_TURN := 2` pool**, where a
move *or* a place *or* a merge *or* an Item each costs 1, and the turn auto-passes when spent.
Tracked as divergence #12, and already correct on **Difficulty Ranks**.

**These are the two pages someone reads first to learn how a turn works**, and they teach a
model the game has not used since July. Fix these before anything else in this issue.

## 3. Enemy AI Behaviors states the wrong action count

[Enemy AI Behaviors](https://app.notion.com/p/367f1559c99b81a8958edbf4a0f30762) says *"The AI
takes 2 actions per Turn by default."* Shipped: `ENEMY_ACTIONS_PER_TURN := 1`.

**Issue 59 owns this fix** — it resolves the divergence as "baseline 1, Tier 5 restores 2".
Listed here for completeness; do not double-fix it.

## 4. The Clock's start value is 6x stale

[Clock](https://app.notion.com/p/367f1559c99b811da2d2c6d8ebac0ce7): *"Starts at a generous
budget (TBD — e.g., 30 min)."* Shipped: `CLOCK_START_MS := 5 * 60 * 1000` — **5 minutes**,
user call 2026-07-07.

The page's other three Clock numbers match `tuning.gd` exactly; only the headline is wrong —
and it is the one anyone tuning pacing would anchor on. The Board page's 8x12 change from the
same era got a reconciliation note; this never did.

## 5. The Tariffs Catalog's Cost numbers are ~10-20x too high

`tariffs.gd`'s own header says it plainly: *"upstream costs (200/500/1000) assume a much larger
score economy... amounts here live in tuning.gd, scaled ~/100"*. Shipped:
`TARIFF_ACTION_COST := 10`, `TARIFF_LR_PER_SQUARE := 5`.

Verified on **Tariff on Box Pick** (Cost reads "200 / 500 / 1000"). Almost certainly systemic
across the whole [Tariffs Catalog](https://app.notion.com/p/8906ed7b41da4b64a800f30af3494c8d)
DB, but **not verified row by row** — the auditing agent had no `agent-browser` access and
could not enumerate the table. A full pass needs real browser access.

Note issue 57 multiplies Score by 10, which changes the target these should be scaled against —
**do this after 57 lands**, or the numbers will be stale twice.

## 6. Minor: King Tariffs' Mild-tier count is off by one

King Tariffs says *"Mild (8 entries / 6 slots... 262,144 distinct sequences"* (8^6). `Tariffs.TARIFFS`
has **7** Mild entries (move / ability / capture / pass / long-range / box / inflation), so it is
7^6 = 117,649. Moderate (8) and Severe (5) both check out. Low priority while the cadence is
paused.

## Confirmed accurate (recorded so nobody re-checks)

Board 8x12 · Army/Queen Choice's "Long Ma"/"Duchess" (display names for `kirin`/`alibaba`, not
drift) · Wave Catalog's 3-cycle tariff tier schedule (matches `SCHEDULE` wave-for-wave) · the
Box rework · all 10 Artefact texts from the sweep · the Shop-visit retirement.

## Blocked by

- item 5 wants issue 57 to land first, and real `agent-browser` access for the full table

## Outcome — items 1, 2, 4 and 6 fixed 2026-08-30

All in Notion; no code involved. Each used the `> Reconciled <date>` convention rather than
silently overwriting history.

- **#2 (highest impact, done first)** — [Pieces & Movement] and [Game Flow — Player Turn] now
  state the single `ACTIONS_PER_TURN` = 2 pool up front, and their Move/Place/Merge
  subsections say "costs 1 action from the shared pool" instead of claiming independent
  basic-count-plus-bonuses pools. Both copy **Difficulty Ranks**' existing phrasing, so the
  document now agrees with itself rather than having two right answers in different words.
- **#1** — a one-line pause pointer added to Overview, King Tariffs, Wave Catalog and Score,
  each aimed at Fable Prototype Test's addendum. No rules or numbers otherwise touched: the
  Tariff design is paused, not challenged.
- **#4** — Clock's "TBD — e.g., 30 min" corrected to "5 minutes (`CLOCK_START_MS`)", noting
  its other three refill numbers already matched code.
- **#6** — King Tariffs' Mild count 8 -> 7 and 262,144 -> 117,649.

**A compounding error the audit had not spotted, caught during the fix:** King Tariffs'
downstream *"~211 billion total sequences"* is computed from the same wrong Mild count
(8^6 x 8^5-perm x 5^4-perm). Recalculated to **~94.9 billion**. Worth noting because it is the
shape of error a spot-check misses — the headline number was wrong, and so was everything
derived from it two paragraphs later.

Also fixed mid-edit: a Notion serialisation quirk where bold wrapping a code span
(`**\`ACTIONS_PER_TURN\`** = 2**`) round-tripped as literal `****`. Reworded so the code span
sits outside the bold, verified by re-fetching.

### Still open

- ~~**#3**~~ — **DONE.** Issue 59 reconciled Enemy AI Behaviors as "baseline 1, Tier 5 restores
  2", with the fleet numbers attached, and also closed out Difficulty Ranks' own
  "contradiction flagged, not resolved" callout — the same divergence had two ends.

## Outcome — item 5 closed 2026-08-30 (issue 63's pass)

**The Cost numbers were deliberately NOT rewritten. That is the finding, not a deferral.**

The whole 21-row table was enumerated (SQL, before the plan gate hit). The audit's framing —
"~10-20x too high" — turned out to understate the problem in one way and overstate the
fixability in another. There are **three** divergences, and only one of them is a number:

1. **Currency.** Every Cost and every Description in this table is denominated in **Score**
   ("costs an additional Y score", Inflation "-10% score gain", Asset Freeze "-50% score",
   Austerity "double score"). The shipped game charges and reduces **Gold** in every one of
   those cases. This is the systemic divergence the audit did not see, because it spot-checked
   Tariff on Box Pick's Cost cell rather than reading the column.
2. **Shape.** `200 / 500 / 1000` is a three-step ladder. `tuning.gd` has a single flat
   `TARIFF_ACTION_COST := 10` with no ladder at all. **There is no per-row number to correct
   this column to** — any triple written today would be invented, which is exactly the
   "authoritative-looking made-up Gold number" outcome worth avoiding.
3. **Magnitude.** 200 against a shipped 10 is ~**/20**, not the "~/100" that `tariffs.gd`'s
   header had claimed for months (200 → /10 → halved 2026-07-06 → 10).

**Issue 57 did not move the target.** The audit assumed it would. It does not: 57 applies
`Economy.SCORE_MULTIPLIER` at the point of scoring and leaves Gold derived from the raw
unscaled amount (57's own Outcome says so), and Tariffs charge Gold. The Score x10 only
becomes relevant *if* the rework decides Tariffs should charge Score after all.

**Recommendation: this is not worth renumbering before the Tariff rework.** Picking a currency
or inventing a ladder would quietly settle a design question the rework owns, and Tariffs are
switched off (`Tuning.TARIFFS_SCHEDULED := false`) until it lands, so nothing here is live.

What was done instead — the misleading-ness removed without inventing anything:

- **Tariffs Catalog DB description** (renders directly above the table) now states the shipped
  constants `TARIFF_ACTION_COST = 10` / `TARIFF_LR_PER_SQUARE = 5`, all three divergences, why
  the numbers were left alone, and that issue 57 did not move the target.
- **`game/data/tariffs.gd`'s header corrected** — it had been asserting the wrong ratio
  ("~/100") and saying nothing about the currency change. It now records /20, Gold-not-Score,
  and that the reconciliation belongs to the rework.

The 20 Tariff *Description* mismatches the drift checker reports are the same currency
divergence plus deliberate paraphrase; `check-notion-drift.mjs`'s own header already says to
expect them and to act only on Name/Tier mismatches there. Tier mismatches: **zero**.
