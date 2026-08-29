# 48 — Bounty, a new Piece Buff

Status: done (2026-08-29)

## Parent

`.scratch/gdd-gaps/PRD.md`

## What it is

A new entry in `PIECE_BUFFS` (`game/data/items.gd`) — the 13th.

> **Bounty** — Decisive, dormant. When a piece carrying this Buff is captured — whether
> you capture an enemy carrying it, or lose an ally carrying it — choose 1 of 3 random
> Boxes, then open it.

Designed by the user (2026-08-29) as the replacement for the box-carrier enemy that issue
47 deletes. The loot-on-capture moment survives, but it becomes **player-directed**: you
decide which piece carries it and therefore when the Box arrives.

## Why it is symmetric

It pays out on *either* side of a capture, which is unusual and deliberate:

- Applied to an **enemy** — you get a Box for killing it. A reward for aggression.
- Applied to **your own** piece — you get a Box when you lose it. Insurance.

Both are upside for the player, which is what makes it worth a Decisive slot and worth
aiming. The Buff Box item already allows targeting "a target piece (ally or enemy)", so
no new targeting work is needed.

## Details ruled

- **Tier: Decisive** (user call), alongside Bomb, Trap and Reflect.
- **Model: dormant** — it waits for its trigger with no expiry, then resolves and is
  consumed. Same as Shield, Critical, Trap.
- **The reward is a two-step choice**: pick 1 of 3 random Boxes (out of the 9 from issue
  47), *then* that Box opens normally with its own picks. The first step is exactly what
  `game.gd._open_choice_pick` (slice 41) was built for; the second is the existing Box
  flow.
- Per issue 47, all three offered Boxes roll their contents when offered, so All-Seeing
  Eye Contact Lens (issue 49) reveals what is inside all three before you choose.

## The name collides with a legacy Artefact

There is already a core Artefact keyed `bounty` — *"+30 score when capturing a piece worth
50+"* — one of the seven game-native effects in `ARTEFACT_EFFECTS_CORE` that pre-date the
catalog and have **no Notion equivalent**.

The user's ruling: **the Buff takes the name.** The legacy Artefact is renamed as part of
issue 50's cleanup. Since that Artefact's key is load-bearing (saves, `data/scenarios.gd`
and the Shop match on it directly), the rename is issue 50's problem, not this one — but
**this slice must not reuse the key `bounty`** while the Artefact still holds it. Pick a
distinct buff key and note the intent to reconcile.

## Watch out

- `_random_buff_key` (`artefact_hooks.gd`) is the pool for *random* grants. Bounty is pure
  upside on either target, so it is safe to include — it needs no `self_harming` flag.
  Confirm it is reachable there deliberately rather than by accident.
- The trigger fires inside a capture, and `game.gd`'s `_move_player` capture block has a
  delicate order (`Economy.capture_score` runs before `critical`/`range` consumption).
- Autoplay must resolve both the 1-of-3 choice and the Box itself without a modal, or the
  bot leg hangs instead of failing.

### The two halves resolve differently — checked 2026-08-29, and this is NOT blocked

**Enemy half (you capture an enemy carrying Bounty)** happens during *your* turn, so the
Box can open immediately. This path is already proven: the box-carrier code issue 47
deletes did exactly this (`game.gd:1427`, `if boxed: return _open_box_pick()`).

**Ally half (you lose a piece carrying Bounty)** runs through `_lose_player_piece`, the
synchronous choke point called from five sites including the enemy-move loop.
`ArtefactHooks.run` does not await — handlers set `ctx` fields and the loop continues
immediately — so a handler **cannot** open a modal and wait for a choice there.

**Resolve it by deferring, not by suspending:** the ally half queues the reward
(`pending_bounty_boxes += 1` or similar) and the 1-of-3 choice opens at the **start of your
next turn**, when a modal is safe.

An earlier revision of this issue named `pass_after_box` as the precedent for deferring a
Box step across a turn boundary. **That flag no longer exists** — slice 47 removed it along
with the box-carrier enemy that was its only producer. So this slice builds the deferral
queue itself rather than following an existing pattern. It is still only a counter plus a
check at turn start; the point is not to go looking for a precedent that was deleted.

**Why deferring is legitimate here and not for Inflatable Vietcong Torpedo:** the Torpedo's
choice *changes the outcome of the capture itself* (pay 15 Gold and the piece survives), so
it genuinely needs the turn suspended mid-resolution — which is why it stays parked on
issue 33's decision #2. Bounty's Box is a **payout**; it changes nothing about the capture,
so moving it a few seconds later costs the player nothing. **This slice therefore does not
depend on issue 33's decision #2.**

## Acceptance

- Bounty in `PIECE_BUFFS` with tier Decisive, model dormant.
- Fires on both halves: capturing an enemy that carries it, and losing an ally that
  carries it.
- Offers 3 distinct Boxes; the chosen one opens with its correct choices/picks.
- Consumed exactly once — never pays twice, never survives its trigger.
- Autoplay covered; no hang.
- Tests in the split suites, seeds pinned. `run_all.sh` ALL GREEN, click probes included.
- Add it to the Notion Piece Buffs DB — this one is designed here first, so Notion needs
  to learn about it rather than the other way round.

## Blocked by

- issue 47 (the 9 Boxes must exist to pick 3 of them)
- **not** issue 33's decision #2 — see the two-halves note above; deferring the ally-side
  reward to the start of your next turn sidesteps the suspension problem entirely

## Outcome

Shipped in PR #179. Piece Buffs 12 -> 13.

- **Key is `piece_bounty`**, not `bounty` — the legacy core Artefact still holds that key.
  The Buff takes the *name* per the user's ruling; reconciling the two is issue 50's job,
  and comments at the `PIECE_BUFFS` entry and both consume sites say so.
- **Ally half deferred exactly as analysed.** `_lose_player_piece` consumes the buff
  through the existing `_consume_buff` choke point (so other on-consume effects still see
  the trigger) and increments `pending_bounty_boxes`. `_begin_player_turn()` drains **one
  per Turn start**; extra copies queued in the same window wait for a later Turn rather
  than chaining. Built fresh — `pass_after_box` was deleted by slice 47, as this issue was
  corrected to say.
- **Enemy half** opens immediately during the player's own turn.

**The ally-half test is the one that matters, and it is the right shape.** An ally carrying
the buff is captured via `_run_enemy_actions()`; the test then asserts `pending_bounty_boxes
== 1` **and `buff_pick_open == false`** — proving no modal opened mid-enemy-turn, which is
the whole reason for the deferral. Only after `_begin_player_turn()` does it assert the
modal is open, press a **real panel button** (`.pressed.emit()`, not a synthetic call),
resolve the Box, and assert `stock`/`items`/`artefacts` actually grew. A reward landed, not
just a modal closed. A second test proves only one of two same-window payouts resolves per
Turn.

Reachable from `_random_buff_key` deliberately (no `self_harming` flag, so the existing
filter includes it with no code change); verified across 300 seeds. Added to the Notion
Piece Buffs DB.

**RNG ripple, second occurrence:** growing `PIECE_BUFFS` to 13 changed `_random_buff_key`'s
modulo and moved Holy Lint's pinned seed-4 assertion from `reflect` to `shield`. The new
value was probed directly rather than guessed, and `shield` re-checked against the same
Bomb/Trap/Multicapture hazard list. Only affected assertion in the full sweep. See the new
FLAGS.md entry — that assertion has now churned twice in two slices and is worth reshaping.
