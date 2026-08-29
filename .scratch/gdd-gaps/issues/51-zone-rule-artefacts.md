# 51 — The two zone-rule Artefacts

Status: done (2026-08-29)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why this can start

Issue 33 parks nine Artefacts behind four design decisions. **Decision #1 — "do zone rules
bind the AI, or only the player?" — is answered**, and these two are cleared to build.
The rest of issue 33 stays parked.

The answer was cheaper than issue 33 assumed: **`ai_action` calls `Rules.legal_moves`**
(`rules.gd:280`), the same generator the player's moves come from. One filter binds both
sides; there is no second AI move generator to keep in sync.

## Scope

### 1. Winchester Salt Lined Doors — Legendary

> Enemy pieces cannot move onto your back row

Your back row is `y = 0` — the row `_back_row_breached()` watches and the one enemies
march toward. Enemies spawn at `SPAWN_ROW = BOARD_H - 1`, so this never conflicts with
spawning.

Filter enemy destinations of `y == 0` out of `Rules.legal_moves`.

**`rules.gd` is a pure static module and must stay that way** — it has no access to
`g.artefacts` and should not gain any. The denied set (or a simple flag) is computed by
`game.gd` from the held Artefacts and passed *into* `legal_moves`. `_deploy_tiles()`
reading `_held("nazca-boarding-pass")` in `game.gd` is the precedent for where that read
belongs.

Two things to settle while implementing, both small but worth a comment rather than a
silent choice:

- **An enemy already standing on `y = 0`** when you acquire this is not affected — the
  text forbids *moving onto* the row, not being there. It should be free to stay, and free
  to leave.
