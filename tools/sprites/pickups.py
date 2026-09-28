"""Pixel sprites for pickups: XP soul shards, big shards, gold coins and
healing hearts, 4 animation frames each, 16px frames in one atlas.

    python3 tools/sprites/pickups.py

Rows: 0 shard, 1 big shard, 2 coin, 3 heart. Columns: animation frames.
"""
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "sprites", "pickups.png")
F = 16
INK = (12, 8, 16, 255)


def put(img, fx, fy, pts, color):
    px = img.load()
    for x, y in pts:
        if 0 <= x < F and 0 <= y < F:
            px[fx * F + x, fy * F + y] = color


def outline(img, fx, fy):
    px = img.load()
    solid = {(x, y) for y in range(F) for x in range(F) if px[fx * F + x, fy * F + y][3] > 0}
    for y in range(F):
        for x in range(F):
            if (x, y) in solid:
                continue
            if any((x + dx, y + dy) in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[fx * F + x, fy * F + y] = INK


def diamond(cx, cy, rx, ry):
    pts = []
    for y in range(cy - ry, cy + ry + 1):
        w = rx - int(round(abs(y - cy) * rx / ry))
        for x in range(cx - w, cx + w + 1):
            pts.append((x, y))
    return pts


def shard(img, row, big, colors):
    dark, mid, light, glint = colors
    cx, cy = 7, 8
    rx, ry = (4, 6) if big else (3, 5)
    for f in range(4):
        body = diamond(cx, cy, rx, ry)
        put(img, f, row, body, mid)
        # Left half darker, right-top facet lighter.
        put(img, f, row, [(x, y) for x, y in body if x < cx], dark)
        put(img, f, row, [(x, y) for x, y in body if x > cx and y < cy], light)
        put(img, f, row, [(cx, y) for y in range(cy - ry + 1, cy + ry)], light)
        # A glint that runs down the crystal.
        gy = cy - ry + 2 + f * 2
        put(img, f, row, [(cx + 1, gy), (cx + 1, gy + 1)], glint)
        outline(img, f, row)


def coin(img, row):
    rim, face, shine, dark = (140, 92, 30, 255), (236, 188, 72, 255), (255, 236, 150, 255), (180, 120, 40, 255)
    widths = [5, 4, 1, 4]
    for f, w in enumerate(widths):
        pts = []
        for y in range(3, 14):
            dy = abs(y - 8.5) / 5.5
            half = int(round(w * (1 - dy * dy) ** 0.5))
            for x in range(7 - half, 8 + half):
                pts.append((x, y))
        put(img, f, row, pts, rim)
        inner = [(x, y) for x, y in pts if 4 <= y <= 12 and abs(x - 7.5) < max(0.5, w - 1)]
        put(img, f, row, inner, face)
        put(img, f, row, [(x, y) for x, y in inner if x < 7 and y < 8], shine)
        put(img, f, row, [(x, y) for x, y in inner if x > 8 and y > 9], dark)
        outline(img, f, row)


def heart(img, row):
    red, dark, light = (214, 44, 58, 255), (130, 20, 40, 255), (255, 140, 140, 255)
    shape = [
        "..XX...XX..",
        ".XXXX.XXXX.",
        "XXXXXXXXXXX",
        "XXXXXXXXXXX",
        ".XXXXXXXXX.",
        "..XXXXXXX..",
        "...XXXXX...",
        "....XXX....",
        ".....X.....",
    ]
    for f in range(4):
        oy = 4 - (1 if f in (1, 2) else 0)
        pts = [(x + 2, y + oy) for y, line in enumerate(shape) for x, ch in enumerate(line) if ch == "X"]
        put(img, f, row, pts, red)
        put(img, f, row, [(x, y) for x, y in pts if y >= oy + 5 or x >= 10], dark)
        put(img, f, row, [(3, oy + 1), (4, oy + 1), (3, oy + 2)], light)
        outline(img, f, row)


def main():
    img = Image.new("RGBA", (4 * F, 4 * F))
    shard(img, 0, False, ((40, 110, 170, 255), (80, 180, 235, 255), (170, 235, 255, 255), (255, 255, 255, 255)))
    shard(img, 1, True, ((90, 50, 150, 255), (160, 100, 230, 255), (220, 180, 255, 255), (255, 255, 255, 255)))
    coin(img, 2)
    heart(img, 3)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("saved", OUT)


if __name__ == "__main__":
    main()
