"""Synthesizes the paper and dock foley into sounds/ (16-bit mono WAV).

All sounds are generated here from noise and sine waves, so they are ours to
ship. Run: python tools/make_sounds.py [project]
"""
import sys, wave, pathlib
import numpy as np

SR = 44100
rng = np.random.default_rng(7)
out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".") / "sounds"
out.mkdir(exist_ok=True)


def t(sec):
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


def bandpass(x, lo, hi):
    return lowpass(x, hi) - lowpass(x, lo)


def env(n, attack, decay):
    tt = np.arange(n) / SR
    e = np.minimum(tt / max(attack, 1e-4), 1.0) * np.exp(-tt / decay)
    return e


def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    with wave.open(str(out / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("wrote", name)


# Rubber stamp: a dull low thump plus a short papery slap.
n = int(SR * 0.35)
tt = t(0.35)
thump = np.sin(2 * np.pi * (95 - 50 * tt) * tt) * env(n, 0.002, 0.06)
slap = bandpass(noise(0.35), 300, 3000) * env(n, 0.001, 0.018)
save("stamp", thump * 1.0 + slap * 2.5, 0.9)

# Pen scratch: bursts of high band noise, like three short strokes.
x = np.zeros(int(SR * 0.6))
for start, ln in [(0.0, 0.14), (0.18, 0.2), (0.42, 0.12)]:
    s = int(start * SR)
    seg = bandpass(noise(ln), 2000, 7000)
    m = len(seg)
    wob = 0.6 + 0.4 * np.sin(2 * np.pi * 23 * np.arange(m) / SR) ** 2
    seg *= np.sin(np.linspace(0, np.pi, m)) * wob
    x[s:s + m] += seg
save("pen", x, 0.5)

# Paper slide: a soft swish that rises and falls.
ln = 0.45
seg = bandpass(noise(ln), 600, 5000)
save("paper", seg * np.sin(np.linspace(0, np.pi, len(seg))) ** 1.5, 0.45)

# Page flip: quick paper swish with a flap at the end.
seg = bandpass(noise(0.22), 800, 6000) * np.linspace(0.3, 1, int(SR * 0.22)) ** 2
flap = bandpass(noise(0.08), 200, 2000) * env(int(SR * 0.08), 0.001, 0.015)
save("flip", np.concatenate([seg, flap * 2]), 0.45)

# Tick: a pencil tapping a box.
n = int(SR * 0.08)
save("tick", bandpass(noise(0.08), 1500, 6000) * env(n, 0.0005, 0.008), 0.5)

# Hydraulic hiss: a clunk then a falling hiss.
n = int(SR * 1.4)
tt = t(1.4)
hiss = bandpass(noise(1.4), 2500, 9000) * env(n, 0.05, 0.45)
clunk = np.sin(2 * np.pi * 60 * tt) * env(n, 0.002, 0.08)
save("hiss", hiss * 0.8 + clunk, 0.35)

# PA chime: two soft tones, station announcement.
tt = t(1.3)
n = len(tt)
c1 = np.sin(2 * np.pi * 659 * tt) * env(n, 0.01, 0.35)
c2 = np.zeros(n)
s = int(0.32 * SR)
c2[s:] = (np.sin(2 * np.pi * 523 * tt[: n - s]) * env(n - s, 0.01, 0.45))
save("chime", c1 + c2 + 0.3 * np.sin(2 * np.pi * 1318 * tt) * env(n, 0.01, 0.2), 0.35)

# Radio squelch: a click, a burst of band-limited static, a click.
n = int(SR * 0.3)
st = bandpass(noise(0.3), 400, 3200) * np.concatenate([np.ones(int(SR * 0.22)), np.linspace(1, 0, n - int(SR * 0.22))])
click = np.zeros(n)
click[:60] = np.sin(np.linspace(0, np.pi * 6, 60))
save("radio", st * 0.7 + click, 0.4)

# Dock hum: a seamless 8 s loop of low machinery drone.
L = 8.0
tt = t(L)
hum = (np.sin(2 * np.pi * 50 * tt) * 0.5 + np.sin(2 * np.pi * 100 * tt) * 0.25
       + np.sin(2 * np.pi * 150 * tt) * 0.1)
hum *= 0.8 + 0.2 * np.sin(2 * np.pi * tt / L * 2)
rumble = lowpass(noise(L), 180) * 6
air = bandpass(noise(L), 400, 1600) * 0.6
x = hum + rumble + air
fade = int(SR * 0.5)  # crossfade the tail into the head so it loops
x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
save("dock_hum", x[:-fade], 0.3)
