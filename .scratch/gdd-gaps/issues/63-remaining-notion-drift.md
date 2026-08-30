# 63 — The 85 remaining Notion drift findings

Status: done (2026-08-30) — 85 findings → 22, and the 22 are all logged-deliberate

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

`tools/check-notion-drift.mjs`, re-run 2026-08-30 against a fresh snapshot (180 Artefacts /
16 Items / 39 Pieces / 21 Tariffs), reports **85 findings**. Its first run on `main` found 59;
the number went *up* because the catalog kept moving while Notion held still.

Slice 50 reported these rather than fixing them — correctly, since most need a judgement call
about which side is stale, and that is exactly what the checker refuses to decide for you.

**Do not treat this as 85 equal items.** They fall into three very different groups.

## Group 1 — stale `(needs: …)` notes, the large majority

Notion still carries `(needs: choice UI)`-style notes on Artefacts whose mechanics have since
been built. Every one of the 180 is now implemented, so **every remaining `(needs: …)` note is
wrong by definition**. Mechanical, low-risk, high-volume — the ideal thing to batch.

## Group 2 — real semantic drift, four rows

These say genuinely different things on each side and need a ruling per row:

- **Mar-a-Lago Toilet Papers** and **Silk Road Coupon** — trigger mismatch. Notion says "Shop
  restock"; the repo implements the 5-Wave Milestone. This one has been known since slice 39's
  first run and has survived several passes.
- **Pegasus Free Trial** — mechanic mismatch. Almost certainly Notion still carrying the
  original *"can move twice each Turn"* text, which the user **replaced** on 2026-08-30 with
  *"the first move or capture each Turn costs no Action"* (issue 54). If so this is Notion
  being behind, not a real disagreement — verify before ruling.
- **Spare Organ Receipt** — check against issue 53's ruling (50% of **both** consumed pieces).

## Group 3 — two genuine gaps, not drift

- **"Tariff on Promotion" exists in Notion with no `tariffs.gd` entry at all.** Not a text
  mismatch — a Tariff the design has and the game does not. Decide whether to build it or
  retire it. Note Tariffs are currently paused (`TARIFFS_SCHEDULED := false`), so this is not
  urgent, but it should be resolved in the Kings + Tariffs pass rather than found again then.
- **`king` exists in Notion Pieces but not in `data/pieces-codex.js`.** Almost certainly
  intentional — that file's header describes a *curated 38-piece* set and the King is the boss
  piece — but the exclusion was never written down, so the checker will keep reporting it every
  run. Log it as a deliberate exclusion and it stops being noise.

## Suggested order

Group 3 first (two decisions, both small), then Group 2 (four rulings), then batch Group 1.
Doing Group 1 first would feel productive and leave every finding that actually matters still
sitting there.

## Note

`items.gd`'s header claim *"STATUS triage synced 2026-07-14: only KEEP items ship"* remains
**unverifiable** — the checker only sees current Notion state, not a July snapshot. Two agents
have now reached the same conclusion independently and correctly left it alone. Either accept
it as unprovable or delete the claim; do not keep re-investigating it.

## Blocked by

- nothing

## Outcome (2026-08-30)

**85 findings → 22.** Artefacts and Items are now **clean (0 findings each)**. All 22 that
remain are the two exclusions this issue asked to have logged, plus the 20 Tariff Description
paraphrases the checker's own header says to expect — see issue 62's Outcome for why those
belong to the Tariff rework.

Done in the order the spec argued for: Group 3, then Group 2, then the Group 1 bulk.

### Group 3 — both logged, neither built

- **Tariff on Promotion** — annotated in Notion with the user's ruling: deliberately
  unimplemented pending the full Tariff rework, *not* an oversight. It also now carries
  `tariffs.gd`'s original MVP reason (last-rank promotion is cut; merges are covered by Tariff
  on Fuse) and a note that the checker will keep reporting it until the rework resolves it.
- **`king`** — the reading held up. `data/pieces-codex.js` has **exactly 38 entries and no
  `king`**, its header does describe a curated 38-piece set, and the King has no promotion
  chain, no fusion and no inverse, so the four pages that file feeds have nothing to render
  for it. Logged in **both** places: the `pieces-codex.js` header (so the next reader of the
  file sees it) and the Notion King row (so the next reader of the GDD does).

