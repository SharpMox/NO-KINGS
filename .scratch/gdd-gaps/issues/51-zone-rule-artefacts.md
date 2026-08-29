# 51 — The two zone-rule Artefacts

Status: todo — INDEPENDENT (cleared by the user; see issue 33's addendum)

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
