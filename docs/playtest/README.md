# Playtest baselines

The **"before" snapshot** for the balance pass (NO-6). Nothing here is tuned — it exists
so a later tuning pass has a control to diff against, and so the diff is against numbers
someone can regenerate rather than numbers someone once quoted.

## Why this is committed and `.scratch/playtest/` is not

`tools/playtest.sh` defaults its output into `.scratch/`, which is scratch by design and
gitignored. A baseline that lives there is a baseline that exists until someone cleans up.
The control for a tuning pass has to outlive the session that produced it, so it lives in
`docs/` beside `playtest-harness-audit.md`, which is the other durable artefact of the same
harness.

## Reproducing a baseline exactly

```sh
./tools/playtest.sh 3 docs/playtest/baseline-2026-09-09.csv
python3 tools/playtest-summary.py docs/playtest/baseline-2026-09-09.csv
```

That is the **whole** command — no flags were overridden and no rows were edited or
dropped afterwards.

**The seeds are 1, 2 and 3.** `playtest.sh` takes a seed *count*, not a seed list, and
loops `for ((s = 1; s <= SEEDS; s++))` passing `--seed $s`. So "3" means seeds 1-3, every
time, on any machine — the sweep is fully deterministic and there is no hidden entropy to
record.

**The grid is 5 tiers x 6 armies x 3 seeds = 90 runs**, and the script owns the tier and
army lists, so a later run picks up any tier or army added since. If that list changes, the
row count changes with it: compare like-for-like on `(tier, army)`, not on totals.

## Two things that make a re-run non-comparable

- **Run it serially, on an idle machine.** The Clock drains on `delta`, so a run under
  contended load is measuring the machine. `playtest.sh` is serial on purpose; do not
  parallelise it and do not run a Godot suite alongside it.
- **The bot is the instrument.** Every number here is `autoplay.gd` playing, so a change to
  the bot's heuristics invalidates the comparison just as thoroughly as a balance change
  does. If `autoplay.gd` moves, take a fresh baseline before tuning against this one.

## Files

| File | What it is |
| --- | --- |
| `baseline-2026-09-09.csv` | 90 raw rows, one per run, columns straight from the game's own `_telemetry_csv()` |
| `baseline-2026-09-09.summary.txt` | `playtest-summary.py` output for that CSV, committed so the headline numbers are readable without re-running anything |

## What stood out (2026-09-09) — observations, not tuning

Recorded so a later pass knows what the control already looked like. **Nothing here was
acted on**; balance tuning is deliberately saved for last.

- **The bot uses its economy now.** `shop_buy` 93%, `convert` 98%, `sell` 49%, and the 26
  resource-starvation deaths hold a median of **0** Gold. That is the fix from issue 103
  landing, and it is what makes this baseline usable where the pre-103 FLAGS table was not:
  those numbers described a bot that refused to spend.
- **`artefact_activate` is the one leverage still barely exercised — 6.7%.** Any conclusion
  about activatable artefacts rests on almost no data, so treat that column as unmeasured
  rather than as evidence they are weak.
- **Old Guard is a huge outlier**: 8 wins + 1 cap out of 15, median wave 51, median score
  **67,900**. Every other army lands 0-1 wins with a median score between 1,300 and 4,000.
  A ~17x spread between armies dwarfs the spread between tiers.
- **Difficulty is not monotonic across tiers.** Tier 1 and Tier 2 are identical on every
  column (2 wins, median wave 19.5, median score 4,150), and Tier 3 outperforms both *and*
  Tier 4. Only Tier 5 separates cleanly (0 wins, median wave 8).
- **Back-row breach is the dominant death** (52 of 90) ahead of resource starvation (26).
- **2 runs outlived the 8,000-step cap** and are counted as `CAP`, not as losses. They are
  also the slow ones: one Tier 4 / Old Guard run held a core busy for ~11 minutes, against
  the 5-30s the harness advertises. Budget wall-clock for outliers, not for the median.
