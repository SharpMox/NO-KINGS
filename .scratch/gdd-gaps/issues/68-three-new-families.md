# 68 — Three new Families: Syndicate, Cult, Horde

Status: todo — SPECCED (user rulings 2026-08-30) · after 67

## Parent

`.scratch/gdd-gaps/PRD.md` · framework: issue 67

All numbers are ballpark and tunable later (standing user stance); the shapes are ruled.

### 4. The Syndicate — money

- **Kit**: thin stock (~6 pawns + 1 knight) · **triple** baseline Gold
- **Power — Insider Rates**: Shop buy prices ×0.75; sell payouts ×1.25 (50% -> 62.5%,
  floor). **Captured->Stock conversion cost unchanged** at 50% — it is not a Shop purchase,
  and discounting it would reopen the convert/sell arbitrage that equal rates closed.
- **Ability — Hostile Takeover** (1/wave, 1 Action): pay **200% of a target enemy piece's
  value** (user ruling — not 100%): it is removed from the board and joins **your Stock**.

**Hostile Takeover details**: cannot target the King (Air Strike/Sniper precedent). It is a
purchase, not a capture — **no Score, no Gold, no `on_capture`, no capture ledger**; the
piece enters Stock as a **bare id** (state stripped — you bought the soldier, not their
buffs; recommendation, flag if changed). Note it deliberately bypasses the Captured-Stock
pipeline at a premium — that is the point of the family.

### 5. The Cult — buffs

- **Kit**: standard stock · **2 random Artefacts** at run start (seeded RNG, full
  `ARTEFACT_EFFECTS` pool, respecting the cap of 5) · 1 **Buff Box** item
- **Power — Communion**: your Piece Buff cap is 3 (base 2 +1)
- **Ability — Ritual** (1/wave, 1 Action): grant a target piece a random Buff from the
  **safe pool** (`_random_buff_key` — never `self_harming`)

**Interaction to assert**: Communion + Abduction Probe (+1 each) = cap 4, additive per the
stacking rule. Test the pair.

### 6. The Horde — swarm

- **Kit**: **14 pawns**, no majors · baseline Gold
- **Power — Endless Ranks**: pawn deploys cost no Gold (`deploy_cost` waived for pawns)
- **Ability — Conscription** (1/wave, 1 Action): add 2 pawns to your Stock (bare ids)

The kit is merge fuel, not an army — 14 pawns feed the promotion chains. Untargeted
Ability -> confirm dialog per slice 52's rule.

## Acceptance

- All three selectable with kits applied; Powers and Abilities live; the two flagged
  interactions asserted; Syndicate's no-capture-credit asserted (Score/ledgers unchanged by
  a Takeover); probes extended; split suites intact; `run_all.sh` ALL GREEN
  (`timeout: 600000`, blocking, alone). Notion Families page updated with shipped content.

## Blocked by

- issue 67 (the framework)
