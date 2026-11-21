"""Synthesizes combat sounds into sounds/: guns, flak, torpedo, ion, hits,
explosions. Generated from noise and sine waves, so they are ours to ship.
Run: python tools/make_combat_sounds.py [project]
"""
import sys, wave, pathlib
import numpy as np

SR = 44100
rng = np.random.default_rng(11)
out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".") / "sounds"
out.mkdir(exist_ok=True)


def T(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def lowpass(x, cut):
    a = np.exp(-2 * np.pi * cut / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cut):
    return x - lowpass(x, cut)


def env(n, attack, decay):
    tt = np.arange(n) / SR
    return np.minimum(tt / max(attack, 1e-4), 1.0) * np.exp(-tt / decay)


def sweep(f0, f1, sec, curve=2.0):
    tt = T(sec)
    f = f1 + (f0 - f1) * (1 - tt / sec) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def save(name, x, gain=0.85):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    # tiny fade out so nothing clicks
    k = min(len(x), int(SR * 0.004))
    x[-k:] *= np.linspace(1, 0, k)
    with wave.open(str(out / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("wrote", name)


# Forward cannon: a soft, low "thoom" with a short airy tail. No square wave:
# it fires a lot, so it has to sit under the music, not cut through it.
s = 0.26
n = int(SR * s)
body = sweep(520, 110, s, 2.5) * env(n, 0.003, 0.05)
thump = sweep(140, 45, s) * env(n, 0.001, 0.07)
air = lowpass(noise(s), 1800) * env(n, 0.002, 0.04)
save("cannon", lowpass(body * 0.6 + thump * 1.0 + air * 0.5, 2200), 0.7)

# Turret machine gun: a tight crack and a little body. Very short, it fires fast.
s = 0.09
n = int(SR * s)
crack = highpass(lowpass(noise(s), 5000), 700) * env(n, 0.0003, 0.012)
body = sweep(220, 90, s) * env(n, 0.0005, 0.02)
save("turret", crack * 1.0 + body * 0.7, 0.7)

# Flak burst: a dull pop with a rattle of fragments.
s = 0.35
n = int(SR * s)
pop = lowpass(noise(s), 1400) * env(n, 0.001, 0.05)
thump = sweep(120, 45, s) * env(n, 0.001, 0.07)
frag = highpass(noise(s), 2500) * env(n, 0.01, 0.06) * (rng.uniform(0, 1, n) > 0.985)
save("flak", pop * 1.0 + thump * 0.8 + frag * 0.6, 0.75)

# Torpedo launch: a clunk, then a rising rocket whoosh.
s = 0.9
n = int(SR * s)
tt = T(s)
whoosh = lowpass(noise(s), 900) * np.minimum(tt / 0.15, 1.0) * np.exp(-tt / 0.45)
clunk = sweep(140, 60, s) * env(n, 0.001, 0.04)
roar = highpass(lowpass(noise(s), 2500), 400) * np.minimum(tt / 0.2, 1.0) * np.exp(-tt / 0.3) * 0.5
save("torpedo", whoosh + clunk * 0.9 + roar)

# Ion bolt: a wobbling electric zap.
s = 0.45
n = int(SR * s)
tt = T(s)
fm = np.sin(2 * np.pi * (700 * tt + 40 * np.sin(2 * np.pi * 37 * tt)))
buzz = np.sign(np.sin(2 * np.pi * 120 * tt)) * 0.3
save("ion", (fm * 0.7 + buzz) * env(n, 0.003, 0.12) + highpass(noise(s), 3000) * env(n, 0.001, 0.03) * 0.4, 0.7)

# Shield hit: a bright shimmering ping.
s = 0.3
n = int(SR * s)
tt = T(s)
ping = np.sin(2 * np.pi * 1650 * tt) + 0.6 * np.sin(2 * np.pi * 2470 * tt) + 0.4 * np.sin(2 * np.pi * 3310 * tt + 0.3)
save("hit_shield", ping * env(n, 0.001, 0.07) * (0.8 + 0.2 * np.sin(2 * np.pi * 30 * tt)) + highpass(noise(s), 4000) * env(n, 0.0005, 0.01) * 0.3, 0.55)

# Hull hit: a metal clank, inharmonic partials over a thud.
s = 0.4
n = int(SR * s)
tt = T(s)
clank = sum(a * np.sin(2 * np.pi * f * tt) * np.exp(-tt / d) for f, a, d in [(523, 1.0, 0.09), (1377, 0.6, 0.05), (2213, 0.4, 0.03), (311, 0.5, 0.12)])
thud = sweep(110, 50, s) * env(n, 0.001, 0.05)
save("hit_hull", clank * 0.6 + thud + lowpass(noise(s), 2500) * env(n, 0.0005, 0.015) * 0.6, 0.75)

# Small explosion: a crack, a rolling boom, crackle.
for name, s, deep, tail in [("boom_small", 1.0, 1.0, 0.25), ("boom_big", 2.2, 0.6, 0.6)]:
    n = int(SR * s)
    tt = T(s)
    boom = lowpass(noise(s), 380 * deep) * np.exp(-tt / tail) * 2.5
    sub = sweep(90 * deep, 30, s) * np.exp(-tt / (tail * 0.8))
    crack = lowpass(noise(s), 4000) * env(n, 0.0005, 0.02)
    crackle = highpass(noise(s), 1500) * (rng.uniform(0, 1, n) > 0.993) * np.exp(-tt / (tail * 1.5)) * 1.5
    save(name, boom + sub * 1.2 + crack * 0.8 + crackle)
