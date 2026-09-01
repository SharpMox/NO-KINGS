# 102 — A game icon, generated from Larry

Status: todo (planned 2026-09-01)

## Parent

`.scratch/gdd-gaps/PRD.md` — surfaced by the Android export (issue 86)

## Why

`game/project.godot` has **no `config/icon`**. Godot falls back to its own logo, so every
build — including the debug APK that already builds (86) — ships as a generic Godot app. A
store build cannot go out like that, so this gates 86 alongside the Play Console entry.

## The source (user supplied 2026-09-01)

`~/Downloads/Larry.png` — **1016x1016, RGBA**. No frame extraction needed; the earlier plan
to pull a still from `game/assets/video/larry_intro.ogv` is dropped.

Inspected: pixel-art demon face, purple horns, white slash eyes, a green grin, on a
transparent/black field. Centred, high contrast, simple silhouette — it should stay legible at
48x48, which is the bar that matters.

**Three properties that dictate the work:**

1. **It is pixel art.** Resize with **nearest-neighbour**, never bilinear/Lanczos — smooth
   scaling turns crisp pixel edges into mush. 1016 is also not a power of two, so going to
   512 is a 0.504 factor; prefer scaling to 508 (exact 1/2) and padding, or re-render at
   512 rather than resampling at an awkward ratio.
2. **The subject is dark on transparency.** On a dark launcher background it will largely
   disappear. The Android **adaptive** icon needs an explicit background layer, not
   transparency — pick a colour from the art (the purple or the green) rather than leaving it
   to the launcher.
3. **Safe zone.** Android adaptive icons crop to a circle/squircle; the horns reach high in
   the frame and will be clipped unless the art is inset into the 66% safe zone.

Larry is the **wave-201 King, deliberately parked** (issue 89 ruling — do not build him
unprompted). Using his likeness as the app icon does not un-park him, but worth naming so
nobody reads the icon as a commitment to ship the character.

## Scope

- Commit the source `Larry.png` into the repo (it currently lives only in `~/Downloads`, i.e.
  outside version control — the icon must be regenerable).
- Produce the icon set: Godot wants a square source at `config/icon`; Android additionally
  wants adaptive foreground/background layers, and the Play Console wants a 512x512 hi-res
  icon separately from the APK.
- Wire `config/icon` in `project.godot` and the Android export preset.

## Acceptance

- `project.godot` sets `config/icon`; a fresh export shows it rather than the Godot logo.
- **Legible at 48x48** — that is the real bar, not how it looks at full size.
- Nearest-neighbour scaling only; no soft edges on the pixel art.
- The adaptive icon survives a circular crop with the horns intact.
- Source art committed, so the icon is regenerable rather than a one-off nobody can reproduce.
- `run_all.sh` ALL GREEN, foreground, alone (`test_assets.gd` covers asset pairing rules).

## Blocked by

Nothing.

## Adjacent, not in scope

`~/Downloads/KingChessPiece.png` (280x280) also exists. FLAGS has a standing item that the
**King is the last piece on the monochrome-SVG fallback path** and needs
`king-light.png` + `king-dark.png` — dropping those in switches it over with zero code
change. Different slice, but the art may already be in hand.
