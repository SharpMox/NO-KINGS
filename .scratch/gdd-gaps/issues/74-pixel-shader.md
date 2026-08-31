# 74 — Pixel filter/shader experiment (UI overlay)

Status: todo — EXPERIMENT, timeboxed

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
