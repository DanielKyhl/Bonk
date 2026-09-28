"""Renders every sound effect to game/assets/audio/sfx/<name>.wav (or .ogg
for sounds longer than a second).

    python3 tools/audio/sfx.py

All sounds are synthesized here (see dsp.py): no samples, no licenses.
Keep them short, dry-ish and low: the game plays many at once.
"""
import os
import zlib

import numpy as np
import soundfile as sf

from dsp import *  # noqa: F401,F403

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "audio", "sfx")

SOUNDS = {}


def sound(fn):
    SOUNDS[fn.__name__] = fn
    return fn


# --- Combat ------------------------------------------------------------------------------------
@sound
def hit():
    """A blow landing on bone and rotten flesh."""
    d = 0.16
    body = sine(glide(170, 60, d, 0.03), d) * decay(d, 0.05)
    crack = bp(noise(d), 700, 2600) * decay(d, 0.018) * 0.7
    return np.tanh(mix(body, crack) * 1.8)


@sound
def crit():
    d = 0.3
    base = hit() * 0.9
    snap = hp(noise(0.05), 3000) * decay(0.05, 0.008)
    ring = metal([1760, 2650, 3900], d, 0.08) * 0.35
    return mix(base, snap, ring)


@sound
def bone():
    """Bones clattering apart."""
    d = 0.32
    out = np.zeros(n_of(d))
    for k in range(9):
        at = rand(0, 0.2) * (k / 9) + k * 0.012
        f = rand(1200, 3600)
        click = bp(noise(0.03), f * 0.7, f * 1.3) * decay(0.03, 0.005) * (1.0 - k * 0.07)
        place(out, click, at)
    thud = sine(glide(120, 50, 0.12, 0.03), 0.12) * decay(0.12, 0.04) * 0.6
    return mix(out, thud)


@sound
def swing():
    """A heavy weapon cutting the air."""
    return whoosh(0.26, 350, 1500, 500, 0.9, 0.45) * 1.4


@sound
def claw():
    a = whoosh(0.14, 900, 3200, 1400, 0.8, 0.4)
    rip = bp(noise(0.14), 1800, 5000) * decay(0.14, 0.03) * 0.5
    return mix(a * 1.3, rip)


@sound
def throw():
    return whoosh(0.16, 700, 2600, 1200, 0.8, 0.3) * 1.2


@sound
def smite():
    """A shaft of holy light: a bright strike, a bell and a thump."""
    d = 1.0
    b = bell(880, d, decay_s=0.35, bright=1.2) * 0.5
    zap = hp(noise(0.08), 2500) * decay(0.08, 0.02) * 0.6
    boom = sine(glide(110, 45, 0.4, 0.06), 0.4) * decay(0.4, 0.12)
    return reverb_mono(np.tanh(mix(b, zap, boom) * 1.3), 1.0, 0.2)


@sound
def fire():
    """Dragon breath: a roaring rush with crackles."""
    d = 0.7
    roar = lp(noise(d), 900) * swell(d, 0.05, 0.45)
    roar *= 1.0 + 0.5 * lp(noise(d), 25)
    hiss = sweep(noise(d), "band", lambda t: 2500 - 1500 * t / d, 0.8) * swell(d, 0.02, 0.5) * 0.35
    out = mix(roar, hiss)
    for k in range(10):
        pop = bp(noise(0.01), 2000, 6000) * decay(0.01, 0.002) * rand(0.3, 0.8)
        place(out, pop, rand(0.05, 0.55))
    return np.tanh(out * 1.5)


@sound
def zap():
    """Lightning: a hard crack and a buzzing tail."""
    d = 0.45
    out = np.zeros(n_of(d))
    at = 0.0
    while at < 0.18:
        burst = hp(noise(0.02), 1500) * decay(0.02, 0.005) * rand(0.5, 1.0)
        place(out, burst, at)
        at += rand(0.008, 0.03)
    buzz = saw(62 + 8 * np.sin(2 * np.pi * 13 * tt(d)), d) * bp(noise(d), 200, 3000) * decay(d, 0.12) * 0.5
    boom = sine(glide(90, 40, 0.3, 0.05), 0.3) * decay(0.3, 0.1) * 0.8
    return np.tanh(mix(out * 1.2, buzz, boom) * 1.6)


@sound
def chain():
    """Iron links: a lash and a rattle."""
    d = 0.42
    out = np.zeros(n_of(d))
    place(out, whoosh(0.16, 500, 2200, 900) * 0.8, 0.0)
    for k in range(6):
        f = rand(1500, 2400)
        place(out, metal([f, f * 1.52, f * 2.31], 0.12, 0.03) * (0.7 - k * 0.08), 0.1 + k * 0.035 + rand(0, 0.01))
    return out


