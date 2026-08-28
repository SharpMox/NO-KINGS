# 31 — Capture-context effects

Status: todo — MOSTLY INDEPENDENT (one term needs defining)

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

## Blocked by

- nothing for the three; Dark Market Light Bulb blocked on the definition
