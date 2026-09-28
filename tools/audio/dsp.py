"""Small synthesis toolkit for the game's procedural audio (numpy + scipy).

Everything works on float64 numpy arrays at SR samples per second; mono
unless a function says otherwise (stereo is shape (n, 2)).
"""
import numpy as np
from scipy import signal

SR = 44100
_rng = np.random.default_rng(7)


def seed(s):
    global _rng
    _rng = np.random.default_rng(s)


def rand(a=0.0, b=1.0):
    return float(_rng.uniform(a, b))


def n_of(dur):
    return max(1, int(round(dur * SR)))


def tt(dur):
    return np.arange(n_of(dur)) / SR


def noise(dur):
    return _rng.standard_normal(n_of(dur))


def pad_to(x, n):
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def place(buf, x, at):
    """Adds x into buf starting at time `at` (seconds); clips at the end."""
    i = int(round(at * SR))
    if i >= len(buf):
        return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[:j - i]


# --- Envelopes -------------------------------------------------------------------
def fade_out(x, dur=0.01):
    """Ramps the last `dur` seconds to zero so a cut never clicks."""
    n = min(len(x), n_of(dur))
    x = np.array(x, dtype=float)
    x[len(x) - n:] *= np.linspace(1.0, 0.0, n)
    return x


def decay(dur, tau):
    return fade_out(np.exp(-tt(dur) / tau), 0.01)


def adsr(dur, a, d, s, r):
    """Attack, decay, sustain level, release (release fits inside dur)."""
    n = n_of(dur)
    t = np.arange(n) / SR
    e = np.full(n, s)
    e[t < a] = t[t < a] / max(a, 1e-6)
    m = (t >= a) & (t < a + d)
    e[m] = 1.0 - (1.0 - s) * (t[m] - a) / max(d, 1e-6)
    rs = dur - r
    m = t >= rs
    e[m] *= np.clip(1.0 - (t[m] - rs) / max(r, 1e-6), 0.0, 1.0)
    return e


def swell(dur, attack, release):
    """Smooth (raised-cosine) fade in and out."""
    t = tt(dur)
    e = np.ones_like(t)
    a = t < attack
    e[a] = 0.5 - 0.5 * np.cos(np.pi * t[a] / attack)
    r = t > dur - release
    e[r] *= 0.5 + 0.5 * np.cos(np.pi * (t[r] - (dur - release)) / release)
    return e


# --- Oscillators -------------------------------------------------------------------
def phase_of(freq, dur):
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n_of(dur),))
    return 2.0 * np.pi * np.cumsum(f) / SR


def sine(freq, dur, ph=0.0):
    return np.sin(phase_of(freq, dur) + ph)


def saw(freq, dur, ph=0.0):
    p = (phase_of(freq, dur) + ph) / (2.0 * np.pi)
    return 2.0 * (p - np.floor(p)) - 1.0


def square(freq, dur, duty=0.5):
    p = phase_of(freq, dur) / (2.0 * np.pi)
    return np.where(p - np.floor(p) < duty, 1.0, -1.0)


def glide(f0, f1, dur, tau):
    """Frequency curve falling (or rising) exponentially from f0 to f1."""
    return f1 + (f0 - f1) * np.exp(-tt(dur) / tau)


def vibrato(freq, dur, rate=5.0, depth=0.004, ph=0.0):
    return freq * (1.0 + depth * np.sin(2 * np.pi * rate * tt(dur) + ph))


# --- Filters -------------------------------------------------------------------------
def _sos(kind, f, order):
    nyq = SR / 2.0
    if kind == "band":
        lo, hi = f
        return signal.butter(order, [max(10.0, lo) / nyq, min(hi, nyq * 0.95) / nyq], "bandpass", output="sos")
    return signal.butter(order, min(f, nyq * 0.95) / nyq, {"low": "lowpass", "high": "highpass"}[kind], output="sos")


def lp(x, f, order=2):
    return signal.sosfilt(_sos("low", f, order), x, axis=0)


def hp(x, f, order=2):
    return signal.sosfilt(_sos("high", f, order), x, axis=0)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("band", (lo, hi), order), x, axis=0)


