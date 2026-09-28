"""Pixel sprites for weapon effects (weapons_fx.png) and boss projectiles
(boss_fx.png rows: 0 death bolt, 1 soul orb, 2 ice shard, 3 frost orb,
4 bile bolt, 5 plague orb), 24px frames, 4 columns.

weapons_fx.png rows (5-10 are hero weapons: 5 claw slash, 6 chain link,
7 ice shard, 8 soul blade, 9 soul skull, 10 dragon fire):

    0 holy orb (pulsing)      1 flail head (spinning spikes)
    2 javelin (points right)  3 throwing axe (points right)
    4 smite star (bursting)

    python3 tools/sprites/weapons_fx.py
"""
import math
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "sprites", "weapons_fx.png")
F = 24
INK = (12, 8, 16, 255)


class Frame:
    def __init__(self, img, col, row):
        self.px = img.load()
        self.ox = col * F
        self.oy = row * F

    def set(self, x, y, c):
        x, y = int(math.floor(x + 0.5)), int(math.floor(y + 0.5))
        if 0 <= x < F and 0 <= y < F:
            self.px[self.ox + x, self.oy + y] = c

    def get(self, x, y):
        if 0 <= x < F and 0 <= y < F:
            return self.px[self.ox + x, self.oy + y]
        return (0, 0, 0, 0)

    def disc(self, cx, cy, r, c):
        for y in range(F):
            for x in range(F):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.set(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / n
            self.set(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)

    def outline(self):
        solid = {(x, y) for y in range(F) for x in range(F) if self.get(x, y)[3] > 0}
        for y in range(F):
            for x in range(F):
                if (x, y) not in solid and any((x + dx, y + dy) in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.set(x, y, INK)


def orb(img, row=0, colors=((70, 130, 220, 255), (130, 200, 255, 255), (210, 240, 255, 255))):
    for f in range(4):
        fr = Frame(img, f, row)
        r = 5 + (1 if f in (1, 2) else 0)
        fr.disc(11.5, 11.5, r + 1.5, colors[0])
        fr.disc(11.5, 11.5, r, colors[1])
        fr.disc(10.5, 10.5, r - 2, colors[2])
        fr.disc(9.5, 9.5, 1.2, (255, 255, 255, 255))
        # Sparkles orbiting the orb.
        a = f * math.pi / 2
        fr.set(11.5 + math.cos(a) * 10, 11.5 + math.sin(a) * 10, colors[2])
        fr.outline()


def flail(img):
    for f in range(4):
        fr = Frame(img, f, 1)
        for k in range(8):
            a = k * math.pi / 4 + f * math.pi / 16
            fr.line(11.5, 11.5, 11.5 + math.cos(a) * 9, 11.5 + math.sin(a) * 9, (150, 140, 130, 255))
        fr.disc(11.5, 11.5, 5.5, (180, 150, 70, 255))
        fr.disc(11.5, 11.5, 4.2, (236, 196, 96, 255))
        fr.disc(10.2, 10.2, 1.6, (255, 240, 170, 255))
        fr.outline()


def javelin(img):
    for f in range(4):
        fr = Frame(img, f, 2)
        shaft, dark, tip, glow = (200, 160, 90, 255), (130, 96, 50, 255), (240, 236, 220, 255), (255, 230, 140, 255)
        fr.line(1, 12, 17, 12, shaft)
        fr.line(1, 13, 17, 13, dark)
        for i in range(6):
            fr.line(17 + i, 12 - (2 - i // 2) + 0, 17 + i, 13 + (2 - i // 2), tip)
        fr.set(22, 12, tip)
        fr.set(22, 13, tip)
        # Holy light trailing off the tail, flickering.
        for i in range(3):
            if (i + f) % 2 == 0:
                fr.set(0 - i, 12, glow)
        fr.set(19, 11, (255, 255, 255, 255))
        fr.outline()


def axe(img):
    for f in range(4):
        fr = Frame(img, f, 3)
        handle, dark, blade, edge = (140, 96, 56, 255), (90, 60, 34, 255), (170, 176, 188, 255), (236, 240, 248, 255)
        fr.line(3, 12, 17, 12, handle)
        fr.line(3, 13, 17, 13, dark)
        for y in range(5, 21):
            w = 5 - abs(y - 12.5) * 0.45
            for x in range(15, 15 + int(max(1, w)) + 1):
                fr.set(x, y, blade)
            fr.set(15 + int(max(1, w)) + 1, y, edge)
        fr.outline()


def smite(img):
    for f in range(4):
        fr = Frame(img, f, 4)
        r = 3 + f * 2.5
        for k in range(8):
            a = k * math.pi / 4
            ln = r if k % 2 == 0 else r * 0.6
            fr.line(11.5, 11.5, 11.5 + math.cos(a) * ln, 11.5 + math.sin(a) * ln, (255, 236, 160, 255))
        fr.disc(11.5, 11.5, max(1.0, 3.5 - f * 0.8), (255, 255, 230, 255))
        if f < 3:
            fr.outline()


def death_bolt(img, row=0, colors=((110, 30, 160, 255), (140, 50, 200, 255), (200, 130, 255, 255), (250, 230, 255, 255))):
    """A ball of soulfire with a flickering tail (points right)."""
    tail, rim, body, core = colors
    for f in range(4):
        fr = Frame(img, f, row)
        for k in range(5):
            y = 11.5 + (k - 2) * 1.6
            ln = 8 - abs(k - 2) * 2 + (f + k) % 3
            fr.line(13 - ln, y, 13, y, tail)
        fr.disc(14.5, 11.5, 5.5, rim)
        fr.disc(15.0, 11.5, 3.8, body)
        fr.disc(15.5, 11.0, 1.8, core)
        fr.outline()


def claw(img):
    """Three bold curved rakes: they tear in (frames 0-1), then thin out."""
    red, dark, white = (200, 40, 40, 255), (120, 16, 24, 255), (255, 236, 226, 255)
    for f in range(4):
        fr = Frame(img, f, 5)
        reach = (0.55, 1.0, 1.0, 1.0)[f]
        for k in range(3):
            off = (k - 1) * 6
            steps = 60
            for i in range(int(steps * reach) + 1):
                t = i / steps
                x = 2 + t * 20
                y = 12 + off - math.sin(t * math.pi) * 4
                # Thick in the middle of the stroke, pointed at both ends.
                w = math.sin(t * math.pi) * (2.2 if f < 3 else 1.2)
                head = t > reach - 0.18 and f < 2
                for d in range(0, int(w) + 1):
                    fr.set(x, y + d, white if head or d == 0 and f < 3 else red)
                if f < 3 and w > 1.0:
                    fr.set(x, y + int(w) + 1, dark)
        fr.outline()


def chain(img):
    """Heavy iron links, alternating face-on rings and edge-on bars; the
    pattern repeats every 12px so frames tile along the lash."""
    dark, mid, lite = (70, 72, 82, 255), (150, 152, 164, 255), (215, 218, 228, 255)
    for f in range(4):
        fr = Frame(img, f, 6)
        shift = (f % 2) * 2
        for k in range(2):
            x0 = k * 12 + shift
            # Face-on ring: an oval 8 x 7 with a hole.
            for a in range(24):
                ang = a * math.pi / 12
                for rr in (3.2, 2.4):
                    fr.set(x0 + 4 + math.cos(ang) * rr, 12 + math.sin(ang) * rr * 0.9, mid if rr > 3 else lite)
            fr.set(x0 + 3, 10, lite)
            # Edge-on link: a short thick bar.
            for x in range(x0 + 8, x0 + 13):
                fr.set(x % 24, 11, lite)
                fr.set(x % 24, 12, mid)
                fr.set(x % 24, 13, dark)
        fr.outline()


def shard(img):
    for f in range(4):
        fr = Frame(img, f, 7)
        for i in range(16):
            w = int(3 - abs(i - 9) * 0.35)
            for d in range(-w, w + 1):
                fr.set(4 + i, 12 + d, (150, 210, 250, 255) if d != 0 else (235, 250, 255, 255))
        fr.set(19 - f, 11, (255, 255, 255, 255))
        fr.outline()


def soul_blade(img):
    for f in range(4):
        fr = Frame(img, f, 8)
        a = f * math.pi / 4
        c, s_ = math.cos(a), math.sin(a)
        for i in range(-9, 10):
            for w in (-1, 0, 1):
                x = 11.5 + c * i - s_ * w
                y = 11.5 + s_ * i + c * w
                col = (120, 240, 220, 255) if i > -4 else (60, 120, 110, 255)
                fr.set(x, y, col)
        for w in range(-4, 5):
            fr.set(11.5 + c * -4 - s_ * w, 11.5 + s_ * -4 + c * w, (80, 160, 150, 255))
        fr.outline()


def soul_skull(img):
    for f in range(4):
        fr = Frame(img, f, 9)
        fr.disc(12, 10, 6, (190, 170, 240, 255))
        fr.disc(12, 14, 4, (170, 150, 220, 255))
        fr.disc(9.5, 10, 1.6, (30, 10, 50, 255))
        fr.disc(14.5, 10, 1.6, (30, 10, 50, 255))
        fr.line(10, 16, 14, 16, (30, 10, 50, 255))
        for k in range(3):
            fr.set(4 - k + (f % 2), 12 + k * 2, (150, 110, 220, 255))
        fr.outline()


def dragon_fire(img):
    for f in range(4):
        fr = Frame(img, f, 10)
        r = 4 + f * 1.8
        fr.disc(11.5, 11.5, r + 1.5, (200, 60, 20, 255))
        fr.disc(11.5, 11.5, r, (250, 140, 40, 255))
        fr.disc(11.0, 11.0, max(1.0, r - 3), (255, 230, 140, 255))
        if f < 3:
            fr.outline()


def main():
    img = Image.new("RGBA", (4 * F, 11 * F))
    orb(img)
    flail(img)
    javelin(img)
    axe(img)
    smite(img)
    claw(img)
    chain(img)
    shard(img)
    soul_blade(img)
    soul_skull(img)
    dragon_fire(img)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("saved", OUT)
    boss = Image.new("RGBA", (4 * F, 6 * F))
    death_bolt(boss)
    orb(boss, 1, ((40, 120, 60, 255), (90, 220, 110, 255), (200, 255, 190, 255)))
    death_bolt(boss, 2, ((60, 140, 190, 255), (90, 180, 230, 255), (170, 230, 255, 255), (255, 255, 255, 255)))
    orb(boss, 3, ((120, 170, 220, 255), (200, 230, 255, 255), (250, 252, 255, 255)))
    death_bolt(boss, 4, ((110, 130, 30, 255), (150, 170, 40, 255), (200, 220, 90, 255), (240, 250, 190, 255)))
    orb(boss, 5, ((80, 70, 30, 255), (130, 120, 50, 255), (190, 180, 100, 255)))
    boss.save(os.path.join(os.path.dirname(OUT), "boss_fx.png"))


if __name__ == "__main__":
    main()
