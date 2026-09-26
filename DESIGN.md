---
version: alpha
name: NO KINGS Reference Site
description: >-
  The static web encyclopedia at nokings.sharpunk.com. Tokens follow the
  artefacts.html design pilot, which codex, promotion, fusion and inversion
  copy and assets/site.css matches. Dark is the default theme; light values
  carry a light- prefix.
colors:
  # ---- Brand (dark theme, the default) ----
  primary: "#a8d048"            # Larry's grin lime: --lime and --accent in dark
  secondary: "#a070e8"          # lavender: --violet-hi
  tertiary: "#7a3ae8"           # rim violet: --violet
  neutral: "#0f0a1c"            # --bg
  # ---- Surfaces and ink (dark) ----
  background: "#0f0a1c"
  surface: "#181030"
  surface-2: "#221643"
  border: "#332352"
  border-soft: "#261a44"
  on-surface: "#efeaff"         # --text
  text-soft: "#a79ac9"
  text-dim: "#8c81a9"
  accent: "#a8d048"             # links and focus rings
  lime: "#a8d048"               # display: hero gradient, fills, active states
  on-lime: "#141024"            # --dark-ink: text on lime and rarity fills, both themes
  violet: "#7a3ae8"
  violet-hi: "#a070e8"
  on-violet: "#ffffff"          # encyclopedia pressed chips only
  scrim: "#080412"              # --scrim at 42-72%: dialog backdrops and glyph halos
  glass-wash: "#181030"         # --glass-wash at 9-20% under the lavender tint
  glass-rim: "#efeaff"          # --glass-rim at 6-22%: inset highlight
  brand-red: "#e5352b"          # favicon prohibition ring only
  # ---- Rarity ladder (dark) ----
  rarity-common: "#7b8190"
  rarity-uncommon: "#2fb3a6"
  rarity-rare: "#a8d048"
  rarity-legendary: "#a070e8"
  # ---- Movement-diagram board (dark), read by assets/board.js ----
  board-light: "#4a4270"
  board-dark: "#241d3e"
  piece-disc: "#efeaff"
  on-piece-disc: "#0f0a1c"
  move: "#79a7ff"               # also ray and the leaper badge
  capture: "#ff7878"
  hurdle: "#c890e8"
  hop-target: "#6dd6a8"
  ray: "#79a7ff"
  rider: "#ffae5c"
  # ---- Light theme (explicit opt-in via the toggle) ----
  light-background: "#f4ecda"
  light-surface: "#fcf0d8"
  light-surface-2: "#fff8ea"
  light-border: "#e0d0ae"
  light-border-soft: "#ebdcbf"
  light-on-surface: "#231544"
  light-text-soft: "#5f5080"
  light-text-dim: "#6f6484"
  light-accent: "#577319"       # same token as light-lime
  light-lime: "#577319"
  light-on-lime: "#fcf0d8"
  light-violet: "#6a2ed0"
  light-violet-hi: "#8a52d8"
  light-scrim: "#080412"        # same as dark: light uses the dark violet wash (Max, 26/09/2026)
  light-glass-wash: "#181030"   # same as dark --glass-wash
  light-glass-rim: "#efeaff"    # same as dark --glass-rim
  light-rarity-common: "#656a76"
  light-rarity-uncommon: "#10766d"
  light-rarity-rare: "#577319"  # --r-rare is var(--lime)
  light-rarity-legendary: "#7a3ae8"
  light-board-light: "#fcf0d8"
  light-board-dark: "#b3a8c2"
  light-piece-disc: "#231544"
  light-on-piece-disc: "#fcf0d8"
  light-move: "#2e6fd0"
  light-capture: "#c0392b"
  light-hurdle: "#7a3ae8"
  light-hop-target: "#2f8f5f"
  light-ray: "#2e6fd0"          # --ray-color is var(--move-color)
  light-rider: "#c8791f"
