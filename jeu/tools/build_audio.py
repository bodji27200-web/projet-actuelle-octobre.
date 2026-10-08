"""Compose et synthétise la musique et les bruitages du jeu (style 8 bits, compositions originales).

Usage : python3 build_audio.py <dossier_sortie>   (nécessite numpy et ffmpeg)
Chaque morceau est généré à partir d'une grille d'accords, d'un tempo et d'une graine : mélodie à motifs répétés
(structure A A' B A), arpèges, basse et percussions, comme sur les consoles portables.
"""
import os
import random
import subprocess
import sys
import wave

import numpy as np

OUT = sys.argv[1]
SR = 22050
os.makedirs(f"{OUT}/music", exist_ok=True)
os.makedirs(f"{OUT}/sfx", exist_ok=True)

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]
HARM = [0, 2, 3, 5, 7, 8, 11]


def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def square(f, n, duty=0.5, vol=0.2):
    t = np.arange(n) / SR
    ph = (t * f) % 1.0
    return np.where(ph < duty, vol, -vol).astype(np.float32)


def triangle(f, n, vol=0.3):
    t = np.arange(n) / SR
    ph = (t * f) % 1.0
    return (vol * (4 * np.abs(ph - 0.5) - 1)).astype(np.float32)


def noise(n, vol=0.2, decay=30.0, lp=1):
    x = (np.random.rand(n) * 2 - 1).astype(np.float32)
    if lp > 1:
        x = np.convolve(x, np.ones(lp) / lp, mode="same").astype(np.float32)
    env = np.exp(-np.arange(n) / SR * decay).astype(np.float32)
    return x * env * vol


def env_adsr(n, a=0.005, d=0.05, s=0.7, r=0.04):
    e = np.ones(n, dtype=np.float32) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na)
    if na + nd < n:
        e[na:na + nd] = np.linspace(1, s, nd)
    if nr < n:
        e[n - nr:] *= np.linspace(1, 0, nr)
    return e


def place(buf, start, sig):
    end = min(len(buf), start + len(sig))
    if end > start:
        buf[start:end] += sig[:end - start]


