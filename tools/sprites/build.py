"""Builds the game's character sprite atlases from Universal LPC layers.

    python3 tools/sprites/build.py /path/to/Universal-LPC-Spritesheet-Character-Generator

Writes game/assets/sprites/<id>.png, their layout to scripts/data/sprite_meta.gd, and
game/assets/sprites/CREDITS.txt listing every source sheet's authors and
licenses (required by CC-BY / OGA-BY / GPL).
"""
import csv
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from lpc import FRAME, Lpc, compose, outline  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "sprites")

## Atlas rows: (anim, frames, directions). Directions are up, left, down, right.
ANIMS = [("walk", 9, 4), ("slash", 6, 4), ("hurt", 6, 1)]
CASTER_ANIMS = [("walk", 9, 4), ("spellcast", 7, 4), ("hurt", 6, 1)]


def metal(target):
    return ("metal", "steel", target)


def cloth(target):
    return ("cloth", "white", target)


def grime(r, g, b):
    """Bone gone yellow-grey with age."""
    l = (r + g + b) / 3.0
    return (l * 0.86 + 14, l * 0.80 + 10, l * 0.66 + 6)


def deathly(r, g, b):
    """Bone bleached cold and blue, for the Lich."""
    l = (r + g + b) / 3.0
    return (l * 0.72 + 8, l * 0.8 + 14, l * 0.92 + 26)


CHARACTERS = {
    "crusader": [
        {"path": "cape/solid/bg", "z": 5, "recolor": cloth("maroon")},
        {"path": "shield/crusader/bg|crusader", "z": 2},
        {"path": "weapon/blunt/flail/behind|flail", "z": 9},
        {"path": "body/bodies/male", "z": 10},
        {"path": "feet/armour/plate/male", "z": 15, "recolor": metal("steel")},
        {"path": "legs/armour/plate/male", "z": 20, "recolor": metal("steel")},
        {"path": "torso/armour/plate/male", "z": 60, "recolor": metal("steel")},
        {"path": "arms/armour/plate/male", "z": 60, "recolor": metal("steel")},
        {"path": "shoulders/pauldrons/male", "z": 61, "recolor": ("metal", "steel", "gold")},
        {"path": "arms/hands/gloves/male", "z": 70, "recolor": metal("iron")},
        {"path": "cape/solid/fg", "z": 85, "recolor": cloth("maroon")},
        {"path": "cape/trim", "z": 90, "recolor": ("cloth", "brown", "yellow")},
        {"path": "head/heads/human/male", "z": 100},
        {"path": "shield/crusader/fg/male|crusader", "z": 110},
        {"path": "hat/helmet/greathelm/male", "z": 130, "recolor": metal("steel")},
        {"path": "weapon/blunt/flail|flail", "z": 140},
    ],
    "skeleton": [
        {"path": "body/bodies/skeleton", "z": 10, "fn": grime},
        {"path": "head/heads/skeleton/adult", "z": 100, "fn": grime},
    ],
    "ghoul": [
        {"path": "body/bodies/zombie|zombie", "z": 10},
        {"path": "head/heads/zombie/adult", "z": 100},
        {"path": "cape/tattered/bg", "z": 5, "recolor": cloth("charcoal")},
        {"path": "cape/tattered/fg", "z": 85, "recolor": cloth("charcoal")},
    ],
    "skeleton_warrior": [
        {"path": "body/bodies/skeleton", "z": 10, "fn": grime},
        {"path": "head/heads/skeleton/adult", "z": 100, "fn": grime},
        {"path": "torso/armour/plate/male", "z": 60, "recolor": metal("iron")},
        {"path": "legs/armour/plate/male", "z": 20, "recolor": metal("iron")},
        {"path": "shoulders/pauldrons/male", "z": 61, "recolor": ("metal", "steel", "copper")},
        {"path": "hat/helmet/greathelm/male", "z": 130, "recolor": metal("iron")},
        {"path": "weapon/sword/longsword|longsword", "z": 140},
        {"path": "weapon/sword/longsword/universal_behind|longsword", "z": 9},
    ],
    "lich": [
        {"path": "cape/tattered/bg", "z": 5, "recolor": cloth("black")},
        {"path": "weapon/polearm/scythe/universal_behind|scythe", "z": 9, "anims": {"spellcast": None}},
        {"path": "body/bodies/skeleton", "z": 10, "fn": deathly},
        {"path": "torso/clothes/robe/female|black", "z": 35},
        {"path": "cape/tattered/fg", "z": 85, "recolor": cloth("black")},
        {"path": "head/heads/skeleton/adult", "z": 100, "fn": deathly},
        {"path": "hat/formal/crown/adult|crown_gold", "z": 130},
        {"path": "weapon/polearm/scythe|scythe", "z": 140, "anims": {"spellcast": None}},
    ],
    "skeleton_mage": [
        {"path": "cape/tattered/bg", "z": 5, "recolor": cloth("purple")},
        {"path": "body/bodies/skeleton", "z": 10, "fn": grime},
        {"path": "head/heads/skeleton/adult", "z": 100, "fn": grime},
        {"path": "cape/tattered/fg", "z": 85, "recolor": cloth("purple")},
    ],
}

