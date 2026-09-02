#!/usr/bin/env python3
"""issue 103: summarise a playtest CSV.

Two questions, in this order:

  1. IS THE BOT USING ITS LEVERAGES? A leverage with a zero usage rate means
     every number below it describes a bot that refuses to use that tool, not a
     property of the game. This block comes first on purpose — the balance table
     underneath is only trustworthy once it is clean.

  2. How does the game behave per tier / per army?

Usage:  python3 tools/playtest-summary.py <run.csv>
"""
import csv
import statistics
import sys
from collections import defaultdict

LEVERAGES = [
    "shop_open", "shop_buy", "sell", "convert", "item_use",
    "artefact_activate", "army_ability", "merge", "deploy",
    "buff_apply", "capture",
]

# `shop_open` counts the PANEL being opened. The bot buys through Shop.buy —
# the same function the panel calls — because autoplay deliberately avoids
# modals, so this column reads 0 even when the bot is shopping heavily. It is
# a UI counter, not an economy one, and flagging it as "never used" would be a
# false alarm that trains the reader to ignore the alarm that matters.
UI_ONLY = {"shop_open"}


def main(path: str) -> int:
    with open(path) as fh:
        rows = list(csv.DictReader(fh))
    if not rows:
        print("no rows in %s" % path)
        return 1
    for r in rows:
        for k in ("wave", "score", "turns", "gold_left", *LEVERAGES):
            r[k] = int(r[k])

    caps = sum(1 for r in rows if r["result"] == "CAP")
    print("%d runs from %s%s\n" % (len(rows), path,
          "  (%d outlived the step cap — unresolved, not losses)" % caps if caps else ""))

    print("LEVERAGE USE  (runs that used it at all / total, and the median when used)")
    unused = []
    for lev in LEVERAGES:
        used = [r[lev] for r in rows if r[lev] > 0]
        pct = 100.0 * len(used) / len(rows)
        med = statistics.median(used) if used else 0
        flag = ""
        if not used:
            if lev in UI_ONLY:
                flag = "   (UI counter — bot buys via Shop.buy, not the panel)"
            else:
                flag = "   <-- NEVER USED"
                unused.append(lev)
        print("  %-18s %5.1f%%  median %6.0f%s" % (lev, pct, med, flag))

    # Unspent Gold at death is the sharpest single tell: a bot that dies of
    # resource starvation while holding Gold has not run out of resources, it
    # has run out of ideas.
    starved = [r for r in rows if "starv" in r["reason"].lower()]
    if starved:
        gold = [r["gold_left"] for r in starved]
        print("\n  %d runs died of resource starvation, holding a median of %.0f Gold"
              % (len(starved), statistics.median(gold)))
    print("  median Gold unspent at run end, all runs: %.0f"
          % statistics.median([r["gold_left"] for r in rows]))

    if unused:
        print("\n  !! %d leverage(s) never used in ANY run: %s"
              % (len(unused), ", ".join(unused)))
        print("     Treat the table below as a floor, not as the game's difficulty.")

    for key in ("tier", "army"):
        print("\nBY %s" % key.upper())
        groups = defaultdict(list)
        for r in rows:
            groups[r[key]].append(r)
        print("  %-11s %5s %7s %11s %11s" % (key, "runs", "wins", "median wave", "median score"))
        for name in sorted(groups):
            g = groups[name]
            wins = sum(1 for r in g if r["result"] == "WIN")
            caps = sum(1 for r in g if r["result"] == "CAP")
            print("  %-11s %5d %7s %11.1f %11.0f" % (
                name, len(g), "%d%s" % (wins, "+%dc" % caps if caps else ""),
                statistics.median([r["wave"] for r in g]),
                statistics.median([r["score"] for r in g]),
            ))

    print("\nHOW RUNS END")
    reasons = defaultdict(int)
    for r in rows:
        reasons[(r["result"], r["reason"])] += 1
    for (res, reason), n in sorted(reasons.items(), key=lambda kv: -kv[1]):
        print("  %-5s %-32s %d" % (res, reason[:32], n))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1]))