def compose(name, root="C", mode="major", bpm=120, prog=None, seed=1, bars=16, lead_duty=0.25, arp=True,
            drums="basic", octave=5, swing=0.0, lead_vol=0.13, sparse=0.0):
    rng = random.Random(seed)
    scale = {"major": MAJOR, "minor": MINOR, "harm": HARM}[mode]
    base = 12 * (octave + 1) + NOTE[root]
    prog = prog or ([0, 4, 5, 3] if mode == "major" else [0, 5, 2, 6])
    beat = 60.0 / bpm
    sixteenth = beat / 4
    total = int(bars * 4 * beat * SR)
    lead = np.zeros(total, dtype=np.float32)
    harm = np.zeros(total, dtype=np.float32)
    bass = np.zeros(total, dtype=np.float32)
    drum = np.zeros(total, dtype=np.float32)

    def chord_tones(deg):
        return [scale[(deg + k) % 7] + 12 * ((deg + k) // 7) for k in (0, 2, 4)]

    # Motifs rythmiques (en doubles-croches) et mélodiques (degrés relatifs)
    def make_phrase(length_bars):
        notes = []
        pos = 0
        deg = rng.choice([0, 2, 4])
        while pos < length_bars * 16:
            dur = rng.choice([2, 2, 2, 4, 4, 1, 1, 6, 8] if bpm < 140 else [1, 1, 2, 2, 2, 4, 3])
            dur = min(dur, length_bars * 16 - pos)
            if rng.random() < sparse:
                notes.append((None, dur))
            else:
                deg += rng.choice([-2, -1, -1, 0, 1, 1, 2, 3, -3])
                deg = max(-3, min(9, deg))
                notes.append((deg, dur))
            pos += dur
        return notes

    a = make_phrase(4)
    a2 = list(a[:-2]) + make_phrase(4)[-2:]
    b = make_phrase(4)
    phrases = [a, a2, b, a]
    pos16 = 0
    for ph in phrases:
        for deg, dur in ph:
            if deg is not None:
                bar = pos16 // 16
                chord = prog[bar % len(prog)]
                # attire les temps forts vers les notes de l'accord
                if pos16 % 4 == 0:
                    ct = chord_tones(chord)
                    best = min(ct, key=lambda c: abs(c - (scale[deg % 7] + 12 * (deg // 7))))
                    semis = best
                else:
                    semis = scale[deg % 7] + 12 * (deg // 7)
                n = int(dur * sixteenth * SR)
                sig = square(freq(base + semis), n, lead_duty, lead_vol) * env_adsr(n, 0.004, 0.06, 0.6, 0.03)
                # léger vibrato pour les notes longues
                place(lead, int(pos16 * sixteenth * SR + (swing * sixteenth * SR if pos16 % 2 else 0)), sig)
            pos16 += dur
    for bar in range(bars):
        chord = prog[bar % len(prog)]
        ct = chord_tones(chord)
        start = int(bar * 4 * beat * SR)
        # Basse : fondamentale en croches / noires selon le tempo
        pattern = [0, 0, 2, 0] if bpm >= 130 else [0, 2]
        step = 4 * beat / len(pattern)
        for i, p in enumerate(pattern):
            n = int(step * SR * 0.9)
            semis = (ct[0] if p == 0 else ct[2]) - 24
            place(bass, start + int(i * step * SR), triangle(freq(base + semis), n, 0.22) * env_adsr(n, 0.002, 0.03, 0.8, 0.02))
        # Arpèges
        if arp:
            for i in range(16):
                n = int(sixteenth * SR * 0.85)
                semis = ct[i % 3] - 12 + (12 if i % 6 == 5 else 0)
                place(harm, start + int(i * sixteenth * SR), square(freq(base + semis), n, 0.5, 0.045) * env_adsr(n, 0.002, 0.02, 0.5, 0.01))
        else:
            n = int(4 * beat * SR)
            for c in ct:
                place(harm, start, square(freq(base + c - 12), n, 0.5, 0.025) * env_adsr(n, 0.05, 0.2, 0.5, 0.2))
        # Percussions
        if drums != "none":
            for i in range(16):
                t0 = start + int(i * sixteenth * SR)
                if drums in ("basic", "fast"):
                    if i % 8 == 0:
                        place(drum, t0, triangle(55, int(0.12 * SR), 0.35) * np.exp(-np.arange(int(0.12 * SR)) / SR * 25))
                    if i % 8 == 4:
                        place(drum, t0, noise(int(0.12 * SR), 0.18, 22, 2))
                    if drums == "fast" and i % 2 == 0 or drums == "basic" and i % 4 == 2:
                        place(drum, t0, noise(int(0.03 * SR), 0.06, 120))
                elif drums == "soft" and i % 8 == 0:
                    place(drum, t0, noise(int(0.06 * SR), 0.05, 50, 4))
    mix = lead + harm + bass + drum
    mix = np.tanh(mix * 1.2) * 0.85
    write_ogg(f"{OUT}/music/{name}.ogg", mix)


def jingle(name, notes, bpm=140, duty=0.25, root=60, chord_end=True):
    beat = 60.0 / bpm
    total = int((sum(d for _, d in notes) * beat / 4 + 0.6) * SR)
    buf = np.zeros(total, dtype=np.float32)
    bass = np.zeros(total, dtype=np.float32)
    pos = 0.0
    for semis, dur in notes:
        n = int(dur * beat / 4 * SR)
        if semis is not None:
            place(buf, int(pos * SR), square(freq(root + 12 + semis), n, duty, 0.16) * env_adsr(n, 0.003, 0.05, 0.6, 0.03))
            place(bass, int(pos * SR), triangle(freq(root - 12 + semis - (semis % 12) + [0, 0, 0, 0, 4, 5, 5, 7, 7, 9, 10, 7][semis % 12]), n, 0.18) * env_adsr(n))
        pos += dur * beat / 4
    mix = np.tanh((buf + bass) * 1.2) * 0.85
    write_ogg(f"{OUT}/music/{name}.ogg", mix)


def sfx(name, sig):
    write_ogg(f"{OUT}/sfx/{name}.ogg", np.tanh(sig * 1.1) * 0.9)


def sweep(f0, f1, dur, duty=0.5, vol=0.25, shape="square"):
    n = int(dur * SR)
    f = np.linspace(f0, f1, n)
    ph = np.cumsum(f / SR) % 1.0
    if shape == "square":
        s = np.where(ph < duty, vol, -vol)
    else:
        s = vol * (4 * np.abs(ph - 0.5) - 1)
    return (s * env_adsr(n, 0.002, 0.02, 0.8, min(0.05, dur / 3))).astype(np.float32)


def write_ogg(path, data):
    tmp = path + ".wav"
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", path], check=True)
    os.remove(tmp)


np.random.seed(7)
# --- Musiques (boucles) -------------------------------------------------------
compose("title", "C", "major", 118, [0, 3, 4, 0, 5, 3, 1, 4], seed=11, lead_duty=0.25)
compose("pallet", "G", "major", 96, [0, 3, 0, 4, 5, 3, 1, 4], seed=12, drums="soft", arp=False, sparse=0.1)
compose("town", "D", "major", 112, [0, 4, 5, 3], seed=13)
compose("celadon", "F", "major", 108, [0, 5, 3, 4], seed=14, drums="soft")
compose("saffron", "A", "major", 118, [0, 3, 4, 4], seed=15)
compose("cinnabar", "E", "major", 116, [0, 4, 3, 4], seed=16)
compose("lavender", "C", "harm", 78, [0, 5, 3, 4], seed=17, drums="none", lead_duty=0.5, sparse=0.2)
compose("route", "C", "major", 134, [0, 4, 5, 3, 0, 4, 3, 4], seed=18, drums="fast")
compose("forest", "E", "minor", 110, [0, 5, 6, 4], seed=19, drums="soft")
compose("cave", "A", "minor", 92, [0, 5, 3, 4], seed=20, drums="soft", arp=False, sparse=0.15)
compose("tower", "D", "harm", 72, [0, 3, 5, 4], seed=21, drums="none", arp=False, lead_duty=0.5, sparse=0.25)
compose("center", "F", "major", 100, [0, 3, 4, 0], seed=22, drums="soft")
compose("mart", "C", "major", 124, [0, 5, 3, 4], seed=23)
compose("lab", "G", "major", 108, [0, 3, 4, 5], seed=24, drums="soft")
compose("gym", "B", "minor", 138, [0, 5, 6, 4], seed=25, drums="fast")
compose("league", "D", "minor", 128, [0, 6, 5, 4], seed=26, drums="basic")
compose("sea", "A", "major", 104, [0, 3, 0, 4], seed=27, drums="soft")
compose("cycling", "G", "major", 146, [0, 4, 5, 3], seed=28, drums="fast")
compose("safari", "F", "major", 120, [0, 3, 4, 3], seed=29)
compose("rocket", "E", "harm", 142, [0, 5, 4, 0], seed=30, drums="fast", lead_duty=0.125)
compose("mansion", "G", "harm", 84, [0, 5, 3, 4], seed=31, drums="soft", arp=False)
compose("dungeon", "F#", "minor", 104, [0, 5, 6, 4], seed=32, drums="soft")
compose("indoor", "C", "major", 104, [0, 5, 3, 4], seed=33, drums="soft")
compose("battle_wild", "A", "minor", 152, [0, 5, 3, 4], seed=34, drums="fast", lead_duty=0.25)
compose("battle_trainer", "D", "harm", 158, [0, 6, 5, 4], seed=35, drums="fast", lead_duty=0.125)
compose("gym_battle", "C", "harm", 164, [0, 5, 6, 4], seed=36, drums="fast")
compose("battle_legend", "B", "harm", 150, [0, 5, 3, 4, 0, 6, 5, 4], seed=37, drums="fast", lead_duty=0.25)
compose("rival", "G", "minor", 156, [0, 6, 5, 6], seed=38, drums="fast", lead_duty=0.125)
compose("victory_wild", "C", "major", 130, [0, 3, 4, 0], seed=39, bars=8)
compose("victory_trainer", "G", "major", 136, [0, 4, 3, 4], seed=40, bars=8)
compose("hall", "C", "major", 100, [0, 3, 4, 5, 3, 4, 0, 0], seed=41, drums="soft")
# --- Jingles -------------------------------------------------------------------
jingle("heal", [(0, 2), (4, 2), (7, 2), (12, 4), (7, 2), (12, 8)], 120)
jingle("catch", [(0, 2), (4, 2), (7, 2), (12, 2), (11, 2), (12, 2), (14, 2), (16, 8)], 150)
jingle("levelup", [(0, 1), (4, 1), (7, 1), (12, 4)], 160)
jingle("item", [(7, 2), (7, 1), (9, 1), (11, 2), (12, 6)], 150)
jingle("badge", [(0, 2), (4, 2), (7, 2), (12, 2), (7, 2), (12, 2), (16, 2), (19, 8)], 140)
jingle("evolve", [(0, 2), (4, 2), (7, 2), (11, 2), (12, 2), (16, 2), (19, 2), (24, 8)], 120)
jingle("save", [(12, 2), (7, 2), (12, 4)], 160)
# --- Bruitages -----------------------------------------------------------------
sfx("select", sweep(900, 900, 0.04, 0.5, 0.18))
sfx("bump", sweep(140, 90, 0.08, 0.5, 0.25))
sfx("door", np.concatenate([noise(int(0.12 * SR), 0.25, 20, 3), sweep(300, 200, 0.06)]))
sfx("hit", np.concatenate([noise(int(0.1 * SR), 0.4, 18, 2)]))
sfx("faint", sweep(600, 80, 0.5, 0.5, 0.22))
sfx("exp", sweep(400, 1200, 0.3, 0.25, 0.12))
sfx("stat_up", np.concatenate([sweep(400, 900, 0.12), sweep(500, 1100, 0.12)]))
sfx("stat_down", np.concatenate([sweep(900, 400, 0.12), sweep(800, 300, 0.12)]))
sfx("throw", sweep(300, 900, 0.2, 0.5, 0.15))
sfx("shake", noise(int(0.08 * SR), 0.3, 25, 4))
sfx("click", np.concatenate([sweep(1200, 1200, 0.03, 0.5, 0.2), np.zeros(int(0.03 * SR), np.float32), sweep(1600, 1600, 0.05, 0.5, 0.2)]))
sfx("break_free", np.concatenate([noise(int(0.06 * SR), 0.35, 20), sweep(500, 1000, 0.1)]))
sfx("alert", np.concatenate([sweep(880, 880, 0.08), sweep(1320, 1320, 0.1)]))
sfx("jump", sweep(300, 600, 0.15, 0.5, 0.15, "tri"))
sfx("heal", sweep(500, 1500, 0.4, 0.25, 0.12))
sfx("shiny", np.concatenate([sweep(1800, 2400, 0.06), sweep(2000, 2600, 0.06), sweep(2200, 2900, 0.1)]))
sfx("save", np.concatenate([sweep(800, 800, 0.06), sweep(1200, 1200, 0.1)]))
print("audio généré dans", OUT)
