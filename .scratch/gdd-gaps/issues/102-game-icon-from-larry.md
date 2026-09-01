# 102 — A game icon, generated from Larry

Status: todo (planned 2026-09-01)

## Parent

`.scratch/gdd-gaps/PRD.md` — surfaced by the Android export (issue 86)

## Why

`game/project.godot` has **no `config/icon`**. Godot falls back to its own logo, so every
build — including the debug APK that already builds (86) — ships as a generic Godot app. A
store build cannot go out like that, so this gates 86 alongside the Play Console entry.

## The input is a video, not an image

There is **no Larry image in the repo**. The only Larry asset is:

```
game/assets/video/larry_intro.ogv
```

So the first step is extracting a frame — `ffmpeg -i larry_intro.ogv -vf "select=..." -frames:v 1`
— then picking the one that reads at icon size. That is a real step, not a detail: a frame
chosen for motion looks like a smear at 48x48.

Larry is the **wave-201 King, deliberately parked** (issue 89 ruling — do not build him
unprompted). Using his likeness as the app icon is fine and does not un-park him, but worth
naming so nobody reads the icon as a commitment to ship the character.

## Scope

- Extract a usable frame from `larry_intro.ogv`.
- Produce the icon set: Godot wants a square source (512x512 or 1024x1024) at
  `config/icon`; Android additionally wants adaptive foreground/background layers, and the
  Play Console wants a 512x512 hi-res icon separately from the APK.
- Wire `config/icon` in `project.godot` and the Android export preset.

## Acceptance

- `project.godot` sets `config/icon`; a fresh export shows it rather than the Godot logo.
- **Legible at 48x48** — that is the real bar, not how it looks at full size.
- Source frame and any intermediate art committed, so the icon is regenerable rather than a
  one-off nobody can reproduce.
- `run_all.sh` ALL GREEN, foreground, alone (`test_assets.gd` covers asset pairing rules).

## Blocked by

Nothing — but the frame choice is a taste call and should be shown before the set is built
around it.
