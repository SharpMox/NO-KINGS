# 21 — Artefacts: echo, duplication and cross-artefact meta-triggers

Status: done (partial)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Split out of

19 — during that slice's triage, this group turned out to be one real system
(a meta-layer over `ArtefactHooks.run()` itself), not a scatter of one-offs —
see issue 19's Outcome for the full accounting of what shipped there instead.

## What to build

Every artefact here reads or reacts to *another artefact's own trigger*, not
to a game event directly. `ArtefactHooks.run(g, hook, ctx)` today just walks
`REGISTRY` and calls `_dispatch` per held key — it has no concept of "an
artefact fired," "twice," or "the last one bought," so none of these can be
expressed as an ordinary REGISTRY line + `match` case. The real work is
deciding what `run()` itself needs to expose (a fired-this-call list? a
trigger log?) before any of these can be REGISTRY entries.

| Artefact | Needs | Note |
| --- | --- | --- |
| 100% Genuine Original Mona Lisa | artefact echo | "your first Artefact trigger [any hook] is copied and triggers again," including enemy turns |
| Red Diary's Missing Pages | artefact echo | same idea, scoped to "on losing a piece" Artefacts only (on_piece_lost, issue 19) |
| Polybius Cartridge | (no needs-note, Special) | "When a 'Capture' Artefact triggers: it triggers an additional time" — same shape, scoped to on_capture |
| Max Headroom Mask | (no needs-note, Special) | same shape, scoped to "Wave" Artefacts (on_wave_clear/on_wave_spawn) |
| CERN Ctrl+Z Shortcut | duplicate detection | "your duplicate Artefacts trigger one extra time" — needs run() to know a key is held 2+ times, which REGISTRY already implies but no handler currently reads |
| Bilderberg Hotel Slippers | trigger tracking | "+15 Gold whenever two or more of your Artefacts trigger on the same event" — needs run() to report how many handlers actually fired this call, not just how many are held |
| Déjà Vu Glitch | gain multiplier | "your first Score gain and first Gold gain each Turn: they trigger again" — re-running Economy.earn's own ctx a second time without double-charging the reason-tagged early-clear/etc. gates |
| Troll Farm Employee of the Month | dual-trigger dispatch | "your 'Wave' Artefacts also trigger on Wave start" — cross-wires on_wave_spawn to also run the on_wave_clear handlers, artefact-by-artefact |
| Ecdysis Sheddings | artefact-copy dispatch | "copies the effect of the last other Artefact you bought" — needs a purchase-order log and a way to invoke an arbitrary key's handler by name |
| Illuminati: NWO Booster Pack | artefact-trigger event | "+2 Gold/+20 Score whenever a 'Capture' Artefact triggers" — same shape as Polybius but additive, not multiplicative |
| Illuminati Fridge Magnet | rarity threading | "own Artefacts of every rarity" — `Items.ARTEFACT_EFFECTS` carries `rarity` per-entry (issue 18) but the 7 core keys have none at all, so "every rarity" can never be literally true while they're held — a design question, not just plumbing (issue 16's held-back note) |
| Capstone Polish | acquisition-path ambiguity | "on acquiring an Artefact" only reaches on_purchase today; box-granted artefacts are a different call site (issue 16's held-back note, repeated in issue 17/18) |
| Deep State Yearbook / New World Order Gerrymandering | cross-artefact modification | both artefacts modify *other* artefacts' own payouts — real design work on what "modifies" means before any hook shape follows (issue 16's held-back note) |

## Acceptance criteria

- [x] Decide `run()`'s new contract: does it return which keys actually fired
      (not just which are held), and is a "trigger log" (last N hook fires,
      with key + hook) worth adding as a small `g` field the way
      `wave_capture_count` etc. already are?
- [x] Illuminati Fridge Magnet and the two Yearbook/Gerrymandering artefacts
      need a design ruling before they're triaged further — Notion question,
      not a guess
- [x] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 19 — Special + prereq triage (this file is one of its splits)

## Outcome

