#!/usr/bin/env python3
"""Builds the Al-Kahf Journey's fonts: four weights of Baloo Bhaijaan 2.

Upstream ships one variable file whose strokes overlap, and the text engine
Flutter uses on Android draws small notches where they cross. Here each weight
is pinned and its outlines are merged, so the letters draw clean on every
phone. Nothing else about the font is changed.

Baloo Bhaijaan 2 is by Ek Type, under the SIL Open Font License 1.1
(asset/fonts/baloo_bhaijaan2_OFL.txt). It declares no reserved font name.

Needs: pip install fonttools skia-pathops
Run:   python3 tools/make_journey_fonts.py
"""

import hashlib
import pathlib
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tools/fonts/BalooBhaijaan2-wght.ttf"
SOURCE_SHA256 = "3e9f07fbc796c0ddcb3e6e0aa26f9c86741d9f5b7f5cb72f4ed3c06e55a19336"
WEIGHTS = (400, 600, 700, 800)


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
    return 0


if __name__ == "__main__":
    sys.exit(main())
