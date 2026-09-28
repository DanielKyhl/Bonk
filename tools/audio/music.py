"""Renders the music loops to game/assets/audio/music/<name>.ogg.

    python3 tools/audio/music.py [name ...]

Each track is written as notes on a timeline (beats), mixed in stereo with
a reverb send, and its tail is folded back onto the start so the loop is
seamless. Everything is synthesized (see dsp.py).
"""
import os
import sys
import zlib

import numpy as np
import soundfile as sf
from scipy import signal

import dsp
from dsp import SR, bell, bowed, choir, drum, hp, lp, bp, noise, pad, pluck, swell, n_of, soft_clip

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "audio", "music")


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def m(name):
    """'D3' -> MIDI number."""
    return 12 * (int(name[-1]) + 1) + NOTE[name[:-1]]


class Track:
    """A circular timeline: anything that runs past the loop end (long
    notes, reverb tails) wraps onto the start, so the loop is seamless."""

    def __init__(self, bpm, bars):
        self.spb = 60.0 / bpm
        self.bars = bars
        self.length = bars * 4 * self.spb
        n = n_of(self.length)
        self.dry = np.zeros((n, 2))
        self.send = np.zeros((n, 2))

    def beat(self, b):
        return b * self.spb

    @staticmethod
    def _wrap_add(buf, i, x):
        n = len(buf)
        i %= n
        while len(x):
            j = min(n - i, len(x))
            buf[i:i + j] += x[:j]
            x = x[j:]
            i = 0

    def add(self, x, at_beat, gain=1.0, pan=0.0, verb=0.3):
        """Places mono x at a beat (negative beats count back from the loop
        end), panned -1 left .. 1 right, with some of it sent to the reverb."""
        i = int(round(self.beat(at_beat) * SR))
        a = (pan + 1.0) * np.pi / 4.0
        lr = np.array([np.cos(a), np.sin(a)]) * np.sqrt(2.0)
        seg = (x * gain)[:, None] * lr
        self._wrap_add(self.dry, i, seg * (1.0 - verb * 0.5))
        self._wrap_add(self.send, i, seg * verb)

    def render(self, rt60=3.0, bright=3500.0, loud_db=-17.0):
        ir = dsp.reverb_ir(rt60, bright, 0.03)
        out = self.dry.copy()
        for c in range(2):
            wet = signal.fftconvolve(self.send[:, c], ir[:, c])
            col = np.zeros(len(out))
            self._wrap_add(col, 0, wet)
            out[:, c] += col
        # Filter two laps and keep the second, so the filter has no start-up
        # transient at the seam.
        out = hp(np.concatenate([out, out]), 30.0)[len(out):]
        rms = np.sqrt(np.mean(out ** 2))
        out *= 10 ** (loud_db / 20.0) / max(rms, 1e-9)
        return soft_clip(out, 1.2) * 0.97


# --- Parts ----------------------------------------------------------------------------------------
def chords_choir(tr, prog, bars_each, vowel="oh", gain=0.5, octave_shift=0, verb=0.5):
    """Held choir chords; each overlaps the next by a beat so the loop seam
    lands inside a crossfade."""
    beats = bars_each * 4
    for k, chord in enumerate(prog):
        dur = tr.beat(beats + 1.5)
        for v, note in enumerate(chord):
            f = mtof(m(note) + 12 * octave_shift)
            tr.add(choir(f, dur, vowel, voices=4, attack=tr.beat(1.5), release=tr.beat(2.0)),
                   k * beats - 0.5, gain / len(chord) * 1.8, pan=(v - 1) * 0.35, verb=verb)


