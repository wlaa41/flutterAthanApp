#!/usr/bin/env python3
"""Builds the bundled mushaf assets in asset/quran from the King Fahd Complex data.

The Quran text and the fonts are never edited. Each ayah keeps the exact code
points published by the King Fahd Glorious Quran Printing Complex (KFGQPC); the
script only removes the trailing ayah-number marker (the reader draws it again
from the ayah number) and repacks the rows. Fonts are copied byte for byte.

Inputs
  --kfgqpc DIR      checkout of https://github.com/thetruetruth/quran-data-kfgqpc
                    (a mirror of https://qurancomplex.gov.sa/en/techquran/dev/)
  --tajweed FILE    https://api.quran.com/api/v4/quran/verses/uthmani_tajweed
  --crosscheck FILE https://api.quran.com/api/v4/quran/verses/qpc_hafs
                    (an independent copy of the Hafs text; must match exactly)

Run:  python3 tools/build_quran_assets.py --kfgqpc ... --tajweed ... --crosscheck ...
"""
import argparse
import collections
import difflib
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import unicodedata

EDITIONS = [
    # id, data file, font file, expected ayah total (the counting system of that mushaf)
    ("hafs", "hafs/data/hafsData_v18.json", "hafs/font/hafs.18.ttf", 6236),
    ("shouba", "shouba/data/ShoubaData08.json", "shouba/font/shouba.8.ttf", 6236),
    ("warsh", "warsh/data/warshData_v10.json", "warsh/font/warsh.10.ttf", 6214),
    ("qaloon", "qaloon/data/QaloonData_v10.json", "qaloon/font/qaloon.10.ttf", 6214),
    ("doori", "doori/data/DooriData_v09.json", "doori/font/doori.9.ttf", 6217),
    ("soosi", "soosi/data/SoosiData09.json", "soosi/font/soosi.9.ttf", 6217),
    ("bazzi", "bazzi/data/BazziData_v07.json", "bazzi/font/bazzi.7.ttf", 6220),
    ("qumbul", "qumbul/data/QumbulData_v07.json", "qumbul/font/qumbul.7.ttf", 6220),
]
HAFS_COUNTS = [7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6]
DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
MARKER = re.compile(r"^(.*?)[  ]*([٠-٩]+)\s*$", re.S)
TAJWEED_RULES = [
    "ham_wasl", "slnt", "laam_shamsiyah", "madda_normal", "madda_permissible",
    "madda_necessary", "madda_obligatory", "qalaqah", "ikhafa_shafawi", "ikhafa",
    "idgham_shafawi", "iqlab", "idgham_ghunnah", "idgham_wo_ghunnah",
    "idgham_mutajanisayn", "idgham_mutaqaribayn", "ghunnah",
]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def is_mark(ch):
    return unicodedata.category(ch) in ("Mn", "Mc", "Me")


def load_edition(root, data_file):
    rows = json.load(io.open(os.path.join(root, data_file), encoding="utf-8-sig"))
    surahs = [[] for _ in range(114)]
    for row in rows:
        surah = int(row.get("sura_no", row.get("sora")))
        number = int(row["aya_no"])
        match = MARKER.match(row["aya_text"])
        if not match:
            raise SystemExit(f"{data_file}: no ayah marker in {surah}:{number}")
        text, marker = match.group(1), int(match.group(2).translate(DIGITS))
        if marker != number:
            raise SystemExit(f"{data_file}: marker {marker} != ayah {surah}:{number}")
        if not text.strip() or re.search("[٠-٩]", text):
            raise SystemExit(f"{data_file}: unexpected body in {surah}:{number}")
        if any(ord(c) > 0xFFFF for c in text):
            raise SystemExit(f"{data_file}: non-BMP character in {surah}:{number}")
        if len(surahs[surah - 1]) != number - 1:
            raise SystemExit(f"{data_file}: ayah order broken at {surah}:{number}")
        page = int(re.search(r"\d+", str(row["page"])).group(0))
        surahs[surah - 1].append({"t": text, "p": page, "j": int(row["jozz"])})
    if any(not s for s in surahs):
        raise SystemExit(f"{data_file}: a surah is empty")
    return surahs


# ---------------------------------------------------------------- numbering map
FOLD = {}
for src in "أإآٱٲٳ":
    FOLD[src] = "ا"
for src in "ىئیٮ":
    FOLD[src] = "ي"
FOLD["ؤ"] = "و"
FOLD["ة"] = "ه"


