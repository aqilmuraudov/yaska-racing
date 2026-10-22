"""Procedural audio for BAKU TURBO (original, no samples).

Generates every sound effect, the engine/drift loops and two music loops
into assets/audio. Loops carry a RIFF 'smpl' chunk so Godot's WAV importer
detects the loop points. Re-run after editing:

    python tools/audio/generate_audio.py

Requires numpy. Deterministic (fixed seeds).
"""
import os
import struct
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
MUS = os.path.join(ROOT, "assets", "audio", "music")
SR = 32000
rng = np.random.default_rng(7)


# --- WAV writing -----------------------------------------------------------

def write_wav(path, data, sr=SR, loop=None):
    """data: float array (n,) mono or (n, 2) stereo in -1..1."""
    data = np.asarray(data, dtype=np.float64)
    if data.ndim == 1:
        data = data[:, None]
    peak = np.max(np.abs(data)) if data.size else 1.0
    if peak > 0.98:
        data = data / peak * 0.98
    pcm = (data * 32767.0).astype("<i2")
    ch = pcm.shape[1]
    payload = pcm.tobytes()
    chunks = b""
    fmt = struct.pack("<HHIIHH", 1, ch, sr, sr * ch * 2, ch * 2, 16)
    chunks += b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(payload)) + payload
    if len(payload) % 2:
        chunks += b"\0"
    if loop is not None:
        start, end = loop
        smpl = struct.pack("<9I", 0, 0, int(1e9 / sr), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, int(start), int(end) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


# --- DSP helpers ---------------------------------------------------------------

def t_axis(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def env_adsr(n, a=0.005, d=0.05, s=0.6, r=0.1, sr=SR):
    e = np.ones(n) * s
    na, nd, nr = int(a * sr), int(d * sr), int(r * sr)
    na = max(na, 1)
    e[:na] = np.linspace(0, 1, na)
    e[na:na + nd] = np.linspace(1, s, len(e[na:na + nd]))
    if nr > 0:
        e[-nr:] *= np.linspace(1, 0, min(nr, n))
    return e


def env_exp(n, decay, sr=SR):
    return np.exp(-np.arange(n) / (decay * sr))


def onepole_lp(x, cutoff, sr=SR):
    if np.isscalar(cutoff):
        cutoff = np.full(len(x), cutoff)
    a = np.exp(-2 * np.pi * np.asarray(cutoff) / sr)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def lp_fast(x, cutoff, sr=SR):
    """Constant-cutoff one-pole low-pass via scipy-free IIR (vectorised-ish)."""
    a = np.exp(-2 * np.pi * cutoff / sr)
    y = np.empty_like(x)
    acc = 0.0
    b = 1 - a
    for i, v in enumerate(x):
        acc = b * v + a * acc
        y[i] = acc
    return y


def hp_fast(x, cutoff, sr=SR):
    return x - lp_fast(x, cutoff, sr)


def bandpass(x, lo, hi, sr=SR):
    return hp_fast(lp_fast(x, hi, sr), lo, sr)


def saw(phase):
    return 2.0 * (phase % 1.0) - 1.0


def square(phase, duty=0.5):
    return np.where((phase % 1.0) < duty, 1.0, -1.0)


def tri(phase):
    return 2.0 * np.abs(2.0 * (phase % 1.0) - 1.0) - 1.0


def sweep_phase(f0, f1, dur, curve=1.0, sr=SR):
    n = int(dur * sr)
    k = np.linspace(0, 1, n) ** curve
    f = f0 + (f1 - f0) * k
    return np.cumsum(f) / sr


def noise(n):
    return rng.uniform(-1, 1, n)


def crossfade_loop(x, fade):
    """Makes x loop seamlessly by blending its tail into its head."""
    head = x[:fade].copy()
    tail = x[-fade:]
    w = np.linspace(0, 1, fade)
    x = x[:-fade].copy()
    x[:fade] = head * w + tail * (1 - w)
    return x


# --- Sound effects -----------------------------------------------------------------

def sfx_all():
    out = {}
    # Hop: quick springy blip
    p = sweep_phase(260, 620, 0.12, 0.6)
    out["hop"] = np.sin(2 * np.pi * p) * env_exp(len(p), 0.05) * 0.6
    # Landing thud
    n = int(0.25 * SR)
    p = sweep_phase(120, 45, 0.25, 0.5)
    out["land"] = (np.sin(2 * np.pi * p) * env_exp(n, 0.07) + lp_fast(noise(n), 900) * env_exp(n, 0.03) * 0.8) * 0.8
    # Boost whoosh + rising tone
    n = int(0.7 * SR)
    whoosh = bandpass(noise(n), 400, 3500) * env_adsr(n, 0.02, 0.15, 0.5, 0.4) * 1.6
    p = sweep_phase(300, 900, 0.7, 0.7)
    out["boost"] = whoosh + np.sin(2 * np.pi * p) * env_adsr(n, 0.01, 0.2, 0.3, 0.3) * 0.35
    p2 = sweep_phase(400, 1300, 0.8, 0.6)
    n2 = len(p2)
    out["boost_perfect"] = (bandpass(noise(n2), 500, 4500) * env_adsr(n2, 0.02, 0.2, 0.5, 0.4) * 1.4
                            + (np.sin(2 * np.pi * p2) + 0.5 * np.sin(4 * np.pi * p2)) * env_adsr(n2, 0.01, 0.25, 0.35, 0.35) * 0.35
                            + np.sin(2 * np.pi * 1760 * t_axis(0.8)) * env_exp(n2, 0.12) * 0.25)
    # Miss: dull descending buzz
    p = sweep_phase(330, 160, 0.25)
    out["miss"] = lp_fast(square(p), 1400) * env_exp(len(p), 0.09) * 0.35
    # Wall hit: crunchy knock
    n = int(0.3 * SR)
    out["wall_hit"] = (lp_fast(noise(n), 1800) * env_exp(n, 0.04) * 1.2 + np.sin(2 * np.pi * sweep_phase(160, 60, 0.3)) * env_exp(n, 0.06) * 0.7)
    # Item hit: spin-out wobble
    n = int(0.8 * SR)
    t = t_axis(0.8)
    wob = np.sin(2 * np.pi * (220 * t + 40 * np.sin(2 * np.pi * 9 * t) / (2 * np.pi * 9)))
    out["hit"] = (wob * 0.4 + bandpass(noise(n), 200, 2000) * 0.5) * env_exp(n, 0.25)
    # Shield up / block
    t = t_axis(0.5)
    out["shield_up"] = (np.sin(2 * np.pi * 660 * t) + np.sin(2 * np.pi * 990 * t) * 0.6 + np.sin(2 * np.pi * 1320 * t) * 0.3) * env_adsr(len(t), 0.03, 0.2, 0.4, 0.25) * 0.35
    t = t_axis(0.4)
    out["shield_block"] = (np.sin(2 * np.pi * 1200 * t) * env_exp(len(t), 0.1) + bandpass(noise(len(t)), 2000, 8000) * env_exp(len(t), 0.03)) * 0.5
    # Recover: rising chime
    seq = []
    for f in (523, 659, 784):
        tt = t_axis(0.12)
        seq.append(np.sin(2 * np.pi * f * tt) * env_exp(len(tt), 0.08))
    out["recover"] = np.concatenate(seq) * 0.4
    # Pickup: sparkly arpeggio
    seq = []
    for f in (784, 988, 1175, 1568):
        tt = t_axis(0.07)
        seq.append((np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt)) * env_exp(len(tt), 0.05))
    out["pickup"] = np.concatenate(seq) * 0.35
    # Trap drop / trap hit
    n = int(0.25 * SR)
    out["trap_drop"] = (np.sin(2 * np.pi * sweep_phase(500, 200, 0.25)) * env_exp(n, 0.06) * 0.5 + lp_fast(noise(n), 3000) * env_exp(n, 0.02) * 0.4)
    n = int(0.5 * SR)
    out["trap_hit"] = (lp_fast(noise(n), 2500) * env_exp(n, 0.08) + np.sin(2 * np.pi * sweep_phase(300, 80, 0.5)) * env_exp(n, 0.12) * 0.8) * 0.9
    # Kart bump
    n = int(0.15 * SR)
    out["bump"] = (np.sin(2 * np.pi * sweep_phase(180, 90, 0.15)) * env_exp(n, 0.04) + lp_fast(noise(n), 1200) * env_exp(n, 0.02) * 0.6) * 0.7
    # Countdown and race cues
    t = t_axis(0.25)
    out["count_beep"] = (square(440 * t, 0.5) * 0.3 + np.sin(2 * np.pi * 440 * t) * 0.5) * env_adsr(len(t), 0.005, 0.05, 0.7, 0.08)
    t = t_axis(0.7)
    out["count_go"] = (square(880 * t, 0.5) * 0.25 + np.sin(2 * np.pi * 880 * t) * 0.5) * env_adsr(len(t), 0.005, 0.1, 0.7, 0.3)
    out["lap"] = np.concatenate([np.sin(2 * np.pi * f * t_axis(0.1)) * env_exp(int(0.1 * SR), 0.07) for f in (659, 880)]) * 0.45
    out["final_lap"] = np.concatenate([(np.sin(2 * np.pi * f * t_axis(0.13)) + 0.3 * square(f * t_axis(0.13))) * env_exp(int(0.13 * SR), 0.1) for f in (659, 784, 988, 1319)]) * 0.35
    fan = []
    for f, d in ((523, 0.15), (659, 0.15), (784, 0.15), (1047, 0.5)):
        tt = t_axis(d)
        fan.append((np.sin(2 * np.pi * f * tt) + 0.4 * saw(f * tt) * 0.5) * env_adsr(len(tt), 0.01, 0.05, 0.7, d * 0.4))
    out["finish"] = np.concatenate(fan) * 0.45
    tt = t_axis(0.3)
    out["tutorial_step"] = (np.sin(2 * np.pi * 880 * tt) + np.sin(2 * np.pi * 1320 * tt) * 0.5) * env_exp(len(tt), 0.1) * 0.4
    # UI
    tt = t_axis(0.06)
    out["ui_move"] = np.sin(2 * np.pi * 1200 * tt) * env_exp(len(tt), 0.02) * 0.25
    tt = t_axis(0.14)
    out["ui_confirm"] = (np.sin(2 * np.pi * sweep_phase(700, 1100, 0.14)) * env_exp(len(tt), 0.06)) * 0.35
    out["ui_back"] = (np.sin(2 * np.pi * sweep_phase(900, 500, 0.14)) * env_exp(len(tt), 0.06)) * 0.3
    tt = t_axis(0.2)
    out["ui_open"] = (np.sin(2 * np.pi * 660 * tt) * 0.5 + np.sin(2 * np.pi * 990 * tt) * 0.3) * env_exp(len(tt), 0.08) * 0.35
    return out


def engine_loop():
    """1 s seamless loop: firing pulses + harmonics, pitch-shifted at runtime."""
    dur = 1.0
    t = t_axis(dur)
    f = 60.0  # integer cycles per loop
    x = np.zeros_like(t)
    for h, amp in ((1, 1.0), (2, 0.55), (3, 0.35), (4, 0.22), (6, 0.12), (8, 0.06)):
        x += amp * np.sin(2 * np.pi * f * h * t + h * 0.7)
    # "putt" amplitude modulation at half firing rate
    x *= 0.75 + 0.25 * np.sin(2 * np.pi * 30.0 * t)
    x = np.tanh(x * 1.4)
    n = len(t)
    fade = int(0.08 * SR)
    grit = bandpass(noise(n + fade), 150, 1800) * 0.18
    grit = crossfade_loop(grit, fade)
    x = x[: len(grit)] * 0.55 + grit
    return x


def drift_loop():
    dur = 1.2
    n = int(dur * SR)
    fade = int(0.1 * SR)
    t = t_axis((n + fade) / SR)
    squeal = bandpass(noise(len(t)), 900, 2600) * (0.8 + 0.2 * np.sin(2 * np.pi * 5 * t))
    tone = np.sin(2 * np.pi * (1400 * t + 30 * np.sin(2 * np.pi * 3 * t))) * 0.15
    return crossfade_loop((squeal + tone) * 0.6, fade)


# --- Music ------------------------------------------------------------------------

# Mode with an augmented second (E F G# A B C D) evokes Caucasian / mugham
# colour while staying in a bright, game-friendly pop arrangement.
SCALE = [0, 1, 4, 5, 7, 8, 10]


def midi_to_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def note_in_scale(root, degree):
    octave, idx = divmod(degree, len(SCALE))
    return root + 12 * octave + SCALE[idx]


def render_music(bpm, bars, root, seed, energy):
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    total = bars * 4 * beat
    n = int(total * SR)
    tail = int(2.0 * SR)  # room for note tails past the loop end
    L = np.zeros(n + tail)
    R = np.zeros(n + tail)

    def add(buf, sig, start_s, gain):
        i0 = int(start_s * SR)
        i1 = min(n + tail, i0 + len(sig))
        if i0 < n:
            buf[i0:i1] += sig[: i1 - i0] * gain

    def addst(sig, start, gain, pan=0.0):
        add(L, sig, start, gain * (1 - max(pan, 0)))
        add(R, sig, start, gain * (1 + min(pan, 0)))

    # Drums
    kick_t = t_axis(0.35)
    kick = np.sin(2 * np.pi * np.cumsum(55 + 110 * np.exp(-kick_t * 30)) / SR) * env_exp(len(kick_t), 0.12)
    snare = (bandpass(noise(int(0.25 * SR)), 900, 7000) * env_exp(int(0.25 * SR), 0.06) + np.sin(2 * np.pi * 190 * t_axis(0.25)) * env_exp(int(0.25 * SR), 0.04) * 0.6)
    hat = hp_fast(noise(int(0.06 * SR)), 6000) * env_exp(int(0.06 * SR), 0.015)
    tom = np.sin(2 * np.pi * np.cumsum(120 + 80 * np.exp(-t_axis(0.3) * 20)) / SR) * env_exp(int(0.3 * SR), 0.1)
    # Chord progression in scale degrees (i - VI - VII - i style)
    prog = [0, 5, 6, 0, 3, 5, 6, 4]
    for bar in range(bars):
        b0 = bar * 4 * beat
        chord_deg = prog[bar % len(prog)]
        for q in range(4):
            tq = b0 + q * beat
            if q in (0, 2) or (energy > 0.7 and q == 3 and bar % 2 == 1):
                addst(kick, tq, 0.9)
            if q in (1, 3):
                addst(snare, tq, 0.45 * energy + 0.15, 0.05)
            for e8 in range(2):
                addst(hat, tq + e8 * beat / 2, 0.25 if e8 else 0.18, 0.3)
            if energy > 0.6 and bar % 4 == 3 and q == 3:
                for k in range(4):
                    addst(tom, tq + k * beat / 4, 0.4, -0.3 + k * 0.2)
        # Bass: root eighths with fifth on offbeats
        for e8 in range(8):
            deg = chord_deg if e8 % 4 != 3 else chord_deg + 4
            f = midi_to_hz(note_in_scale(root - 24, deg))
            d = beat / 2 * 0.9
            tt = t_axis(d)
            sig = lp_fast(saw(f * tt) * 0.7 + square(f * tt) * 0.3, 500 + 900 * energy) * env_adsr(len(tt), 0.005, 0.08, 0.6, 0.05)
            addst(sig, b0 + e8 * beat / 2, 0.42)
        # Pad: chord tones, soft
        d = 4 * beat
        tt = t_axis(d)
        pad = np.zeros(len(tt))
        for k in (0, 2, 4):
            f = midi_to_hz(note_in_scale(root - 12, chord_deg + k))
            pad += saw(f * tt * 1.003) * 0.3 + saw(f * tt * 0.997) * 0.3
        pad = lp_fast(pad, 1500) * env_adsr(len(tt), 0.3, 0.5, 0.7, 0.6)
        addst(pad, b0, 0.11, -0.4)
        addst(pad, b0, 0.11, 0.4)
    # Lead melody: motif-based, two phrases, tar-like pluck with vibrato.
    motif = [4, 3, 2, 1, 2, 4, 5, 4]
    rhythm = [0.5, 0.25, 0.25, 0.5, 0.5, 0.75, 0.25, 1.0]
    for bar in range(bars):
        if energy < 0.6 and bar % 2 == 1:
            continue
        b0 = bar * 4 * beat
        shift = [0, 2, 1, -1][(bar // 2) % 4]
        tcur = b0
        for i, dur in enumerate(rhythm):
            deg = motif[i] + shift + (r.integers(-1, 2) if i in (3, 6) else 0)
            f = midi_to_hz(note_in_scale(root + 12, deg))
            dsec = dur * beat
            tt = t_axis(dsec * 0.95)
            vib = 1 + 0.006 * np.sin(2 * np.pi * 6 * tt) * np.clip(tt * 4, 0, 1)
            ph = np.cumsum(f * vib) / SR
            pluck = (tri(ph) * 0.6 + square(ph, 0.3) * 0.25 + np.sin(2 * np.pi * 2 * ph) * 0.15)
            pluck = lp_fast(pluck, 3500) * env_adsr(len(tt), 0.004, 0.12, 0.45, 0.08)
            addst(pluck, tcur, 0.2 + 0.08 * energy, 0.15)
            # Echo
            addst(pluck, tcur + beat * 0.75, 0.07, -0.35)
            tcur += dsec
    # Wrap the tails onto the start: the loop is seamless by construction.
    L[:tail] += L[n:]
    R[:tail] += R[n:]
    mix = np.stack([L[:n], R[:n]], axis=1)
    # Gentle master: soft clip
    mix = np.tanh(mix * 1.1) * 0.85
    return mix


def main():
    os.makedirs(SFX, exist_ok=True)
    os.makedirs(MUS, exist_ok=True)
    for name, sig in sfx_all().items():
        sig = np.asarray(sig, dtype=np.float64).copy()
        # 1 ms fade-in / 8 ms fade-out: no clicks when one-shots start or end.
        fi, fo = int(0.001 * SR), min(int(0.008 * SR), len(sig) // 2)
        sig[:fi] *= np.linspace(0, 1, fi)
        sig[-fo:] *= np.linspace(1, 0, fo)
        write_wav(os.path.join(SFX, name + ".wav"), sig)
    eng = engine_loop()
    write_wav(os.path.join(SFX, "engine_loop.wav"), eng, loop=(0, len(eng)))
    dr = drift_loop()
    write_wav(os.path.join(SFX, "drift_loop.wav"), dr, loop=(0, len(dr)))
    menu = render_music(104, 16, 64, 11, 0.45)
    write_wav(os.path.join(MUS, "menu.wav"), menu, sr=SR, loop=(0, len(menu)))
    race = render_music(132, 24, 64, 23, 0.9)
    write_wav(os.path.join(MUS, "race.wav"), race, sr=SR, loop=(0, len(race)))
    print("audio written:", len(os.listdir(SFX)), "sfx,", len(os.listdir(MUS)), "music")


if __name__ == "__main__":
    main()
