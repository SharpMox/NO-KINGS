# 71 — Cinematic intro

Status: todo — NEEDS TWO DECISIONS

## Parent

`.scratch/gdd-gaps/PRD.md`

## The asset

`~/Downloads/LarryIntro.mp4` — 1.3 MB.

## What has to be decided first

1. **When does it play?** Options: on first launch only (stored in settings), every launch
   with a skip, or from a menu entry. First-launch-only is the usual answer for a 1.3 MB
   intro; every-launch needs a skip on the first frame or it becomes an obstacle.
2. **Does it block the menu?** If it plays on launch it must be skippable by any input, and
   the click probes need to know how to get past it or **every windowed probe breaks** —
   `test_menu_clicks.gd` boots straight into the menu today.

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
