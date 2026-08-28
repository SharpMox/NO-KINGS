# 42 — Full buff pool, and "Demoted"

Status: todo — INDEPENDENT (both ruled 2026-08-29)

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

- [ ] Random grants draw from all tiers; `slow` still excluded as self-harming
- [ ] The three Tactical granters widened AND their Notion text updated, or left alone with a
      recorded reason — not silently mismatched
- [ ] Per-piece peak-rank stamp, persisted, clearing correctly on re-promotion
- [ ] Dark Market Light Bulb implemented
- [ ] `run_all.sh` all green

## Blocked by

- nothing
