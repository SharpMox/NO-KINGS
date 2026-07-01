# Generates flat token sprites (256x256 PNG, transparent bg) for the MVP pieces:
# neutral ivory disc + dark ring + the piece glyph. The game tints per side at
# runtime. Rerun after changing the piece set:
#   python3 tools/generate-piece-tokens.py
# ponytail: placeholder art — swap the PNGs for real art anytime, same filenames.
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game/assets/pieces"
SIZE = 256

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/System/Library/Fonts/Apple Symbols.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]


def font_for(text: str, size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        try:
            f = ImageFont.truetype(path, size)
        except OSError:
            continue
        if all(f.getmask(ch).getbbox() for ch in text):
            return f
    raise SystemExit(f"no installed font renders {text!r}")


def main() -> None:
    pieces = json.loads((ROOT / "game/data/pieces.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    for pid, p in pieces.items():
        img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        m = 12
        d.ellipse([m, m, SIZE - m, SIZE - m], fill=(238, 228, 205, 255),
                  outline=(40, 34, 26, 255), width=10)
        glyph = p["glyph"]
        fsize = 150 if len(glyph) == 1 else (110 if len(glyph) == 2 else 80)
        font = font_for(glyph, fsize)
        box = d.textbbox((0, 0), glyph, font=font)
        pos = ((SIZE - box[2] - box[0]) / 2, (SIZE - box[3] - box[1]) / 2)
        d.text(pos, glyph, font=font, fill=(40, 34, 26, 255))
        img.save(OUT / f"{pid}.png")
    print(f"wrote {len(pieces)} tokens to {OUT}")


if __name__ == "__main__":
    main()
