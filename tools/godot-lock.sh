#!/bin/sh
# Serialise Godot runs across sessions and agents on this machine.
#
#   tools/godot-lock.sh game/tests/run_all.sh
#   tools/godot-lock.sh godot --path game -s tests/test_menu_clicks.gd
#
# Exits with the wrapped command's status. Three things this gets right that
# the inline mkdir/rmdir pair did not:
#
#   1. THE TRAP. An interrupted or killed run never reaches its own rmdir, so
#      the plain shape leaves the lock held with no process alive to clear it.
#      Measured 2026-09-18: a user interrupt and a harness kill both deliver
#      SIGTERM. It happened for real on 2026-09-17 at 18:01:44.
#   2. THE CHILD RUNS IN THE BACKGROUND, and we block in `wait` instead of in
#      the command itself. This is not a style choice. A trap does NOT run
#      while the shell is blocked on a FOREGROUND child — bash defers it until
#      the child exits, so a `kill -TERM` at the wrapper released the lock only
#      28 s later, when the wrapped sleep finished on its own (measured
#      2026-09-18, and the reason the first version of this script failed its
#      own test). `wait` is interruptible, so the handler runs at once however
#      the signal is delivered: process-group kill, single-pid kill, or Ctrl-C.
#   3. THE PID. A trap cannot catch SIGKILL, power loss or a session dying
#      outright, so an orphan is still possible. Recording the holder's pid
#      lets the NEXT contender prove the holder is dead before clearing it —
#      the only safe way to break "only the holder removes it".
#
# STDIN: `"$@" &` in a POSIX shell redirects the child's stdin from /dev/null.
# Nothing in run_all.sh reads stdin so it does not bite us, but a direct call
# and a wrapped call differ here — the next person wrapping something
# interactive will meet it. Verified 2026-09-18 that the windowed click probes
# are unaffected: a non-interactive shell has no job control, so the child is
# not moved to another terminal group and its window, focus and input path are
# unchanged.
#
# KNOWN LIMIT, measured 2026-09-18: if this script is itself launched with `&`
# from a non-interactive shell, SIGINT is pre-set to IGNORED for asynchronous
# jobs and a later `trap ... INT` cannot re-enable it — so a `kill -INT` at the
# wrapper does nothing until the child ends by itself. SIGTERM has no such rule
# and works (1 s, measured). This costs us nothing in practice: a user
# interrupt and a harness kill both deliver TERM on both machines (measured
# twice, 2026-09-18). The INT trap is kept for a real foreground Ctrl-C, where
# the signal is not pre-ignored.
#
# Deliberately a script and not a snippet: the correct sequence has three
# subtleties, and every caller copying it by hand is a caller who can get one
# of them wrong.
set -u

LOCK=/tmp/nokings-godot.lock
WAIT=${GODOT_LOCK_WAIT:-30}     # seconds between attempts; tests override it
TRIES=${GODOT_LOCK_TRIES:-0}    # 0 = wait forever, N = give up after N tries

[ $# -gt 0 ] || { echo "usage: $0 <command> [args...]" >&2; exit 64; }

attempt=0
while ! mkdir "$LOCK" 2>/dev/null; do
	attempt=$((attempt + 1))
	holder=$(cat "$LOCK/pid" 2>/dev/null || true)

	# An EMPTY or missing pid file is NOT staleness: the holder may have won
	# the mkdir microseconds ago and not written it yet. Only a pid we can
	# prove is dead earns a clear.
	if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
		echo "godot-lock: holder pid $holder is dead — clearing stale lock" >&2
		rm -f "$LOCK/pid"
		rmdir "$LOCK" 2>/dev/null || true
		continue
	fi

	if [ "$TRIES" -gt 0 ] && [ "$attempt" -ge "$TRIES" ]; then
		echo "godot-lock: still held by pid ${holder:-unknown} after $attempt tries" >&2
		exit 75
	fi
	sleep "$WAIT"
done

# The directory is the lock (mkdir is the atomic operation); the pid file is
# only evidence about its holder.
echo $$ > "$LOCK/pid"

child=""
release() {
	# Take the Godot process down with us, or it keeps the display and the
	# next holder inherits a running game rather than a free machine.
	[ -n "$child" ] && kill -TERM "$child" 2>/dev/null
	rm -f "$LOCK/pid"
	rmdir "$LOCK" 2>/dev/null || true
}
trap 'release; exit 130' INT
trap 'release; exit 143' TERM
trap 'release; exit 129' HUP
trap 'release' EXIT

"$@" &
child=$!
wait "$child"
rc=$?

child=""        # it is gone; do not signal a recycled pid from the EXIT trap
release
trap - EXIT
exit $rc