typography:
  display-hero:
    fontFamily: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif
    fontSize: 88px
    fontWeight: 800
    lineHeight: 0.95
    letterSpacing: -0.035em
  headline-panel:
    fontFamily: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif
    fontSize: 26px
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: -0.02em
  title-lg:
    fontFamily: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif
    fontSize: 20px
    fontWeight: 600
    lineHeight: 1.3
  title-md:
    fontFamily: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif
    fontSize: 17px
    fontWeight: 700
    lineHeight: 1.15
  body-lede:
    fontFamily: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif
    fontSize: 16.5px
    fontWeight: 400
    lineHeight: 1.55
  body-md:
    fontFamily: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.55
  body-sm:
    fontFamily: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif
    fontSize: 12.5px
    fontWeight: 400
    lineHeight: 1.55
  caption:
    fontFamily: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.55
  nav-link:
    fontFamily: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif
    fontSize: 12.5px
    fontWeight: 600
    lineHeight: 1
  wordmark:
    fontFamily: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif
    fontSize: 13.5px
    fontWeight: 800
    lineHeight: 1
    letterSpacing: 0.04em
  label-mono:
    fontFamily: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace
    fontSize: 11px
    fontWeight: 700
    lineHeight: 1
    letterSpacing: 0.09em
  label-mono-sm:
    fontFamily: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace
    fontSize: 10px
    fontWeight: 700
    lineHeight: 1
    letterSpacing: 0.17em
  label-mono-xs:
    fontFamily: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace
    fontSize: 9px
    fontWeight: 700
    lineHeight: 1
    letterSpacing: 0.12em
  code:
    fontFamily: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace
    fontSize: 11px
    fontWeight: 600
    lineHeight: 1.4
rounded:
  xs: 4px          # --rad-xs
  control: 8px     # --rad-ctl
  sm: 12px         # --rad-sm
  md: 18px         # --rad-md
  dialog: 26px     # --rad-dlg
  pill: 999px      # --rad-pill
spacing:
  wrap: 1560px
  nav-height: 60px
  gutter: 22px
  gutter-phone: 16px
  gutter-wall: 10px
  hero-top: 52px
  hero-bottom: 26px
  gap-xs: 4px
  gap-sm: 7px
  gap-md: 12px
  gap-lg: 20px
  gap-xl: 26px
  section: 54px
  bp-phone: 560px
  bp-panel: 760px
  bp-nav: 860px
  bp-sticky-bar: 900px
