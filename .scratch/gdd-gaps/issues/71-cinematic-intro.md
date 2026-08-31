# 71 — Cinematic intro

Status: todo — SPECCED (user rulings 2026-08-31) · ready

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
