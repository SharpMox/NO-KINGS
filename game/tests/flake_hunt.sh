#!/bin/sh
# issue 88: hunt the intermittent click-probe failure.
#
#   game/tests/flake_hunt.sh [runs]     # default 40 of each probe, interleaved
#
# Why this exists rather than a hand-typed loop: at a rate around 1-in-20, a
# failure that is observed and then discarded is expensive to reproduce again.
# This keeps the FULL OUTPUT of every failing run, which is the thing the last
# hunt did not have and could not reconstruct.
#
# Two rules from CLAUDE.md are baked in, because both have already produced a
# confidently wrong conclusion in this repo:
#
#   1. RUN ALONE. The probes are windowed and fight over focus. A failure
#      during a concurrent run is not evidence of a bug — and a pass during one
#      is not evidence of correctness either.
#   2. INTERLEAVE, never batch. Comparing 20 runs of A then 20 of B measures
#      machine load, not the thing under test. The two probes alternate here so
#      any comparison between them sees identical conditions.
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
RUNS="${1:-40}"
OUT="${OUT:-/tmp/flake-hunt}"

other=$(pgrep -f '[Gg]odot' 2>/dev/null || true)
if [ -n "$other" ]; then
	echo "REFUSING TO RUN: another Godot process is up (pid:$(printf '%s' "$other" | tr '\n' ' '))"
	echo "That includes an idle EDITOR window, which is the usual culprit — close it."
	echo "The probes need an uncontended machine. This refuses rather than warns"
	echo "(as run_all.sh does) because a hunt's whole output is its pass/fail RATE,"
	echo "and a rate measured under contention is not a rate for anything."
	exit 2
fi

rm -rf "$OUT"; mkdir -p "$OUT"
pass=0; fail=0
i=1
while [ "$i" -le "$RUNS" ]; do
	for probe in game menu; do
		out=$("$GODOT" --path . -s "tests/test_${probe}_clicks.gd" 2>&1)
		if printf '%s' "$out" | grep -qE "ALL (GAME|MENU) CLICKS OK"; then
			pass=$((pass + 1))
		else
			fail=$((fail + 1))
			printf '%s' "$out" > "$OUT/${probe}_run${i}.log"
			echo "FAIL: ${probe}-clicks run $i  ->  $OUT/${probe}_run${i}.log"
			printf '%s' "$out" | grep -E "^(FAIL|ERROR)" | head -5
		fi
	done
	i=$((i + 1))
done
echo "---"
echo "pass=$pass fail=$fail  (failing output in $OUT)"
[ "$fail" -eq 0 ] && echo "NO FAILURES — see issue 88 for what a zero result does and does not prove"
exit 0