def sweep(x, kind, f_of_t, width=0.5, block=256):
    """Time-varying filter: f_of_t(t) gives the cutoff (or band center) in Hz
    for each block; band width is a fraction of the center."""
    out = np.zeros_like(x)
    zi = None
    for i in range(0, len(x), block):
        f = float(f_of_t(i / SR))
        if kind == "band":
            sos = _sos("band", (f * (1 - width / 2), f * (1 + width / 2)), 2)
        else:
            sos = _sos(kind, f, 2)
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[i:i + block], zi = signal.sosfilt(sos, x[i:i + block], zi=zi)
    return out


def formants(x, vowel):
    """Shapes a buzzy source into a sung vowel."""
    table = {
        "ah": [(700, 110, 1.0), (1100, 120, 0.55), (2600, 160, 0.2)],
        "oh": [(450, 90, 1.0), (800, 100, 0.6), (2830, 160, 0.12)],
        "oo": [(320, 70, 1.0), (870, 90, 0.35), (2250, 150, 0.08)],
        "eh": [(530, 90, 1.0), (1850, 140, 0.45), (2500, 160, 0.2)],
    }
    out = np.zeros_like(x)
    for f, bw, g in table[vowel]:
        out += bp(x, f - bw, f + bw) * g
    return out


# --- Instruments ---------------------------------------------------------------------------
def pluck(freq, dur, bright=0.5, damp=0.996):
    """Karplus-Strong string (lute / harp)."""
    # The loop averages two neighbouring samples (a gentle string lowpass),
    # which adds half a sample to the period.
    n0 = max(2, int(round(SR / freq - 0.5)))
    exc = lp(noise(n0 / SR + 0.001), 800 + 6000 * bright)[:n0]
    x = np.zeros(n_of(dur))
    x[:n0] = exc
    a = np.zeros(n0 + 2)
    a[0] = 1.0
    a[n0] = -damp * 0.5
    a[n0 + 1] = -damp * 0.5
    y = signal.lfilter([1.0], a, x)
    return y * swell(dur, 0.002, min(0.3, dur * 0.3))


def bell(freq, dur, partials=None, decay_s=3.0, bright=1.0):
    """Church-bell partials (hum, prime, tierce, quint, nominal...)."""
    if partials is None:
        partials = [(0.5, 0.6, 1.3), (1.0, 1.0, 1.0), (1.19, 0.5, 0.7), (1.5, 0.35, 0.55),
                    (2.0, 0.45, 0.45), (2.52, 0.25 * bright, 0.3), (3.01, 0.18 * bright, 0.22),
                    (4.1, 0.1 * bright, 0.15)]
    t = tt(dur)
    out = np.zeros_like(t)
    for ratio, amp, dk in partials:
        f = freq * ratio
        if f > SR * 0.45:
            continue
        beat = 1.0 + 0.002 * rand(-1, 1)
        out += amp * np.sin(2 * np.pi * f * beat * t + rand(0, 6.28)) * np.exp(-t / (decay_s * dk))
    strike = bp(noise(0.03), 1500, 6000) * decay(0.03, 0.006) * 0.4 * bright
    out[:len(strike)] += strike
    return fade_out(out, min(0.3, dur * 0.2))


def metal(freqs, dur, tau=0.25):
    """Inharmonic metallic hit (anvils, chains, shields)."""
    t = tt(dur)
    out = np.zeros_like(t)
    for k, f in enumerate(freqs):
        out += np.sin(2 * np.pi * f * t + rand(0, 6.28)) * np.exp(-t / (tau * (1.0 - 0.12 * k))) / (1 + k * 0.4)
    click = hp(noise(0.012), 2500) * decay(0.012, 0.002)
    out[:len(click)] += click * 0.8
    return fade_out(out, min(0.1, dur * 0.2))


def drum(f0, f1, dur, body_tau=0.3, snap=0.4, skin=0.3):
    """Tom / taiko: a falling sine body, a stick click and skin noise."""
    body = sine(glide(f0, f1, dur, 0.05), dur) * decay(dur, body_tau)
    click = lp(noise(0.02), 3000) * decay(0.02, 0.004) * snap
    sk = bp(noise(dur), 120, 900) * decay(dur, body_tau * 0.35) * skin
    return fade_out(np.tanh(mix(body, click, sk) * 1.4), 0.02)