def word_keys(text):
    keys = []
    for word in re.split(r"[\s ]+", text):
        key = "".join(
            FOLD.get(c, c)
            for c in word
            if unicodedata.category(c) == "Lo" and c not in "ءـ"
        )
        if key:
            keys.append(key)
    return keys


def map_to_hafs(hafs_surah, other_surah):
    """For every ayah of another riwaya, the Hafs ayah range holding the same words."""
    h_words, h_owner = [], []
    for index, ayah in enumerate(hafs_surah):
        for key in word_keys(ayah["t"]):
            h_words.append(key)
            h_owner.append(index + 1)
    o_words, o_owner = [], []
    for index, ayah in enumerate(other_surah):
        for key in word_keys(ayah["t"]):
            o_words.append(key)
            o_owner.append(index + 1)
    matcher = difflib.SequenceMatcher(None, o_words, h_words, autojunk=False)
    target = [None] * len(o_words)
    for tag, a0, a1, b0, b1 in matcher.get_opcodes():
        if tag == "equal":
            for k in range(a1 - a0):
                target[a0 + k] = b0 + k
        elif a1 > a0 and b1 > b0:  # same passage spelled differently
            for k in range(a1 - a0):
                target[a0 + k] = b0 + min(b1 - b0 - 1, k * (b1 - b0) // (a1 - a0))
    overlap = collections.defaultdict(collections.Counter)
    for position, hafs_position in enumerate(target):
        if hafs_position is not None:
            overlap[o_owner[position]][h_owner[hafs_position]] += 1
    h_len = collections.Counter(h_owner)
    o_len = collections.Counter(o_owner)
    ranges = []
    for number in range(1, len(other_surah) + 1):
        hits = overlap.get(number)
        if not hits:
            raise SystemExit(f"no Hafs words found for ayah {number}")
        keep = [
            h for h, n in hits.items()
            if n * 2 >= h_len[h] or n * 2 >= o_len[number]
        ] or [hits.most_common(1)[0][0]]
        ranges.append((min(keep), max(keep)))
    for (a0, a1), (b0, b1) in zip(ranges, ranges[1:]):
        if b0 < a1 or a0 > a1:
            raise SystemExit(f"numbering map is not monotonic: {ranges}")
    return ranges


# ------------------------------------------------------------------- tajweed
TAG = re.compile(r"<tajweed class=([a-z_]+)>|</tajweed>")
DROP = set("ـ‌‍‎‏")
CANON = {
    "ْ": "ۡ", "ٲ": "ٰ", " ": " ",
    "ى": "Y", "ي": "Y", "ٮ": "Y",
    "ً": "F", "ٗ": "F", "ࣰ": "F",
    "ٌ": "D", "ٞ": "D", "ࣱ": "D",
    "ٍ": "K", "ٖ": "K", "ࣲ": "K",
    "۟": "Z", "۠": "Z",
}


def parse_tajweed(markup, key):
    markup = re.sub(r"\s*<span class=end>[^<]*</span>\s*$", "", markup)
    if key == "32:3" and markup.count("<tajweed") != markup.count("</tajweed>"):
        # Upstream lost one opening tag in this verse; restore it.
        markup = markup.replace(
            ">ٮٰ</tajweed>",
            "<tajweed class=madda_normal>ٮٰ</tajweed>",
        )
    parts, spans, stack, position, length = [], [], [], 0, 0
    for match in TAG.finditer(markup):
        piece = markup[position:match.start()]
        parts.append(piece)
        length += len(piece)
        position = match.end()
        if match.group(1):
            stack.append((match.group(1), length))
        else:
            rule, start = stack.pop()
            spans.append((start, length, rule))
    parts.append(markup[position:])
    if stack or "<" in "".join(parts) or ">" in "".join(parts):
        raise SystemExit(f"unbalanced tajweed markup in {key}")
    return "".join(parts), spans


def canonical(text):
    tokens, origin = [], []
    for index, ch in enumerate(text):
        if ch in DROP:
            continue
        tokens.append(CANON.get(ch, ch))
        origin.append(index)
    return tokens, origin


def transfer_spans(source, spans, target, stats):
    """Moves rule spans from quran.com's spelling onto the KFGQPC spelling."""
    # quran.com writes the alef before its tanween; the Complex writes it after.
    source = re.sub("\u0627(\u064b)", "\\1\u0627", source)
    s_tokens, s_origin = canonical(source)
    t_tokens, t_origin = canonical(target)
    opcodes = difflib.SequenceMatcher(None, s_tokens, t_tokens, autojunk=False).get_opcodes()

    def boundary(position):
        for tag, a0, a1, b0, b1 in opcodes:
            if a0 <= position <= a1:
                if tag == "equal":
                    return b0 + (position - a0)
                if position == a0:
                    return b0
                if position == a1:
                    return b1
                return b0 + round((position - a0) * (b1 - b0) / (a1 - a0))
        return len(t_tokens)

    def to_canonical(index):  # first canonical position at or after a source index
        lo, hi = 0, len(s_origin)
        while lo < hi:
            mid = (lo + hi) // 2
            if s_origin[mid] < index:
                lo = mid + 1
            else:
                hi = mid
        return lo

    def to_target(position):
        return t_origin[position] if position < len(t_origin) else len(target)

    letters = lambda tokens: [t for t in tokens if len(t) == 1 and not is_mark(t) and t != " "]
    result = []
    for start, end, rule in sorted(spans):
        c0, c1 = to_canonical(start), to_canonical(end)
        b0, b1 = boundary(c0), boundary(c1)
        if b1 <= b0:
            stats["empty"] += 1
            continue
        s_letters, t_letters = letters(s_tokens[c0:c1]), letters(t_tokens[b0:b1])
        if s_letters != t_letters:
            # A dagger alef sits on a tatweel in one spelling and on a ya in the other.
            carrier = "\u0640" in source[start:end]
            if not (carrier and [x for x in s_letters if x != "Y"] == [x for x in t_letters if x != "Y"]):
                stats["letters_differ"] += 1
                continue
        t0, t1 = to_target(b0), to_target(b1)
        # Colour whole letters: a letter is painted together with its marks.
        if is_mark(target[t0]):
            forward = t0
            while forward < t1 and is_mark(target[forward]):
                forward += 1
            if forward < t1:
                t0 = forward
            else:
                while t0 > 0 and is_mark(target[t0]):
                    t0 -= 1
        while t1 < len(target) and is_mark(target[t1]):
            t1 += 1
        if result and t0 < result[-1][1]:
            t0 = result[-1][1]
        while t0 < t1 and target[t0] in "  ":
            t0 += 1
        if t1 <= t0:
            stats["swallowed"] += 1
            continue
        result.append((t0, t1, rule))
        stats["kept"] += 1
    return result


def dump(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def write_json(path, head, rows_name, groups):
    """Writes plain JSON with one ayah per line, so the text can be read and
    compared in the repository. The files are deliberately not gzipped: the
    Android build unpacks any *.gz asset and drops the extension, and the app
    would then look for a file that is no longer there. The APK compresses
    them anyway."""
    lines = [dump(head)[:-1] + f',"{rows_name}":[']
    for index, group in enumerate(groups):
        lines.append("[")
        lines += [dump(row) + ("," if n + 1 < len(group) else "") for n, row in enumerate(group)]
        lines.append("]" + ("," if index + 1 < len(groups) else ""))
    lines.append("]}")
    raw = ("\n".join(lines) + "\n").encode("utf-8")
    json.loads(raw)  # must stay valid JSON
    with open(path, "wb") as handle:
        handle.write(raw)
    return len(raw)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--kfgqpc", required=True)
    parser.add_argument("--tajweed", required=True)
    parser.add_argument("--crosscheck", required=True)
    parser.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "asset", "quran"))
    args = parser.parse_args()
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)
    manifest = {
        "source": "https://github.com/thetruetruth/quran-data-kfgqpc",
        "origin": "https://qurancomplex.gov.sa/en/techquran/dev/",
        "tajweed": "https://api.quran.com/api/v4/quran/verses/uthmani_tajweed",
        "editions": {},
    }
    try:
        manifest["source_commit"] = subprocess.check_output(
            ["git", "-C", args.kfgqpc, "rev-parse", "HEAD"], text=True).strip()
    except Exception:
        manifest["source_commit"] = "unknown"

    loaded = {}
    for edition, data_file, font_file, expected in EDITIONS:
        surahs = load_edition(args.kfgqpc, data_file)
        total = sum(len(s) for s in surahs)
        if total != expected:
            raise SystemExit(f"{edition}: {total} ayat, expected {expected}")
        loaded[edition] = surahs
    hafs = loaded["hafs"]
    if [len(s) for s in hafs] != HAFS_COUNTS:
        raise SystemExit("hafs: per-surah ayah counts are not the Kufi count")

    # An independent copy of the same KFGQPC Hafs release must agree exactly.
    check = json.load(open(args.crosscheck, encoding="utf-8"))["verses"]
    if len(check) != 6236:
        raise SystemExit("crosscheck: expected 6236 verses")
    for verse in check:
        surah, number = map(int, verse["verse_key"].split(":"))
        body = MARKER.match(verse["text_qpc_hafs"]).group(1)
        if body != hafs[surah - 1][number - 1]["t"]:
            raise SystemExit(f"crosscheck mismatch at {verse['verse_key']}")
    print("hafs: 6236 ayat identical to the quran.com copy of the KFGQPC text")

    for edition, data_file, font_file, expected in EDITIONS:
        surahs = loaded[edition]
        remapped = 0
        payload_surahs = []
        for index, surah in enumerate(surahs):
            identity = len(surah) == len(hafs[index])
            ranges = map_to_hafs(hafs[index], surah) if edition != "hafs" else None
            if ranges is not None:
                identity = all(r == (n, n) for n, r in enumerate(ranges, 1)) and identity
            rows = []
            for number, ayah in enumerate(surah, 1):
                row = [ayah["t"], ayah["p"], ayah["j"]]
                if not identity:
                    row += list(ranges[number - 1])
                    if ranges[number - 1] != (number, number):
                        remapped += 1
                rows.append(row)
            payload_surahs.append(rows)
        if edition in ("hafs", "shouba") and remapped:
            raise SystemExit(f"{edition}: Kufi numbering should map one to one")
        # The basmalah of each mushaf, in its own spelling, from An-Naml 27:30.
        basmalah = None
        for ayah in surahs[26]:
            words = re.split(r"[  ]+", ayah["t"])
            for position in range(len(words) - 3):
                if word_keys(" ".join(words[position:position + 4])) == ["بسم", "الله", "الرحمن", "الرحيم"]:
                    basmalah = " ".join(words[position:position + 4])
        if basmalah is None:
            raise SystemExit(f"{edition}: basmalah not found in An-Naml")
        if edition == "hafs" and basmalah != hafs[0][0]["t"]:
            raise SystemExit("hafs: basmalah of 27:30 differs from 1:1")
        target = os.path.join(out, f"{edition}.json")
        size = write_json(target, {
            "format": 1, "id": edition, "count": expected, "basmalah": basmalah,
        }, "surahs", payload_surahs)
        font_target = os.path.join(out, "..", "fonts", f"kfgqpc_{edition}.ttf")
        os.makedirs(os.path.dirname(font_target), exist_ok=True)
        shutil.copyfile(os.path.join(args.kfgqpc, font_file), font_target)
        manifest["editions"][edition] = {
            "data": data_file,
            "data_sha256": sha256(os.path.join(args.kfgqpc, data_file)),
            "font": font_file,
            "font_sha256": sha256(font_target),
            "ayat": expected,
            "ayat_numbered_differently_from_hafs": remapped,
            "asset": f"asset/quran/{edition}.json",
            "asset_sha256": sha256(target),
            "asset_bytes": size,
        }
        if sha256(font_target) != sha256(os.path.join(args.kfgqpc, font_file)):
            raise SystemExit(f"{edition}: font copy differs from the source")
        print(f"{edition}: {expected} ayat, {remapped} numbered differently from Hafs, "
              f"{os.path.getsize(target)} bytes")

    tajweed = json.load(open(args.tajweed, encoding="utf-8"))["verses"]
    if len(tajweed) != 6236:
        raise SystemExit("tajweed: expected 6236 verses")
    stats = collections.Counter()
    all_spans = []
    for verse in tajweed:
        surah, number = map(int, verse["verse_key"].split(":"))
        source, spans = parse_tajweed(verse["text_uthmani_tajweed"], verse["verse_key"])
        stats["source_spans"] += len(spans)
        moved = transfer_spans(source, spans, hafs[surah - 1][number - 1]["t"], stats)
        flat = []
        for start, end, rule in moved:
            flat += [start, end - start, TAJWEED_RULES.index(rule)]
        all_spans.append(flat)
    # One group per surah on disk; the app reads them as one run of 6236 ayat.
    by_surah, position = [], 0
    for count in HAFS_COUNTS:
        by_surah.append(all_spans[position:position + count])
        position += count
    target = os.path.join(out, "hafs_tajweed.json")
    write_json(target, {"format": 1, "rules": TAJWEED_RULES}, "surahs", by_surah)
    manifest["tajweed_transfer"] = dict(stats)
    manifest["tajweed_asset_sha256"] = sha256(target)
    print("tajweed:", dict(stats), os.path.getsize(target), "bytes")

    with open(os.path.join(os.path.dirname(__file__), "quran_assets_manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
