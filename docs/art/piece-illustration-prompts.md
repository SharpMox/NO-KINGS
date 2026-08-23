# Piece Illustration Prompt Pack

Generation kit for the 25 MVP piece illustrations (8 promotion chains × 3 stages +
the enemy King). Generate each image, save it with the **exact filename** shown,
and drop it into `game/assets/pieces/` — the game hot-swaps them (glyph/token
fallback covers anything missing). After adding files, open the project once in
the Godot editor (or run `godot --headless --import` from `game/`) so the new
PNGs get import metadata, and commit the generated `.import` files with the PNGs.

## Style guide (prepend to every prompt)

> Fantasy chess piece illustration, painted-miniature style, single centered
> character on a fully transparent background, square 512×512, waist-up or full
> figure, bold readable silhouette that stays clear at 52 pixels, soft warm
> lighting, ivory/parchment and antique-gold palette with muted accents, thin
> dark outline, no text, no frame, no drop shadow.

**Engine constraint:** the game tints each piece per side at runtime (blue for
the player, red for the enemy) by color multiplication — keep base colors
**light and fairly neutral** or the team tint won't read. Avoid large saturated
blue/red areas.

**Consistency tip:** generate all images in one session/thread with the style
guide pinned, and regenerate any outlier rather than accepting drift. Keep the
character scale similar across the set (heads roughly the same size).

## The 25 prompts

### Pawn chain
| File | Prompt (after the style guide) |
|---|---|
| `pawn.png` | A humble footsoldier with a round wooden shield and short spear, simple leather armor, standing at attention. Rank 1 of 3 — plain and unadorned. |
| `sergeant.png` | **Ranger** — a hooded scout with twin short blades and a travel cloak, alert stance. Rank 2 — modest gear upgrades, a hint of green trim. |
| `arrow-pawn.png` | **Archer** — a longbow archer mid-draw, quiver on the back, light chainmail. Rank 3 — confident, weathered veteran, gold-trimmed hood. |

### Seer chain (diagonal mystics)
| File | Prompt |
|---|---|
| `ferz.png` | **Seer** — an old fortune-teller clutching a small crystal orb, patched robes, eyes closed in concentration. Rank 1 — humble mystic. |
| `elephant-modern.png` | **Mystic** — a robed diviner levitating two glowing runestones, ornate headwrap, arcane sigils on the sleeves. Rank 2. |
| `high-priestess.png` | **Shaman** — a regal oracle with a crescent diadem, layered ceremonial robes, an aura of floating glyphs. Rank 3 — serene and powerful. |

### Mage chain (orthogonal casters)
| File | Prompt |
|---|---|
| `wazir.png` | **Mage** — a young battle-mage with a plain staff and studded robe, sparks at the staff tip. Rank 1. |
| `war-machine.png` | **Sorcerer** — a mid-career spellcaster wreathed in crackling energy, twin-pronged staff, billowing robe. Rank 2. |
| `champion.png` | **Archmage** — an imposing master of the arcane, floating grimoire, staff crowned with a burning sigil, ornate mantle. Rank 3. |

### Bishop chain
| File | Prompt |
|---|---|
| `bishop.png` | A classic chess Bishop reimagined as a cleric with a tall mitre and crozier, calm expression. Rank 1. |
| `dragon-horse.png` | **Cardinal** — an armored holy knight with a winged helm, glowing longsword and tower shield bearing a sun emblem. Rank 2. |
| `archbishop.png` | **Archbishop** — a militant high cleric in gilded plate-and-vestments, radiant staff, halo-like ring behind the head. Rank 3. |

### Rook chain
| File | Prompt |
|---|---|
| `rook.png` | A classic stone tower rook with weathered battlements and an oak gate, ivy at the base. Rank 1. |
| `dragon-king.png` | **Drakehold** — a young wingless dragon coiled around a broken tower, scales like river stone. Rank 2. |
| `chancellor.png` | **Dragonlord** — an armored dragon-rider atop a battle-scarred drake, lance raised, banners streaming. Rank 3. |

### Knight chain
| File | Prompt |
|---|---|
| `knight.png` | A classic chess knight as an armored horse head with flowing mane, proud profile. Rank 1. |
| `gnu.png` | **Pegasus** — a half-eagle half-horse rearing with wings flared, fierce golden eyes. Rank 2. |
| `buffalo.png` | **Hippogriff** — a colossal horned beast with stone-like hide and glowing rune brands, lowered charging head. Rank 3. |

### Long Ma chain (celestial)
| File | Prompt |
|---|---|
| `kirin.png` | **Long Ma** — an elegant East-Asian kirin (dragon-deer) with a single antler and flowing tail, light flame wisps at the hooves. Rank 1. |
| `kirin-plus.png` | **Qi Lin** — the kirin ascendant, golden antlers, mane of soft fire, faint halo. Rank 2. |
| `kirin-plus-plus.png` | **Ying Long** — the kirin fully divine, galaxy-patterned coat, twin flowing antlers, ring of small stars orbiting it. Rank 3. |

### Duchess chain
| File | Prompt |
|---|---|
| `alibaba.png` | **Duchess** — a cloaked traveler with a walking staff and heavy satchel, face in hood shadow, dusty boots. Rank 1. |
| `bodyguard.png` | **Princess** — an elite royal guard in ornate half-plate with a halberd and full-face helm, unshakeable stance. Rank 2. |
| `queen.png` | **Queen** — a commanding warrior-queen with a tall crown, ceremonial sword, and flowing regal mantle. Rank 3 — the strongest piece. |

### Enemy boss
| File | Prompt |
|---|---|
| `king.png` | **The King** — a tyrant king on a walking throne, heavy crown too large for his head, cruel expression, gaudy scepter. This is the enemy boss the player must checkmate — make him ominous but slightly grotesque. |

## Checklist after generating

1. 25 PNGs in `game/assets/pieces/`, filenames exactly as above, transparent bg.
2. `godot --headless --import` from `game/` (or open the editor once).
3. `godot --headless --path game -s tests/test_assets.gd` → ALL 25 TOKENS PRESENT.
4. Eyeball in-game: `godot --path game -- --screenshot <dir>` and check `game.png`.
