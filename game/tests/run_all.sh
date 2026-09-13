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
	# </dev/null >/dev/null: the orphaned sleep must not inherit our stdout, or a
	# caller reading us through a pipe blocks until it expires (up to TIMEOUT).
	( sleep "$TIMEOUT"; kill "$pid" 2>/dev/null ) </dev/null >/dev/null 2>&1 &
	watchdog=$!
	wait "$pid"
	code=$?
	kill "$watchdog" 2>/dev/null
	wait "$watchdog" 2>/dev/null
	out=$(cat "$outfile")
	if [ "$code" -ne 0 ] || printf '%s' "$out" | grep -q "SCRIPT ERROR"; then
		fails="$fails $name"
		echo "FAIL: $name (exit $code) — full log kept at $outfile"
		printf '%s\n' "$out" | grep -i "FAIL\|ERROR" | head -6
	else
		echo "ok: $name"; rm -f "$outfile"
	fi
}

if [ "${1:-}" != "--headless" ]; then
	run menu-clicks -s tests/test_menu_clicks.gd
	run game-clicks -s tests/test_game_clicks.gd
	# Touch-drag probe. ScrollContainer only drag-scrolls when the DisplayServer
	# reports a touchscreen, which a desktop does only under this project
	# setting — and Input has no runtime setter for it, so it goes through
	# override.cfg for exactly this one run. The trap removes the file however
	# the run ends: left behind, every later mouse click would also be a touch.
	printf '[input_devices]\npointing/emulate_touch_from_mouse=true\n' > override.cfg
	trap 'rm -f override.cfg' EXIT
	run touch-scroll -s tests/test_touch_scroll.gd
	run long-press -s tests/test_long_press.gd # NO-72: same override, same reason
	rm -f override.cfg
else
	echo "skipped: click probes (--headless) — run them before merging UI work"
fi

# NOTE: tests/repro_no45.gd is GONE (NO-45 is fixed). It was deliberately red
# while the bug was live and kept out of this list for that reason — a suite
# entry expected to be red teaches everyone to ignore red. Now that it is green
# the same checks live in tests/test_touch_scroll.gd above, which is the one
# suite this script already wraps in the touch-emulation override.
for t in rules save cloud_save assets waves kings endless armies scores history settings gold clock shop \
	items items_king_abilities items_buffs items_artefacts_1 items_artefacts_2 items_artefacts_3 items_artefacts_4 \
	box combos scenarios background tiers intro seed account sync leaderboard drive back_button; do
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
