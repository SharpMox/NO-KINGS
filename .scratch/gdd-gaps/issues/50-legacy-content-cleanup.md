# 50 — Legacy content cleanup: only what Notion describes should ship

Status: todo — LATER (user: "later probably") · not urgent, do not start ahead of 47-49

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

The user went looking for an Artefact called **Bounty**, could not find it in the Notion
DB, and was right — it is not there. It is one of seven **game-native** Artefact effects
in `ARTEFACT_EFFECTS_CORE` (`game/data/items.gd`) that pre-date the 180-entry catalog. The
file says so itself:

> "The 7 game-native artefact effects — pre-date the 180-entry reference-site catalog …
> and have no Notion/site equivalent, so they are not in that export."

They are **not dead code** — they are rolled in Boxes, sold in the Shop and grantable
today. So this is undocumented *content*: things a player can acquire that the design
source of truth has never heard of.

## The seven

| Key | Name | Effect |
| --- | --- | --- |
| `first_capture_extra` | First-Capture Extra Action | If your first action of a turn is a capture, gain an extra action |
| `greed` | Greed | +10 score per Pawn captured |
| `move` | Move | +1 action per turn |
| `lifesteal` | Lifesteal | Captures restore 2s of clock |
| `score` | Score | +10 score on every capture |
| `timer` | Timer | Milestone clock refills give +5s more |
| `bounty` | Bounty | +30 score when capturing a piece worth 50+ |

For each: promote it into the Notion Artefacts DB as canon, or retire it.

## Why this is not a simple delete

`items.gd` warns that these keys are load-bearing:

> "Keys are load-bearing: saves, scenarios (`data/scenarios.gd`) and the shop match on
> them directly."

So removing or renaming one touches save compatibility (`save_config.gd` carries
`SAVE_VERSION` and a `_MIGRATIONS` table built in slice 38 — this is plausibly its first
real customer), every TEST scenario that names the key, and Shop stocking.

## The one piece of this that is already committed

**`bounty` must be renamed or retired**, because issue 48's new Piece Buff takes the name
(user ruling 2026-08-29). Issue 48 deliberately avoids reusing the key while the Artefact
still holds it, so nothing is broken in the meantime — but the two cannot both be called
Bounty indefinitely.

## Also in scope

- Re-run `tools/check-notion-drift.mjs` (slice 39) and work its findings. Its first run
  found **59** on `main`, including ~30 stale `(needs: …)` notes and a Demote grammar
  difference. Slices 43-46 cleared some; the rest are unreviewed.
- Confirm `PIECE_BUFFS` and `ITEMS` are clean. `ITEMS` was synced 2026-07-14 (REWORK/REMOVE
  entries deleted), and `PIECE_BUFFS` gains Bounty in issue 48 — that one is designed in
  the repo first, so Notion needs to learn it rather than the reverse.
- The two rows already excluded at the bottom of `items.gd` (Capture Everything, Obstacle)
  should be confirmed as still-intended exclusions rather than forgotten ones.

## Acceptance

- Every Artefact, Item and Piece Buff the game can offer exists in Notion, or is
  deliberately and visibly excluded with a reason.
- No key rename breaks an existing save — via `_MIGRATIONS` if needed, per
  `save_config.gd`'s policy (an additive field is safe; a reshaped one is a silent
  corruption).
- `run_all.sh` ALL GREEN.

## Blocked by

- nothing structurally, but sequence it after 47-49; the user parked it as "later"
