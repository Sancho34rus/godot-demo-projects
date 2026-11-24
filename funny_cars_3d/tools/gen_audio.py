#!/usr/bin/env python3
"""Generates the game's sound effects and music as 16-bit mono WAV files.

Pure standard library, so it runs anywhere. Everything is synthesised here, so
no third-party audio is used. Run from the project root:
    python3 tools/gen_audio.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write(name, samples):
    path = os.path.join(OUT, name + ".wav")
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.85 / peak if peak > 0.85 else 1.0
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples)
        w.writeframes(frames)
    print("wrote", path, len(samples) / RATE, "s")


def env_ad(t, attack, decay):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def tone(freq, dur, wave_kind="sine", amp=1.0, a=0.005, d=0.15):
    n = int(dur * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        phase += freq / RATE
        f = phase % 1.0
        if wave_kind == "square":
            v = 1.0 if f < 0.5 else -1.0
        elif wave_kind == "saw":
            v = 2.0 * f - 1.0
        elif wave_kind == "tri":
            v = 4.0 * abs(f - 0.5) - 1.0
        else:
            v = math.sin(2 * math.pi * f)
        out.append(amp * v * env_ad(t, a, d))
    return out


def noise(dur, seed=1):
    rnd = random.Random(seed)
    return [rnd.uniform(-1, 1) for _ in range(int(dur * RATE))]


def lowpass(x, k):
    y = []
    acc = 0.0
    for v in x:
        acc += k * (v - acc)
        y.append(acc)
    return y


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def place(out, sig, at):
    start = int(at * RATE)
    need = start + len(sig)
    if need > len(out):
        out.extend([0.0] * (need - len(out)))
    for i, v in enumerate(sig):
        out[start + i] += v
    return out


def sweep(f0, f1, dur, amp=1.0, kind="sine"):
    n = int(dur * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = f0 + (f1 - f0) * t / dur
        phase += f / RATE
        if kind == "square":
            v = 1.0 if (phase % 1.0) < 0.5 else -1.0
        else:
            v = math.sin(2 * math.pi * phase)
        out.append(amp * v * env_ad(t, 0.01, dur * 0.5))
    return out


# ---------------------------------------------------------------- effects ---
def sfx_click():
    return tone(900, 0.06, amp=0.6, a=0.002, d=0.02)


def sfx_star():
    out = []
    for i, f in enumerate([660, 880, 1175, 1480]):
        out = place(out, tone(f, 0.16, "tri", 0.6, a=0.005, d=0.09), i * 0.07)
    return out


def sfx_success():
    out = []
    for i, f in enumerate([523, 659, 784, 1046]):
        out = place(out, tone(f, 0.28, "tri", 0.55, a=0.01, d=0.15), i * 0.11)
    return out


def sfx_unlock():
    return sweep(400, 1600, 0.6, 0.7)


def sfx_dig():
    n = noise(0.45, 3)
    body = lowpass(n, 0.08)
    thump = sweep(120, 60, 0.45, 0.5)
    return mix([v * env_ad(i / RATE, 0.01, 0.18) for i, v in enumerate(body)], thump)


def sfx_tool():
    out = place([], tone(1800, 0.12, "square", 0.3, a=0.001, d=0.03), 0.0)
    out = place(out, tone(2600, 0.09, "square", 0.2, a=0.001, d=0.02), 0.0)
    return place(out, tone(900, 0.2, "square", 0.25, a=0.002, d=0.06), 0.12)


def sfx_water():
    n = lowpass(noise(0.9, 7), 0.12)
    return [v * (0.4 + 0.6 * math.sin(i / RATE * math.pi / 0.9)) * 0.9 for i, v in enumerate(n)]


def sfx_siren():
    out = []
    for k in range(2):
        out = place(out, sweep(620, 980, 0.9, 0.55, "sine"), k * 0.9)
    return place(out, sweep(980, 620, 0.9, 0.55, "sine"), 1.8)


def sfx_hydraulic():
    return sweep(90, 140, 0.8, 0.45, "square")


def sfx_brush():
    n = lowpass(noise(0.7, 11), 0.25)
    return [v * (0.55 + 0.45 * math.sin(2 * math.pi * 7.0 * i / RATE)) for i, v in enumerate(n)]


def sfx_foam():
    out = []
    rnd = random.Random(5)
    for k in range(18):
        t0 = k * 0.03 + rnd.uniform(0, 0.02)
        out = place(out, tone(rnd.uniform(1200, 2400), 0.05, "sine", 0.25, a=0.002, d=0.02), t0)
    return out


def sfx_bubble():
    return sweep(300, 900, 0.18, 0.5)


def sfx_splash():
    return [v * env_ad(i / RATE, 0.002, 0.2) for i, v in enumerate(lowpass(noise(0.35, 13), 0.3))]


def sfx_gift():
    out = []
    for i, f in enumerate([784, 988, 1175, 1568, 1976]):
        out = place(out, tone(f, 0.12, "sine", 0.5, a=0.004, d=0.07), i * 0.06)
    return out


def sfx_animal():
    return mix(sweep(520, 700, 0.25, 0.4), sweep(700, 480, 0.25, 0.3))


def sfx_horn():
    return mix(tone(330, 0.5, "saw", 0.25, a=0.01, d=0.3), tone(415, 0.5, "saw", 0.2, a=0.01, d=0.3))


def sfx_dry():
    return [v * (0.3 + 0.7 * abs(math.sin(i / RATE * 40))) * 0.5 for i, v in enumerate(noise(0.9, 17))]


def sfx_fail():
    return sweep(440, 220, 0.4, 0.4)


def sfx_crane():
    return mix(sweep(180, 240, 1.0, 0.25, "square"), tone(70, 1.0, "saw", 0.12, a=0.01, d=0.5))


# ------------------------------------------------------------------ engines ---
def engine_loop(base_hz, dur=1.0, amp=0.35, seed=2):
    """A loop that repeats seamlessly: its period is exactly `dur`."""
    n = int(dur * RATE)
    out = []
    rnd = random.Random(seed)
    harm = [(1, 1.0), (2, 0.6), (3, 0.35), (4, 0.2), (5, 0.12)]
    cycles = max(1, round(base_hz * dur))
    f = cycles / dur
    for i in range(n):
        t = i / RATE
        v = 0.0
        for h, a in harm:
            v += a * math.sin(2 * math.pi * f * h * t)
        v = v / 2.2 + rnd.uniform(-0.04, 0.04)
        out.append(amp * v)
    return out


def engine_car():
    return engine_loop(40, 1.0, 0.35, 2)


def engine_truck():
    return engine_loop(28, 1.0, 0.45, 3)


def engine_small():
    return engine_loop(64, 1.0, 0.25, 4)


# ----------------------------------------------------------------- music ---
NOTE = {"C": 261.63, "D": 293.66, "E": 329.63, "F": 349.23, "G": 392.0, "A": 440.0, "B": 493.88, "c": 523.25, "d": 587.33, "e": 659.25, "f": 698.46, "g": 783.99}


def music(melody, bass, bpm, bars_per_loop=None):
    beat = 60.0 / bpm
    out = []
    t = 0.0
    for note, beats in melody:
        dur = beats * beat
        if note != "-":
            out = place(out, tone(NOTE[note], dur * 0.92, "tri", 0.22, a=0.01, d=dur * 0.35), t)
        t += dur
    total = t
    t = 0.0
    for note, beats in bass:
        dur = beats * beat
        if note != "-":
            out = place(out, tone(NOTE[note] / 2, dur * 0.92, "sine", 0.28, a=0.01, d=dur * 0.45), t)
        t += dur
    # pad the loop to exactly its length so it repeats cleanly
    n = int(total * RATE)
    out = out[:n] + [0.0] * max(0, n - len(out))
    return out


def music_main():
    melody = [("C", 1), ("E", 1), ("G", 1), ("c", 1), ("G", 1), ("E", 1), ("C", 1), ("-", 1),
              ("D", 1), ("F", 1), ("A", 1), ("d", 1), ("A", 1), ("F", 1), ("D", 1), ("-", 1),
              ("E", 1), ("G", 1), ("c", 1), ("e", 1), ("c", 1), ("G", 1), ("E", 1), ("-", 1),
              ("G", 1), ("E", 1), ("C", 1), ("E", 1), ("G", 2), ("-", 2)]
    bass = [("C", 4), ("F", 4), ("G", 4), ("C", 4), ("C", 2), ("G", 2), ("C", 4)]
    return music(melody, bass, 120)


def music_menu():
    melody = [("E", 1), ("G", 1), ("c", 2), ("-", 1), ("d", 1), ("c", 1), ("G", 2), ("-", 1), ("A", 1), ("G", 1), ("E", 2), ("-", 2),
              ("G", 1), ("c", 1), ("e", 2), ("-", 1), ("d", 1), ("c", 1), ("G", 2), ("-", 2)]
    bass = [("C", 4), ("A", 4), ("F", 4), ("G", 4)]
    return music(melody, bass, 104)


def main():
    os.makedirs(OUT, exist_ok=True)
    effects = {
        "click": sfx_click, "star": sfx_star, "success": sfx_success, "unlock": sfx_unlock,
        "dig": sfx_dig, "tool": sfx_tool, "water": sfx_water, "siren": sfx_siren,
        "hydraulic": sfx_hydraulic, "brush": sfx_brush, "foam": sfx_foam, "bubble": sfx_bubble,
        "splash": sfx_splash, "gift": sfx_gift, "animal": sfx_animal, "horn": sfx_horn,
        "dry": sfx_dry, "fail": sfx_fail, "crane": sfx_crane,
        "engine_car": engine_car, "engine_truck": engine_truck, "engine_small": engine_small,
        "music_main": music_main, "music_menu": music_menu,
    }
    for name, fn in effects.items():
        write(name, fn())


if __name__ == "__main__":
    main()
