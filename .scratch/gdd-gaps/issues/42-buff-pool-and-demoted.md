# 42 — Full buff pool, and "Demoted"

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## Ruling 1 — random buff grants draw from the FULL pool

Issue 28 asked whether random grants should be tier-restricted. **They should not** — keep
the full pool.

Note this does not undo issue 27: `slow` stays excluded from random grants because it is
self-harming, which is a different axis from tier. Full pool means *all tiers*, not *all
buffs including the debuff*.

The user also asked to **consider upgrading the three Tactical-restricted granters to the
full pool**:

- **MK-Ultra Sugar Cube** — "On Deploy: the deployed piece gets +1 Tactical Piece Buff"
- **Obedience-Flavored Tap Water** — "On your first Capture each Wave: … +1 Tactical Piece Buff"
- **Sleeper Agent Pillow** — "On buying a Piece in the Shop: it arrives with a random Tactical Piece Buff"

⚠️ Their catalog text explicitly says **Tactical**, so this is a **Notion text change as well
as a code change** — do not silently widen the pool and leave the text lying. Note the tier
words are load-bearing for balance: a Decisive buff (Bomb, Trap, Reflect) from a Common
artefact is a much bigger swing than a Tactical one. Flag that in the Outcome; the user said
"consider", not "do".

## Ruling 2 — "Demoted" means below its PEAK rank

Blocks **Dark Market Light Bulb**: *"Ranked pieces give double Gold on Capture; Demoted
pieces give no Score on Capture."*

`ArtefactHooks._ranked()` already defines Ranked. **Demoted = currently sitting below its
historical peak rank**, so the label **clears** if the piece climbs back — option (b), chosen
over "was ever demoted".

That needs a per-piece **peak-rank stamp**: recorded when a piece ranks up, compared against
its current rank. It rides on the piece Dictionary per ADR-0002 and must round-trip through
`save_config.gd` like the capture ledger does.

## Acceptance criteria

- [x] Random grants draw from all tiers; `slow` still excluded as self-harming
- [x] The three Tactical granters widened AND their Notion text updated, or left alone with a
      recorded reason — not silently mismatched (left alone, reason recorded — see Outcome)
- [x] Per-piece peak-rank stamp, persisted, clearing correctly on re-promotion
- [x] Dark Market Light Bulb implemented
- [x] `run_all.sh` all green

## Blocked by

- nothing

## Outcome (2026-08-29)

**Ruling 1 — already true in code, clarified in comments.** `_random_buff_key`'s
`tier == ""` default (every REGISTRY caller but 3) already draws from the full pool
across all tiers; `self_harming` exclusion (Slow, issue 27) is the separate axis it
already was. Reworded the function's own header so the two rules read as a
deliberate design, not an accident, and added a one-line note at each of the 3
Tactical-restricted call sites explaining why they weren't widened (below).

**Considered widening MK-Ultra Sugar Cube / Obedience-Flavored Tap Water / Sleeper
Agent Pillow to the full pool — declined, code unchanged.** All 3 are Common
(x2)/Uncommon rarity on the catalog's highest-frequency Piece Buff triggers (every
Deploy, once per Wave, every Shop piece-buy). A Decisive buff (Bomb/Trap/Reflect)
landing that often off a Common artefact is a materially bigger power swing than a
Tactical one — the exact asymmetry the user flagged when asking to weigh this.
Recommendation: leave Tactical-only. **No pool was widened, so no Notion text needs
editing** — their catalog text ("Tactical Piece Buff") still matches the code.

**Ruling 2 — shipped.** Added a `peak_ranked` stamp to the piece Dictionary
(ADR-0002), written once in `ArtefactHooks.run()`'s `on_rank_up` branch — the single
choke point merge_logic.gd `commit_merge`, game.gd's "promote" Item, and this file's
own `mrna-firmware-update`/`alien-rocket-toy` in-place promotions already dispatch
through, so no new call sites. `_demoted()` sits next to `_ranked()`: `peak_ranked`
set but currently unranked. Since nothing ever clears the stamp, a later rank-up
puts the piece back at "currently ranked", which makes the comparison itself flip
false — "clears on re-promotion" (option b) falls out for free, no separate reset
step. Rides the piece Dictionary exactly like the per-piece capture ledger (issue
25) already does, so it round-trips through `save_config.gd`/Extraction with zero
new save code (verified, not assumed — `to_config()`/`apply()` already generically
duplicate/merge whatever extra fields a board-piece Dictionary carries).

One accepted gap, documented at the `run()` stamp site rather than silently
papered over: a same-id merge that lands in **Stock** (not the board) appends a
bare id `String`, not a Dictionary (`merge_logic.gd`, ADR-0002's "merging discards
input state") — nothing to stamp `peak_ranked` onto until some other handler (Holy
Grail Coaster's own branch) converts it. Identical limitation the capture
ledger/buffs already accept for that same path; not a new hole this issue opened.

Implemented **Dark Market Light Bulb**. Gold half mirrors CIA Heart Attack Gun's
existing "+100% Gold" idiom (`g.gold += roundi(ctx.base)`, id-only `_ranked` check,
no board lookup needed). Score half needed a new `no_score` ctx OUTPUT flag on
`on_capture` (economy.gd's `capture_score`), applied exactly once after every
handler has dispatched — a direct `ctx.pts = 0` inside the handler would have made
the result depend on `run()`'s alphabetical key-sort relative to any other
`+=`-style on_capture handler, exactly the order-dependence the file's ctx contract
(header) exists to rule out.

Test coverage (`test_items.gd`, "Dark Market Light Bulb"): a real merge → `_demoted`
false; a real "demote" Item use → stamp survives the id drop, `_demoted` true, a
capture pays 0 Score and no Gold bonus; a real "promote" Item use back past the old
peak → `_demoted` false again, a capture pays double Gold and full Score. Plus a
never-Ranked control piece, unaffected either way. `data/scenarios.gd` gained
"Artefacts: slice 42 (peak-rank stamp — Dark Market Light Bulb)" for manual/swept
sandbox coverage of the same 3 states. `run_all.sh`: ALL GREEN.

PR: https://github.com/SharpMox/NO-KINGS/pull/155
