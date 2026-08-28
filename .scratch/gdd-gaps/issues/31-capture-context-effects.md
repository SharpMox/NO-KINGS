# 31 — Capture-context effects

Status: done (3 of 4 — Dark Market Light Bulb blocked, see Outcome)

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

Several artefacts key off properties of a capture the ctx already *nearly* carries. The
capture ctx has `attacker_id`, `attacker_pos`, `attacker_buffed`, `victim_pos`,
`victim_captures`, `wave_capture_index`, `turn_capture_index`.

Buildable now:

- **Curtain Rods Bag (Rifle-Shaped)** — *"On your first Capture each Wave: double Score,
  but it pays no Gold"*. `wave_capture_index` gives the first-capture test; the "pays no
  Gold" half needs the Score and Gold sides of `Economy.earn` to diverge for one call,
  which the `gold_bonus`/`score_bonus` ctx channels can express.
- **Templar Debit Card** — needs a "pay with Score" path.
- **$2.3 Trillion Receipt** — needs `_destroy` to expose a score hook. Note `_destroy`
  deliberately pays nothing today (Destruction is not capture, per CONTEXT.md), so this is
  a deliberate exception rather than a bug fix — say so in the code.

⚠️ **Blocked on a definition:** **Dark Market Light Bulb** — *"Ranked pieces give double
Gold on Capture; Demoted pieces give no Score on Capture"*. `ArtefactHooks._ranked()`
already defines Ranked (not its own chain base). **"Demoted" is undefined** — a piece that
has been demoted at some point? one currently below its peak? Do NOT guess; raise it as a
Notion question and leave the artefact unimplemented.

## Acceptance criteria

- [ ] Curtain Rods Bag, Templar Debit Card, $2.3 Trillion Receipt implemented
- [ ] "Demoted" raised as a Notion question, artefact left unimplemented
- [ ] `run_all.sh` all green

## Outcome (2026-08-28)

Shipped all three buildable ones:

- **Curtain Rods Bag (Rifle-Shaped)** — the capture's `Economy.earn` call is now tagged
  `reason = "wave_first_capture"`; the Score handler doubles off the immutable base, and the
  Gold handler cancels that call's own 1:1 contribution (floored, so stacked copies cannot go
  negative). No new ctx channel needed.
- **Templar Debit Card** — `Shop._score_credit()`, following Agartha Welcome Mat's existing
  "standing rule read off `g.artefacts`" shape rather than adding a REGISTRY entry.
- **$2.3 Trillion Receipt** — `_destroy()` grew a `by_item` flag and a new `on_destroy` hook,
  fired only by Drone Strike / Air Strike / Sniper. Commented in code as a **deliberate
  exception** to "Destruction pays nothing" (CONTEXT.md) so the next reader does not think the
  invariant was forgotten. Bomb's `_detonate` and the JD Vance Tariff stay unpaid.

### ⚠️ Open question for the user — "Demoted"

**Dark Market Light Bulb** is left `implemented: false`. Its text is *"Ranked pieces give
double Gold on Capture; Demoted pieces give no Score on Capture."* `ArtefactHooks._ranked()`
already defines Ranked (a piece that is not its own promotion-chain base), but **"Demoted"
has no definition anywhere in the code or the GDD**. Two plausible readings:

- **(a)** a piece that has been demoted at any point this run — needs a persistent per-piece
  flag, and a piece stays "Demoted" forever even after being re-promoted.
- **(b)** a piece currently sitting below its historical peak rank — needs a per-piece peak
  stamp, and the label clears when it climbs back.

These differ materially for any piece that gets demoted and then re-promoted. Not guessed at.

## Blocked by

- nothing for the three; Dark Market Light Bulb blocked on the definition
