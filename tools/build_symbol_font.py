"""Rebuild game/assets/fonts/NoKingsSymbols.ttf (see that folder's README).

The symbols Pixel Operator lacks, subset from four Noto fonts (OFL 1.1), merged into one
face, rescaled to Pixel Operator's 1600 units/em and given its exact vertical metrics
(ascent 1300, descent 300, gap 72), so chaining it as a fallback never changes a line's
height. Keep GLYPHS in step with GLYPHS in game/tests/test_theme.gd.

  pip install fonttools
  python3 tools/build_symbol_font.py <dir with the four unhinted Noto TTFs>
"""
import os
import sys
from fontTools import subset
from fontTools.merge import Merger
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem

GLYPHS = ("← → ✦ ☰ ⚠ ⇄ ★ ⚑ ⓘ ◆ ✕ ⟲ ⧖ ♟ ▴ ● ∩ ⚔ ○ ▾ − θ "
          "‼ ↩ ↯ ⇢ ≋ ⊘ ▣ ▸ ◈ ◎ ✚ ✳ ✴ ✹ ➜ ➤ ⧗ ⨯ ♚ ♛ ♜ ♝ ♞ ½").split()
# First source that has a glyph supplies it. From github.com/notofonts/notofonts.github.io,
# fonts/<Family>/unhinted/ttf/.
SOURCES = ["NotoSansSymbols2-Regular.ttf", "NotoSansMath-Regular.ttf",
           "NotoSansSymbols-Regular.ttf", "NotoSans-Regular.ttf"]
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "fonts", "NoKingsSymbols.ttf")

left = [ord(c) for c in GLYPHS]
parts = []
for src in SOURCES:
    path = os.path.join(sys.argv[1], src)
    cmap = TTFont(path).getBestCmap()
    take = [u for u in left if u in cmap]
    left = [u for u in left if u not in cmap]
    if not take:
        continue
    opts = subset.Options()
    opts.layout_features = []
    opts.drop_tables += ["GSUB", "GPOS", "GDEF", "MATH", "STAT", "DSIG", "vhea", "vmtx"]
    opts.hinting = False
    opts.name_IDs = []
    font = TTFont(path)
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=take)
    sub.subset(font)
    parts.append(font)
assert not left, "no source covers: " + "".join(map(chr, left))

tmp = []
for i, font in enumerate(parts): # Merger takes paths
    tmp.append("%s.part%d.ttf" % (OUT, i))
    font.save(tmp[-1])
merged = Merger().merge(tmp)
for p in tmp:
    os.remove(p)

scale_upem(merged, 1600)
hhea, os2 = merged["hhea"], merged["OS/2"]
hhea.ascent, hhea.descent, hhea.lineGap = 1300, -300, 72
os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = 1300, -300, 72
os2.usWinAscent, os2.usWinDescent = 1300, 300
os2.fsSelection |= 1 << 7 # USE_TYPO_METRICS, as Pixel Operator sets it
name = merged["name"]
name.names = []
for nid, val in {
    0: "Copyright 2022 The Noto Project Authors (https://github.com/notofonts). "
       "Copyright 2022 Google LLC. Subset and merged for NO KINGS.",
    1: "NoKings Symbols", 2: "Regular", 3: "NoKingsSymbols-Regular",
    4: "NoKings Symbols Regular", 5: "Version 1.0", 6: "NoKingsSymbols-Regular",
    13: "This Font Software is licensed under the SIL Open Font License, Version 1.1.",
    14: "https://openfontlicense.org",
}.items():
    name.setName(val, nid, 3, 1, 0x409)
merged.save(OUT)
print("wrote", os.path.normpath(OUT), os.path.getsize(OUT), "bytes")