def drone(tr, notes, gain=0.35, cutoff=500, seg_bars=4):
    """A low held drone in overlapping segments (so it loops cleanly)."""
    beats = seg_bars * 4
    for k in range(tr.bars // seg_bars):
        for note in notes:
            dur = tr.beat(beats + 3)
            tr.add(pad(mtof(m(note)), dur, 3, cutoff, attack=tr.beat(2.5), release=tr.beat(2.5), spread=8),
                   k * beats - 1.5, gain / len(notes), verb=0.3)


def wind(tr, gain=0.18, lo=300, hi=1400, seg_bars=4):
    beats = seg_bars * 4
    for k in range(tr.bars // seg_bars):
        dur = tr.beat(beats + 3)
        x = dsp.sweep(noise(dur), "band", lambda t: lo + (hi - lo) * (0.5 + 0.5 * np.sin(t * 0.7 + k)), 0.6)
        tr.add(x * swell(dur, tr.beat(3), tr.beat(3)), k * beats - 1.5, gain, pan=0.3 * (1 if k % 2 else -1), verb=0.5)


def taiko(tr, bars, pattern, gain=1.0, f=(70, 42), verb=0.25, accent=None):
    """pattern: list of eighth-note steps (0..7) per bar."""
    for bar in bars:
        for step in pattern:
            v = 1.0 if accent is None or step in accent else 0.7
            tr.add(drum(f[0] * dsp.rand(0.97, 1.03), f[1], 1.0, 0.35, 0.5, 0.4), bar * 4 + step * 0.5,
                   gain * v * dsp.rand(0.9, 1.0), pan=dsp.rand(-0.1, 0.1), verb=verb)


def toms(tr, bars, steps16, gain=0.5, f=(170, 110), verb=0.2, pan=0.25):
    for bar in bars:
        for step in steps16:
            tr.add(drum(f[0] * dsp.rand(0.95, 1.05), f[1], 0.4, 0.12, 0.8, 0.5), bar * 4 + step * 0.25,
                   gain * dsp.rand(0.75, 1.0), pan=pan * (1 if step % 2 else -1), verb=verb)


def ostinato(tr, roots, bars_each, pattern, gain=0.45, cutoff=700, verb=0.15, octave=0):
    """Low strings: pattern is a list of (eighth step, semitones above root)."""
    for k, root in enumerate(roots):
        for bar in range(bars_each):
            b0 = (k * bars_each + bar) * 4
            for step, semi in pattern:
                f = mtof(m(root) + semi + 12 * octave)
                x = bowed(f, tr.beat(0.5) * 0.95, cutoff, 0.01, 0.06)
                tr.add(x, b0 + step * 0.5, gain * (1.0 if step == 0 else 0.75), pan=-0.15, verb=verb)


def melody(tr, notes, gain=0.35, bright=0.45, pan=0.25, verb=0.4, damp=0.996):
    """notes: (beat, note name, beats long)."""
    for b, note, length in notes:
        tr.add(pluck(mtof(m(note)), tr.beat(length) + 1.2, bright, damp), b, gain, pan=pan, verb=verb)


def bells(tr, notes, gain=0.35, decay_s=3.0, verb=0.5, pan=-0.3):
    for b, note in notes:
        tr.add(bell(mtof(m(note)), decay_s * 1.6, decay_s=decay_s), b, gain, pan=pan, verb=verb)


# --- Tracks -----------------------------------------------------------------------------------------
TRACKS = {}


def track(fn):
    TRACKS[fn.__name__] = fn
    return fn


@track
def menu():
    """Title screen: a slow, cold hymn over a drone. D minor, 66 bpm."""
    tr = Track(66, 16)
    drone(tr, ["D2", "A2"], 0.5, 420)
    wind(tr, 0.12)
    prog = [["D3", "F3", "A3"], ["Bb2", "D3", "F3"], ["G2", "Bb2", "D3"], ["A2", "C#3", "E3"]] * 2
    chords_choir(tr, prog, 2, "oh", 0.55)
    bells(tr, [(0, "D4"), (32, "A3")], 0.3, 3.5)
    arp = []
    for k, chord in enumerate(prog[4:]):
        base = 32 + k * 8
        tones = [c[:-1] + str(int(c[-1]) + 1) for c in chord]
        for i, b in enumerate([0, 1.5, 3, 4, 5.5, 7]):
            if i == 5 and k % 2:
                continue
            arp.append((base + b, tones[i % 3], 1.5))
    melody(tr, arp, 0.22, 0.35, pan=0.3, verb=0.5)
    return tr.render(4.0, 3000, -19)


@track
def vale():
    """Hallowed Vale: war drums, low strings and a dirge. D minor, 92 bpm."""
    tr = Track(92, 16)
    roots = ["D2", "Bb1", "C2", "A1"] * 2
    ostinato(tr, roots, 2, [(0, 0), (1, 0), (2, 12), (3, 0), (4, 0), (5, 7), (6, 12), (7, 7)], 0.5, 650)
    prog = [["D3", "F3", "A3"], ["Bb2", "D3", "F3"], ["C3", "E3", "G3"], ["A2", "C#3", "E3"]] * 2
    chords_choir(tr, prog, 2, "ah", 0.42)
    taiko(tr, range(16), [0, 3, 4], 0.9, accent=[0])
    toms(tr, [b for b in range(16) if b % 4 == 3], [12, 13, 14, 15], 0.45)
    toms(tr, range(16), [4, 12], 0.25, (240, 180))
    bells(tr, [(0, "D4")], 0.3, 3.0)
    motif = [(0, "D4", 1), (1, "F4", 0.5), (1.5, "E4", 0.5), (2, "D4", 1), (3, "C#4", 1),
             (4, "D4", 1.5), (5.5, "A3", 0.5), (6, "Bb3", 1), (7, "A3", 1)]
    mel = []
    for start in (16, 48):
        mel += [(start + b, n, l) for b, n, l in motif]
        mel += [(start + 8 + b, n, l) for b, n, l in [(0, "F4", 1), (1, "G4", 0.5), (1.5, "F4", 0.5), (2, "E4", 1),
                                                          (3, "D4", 1), (4, "C#4", 2), (6, "E4", 1), (7, "A4", 1)]]
    melody(tr, mel, 0.34, 0.5, pan=0.25, verb=0.35)
    return tr.render(2.6, 3500, -21)


@track
def frost():
    """Frostfang Peaks: glassy arpeggios, distant drums, wind. E minor, 84 bpm."""
    tr = Track(84, 16)
    drone(tr, ["E2", "B2"], 0.4, 380)
    wind(tr, 0.2, 800, 3500)
    prog = [["E3", "G3", "B3"], ["C3", "E3", "G3"], ["A2", "C3", "E3"], ["B2", "D#3", "F#3"]] * 2
    chords_choir(tr, prog, 2, "oo", 0.5)
    taiko(tr, range(16), [0, 5], 0.8, f=(60, 38), verb=0.45, accent=[0])
    arp = []
    for k, chord in enumerate(prog):
        tones = [c[:-1] + str(int(c[-1]) + 2) for c in chord]
        for i in range(8):
            arp.append((k * 8 + i, tones[[0, 1, 2, 1][i % 4]] if i % 4 != 3 or k % 2 == 0 else tones[2], 1))
    melody(tr, arp, 0.16, 0.9, pan=0.4, verb=0.6, damp=0.998)
    bells(tr, [(0, "E4"), (16, "B3"), (32, "E4"), (48, "G3")], 0.22, 3.0, 0.6, 0.35)
    return tr.render(3.6, 5000, -22)


@track
def bog():
    """Blightmire: murky drones, hand drums and a crooked phrygian lute. C minor, 88 bpm."""
    tr = Track(88, 16)
    drone(tr, ["C2", "G2", "Db3"], 0.45, 350)
    roots = ["C2", "Db2", "C2", "G1"] * 2
    ostinato(tr, roots, 2, [(0, 0), (3, 0), (4, 1), (6, 0)], 0.42, 450)
    prog = [["C3", "Eb3", "G3"], ["Db3", "F3", "Ab3"], ["C3", "Eb3", "G3"], ["G2", "B2", "D3"]] * 2
    chords_choir(tr, prog, 2, "oh", 0.38, verb=0.45)
    taiko(tr, range(16), [0, 3, 6], 0.7, f=(80, 50), accent=[0])
    toms(tr, range(16), [2, 6, 10, 11, 14], 0.3, (300, 220), pan=0.35)
    mel = []
    phrase = [(0, "C4", 1), (1, "Db4", 1), (2, "C4", 0.5), (2.5, "Bb3", 0.5), (3, "G3", 1),
              (4, "Ab3", 1.5), (5.5, "G3", 0.5), (6, "F3", 1), (7, "G3", 1)]
    for start in (8, 24, 40, 56):
        mel += [(start + b, n, l) for b, n, l in phrase]
    melody(tr, mel, 0.3, 0.3, pan=-0.25, verb=0.35, damp=0.994)
    return tr.render(2.4, 2500, -21)


@track
def boss():
    """The boss: relentless drums, stabbing strings and a choir. D minor, 128 bpm."""
    tr = Track(128, 16)
    roots = ["D2", "D2", "Eb2", "D2", "Bb1", "C2", "A1", "A1"]
    ostinato(tr, roots, 2, [(k, s) for k, s in enumerate([0, 0, 12, 0, 1, 0, 12, 7])], 0.55, 900)
    taiko(tr, range(16), [0, 2, 3, 4, 6], 0.95, accent=[0, 4])
    toms(tr, range(16), [2, 6, 10, 14], 0.35, (220, 150))
    toms(tr, [b for b in range(16) if b % 2 == 1], [8, 9, 10, 11, 12, 13, 14, 15], 0.4, (180, 120))
    prog = [["D3", "F3", "A3"], ["D3", "F3", "A3"], ["Eb3", "G3", "Bb3"], ["D3", "F3", "A3"],
            ["Bb2", "D3", "F3"], ["C3", "E3", "G3"], ["A2", "C#3", "E3"], ["A2", "C#3", "E3"]]
    chords_choir(tr, prog, 2, "ah", 0.5)
    stabs = []
    for bar in range(16):
        chord = prog[bar // 2]
        for step in (1.5, 3.5):
            for note in chord:
                stabs.append((bar * 4 + step, note))
    for b, note in stabs:
        f = mtof(m(note))
        x = lp(dsp.saw(f, 0.3) + dsp.saw(f * 1.005, 0.3), 1800) * dsp.decay(0.3, 0.08)
        tr.add(x, b, 0.14, pan=0.2, verb=0.3)
    bells(tr, [(0, "D4"), (32, "D4")], 0.3, 2.5)
    return tr.render(2.0, 4000, -19)


def write_ogg(path, x, block=SR // 2):
    """libsndfile's Vorbis encoder can crash on one huge write: feed it blocks."""
    x = np.ascontiguousarray(x, dtype=np.float32)
    with sf.SoundFile(path, "w", SR, x.shape[1] if x.ndim > 1 else 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(x), block):
            f.write(x[i:i + block])


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(TRACKS)
    for name in names:
        dsp.seed(zlib.crc32(name.encode()))
        x = TRACKS[name]()
        path = os.path.join(OUT, name + ".ogg")
        write_ogg(path, x)
        print("%s: %.1fs, %d KB" % (name, len(x) / SR, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
