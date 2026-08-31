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

# Fresh worktrees have no .godot/ import cache, and Godot's on-demand import
# races with the first suite's resource loads — intermittently "Failed
# loading resource" on item SVG icons (slice 36). Import synchronously,
# once, up front, so every suite below runs against a warm cache. Cheap/no-op
# on an already-warm cache (a couple of seconds).
echo "importing assets..."
import_log=$(mktemp)
if ! "$GODOT" --headless --path . --import >"$import_log" 2>&1; then
	echo "WARNING: asset import exited non-zero — resource loads below may race a stale cache"
	tail -20 "$import_log"
fi
rm -f "$import_log"

# The windowed click probes (menu-clicks/game-clicks) grab real window focus
# and OS-level click routing, which another running Godot instance can
# steal. Detect that plainly instead of retrying — a retry that hides a
# real intermittent bug is worse than the flake.
other_godot=""
if [ "${1:-}" != "--headless" ]; then
	other_godot=$(pgrep -f '[Gg]odot' 2>/dev/null || true)
	if [ -n "$other_godot" ]; then
		echo "WARNING: other Godot process(es) running (pid:$(printf '%s' "$other_godot" | tr '\n' ' '))"
		echo "WARNING: menu-clicks/game-clicks need an uncontended machine — a failure below may be contention, not a regression. Close other Godot instances and re-run to confirm."
	fi
fi

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

for t in rules save cloud_save assets waves kings endless armies scores history settings gold clock shop \
	items items_tariffs items_buffs items_artefacts_1 items_artefacts_2 items_artefacts_3 items_artefacts_4 \
	box scenarios background tiers intro seed account sync; do
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
