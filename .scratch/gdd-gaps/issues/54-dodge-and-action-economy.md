# 54 — Dodge, dormant Tariff pair, and two action-economy rules

Status: done (2026-08-30)

## Parent

`.scratch/gdd-gaps/PRD.md`

## 1. Dodge — 2 Artefacts, and no turn suspension needed

Both intercept "a piece would be captured". Issue 33's decision #2 worried this needs a
modal mid-enemy-turn. **The user's rulings remove that need entirely** — both resolve
automatically, so nothing in the game requires suspending an enemy turn.

### UAP Breath Mint — Legendary

> Once per Wave: when one of your pieces would be captured, it instead moves 1 square away

**Auto-selects its landing square. If no tile is available, the effect does nothing** and
the capture proceeds (user ruling). No player choice, so no modal.

Prefer an empty square away from the attacker. Multicapture's auto-pick of its victim is the
precedent for "the trigger resolves itself rather than adding a targeting step".

### Inflatable Vietcong Torpedo — Uncommon

> Once per Wave, when one of your pieces would be captured: pay 15 Gold and it survives

**Auto-pays when you can afford it** (user ruling). No prompt. If you have under 15 Gold, it
does not fire and the capture proceeds.

Both hook the existing repel concept — `BuffLogic.repels_capture` already expresses "this
capture attempt does not happen" for Shield and Reflect. Extend that path rather than
inventing a second interception point.

**Consequence worth stating:** with these two auto-resolving, **issue 33's decision #2 has
no remaining consumer.** Nothing in the catalog needs a mid-capture player choice.

---

## 2. The Tariff pair — build dormant

Both depend on Tariffs, which the user removed from runs on 2026-08-29
(`TARIFFS_SCHEDULED := false`) pending the King-mechanics pass. **Ruling: build them anyway,
dormant** — wired and correct, simply never triggered until Tariffs return.

- **Exhibit 399** (Legendary) — *"When a Tariff would be applied: you choose between 2
  options"*
- **SETI's Red Marker** (Rare) — *"On acquiring this Artefact: one random active Tariff is
  inverted into its equivalent bonus"*

Because they cannot fire in a real run, **their tests are the only proof they work.** Drive
the Tariff paths directly in the suite rather than relying on any in-game path. Say plainly
in the Outcome that neither has been exercised in a live run.

Exhibit 399 does need a genuine 2-way choice — that is `_open_choice_pick` (slice 41), fired
from the Tariff-apply path.

---

## 3. Two action-economy rules

### Hellfire Club Discord Invite — Legendary

> +2 Actions per Turn, but you cannot Pass while Actions remain

**Verified 2026-08-29:** `_on_pass` has **no** `actions_left` check today — passing with
Actions remaining is currently allowed. So this Artefact genuinely removes a control the
player has, which the user confirmed they want.

Gate `_on_pass` while it is held and `actions_left > 0`. Two things to get right or it
becomes a softlock:

- The Pass button must show *why* it is disabled, not just fail.
- **There must always be a legal Action available.** If the player has Actions left but no
  legal move, deploy or item use, they must still be able to end the Turn — otherwise the
  run is stuck. Find that case and handle it explicitly.

### Pegasus Free Trial — Legendary, REWORKED

Original text: *"Pieces at the end of their Rank chain can move twice each Turn."* That
redefines `moved_this_turn`, which **Blitz now depends on**, and issue 33 parked it for
exactly that reason.

**The user reworked it (2026-08-29):** the first move or capture each Turn by an
end-of-chain piece **costs no Action**. Same power, and it reuses the free-move mechanism the
Blitz rework already built instead of touching `moved_this_turn` at all. Decision #3 in
issue 33 is resolved by making it moot.

**Re-text** to something like: *"The first move or capture each Turn by a piece at the end
of its Rank chain costs no Action."*

