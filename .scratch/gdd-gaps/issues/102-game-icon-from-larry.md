# 102 — A game icon, generated from Larry

Status: done (2026-09-01)

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
   transparency.

   **RULED (user, 2026-09-01): purple background.** Sampled palette, by share of the image:

   | Colour | Share | What it is |
   | --- | --- | --- |
   | `#050603` | 88.9% | the near-black field / Larry's body |
   | `#030837` | 5.0% | deep indigo shadow |
   | `#542AC0` | 1.7% | **the bright purple horns** |
   | `#1F143A` | 1.3% | dark purple |
   | `#FFFFFF` | 1.1% | the eyes |
   | `#391E7D` | 1.1% | mid purple |
   | `#A4CF47` | 0.6% | the acid-green grin |

   **Use `#391E7D` (mid purple).** The trap is picking the brightest one: a `#542AC0`
   background is the *same colour as the horns*, so the horns would vanish into it and Larry
   would lose his silhouette. `#391E7D` is dark enough that the white eyes and green grin pop,
   light enough that the near-black body reads as a distinct shape against it.

   Fallback `#1F143A` if the `#542AC0` horns still lack separation at small sizes. **Decide at
   48x48, not at full size** — that is where the choice is actually load-bearing.
3. **Safe zone.** Android adaptive icons crop to a circle/squircle; the horns reach high in
   the frame and will be clipped unless the art is inset into the 66% safe zone.

Larry is the **wave-201 King, deliberately parked** (issue 89 ruling — do not build him
unprompted). **CONFIRMED intended branding** (user, 2026-09-01): he is the app icon even
though the character does not ship. Recorded so a future reader does not "fix" the
inconsistency by swapping the icon or by building the King.

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
- Adaptive background is `#391E7D`, and the `#542AC0` horns still read against it at 48x48.
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

## Outcome (2026-09-01)

Shipped. `config/icon="res://icon.png"` in `project.godot`, three launcher icons wired into
the Android preset, source art committed at `game/assets/icon/larry-source.png`.

### The purple ruling rested on a wrong premise — mine

This slice told the user the art was "a dark subject on transparency" that would vanish on a
dark launcher, and purple was ruled to solve that. **`Larry.png` is 100% opaque** — measured,
every pixel alpha 255. `sips` reports `hasAlpha: yes` because the channel exists, not because
anything is transparent. The black field is *painted*, so:

- the icon can never "vanish" — it is a solid, well-defined square
- a purple background can never show through it

Making purple show requires keying the near-black out. **That was tried and it destroys the
art**: Larry's horns are themselves purple (`#542AC0`, `#391E7D`, `#1F143A`), so on a purple
field the horns disappear and only the white eyes and green grin survive. Rendered and
compared at 48x48 — the black version keeps horns, eyes, grin and arms; the keyed version
loses the entire top half of the character.

### What shipped instead

| Asset | Content |
| --- | --- |
| `icon.png` (512), `playstore-512`, `main-192` | **the art as drawn**, full bleed |
| `adaptive-foreground` (432) | Larry inset to 254px, transparent margin |
| `adaptive-background` (432) | **`#391E7D` purple** — the ruling, applied where Android requires a background layer anyway |

So purple is honoured in the adaptive icon (where a background layer is mandatory and
genuinely visible around the inset foreground), and the art is left intact everywhere the
whole square is shown.

**Reversible in one command** if the user prefers purple everywhere despite the horns — the
keyed variant is a single `colorkey` filter; see the git history of this slice.

### Scaling

All nearest-neighbour (`flags=neighbor`), and every step is an **exact integer divide** of the
1016px source so no pixel is resampled unevenly: 1016 -> 508 (/2) padded to 512, 1016 -> 254
(/4) inset in 432, 1016 -> 127 (/8) padded to 192. The 254px foreground sits at 58.8% of 432,
inside the 66% adaptive safe zone, so the circular crop keeps the horns.

`run_all.sh` ALL GREEN, foreground, alone.
