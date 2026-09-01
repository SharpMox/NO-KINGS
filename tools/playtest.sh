#!/usr/bin/env bash
# issue 103: run the bot many times and collect one CSV row per run.
#
# Every balance number this project has ever quoted came from `autoplay.gd`, so
# what the bot can and cannot do IS the measurement. This script exists to make
# that measurable rather than assumed: each row carries the leverage counters,
# and a leverage the bot never touches shows up as a column of zeros.
#
#   tools/playtest.sh [seeds] [out.csv]
#
# Cost: ~5-30s per run, ZERO tokens — this is GDScript, no model in the loop.
# That is a hard rule for this harness, not an implementation detail: an agent
# may read the aggregate, never play the game.
#
# SERIAL ON PURPOSE. The Clock drains on `delta` (game.gd), so a run under
# contended load is not comparable to one run on an idle machine. Parallelising
# would make the batch faster and the numbers meaningless — the same
# load-sensitivity that produced a confident, wrong flake conclusion on
# 2026-08-29 (see CLAUDE.md's interleaving rule).
set -uo pipefail
cd "$(dirname "$0")/.."

SEEDS=${1:-3}
OUT=${2:-.scratch/playtest/run-$(date +%Y%m%d-%H%M%S).csv}
TIERS=("Tier 1" "Tier 2" "Tier 3" "Tier 4" "Tier 5")
ARMIES=("Crown" "Wild Hunt" "Old Guard" "Syndicate" "Cult" "Horde")

mkdir -p "$(dirname "$OUT")"
# The header comes from the game itself, so the columns can never drift out of
# sync with what _telemetry_csv() actually emits.
godot --headless --path game -s tests/print_telemetry_header.gd 2>/dev/null \
  | grep '^PLAYTEST,' | sed 's/^PLAYTEST,//' > "$OUT"

total=$(( ${#TIERS[@]} * ${#ARMIES[@]} * SEEDS ))
n=0
for tier in "${TIERS[@]}"; do
  for army in "${ARMIES[@]}"; do
    for ((s = 1; s <= SEEDS; s++)); do
      n=$((n + 1))
      printf '[%3d/%3d] %-7s %-10s seed %d ... ' "$n" "$total" "$tier" "$army" "$s"
      row=$(godot --headless --path game -- \
              --autoplay --tier "$tier" --army "$army" --seed "$s" --steps 8000 2>/dev/null \
            | grep '^PLAYTEST,' | head -1 | sed 's/^PLAYTEST,//')
      if [ -z "$row" ]; then
        echo "NO ROW (run produced no telemetry)"
        continue
      fi
      echo "$row" >> "$OUT"
      echo "$row" | cut -d, -f1-4 | tr ',' ' '
    done
  done
done

echo "---"
echo "wrote $OUT ($(($(wc -l < "$OUT") - 1)) runs)"
echo "summarise with:  python3 tools/playtest-summary.py $OUT"