**One reading to confirm while implementing:** this is per *piece* — each end-of-chain piece
gets its own free first move/capture each Turn — not one free action shared across them all.
That matches the original "can move twice each Turn", which was per piece. If that turns out
too strong in play it is a tuning change, not a rework.

"End of its Rank chain" is the inverse of `Shop.base_piece_pool` (which keeps pieces nothing
promotes *into*); here you want pieces with no `next`.

## Acceptance

- All 6 `implemented: true`, Pegasus and Jet-Fuel-style texts corrected, exported via
  `node tools/export-game-artefacts.mjs`.
- UAP: assert the no-available-tile case does nothing and the capture proceeds.
- Torpedo: assert it does **not** fire under 15 Gold, and that Gold is actually deducted.
- Both dodges: assert once-per-Wave, and that the Wave boundary re-arms them.
- Hellfire: assert Pass is blocked with Actions remaining, **and** that a no-legal-action
  state can still end the Turn.
- Pegasus: assert the first move/capture is free per piece and the second is not.
- Tariff pair: driven directly in tests; Outcome states they are unexercised in live runs.
- Tests in the split suites, seeds pinned. `run_all.sh` ALL GREEN, foreground.

## Blocked by

- nothing

## Outcome

5 of the 6 artefacts shipped `implemented: true`; SETI's Red Marker stays `implemented:
false` (reason below). `node tools/export-game-artefacts.mjs` re-run.

**UAP Breath Mint / Inflatable Vietcong Torpedo** both extend the EXISTING repel guard in
`game.gd`'s `_run_enemy_actions` — the same "this capture attempt does not happen" shape
`BuffLogic.repels_capture` and Cheyenne Mountain Doorbell already use — rather than a second
interception point, exactly as the spec asked. Both are standing-rule reads there
(`_held(...)`), each still carrying a REGISTRY entry purely for its own `on_wave_clear`
reset (`g.uap_used_this_wave` / `g.torpedo_used_this_wave`, the same once-per-Wave idiom as
Hoffa's Cement Shoes, not scaled by held copies). UAP auto-picks the empty neighbour farthest
from the attacker (`_uap_dodge_target`, same "resolves itself" precedent as multicapture's
auto-picked victim); with none free it is a genuine no-op and the capture proceeds. Torpedo
auto-pays 15 Gold only when affordable; under 15 it doesn't fire. When both are held, UAP
(free) is tried before Torpedo (costs Gold) — an emergent combo call, not a GDD ruling, but
the lower-cost option winning ties is the least surprising default. Covered in
`test_items_artefacts_4.gd`: control (no artefact → captured normally), the dodge/pay
happening, once-per-Wave + Wave-boundary re-arm, the no-free-tile no-op, and the UAP-before-
Torpedo combo.

**Hellfire Club Discord Invite** (+2 Actions/Turn, `on_turn_start`) gates `game.gd`'s
`_on_pass` with a new `_pass_blocked()` check. Because `_on_pass` genuinely had no
`actions_left` check before this, the new restriction is paired with `_has_legal_action()`
(legal moves, Deploys, Item uses) as an explicit escape hatch — the block only applies when a
legal Action actually exists, so a fully boxed-in board can never be stuck. Two things
mattered here that weren't obvious going in:
- **`Rules.legal_moves` knows nothing about `moved_this_turn`.** That "one move per piece per
  Turn" lock is enforced only at the tile-click gate, not inside the engine's own move
  legality — so a naive "does a legal move exist" check would call a piece that already moved
  this Turn a legal action and wrongly keep Pass blocked. `_has_legal_action()` filters
  `Rules.legal_moves`'s results through `moved_this_turn`, the same filter `autoplay.gd`'s own
  `step()` already applies for the identical reason. Caught by writing a regression test for
  exactly this case before trusting the helper.
- **Item usability needed a real 2-stage check for "pair" targets** (Tactical Reposition,
  Rapid Deployment, Decoy Swap) — a non-empty stage-A doesn't guarantee any stage-A pick has a
  valid stage-B, so `_has_usable_item()` walks stage A's candidates and checks stage B for
  each. `target == ""` items (Counter-Intel, Surprise Attack) are always usable; tile/area/
  multi items only need one valid anchor.
The Pass button (`hud.gd`) shows *why* it's disabled while blocked: greyed out, relabeled
"MUST ACT", and a tooltip naming the artefact — not a silent failed click.

**Pegasus Free Trial — reworked by the user** away from "move twice each Turn" (which would
have redefined `moved_this_turn`, the field Blitz depends on) to "the first move/capture each
Turn by an end-of-chain piece costs no Action." Implemented as an ordinary `on_turn_start`
REGISTRY handler that grants Blitz's own `blitz_free_move` flag to every player piece with no
`next` (excluding the King, same convention every other per-piece item effect uses) — the
exact free-move mechanism the Blitz rework already built, never touching `moved_this_turn`.
One reordering was needed in `_begin_player_turn`: the per-turn `blitz_free_move` cleanup
loop now runs BEFORE `ArtefactHooks.run(self, "on_turn_start")` instead of after, so Pegasus's
grant survives it (previously the cleanup ran second and would have erased the same-turn
grant immediately). Boolean grant, not additive — 2 held copies still grant exactly one free
move per eligible piece, same non-stacking precedent as Y2K Patch Floppy Disk. Per piece:
tested with two separate end-of-chain pieces (two Queens), each spending its own free
move/capture independently.

**Exhibit 399** is wired but genuinely dormant — `Tuning.TARIFFS_SCHEDULED` is `false`
(2026-08-29 ruling), so Tariffs never activate in a live run; this can only be exercised by
calling `economy.gd`'s `apply_tariff` / `activate_tariff_by_key` directly, which
`test_items_tariffs.gd` now does. **It has not been exercised in a live run.** Its
`on_tariff_apply` handler sets a new `ctx.choice` output flag (mirrors `ctx.cancel`'s shape).
`apply_tariff` was split: the actual effect moved into a new `resolve_tariff`, and when
`ctx.choice` is set, `apply_tariff` defers to `game.gd`'s new `_open_exhibit_choice`, which
reframes "you choose between 2 options" as the existing tariff-cancel mechanism (Salvation
Gift Card's own veto) — "Let it apply" vs "Block it" — handed to the player as a real choice
through the issue-41 choice-pick seam instead of firing automatically and with no recharge
limit. This was a design call, not a GDD-specified pair of options (the catalog text never
enumerates what the 2 options are); it was chosen because it reuses an existing mechanic with
no new numeric content, unlike the alternative of inventing tariff-specific option pairs.
`ctx.cancel` is still checked first, so Salvation's automatic veto wins outright if both are
somehow held. Tested: control (applies immediately, no modal), "Let it apply" resolves
normally, "Block it" never lands, and a same-hook reward artefact (Merchants of Death Sample
Case) still pays out immediately regardless of the pending pick.

**SETI's Red Marker stays `implemented: false`.** "One random active Tariff is inverted into
its equivalent bonus" needs a per-Tariff "what's this one's opposite" table that doesn't
exist in `data/tariffs.gd` — most Tariffs (Sanctions, Regulation, Trade War, Filibuster, the
6 flat action-cost surcharges) have no numeric "bonus" to invert to, only a behavioural
penalty. This is the exact gap issue 22 already flagged and declined to guess at
("Guessing one in code would be exactly the kind of guess this issue's acceptance criteria
rules out"); issue 54 didn't supply a table either, and inventing one now would be new design
content, not wiring. Left `implemented: false` per this repo's own rule: ambiguity goes back
to Notion as a question, not into code as a guess.

Non-regression suite: `game/tests/run_all.sh`, foreground, full run (windowed click probes +
27 headless suites + full autoplay). Final line: `ALL GREEN`.
