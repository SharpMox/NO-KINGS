# 85 — Cloud leaderboards

Status: todo

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
