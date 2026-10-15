#!/usr/bin/env python3
"""Build game-ready art from the generated source sheets in docs/art/sources.

    python3 tools/art/build_assets.py          (needs Pillow, numpy, scipy)

Every sheet was generated on a pure #00FF00 background (see docs/art/art-direction.md), so the
pieces are keyed and cut here instead of by hand. Besides the PNGs this writes the numbers the
game needs to place art exactly, so nothing is tuned by eye in GDScript:

- assets/ui/ui.json: per UI piece, the 9-slice margins (texture_margin: corners and borders
  that must not stretch), the content margins (the visible face, so text and icons centre on
  what the eye sees, not on the outline and the darker bottom lip) and the image size.
- Ore and rock sprites share one canvas size per family and are centred on their box
  (ores: outline box; rocks: main body), so every sprite lands on the same point of a cell.
  Every gem fits the same outer box, so all kinds read as the same size.

It also writes docs/art/ui-slices.png, which draws the slice lines and content boxes for review.
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "docs", "art", "sources")
OUT = os.path.join(ROOT, "assets")


def key(path):
    """RGBA array with the green background keyed out and green spill removed."""
    im = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    gx = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (gx - 40) / 80.0, 0, 1)
    g2 = np.where(gx > 0, np.maximum(r, b), g)
    return np.dstack([r, g2, b, alpha * 255]).astype(np.uint8)


def cell(rgba, k, n=3, dilate=6):
    """Piece k of an n x n sheet: the largest blob plus anything close to it, cropped."""
    h, w = rgba.shape[:2]
    q = rgba[(k // n) * h // n:(k // n + 1) * h // n, (k % n) * w // n:(k % n + 1) * w // n].copy()
    a = q[..., 3] > 128
    lab, cnt = ndimage.label(ndimage.binary_dilation(a, iterations=dilate))
    sizes = ndimage.sum(a, lab, range(1, cnt + 1))
    keep = lab == (1 + int(np.argmax(sizes)))
    q[..., 3] = np.where(keep, q[..., 3], 0)
    ys, xs = np.where(q[..., 3] > 128)
    return q[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def save(arr_or_img, *parts):
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im = arr_or_img if isinstance(arr_or_img, Image.Image) else Image.fromarray(arr_or_img)
    im.save(path, optimize=True)
    return path


def remove_ruled_lines(a, top):
    """Straight dark lines copied from a blockout: rows clearly darker than 4 px above and below."""
    out = a.astype(np.float32).copy()
    h, w = a.shape[:2]
    lum = out[..., :3].mean(2)
    x0, x1 = int(w * 0.08), int(w * 0.92)
    rows = [y for y in range(top + 5, h - 12)
            if np.mean(lum[y, x0:x1] < (lum[y - 4, x0:x1] + lum[y + 4, x0:x1]) / 2 - 14) > 0.6]
    groups = []
    for y in rows:
        if groups and y - groups[-1][-1] <= 2:
            groups[-1].append(y)
        else:
            groups.append([y])
    for g in groups:
        y0, y1 = g[0] - 2, g[-1] + 2
        for y in range(y0 + 1, y1):
            t = (y - y0) / (y1 - y0)
            out[y, :, :3] = (1 - t) * a[y0, :, :3] + t * a[y1, :, :3]
    return out.astype(np.uint8)


# --- board tiles ---------------------------------------------------------------------------
TILE_W = 256


# Planets: "" is the first planet (tiles_tops.png -> assets/tiles/), any other name has its own
# sheets (tiles_tops_<name>.png -> assets/tiles/<name>/), painted over the first planet's sheets
# so every tileset shares one geometry.
PLANETS = ["", "verdis"]


def build_tiles(planet=""):
    """Tops (soil, exhausted, shallow dents) from one sheet, layered earth bands from another."""
    sfx = "_" + planet if planet else ""
    if not os.path.exists(os.path.join(SRC, "tiles_tops%s.png" % sfx)):
        return {}
    tops = key(os.path.join(SRC, "tiles_tops%s.png" % sfx))
    bands = key(os.path.join(SRC, "tiles_bands%s.png" % sfx))
    # slot in tiles_tops.png -> name; the band comes from the same slot of tiles_bands.png
    plan = {"soil_a": (0, 0), "soil_b": (1, 1), "bare": (3, 6), "dent1": (4, 2), "dent2": (5, 3)}
    meta = {}
    for name, (ti, bi) in plan.items():
        t = cell(tops, ti)
        tw = t.shape[1]
        top = Image.fromarray(t[:tw]).resize((TILE_W, TILE_W), Image.LANCZOS)
        b = cell(bands, bi)
        bw = b.shape[1]
        b = remove_ruled_lines(b, bw)
        band = Image.fromarray(b[bw - 6:]).resize((TILE_W, round((b.shape[0] - bw + 6) * TILE_W / bw)), Image.LANCZOS)
        out = Image.new("RGBA", (TILE_W, TILE_W - 6 + band.height))
        out.alpha_composite(band, (0, TILE_W - 6))
        out.alpha_composite(top, (0, 0))
        save(out, *(["tiles", planet, name + ".png"] if planet else ["tiles", name + ".png"]))
        meta[name] = {"size": [out.width, out.height]}
    return meta


# --- rocks: 3 forms x 3 break states, one canvas, body centred ------------------------------
ROCK_CANVAS = 320
ROCK_BODY = 236  # intact rock width on the canvas; the tile top is 256


def build_rocks():
    rgba = key(os.path.join(SRC, "rocks.png"))
    forms = ["boulder", "stone", "basalt"]
    for f, form in enumerate(forms):
        intact = cell(rgba, f * 3, dilate=45)
        scale = ROCK_BODY / intact.shape[1]
        for st in range(3):
            piece = cell(rgba, f * 3 + st, dilate=45)
            # centre on the main body, not on the bounding box, so flying chips don't shift it
            a = piece[..., 3] > 128
            lab, cnt = ndimage.label(a)
            body = lab == (1 + int(np.argmax(ndimage.sum(a, lab, range(1, cnt + 1))))) if cnt > 1 else a
            if st == 2:  # cracked into chunks: use every big chunk as the body
                sizes = ndimage.sum(a, lab, range(1, cnt + 1))
                body = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.08])
            cy, cx = ndimage.center_of_mass(body)
            im = Image.fromarray(piece)
            im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
            canvas = Image.new("RGBA", (ROCK_CANVAS, ROCK_CANVAS))
            canvas.alpha_composite(im, (round(ROCK_CANVAS / 2 - cx * scale), round(ROCK_CANVAS / 2 - cy * scale)))
            save(canvas, "rocks", "%s_%d.png" % (form, st))


# --- ores: same canvas, same visual weight, centred on their box --------------------------------
ORE_CANVAS = 256
ORE_BOX = 0.80   # every gem fits the same box: its longer side is this share of the canvas
ORE_SQUAT = 0.62 # a gem much wider than tall (the capsule) gets at least this height
# Gems sit on the centre of their outline box. (The alpha centroid lifted the triangle: its
# centroid is low, so its tip ended up near the top of every slot.)


def build_ores():
    rgba = key(os.path.join(SRC, "ores.png"))
    names = ["ferrite", "cryo", "lumen", "ruby", "star", "sapphire", "pearl", "bronze", "obsidian"]
    for k, name in enumerate(names):
        piece = cell(rgba, k)
        a = piece[..., 3] / 255.0
        h, w = piece.shape[:2]
        scale = ORE_BOX * ORE_CANVAS / max(h, w)
        scale = min(max(scale, ORE_SQUAT * ORE_CANVAS / h), 0.95 * ORE_CANVAS / w)
        cy, cx = (h - 1) / 2, (w - 1) / 2
        im = Image.fromarray(piece)
        im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
        canvas = Image.new("RGBA", (ORE_CANVAS, ORE_CANVAS))
        canvas.alpha_composite(im, (round(ORE_CANVAS / 2 - cx * scale), round(ORE_CANVAS / 2 - cy * scale)))
        save(canvas, "ore", name + ".png")
        if name == "sapphire":
            # a little wider, so the slim diamond weighs as much as the other gems
            wide = canvas.resize((round(ORE_CANVAS * 1.22), ORE_CANVAS), Image.LANCZOS)
            off = (wide.width - ORE_CANVAS) // 2
            wide = wide.crop((off, 0, off + ORE_CANVAS, ORE_CANVAS))
            save(recolour(wide, CRYSTAL_HUE, 1.25), "ore", "crystal.png")


# The crystal is the sapphire's cut in the game's crystal violet (Pal.CRYSTAL #c88bff), so it
# matches the ores in size, light and brushwork.
CRYSTAL_HUE = 0.76


def recolour(im, hue, light):
    """Move every pixel to one hue, keep saturation and value, brighten a little."""
    a = np.asarray(im.convert("RGBA")).copy()
    hsv = np.asarray(Image.fromarray(a[..., :3]).convert("HSV")).astype(np.float32)
    hsv[..., 0] = hue * 255
    hsv[..., 2] = np.clip(hsv[..., 2] * light, 0, 255)
    a[..., :3] = np.asarray(Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB"))
    return Image.fromarray(a)


# --- UI pieces: 9-slice and content margins measured from the pixels -----------------------
UI_PIECES = ["panel", "bubble", "button_teal", "button_orange", "button_round",
             "bar_track", "battery", "bar_fill", "card", "plate"]


def ui_components():
    rgba = key(os.path.join(SRC, "hud.png"))
    lab, n = ndimage.label(ndimage.binary_dilation(rgba[..., 3] > 128, iterations=3))
    items = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if (lab[sl] == i + 1).sum() < 1500:
            continue
        piece = rgba[sl].copy()
        piece[..., 3] = np.where(lab[sl] == i + 1, piece[..., 3], 0)
        items.append((round(sl[0].start / 60), sl[1].start, piece))
    items.sort(key=lambda t: (t[0], t[1]))
    assert len(items) == len(UI_PIECES), "expected %d UI pieces, found %d" % (len(UI_PIECES), len(items))
    return {name: trim(p) for name, (_, _, p) in zip(UI_PIECES, items)}


def trim(p):
    ys, xs = np.where(p[..., 3] > 128)
    return p[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def measure(p):
    """Margins of a UI piece, in its own pixels: [left, top, right, bottom]."""
    h, w = p.shape[:2]
    rgb = p[..., :3].astype(np.float32)
    opaque = p[..., 3] > 128
    face = np.median(rgb[int(h * 0.4):int(h * 0.6), int(w * 0.4):int(w * 0.6)].reshape(-1, 3), axis=0)
    near = (np.abs(rgb - face).sum(2) < 70) & opaque  # pixels that belong to the face

    def inset(line):
        """Distance from the start of a scan line to where the face begins (3 face px in a row)."""
        run = 0
        for i, v in enumerate(line):
            run = run + 1 if v else 0
            if run == 3:
                return i - 2
        return len(line) // 2

    def side(lines):
        return int(np.median([inset(l) for l in lines]))

    rows = range(int(h * 0.4), int(h * 0.6) + 1)
    cols = range(int(w * 0.4), int(w * 0.6) + 1)
    face_in = [side([near[y, :] for y in rows]), side([near[:, x] for x in cols]),
               side([near[y, ::-1] for y in rows]), side([near[::-1, x] for x in cols])]

    # Corner size along each axis. The left/right slices must hold the whole rounded end (for a
    # pill that is half its height) so widening a button never stretches a curve; top/bottom
    # slices hold the corner curve plus the top highlight and the darker bottom lip.
    def corner_w(mask):
        """How far in from the side the top-left corner curve reaches (first opaque x on the top rows)."""
        ys = np.where(mask.any(1))[0]
        first = [np.argmax(mask[y]) for y in ys]
        return int(max(first[:3]) - min(first))

    def corner_h(mask):
        return corner_w(mask.T)

    rw = max(corner_w(opaque), corner_w(opaque[:, ::-1]))
    rh_top = max(corner_h(opaque), corner_h(opaque[:, ::-1]))
    rh_bot = max(corner_h(opaque[::-1]), corner_h(opaque[::-1, ::-1]))
    slice_m = [max(face_in[0], rw), max(face_in[1], rh_top), max(face_in[2], rw), max(face_in[3], rh_bot)]
    slice_m = [m + 3 for m in slice_m]
    # keep a stretchable middle of at least 2 px on each axis
    slice_m[0] = min(slice_m[0], w // 2 - 2); slice_m[2] = min(slice_m[2], w // 2 - 2)
    slice_m[1] = min(slice_m[1], h // 2 - 2); slice_m[3] = min(slice_m[3], h // 2 - 2)
    return {"size": [w, h], "slice": slice_m, "face": face_in}


def neutral(p):
    """Grey version of a piece: tinted at runtime (modulate) so every colour shares one shape."""
    im = Image.fromarray(p)
    a = im.getchannel("A")
    g = ImageEnhance.Brightness(im.convert("L").convert("RGB")).enhance(1.45)
    g.putalpha(a)
    return np.asarray(g)


def build_ui():
    pieces = ui_components()
    pieces["button_base"] = neutral(pieces["button_teal"])
    pieces["bar_fill_base"] = neutral(pieces["bar_fill"])
    meta = {}
    for name, p in pieces.items():
        save(p, "ui", name + ".png")
        meta[name] = measure(p)
    # base pieces keep the measurements of the art they were made from
    meta["button_base"] = meta["button_teal"]
    meta["bar_fill_base"] = meta["bar_fill"]
    with open(os.path.join(OUT, "ui", "ui.json"), "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
    # the same numbers as a GDScript constant: exports don't pack plain .json files
    lines = ["class_name UiMetrics", "extends RefCounted", "",
             "## Generated by tools/art/build_assets.py from the UI art. Do not edit by hand.",
             "## Per piece, in texture pixels, [left, top, right, bottom]:",
             "##   slice: 9-slice margins (corners, borders, highlight and lip never stretch)",
             "##   face:  inset of the visible face, so content centres on what the eye sees", "",
             "const DATA := {"]
    for name in sorted(meta):
        m = meta[name]
        lines.append('\t"%s": {"size": Vector2i(%d, %d), "slice": %s, "face": %s},' % (
            name, m["size"][0], m["size"][1], m["slice"], m["face"]))
    lines.append("}")
    with open(os.path.join(ROOT, "scripts", "ui", "UiMetrics.gd"), "w") as f:
        f.write("\n".join(lines) + "\n")
    review(pieces, meta)
    return meta


def review(pieces, meta):
    """Slice lines (magenta) and the face/content box (cyan) over each piece."""
    pad = 24
    tiles = []
    for name, p in pieces.items():
        im = Image.new("RGBA", (p.shape[1] + 2 * pad, p.shape[0] + 2 * pad + 30), (28, 24, 44, 255))
        im.alpha_composite(Image.fromarray(p), (pad, pad + 30))
        d = ImageDraw.Draw(im)
        w, h = meta[name]["size"]
        l, t, r, b = meta[name]["slice"]
        for x in (l, w - r):
            d.line((pad + x, pad + 30, pad + x, pad + 30 + h), fill=(255, 60, 220), width=2)
        for y in (t, h - b):
            d.line((pad, pad + 30 + y, pad + w, pad + 30 + y), fill=(255, 60, 220), width=2)
        fl, ft, fr, fb = meta[name]["face"]
        d.rectangle((pad + fl, pad + 30 + ft, pad + w - fr, pad + 30 + h - fb), outline=(60, 230, 255), width=2)
        d.text((pad, 8), name, fill=(240, 230, 255))
        tiles.append(im)
    W = 1500
    x = y = row_h = 0
    pos = []
    for im in tiles:
        if x + im.width > W:
            x, y, row_h = 0, y + row_h, 0
        pos.append((x, y))
        x += im.width
        row_h = max(row_h, im.height)
    sheet = Image.new("RGB", (W, y + row_h), (20, 18, 34))
    for im, p in zip(tiles, pos):
        sheet.paste(im, p, im)
    sheet.save(os.path.join(ROOT, "docs", "art", "ui-slices.png"))


# --- background: cropped to the screen and dimmed slightly ---------------
def build_background():
    bg = Image.open(os.path.join(SRC, "background.png")).convert("RGB")
    w, h = 1080, 1920
    s = max(w / bg.width, h / bg.height)
    bg = bg.resize((round(bg.width * s), round(bg.height * s)), Image.LANCZOS)
    bg = bg.crop(((bg.width - w) // 2, (bg.height - h) // 2, (bg.width - w) // 2 + w, (bg.height - h) // 2 + h))
    bg = ImageEnhance.Brightness(bg).enhance(0.95)
    os.makedirs(os.path.join(OUT, "bg"), exist_ok=True)
    bg.save(os.path.join(OUT, "bg", "space.jpg"), quality=88)


if __name__ == "__main__":
    for planet in PLANETS:
        print("tiles", planet or "(first)", build_tiles(planet))
    build_rocks()
    build_ores()
    meta = build_ui()
    for k, v in meta.items():
        print("ui", k, v)
    build_background()
