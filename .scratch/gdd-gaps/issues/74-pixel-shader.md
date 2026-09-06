# 74 — Pixel filter/shader experiment (UI overlay)

Status: done (2026-08-31) — every quantising approach rejected; **hard-edged text shipped
instead**, and the shader deleted. See the final Outcome at the bottom.

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

(Screenshots deleted 2026-09-06 — the written findings below are the record.)

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

---

## FINAL Outcome (2026-08-31) — the filter is deleted; hard-edged text shipped

The recommendation above ("scope it to the board, under the HUD") was overtaken: the user's
call was the opposite — **the filter goes on the menus, and art dodges it entirely**, because
the piece tokens are already painted pixel art and quantising them distorts rather than
stylises. The filter shipped on menus at 3x, and was then rejected on sight.

### Every quantising approach was tried and rejected

| Approach | Result | Why it failed |
| --- | --- | --- |
| Full-screen post-effect, 3x | roughened edges only | quantising something already drawn at full resolution |
| SubViewport downscale, AA on | *"looks blurry, not a good pixelated effect"* (user) | magnified font antialiasing, not pixels |
| SubViewport downscale, AA off, 3x | genuine hard pixels, **small text broken** | a vector font has too little grid at 8px — "Settings" rendered as *Sellings* |
| Same at 2x | moderate effect, text legible | still a degraded letterform, not a designed one |
| Same at 1x | crisp text, no distortion | **chosen** — see below |

(Screenshots for all of it were deleted 2026-09-06. The comparison table above is the
record — it was always the part that carried the reasoning.)

### The diagnosis worth keeping

**The blur was font antialiasing, not resolution.** Godot antialiases fonts by default, so
rendering at 1/N and upscaling nearest-neighbour turns every soft grey edge pixel into an
NxN grey blob. That reads as blur no matter what the shader does — which is why the
post-effect and the SubViewport failed the same way despite being different techniques.

Underneath that sits the real ceiling: **a downscaled-then-upscaled vector font is a damaged
letterform, not a designed one.** No factor fixes it, because the tradeoff runs one
direction the whole way — more pixel look, less legibility. A pixel/bitmap font (glyphs
authored to sit on the grid at 8px) is the only thing that gives both, and that is an asset
decision, not a code one. **Recorded here so it is not rediscovered:** if a retro UI is
wanted later, start by importing a pixel font, not by writing another shader.

### What actually shipped

`Settings._crisp_text()` — turn font antialiasing OFF project-wide
(`FONT_ANTIALIASING_NONE` + `SUBPIXEL_POSITIONING_DISABLED` + `HINTING_NONE` on a duplicate
of `ThemeDB.fallback_font`, reassigned to the fallback so it reaches every Control with no
per-scene wiring; guarded so it no-ops after the first boot). It rides on `Settings.apply()`,
which both `menu.gd` and `game.gd` already call once at every boot.

That is the 1x row of the table: **native resolution, no downscale, no shader.** It touches
only glyph rasterisation, so it satisfies the requirement every filter kept failing —
**the painted tokens are left exactly as drawn** — with no CanvasLayer ordering contortion
and no coordinate-space shift for the windowed click probes.

It is project-wide rather than menu-only (the game HUD gets it too), so the HUD's text sits
with the pixel-art tokens instead of contrasting with them. Not gated behind a Settings
toggle — it is a look, not a preference; add one if it turns out to be contentious.

**Deleted:** `game/scripts/pixel_filter.gd`, `game/shaders/pixelate.gdshader`, the `--pixel`
CLI flag and both call sites. At 1x a pixelate pass is arithmetically the identity, so
keeping the shader would have been dead code with a config knob on it.

`game/tests/run_all.sh` — **ALL GREEN** (foreground, alone). No test changed: the effect is
purely visual and the probes were never sensitive to it.

---

## CORRECTION (2026-08-31) — the first version shipped as a no-op

**PR #267's `_crisp_text()` changed no pixels.** It hardened `ThemeDB.fallback_font`, which is
only consulted when nothing else supplies a font — and `ThemeDB.get_default_theme()` supplies
one. Every Control resolved the default theme's font, still antialiased.

Caught by looking at a fresh `--screenshot` capture and noticing the title still had soft grey
edges, then asking a live Label what it actually resolves:

```
fallback_font AA after apply(): 0     <- the property was set
default theme has its own font: true
what a Label RESOLVES:          AA=1  <- ...and nothing read it
```

**Why the tests missed it:** there were none for it, and the obvious one would not have helped.
An assertion that reads back `ThemeDB.fallback_font.antialiasing` passes against the broken
version — it confirms the write, not the effect. The only assertion that can fail here is one
that asks a **live Control** what it resolves.

**Fixed**: both slots are hardened (`theme.default_font` and `ThemeDB.fallback_font`), via a
shared `_hardened()` helper. `test_settings.gd` gained two assertions that construct a real
Label and Button and check `get_theme_font("font")`. **Proven to catch the defect**: stubbing
out the `theme.default_font` line makes both fail; with the fix they pass.

Shipped result: the 1x look the user approved, now actually rendering. (The screenshot that
recorded it was deleted 2026-09-06 — the shipped build is the reference now, which is the
better source anyway: a screenshot of an approved look goes stale the moment the UI moves,
and the HUD was rebuilt by issue 106 two weeks later.)
