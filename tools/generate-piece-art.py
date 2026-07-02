# Generates the 25 piece illustrations as SVG (Godot imports SVG natively via
# ThorVG). Each piece = shared token frame (ivory disc + dark ring) + a
# hand-designed vector emblem. Chains share a motif that gains ornament per
# rank. Rerun after edits, then minify:
#   python3 tools/generate-piece-art.py && npx --yes svgo --folder game/assets/pieces --quiet
# ponytail: vector programmer-art — drop painted PNGs with the same basenames
# into game/assets/pieces/ anytime to override (loader prefers png at parity).
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game/assets/pieces"

INK = "#2a2118"       # outlines + solid silhouettes
IVORY = "#eee4cd"     # disc
GOLD = "#c9a227"      # accents, rank ornaments
RED = "#8b2020"       # king only

# All emblems are drawn in a 100x100 viewbox, centered on the 512px disc.


def svg(body: str) -> str:
    # emblem scaled up for legibility at ~52px board tiles
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 100 100">
<circle cx="50" cy="50" r="47" fill="{IVORY}" stroke="{INK}" stroke-width="3"/>
<g transform="translate(50 50) scale(1.16) translate(-50 -50)">
{body}
</g>
</svg>'''


def halo(y: float = 26, rx: float = 16) -> str:
    """Gold arc above the emblem — rank-2/3 ornament."""
    return f'<path d="M {50 - rx} {y} A {rx} {rx * 0.55} 0 0 1 {50 + rx} {y}" fill="none" stroke="{GOLD}" stroke-width="3" stroke-linecap="round"/>'


def stars(n: int) -> str:
    """Small gold diamonds arced above — rank-3 ornament."""
    pts = [(30, 26), (40, 20), (50, 18), (60, 20), (70, 26)][:n] if n <= 5 else []
    out = ""
    for x, y in pts:
        out += f'<path d="M {x} {y - 3} L {x + 2.4} {y} L {x} {y + 3} L {x - 2.4} {y} Z" fill="{GOLD}"/>'
    return out


def pawn_body(scale: float = 1.0, dy: float = 0.0) -> str:
    """Classic pawn silhouette."""
    return (f'<g transform="translate(50 {52 + dy}) scale({scale})">'
            f'<circle cx="0" cy="-14" r="9" fill="{INK}"/>'
            f'<path d="M -7 -6 Q 0 -1 7 -6 L 10 12 Q 0 16 -10 12 Z" fill="{INK}"/>'
            f'<path d="M -13 13 L 13 13 L 15 20 L -15 20 Z" fill="{INK}"/></g>')


EMBLEMS = {
    # ---- Pawn chain: footsoldier -> hooded ranger -> archer ----
    "pawn": pawn_body(),
    "sergeant": (  # Ranger: hooded head + crossed dagger blades
        f'<path d="M 50 22 L 62 40 L 58 42 Q 50 36 42 42 L 38 40 Z" fill="{INK}"/>'
        f'<circle cx="50" cy="42" r="7" fill="{INK}"/>'
        f'<path d="M 32 74 L 62 44 L 66 48 L 36 78 Z" fill="{INK}"/>'
        f'<path d="M 68 74 L 38 44 L 34 48 L 64 78 Z" fill="{INK}"/>'
        f'<rect x="31" y="72" width="8" height="8" rx="2" fill="{GOLD}"/>'
        f'<rect x="61" y="72" width="8" height="8" rx="2" fill="{GOLD}"/>'
    ),
    "arrow-pawn": (  # Archer: drawn bow + arrow
        f'<path d="M 36 22 Q 66 50 36 78" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
        f'<line x1="36" y1="22" x2="36" y2="78" stroke="{INK}" stroke-width="2.5"/>'
        f'<line x1="36" y1="50" x2="72" y2="50" stroke="{INK}" stroke-width="4"/>'
        f'<path d="M 72 50 L 62 44 L 65 50 L 62 56 Z" fill="{INK}"/>'
        f'<path d="M 36 50 L 28 45 L 31 50 L 28 55 Z" fill="{GOLD}"/>'
    ),
    # ---- Seer chain: eye+orb -> orb+runes -> crescent priestess ----
    "ferz": (
        f'<circle cx="50" cy="58" r="14" fill="none" stroke="{INK}" stroke-width="4"/>'
        f'<path d="M 30 38 Q 50 22 70 38 Q 50 54 30 38 Z" fill="{INK}"/>'
        f'<circle cx="50" cy="38" r="6" fill="{IVORY}"/>'
        f'<circle cx="50" cy="38" r="2.6" fill="{INK}"/>'
    ),
    "elephant-modern": (
        f'<circle cx="50" cy="52" r="15" fill="none" stroke="{INK}" stroke-width="4"/>'
        f'<circle cx="50" cy="52" r="6" fill="{GOLD}"/>'
        f'<path d="M 26 38 L 32 32 L 38 38 L 32 44 Z" fill="{INK}"/>'
        f'<path d="M 62 38 L 68 32 L 74 38 L 68 44 Z" fill="{INK}"/>'
        f'<path d="M 44 76 L 50 70 L 56 76 L 50 82 Z" fill="{INK}"/>'
    ),
    "high-priestess": (
        f'<path d="M 30 34 A 22 22 0 1 1 70 34 A 17 17 0 1 0 30 34 Z" fill="{GOLD}"/>'
        f'<circle cx="50" cy="56" r="15" fill="none" stroke="{INK}" stroke-width="4"/>'
        f'<circle cx="50" cy="56" r="7" fill="{INK}"/>'
        f'<path d="M 24 70 L 29 65 L 34 70 L 29 75 Z" fill="{INK}"/>'
        f'<path d="M 66 70 L 71 65 L 76 70 L 71 75 Z" fill="{INK}"/>'
    ),
    # ---- Mage chain: staff+spark -> forked staff -> archmage sigil ----
    "wazir": (
        f'<line x1="44" y1="80" x2="58" y2="30" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
        f'<path d="M 58 30 L 62 20 L 64 30 L 72 32 L 63 36 Z" fill="{GOLD}"/>'
    ),
    "war-machine": (  # Sorcerer: staff crowned by a large radiant orb
        f'<line x1="50" y1="84" x2="50" y2="46" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
        f'<path d="M 42 46 Q 50 38 58 46" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>'
        f'<circle cx="50" cy="32" r="9" fill="{GOLD}" stroke="{INK}" stroke-width="3"/>'
        f'<line x1="50" y1="14" x2="50" y2="20" stroke="{GOLD}" stroke-width="3" stroke-linecap="round"/>'
        f'<line x1="34" y1="24" x2="39" y2="27" stroke="{GOLD}" stroke-width="3" stroke-linecap="round"/>'
        f'<line x1="66" y1="24" x2="61" y2="27" stroke="{GOLD}" stroke-width="3" stroke-linecap="round"/>'
    ),
    "champion": (
        f'<line x1="42" y1="84" x2="42" y2="30" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
        f'<circle cx="42" cy="26" r="7" fill="{GOLD}" stroke="{INK}" stroke-width="2.5"/>'
        f'<path d="M 56 62 L 78 62 L 78 78 L 56 78 Z" fill="none" stroke="{INK}" stroke-width="3.5"/>'
        f'<line x1="56" y1="68" x2="78" y2="68" stroke="{INK}" stroke-width="2"/>'
        f'<path d="M 42 22 Q 39 15 44 10 Q 43 16 48 18 Q 46 21 42 22 Z" fill="{RED}"/>'
    ),
    # ---- Bishop chain: mitre -> winged paladin -> haloed archbishop ----
    "bishop": (
        f'<path d="M 50 20 Q 66 38 62 56 L 38 56 Q 34 38 50 20 Z" fill="{INK}"/>'
        f'<line x1="43" y1="30" x2="57" y2="44" stroke="{IVORY}" stroke-width="3.5"/>'
        f'<path d="M 34 60 L 66 60 L 70 70 L 30 70 Z" fill="{INK}"/>'
    ),
    "dragon-horse": (  # Paladin: winged helm + sword
        f'<path d="M 40 34 Q 50 24 60 34 L 60 52 Q 50 60 40 52 Z" fill="{INK}"/>'
        f'<rect x="44" y="38" width="12" height="4" fill="{IVORY}"/>'
        f'<path d="M 38 34 Q 24 30 20 40 Q 30 42 38 40 Z" fill="{GOLD}"/>'
        f'<path d="M 62 34 Q 76 30 80 40 Q 70 42 62 40 Z" fill="{GOLD}"/>'
        f'<line x1="50" y1="62" x2="50" y2="84" stroke="{INK}" stroke-width="4.5"/>'
        f'<line x1="42" y1="68" x2="58" y2="68" stroke="{INK}" stroke-width="4"/>'
    ),
    "archbishop": (
        f'{halo(24, 15)}'
        f'<path d="M 50 26 Q 65 42 61 58 L 39 58 Q 35 42 50 26 Z" fill="{INK}"/>'
        f'<line x1="44" y1="35" x2="56" y2="47" stroke="{GOLD}" stroke-width="3.5"/>'
        f'<path d="M 34 62 L 66 62 L 70 72 L 30 72 Z" fill="{INK}"/>'
        f'<line x1="26" y1="44" x2="34" y2="78" stroke="{INK}" stroke-width="3.5"/>'
        f'<path d="M 26 44 Q 20 36 27 32 Q 25 40 31 42 Z" fill="{INK}"/>'
    ),
    # ---- Rook chain: tower -> drake -> dragonlord ----
    "rook": (
        f'<path d="M 34 30 L 34 22 L 41 22 L 41 27 L 46 27 L 46 22 L 54 22 L 54 27 L 59 27 L 59 22 L 66 22 L 66 30 L 61 36 L 61 66 L 66 74 L 34 74 L 39 66 L 39 36 Z" fill="{INK}"/>'
        f'<rect x="46" y="52" width="8" height="14" fill="{IVORY}"/>'
    ),
    "dragon-king": (  # Drake: dragon head profile
        f'<path d="M 28 56 Q 30 38 48 34 Q 62 30 70 40 L 78 44 L 68 48 Q 66 58 54 60 L 58 68 L 46 64 Q 32 66 28 56 Z" fill="{INK}"/>'
        f'<circle cx="58" cy="42" r="2.8" fill="{IVORY}"/>'
        f'<path d="M 46 33 L 42 22 L 52 30 Z" fill="{GOLD}"/>'
        f'<path d="M 36 62 Q 24 70 30 80 Q 34 72 44 68 Z" fill="{INK}"/>'
    ),
    "chancellor": (  # Dragonlord: dragon head + lance + banner
        f'<path d="M 26 58 Q 28 42 44 38 Q 56 34 63 42 L 70 46 L 61 50 Q 59 58 49 60 Q 34 64 26 58 Z" fill="{INK}"/>'
        f'<circle cx="52" cy="45" r="2.6" fill="{IVORY}"/>'
        f'<path d="M 42 37 L 38 27 L 47 34 Z" fill="{GOLD}"/>'
        f'<line x1="70" y1="20" x2="70" y2="80" stroke="{INK}" stroke-width="4"/>'
        f'<path d="M 70 22 L 84 27 L 70 34 Z" fill="{RED}"/>'
    ),
    # ---- Knight chain: horse -> winged hippogriff -> horned behemoth ----
    "knight": (
        f'<path d="M 38 76 L 40 52 Q 30 48 32 38 Q 36 24 52 22 L 50 16 L 58 22 Q 70 28 70 44 L 66 76 Z" fill="{INK}"/>'
        f'<circle cx="52" cy="32" r="2.6" fill="{IVORY}"/>'
        f'<path d="M 55 22 L 60 28 L 54 28 Z" fill="{IVORY}"/>'
    ),
    "gnu": (  # Hippogriff: horse head + swept wing
        f'<path d="M 40 76 L 42 54 Q 33 50 35 40 Q 39 27 53 26 L 51 20 L 59 26 Q 69 31 69 46 L 66 76 Z" fill="{INK}"/>'
        f'<circle cx="53" cy="35" r="2.5" fill="{IVORY}"/>'
        f'<path d="M 64 50 Q 82 40 86 26 Q 72 30 62 42 Z" fill="{GOLD}"/>'
    ),
    "buffalo": (  # Behemoth: horned bull head, front view
        f'<path d="M 36 40 Q 50 30 64 40 L 62 62 Q 50 74 38 62 Z" fill="{INK}"/>'
        f'<path d="M 36 42 Q 20 38 18 24 Q 32 26 40 36 Z" fill="{INK}"/>'
        f'<path d="M 64 42 Q 80 38 82 24 Q 68 26 60 36 Z" fill="{INK}"/>'
        f'<circle cx="44" cy="48" r="2.8" fill="{RED}"/>'
        f'<circle cx="56" cy="48" r="2.8" fill="{RED}"/>'
        f'<path d="M 46 64 Q 50 68 54 64 L 54 70 L 46 70 Z" fill="{GOLD}"/>'
    ),
    # ---- Kirin chain: antlered head, gaining halo then stars ----
    "kirin": (
        f'<path d="M 40 78 L 42 56 Q 34 50 38 40 Q 44 30 56 30 L 54 24 L 62 30 Q 70 36 68 48 L 64 78 Z" fill="{INK}"/>'
        f'<path d="M 50 30 Q 44 18 34 16 Q 40 26 46 30 Z" fill="{GOLD}"/>'
        f'<path d="M 56 28 Q 56 16 48 10 Q 52 20 52 28 Z" fill="{GOLD}"/>'
        f'<circle cx="55" cy="38" r="2.5" fill="{IVORY}"/>'
    ),
    "kirin-plus": (
        f'{halo(20, 17)}'
        f'<path d="M 40 78 L 42 58 Q 34 52 38 42 Q 44 32 56 32 L 54 26 L 62 32 Q 70 38 68 50 L 64 78 Z" fill="{INK}"/>'
        f'<path d="M 50 32 Q 44 20 34 18 Q 40 28 46 32 Z" fill="{GOLD}"/>'
        f'<path d="M 56 30 Q 56 18 48 12 Q 52 22 52 30 Z" fill="{GOLD}"/>'
        f'<circle cx="55" cy="40" r="2.5" fill="{IVORY}"/>'
    ),
    "kirin-plus-plus": (
        f'{stars(5)}'
        f'<path d="M 40 80 L 42 60 Q 34 54 38 44 Q 44 34 56 34 L 54 28 L 62 34 Q 70 40 68 52 L 64 80 Z" fill="{INK}"/>'
        f'<path d="M 50 34 Q 44 22 34 20 Q 40 30 46 34 Z" fill="{GOLD}"/>'
        f'<path d="M 56 32 Q 56 20 48 14 Q 52 24 52 32 Z" fill="{GOLD}"/>'
        f'<circle cx="55" cy="42" r="2.5" fill="{GOLD}"/>'
    ),
    # ---- Wanderer chain: traveler -> praetorian -> queen ----
    "alibaba": (  # Wanderer: wide-brim hat + walking staff
        f'<path d="M 28 40 Q 50 28 72 40 L 66 44 L 34 44 Z" fill="{INK}"/>'
        f'<circle cx="50" cy="34" r="8" fill="{INK}"/>'
        f'<path d="M 40 48 Q 50 44 60 48 L 64 78 L 36 78 Z" fill="{INK}"/>'
        f'<line x1="68" y1="30" x2="68" y2="82" stroke="{INK}" stroke-width="4"/>'
        f'<circle cx="68" cy="28" r="3.5" fill="{GOLD}"/>'
    ),
    "bodyguard": (  # Praetorian: crested full-face helm over a tall shield
        f'<path d="M 44 20 Q 42 10 50 6 Q 58 10 56 20 Z" fill="{RED}"/>'
        f'<path d="M 38 30 Q 50 20 62 30 L 62 50 Q 50 58 38 50 Z" fill="{INK}"/>'
        f'<line x1="50" y1="32" x2="50" y2="52" stroke="{IVORY}" stroke-width="2.5"/>'
        f'<rect x="42" y="37" width="16" height="3" fill="{IVORY}"/>'
        f'<path d="M 36 60 L 64 60 L 64 76 Q 50 86 36 76 Z" fill="{INK}"/>'
        f'<circle cx="50" cy="69" r="4" fill="{GOLD}"/>'
    ),
    "queen": (
        f'<path d="M 30 62 L 26 34 L 38 48 L 44 28 L 50 46 L 56 28 L 62 48 L 74 34 L 70 62 Z" fill="{INK}"/>'
        f'<circle cx="26" cy="30" r="3.5" fill="{GOLD}"/><circle cx="44" cy="24" r="3.5" fill="{GOLD}"/>'
        f'<circle cx="56" cy="24" r="3.5" fill="{GOLD}"/><circle cx="74" cy="30" r="3.5" fill="{GOLD}"/>'
        f'<circle cx="50" cy="42" r="3.5" fill="{GOLD}"/>'
        f'<path d="M 30 66 L 70 66 L 73 76 L 27 76 Z" fill="{INK}"/>'
        f'<circle cx="50" cy="71" r="3" fill="{GOLD}"/>'
    ),
    # ---- Fusion-only pieces ----
    "squirrel": (  # Faerie: winged sprite
        f'<path d="M 50 34 L 62 52 L 50 72 L 38 52 Z" fill="{INK}"/>'
        f'<circle cx="50" cy="30" r="7" fill="{INK}"/>'
        f'<path d="M 38 46 Q 20 34 16 20 Q 34 28 42 40 Z" fill="{GOLD}"/>'
        f'<path d="M 62 46 Q 80 34 84 20 Q 66 28 58 40 Z" fill="{GOLD}"/>'
        f'<circle cx="50" cy="52" r="3" fill="{GOLD}"/>'
    ),
    "crown-princess": (  # coronet over a flowing veil
        f'<path d="M 36 34 L 34 20 L 43 28 L 50 16 L 57 28 L 66 20 L 64 34 Z" fill="{GOLD}"/>'
        f'<circle cx="50" cy="44" r="8" fill="{INK}"/>'
        f'<path d="M 40 52 Q 50 48 60 52 L 68 80 L 32 80 Z" fill="{INK}"/>'
        f'<line x1="50" y1="56" x2="50" y2="76" stroke="{IVORY}" stroke-width="2.5"/>'
    ),
    "amazon": (  # Queen + Knight: horse head wearing the coronet
        f'<path d="M 38 78 L 40 54 Q 31 50 33 40 Q 37 27 52 25 L 50 19 L 58 25 Q 69 31 69 46 L 65 78 Z" fill="{INK}"/>'
        f'<circle cx="52" cy="34" r="2.6" fill="{IVORY}"/>'
        f'<path d="M 40 24 L 38 12 L 46 19 L 52 10 L 56 20 L 64 14 L 61 24 Q 50 18 40 24 Z" fill="{GOLD}"/>'
    ),
    # ---- The enemy King: oversized jagged crown, red gem ----
    "king": (
        f'<path d="M 26 64 L 22 30 L 36 44 L 44 24 L 50 42 L 56 24 L 64 44 L 78 30 L 74 64 Z" fill="{INK}"/>'
        f'<circle cx="50" cy="52" r="5" fill="{RED}"/>'
        f'<path d="M 26 68 L 74 68 L 78 80 L 22 80 Z" fill="{INK}"/>'
        f'<path d="M 46 10 L 54 10 L 54 16 L 60 16 L 60 23 L 54 23 L 54 30 L 46 30 L 46 23 L 40 23 L 40 16 L 46 16 Z" fill="{RED}"/>'
    ),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for pid, body in EMBLEMS.items():
        (OUT / f"{pid}.svg").write_text(svg(body) + "\n")
    print(f"wrote {len(EMBLEMS)} SVGs to {OUT}")
    assert len(EMBLEMS) == 28, f"expected 28, got {len(EMBLEMS)}"


if __name__ == "__main__":
    main()
