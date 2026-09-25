#!/bin/sh
# NO-KINGS non-regression suite. When to run what (repo CLAUDE.md, 2026-09-24):
# design iteration / docs-only — no suite; PR ready with a UI change — --only
# the suites covering it; rules/economy/autoplay change — full run before merge;
# before merge — ONE full run on the combined batch of ready PRs, not per PR.
#
#   game/tests/run_all.sh              # full: windowed click probes + headless
#   game/tests/run_all.sh --headless   # skip the windowed probes (CI / no GUI)
#   game/tests/run_all.sh --only board_draw,game-clicks   # just these (run names;
#                                      # bare <t> = test_<t>); unknown name -> exit 2
#
# Order matters (repo CLAUDE.md): the click probes run FIRST — Godot headless
# drops GUI picking, and the CLI bypasses once green-lit a dead main menu.
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
# NO-192: 300 -> 600. test_scenarios is genuinely 190-250s on Main and
# exceeded 300s on Aux (killed, exit 143); it passed at 600s. Per-step cap: a
# crashed probe must not block forever, but a hung run is still bounded.
TIMEOUT="${TIMEOUT:-600}"
fails=""
ran=0

# Every probe that simulates input runs on GAME time: --fixed-fps 60 makes
# each frame's process delta exactly 1/60 s however long the frame really
# took (Godot 4.7 main_timer_sync.cpp:433), and SceneTreeTimers, Tweens, the
# Clock and Tuning.now_ms() all advance by that delta. So a double-tap window,
# a long-press hold or a slide is N frames on a fast Mac and a loaded CI runner
# alike. It also skips the engine's frame-pacing sleep (main.cpp:5166), so the
# probes run as fast as frames render; --disable-vsync is NOT needed — vsync
# only throttles wall-clock speed, never the delta. The headless suites keep
# real time: nothing in them races a time window, and uncapped headless frames
# would turn their in-test watchdogs (create_timer(120)) into seconds of wall.
FIXED="--fixed-fps 60"

WINDOWED="menu-clicks game-clicks game-clicks-notch touch-scroll long-press"
HEADLESS_TESTS="rules save cloud_save assets waves kings endless armies scores history settings gold clock shop \
	items items_king_abilities items_buffs items_artefacts_1 items_artefacts_2 items_artefacts_3 items_artefacts_4 \
	box combos scenarios background tiers intro seed account sync leaderboard drive drive_type back_button \
	menu_continue menu_keyboard sign_in board_draw bomb_highlight mass en_passant banners ads capture_paths theme"

headless=""
only=""
while [ $# -gt 0 ]; do
	case "$1" in
		--headless) headless=1 ;;
		--only) only="${2:-}"; [ -n "$only" ] || { echo "--only needs a comma-list"; exit 2; }; shift ;;
		*) echo "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

# --only: normalise to ",name,name," so want() is one case match. A name that
# matches no suite exits 2 — a filter that runs nothing must never say ALL GREEN.
if [ -n "$only" ]; then
	known=" $WINDOWED test_game_time test_launch_bypass autoplay"
	for t in $HEADLESS_TESTS; do known="$known test_$t"; done
	known="$known "
	norm=","; unknown=""
	for n in $(printf '%s' "$only" | tr ',' ' '); do
		case "$known" in
			*" $n "*) norm="$norm$n," ;;
			*" test_$n "*) norm="${norm}test_$n," ;;
			*) unknown="$unknown $n" ;;
		esac
	done
	if [ -n "$unknown" ]; then
		echo "unknown suite(s):$unknown"
		echo "known:$known"
		exit 2
	fi
	only="$norm"
fi
want() {
	[ -z "$only" ] && return 0
	case "$only" in *",$1,"*) return 0 ;; esac
	return 1
}

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

# Every tracked script needs its committed .uid sidecar. Godot writes one on
# import, but since 2026-09-19 scripts are written on a machine that never runs
# Godot, so the sidecar only appears on the machine that runs this suite —
# which never commits. List what's missing with the value Godot just generated,
# so whoever reads this can commit those exact lines.
missing_uids=""
for f in $(git ls-files '*.gd' | grep -v '^addons/'); do
	git ls-files --error-unmatch "$f.uid" >/dev/null 2>&1 || missing_uids="$missing_uids $f.uid"
done
if [ -n "$missing_uids" ]; then
	fails="$fails uid-sidecars"
	echo "FAIL: uid-sidecars — scripts with no committed .uid; commit these as-is (game/<path>):"
	for u in $missing_uids; do
		echo "  $u: $(cat "$u" 2>/dev/null || echo '(not generated)')"
	done
fi

