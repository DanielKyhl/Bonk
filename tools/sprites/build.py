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


def icy(r, g, b):
    """Frozen bone, blue-white (Frostfang draugr)."""
    l = (r + g + b) / 3.0
    return (l * 0.66 + 8, l * 0.82 + 18, l * 0.95 + 34)


def rot(r, g, b):
    """Swamp-rotted flesh, sickly green (Blightmire)."""
    return (r * 0.72, g * 0.9 + 12, b * 0.62)


def pale(r, g, b):
    """Drowned-blue flesh (ice wraiths)."""
    l = (r + g + b) / 3.0
    return (l * 0.62 + 16, l * 0.76 + 26, l * 0.92 + 44)


def dragon_red(r, g, b):
    """Green scales turned blood red (Dragonborn)."""
    return (g * 1.05 + 12, r * 0.5 + 4, b * 0.45)


def stone(r, g, b):
    """Grey rune-stone (Rune Golem)."""
    l = (r + g + b) / 3.0
    return (l * 0.68 + 22, l * 0.7 + 24, l * 0.78 + 30)


def ghostly(r, g, b):
    """Pale spectral teal (Wraith Knight)."""
    l = (r + g + b) / 3.0
    return (l * 0.5 + 12, l * 0.86 + 30, l * 0.82 + 40)


