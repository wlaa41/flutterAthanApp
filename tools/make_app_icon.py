#!/usr/bin/env python3
"""Draws the Athan app icon and writes every Android and iOS size.

The mark (keel arch, inner dome, crescent, two minarets) is built from pen
strokes whose width follows a pressure curve, in the OW yellow-green on the OW
dark ground. Needs rsvg-convert and Pillow.

Run from the repository root:  python3 tools/make_app_icon.py
"""
import io
import math
import os
import subprocess

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GREEN_TOP, GREEN, GREEN_DEEP = "#C9F07F", "#9BD43B", "#7FB728"
DARK_LIFT, DARK, DARK_EDGE = "#222B1C", "#12160F", "#0A0C09"
AXIS = 166.0  # mirror axis, in the units the mark was drawn in


# ------------------------------------------------------------------ pen strokes
def cubic(p0, p1, p2, p3, n=60):
    pts = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


def join(*parts):
    out = []
    for part in parts:
        for p in part:
            if not out or abs(out[-1][0] - p[0]) + abs(out[-1][1] - p[1]) > 1e-6:
                out.append(p)
    return out


def resample(pts, n):
    d = [0.0]
    for a, b in zip(pts, pts[1:]):
        d.append(d[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    out, j = [], 0
    for i in range(n + 1):
        s = d[-1] * i / n
        while j < len(d) - 2 and d[j + 1] < s:
            j += 1
        u = (s - d[j]) / ((d[j + 1] - d[j]) or 1e-9)
        out.append((pts[j][0] + (pts[j + 1][0] - pts[j][0]) * u,
                    pts[j][1] + (pts[j + 1][1] - pts[j][1]) * u))
    return out


def pressure(keys):
    """Monotone cubic curve through (position, pressure) keys: the nib swells
    and thins evenly, with no flat steps and no overshoot."""
    xs, ys = [k[0] for k in keys], [k[1] for k in keys]
    n = len(xs)
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    delta = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    m[0], m[-1] = delta[0], delta[-1]
    for i in range(1, n - 1):
        if delta[i - 1] * delta[i] > 0:
            w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i])

    def curve(t):
        t = min(max(t, xs[0]), xs[-1])
        i = 0
        while i < n - 2 and t > xs[i + 1]:
            i += 1
        u = (t - xs[i]) / h[i]
        return max(0.0, (2 * u ** 3 - 3 * u ** 2 + 1) * ys[i] + (u ** 3 - 2 * u ** 2 + u) * h[i] * m[i]
                   + (-2 * u ** 3 + 3 * u ** 2) * ys[i + 1] + (u ** 3 - u ** 2) * h[i] * m[i + 1])
    return curve


def soften(values, radius):
    kernel = [math.exp(-0.5 * (j / (radius / 2.0)) ** 2) for j in range(-radius, radius + 1)]
    out = []
    for i in range(len(values)):
        total = weight = 0.0
        for j, w in zip(range(-radius, radius + 1), kernel):
            total += values[min(max(i + j, 0), len(values) - 1)] * w
            weight += w
        out.append(total / weight)
    out[0], out[-1] = values[0], values[-1]
    return out


def round_joins(pts):
    pts = resample(pts, max(len(pts), 400))
    for _ in range(2):
        pts = [pts[0]] + [((pts[i - 1][0] + 2 * pts[i][0] + pts[i + 1][0]) / 4,
                           (pts[i - 1][1] + 2 * pts[i][1] + pts[i + 1][1]) / 4)
                          for i in range(1, len(pts) - 1)] + [pts[-1]]
    return pts