CHAR_ANIMS = {"skeleton_mage": CASTER_ANIMS, "lich": CASTER_ANIMS}


def build(lpc, cid, layers):
    anims = CHAR_ANIMS.get(cid, ANIMS)
    cols = max(a[1] for a in anims)
    rows = sum(a[2] for a in anims)
    atlas = Image.new("RGBA", (cols * FRAME, rows * FRAME))
    meta = {"frame": FRAME, "cols": cols, "rows": rows, "anims": {}}
    row = 0
    for name, frames, dirs in anims:
        sheet = compose(lpc, layers, name, frames)
        atlas.alpha_composite(sheet.crop((0, 0, frames * FRAME, dirs * FRAME)), (0, row * FRAME))
        meta["anims"][name] = {"row": row, "frames": frames, "dirs": dirs}
        row += dirs
    outline(atlas)
    atlas.save(os.path.join(OUT, cid + ".png"))
    print(cid, atlas.size)
    return meta


def credits(lpc):
    """Matches every used sheet against CREDITS.csv (longest path prefix)."""
    rows = []
    with open(os.path.join(lpc.root, "CREDITS.csv"), newline="") as f:
        for r in csv.DictReader(f):
            rows.append(r)
    lines = [
        "Character sprites are composited from the Universal LPC Spritesheet Character Generator",
        "(https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator).",
        "Sources, authors and licenses of each sheet used:",
        "",
    ]
    seen = set()
    for used in sorted(lpc.used):
        best = None
        for r in rows:
            p = r.get("filename", "")
            if used.startswith(p) and (best is None or len(p) > len(best["filename"])):
                best = r
        if best is None or best["filename"] in seen:
            continue
        seen.add(best["filename"])
        lines.append(best["filename"])
        lines.append("  Authors: " + best.get("authors", "").replace("\n", ", "))
        lines.append("  Licenses: " + best.get("licenses", "").replace("\n", ", "))
        urls = best.get("urls", "").replace("\n", " ")
        if urls:
            lines.append("  Links: " + urls)
        lines.append("")
    with open(os.path.join(OUT, "CREDITS.txt"), "w") as f:
        f.write("\n".join(lines))


def write_meta(metas):
    """Atlas layouts as a GDScript constant (JSON files aren't exported)."""
    lines = [
        "class_name SpriteMeta",
        "extends RefCounted",
        "## Generated by tools/sprites/build.py. Atlas layout of each character sprite:",
        "## anim -> [first row, frames, directions]. Frames are 64px.",
        "",
        "const ATLASES := {",
    ]
    for cid, meta in metas.items():
        anims = ", ".join('"%s": [%d, %d, %d]' % (n, a["row"], a["frames"], a["dirs"]) for n, a in meta["anims"].items())
        lines.append('\t"%s": {"cols": %d, "rows": %d, "anims": {%s}},' % (cid, meta["cols"], meta["rows"], anims))
    lines.append("}")
    with open(os.path.join(ROOT, "game", "scripts", "data", "sprite_meta.gd"), "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    lpc = Lpc(sys.argv[1] if len(sys.argv) > 1 else "/home/user/pixel/lpc")
    os.makedirs(OUT, exist_ok=True)
    metas = {}
    for cid, layers in CHARACTERS.items():
        metas[cid] = build(lpc, cid, layers)
    write_meta(metas)
    credits(lpc)


if __name__ == "__main__":
    main()
