"""Pixel UI frames (9-patch textures) for panels, cards and buttons.

    python3 tools/sprites/ui_frames.py

Every art pixel is drawn 2x2 so frames match the 2x pixel scale of the world.
Writes game/assets/ui/<name>.png; UIStyle uses 6px (3 art pixel) margins.
"""
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "ui")
N = 8   # art pixels per side
K = 2   # screen pixels per art pixel

FRAMES = {
    # name: (fill, outline, light edge, dark edge)
    "panel": ((18, 15, 22, 228), (6, 4, 8, 255), (78, 66, 58, 255), (40, 33, 30, 255)),
    "card": ((24, 20, 28, 240), (6, 4, 8, 255), (122, 96, 62, 255), (62, 48, 34, 255)),
    "card_hot": ((36, 28, 30, 245), (6, 4, 8, 255), (246, 208, 120, 255), (170, 118, 52, 255)),
    "button": ((30, 24, 30, 240), (6, 4, 8, 255), (122, 96, 62, 255), (62, 48, 34, 255)),
    "button_hot": ((196, 150, 72, 255), (6, 4, 8, 255), (250, 222, 150, 255), (140, 96, 40, 255)),
    "slot": ((14, 12, 18, 220), (6, 4, 8, 255), (70, 60, 54, 255), (34, 28, 26, 255)),
}


def frame(fill, outline, light, dark):
    img = Image.new("RGBA", (N * K, N * K))
    px = img.load()
    for y in range(N):
        for x in range(N):
            edge = x == 0 or y == 0 or x == N - 1 or y == N - 1
            corner = (x in (0, N - 1)) and (y in (0, N - 1))
            if corner:
                c = (0, 0, 0, 0)
            elif edge:
                c = outline
            elif x == 1 or y == 1:
                c = light if not ((x == 1 and y == N - 2) or (y == 1 and x == N - 2)) else dark
            elif x == N - 2 or y == N - 2:
                c = dark
            else:
                c = fill
            for yy in range(K):
                for xx in range(K):
                    px[x * K + xx, y * K + yy] = c
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, cols in FRAMES.items():
        frame(*cols).save(os.path.join(OUT, name + ".png"))
    print("frames:", len(FRAMES))


if __name__ == "__main__":
    main()