components:
  nav-bar:
    backgroundColor: "{colors.background}"
    textColor: "{colors.text-soft}"
    height: "{spacing.nav-height}"
    padding: "{spacing.gutter}"
  nav-link:
    textColor: "{colors.text-soft}"
    typography: "{typography.nav-link}"
    padding: 13px
  nav-link-active:
    textColor: "{colors.on-surface}"
  nav-wordmark:
    textColor: "{colors.on-surface}"
    typography: "{typography.wordmark}"
  icon-button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-soft}"
    rounded: "{rounded.pill}"
    size: 38px
  icon-button-pressed:
    backgroundColor: "{colors.lime}"
    textColor: "{colors.on-lime}"
    rounded: "{rounded.pill}"
    size: 40px
  hero-title:
    textColor: "{colors.on-surface}"
    typography: "{typography.display-hero}"
  hero-lede:
    textColor: "{colors.text-soft}"
    typography: "{typography.body-lede}"
  chip:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-soft}"
    typography: "{typography.label-mono}"
    rounded: "{rounded.pill}"
    padding: 11px 15px
  chip-active:
    backgroundColor: "{colors.lime}"
    textColor: "{colors.on-lime}"
  chip-active-light:
    backgroundColor: "{colors.light-lime}"
    textColor: "{colors.on-lime}"
  chip-square:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-soft}"
    typography: "{typography.label-mono}"
    rounded: "{rounded.xs}"
    padding: 8px 11px
  segmented-group:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.pill}"
    padding: 4px
  segmented-option-active:
    backgroundColor: "{colors.lime}"
    textColor: "{colors.on-lime}"
    typography: "{typography.label-mono}"
    rounded: "{rounded.pill}"
    padding: 9px 16px
  search-input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-md}"
    rounded: "{rounded.pill}"
    height: 44px
    width: 270px
    padding: 0 18px
  filter-box:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-soft}"
    typography: "{typography.label-mono}"
    rounded: "{rounded.control}"
    padding: 11px 14px
  count-badge:
    backgroundColor: "{colors.lime}"
    textColor: "{colors.on-lime}"
    typography: "{typography.label-mono-xs}"
    rounded: "{rounded.pill}"
    padding: 3px 6px
  glass-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    padding: 10px
  piece-tile:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.sm}"
    width: 88px
    padding: 9px
  tier-panel:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    padding: 8px 10px
  ledger-row:
    textColor: "{colors.on-surface}"
    typography: "{typography.body-md}"
    rounded: "{rounded.sm}"
    padding: 8px 13px
    height: 38px
  ledger-row-open:
    backgroundColor: "{colors.surface-2}"
  side-panel:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    width: 700px
    padding: 22px 34px
  dialog:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.dialog}"
    padding: 26px 28px
  dialog-title:
    textColor: "{colors.lime}"
    typography: "{typography.headline-panel}"
  close-button:
    backgroundColor: "{colors.surface-2}"
    textColor: "{colors.text-soft}"
    rounded: "{rounded.pill}"
    size: 34px
  tag:
    backgroundColor: "{colors.surface-2}"
    textColor: "{colors.on-surface}"
    typography: "{typography.label-mono-xs}"
    rounded: "{rounded.pill}"
    padding: 5px 9px
  betza-pill:
    backgroundColor: "{colors.surface-2}"
    textColor: "{colors.text-soft}"
    typography: "{typography.code}"
    rounded: "{rounded.pill}"
    padding: 2px 9px
  mono-label:
    textColor: "{colors.text-dim}"
    typography: "{typography.label-mono-sm}"
  footer:
    textColor: "{colors.text-dim}"
    typography: "{typography.caption}"
    padding: 26px 22px 52px
  board-square:
    backgroundColor: "{colors.board-dark}"
    rounded: "{rounded.control}"
  board-square-light:
    backgroundColor: "{colors.light-board-dark}"
    textColor: "{colors.light-rider}"
  link:
    textColor: "{colors.accent}"
  link-light:
    backgroundColor: "{colors.light-background}"
    textColor: "{colors.light-accent}"
  body-light:
    backgroundColor: "{colors.light-background}"
    textColor: "{colors.light-on-surface}"
  dim-text-light:
    backgroundColor: "{colors.light-background}"
    textColor: "{colors.light-text-dim}"
  violet-label-light:
    backgroundColor: "{colors.light-background}"
    textColor: "{colors.light-violet-hi}"
  hop-label-light:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-hop-target}"
  chip-active-encyclopedia:
    backgroundColor: "{colors.violet}"
    textColor: "{colors.on-violet}"
  chip-active-encyclopedia-light:
    backgroundColor: "{colors.light-violet}"
    textColor: "{colors.on-violet}"
  category-label:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.violet-hi}"
    typography: "{typography.label-mono-xs}"
  rarity-chip-common:
    backgroundColor: "{colors.rarity-common}"
    textColor: "{colors.on-lime}"
  rarity-chip-uncommon:
    backgroundColor: "{colors.rarity-uncommon}"
    textColor: "{colors.on-lime}"
  rarity-chip-rare:
    backgroundColor: "{colors.rarity-rare}"
    textColor: "{colors.on-lime}"
  rarity-chip-legendary:
    backgroundColor: "{colors.rarity-legendary}"
    textColor: "{colors.on-lime}"
  rarity-chip-common-light:
    backgroundColor: "{colors.light-rarity-common}"
    textColor: "{colors.on-lime}"
  rarity-chip-uncommon-light:
    backgroundColor: "{colors.light-rarity-uncommon}"
    textColor: "{colors.on-lime}"
  rarity-chip-rare-light:
    backgroundColor: "{colors.light-rarity-rare}"
    textColor: "{colors.on-lime}"
  rarity-chip-legendary-light:
    backgroundColor: "{colors.light-rarity-legendary}"
    textColor: "{colors.on-lime}"
  diagram-move:
    backgroundColor: "{colors.board-light}"
    textColor: "{colors.move}"
  diagram-capture:
    backgroundColor: "{colors.board-light}"
    textColor: "{colors.capture}"
  diagram-hurdle:
    backgroundColor: "{colors.board-light}"
    textColor: "{colors.hurdle}"
  diagram-hop-target:
    backgroundColor: "{colors.board-light}"
    textColor: "{colors.hop-target}"
  diagram-ray:
    backgroundColor: "{colors.board-light}"
    textColor: "{colors.ray}"
  diagram-rider:
    backgroundColor: "{colors.board-light}"
    textColor: "{colors.rider}"
  diagram-piece:
    backgroundColor: "{colors.piece-disc}"
    textColor: "{colors.on-piece-disc}"
  diagram-move-light:
    backgroundColor: "{colors.light-board-dark}"
    textColor: "{colors.light-move}"
  diagram-capture-light:
    backgroundColor: "{colors.light-board-dark}"
    textColor: "{colors.light-capture}"
  diagram-hurdle-light:
    backgroundColor: "{colors.light-board-light}"
    textColor: "{colors.light-hurdle}"
  diagram-ray-light:
    backgroundColor: "{colors.light-board-light}"
    textColor: "{colors.light-ray}"
  diagram-piece-light:
    backgroundColor: "{colors.light-piece-disc}"
    textColor: "{colors.light-on-piece-disc}"
  divider:
    backgroundColor: "{colors.border}"
    height: 1px
  divider-light:
    backgroundColor: "{colors.light-border}"
    height: 1px
  rail-cell-out:
    backgroundColor: "{colors.border-soft}"
    rounded: "{rounded.xs}"
  rail-cell-out-light:
    backgroundColor: "{colors.light-border-soft}"
    rounded: "{rounded.xs}"
  record-open-light:
    backgroundColor: "{colors.light-surface-2}"
    textColor: "{colors.light-text-soft}"
  dialog-backdrop:
    backgroundColor: "{colors.scrim}"
    textColor: "{colors.glass-rim}"
  dialog-backdrop-light:
    backgroundColor: "{colors.light-scrim}"
    textColor: "{colors.light-glass-rim}"
  glass-wash:
    backgroundColor: "{colors.glass-wash}"
    textColor: "{colors.glass-rim}"
  glass-wash-light:
    backgroundColor: "{colors.light-glass-wash}"
    textColor: "{colors.light-glass-rim}"
  segmented-option-active-light:
    backgroundColor: "{colors.light-lime}"
    textColor: "{colors.light-on-lime}"
  favicon:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.brand-red}"
    rounded: 7px
    size: 32px
