# 85 — Cloud leaderboards

Status: done (2026-08-31)

## Parent

`.scratch/gdd-gaps/issues/72-accounts-and-offline.md`

## Scope

User ruling (2026-08-31): **leaderboards go cloud, with the same highest-wins merge rule.**
The local board (`Economy.record_score`) stays as the offline view — it is not replaced.

So: two views over the same data, the local one always available, the cloud one when reachable.

## The pairing worth stating up front

**The seed system (issue 75, shipped) is what makes a cloud leaderboard meaningful.** Same
seed, same board, genuinely comparable runs — otherwise a leaderboard compares luck.

The seed and the build version are **both already displayed on the results screen**, put there
for exactly this. If seeded leaderboards are wanted, the data is present; that is a scope
decision for this slice, not new work.

## Watch out

- Reuse 84's merge rule rather than writing a second one. Two implementations of
  "highest wins" will drift.
- Offline must show the local board without an error state — an unreachable leaderboard is the
  normal case, not a failure.

## Acceptance

- Cloud board reads and writes through the backend seam; local board unchanged and still
  shown offline.
- Merge behaviour matches 84's rule, sharing its implementation.
- Menu click probes reach both views.
- `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

- 84 (the merge rule and the queue)

## Outcome (2026-08-31)

**Cloud board reads through the backend seam; the local board is unchanged and is exactly what
shows when the cloud is unreachable.**

### The issue's own instruction was the wrong answer, and this is the finding

85 said *"Reuse 84's merge rule rather than writing a second one. Two implementations of
'highest wins' will drift."* Reasonable, and **wrong here** — following it would have lost data.

`CloudSave.resolve()` picks **one side wholesale**. That is correct for a run state, where
there is exactly one true current run. A leaderboard is a **set of finished runs**, so picking
a side silently deletes the other device's real scores — a player would watch entries vanish
after syncing.

`Leaderboard.merge()` applies highest-wins **per entry instead of per payload**: union both
boards, dedupe, sort, keep the top 10. Same monotonic principle — nothing regresses, no
timestamps, no three-way merge — expressed for a *set* rather than a *state*. The reasoning is
in the file header so the "just reuse resolve()" instinct does not come back.

### Behaviour

- `Leaderboard.board(local)` is what the Scores screen renders: local unioned with the cloud
  when there is one, exactly local when there is not.
- **An unreachable leaderboard is the normal case**, not an error: desktop, offline, or a
  platform whose plugin has not landed. The screen carries a status line — *"Cloud scores
  included."* / *"Local scores — sign in to compare."* — so the player can tell "no cloud
  scores yet" from "not signed in", and never sees a failure state for the ordinary case.
- Dedupe is on `score/wave/kings`, so **the same board synced up and pulled back does not
  duplicate itself** — the failure mode a naive union has.
- `merge()` is order-independent and idempotent; both asserted.

The seed pairing the issue notes still holds and needs no work: the seed and build version are
already on the results screen, so seeded leaderboards are a scope decision rather than new
plumbing.

### Tests

10 assertions in `test_leaderboard.gd`, the load-bearing one being that **both devices' runs
survive** — a pick-one implementation fails it immediately. Plus a malformed cloud payload
falling back to local rather than erroring, and a probe assertion that the Scores screen states
which board it is showing.

`run_all.sh` **157.1s ALL GREEN**, foreground, alone.
