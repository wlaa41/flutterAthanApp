#!/usr/bin/env python3
"""Writes asset/quran/hafs_pages.json: where every line of the printed
Madinah mushaf begins.

The app's Hafs text comes from the King Fahd Complex, one verse at a time.
That is enough for flowing text, not for a page that looks like the print:
the print has 604 pages of 15 lines, and each line starts at a fixed word.
quran.com publishes that word-by-word layout through its API. This tool
fetches it, matches it to the bundled text letter for letter, and stores for
each line of each page the first word of the line.

    python3 tools/build_mushaf_pages.py --pages DIR [--fetch]

DIR holds one answer per page, p1.json to p604.json. With --fetch the missing
ones are downloaded first (about 12 MB in all).

A line is one of:
    n >= 0   text; n is the number of its first token, counting through the
             whole mushaf. The tokens of a verse are its words, split at
             spaces, and then its end mark.
    -s       the name banner of surah s
    -(200+s) the basmalah line before surah s
    null     no line (the first two pages have eight lines)
"""
import argparse
import datetime
import hashlib
import json
import os
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGES = 604
LINES = 15
API = (
    "https://api.quran.com/api/v4/verses/by_page/{page}?words=true"
    "&word_fields=line_number,page_number,text_qpc_hafs,char_type_name,position,code_v2"
    "&per_page=50&fields=verse_key"
)

# Lines the print sets centred instead of from margin to margin. These are
# facts about the printed pages, taken from the list quran.com's own reader
# uses (quran.com-frontend-next, src/components/Verse/pageUtils.ts). Every
# line of pages 1 and 2 is centred as well.
CENTRED = {
    255: [2],
    528: [9],
    534: [6],
    545: [6],
    586: [1],
    593: [2],
    594: [5],
    600: [10],
    602: [5, 15],
    603: [10, 15],
    604: [4, 9, 14, 15],
}


def fetch(folder):
    os.makedirs(folder, exist_ok=True)
    for page in range(1, PAGES + 1):
        path = os.path.join(folder, f"p{page}.json")
        if os.path.exists(path):
            continue
        for attempt in range(4):
            try:
                request = urllib.request.Request(
                    API.format(page=page), headers={"User-Agent": "AthanApp build"}
                )
                data = urllib.request.urlopen(request, timeout=60).read()
                json.loads(data)
                with open(path, "wb") as handle:
                    handle.write(data)
                break
            except Exception as error:  # noqa: BLE001 - retried, then reported
                if attempt == 3:
                    raise SystemExit(f"page {page}: {error}")
                time.sleep(2 * (attempt + 1))