---

# NO KINGS Reference Site

## Overview

NO KINGS is "an explosive Chess riot", and the reference site is its encyclopedia:
a piece codex, promotion, fusion and inversion references, a relationship graph and
merge matrix, a Betza-notation sandbox, the 180 artefacts and a 100-piece
encyclopedia. It is static HTML with inline `<style>` per page and a few shared files
in `assets/`.

The look comes from the game's mascot, Larry: a deep-violet body, an electric violet
rim, lavender highlights and a lime grin, set on the cream of the game board. Dark is
the product default and the system colour-scheme preference is deliberately ignored
(`assets/theme-init.js`); light is an explicit opt-in from the header toggle.

The feel is **dense and technical, softened by glass**. Mono uppercase micro-labels,
tight rows and fixed-size diagram cards carry the data. Frosted surfaces over a
radial violet-and-lime "aura" add depth, and springy card motion adds play. Pages are
reference tools, so information density wins over whitespace.

The site runs **two generations** of styling on one token set:

- **Pilot pages** (`artefacts`, `codex`, `promotion`, `fusion`, `inversion`) do not
  load `assets/site.css`. Each carries its own copy of the tokens above, plus
  `.hero`, `.foot` and the glass recipes. `artefacts.html` is the named seed of the
  next `site.css`.
- **Legacy pages** (`betza`, `graph`, `encyclopedia/`, `privacy`, `terms`) load
  `assets/site.css`, whose palette, radii, glass tokens, hero and focus ring match
  the pilot in both themes.

Both generations share `assets/nav.css`/`nav.js` (header), `theme.js` (toggle) and
`board.js` (diagrams). This file specifies the pilot generation.

## Colors

Semantic names mirror the CSS custom properties so the tokens map one-to-one onto
code (`on-surface` is `--text`, `board-dark` is `--sq-dark`, and so on).