@sound
def ice():
    """Frost shards: glassy pings and a crackle."""
    d = 0.5
    out = np.zeros(n_of(d))
    for k in range(5):
        f = rand(2200, 4800)
        ping = (np.sin(2 * np.pi * f * tt(0.25)) + 0.4 * np.sin(2 * np.pi * f * 2.7 * tt(0.25))) * decay(0.25, 0.05)
        place(out, ping * 0.5, k * 0.025 + rand(0, 0.01))
    place(out, whoosh(0.12, 2000, 5000) * 0.6, 0.0)
    crackle = hp(noise(0.2), 4000) * decay(0.2, 0.04) * 0.4
    return reverb_mono(mix(out, crackle), 0.6, 0.2, 7000)


@sound
def slam():
    """The golem's fists hit the ground."""
    d = 0.9
    boom = sine(glide(95, 32, d, 0.08), d) * decay(d, 0.28)
    rumble = lp(noise(d), 260) * decay(d, 0.3) * 1.2
    crunch = bp(noise(0.2), 400, 2200) * decay(0.2, 0.05) * 0.8
    stones = np.zeros(n_of(d))
    for k in range(8):
        f = rand(800, 2500)
        place(stones, bp(noise(0.02), f * 0.7, f * 1.3) * decay(0.02, 0.004) * 0.4, 0.08 + rand(0, 0.35))
    return np.tanh(mix(boom * 1.2, rumble, crunch, stones) * 1.6)


@sound
def soul():
    """The soul blade: a ghostly moan riding a whoosh."""
    d = 0.5
    w = whoosh(d, 300, 1100, 400) * 0.9
    moan = np.zeros(n_of(d))
    for f in (330, 392, 440):
        moan += sine(vibrato(f, d, 6.0, 0.02), d) * 0.25
    moan *= swell(d, 0.1, 0.3)
    return reverb_mono(mix(w, moan), 1.2, 0.35)


@sound
def skull():
    """A screaming skull: a falling shriek."""
    d = 0.45
    f = glide(820, 330, d, 0.15)
    src = saw(vibrato(f, d, 22.0, 0.02), d)
    shriek = formants(src, "eh") * swell(d, 0.02, 0.25)
    breath = bp(noise(d), 1500, 4000) * swell(d, 0.01, 0.3) * 0.25
    return reverb_mono(mix(shriek * 1.2, breath), 0.9, 0.3)


@sound
def rift():
    """Time tears: a warped, sinking tone that swells up."""
    d = 0.9
    f = glide(420, 140, d, 0.35) * (1.0 + 0.06 * np.sin(2 * np.pi * 7 * tt(d)))
    tone = (sine(f, d) + 0.5 * sine(f * 1.51, d) + 0.3 * sine(f * 2.02, d)) * swell(d, 0.25, 0.4)
    air = sweep(noise(d), "band", lambda t: 3000 - 2400 * t / d, 0.5) * swell(d, 0.3, 0.3) * 0.3
    return reverb_mono(mix(tone * 0.6, air), 1.5, 0.35)


# --- Hero ----------------------------------------------------------------------------------------
@sound
def jump():
    return whoosh(0.14, 400, 1200) * 0.8


@sound
def land():
    d = 0.18
    thud = sine(glide(110, 45, d, 0.03), d) * decay(d, 0.045)
    dirt = bp(noise(d), 250, 1200) * decay(d, 0.03) * 0.6
    return np.tanh(mix(thud, dirt) * 1.5)


@sound
def slide():
    d = 0.45
    grit = bp(noise(d), 900, 3200) * (0.7 + 0.3 * lp(np.abs(noise(d)), 60))
    return grit * swell(d, 0.03, 0.3) * 0.9


@sound
def stomp():
    base = land()
    crunch = bone() * 0.7
    return mix(base, crunch)


@sound
def launch():
    """A holy spring or kicker throws you skyward."""
    d = 0.7
    w = whoosh(d, 300, 3000, None, 0.7)
    rise = sine(np.linspace(400, 1300, n_of(d)), d) * swell(d, 0.05, 0.4) * 0.25
    return reverb_mono(mix(w, rise), 1.0, 0.25)


@sound
def hurt():
    """Something tears into you."""
    d = 0.32
    punch = sine(glide(150, 45, d, 0.035), d) * decay(d, 0.06)
    tear = bp(noise(d), 500, 2200) * decay(d, 0.05)
    return np.tanh(mix(punch * 1.1, tear * 1.2) * 2.0)