- **Does it also prevent captures on `y = 0`?** A capture is normally a move onto the
  victim's tile, so ordinarily yes. Check whether any piece can capture *without* moving
  (`moves_for`'s `mode_filter` suggests distinct move/capture modes) — if such a piece
  exists, decide and document whether Winchester stops it.

**Yes, this makes the back-row breach loss unreachable.** That is the card working as
written, not a bug — assert it in a test rather than treating it as a surprise.

### 2. Cheyenne Mountain Doorbell — Legendary

> Your pieces on your back row cannot be captured

Player pieces on `y = 0` cannot be captured. The precedent is the existing repel path:
`BuffLogic.repels_capture` already expresses "this capture attempt does not happen, the
attacker stays put" for Shield and Reflect. Hook the same place rather than inventing a
second concept.

Note **Winchester largely subsumes this** — if enemies cannot enter `y = 0` at all, they
cannot capture there either. That is fine; they are separate Legendaries and holding both
is simply redundant. Cheyenne still does real work on its own, and it is the simpler of
the two, so build it first.

## Neither of these is a REGISTRY hook

Both are passive board rules read from the held Artefacts at the point the rule is
evaluated — like `_deploy_tiles()` reads Nazca Boarding Pass — not `on_*` dispatches.

That means `test_items_artefacts_4.gd`'s **REGISTRY-coverage audit will fail** unless both
keys are added to its documented-exception list, the same way slice 46's three Box
Artefacts were. Expect it; do not paper over it with hollow REGISTRY entries.

## Acceptance

- Both `implemented: true` in `data/artefacts.js`, `(needs: …)` notes cleared, then
  `node tools/export-game-artefacts.mjs`. Never hand-edit `game/data/artefacts.json`.
- **The AI is bound too** — assert it directly: an enemy that would otherwise have a legal
  move onto `y = 0` does not take it, driven through `ai_action`, not just through
  `legal_moves`.
- Winchester: assert the back-row breach cannot occur while it is held.
- Cheyenne: assert a capture attempt on a `y = 0` player piece is repelled and the
  attacker stays put.
- `rules.gd` gains no reference to `g.artefacts`.
- Tests in the split suites, seeds pinned, asserting observable behaviour. `run_all.sh`
  ALL GREEN.

## Blocked by

- nothing

## Outcome

Both implemented. `data/artefacts.js` flipped `implemented: true` and cleared the
`(needs: …)` notes; `node tools/export-game-artefacts.mjs` regenerated the JSON.

- **`rules.gd` stays pure.** `legal_moves`, `ai_action` and `is_checkmate` each gained a
  `denied: Array[Vector2i] = []` parameter (default empty, so every existing call site is
  unaffected) — a plain destination denylist, generic to any future zone rule, not
  Artefact-specific. `game.gd._enemy_denied_tiles()` (next to `_deploy_tiles`, the Nazca
  Boarding Pass precedent) reads `_held("winchester-salt-lined-doors")` and returns the 8
  `y=0` tiles or `[]`; it is threaded into all three `Rules.*` call sites. No
  `g.artefacts` reference exists in `rules.gd`.
- **The AI is bound, proven through `ai_action`.** `test_rules.gd` denies the back row on
  the existing "full-width swarm commits to row 0" fixture and asserts `ai_action(...,
  denied)` returns `{}` (not merely that `legal_moves` came back filtered).
  `test_items_artefacts_4.gd` goes one level up: a real `_boot()` scenario holding
  Winchester, driven through `g._run_enemy_actions()` (the actual `game.gd` call path),
  with a **control run without the artefact first** proving the same board really would
  complete the breach — so the held-artefact run is proof of a block, not a scenario that
  could never have happened.
- **Enemy already on `y=0`:** filtering is by destination only, never origin — a piece
  already standing there is untouched and free to leave via any non-denied square.
  Documented as a deliberate reading in `rules.gd`'s `legal_moves` header and asserted in
  `test_rules.gd` (a rook on the denied row keeps its non-row0 moves).
  Moving *sideways* to another `y=0` tile is still denied — "cannot move onto" reads as
  about the destination, not which side of the row the piece started on.
- **Captures on `y=0`:** yes, denied identically — a capture is a move onto the victim's
  tile in this engine (`board[to] = board[from]; board.erase(from)`), so a single
  destination filter covers movement and capture alike. Audited `moves_for`'s
  `mode_filter` and every move-execution path in `game.gd` for a piece that captures
  without relocating: the only one that exists, Multicapture, is player-only and can only
  destroy an *enemy* piece adjacent to a landed capture — it never threatens a player
  piece, so it can never bypass Cheyenne and is irrelevant to Winchester. No
  capture-without-moving case needed special handling.
- **Winchester makes the back-row breach unreachable — asserted, not treated as a bug.**
  Same `_boot()` scenario (7 stuck enemy pawns filling `y=0` columns 0-6, an enemy rook one
  step from the last column, 8 enemies at `y<=2` meeting the AI's "commit" threshold) is
  run twice: without Winchester the swarm completes the breach (`_back_row_breached()` true,
  `state == GAME_OVER`); with it held, the rook never lands on the last tile and neither
  fires.
- **Cheyenne** hooks the existing repel branch in `game.gd._run_enemy_actions()` (the
  `BuffLogic.repels_capture` / Shield-Reflect site) rather than inventing a second concept:
  `board[act.to].owner == PLAYER and act.to.y == 0 and _held("cheyenne-mountain-doorbell")`
  joins the same `if`, and since there's no Buff to consume it falls into the existing
  "Blocked" branch with `_consume_buff` skipped. Asserted with the same control-then-held
  pattern: without the artefact an enemy rook freely captures a back-row player piece; with
  it, the piece survives and the attacker stays on its own tile.
- **Not a REGISTRY hook, as expected.** Both keys added to `test_items_artefacts_4.gd`'s
  documented `no_registry_exceptions` (slice 46's Box Artefacts precedent) — passive board
  rules read directly off held Artefacts, never an `on_*` dispatch.
- `is_checkmate` also took the `denied` parameter (both `game.gd` call sites now pass
  `_enemy_denied_tiles()`) so the win-condition check and `ai_action` never disagree about
  which squares are legal — Winchester denying a king's only escape onto `y=0` must read as
  checkmate, not as a move `ai_action` then refuses to make. No dedicated test for this
  narrower case (constructing a forced single-escape-onto-row-0 checkmate needs several
  blocking pieces purely to pin the king down); the existing `ai_action`/`legal_moves`
  coverage on the shared `denied` mechanism, plus `run_all.sh`'s scenario/autoplay sweeps,
  are the regression net for it.
- `game/tests/run_all.sh` — ALL GREEN, all 7 split item suites (`test_items.gd` +
  `test_items_{tariffs,buffs,artefacts_1,artefacts_2,artefacts_3,artefacts_4}.gd`) intact.