- **Lime (#a8d048 dark / #577319 light):** Larry's grin. One olive per theme:
  `--accent` (links, focus rings) and `--r-rare` are `var(--lime)`, not separate
  hexes. The light value was darkened from the source #6f9420 (3.01:1 on cream).
  Text on a lime or rarity fill is `--dark-ink` #141024 in both themes.
- **Violet (#7a3ae8) and Violet-hi (#a070e8):** Larry's rim and lavender. Violet-hi
  runs the hover borders on chips and tiles, the tail of the hero gradient, and small
  category labels. Plain `--violet` is 3.11:1 on the dark surface, so it is a fill
  colour, never a text colour.
- **Neutrals:** a violet-tinted ladder. Background #0f0a1c, surface #181030,
  surface-2 #221643, borders #332352 and #261a44, ink #efeaff, then text-soft #a79ac9
  for secondary copy and text-dim #8c81a9 for metadata and counters. The light ladder
  is cream: #f4ecda, #fcf0d8, #fff8ea, with ink #231544.
- **Rarity ladder:** common slate, uncommon teal, rare lime, legendary violet. It was
  built for artefacts, and promotion/fusion/inversion reuse it for stage labels so
  climbing a Family reads like climbing a rarity. Teal rather than a second green,
  because two greens are indistinguishable at 15px.
- **Diagram palette:** eight tokens that `assets/board.js` reads by name: move (blue
  ring), capture (red X), hurdle (violet dashed box), hop-target (green), ray (blue
  line), rider (orange dashed path), plus the square and piece-disc colours. The
  relation colours in codex and graph reuse them: promotion = hop-target, additive
  fusion = accent, synergistic fusion = hurdle, inversion = text-soft. Move and ray
  are one blue: `--ray-color` is `var(--move-color)`.
- **Glass recipe:** `linear-gradient(150deg, rgba(160,112,232,a),
  color-mix(--glass-wash b%))` over `color-mix(surface N%, transparent)`, with an
  inset `color-mix(--glass-rim 13-22%)` top highlight and `--scrim` at 42-72% behind
  dialogs. The three tokens are the same in both themes: light deliberately reuses
  dark's violet wash, ink rim and near-black scrim rather than a cream variant
  (Max's preference, 26/09/2026) — everything else on the light surfaces stays cream.
- **Behaviour badges** (`encyclopedia/index.html`) use a separate 8-hue palette
  held in page-local `--bd-*` variables, one text and edge pair per hue per theme.
  The leaper badge reads `--move-color`.

## Typography

One system sans stack (`-apple-system, BlinkMacSystemFont, Segoe UI, Roboto`) for
everything readable, and one system mono stack (`ui-monospace, SFMono-Regular, Menlo,
Consolas`) for everything that labels, counts or notates. No web fonts are loaded.

- **Display:** the page title is 800 weight, italic, `clamp(44px, 7.4vw, 88px)`, line
  height 0.95, tracking -0.035em, filled with a 96deg lime-to-violet-hi gradient
  through `background-clip:text`. It keeps a 0.07em right pad so the italic's last
  glyph is not clipped. Legacy pages get the same size and treatment from
  `site.css`'s `header h1`.
- **Headlines:** panel and dialog titles at 26-28px, bold, tight tracking.
- **Body:** 14px for record text, 12-12.5px for descriptions and legends, line
  height 1.5-1.6. The hero lede is 16.5px in text-soft, capped at 50-52ch.
- **Mono labels:** 700 weight, uppercase, tracked 0.08-0.2em, at 11px (chips,
  toggles), 10px (section labels, tier headings) and 8.5-9.5px (stage, type and tag
  micro-labels). Tracking widens as size drops.
- **Notation:** Betza strings and counts use the mono stack at 600 weight, 10.5-11px,
  never uppercased.

## Layout

- **Container:** one centred column, `--wrap: 1560px`, used by the nav, hero and
  footer with a 22px gutter on every page (16px on phones).
- **Walls run full-bleed.** `main` drops the cap and uses a 10px gutter so card walls
  (decks, atlas, ledger) solve their own sizes against the whole window. Card width
  is computed rather than picked: decks take `clamp(144px, (100vw + 32px) / 9, 184px)`
  so three fanned Families fit a row.
- **Chrome is measured.** The sticky header is 60px minimum; `nav.js` writes the
  real height to `--nav-h`, and artefacts writes `--bar-h` for its sticky filter bar.
  Sticky offsets are always derived from these, never hardcoded.
- **Side panels** (codex record, betza notation) are fixed at `min(700-720px,
  46-48.6vw)` from the right. On desktop they push content by the same width; below
  760px (codex) or 960px (betza) they become full-width or rejoin the flow.
- **Spacing** is dense and irregular rather than on a strict grid. The recurring
  steps are 4, 7, 12, 20, 26px for gaps and 54px between sections.
- **Breakpoints:** 560px is the phone breakpoint (`site.css`, CLAUDE.md), used by
  every page including the stack pages. Wider ones are layout-specific: 720px
  (legacy card grids), 760px (pilot panels, dialogs), 860px (nav burger,
  artefacts), 900px (sticky filter bar), 960px (betza panel).
- **Touch targets:** at 44px minimum on phones. `site.css` enforces it for shared
  class names, and the pilot pages size their own controls to 44px.

## Elevation & Depth

Depth comes from **frosted glass over an aura**, not from drop shadows.

1. **Aura (level 0):** a fixed `body::before` with two radial gradients, violet at
   top-left and lime at top-right (14%/12% alpha in light, 30%/13% in dark). The
   encyclopedia adds two more lower down so its long grid has something to blur.
2. **Glass controls (level 1):** filter boxes and keys. Surface at 52-58%, the faint
   violet wash, `blur(14px) saturate(150%)`, and a 1px inset highlight.
3. **Glass cards (level 2):** deck cards, piece tiles, relation boxes, encyclopedia
   cards. Surface at 46-54%, blur 9-16px, 1px violet-hi or text-mix rim.
4. **Panels and dialogs (level 3):** surface at 42-62%, `blur(26px) saturate(160%)`,
   and the only real shadows on the site: `-30px 0 70px -40px rgba(0,0,0,.8)` for side
   panels and `0 40px 90px -30px rgba(0,0,0,.85)` for dialogs.

Every glass surface falls back to solid `--surface` under
`prefers-reduced-transparency: reduce`. Active and focused states use rings, not
lift: a 1-4px `color-mix` box-shadow in the element's own hue, with an optional soft
glow (`--glow` on the artefacts search, the codex open tile).

## Shapes

The language is **soft geometry**: generous radii on containers, full pills on
controls, and square-ish diagram cells.

Every radius is a token: `--rad-xs` 4, `--rad-ctl` 8, `--rad-sm` 12, `--rad-md` 18,
`--rad-dlg` 26, `--rad-pill` 999 (plus 50% for circles).

- **Pill:** chips, segmented toggles, search input, tags, Betza pills, count
  badges, and the round icon buttons (theme toggle, burger, close).
- **md (18px):** tier panels and deck cards.
- **sm (12px):** piece tiles, encyclopedia cards, ledger rows, artefact art, focus rings.
- **ctl (8px):** filter boxes, relation boxes, tables, tooltips, betza keys,
  diagram crops and boards.
- **xs (4px):** rail cells (circles in dense mode), square chips on the stack
  pages, code tokens.
- **dlg (26px):** dialogs, with a 25px inner rim.

## Components

- **Header (`assets/nav.css`):** a sticky bar on `--bg` at 78% with `blur(14px)` and
  a soft bottom border. Wordmark in 800 weight, links in 600 weight text-soft, and
  the current page gets ink plus a 2px lime underline (a left bar in the phone
  menu). Below 860px the links collapse behind a round burger. The theme toggle is a
  38px round button that turns lime on hover.
- **Hero:** display title with the gradient `<em>`, then a text-soft lede.
- **Chips:** three variants, each deliberate. Artefacts and encyclopedia share one
  pill chip (11px mono, 11px 15px padding); only the pressed fill differs:
  the chip's own rarity or bonus hue with `--dark-ink` text on artefacts, where
  colour carries meaning, and violet with white text on encyclopedia, where it
  does not. Promotion, fusion and inversion share one square chip (`--rad-xs`,
  10.5px) in a grid of Family columns, pressed in lime. Graph uses 12px sans
  legend pills with a coloured dot, because they toggle relation colours rather
  than filter a list. Hover lifts 1px and borders in violet-hi.
- **Filter box (`.fbox`/`.filt`):** a glass container whose closed state is its own
  mono "Filters" label and whose open state grows into the chip panel. A lime count
  badge shows how many filters are on. Shared by encyclopedia, betza and the three
  stack pages.
- **Wallet stacks (promotion, fusion, inversion):** glass cards (`--rad-md`,
  violet-hi rim) stacked 44px apart with a 13px step, fanning out on a spring curve
  (`cubic-bezier(.3,1.45,.42,1)`). Each stack is headed by an `<h3>` in 11px mono,
  `--accent`. The seam glyph (arrow, `+`/`=`, or swap) is lime with a halo that
  switches per theme: cream in light, `--scrim` in dark. Stage labels borrow the
  rarity ladder per page: promotion base/mid/end = uncommon/rare/legendary, fusion
  inputs/product = rare/legendary, inversion both halves = uncommon.
- **Line dialog:** the three-station close-up of one Family, fusion or pair: a
  `--rad-dlg` glass slab, `min(1158px, 100vw)` wide on all three pages, with a lime
  title, boards at up to 330px, and a two-column record under each board.
- **Codex tile and side panel:** 88px glass tiles holding a cropped diagram that
  zooms out on hover. How a piece is obtained is encoded in the border: violet-hi for
  promoted, lime for forged, dashed for mirrors. The record opens in a fixed glass
  panel whose relation boxes are tinted by relation colour.
- **Artefact ledger:** one-line rows (38px min) with a rarity dot, mono number, name
  column fixed at 250px, and an ellipsised effect. Rows open into a three-column
  record (art, effect, tags) on surface-2 with a rarity-tinted border. A sticky rail
  of 3px-radius cells and SVG threads ties rows back to their squares.
- **Tags and pills:** mono uppercase tags on a rarity-tinted surface-2 pill; the
  Betza pill is mono 11px on surface-2.
- **Tables (betza, graph matrix, prose pages):** solid surface, 1px borders,
  uppercase small headers. The glass is dropped on purpose, because tables need
  contrast.
- **Tooltips (graph):** solid surface, 8-10px radius, `0 6px 24px rgba(0,0,0,.18)`,
  and a border coloured by relation kind.
- **Footer:** pilot `.foot` has a hairline top border in border-soft, text-dim at
  13px, with a text-soft 14px lead line. Legacy pages (privacy and terms included)
  use `site.css`'s bare `footer` with a `.footer-page-line` lead.
- **Movement diagrams:** drawn by `board.js` from the diagram tokens. Squares are
  `--sq-light`/`--sq-dark` and the piece is a disc in `--piece-disc`.

## Do's and Don'ts

- Do read every colour through a custom property. Pages restate the token block
  rather than hardcoding values, so a theme flip only works for what goes through
  `var()`.
- Do define every token in both `:root` (light) and `[data-theme="dark"]`, and put
  any colour whose meaning changes with the theme there as well.
- Do use `--accent` for links and focus, and `--lime` for display fills. Keep text
  on lime in `--on-lime`, which flips between themes.
- Don't use `--violet` as small text. Use `--violet-hi` or `--accent`, and check
  4.5:1 on the surface it will sit on.
- Do use the radius tokens and `--mono`/`--sans`; don't write a literal radius or
  font stack.
- Do measure chrome heights into `--nav-h`/`--bar-h`. Don't hardcode sticky offsets.
- Do give every glass surface a `prefers-reduced-transparency` solid fallback and
  every animation a `prefers-reduced-motion` off switch.
- Do keep mono uppercase for labels, counts and notation, and sans for anything read
  as a sentence.
- Do keep phone controls at 44px or larger.
- Don't add drop shadows for hierarchy. Use glass level, border tint or a ring.
- Don't fork a shared component per page. Chips, filter boxes and stacks are
  duplicated today; changes must land in every copy, or be extracted first.
- Do keep one focus ring: 2px `--accent` outline, 3px offset, `--rad-sm` radius.
- Don't point diagram colours at page-specific values. `board.js` reads the eight
  diagram tokens by name, so every page that draws a board must define all of them.