def whoosh(dur, f0, f1, f2=None, width=0.9, curve=0.5):
    """Air movement: band-passed noise whose center moves f0 -> f1 (-> f2)."""
    def f_of(t):
        u = t / dur
        if f2 is None:
            return f0 + (f1 - f0) * u
        return f0 + (f1 - f0) * (u / curve) if u < curve else f1 + (f2 - f1) * ((u - curve) / (1 - curve))
    return sweep(noise(dur), "band", f_of, width) * swell(dur, dur * 0.35, dur * 0.55)


def choir(freq, dur, vowel="ah", voices=4, attack=0.6, release=0.9, spread=9.0):
    """A few detuned buzzy voices through vowel formants."""
    src = np.zeros(n_of(dur))
    for v in range(voices):
        cents = (v - (voices - 1) / 2) * spread + rand(-2, 2)
        f = vibrato(freq * 2 ** (cents / 1200), dur, rand(4.5, 5.8), 0.005, rand(0, 6.28))
        src += saw(f, dur, rand(0, 6.28))
    breath = hp(noise(dur), 2000) * 0.05
    out = formants(src / voices + breath, vowel)
    return out * swell(dur, attack, release)


def pad(freq, dur, voices=3, cutoff=1400, attack=1.0, release=1.2, spread=12.0):
    src = np.zeros(n_of(dur))
    for v in range(voices):
        cents = (v - (voices - 1) / 2) * spread
        src += saw(freq * 2 ** (cents / 1200), dur, rand(0, 6.28))
    return lp(src / voices, cutoff, 2) * swell(dur, attack, release)


def bowed(freq, dur, cutoff=900, attack=0.05, release=0.12):
    """Low string / bass note: saw through a lowpass with a short envelope."""
    src = saw(vibrato(freq, dur, 5.5, 0.002), dur) + 0.5 * saw(freq * 1.003, dur)
    return lp(src, cutoff, 2) * swell(dur, attack, release)


# --- Space and mastering ---------------------------------------------------------------------
def reverb_ir(rt60, bright=4000.0, predelay=0.02, stereo=True, seed_=11):
    """A synthetic hall: decaying noise that darkens as it fades."""
    r = np.random.default_rng(seed_)
    n = n_of(rt60 * 1.2)
    t = np.arange(n) / SR
    env = np.exp(-6.9 * t / rt60)
    chans = []
    for c in range(2 if stereo else 1):
        nz = r.standard_normal(n)
        early = lp(nz, bright) * env
        late = lp(nz, bright * 0.25) * env
        mixw = np.clip(t / (rt60 * 0.5), 0, 1)
        ir = early * (1 - mixw) + late * mixw
        ir = np.concatenate([np.zeros(int(predelay * SR)), ir])
        chans.append(ir / np.sqrt(np.sum(ir ** 2)))
    return np.stack(chans, axis=1) if stereo else chans[0]


def reverb(x, rt60=2.0, wet=0.3, bright=4000.0, predelay=0.02):
    """Mono in: returns stereo (n, 2) if x is mono and stereo reverb."""
    ir = reverb_ir(rt60, bright, predelay)
    if x.ndim == 1:
        dry = np.stack([x, x], axis=1)
    else:
        dry = x
    n = len(dry) + len(ir) - 1
    out = np.zeros((n, 2))
    out[:len(dry)] += dry * (1 - wet)
    for c in range(2):
        src = dry[:, c]
        out[:, c] += signal.fftconvolve(src, ir[:, c]) * wet
    return out


def reverb_mono(x, rt60=1.2, wet=0.25, bright=4000.0, predelay=0.01):
    ir = reverb_ir(rt60, bright, predelay, stereo=False)
    out = np.zeros(len(x) + len(ir) - 1)
    out[:len(x)] += x * (1 - wet)
    out += signal.fftconvolve(x, ir) * wet
    return out


def trim(x, thresh=0.002, fade=0.05):
    """Cuts trailing silence and fades the end."""
    a = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    idx = np.nonzero(a > thresh * max(1e-9, a.max()))[0]
    end = int(idx[-1]) + 1 if len(idx) else len(x)
    x = x[:end].copy()
    nf = min(len(x), int(fade * SR))
    ramp = np.linspace(1, 0, nf)
    if x.ndim == 1:
        x[-nf:] *= ramp
    else:
        x[-nf:] *= ramp[:, None]
    return x


def normalize(x, peak_db=-1.0):
    p = np.max(np.abs(x))
    return x if p == 0 else x / p * 10 ** (peak_db / 20)


def soft_clip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)