@sound
def block():
    """Holy Aegis turns a blow: a shield clang."""
    d = 1.0
    clang = metal([523, 1270, 2130, 3120, 4400], d, 0.25)
    thud = sine(glide(160, 70, 0.1, 0.02), 0.1) * decay(0.1, 0.03)
    return reverb_mono(mix(clang * 0.7, thud), 1.1, 0.3)


@sound
def revive():
    d = 2.0
    swellx = choir(147, d, "ah", attack=0.3, release=1.0) + choir(220, d, "ah", attack=0.4, release=1.0)
    boom = sine(glide(80, 35, 0.8, 0.1), 0.8) * decay(0.8, 0.25)
    return reverb_mono(mix(swellx * 0.6, boom, bell(587, d, decay_s=1.2) * 0.3), 2.0, 0.35)


# --- Pickups and rewards ----------------------------------------------------------------------------
@sound
def gem():
    d = 0.14
    t = tt(d)
    tone = (np.sin(2 * np.pi * 1568 * t) + 0.35 * np.sin(2 * np.pi * 3136 * t)) * decay(d, 0.035)
    return tone * 0.6


@sound
def coin():
    d = 0.3
    out = np.zeros(n_of(d))
    place(out, metal([2093, 3140, 4870], 0.2, 0.05) * 0.6, 0.0)
    place(out, metal([2637, 3960, 5600], 0.2, 0.06) * 0.6, 0.05)
    return out


@sound
def heart():
    d = 0.6
    t = tt(d)
    tone = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((523, 0.5), (659, 0.35), (784, 0.3))) * swell(d, 0.02, 0.45)
    return reverb_mono(tone * 0.6, 0.8, 0.25)


@sound
def levelup():
    """A dark hymn rising to a major chord."""
    d = 1.8
    out = np.zeros(n_of(d))
    for f in (147, 185, 220, 294):   # D major
        place(out, choir(f, 1.6, "ah", attack=0.25, release=0.9) * 0.35, 0.0)
    for k, f in enumerate((587, 740, 880, 1175)):
        place(out, pluck(f, 1.0, 0.6) * 0.35, 0.05 + k * 0.07)
    return reverb_mono(out, 1.8, 0.3)


@sound
def chest():
    """An old lid creaks open, the latch drops, something glints."""
    d = 1.1
    out = np.zeros(n_of(d))
    creak_f = 70 + 25 * np.sin(2 * np.pi * 2.5 * tt(0.45)) + 30 * tt(0.45)
    creak = formants(saw(creak_f, 0.45) * (0.6 + 0.4 * np.abs(noise(0.45))), "oh") * swell(0.45, 0.05, 0.1)
    place(out, creak * 0.9, 0.0)
    place(out, land() * 0.8, 0.42)
    for k, f in enumerate((1318, 1760, 2093)):
        place(out, bell(f, 0.6, decay_s=0.25) * 0.18, 0.5 + k * 0.06)
    return reverb_mono(out, 0.9, 0.2)


@sound
def item():
    d = 1.0
    out = np.zeros(n_of(d))
    for k, f in enumerate((659, 880, 1047)):
        place(out, pluck(f, 0.8, 0.7) * 0.5, k * 0.06)
    return reverb_mono(out, 1.2, 0.3)


@sound
def legendary():
    d = 2.2
    out = np.zeros(n_of(d))
    for k, f in enumerate((587, 740, 880, 1175, 1480)):
        place(out, pluck(f, 1.4, 0.8) * 0.45, k * 0.07)
    for f in (294, 370, 440):
        place(out, choir(f, 1.8, "ah", attack=0.3, release=1.0) * 0.3, 0.1)
    place(out, bell(1175, 1.5, decay_s=0.8) * 0.2, 0.35)
    return reverb_mono(out, 2.2, 0.35)


@sound
def toll():
    """A funeral bell: a new wave, an elite, an altar."""
    return reverb_mono(bell(146.8, 4.0, decay_s=2.5), 3.0, 0.35, 3000)


@sound
def prayer():
    """A shrine answers."""
    d = 3.0
    out = bell(392, d, decay_s=1.6) * 0.6
    for f in (196, 247, 294):
        out = mix(out, choir(f, 2.6, "oo", attack=0.4, release=1.4) * 0.3)
    return reverb_mono(out, 2.5, 0.35)


@sound
def curse():
    """The cursed altar wakes."""
    d = 2.4
    out = np.zeros(n_of(d))
    for f in (73.4, 77.8, 110, 116.5):   # minor seconds, low
        out += pad(f, d, 3, 700, attack=0.6, release=1.2) * 0.35
    out += choir(147, d, "oh", attack=0.8, release=1.0) * 0.3
    boom = sine(glide(70, 30, 1.0, 0.15), 1.0) * decay(1.0, 0.35)
    place(out, boom, 0.3)
    return reverb_mono(np.tanh(out * 1.4), 2.5, 0.35)


