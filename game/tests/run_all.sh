#!/bin/sh
# NO-KINGS non-regression suite — run after EVERY feature or code change.
#
#   game/tests/run_all.sh              # full: windowed click probes + headless
#   game/tests/run_all.sh --headless   # skip the windowed probes (CI / no GUI)
#
# Order matters (repo CLAUDE.md): the click probes run FIRST — Godot headless
# drops GUI picking, and the CLI bypasses once green-lit a dead main menu.
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
TIMEOUT="${TIMEOUT:-300}" # per-step cap: a crashed probe must not block forever
fails=""

run() {
	name="$1"; shift
	outfile=$(mktemp)
	"$GODOT" --path . "$@" >"$outfile" 2>&1 &
	pid=$!
	( sleep "$TIMEOUT"; kill "$pid" 2>/dev/null ) &
	watchdog=$!
	wait "$pid"
	code=$?
	kill "$watchdog" 2>/dev/null
	wait "$watchdog" 2>/dev/null
	out=$(cat "$outfile"); rm -f "$outfile"
	if [ "$code" -ne 0 ] || printf '%s' "$out" | grep -q "SCRIPT ERROR"; then
		fails="$fails $name"
		echo "FAIL: $name (exit $code)"
		printf '%s\n' "$out" | grep -i "FAIL\|ERROR" | head -6
	else
		echo "ok: $name"
	fi
}

if [ "${1:-}" != "--headless" ]; then
	run menu-clicks -s tests/test_menu_clicks.gd
	run game-clicks -s tests/test_game_clicks.gd
else
	echo "skipped: click probes (--headless) — run them before merging UI work"
fi

for t in rules save assets waves endless armies scores money items box scenarios; do
	run "test_$t" --headless -s "tests/test_$t.gd"
done

run autoplay --headless -- --autoplay

echo "---"
if [ -z "$fails" ]; then
	echo "ALL GREEN"
else
	echo "FAILED:$fails"
	exit 1
fi
