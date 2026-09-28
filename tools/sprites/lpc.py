"""Composites Universal LPC layers into game sprite atlases.

Usage: python3 tools/sprites/build.py [path to Universal-LPC-Spritesheet-Character-Generator]

Each character is a list of layers (sheet path, z order, recolor). Frames are
64x64; LPC sheets have one row per direction: up, left, down, right.
"""
import json
import os
from PIL import Image

FRAME = 64
DIRS = 4


class Lpc:
    def __init__(self, root):
        self.root = root
        self.sheets = os.path.join(root, "spritesheets")
        self.palettes = {}
        self.used = set()

    def palette(self, material, name):
        key = (material, name)
        if key not in self.palettes:
            for fname in os.listdir(os.path.join(self.root, "palette_definitions", material)):
                if not fname.endswith(".json") or fname.startswith("meta_"):
                    continue
                with open(os.path.join(self.root, "palette_definitions", material, fname)) as f:
                    data = json.load(f)
                for n, cols in data.items():
                    self.palettes.setdefault((material, n), [_hex(c) for c in cols])
        return self.palettes[key]

    def sheet(self, path, anim):
        """Loads spritesheets/<path>/<anim>.png, or <path>/<anim>/<variant>.png
        when path is "dir|variant". Returns None if this anim doesn't exist."""
        variant = None
        if "|" in path:
            path, variant = path.split("|")
        f = os.path.join(self.sheets, path, anim, variant + ".png") if variant else os.path.join(self.sheets, path, anim + ".png")
        if not os.path.exists(f):
            return None
        self.used.add(os.path.relpath(f, self.sheets))
        return Image.open(f).convert("RGBA")


def _hex(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def recolor(img, src, dst):
    """Maps each palette color in src to the same slot in dst (±1 tolerance)."""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            for k, s in enumerate(src):
                if abs(r - s[0]) <= 1 and abs(g - s[1]) <= 1 and abs(b - s[2]) <= 1:
                    d = dst[k]
                    px[x, y] = (d[0], d[1], d[2], a)
                    break
    return img


def tint(img, fn):
    """Applies fn(r, g, b) -> (r, g, b) to every visible pixel."""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a:
                nr, ng, nb = fn(r, g, b)
                px[x, y] = (int(nr), int(ng), int(nb), a)
    return img


def compose(lpc, layers, anim, frames):
    """Stacks layers for one animation. Layers: dicts with path, z, and
    optionally recolor=(material, base, target) and anims={anim: alt}."""
    out = Image.new("RGBA", (frames * FRAME, DIRS * FRAME))
    for layer in sorted(layers, key=lambda l: l["z"]):
        a = layer.get("anims", {}).get(anim, anim)
        if a is None:
            continue
        img = lpc.sheet(layer["path"], a)
        if img is None:
            continue
        if "recolor" in layer:
            mat, base, target = layer["recolor"]
            recolor(img, lpc.palette(mat, base), lpc.palette(mat, target))
        if "fn" in layer:
            tint(img, layer["fn"])
        rows = img.size[1] // FRAME
        cols = img.size[0] // FRAME
        for r in range(min(rows, DIRS)):
            for c in range(min(cols, frames)):
                tile = img.crop((c * FRAME, r * FRAME, (c + 1) * FRAME, (r + 1) * FRAME))
                out.alpha_composite(tile, (c * FRAME, r * FRAME))
        if rows == 1:  # single-row sheets (hurt) fill the first row only
            pass
    return out


def outline(img, color=(12, 8, 14, 255)):
    """Adds a 1px dark outline around opaque pixels (per 64px frame, no bleed)."""
    src = img.copy()
    sp = src.load()
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] > 0:
                continue
            fx, fy = x % FRAME, y % FRAME
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = fx + dx, fy + dy
                if 0 <= nx < FRAME and 0 <= ny < FRAME and sp[x + dx, y + dy][3] > 128:
                    px[x, y] = color
                    break
    return img