def stroke(pts, nib, curve, n=260, cap_end=True, ends=None):
    """Outline of one pen stroke: the centre line widened by nib * pressure."""
    pts = resample(round_joins(pts), n)
    half = soften([nib * curve(i / n) / 2 for i in range(n + 1)], max(2, n // 40))
    left, right, heading = [], [], []
    for i, p in enumerate(pts):
        a, b = pts[max(0, i - 1)], pts[min(n, i + 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        length = math.hypot(tx, ty) or 1e-9
        heading.append((tx / length, ty / length))
        nx, ny = -ty / length, tx / length
        left.append((p[0] + nx * half[i], p[1] + ny * half[i]))
        right.append((p[0] - nx * half[i], p[1] - ny * half[i]))

    def cap(point, radius, direction):
        angle = math.atan2(direction[1], direction[0])
        return [(point[0] + radius * math.cos(angle + math.pi / 2 - math.pi * k / 12),
                 point[1] + radius * math.sin(angle + math.pi / 2 - math.pi * k / 12)) for k in range(1, 12)]

    outline = list(left)
    if cap_end:
        outline += cap(pts[-1], half[-1], heading[-1])
    outline += right[::-1]
    outline += cap(pts[0], half[0], (-heading[0][0], -heading[0][1]))
    if ends is not None:
        ends["end"] = (left[-1], right[-1], heading[-1], pts[-1])
    return outline


def mirror(pts):
    return [(2 * AXIS - x, y) for x, y in pts]


def peak(ends):
    """Sharp point where a stroke meets its mirror image on the axis."""
    left, right, (dx, dy), centre = ends["end"]
    outer, inner = min((left, right), key=lambda q: q[1]), max((left, right), key=lambda q: q[1])
    width = math.hypot(left[0] - right[0], left[1] - right[1])
    reach = min((AXIS - outer[0]) / dx if abs(dx) > 1e-9 else 0.0, 1.6 * width)
    return [outer, (AXIS, outer[1] + reach * dy), (2 * AXIS - outer[0], outer[1]),
            (2 * AXIS - inner[0], inner[1]), (AXIS, max(inner[1], centre[1]) + width), inner]


def crescent(cx, cy, outer, inner, shift, opening, n=90):
    """A disc with a smaller disc cut out towards the opening: two sharp horns."""
    theta = math.radians(opening)
    ix, iy = cx + shift * math.cos(theta), cy - shift * math.sin(theta)
    a = math.acos((shift * shift + outer * outer - inner * inner) / (2 * shift * outer))
    pts = [(cx + outer * math.cos(theta + a + (2 * math.pi - 2 * a) * i / n),
            cy - outer * math.sin(theta + a + (2 * math.pi - 2 * a) * i / n)) for i in range(n + 1)]
    a0 = math.atan2(-(pts[-1][1] - iy), pts[-1][0] - ix)
    a1 = math.atan2(-(pts[0][1] - iy), pts[0][0] - ix)
    while a1 > a0:
        a1 -= 2 * math.pi
    return pts + [(ix + inner * math.cos(a0 + (a1 - a0) * i / n),
                   iy - inner * math.sin(a0 + (a1 - a0) * i / n)) for i in range(1, n)]


def mark():
    """The whole mark as a list of outlines (one per stroke)."""
    shapes = []
    arch = join(
        cubic((70.2, 232.0), (70.6, 200.0), (70.4, 165.0), (71.0, 146.0), n=40),   # the upright
        cubic((71.0, 146.0), (70.0, 120.0), (98.0, 98.0), (127.5, 80.0), n=60),    # the shoulder
        cubic((127.5, 80.0), (145.0, 69.0), (158.0, 62.0), (166.0, 47.0), n=40),   # up to the point
    )
    ends = {}
    side = stroke(arch, 10.2, pressure([(0, 0.03), (0.07, 0.14), (0.15, 0.30), (0.25, 0.52), (0.36, 0.72),
                                        (0.5, 0.86), (0.77, 1.0), (0.9, 0.90), (1.0, 0.62)]),
                  cap_end=False, ends=ends)
    shapes += [side, mirror(side), peak(ends)]
    dome = join(
        cubic((166.0, 143.5), (166.5, 156.0), (180.0, 163.0), (200.0, 176.0), n=50),
        cubic((200.0, 176.0), (224.0, 190.0), (246.4, 205.0), (243.4, 252.0), n=70),
    )
    side = stroke(dome, 15.6, pressure([(0, 0.11), (0.07, 0.56), (0.2, 1.0), (0.35, 0.97), (0.46, 0.88),
                                        (0.56, 0.75), (0.64, 0.56), (0.71, 0.40), (0.77, 0.27), (0.83, 0.19),
                                        (0.90, 0.10), (1.0, 0.02)]))
    shapes += [side, mirror(side)]
    minaret = cubic((51.6, 148.0), (51.8, 182.0), (52.0, 216.0), (52.2, 253.0), n=60)
    side = stroke(minaret, 6.8, pressure([(0, 0.04), (0.1, 0.55), (0.22, 1.0), (0.4, 0.95), (0.62, 0.7),
                                          (0.82, 0.4), (1.0, 0.04)]), n=160)
    shapes += [side, mirror(side)]
    shapes.append(crescent(165.8, 125.2, 14.2, 11.7, 6.1, 40))
    return shapes


# ------------------------------------------------------------------- rendering
def placed(shapes, size, span, lift=0.0):
    """Scales the mark so its wider side covers `span` of the canvas, centred."""
    xs = [x for s in shapes for x, _ in s]
    ys = [y for s in shapes for _, y in s]
    scale = size * span / max(max(xs) - min(xs), max(ys) - min(ys))
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    return [[(size / 2 + (x - cx) * scale, size / 2 - lift * size + (y - cy) * scale) for x, y in s]
            for s in shapes]


def path(shape):
    number = lambda v: f"{v:.2f}".rstrip("0").rstrip(".")
    return "M" + " L".join(f"{number(x)} {number(y)}" for x, y in shape) + " Z"


def svg(size, span, background=True, ink=None, lift=0.006):
    shapes = placed(mark(), size, span, lift)
    fill = ink or "url(#ink)"
    body = "".join(f'<path d="{path(s)}" fill="{fill}"/>' for s in shapes)
    ground = f'<rect width="{size}" height="{size}" fill="url(#ground)"/>' if background else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}"><defs>'
        f'<radialGradient id="ground" cx="50%" cy="30%" r="80%"><stop offset="0" stop-color="{DARK_LIFT}"/>'
        f'<stop offset="0.55" stop-color="{DARK}"/><stop offset="1" stop-color="{DARK_EDGE}"/></radialGradient>'
        f'<linearGradient id="ink" gradientUnits="userSpaceOnUse" x1="0" y1="{size * (0.5 - span * 0.45):.1f}" '
        f'x2="0" y2="{size * (0.5 + span * 0.45):.1f}"><stop offset="0" stop-color="{GREEN_TOP}"/>'
        f'<stop offset="0.45" stop-color="{GREEN}"/><stop offset="1" stop-color="{GREEN_DEEP}"/></linearGradient>'
        f"</defs>{ground}{body}</svg>"
    )


def raster(svg_text, pixels):
    """Renders at 4x and scales down for clean edges at small sizes."""
    big = min(pixels * 4, 4096)
    png = subprocess.run(["rsvg-convert", "-w", str(big), "-h", str(big)], input=svg_text.encode(),
                         capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA").resize((pixels, pixels), Image.LANCZOS)


def masked(image, radius_fraction):
    size = image.size[0] * 4
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * radius_fraction), fill=255)
    image = image.copy()
    image.putalpha(mask.resize(image.size, Image.LANCZOS))
    return image


def save(image, *parts):
    target = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    image.save(target, optimize=True)


def main():
    full = svg(1024, 0.70)                       # full square: iOS, store, older Android
    layer = svg(1024, 0.435, background=False)   # adaptive foreground, inside the safe circle
    mono = svg(1024, 0.435, background=False, ink="#FFFFFF")
    ground = svg(1024, 0.0001, ink="none")       # background layer only
    for name, text in (("athan_icon.svg", full), ("athan_mark.svg", svg(1024, 0.86, background=False))):
        with open(os.path.join(ROOT, "design", "app_icon", name), "w", encoding="utf-8") as handle:
            handle.write(text)
    save(raster(full, 1024).convert("RGB"), "design", "app_icon", "athan_icon_1024.png")

    res = ("android", "app", "src", "main", "res")
    for density, legacy in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        tile = raster(full, legacy)
        save(masked(tile, 0.22), *res, f"mipmap-{density}", "ic_launcher.png")
        save(masked(tile, 0.5), *res, f"mipmap-{density}", "ic_launcher_round.png")
        adaptive = legacy * 108 // 48
        save(raster(layer, adaptive), *res, f"mipmap-{density}", "ic_launcher_foreground.png")
        save(raster(mono, adaptive), *res, f"mipmap-{density}", "ic_launcher_monochrome.png")
        save(raster(ground, adaptive).convert("RGB"), *res, f"mipmap-{density}", "ic_launcher_background.png")
    save(raster(full, 512).convert("RGB"), "android", "app", "src", "main", "ic_launcher-playstore.png")

    ios = ("ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    for points, scales in ((20, (1, 2, 3)), (29, (1, 2, 3)), (40, (1, 2, 3)), (60, (2, 3)), (76, (1, 2)),
                           (83.5, (2,)), (1024, (1,))):
        for scale in scales:
            label = f"{points:g}x{points:g}@{scale}x"
            save(raster(full, round(points * scale)).convert("RGB"), *ios, f"Icon-App-{label}.png")
    print("icon written")


if __name__ == "__main__":
    main()
