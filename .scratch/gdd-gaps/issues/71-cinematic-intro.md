# 71 — Cinematic intro

Status: done — shipped on feat/cinematic-intro-71

## Parent

`.scratch/gdd-gaps/PRD.md`

## The asset

`~/Downloads/LarryIntro.mp4` — 1.3 MB.

## Decided (user, 2026-08-31)

- **Plays at the very start**, every launch.
- **Skippable with clicks** — any click ends it and goes straight to the menu.

## The asset is already converted and committed

`game/assets/video/larry_intro.ogv` — Ogg Theora, 128x228, 11.3s, no audio, **288 KB**
(down from the 1.3 MB MP4; Theora came out smaller here because the source was oddly
high-bitrate for its resolution). Converted with `ffmpeg2theora`, since Homebrew's current
ffmpeg build no longer ships `libtheora`.

**Nothing plays it yet** — that is this slice.

## ⚠️ The probe problem — solve this first, not last

`test_menu_clicks.gd` and `test_game_clicks.gd` boot straight into the menu today. **An
intro in front of it breaks every windowed probe**, which is the suite's only real-input
coverage and has caught bugs headless testing structurally cannot (the six-Family menu
overflow, hours ago).

Do **not** solve this with a timing hack ("wait 12 seconds"), which makes every probe run
slower and flakier — the suite already has one load-sensitive stall on record.

**Use a bypass the probes can set deterministically**: a `GameScript`/settings flag, or the
same `next_config` seam the probes already use, that skips the intro entirely. State clearly
in the PR which mechanism you chose and why the probes cannot race it.

Since the video is **128x228 in a 480x800 window**, also decide how it is presented — letterboxed
at native size, or scaled up. Native-size pixel art scaled 3x with nearest-neighbour filtering
would suit the source; smooth-scaling 128px art to full width will look soft. Show a screenshot.

## Godot notes

Godot 4 plays video through `VideoStreamPlayer`, which handles **Ogg Theora** natively —
**not MP4/H.264**. So the asset needs converting (`ffmpeg -i LarryIntro.mp4 -c:v libtheora
-q:v 7 -c:a libvorbis intro.ogv`), and quality/size after conversion should be checked before
committing to it.

Confirm the converted file's size — Theora is less efficient than H.264, so 1.3 MB in may be
noticeably larger out.

## Acceptance

- Plays at the ruled moment, skippable by any input.
- **The windowed click probes still pass** — whatever gating is added, `test_menu_clicks.gd`
  and `test_game_clicks.gd` must reach the menu. Prefer a settings flag the probes set, over
  timing hacks.
- `run_all.sh` ALL GREEN (`timeout: 600000`, alone).

## Blocked by

- the two decisions above

## Outcome

New `scenes/Intro.tscn` + `scripts/intro.gd`, set as `project.godot`'s
`run/main_scene` (was `Menu.tscn`).

**Probe safety — no bypass flag needed.** Every `tests/test_*.gd`, including
`test_menu_clicks.gd`/`test_game_clicks.gd`, `extends SceneTree` and runs via
`godot -s tests/test_X.gd` — Godot's `-s` flag replaces the engine's main loop
with the script's own `SceneTree` and never loads `run/main_scene` at all. Both
click probes instantiate `Menu.tscn` directly (`load(...).instantiate();
root.add_child(menu)`), so `Intro.tscn` is structurally unreachable from them —
not raced-and-usually-winning, but never on their code path in the first
place. Confirmed by running `game/tests/run_all.sh` twice in a row (`timeout:
600000`, `menu-clicks`/`game-clicks` both green both times) despite two other
Godot processes running concurrently on the machine (other agents' sessions —
`run_all.sh`'s own contention check warned but didn't block).

The one real launch mode that *does* go through `main_scene` without wanting
the intro is the existing CLI bypasses — `--autoplay`, `--scenario`,
`--screenshot` (the same three `menu.gd` already special-cases, including
`run_all.sh`'s own final `autoplay` step, which boots with no `-s` flag).
`intro.gd` extracts a static `should_bypass(args)` predicate and skips straight
to `Menu.tscn` when any of those are present — unit-tested headless in the new
`tests/test_intro.gd`.

**Presentation**: 128×228 source, nearest-neighbour 3× (384×684), letterboxed
and centered in the 480×800 canvas — smooth-scaling would have gone soft.
Screenshot attached to the PR.

**Edge cases**:
- Natural end: the video's `finished` signal fires reliably (verified
  headless, fired at ~11.6s against an 11.3s clip) and hands off to the Menu —
  it does not hang on the last frame.
- First-frame click: a synthetic click on the very first rendered frame
  advances cleanly with no crash, verified windowed. An `_advanced` guard
  makes `_advance()` idempotent so the `finished` signal and a click can never
  double-fire a scene change, whichever lands first.

**New test**: `tests/test_intro.gd` (headless, added to `run_all.sh`) covers
`should_bypass()` for all three CLI flags plus a control case, and the
idempotent-advance guard via two direct `_advance()` calls. It does not probe
real click routing — this repo's own click-probe headers already document that
headless Godot drops GUI picking, and since the intro is deliberately
unreachable from the two existing windowed probes, a third windowed suite
would only re-prove `_gui_input` fires (verified manually instead, see above)
at real window-boot cost, for coverage the cheaper headless guard test already
gives.
