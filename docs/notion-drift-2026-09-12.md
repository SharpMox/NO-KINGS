# Notion drift check — 2026-09-12

> **RULINGS, same day.** Max settled two of the three findings below. Recorded here and in
> **NO-70**, which is the durable home — this file is a dated snapshot of one run and will
> be superseded by the next one.
>
> - **Finding 2, Filibuster — CLOSED, NO CHANGE.** The generic `ctx.actions += 1` at
>   `artefact_hooks.gd:1956` is correct and Notion's "+1 move action per turn" stands as
>   wording. Notion was deliberately NOT edited. A future drift run will report this line
>   again; it is settled, not open.
> - **Finding 3, Tariff on Fuse — RESOLVED BY UPDATING NOTION.** The code is correct: the
>   charge applies to any merge, Rank Up included. Notion's Description was changed from
>   "Performing a Fuse (merge of captured pieces) costs an additional Y score to perform."
>   to "Performing a Fuse (any merge, including a same-piece Rank Up) costs an additional Y
>   score to perform." Verified by re-reading all 19 rows and diffing: exactly one cell
>   changed, nothing adjacent moved. The row still reports as a mismatch, because the repo
>   says *gold* where Notion says *score* — but that is now only the documented currency
>   divergence below, not a scope disagreement.
> - **Finding 1, Regulation — STILL OPEN.** Max's call, not yet made.

First run since `collect-cells.js` was fixed (2026-09-09). Before that fix a
horizontally-scrolled grid returned rows with empty Name / Codex ID / Betza under a
summary line indistinguishable from a good read, which manufactured 11 phantom Artefact
findings. **Both completeness checks held on all four reads this time**, so what is below
has a real claim to being drift rather than viewport:

| catalog | rows collected | expected | columns | width distribution |
|---|---|---|---|---|
| Artefacts | 180 | 180 | 8 | `{"8":180}` |
| Items | 16 | 16 | 5 | `{"5":16}` |
| Pieces | 39 | 39 | 22 | `{"22":39}` |
| Tariffs | 19 | 19 | 5 | `{"5":19}` |

Read-only in Notion throughout: no page, property or row was touched.

## Counts

| catalog | findings | of which actionable |
|---|---|---|
| Artefacts | 0 | 0 |
| Items | 0 | 0 |
| Pieces | 1 | 0 (known and expected) |
| Tariffs | 19 (all Description; 0 Name, 0 Tier) | 2, possibly 3 |

**20 findings, 2–3 of them real.** Artefacts and Items are genuinely clean — 180 and 16
rows compared on Rarity, STATUS and effect/description text with nothing to report.

## Pieces — not drift

```
  [pieces] "king" — in Notion only (no matching repo row)
```

Expected. `data/pieces-codex.js` is the 38 curated codex pieces by design (CLAUDE.md);
the King is a game piece, not a codex entry. notion-web's SKILL.md already records that a
clean run shows "only the expected King row on Pieces". Neither side is stale.

## Tariffs — 19 Description mismatches, 0 Name, 0 Tier

`check-notion-drift.mjs`'s own header predicts "a wall of mismatches" here and says the
ones worth acting on are Name and Tier. There are none of those. Of the 19:

**11 are the documented currency divergence — NEITHER SIDE IS STALE.** Notion denominates
these in SCORE, `game/data/king_abilities.gd` charges GOLD. That file's header records it
explicitly (corrected 2026-08-30, issue 62): the upstream Cost column "is design intent,
not shipped values", diverges on currency, on the ladder (200/500/1000 vs one flat
constant) and on ratio (~/20), and is **"Not reconciled on purpose: picking a currency or
a ladder belongs to the coming Tariff rework"**. Tariffs are switched off —
`Tuning.KING_ABILITIES_SCHEDULED` is false. Affected rows: Asset Freeze, Austerity,
Inflation, and the seven `Tariff on …` action costs.

**6 are pure wording, and the implementation agrees with Notion.** Checked rather than
assumed:

- *Sanctions* — Notion's "(random, fixed at trigger time)" is exactly what
  `economy.gd:379` does (`# fix the barred type at trigger time`).
- *Hostile Takeover* — Notion's "in place" holds: `economy.gd:367` flips `owner` on the
  piece's own square.
- *Asset Freeze* — Notion's "rounded down" holds: `g.gold /= 2` is integer division.
- *Asset Seizure*, *Trade War*, *Forced Audit*, *Recession*, *Diplomatic Visit* —
  same effect, shorter sentence.

### Finding 1 — Regulation is implemented to half its Notion definition

```
  [tariffs] "Regulation" Description: Notion="Pawns can no longer be merged or promoted." repo="Pawns can no longer be merged."
```

Not a paraphrase. `artefact_hooks.gd:1949` blocks `on_merge_check` when either side is a
pawn, and **there is no promotion gate anywhere** — no `on_promote` hook exists. Promotion
ships by two routes, neither gated: the ▲ badge (`hud.gd:1137`) and the `"promote"` Item
(`game.gd:2667`).

**Which side is stale: cannot tell — this is a design call.** Notion is the design source
of truth, which points to the repo missing half the effect. But Tariffs are dormant
pending the rework, so it may have been scoped out deliberately and simply not written
down. Nothing in `.scratch/gdd-gaps/NOTION-QUESTIONS.md` rules on it.

### Finding 2 — Filibuster's extra action may not be move-restricted

```
  [tariffs] "Filibuster" Description: Notion="Enemy AI gains +1 move action per turn for the rest of the run." repo="The enemy gains +1 action per turn."
```

`artefact_hooks.gd:1956` does `ctx.actions += 1`, a generic action. Whether Notion's
"move action" means "an action, which for the AI is a move" or "an action restricted to
moving" is unresolved. Low stakes, but it is a behavioural question and not wording.

### Finding 3 (lower confidence) — Tariff on Fuse is charged on every merge

```
  [tariffs] "Tariff on Fuse" Description: Notion="Performing a Fuse (merge of captured pieces) costs an additional Y score to perform." repo="Each merge costs extra gold."
```

`Economy.charge(g, "fuse_cost")` sits in `merge_logic.gd:150`, inside `commit_merge`,
which runs for a **Rank Up (same-id) as well as a Fusion** of two different pieces. Notion
scopes the tariff to "merge of captured pieces". This may be nothing — the GDD may use
"Fuse" loosely for any merge — which is why it is flagged rather than asserted.

## What this run does not cover

The checker compares Artefacts on Rarity, STATUS and effect text; Items and Tariffs on
Tier and Description; Pieces on Name, Betza and Letter. Columns it does not read
(Artefacts' Conspiracy/Bonus/Type, Pieces' 19 other columns) could be drifting unobserved.
That is pre-existing scope, not a regression, and is noted here so the next reader does
not mistake a clean report for a full comparison.
