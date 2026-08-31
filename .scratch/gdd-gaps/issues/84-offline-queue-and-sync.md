# 84 — Offline play while signed in, and the sync queue

Status: todo

## Parent

`.scratch/gdd-gaps/issues/72-accounts-and-offline.md` (split (c))

## Scope

User ruling (2026-08-31): **offline while signed in plays normally and queues for sync.**
Conflict rule when the same account has played on two devices: **highest wave reached wins.**

That rule works precisely because progress here is monotonic — Score and deepest-wave only
ever increase — so "highest wins" is well-defined and needs **no timestamps and no three-way
merge**. Do not build one.

- Writes go to local disk first, always. The queue is a list of pending pushes.
- On reconnect, drain the queue; on conflict, take the higher wave.
- The queue must survive a kill — it is persisted, not in-memory.

## Testable without a device, which is the point of splitting it here

`cloud_backend_memory.gd` already exists as a test backend. Everything in this slice is
backend-agnostic and can be driven against it: go offline, play, reconnect, assert the drain.
**No Play Games or Game Center needed** — that is why this slice comes before 86/87 rather
than after.

## Watch out

- **Assert the conflict rule with the loser being the local device**, not only the remote one.
  A "highest wins" implementation that only ever discards remote data passes a naive test and
  is wrong in exactly the case that matters.
- A drain that partially fails must not lose the rest of the queue.
- `CloudSave.sync_file` is already called at menu boot for run/scores/history — this slice
  changes what happens when that call cannot reach anything.

## Acceptance

- Playing offline while signed in works with no degradation and no prompt.
- The queue persists across a kill and drains on reconnect.
- Highest-wave-wins asserted in **both** directions.
- `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

- 83 (account-owned saves — there is nothing to sync until saves have an owner)