def body(target):
    return ("body", "light", target)


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
    # --- Heroes ---
    "dragonborn": [
        {"path": "body/wings/lizard/adult/bg", "z": 4, "recolor": body("green"), "fn": dragon_red},
        {"path": "body/tail/lizard/adult/bg", "z": 6, "recolor": body("green"), "fn": dragon_red},
        {"path": "body/bodies/male", "z": 10, "recolor": body("green"), "fn": dragon_red},
        {"path": "legs/armour/plate/male", "z": 20, "recolor": metal("bronze")},
        {"path": "torso/armour/plate/male", "z": 60, "recolor": metal("bronze")},
        {"path": "shoulders/pauldrons/male", "z": 61, "recolor": ("metal", "steel", "gold")},
        {"path": "head/heads/lizard/male", "z": 100, "fn": dragon_red},
        {"path": "body/tail/lizard/adult/fg", "z": 105, "recolor": body("green"), "fn": dragon_red},
        {"path": "body/wings/lizard/adult/fg", "z": 106, "recolor": body("green"), "fn": dragon_red},
    ],
    "stormcaller": [
        {"path": "cape/solid/bg", "z": 5, "recolor": cloth("navy")},
        {"path": "body/bodies/female", "z": 10},
        {"path": "torso/clothes/robe/female|blue", "z": 35},
        {"path": "cape/solid/fg", "z": 85, "recolor": cloth("navy")},
        {"path": "cape/trim", "z": 90, "recolor": ("cloth", "brown", "yellow")},
        {"path": "head/heads/human/female", "z": 100},
        {"path": "hat/magic/wizard/base/adult|blue", "z": 130},
    ],
    "werewolf": [
        {"path": "body/tail/wolf/adult/bg|fur_brown", "z": 6},
        {"path": "body/bodies/male", "z": 10, "recolor": body("fur_brown")},
        {"path": "legs/armour/plate/male", "z": 20, "recolor": metal("iron")},
        {"path": "arms/hands/gloves/male", "z": 70, "recolor": metal("iron")},
        {"path": "head/heads/wolf/male", "z": 100},
        {"path": "body/tail/wolf/adult/fg|fur_brown", "z": 105},
    ],
    "chainwarden": [
        {"path": "weapon/blunt/flail/behind|flail", "z": 9},
        {"path": "body/bodies/male", "z": 10},
        {"path": "legs/armour/plate/male", "z": 20, "recolor": metal("iron")},
        {"path": "torso/armour/plate/male", "z": 60, "recolor": metal("iron")},
        {"path": "arms/armour/plate/male", "z": 60, "recolor": metal("iron")},
        {"path": "shoulders/pauldrons/male", "z": 61, "recolor": ("metal", "steel", "iron")},
        {"path": "head/heads/human/male", "z": 100},
        {"path": "hat/cloth/hood/adult", "z": 130, "recolor": cloth("black")},
        {"path": "weapon/blunt/flail|flail", "z": 140},
    ],
    "frost_witch": [
        {"path": "cape/tattered/bg", "z": 5, "recolor": cloth("sky")},
        {"path": "body/bodies/female", "z": 10, "recolor": body("lavender")},
        {"path": "torso/clothes/robe/female|white", "z": 35},
        {"path": "cape/tattered/fg", "z": 85, "recolor": cloth("sky")},
        {"path": "head/heads/human/female", "z": 100, "recolor": body("lavender")},
        {"path": "hat/magic/wizard/base/adult|white", "z": 130},
    ],
    "rune_golem": [
        {"path": "body/bodies/male", "z": 10, "fn": stone},
        {"path": "legs/armour/plate/male", "z": 20, "recolor": metal("copper")},
        {"path": "shoulders/pauldrons/male", "z": 61, "recolor": ("metal", "steel", "copper")},
        {"path": "arms/hands/gloves/male", "z": 70, "recolor": metal("copper")},
        {"path": "head/heads/troll/adult", "z": 100, "fn": stone},
    ],
    "wraith_knight": [
        {"path": "cape/tattered/bg", "z": 5, "recolor": cloth("black")},
        {"path": "weapon/sword/longsword/universal_behind|longsword", "z": 9},
        {"path": "body/bodies/skeleton", "z": 10, "fn": ghostly},
        {"path": "legs/armour/plate/male", "z": 20, "recolor": metal("iron")},
        {"path": "torso/armour/plate/male", "z": 60, "recolor": metal("iron")},
        {"path": "cape/tattered/fg", "z": 85, "recolor": cloth("black")},
        {"path": "head/heads/skeleton/adult", "z": 100, "fn": ghostly},
        {"path": "hat/helmet/greathelm/male", "z": 130, "recolor": metal("iron")},
        {"path": "weapon/sword/longsword|longsword", "z": 140},
    ],
    "necromancer": [
        {"path": "cape/tattered/bg", "z": 5, "recolor": cloth("black")},
        {"path": "body/bodies/male", "z": 10, "recolor": body("taupe")},
        {"path": "legs/armour/plate/male", "z": 20, "recolor": metal("iron")},
        {"path": "torso/armour/plate/male", "z": 60, "recolor": metal("iron")},
        {"path": "cape/tattered/fg", "z": 85, "recolor": cloth("black")},
        {"path": "head/heads/human/male", "z": 100, "recolor": body("taupe")},
        {"path": "hat/cloth/hood/adult", "z": 130, "recolor": cloth("purple")},
    ],
    "chronomancer": [
        {"path": "cape/solid/bg", "z": 5, "recolor": cloth("purple")},
        {"path": "body/bodies/female", "z": 10, "recolor": body("amber")},
        {"path": "torso/clothes/robe/female|purple", "z": 35},
        {"path": "cape/solid/fg", "z": 85, "recolor": cloth("purple")},
        {"path": "cape/trim", "z": 90, "recolor": ("cloth", "brown", "yellow")},
        {"path": "head/heads/human/female", "z": 100, "recolor": body("amber")},
        {"path": "hat/magic/wizard/base/adult|purple", "z": 130},
    ],
    # --- Frostfang Peaks ---
    "draugr": [
        {"path": "body/bodies/skeleton", "z": 10, "fn": icy},
        {"path": "head/heads/skeleton/adult", "z": 100, "fn": icy},
        {"path": "hat/helmet/horned/adult", "z": 130, "recolor": metal("iron")},
    ],
    "ice_wraith": [
        {"path": "cape/tattered/bg", "z": 5, "recolor": cloth("white")},
        {"path": "body/bodies/zombie|zombie", "z": 10, "fn": pale},
        {"path": "head/heads/zombie/adult", "z": 100, "fn": pale},
        {"path": "cape/tattered/fg", "z": 85, "recolor": cloth("white")},
    ],
    "draugr_warrior": [
        {"path": "weapon/blunt/waraxe/behind|waraxe", "z": 9},
        {"path": "body/bodies/skeleton", "z": 10, "fn": icy},
        {"path": "legs/armour/plate/male", "z": 20, "recolor": metal("steel")},
        {"path": "torso/armour/plate/male", "z": 60, "recolor": metal("steel")},
        {"path": "head/heads/skeleton/adult", "z": 100, "fn": icy},
        {"path": "hat/helmet/barbarian_viking/adult", "z": 130},
        {"path": "weapon/blunt/waraxe|waraxe", "z": 140},
    ],
    "frost_mage": [
        {"path": "cape/tattered/bg", "z": 5, "recolor": cloth("navy")},
        {"path": "body/bodies/skeleton", "z": 10, "fn": icy},
        {"path": "cape/tattered/fg", "z": 85, "recolor": cloth("navy")},
        {"path": "head/heads/skeleton/adult", "z": 100, "fn": icy},
        {"path": "hat/magic/wizard/base/adult|blue", "z": 130},
    ],
    "draugr_king": [
        {"path": "cape/tattered/bg", "z": 5, "recolor": cloth("navy")},
        {"path": "weapon/blunt/waraxe/behind|waraxe", "z": 9, "anims": {"spellcast": None}},
        {"path": "body/bodies/skeleton", "z": 10, "fn": icy},
        {"path": "legs/armour/plate/male", "z": 20, "recolor": metal("iron")},
        {"path": "torso/armour/plate/male", "z": 60, "recolor": metal("iron")},
        {"path": "shoulders/pauldrons/male", "z": 61, "recolor": ("metal", "steel", "silver")},
        {"path": "cape/tattered/fg", "z": 85, "recolor": cloth("navy")},
        {"path": "head/heads/skeleton/adult", "z": 100, "fn": icy},
        {"path": "hat/helmet/horned/adult", "z": 130, "recolor": metal("silver")},
        {"path": "weapon/blunt/waraxe|waraxe", "z": 140, "anims": {"spellcast": None}},
    ],
    # --- Blightmire ---
    "bog_zombie": [
        {"path": "body/bodies/zombie|zombie", "z": 10, "fn": rot},
        {"path": "head/heads/zombie/adult", "z": 100, "fn": rot},
    ],
    "sackhead": [
        {"path": "body/bodies/zombie|zombie", "z": 10, "fn": rot},
        {"path": "head/heads/zombie/adult", "z": 100, "fn": rot},
        {"path": "hat/cloth/hood_sack/adult", "z": 130, "recolor": cloth("brown")},
    ],
    "bog_brute": [
        {"path": "weapon/blunt/mace/universal_behind|mace", "z": 9},
        {"path": "body/bodies/zombie|zombie", "z": 10, "fn": rot},
        {"path": "legs/armour/plate/male", "z": 20, "recolor": metal("copper")},
        {"path": "torso/armour/plate/male", "z": 60, "recolor": metal("copper")},
        {"path": "head/heads/zombie/adult", "z": 100, "fn": rot},
        {"path": "hat/helmet/greathelm/male", "z": 130, "recolor": metal("copper")},
        {"path": "weapon/blunt/mace|mace", "z": 140},
    ],
    "plague_witch": [
        {"path": "body/bodies/zombie|zombie", "z": 10, "fn": rot},
        {"path": "torso/clothes/robe/female|forest_green", "z": 35},
        {"path": "head/heads/zombie/adult", "z": 100, "fn": rot},
        {"path": "hat/magic/wizard/base/adult|base_black", "z": 130},
    ],
    "mother_rot": [
        {"path": "cape/tattered/bg", "z": 5, "recolor": cloth("black")},
        {"path": "body/bodies/zombie|zombie", "z": 10, "fn": rot},
        {"path": "torso/clothes/robe/female|black", "z": 35},
        {"path": "cape/tattered/fg", "z": 85, "recolor": cloth("black")},
        {"path": "head/heads/zombie/adult", "z": 100, "fn": rot},
        {"path": "hat/magic/wizard/base/adult|base_black", "z": 130},
    ],
    "skeleton_mage": [
        {"path": "cape/tattered/bg", "z": 5, "recolor": cloth("purple")},
        {"path": "body/bodies/skeleton", "z": 10, "fn": grime},
        {"path": "head/heads/skeleton/adult", "z": 100, "fn": grime},
        {"path": "cape/tattered/fg", "z": 85, "recolor": cloth("purple")},
    ],
}

CHAR_ANIMS = {"skeleton_mage": CASTER_ANIMS, "lich": CASTER_ANIMS, "frost_mage": CASTER_ANIMS,
        "draugr_king": CASTER_ANIMS, "plague_witch": CASTER_ANIMS, "mother_rot": CASTER_ANIMS,
        "stormcaller": CASTER_ANIMS, "frost_witch": CASTER_ANIMS, "necromancer": CASTER_ANIMS, "chronomancer": CASTER_ANIMS}


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