# --- Boss -------------------------------------------------------------------------------------------
@sound
def boss_roar():
    d = 2.4
    f = 52 * (1 + 0.1 * np.sin(2 * np.pi * 0.6 * tt(d))) * np.linspace(1.15, 0.85, n_of(d))
    src = saw(f, d) + saw(f * 1.5, d) * 0.5 + bp(noise(d), 100, 1200) * 0.8
    roar = formants(src, "ah") * swell(d, 0.25, 0.9)
    growl = lp(src, 300) * swell(d, 0.2, 1.0) * (0.7 + 0.3 * np.sin(2 * np.pi * 23 * tt(d)))
    boom = sine(glide(60, 25, 1.5, 0.2), 1.5) * decay(1.5, 0.5)
    return reverb_mono(np.tanh(mix(roar * 2.0, growl, boom) * 2.0), 2.5, 0.35, 3000)


@sound
def nova():
    d = 0.8
    w = whoosh(d, 200, 900, 300, 1.0, 0.3) * 1.2
    boom = sine(glide(80, 35, d, 0.1), d) * decay(d, 0.2)
    return reverb_mono(np.tanh(mix(w, boom) * 1.5), 1.5, 0.3)


@sound
def bolt():
    d = 0.35
    w = whoosh(d, 1400, 400, None, 0.7) * 0.8
    hum = sine(glide(300, 120, d, 0.1), d) * decay(d, 0.12) * 0.4
    return mix(w, hum)


@sound
def blink():
    """The boss steps through shadow: a reversed swell."""
    x = whoosh(0.5, 200, 2500, None, 0.8)
    x = reverb_mono(x, 0.8, 0.5)[::-1]
    return x * 0.9


@sound
def boss_die():
    d = 3.0
    out = np.zeros(n_of(d))
    f = glide(90, 30, d, 1.0)
    groan = formants(saw(f, d) + saw(f * 1.01, d), "oh") * swell(d, 0.05, 1.8) * 1.5
    place(out, groan, 0.0)
    place(out, slam(), 0.0)
    place(out, bone() * 0.8, 0.1)
    place(out, bell(98, 2.5, decay_s=1.5) * 0.4, 0.4)
    return reverb_mono(np.tanh(out * 1.3), 3.0, 0.35, 3000)


@sound
def portal():
    d = 2.5
    out = np.zeros(n_of(d))
    for f in (294, 370, 440, 587):
        out += choir(f, d, "ah", attack=0.5, release=1.2) * 0.25
    shimmer = sweep(noise(d), "band", lambda t: 1500 + 3000 * t / d, 0.3) * swell(d, 0.6, 1.0) * 0.3
    return reverb_mono(mix(out, shimmer), 2.5, 0.4)


@sound
def death():
    """You fall: a deep boom and a bell far away."""
    d = 4.0
    out = np.zeros(n_of(d))
    boom = sine(glide(70, 25, 2.0, 0.3), 2.0) * decay(2.0, 0.7)
    place(out, boom * 1.2, 0.0)
    for f in (73.4, 87.3, 110):   # D minor, low
        place(out, pad(f, 3.5, 3, 500, attack=0.1, release=2.5) * 0.4, 0.0)
    place(out, bell(146.8, 3.0, decay_s=2.0) * 0.4, 0.6)
    return reverb_mono(np.tanh(out * 1.2), 3.0, 0.4, 2500)


# --- Interface --------------------------------------------------------------------------------------
@sound
def click():
    d = 0.06
    tick = bp(noise(d), 900, 2500) * decay(d, 0.006)
    knock = sine(glide(700, 400, d, 0.01), d) * decay(d, 0.012) * 0.6
    return mix(tick, knock) * 0.8


@sound
def hover():
    d = 0.04
    return bp(noise(d), 1500, 4000) * decay(d, 0.004) * 0.5


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        seed(zlib.crc32(name.encode()))
        x = fn()
        x = trim(np.asarray(x, dtype=float))
        x = normalize(x, -1.0)
        # Long sounds (reverb tails, stingers) as Ogg Vorbis, short ones as WAV.
        for ext in (".wav", ".ogg"):
            stale = os.path.join(OUT, name + ext)
            if os.path.exists(stale):
                os.remove(stale)
        if len(x) > SR:
            sf.write(os.path.join(OUT, name + ".ogg"), x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
        else:
            sf.write(os.path.join(OUT, name + ".wav"), x.astype(np.float32), SR, subtype="PCM_16")
    print("sfx:", len(SOUNDS))


if __name__ == "__main__":
    main()
