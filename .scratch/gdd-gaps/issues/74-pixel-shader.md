# 74 — Pixel filter/shader experiment (UI overlay)

Status: spike done (2026-08-31) — works, NOT enabled; needs a call

## Parent

`.scratch/gdd-gaps/PRD.md`

## The ask

Try a pixel filter/shader, **mostly over the UI**.

Explicitly framed by the user as *"I want to test"* — so this is a **spike**, not a
commitment. The deliverable is a screenshot and a recommendation, not a shipped feature.

## Approach

A `CanvasLayer` + `ColorRect` with a shader over the UI, or a `SubViewport` rendering at low
resolution with nearest-neighbour upscale — the second gives true pixelation rather than a
post-effect that only looks like it.

The board is 480x800 portrait, so a downscale factor of 2-3 is the plausible range.

## Two things that will decide whether it survives contact

- **Text legibility.** The HUD carries small labels (10px on the All-Seeing Eye reveal) and
  tabular numbers. Pixelating those is where this either works or obviously does not — and
  it is the first thing to screenshot, not the last.
- **The windowed click probes drive real input at real coordinates.** A `SubViewport`
  approach changes the coordinate space, so probes may need their input remapped. Check
  before going far down that path — an approach that breaks every probe is a bad approach
  regardless of how it looks.

## Acceptance

- Screenshots at the tried factors, including **the small-text case**.
- A recommendation with the probe-compatibility answer.
- Do not merge a half-committed version: either it ships behind a setting, or the branch
  stays open as a reference.

## Blocked by

- nothing

## Outcome — the spike works, and it is off

Shipped **off by default**, reachable only via `--pixel <factor>`. Nothing renders differently
unless someone asks for it, so this cannot regress anything while the decision is open.

### Approach: post-effect, not SubViewport — and that was the right call

A `SubViewport` (render small, upscale nearest-neighbour) gives *truer* pixel art, because the
image is authored at low resolution rather than quantised afterwards. **It was rejected
anyway**: it changes the coordinate space input arrives in, and this project's windowed click
probes drive real input at real coordinates. An approach that breaks every probe is a bad
approach however it looks.

The shader samples the already-composited screen, so coordinates are untouched — the full
suite passes with the filter present, and the probes cannot tell it is there.

### The Godot 4 trap, recorded because it fails silently

Godot 3's built-in `SCREEN_TEXTURE` **does not exist in Godot 4**. It must be declared:

```glsl
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
```

Without it the shader compiles cleanly and renders a **blank white screen with no error** —
which is exactly what the first capture produced. `filter_nearest` is also load-bearing:
without it the blocks are smoothly interpolated and the effect looks like blur, not pixels.

### What it looks like

Screenshots in `74-assets/`: `pixel-off.png`, `pixel-3x.png`, `pixel-5x.png`.

At **3x** the pieces read well — the hand-drawn tokens take on a genuine pixel-art quality, and
the board itself is unchanged (flat colours have nothing to quantise). **Text is where the
cost lands**, exactly as predicted: the HUD's larger labels survive, but the small
`enemy turn...` caption is visibly degraded.

### Recommendation

**Do not ship it over the whole screen.** The board and pieces gain from it; the text loses.
Since the effect is a `CanvasLayer`, it can be scoped to sit **under** the HUD rather than over
it — pixelating the board while leaving every label crisp. That is the version worth trying
next, and it is a small change from here.

Left as a spike rather than a feature, per the issue's own framing.
