# 67 — The Family framework + the three seed Families

Status: todo — SPECCED (user rulings 2026-08-30) · family-1 name provisional

## Parent

`.scratch/gdd-gaps/PRD.md`

## What a Family is (ruled)

Choosing a Family determines **Starting Stock, Starting Gold, Starting Artefacts, Starting
Items**, plus:

- a **Family Power** — static buff, active the whole run
- a **Family Ability** — once per Wave, **costs 1 Action** to activate

**Family choice REPLACES the Army pick at run start** (user ruling). `Tuning.ARMIES` becomes
each Family's Starting Stock field. **Keep the save key `army`** holding the family id —
load-bearing keys stay, per the standing convention (bounty/Apocrypha precedent).

**Ability back-out follows slice 52's rule** (user ruling): confirm when untargeted, cancel
from targeting when targeted. Once-per-Wave uses the `*_used_this_wave` idiom reset on Wave
clear. The 1-Action cost is a deliberate contrast with Artefact activation (0) and the Shop
(now 0): `actions_left >= 1` gates it and activation spends one.

**Surface**: the Activate section of the inventory drawer (slice 52's seam), with the Family
Ability visually distinct from Artefact chips. Extend the windowed click probes.

**Engine**: Powers are always-on effects — ride the `artefact_hooks` dispatch (a Family is
mechanically "a held effect that cannot be sold and takes no Artefact slot"). Whatever shape
is chosen, Powers must compose with held Artefacts under the additive stacking rule.

## The three seed Families

### 1. The Levy *(name provisional — alternates: The Muster, The Retinue; user asked for a medieval-army term to replace "Crown")*

*Classic chess: 8 pawns + rook, bishop, knight. Identity: mustering and merging.*

- **Kit**: standard stock (current Crown list) · baseline Gold · 1 **Promote** item
- **Power — Close Ranks**: merges cost no Action
- **Ability — Call the Banners** (1/wave, 1 Action): **copy a target piece from your Stock**
  — duplicate the entry into Stock

The user replaced the original rank-up Ability because it overlapped the Power. The new pair
*combos* instead: copy a piece -> free same-pair merge -> rank up. Copying duplicates the
Stock entry **verbatim** (ADR-0002 carries any state; Asset Recovery is the precedent).

### 2. Wild Hunt

- **Kit**: standard stock · low Gold (~half baseline) · 2 **Blitz** items
- **Power — Blood in the Air**: your first capture each Turn refunds its Action
- **Ability — Loose the Hounds** (1/wave, 1 Action): this Turn, your pieces' **moves** cost
  no Actions; captures still pay

**Interaction to assert, not avoid**: the core Artefact `first_capture_extra` is
near-identical to the Power. Held together they stack **additively** (two refunds) per the
standing stacking rule and the "big interactions stay" principle. Test the pair explicitly.

### 3. Old Guard

- **Kit**: current Old Guard stock (largest set) · low Gold · 1 **Extraction** item
- **Power — Hold the Line**: when you **lose** a piece, refund its full value in Gold
- **Ability — Shield Wall** (1/wave, 1 Action): every piece on your back two rows gains
  **Shield**

**⚠️ THE SAFETY CATCH — "lose" means `on_piece_lost` only.** Selling a piece must NOT
trigger the refund: sell pays 50% and a loss-refund of 100% would make selling pay 150% —
a money printer. Selling removes from Stock and never touches `on_piece_lost` (board
losses), so the hook placement gives this for free — but **assert it directly**: sell a
piece as Old Guard, Gold rises by exactly the sell price. Also: a loss masked by
'Definitely Not Russia' Patch gives **no refund** (issue 53 ruled its mask covers
everything reading `on_piece_lost`) — consistent, assert it.

Shield Wall routes through `_apply_buff`; pieces at the buff cap get the floating
"Buffs full" refusal, which is correct and visible.

## Acceptance

- Family selection replaces the Army pick; all five determinants apply on run start; save
  round-trips the family id + Ability used-this-wave state (**assert the restored value** —
  the identity check cannot catch a missing field).
- All three Powers and Abilities work and are covered per the interactions above.
- Once-per-Wave re-arms on Wave clear; the 1-Action cost is spent and gated.
- Click probes cover the Ability chip. Split suites intact, seeds pinned.
- `run_all.sh` ALL GREEN — `timeout: 600000`, blocking, alone.
- Update the Notion Families page (created by slice 66) with the shipped content.

## Blocked by

- slice 66 (the Notion Families page + display terms) — code seams are independent, but
  land 66 first to avoid doc collisions
