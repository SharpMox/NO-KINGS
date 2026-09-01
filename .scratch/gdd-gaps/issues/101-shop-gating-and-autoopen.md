# 101 — Shop gated to wave 5+, and auto-opens on restock

Status: done (2026-09-02) — gate the PANEL, closed before Wave 5; button kept, disabled

## Parent

`.scratch/gdd-gaps/PRD.md`

## Two halves, very different risk

### (a) Auto-open on restock — additive, low risk

`SHOP_RESTOCK_WAVES` is **5** (`tuning.gd:181`), and `wave_logic.gd:51` already fires Lane A's
guaranteed restock every 5th wave. Opening the panel automatically at that moment is a small,
well-defined change on an event that already exists.

Care needed: the Shop must not auto-open **over** another modal. `_open_shop` already refuses
while `box_open`/`buff_pick_open`/`preview_open`/`win_open` (one modal at a time), and a wave
clear can produce a Box pick. So auto-open has to queue behind those rather than be dropped —
otherwise the restock wave silently doesn't open, which is worse than never auto-opening.

Also: **Kim Jong Un's Juche Power closes the Shop entirely** (`game.gd:3492`). Auto-open must
respect it, or the King's Power announces itself by opening the thing it forbids.

### (b) Gate to wave 5+ — contradicts a documented decision

`game.gd:3487-3490`, verbatim:

> *Shop entry: player's turn only, never over another modal.*
> ***Always openable, in any state — the GDD makes the Shop the one surface the player can
> reach at will.*** *Buying is still turn-gated (`Shop.can_buy`), so outside your turn it is a
> readable catalog with dead Buy buttons.*

"Always openable" is a deliberate, GDD-sourced property, and the Shop is *already* the one
place a player can look things up mid-run — descriptions, prices, what exists. Gating it to
wave 5 removes the **catalog** as well as the **purchasing**, which is probably not the
intent.

**RULED (user, 2026-09-01): gate the panel.** The Shop is **closed until the end of wave 5**,
then opens — and auto-opens at that moment. This deliberately reverses the "always openable"
property, so the code comment at `game.gd:3487` must be **rewritten, not left contradicting
the behaviour** (a stale comment asserting the opposite of the code is how the next reader
gets misled).

Consequences to handle rather than discover:

- **The Shop button stays, disabled** (user ruling, 2026-09-01) — not hidden. A button that
  is present but greyed reads as "not yet", where a missing button reads as "this game has no
  Shop". It must carry **why**: the unlock wave on the button or beside it, since a disabled
  control with no reason is the failure mode this ruling is one step away from.
- **First open is end of wave 5, which is also the first Lane A restock** (`SHOP_RESTOCK_WAVES`
  = 5). The gate and the first restock coincide by construction — good, but it means the
  auto-open and the unlock are the *same event* the first time, and the code should not fire
  two overlapping opens.
- **Losing the catalog before wave 5** is the real cost of this ruling: the Shop is currently
  where a player reads what Items and Artefacts do. Nothing else in the game surfaces those
  descriptions. Worth deciding whether the pre-wave-5 opening needs a read-only reference
  somewhere, or whether the first five waves are simply meant to be played blind.

## Acceptance

- The Shop cannot be opened before the end of wave 5. **The button remains visible and
  disabled**, and states the unlock wave rather than just being dead.
- It **auto-opens** at the end of wave 5 and on each Lane A restock wave, queued behind any
  modal already open (never dropped), and never under Kim Jong Un's Juche.
- `game.gd:3487`'s "always openable" comment is rewritten to match the new rule.
- Scenario boards at wave 4 and wave 5 showing the boundary.
- Click probes extended; `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

Nothing.

## Outcome (2026-09-02)

`Tuning.SHOP_UNLOCK_WAVE = 5`, deliberately equal to `SHOP_RESTOCK_WAVES` so the unlock lands
on the first Lane A restock — the first Shop a player sees is a freshly stocked one, and the
unlock and the auto-open are one event rather than two.

- **`_open_shop` refuses below the unlock Wave** and says *when* ("The Shop opens on Wave 5"),
  never a silent no-op. The old "always openable, in any state — the GDD makes the Shop the
  one surface the player can reach at will" comment was **rewritten**, not left contradicting
  the code.
- **The button stays and is disabled**, reading `Shop (W5)` with a matching tooltip.
- **Auto-open** is queued as `pending_shop_open` and drained at the player-turn-start seam
  that `pending_reinforce` already uses — the restock happens mid-transition where a Box pick
  may already hold a modal, and `_open_shop` refuses over one, so opening inline would
  silently skip the very Wave the auto-open exists for. It survives a save round-trip
  (additive field, defaults false) and never fires under autoplay, which has no way to close
  a panel.

### The gate is on the panel only, and that was a correction mid-slice

The first cut also gated `Shop.can_buy`, for bot fidelity — and **broke seven suites**, which
drive `can_buy` directly at low Waves to test Shop mechanics that have nothing to do with the
unlock. That gate was an addition of mine, not the ruling. Reverted: a player can only reach a
purchase through the panel, so gating the panel is behaviourally complete for them.

**The fidelity concern is real and is now recorded where it belongs**: autoplay buys through
`Shop.buy` without opening the panel (issue 103's `try_shop`), so once 103 merges, `try_shop`
must carry the Wave check itself. Without it the bot shops from Wave 1 while a player cannot,
and 103's measurements stop describing the real game. Noted in `shop.gd`'s own header.

### Test surface

Four probe boots reached the Shop button and booted below the unlock Wave — including one via
the `_buy_a_box` helper, which the first fix missed entirely because the failure surfaced 600
lines from its cause. Found by mapping every Shop-reaching call back to its nearest boot
rather than by bumping every `"wave": 3` in the file, which would have hidden real breakage.

Both halves of the ruling are asserted: `test_shop.gd` covers refusal at Wave 4 and opening at
Wave 5; `test_game_clicks.gd` covers the button being live post-unlock and **disabled, labelled
and unclickable** before it.

`run_all.sh` ALL GREEN, foreground, alone.

### Left open, deliberately

The cost named when the ruling was made stands: the Shop is the only surface showing Item and
Artefact descriptions, so Waves 1-4 are now played without a reference. No replacement was
built — that is a design call, not an oversight.
