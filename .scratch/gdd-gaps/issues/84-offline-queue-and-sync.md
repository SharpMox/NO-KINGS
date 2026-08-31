# 84 — Offline play while signed in, and the sync queue

Status: done (2026-08-31)

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

## Outcome (2026-08-31)

**Offline play queues; reconnect drains; highest wave wins in both directions.**

`scripts/sync_queue.gd` — **persisted**, not in-memory: the queue has to survive the app being
killed, which is the ordinary way a mobile game ends, and an in-memory queue would lose exactly
the sessions it exists to protect. Keyed by save key holding the **latest payload per key
rather than a log** — two offline sessions of the same run do not need pushing twice, and a
log would replay stale states in order to arrive at the same place.

`CloudSave.push()` now enqueues instead of dropping when the backend is unreachable:
**unreachable is deferred, not failed**, which is what "play normally and queue" requires.
`CloudSave.drain_queue()` sends the queue and is safe to call at any boot.

**Drained BEFORE the mirror pull** in `menu.gd`, not after. Draining afterwards would resolve
this device's progress against a cloud copy still missing the very sessions sitting in the
queue.

### Highest wave wins — and no merge machinery was built

`CloudSave.resolve()` compares wave ahead of the timestamp, falling through to the existing
last-write-wins when either side carries no wave (scores and history are not run states) or
when the waves are equal. **No timestamps beyond what already existed, no three-way merge, no
clock agreement between devices** — the rule works because progress here is monotonic, and the
issue was explicit that a merge should not be built.

### The two assertions an implementation can pass while being wrong

Both are in `tests/test_sync.gd`, and both were the issue's own warnings:

- **A partial drain must not lose the rest of the queue.** Asserted with a pusher that fails
  one key of three: the failed entry is kept with its payload intact, the two successes are
  dropped. A drain that cleared wholesale on first success would pass a happy-path test.
- **Highest-wins must be asserted in BOTH directions.** An implementation that only ever
  discards the *remote* side passes a naive test and is wrong in the case that matters — this
  device being the one behind. So: remote wins on a deeper wave *even with a newer local file*,
  and local wins on a deeper wave *even with a newer remote push*.

19 assertions. `run_all.sh` **155.3s ALL GREEN**, foreground, alone. The existing
`test_cloud_save.gd` passes unchanged — the wave rule is additive to last-write-wins, not a
replacement for it.