`ArtefactHooks.run()` grew a `fired` list (local to each call, not a new `g`
field — a "trigger log" turned out to be unnecessary once `fired` exists: a
`(key, hook)` history has no reader that `fired`'s live snapshot doesn't
already serve). `run()` builds `fired` inline from the existing held+tariffs
dispatch loop, then hands it to a new `_run_meta_triggers(g, hook, ctx,
fired, held)` pass — the meta/echo layer — which runs once per `run()` call,
gated by a `g.artefact_echo_depth` re-entrancy guard.

**Re-entrancy rule (written into the header alongside the existing
contract):** every extra trigger the meta pass produces goes straight
through `_dispatch`, never back through `run()`. That makes an echo
observing itself, chaining, or ping-ponging between two held echo artefacts
structurally impossible — not just guarded — because `_run_meta_triggers`
only ever runs once, off the single `fired` snapshot the normal loop already
built; nothing an echoed `_dispatch` does can be seen by a second pass of
itself. `artefact_echo_depth` is the belt-and-suspenders backstop for a
future handler that did call `run()` reentrantly.

Stacking and ordering both survive: N held copies of an echo artefact is N
extra `_dispatch` calls (additive, not compounding — the same rule the
7-artefact core already established), and the meta pass reads `fired`, built
from the same key-sorted `held + tariffs` loop the ORDERING rule already
covers, so nothing about the echo pass depends on iteration order. Verified
directly: `test_items.gd`'s "risky one" holds two echo artefacts (Polybius
Cartridge + CERN Ctrl+Z Shortcut, both on_capture) on top of a duplicated
Capture artefact (two Greeds) plus a percentage artefact (Tinfoil Hat) on
the resulting gain, asserts the exact bounded total (5 Greed dispatches: 2
main + 2 Polybius + 1 CERN, not a hang and not exponential growth), and
re-runs the same held keys in a different array order to assert byte-for-byte
identical results through the full capture+earn pipeline.

### Shipped (9)

100% Genuine Original Mona Lisa, Red Diary's Missing Pages, Polybius
Cartridge, Max Headroom Mask, CERN Ctrl+Z Shortcut, Bilderberg Hotel
Slippers, Illuminati: NWO Booster Pack, Déjà Vu Glitch, Capstone Polish.

Déjà Vu Glitch's "first Score/Gold gain each Turn: they trigger again" reads
as the whole gain repeating, not a second run through every handler (that
would double-charge reason-gated handlers like Naruto Run Manual's
early-clear bonus, and `Economy.earn`'s own ctx doesn't survive the call
boundary to re-invoke anyway — the exact gap issue 26 is scoped to close) —
implemented as a single `ctx.amount *= (1 + held copies)` on the hook's own
already-computed amount, gated by a per-Turn "first gain" flag. Documented
as the interpretation taken, not guessed silently.

Capstone Polish is scoped to `on_purchase` only, matching every other
"on acquiring/buying an Artefact" artefact already shipped
(putin-s-golden-toilet-brush, sleeper-agent-pillow, mao-s-loyalty-badge,
casino-invisible-clock) — applying an established pattern, not a new guess.
Box-granted artefacts stay the known, already-3x-deferred gap (issue 16's
held-back note, repeated in 17/18/19) — unchanged by this slice.

### Deferred (5) — not guessed into code

- **Illuminati Fridge Magnet** — unresolved since issue 19 (its own Outcome's
  open question #3): "own Artefacts of every rarity" can never be literally
  true while any of the 7 core keys (`greed`, `score`, `move`, `lifesteal`,
  `timer`, `bounty`, `first_capture_extra`) are held, since they predate the
  rarity system and carry none. Notion question, unchanged: give them a
  nominal rarity, or exclude them from this artefact's check by design?
- **Deep State Yearbook** / **New World Order Gerrymandering** — both modify
  *other* artefacts' own payouts ("each other Artefact you own pays +5 Gold";
  "Gold paid by other Artefacts is increased by 25%"). What "modifies" means
  is real design work, not plumbing: does it rewrite `ctx.amount`/`g.gold`
  after another handler already wrote it (order-dependent — exactly what the
  ORDERING rule exists to prevent), or does every Gold-paying handler need a
  new `ctx` output field these two sum instead of intercept? Notion
  question — a hook shape shouldn't be picked before that's answered.
