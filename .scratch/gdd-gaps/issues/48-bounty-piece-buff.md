# 48 — Bounty, a new Piece Buff

Status: todo — SPECCED (user design 2026-08-29) · **after 47**

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
- The trigger fires inside a capture. `game.gd`'s `_move_player` capture block has a
  delicate order (`Economy.capture_score` runs before `critical`/`range` consumption), and
  losses run through `on_piece_lost` inside the enemy turn loop. **Opening a modal from
  inside the enemy's turn is the same suspension problem that parks Inflatable Vietcong
  Torpedo in issue 33** — check whether the ally-loss half hits it before assuming both
  halves are equally cheap. If it does, say so rather than working around it.
- Autoplay must resolve both the 1-of-3 choice and the Box itself without a modal, or the
  bot leg hangs instead of failing.

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