def letters(text):
    """The text without the spaces that only separate or attach marks."""
    return text.replace(" ", "").replace(" ", "")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pages", required=True)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--text", default=os.path.join(ROOT, "asset", "quran", "hafs.json"))
    parser.add_argument("--out", default=os.path.join(ROOT, "asset", "quran", "hafs_pages.json"))
    parser.add_argument("--fetched", help="the day the pages were fetched; today for a new record")
    args = parser.parse_args()
    if args.fetch:
        fetch(args.pages)

    with open(args.text, encoding="utf-8") as handle:
        surahs = json.load(handle)["surahs"]

    # Number every token of the bundled text.
    first_token = {}
    count = 0
    for s, surah in enumerate(surahs, 1):
        for a, row in enumerate(surah, 1):
            first_token[(s, a)] = count
            count += len(row[0].split(" ")) + 1

    slots = {}  # (page, line) -> number of its first token
    seen = set()
    notes = {"end mark moved to its word's line": [], "words split differently": []}

    def place(page, line, token):
        key = (page, line)
        if key not in slots or token < slots[key]:
            slots[key] = token

    for page in range(1, PAGES + 1):
        with open(os.path.join(args.pages, f"p{page}.json"), encoding="utf-8") as handle:
            verses = json.load(handle)["verses"]
        for verse in verses:
            s, a = map(int, verse["verse_key"].split(":"))
            if (s, a) in seen:
                raise SystemExit(f"{s}:{a} is listed twice")
            seen.add((s, a))
            mine = surahs[s - 1][a - 1][0].split(" ")
            words = [w for w in verse["words"] if w["char_type_name"] == "word"]
            end = verse["words"][-1]
            if end["char_type_name"] != "end" or len(words) != len(verse["words"]) - 1:
                raise SystemExit(f"{s}:{a} does not end with one end mark")
            if letters("".join(mine)) != letters("".join(w["text_qpc_hafs"] for w in words)):
                raise SystemExit(f"{s}:{a} differs from the bundled text")
            if len(mine) != len(words):
                notes["words split differently"].append(f"{s}:{a}")

            # Where each of my tokens starts, counted in letters.
            starts = {}
            at = 0
            for index, token in enumerate(mine):
                starts[at] = index
                at += len(letters(token))
            base = first_token[(s, a)]
            at = 0
            previous = None
            for word in words:
                here = (word["page_number"], word["line_number"])
                if here != previous:
                    if previous is not None and here < previous:
                        raise SystemExit(f"{s}:{a} runs backwards")
                    if at not in starts:
                        raise SystemExit(f"{s}:{a} breaks a line inside a word")
                    place(here[0], here[1], base + starts[at])
                    previous = here
                at += len(letters(word["text_qpc_hafs"]))
            mark = (end["page_number"], end["line_number"])
            if mark < previous:
                # One mark in the source sits a line above its own word.
                notes["end mark moved to its word's line"].append(f"{s}:{a}")
                mark = previous
            if mark != previous:
                place(mark[0], mark[1], base + len(mine))

    if len(seen) != sum(len(surah) for surah in surahs):
        raise SystemExit("some verses are missing from the pages")

    # Lines must begin in mushaf order.
    ordered = [slots[key] for key in sorted(slots)]
    if ordered != sorted(ordered) or len(set(ordered)) != len(ordered) or ordered[0] != 0:
        raise SystemExit("line starts are not in order")

    # A slot without words is a surah banner or a basmalah. Walk back from the
    # first word of each surah to name them.
    def before(page, line):
        return (page, line - 1) if line > 1 else (page - 1, LINES)

    special = {}
    for s in range(1, len(surahs) + 1):
        start = first_token[(s, 1)]
        key = next(k for k, v in slots.items() if v == start)
        wanted = [-s] if s in (1, 9) else [-(200 + s), -s]
        for value in wanted:
            key = before(*key)
            if key in slots or key in special or key[0] < 1:
                raise SystemExit(f"surah {s}: no free line for its heading")
            special[key] = value

    pages = []
    for page in range(1, PAGES + 1):
        row = []
        for line in range(1, LINES + 1):
            key = (page, line)
            row.append(slots.get(key, special.get(key)))
        pages.append(row)
    unused = [(p + 1, l + 1) for p, row in enumerate(pages) for l, v in enumerate(row) if v is None]
    if any(page > 2 for page, _ in unused):
        raise SystemExit(f"unexplained empty lines: {unused[:10]}")

    centred = {1: list(range(1, 9)), 2: list(range(1, 9)), **CENTRED}
    for page, lines in centred.items():
        for line in lines:
            if pages[page - 1][line - 1] is None:
                raise SystemExit(f"centred line {page}:{line} does not exist")

    head = {
        "format": 1,
        "edition": "hafs",
        "source": "quran.com API v4, verses/by_page, word line numbers of the Madinah mushaf",
        "tokens": count,
        "centred": {str(page): lines for page, lines in sorted(centred.items())},
    }
    body = ",\n".join(json.dumps(row, separators=(",", ":")) for row in pages)
    text = json.dumps(head, ensure_ascii=False, separators=(",", ":"))[:-1] + ',"pages":[\n' + body + "\n]}\n"
    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(text)

    text_lines = sum(1 for row in pages for v in row if v is not None and v >= 0)
    print(f"{PAGES} pages, {text_lines} text lines, {len(special)} headings, {count} tokens")
    for name, items in notes.items():
        print(f"{name}: {len(items)} {' '.join(items)}")
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    print("sha256", digest, len(text.encode("utf-8")), "bytes")

    # What was built, from what, and what the tool had to decide.
    manifest_path = os.path.join(ROOT, "tools", "mushaf_pages_manifest.json")
    fetched = args.fetched
    if fetched is None and os.path.exists(manifest_path):
        with open(manifest_path, encoding="utf-8") as handle:
            fetched = json.load(handle).get("fetched")
    manifest = {
        "asset": "asset/quran/hafs_pages.json",
        "asset_bytes": len(text.encode("utf-8")),
        "asset_sha256": digest,
        "source": API.replace("{page}", "<1 to 604>"),
        "fetched": fetched or datetime.date.today().isoformat(),
        "centred_lines_from": "quran.com-frontend-next, src/components/Verse/pageUtils.ts",
        "pages": PAGES,
        "text_lines": text_lines,
        "headings": len(special),
        "tokens": count,
        "end_mark_moved_to_its_words_line": notes["end mark moved to its word's line"],
        "verses_split_into_words_differently": notes["words split differently"],
    }
    with open(manifest_path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")


if __name__ == "__main__":
    sys.exit(main())