- **Ecdysis Sheddings** — "copies the effect of the last other Artefact you
  bought" needs a way to invoke an arbitrary key's handler under a hook/ctx
  shape it wasn't built for: `on_purchase`'s ctx (`{kind, key, price}`) has
  none of `on_capture`'s `victim_id`/`attacker_id`/`base` a copied Greed or
  Sphinx's Booger would read, none of `on_wave_clear`'s `gold_spent`/
  `gold_base` a copied Zurich Gnome Figurine would read, and so on for all
  180 possible "last Artefact bought." A purchase-order log is cheap; a
  hook/ctx-agnostic way to safely replay an arbitrary handler is real
  design work. Notion question.
- **Troll Farm Employee of the Month** — "your 'Wave' Artefacts also trigger
  on Wave start" would hand `on_wave_clear`'s handlers an `on_wave_spawn`
  ctx missing `gold_spent`/`gold_base`/`captures`/`clean` — most of the 8
  `on_wave_clear` artefacts would silently pay out on zeroed/false fields
  (Zurich Gnome Figurine's 10% of `gold_spent` = 0; Social Credit Report
  Card's `ctx.clean` = false, always taking the penalty branch). Passing a
  synthetic zeroed ctx would be guessing a design the GDD text doesn't
  specify. Notion question: does Wave start get its own real snapshot (What
  counts as "Gold spent" for a Wave that hasn't happened yet?), or does this
  artefact's text need to change?

### Tests

`game/tests/test_items.gd` gained coverage for all 9 shipped artefacts
(including CERN's "singly-held key gets nothing" and Bilderberg's "one
trigger gets nothing" negative cases, and Mona Lisa's enemy-turn-boundary
reset specifically — consuming the player Turn's echo first, then proving
the enemy Turn gets a fresh one), plus the explicit re-entrancy stress case
described above. `game/data/scenarios.gd` gained "Artefacts: slice 21 (echo
and meta-triggers)", holding all 9 shipped keys plus the Capture/Wave/
piece-lost artefacts they echo, swept by `test_scenarios.gd`'s autoplay.
`game/tests/run_all.sh` — ALL GREEN, windowed click probes included.

135 of 180 artefacts now implemented (this slice's 9, on top of the 126 that
landed on `main` from issues 22/23/25/26 while this branch was in flight).

### Rebase note

`main` moved substantially during this slice — issues 22 (tariff
interception), 23 (Buff lifecycle), 25 (per-piece capture ledger) and 26
(economy/Shop/Box grab-bag) all merged, plus PR #125's ctx-contract fix.
Rebased onto `origin/main` keeping both sides everywhere `artefact_hooks.gd`
(header prose, `REGISTRY`, `_dispatch`), `game.gd` (new `g` fields) and
`test_items.gd` conflicted — all pure concatenation, no functional overlap
(different artefact keys, different `g` fields). `game/data/artefacts.json`
was regenerated with `node tools/export-game-artefacts.mjs` after the
rebase rather than trusting the auto-merge. The re-entrancy guard
(`g.artefact_echo_depth`, gating `_run_meta_triggers`) needed no changes:
`_run_meta_triggers` only ever reads `fired`/`held` built from *this* call's
own dispatch loop, so it's unaffected by how many more keys the wider
`REGISTRY` now holds — confirmed by re-running the "risky one" test (two
echo Artefacts + a percentage Artefact, bounded and order-independent)
against the rebased tree; it holds a small, isolated artefact set per test
instance so the result is identical regardless of registry size. Two of the
newly-landed handlers (mRNA Firmware Update, Alien Rocket Toy) call `run()`
reentrantly from inside their own `_dispatch` body for a *different* hook
(`on_rank_up`) — legitimate cross-hook re-entrancy the guard was never meant
to block (it only fires while `_run_meta_triggers` itself is running for
the SAME `run()` call), verified to still work correctly since both are
covered by their own issue-25/23 tests, which stayed green through the
rebase.
