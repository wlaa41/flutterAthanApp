#!/usr/bin/env python3
"""Builds the Al-Kahf Journey's fonts: four weights of Baloo Bhaijaan 2, and
one sign from Noto Naskh Arabic.

Upstream ships one variable file whose strokes overlap, and the text engine
Flutter uses on Android draws small notches where they cross. Here each weight
is pinned and its outlines are merged, so the letters draw clean on every
phone. Nothing else about the font is changed.

Baloo Bhaijaan 2 is by Ek Type, under the SIL Open Font License 1.1
(asset/fonts/baloo_bhaijaan2_OFL.txt). It declares no reserved font name.

Baloo has no drawing for U+FDFA, the blessing written after the Prophet's name,
and the meanings the game quotes use it. That one sign is taken from Noto Naskh
Arabic (The Noto Project Authors, SIL Open Font License 1.1,
asset/fonts/noto_naskh_arabic_OFL.txt) and saved as its own small font under
another name, so a phone that lacks the sign still shows it.

Needs: pip install fonttools skia-pathops
Run:   python3 tools/make_journey_fonts.py
"""

import hashlib
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tools/fonts/BalooBhaijaan2-wght.ttf"
SOURCE_SHA256 = "3e9f07fbc796c0ddcb3e6e0aa26f9c86741d9f5b7f5cb72f4ed3c06e55a19336"
WEIGHTS = (400, 600, 700, 800)

SIGNS_SOURCE = ROOT / "tools/fonts/NotoNaskhArabic-wght.ttf"
SIGNS_SHA256 = "67b5a525a661b607971fbd3f96a81b89d3a768e74534fca84f18ac97e6fab72f"
SIGNS = (0xFDFA,)
SIGNS_NAME = "Journey Signs"


def signs() -> int:
    """One static font holding only [SIGNS], under a name of its own."""
    data = SIGNS_SOURCE.read_bytes()
    if hashlib.sha256(data).hexdigest() != SIGNS_SHA256:
        print(f"{SIGNS_SOURCE} is not the recorded upstream file.", file=sys.stderr)
        return 1
    font = instancer.instantiateVariableFont(TTFont(SIGNS_SOURCE), {"wght": 400})
    options = subset.Options()
    options.layout_features = []
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
    options.notdef_outline = True
    picker = subset.Subsetter(options)
    picker.populate(unicodes=SIGNS)
    picker.subset(font)
    cmap = font.getBestCmap()
    if sorted(cmap) != sorted(SIGNS):
        print(f"the signs font holds {sorted(map(hex, cmap))}.", file=sys.stderr)
        return 1
    # A changed font does not keep the name of the one it came from.
    for record in font["name"].names:
        if record.nameID in (1, 4):
            record.string = SIGNS_NAME
        elif record.nameID == 6:
            record.string = SIGNS_NAME.replace(" ", "")
        elif record.nameID == 3:
            record.string = f"{SIGNS_NAME}: U+FDFA from Noto Naskh Arabic"
    font["head"].created = font["head"].modified = 0
    font.recalcTimestamp = False
    out = ROOT / "asset/fonts/journey_signs.ttf"
    font.save(out)
    print(f"{out.relative_to(ROOT)}: {out.stat().st_size} bytes, "
          f"{len(font.getGlyphOrder())} glyphs, {font['name'].getDebugName(4)}")
    return 0


def main() -> int:
    data = SOURCE.read_bytes()
    if hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
        print(f"{SOURCE} is not the recorded upstream file.", file=sys.stderr)
        return 1
    for weight in WEIGHTS:
        font = instancer.instantiateVariableFont(
            TTFont(SOURCE),
            {"wght": weight},
            overlap=instancer.OverlapMode.REMOVE,
            updateFontNames=True,
        )
        if "fvar" in font or font["OS/2"].usWeightClass != weight:
            print(f"weight {weight} was not pinned.", file=sys.stderr)
            return 1
        # The same bytes on every run, whatever the clock says.
        font["head"].created = font["head"].modified = 0
        out = ROOT / f"asset/fonts/baloo_{weight}.ttf"
        font.recalcTimestamp = False
        font.save(out)
        print(f"{out.relative_to(ROOT)}: {out.stat().st_size} bytes, "
              f"{len(font.getGlyphOrder())} glyphs, "
              f"{font['name'].getDebugName(4)}")
    return signs()


if __name__ == "__main__":
    sys.exit(main())
