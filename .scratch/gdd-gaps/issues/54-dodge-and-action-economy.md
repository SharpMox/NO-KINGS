# 54 — Dodge, dormant Tariff pair, and two action-economy rules

Status: todo — SPECCED (user rulings 2026-08-29)

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