# The windowed click probes (menu-clicks/game-clicks) grab real window focus
# and OS-level click routing, which another running Godot instance can
# steal. Detect that plainly instead of retrying — a retry that hides a
# real intermittent bug is worse than the flake.
other_godot=""
if [ -z "$headless" ]; then
	# Match the process NAME, not the command line: -f matched any process whose
	# args merely mention Godot, so `GODOT=~/Applications/Godot.app/...` in a
	# wrapper's own command line tripped this warning with no Godot running.
	other_godot=$(pgrep -ix godot 2>/dev/null || true)
	if [ -n "$other_godot" ]; then
		echo "WARNING: other Godot process(es) running (pid:$(printf '%s' "$other_godot" | tr '\n' ' '))"
		echo "WARNING: menu-clicks/game-clicks need an uncontended machine — a failure below may be contention, not a regression. Close other Godot instances and re-run to confirm."
	fi
fi

run() {
	name="$1"; shift
	ran=$((ran + 1))
	outfile=$(mktemp)
	"$GODOT" --path . "$@" >"$outfile" 2>&1 &
	pid=$!
	# </dev/null >/dev/null: the orphaned sleep must not inherit our stdout, or a
	# caller reading us through a pipe blocks until it expires (up to TIMEOUT).
	( sleep "$TIMEOUT"; kill "$pid" 2>/dev/null ) </dev/null >/dev/null 2>&1 &
	watchdog=$!
	# A script that fails to parse leaves Godot idle rather than exiting, so
	# without this the suite burns the whole TIMEOUT (x every suite: ~40 min in
	# CI). Poll the log; on the first "Parse Error", kill Godot and fail now.
	parse_error=""
	while kill -0 "$pid" 2>/dev/null; do
		if grep -q "Parse Error" "$outfile"; then
			parse_error=1; kill "$pid" 2>/dev/null; break
		fi
		sleep 1
	done
	wait "$pid"
	code=$?
	[ -n "$parse_error" ] && [ "$code" -eq 0 ] && code=1
	kill "$watchdog" 2>/dev/null
	wait "$watchdog" 2>/dev/null
	out=$(cat "$outfile")
	if [ "$code" -ne 0 ] || printf '%s' "$out" | grep -q "SCRIPT ERROR\|Parse Error"; then
		fails="$fails $name"
		echo "FAIL: $name (exit $code) — full log kept at $outfile"
		printf '%s\n' "$out" | grep -i "FAIL\|ERROR" | head -6
	else
		echo "ok: $name"; rm -f "$outfile"
	fi
}

if [ -z "$headless" ]; then
	want menu-clicks && run menu-clicks $FIXED -s tests/test_menu_clicks.gd
	want game-clicks && run game-clicks $FIXED -s tests/test_game_clicks.gd
	# NO-57: same probe, with a notch inset — the Header must still lay out
	# below it, not just on the un-notched 0px case above.
	want game-clicks-notch && run game-clicks-notch $FIXED -s tests/test_game_clicks.gd -- --safe-top 56
	# Touch-drag probe. ScrollContainer only drag-scrolls when the DisplayServer
	# reports a touchscreen, which a desktop does only under this project
	# setting — and Input has no runtime setter for it, so it goes through
	# override.cfg for exactly this one run. The trap removes the file however
	# the run ends: left behind, every later mouse click would also be a touch.
	printf '[input_devices]\npointing/emulate_touch_from_mouse=true\n' > override.cfg
	trap 'rm -f override.cfg' EXIT
	want touch-scroll && run touch-scroll $FIXED -s tests/test_touch_scroll.gd
	want long-press && run long-press $FIXED -s tests/test_long_press.gd # NO-72: same override, same reason
	rm -f override.cfg
else
	echo "skipped: click probes (--headless) — run them before merging UI work"
	for n in $WINDOWED; do
		[ -n "$only" ] && want "$n" && echo "skipped: $n (in --only, but --headless)"
	done
fi

# NOTE: tests/repro_no45.gd is GONE (NO-45 is fixed). It was deliberately red
# while the bug was live and kept out of this list for that reason — a suite
# entry expected to be red teaches everyone to ignore red. Now that it is green
# the same checks live in tests/test_touch_scroll.gd above, which is the one
# suite this script already wraps in the touch-emulation override.
for t in $HEADLESS_TESTS; do
	want "test_$t" && run "test_$t" --headless -s "tests/test_$t.gd"
done

# test_game_time proves a double tap is N frames, not N ms: it needs the flag.
want test_game_time && run test_game_time --headless $FIXED -s tests/test_game_time.gd

# NO-77: needs the real flag on the command line, so it sits outside the loop.
want test_launch_bypass && run test_launch_bypass --headless -s tests/test_launch_bypass.gd -- --scenario 0

want autoplay && run autoplay --headless -- --autoplay

echo "---"
if [ "$ran" -eq 0 ]; then
	echo "FAILED: no suite ran (--only matched only skipped suites)"
	exit 2
elif [ -z "$fails" ]; then
	echo "ALL GREEN"
else
	echo "FAILED:$fails"
	exit 1
fi