### Group 2 — four rulings, all "Notion was stale"

`game/data/artefacts.json` was the truth in all four, and each Notion row now carries a
`Reconciled 2026-08-30 (issue 63)` paragraph rather than a silent overwrite.

- **Mar-a-Lago Toilet Papers** / **Silk Road Coupon** — "On Shop restock" → **"On 5-Wave
  Milestone"**. Verified in `artefact_hooks.gd`, not just taken from the issue: both dispatch
  `on_wave_clear` through `_milestone5_hit`, the per-artefact cadence ruled 2026-08-28
  (issues 26/28) and wired in issue 43 — counted from each artefact's own acquisition wave,
  which is a *different* beat from the global 10-wave `on_clock_refill` hook.
- **Pegasus Free Trial** — confirmed exactly as predicted: Notion still carried the
  pre-redesign *"can move twice each Turn"*. Now the shipped no-Action wording.
- **Spare Organ Receipt** — singular → **both consumed pieces' value combined**, per issue 53.

### Group 1 — the bulk, and it was bigger than this issue thought

The premise ("all 180 are implemented, so every `(needs: …)` note is wrong by definition")
is right, but it applies to **both sides**. `data/artefacts.js` was carrying **22 of the same
stale notes**, and the checker cannot see them: when both sides carry the identical note the
row compares equal and is silently reported as clean.

So stripping only Notion would have *created* 22 fresh findings. Both sides were stripped:

- **Notion: 81 rows updated** — 54 Notion-only notes, 22 that matched the repo's, plus the
  5 Group 2 / PENDING rows below.
- **Repo: 23 effect strings** in `data/artefacts.js`, re-exported to `game/data/artefacts.json`
  via `tools/export-game-artefacts.mjs` (never hand-edited). The 3 surviving `(needs:` hits in
  that file are inside the header comment, where they are history, not live notes.

### Three findings this issue had not anticipated

- **Holy Lint — the one row where the REPO was stale, not Notion.** Issue 27 renamed the effect
  to *"On Capture: **the capturing piece** gets +1 Piece Buff"* (its Notion note documents the
  change and the reason: it was the only ambiguous text in the catalog). Notion got that fix;
  `data/artefacts.js` never did, and still read the bare *"On Capture: +1 Piece Buff"*. Fixed
  repo-side. Text-only — the mechanic already lands after the capture resolves.
- **Bible Gag Reel Scroll** and **Manna Vending Machine** still carried a *"PENDING — decided,
  not yet built (GDD sweep 2026-08-30)"* prefix. Both **are** built (`artefact_hooks.gd`
  `bible-gag-reel-scroll/on_capture`, `manna-vending-machine/on_wave_clear`) and flagged
  `implemented: true`. Same class of stale flag as a `(needs:)` note; cleared, with the
  replacement rationale kept as a trailing paragraph.
- **Three Items rows** drifted and were not in any group. Two were a missing trailing period
  (Counter-Intel, Radar Jamming — the latter also had a curly apostrophe against the repo's
  straight one). **Demote** carried a real grammatical error: *"Convert a target piece (ally or
  enemy) **it's base chain Piece**"* — "it's" for "its", and no "to". Corrected to the shipped
  wording. Items is now clean.

### On `items.gd`'s unverifiable "STATUS triage synced 2026-07-14"

Left alone, as this issue instructed. Not re-investigated.

### Verification

- **Query Data Source hit the workspace plan gate** partway through (the documented failure
  mode). Reads switched to `agent-browser` — page IDs harvested from the virtualized table by
  scrolling and reading `data-block-id`, and the post-edit state read back the same way.
  Writes stayed on the Notion MCP throughout.
- **The 81 Notion writes were verified independently rather than trusted.** Three Sonnet
  workers reported 25/25 each; a fresh browser read of all 180 rows then confirmed **81/81
  match the intended value** and — the check that actually matters — **0 untouched rows
  changed**. The Items and Tariff writes were confirmed by individual `notion-fetch` calls.
- **`game/tests/run_all.sh --headless`: ALL GREEN** (26 suites + autoplay). Headless rather
  than full because the change is display-string only and the windowed probes need an
  uncontended machine — other agents are active in this session, and a contended probe failure
  would be noise. `effect` is read in exactly one place (`items.gd:151`, to build a display
  `description`) and no test asserts on the text, checked before editing.
