# 50 — Legacy content cleanup: only what Notion describes should ship

Status: done (2026-08-30)

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

## Two more items, found by the 2026-08-30 GDD sweep

1. **The `bounty` rename still has not happened anywhere.** The Notion Piece Buffs row for the
   new **Bounty** Buff records that *"the Buff takes the name; the Artefact is renamed/retired
   separately"* — and that separate step is this issue's, still outstanding. The game ships
   both a Piece Buff named Bounty (key `piece_bounty`) and a legacy core Artefact named Bounty
   (key `bounty`), which is exactly the confusion the ruling was meant to end.

2. **The Wave Catalog's buffed-enemy data is vestigial.** Slice 47 removed the box-carrier
   enemy, but the Notion Wave Catalog still carries a **"Buffed-enemy flags"** column and a
   **"25 buffed-enemy waves"** total. The sweep flagged these inline rather than rewriting
   them — it is a 150-row table and out of scope for a note. Cleaning it belongs here.

## Outcome

Shipped in PR #219.

**The `bounty` collision:** renamed the legacy core Artefact's **display name only**, to
**"Skip Tracer's Rolodex"** — the key stays `bounty`. It is load-bearing (saves,
`data/scenarios.gd`, the Shop all match on it directly) and no player ever sees the key, so
renaming it would trade real save-migration risk for zero visible benefit; a display-name-only
rename fully resolves the collision the user's ruling (issue 48) was about. No `_MIGRATIONS`
entry was needed as a result — nothing in the save shape changed. Updated the Notion Artefacts
page and the Bounty Piece Buff page's Notes to record the rename.

**The other 6 core Artefacts:** left alone, as specced — the keep-or-retire ruling for them
(issue 62) hasn't been made. Re-verified `items.gd`'s header comment describing them is still
accurate.

**Wave Catalog:** removed the vestigial "Buffed-enemy flags" column across all 150 rows and the
"25 buffed-enemy waves" total from Totals, plus two per-row Notes that referenced the removed
mechanic by name (waves 3 and 28).

**Notion drift checker:** re-ran against a fresh 180/16/39/21 snapshot — 85 findings, all
reported rather than fixed (out of this issue's scope). Most Artefact findings are Notion still
carrying a `(needs: ...)` note for mechanics that are actually built. A few are real semantic
drift worth a follow-up: Mar-a-Lago Toilet Papers and Silk Road Coupon (Notion says "Shop
restock", repo says "5-Wave Milestone"), Pegasus Free Trial (different mechanic entirely), Spare
Organ Receipt (Notion describes one consumed piece, Fuse consumes two). Tariffs: one real gap —
Notion defines a "Tariff on Promotion" with no `game/data/tariffs.gd` entry at all. Pieces: `king`
exists in Notion but not `data/pieces-codex.js`, almost certainly intentional (that file's header
says "curated 38-piece working-set"; the King is the objective piece, not a codex piece) but
never explicitly logged as an exclusion. Could not confirm or refute the "STATUS triage synced
2026-07-14" claim in `items.gd`'s header — the checker only sees current Notion state, not
2026-07-14's, so it stays unverifiable, same as the previous agent found.

`run_all.sh` ALL GREEN, run alone.
