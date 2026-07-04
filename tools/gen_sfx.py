# ぽんぽこ用 8bitレトロ風効果音ジェネレータ（標準ライブラリのみ）
# 出力: /Users/kouyoshida/dos_diet/assets/sounds/*.wav (22050Hz, 16bit, mono)
import math
import os
import random
import struct
import wave

SR = 22050
OUT = "/Users/kouyoshida/dos_diet/assets/sounds"
random.seed(7)


def write_wav(name, samples, gain=0.8):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = gain / peak * 32767
    data = b"".join(
        struct.pack("<h", int(max(-32767, min(32767, s * scale))))
        for s in samples
    )
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"{name}: {len(samples)/SR:.2f}s {os.path.getsize(path)} bytes")


def silence(dur):
    return [0.0] * int(SR * dur)


def square(freq_fn, dur, duty=0.5):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq_fn(i / n) if callable(freq_fn) else freq_fn
        phase += f / SR
        out.append(1.0 if (phase % 1.0) < duty else -1.0)
    return out


def triangle(freq_fn, dur):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq_fn(i / n) if callable(freq_fn) else freq_fn
        phase += f / SR
        p = phase % 1.0
        out.append(4 * p - 1 if p < 0.5 else 3 - 4 * p)
    return out


def noise(dur):
    return [random.uniform(-1, 1) for _ in range(int(SR * dur))]


def env(samples, attack=0.005, release=0.05, curve=1.0):
    n = len(samples)
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    out = list(samples)
    for i in range(min(a, n)):
        out[i] *= i / a
    for i in range(min(r, n)):
        out[n - 1 - i] *= (i / r) ** curve
    return out


def decay(samples, k=6.0):
    n = len(samples)
    return [s * math.exp(-k * i / n) for i, s in enumerate(samples)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def cat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def vol(samples, g):
    return [s * g for s in samples]


# ---- 1. リール回転ループ（低いジーッ音＋速いカタカタ。ループ境界が繋がる長さに調整） ----
def spin_loop():
    tick_hz = 24  # カタカタの周期
    dur = 12 / tick_hz  # tick周期の整数倍 → シームレスにループ
    hum = vol(square(55, dur, duty=0.3), 0.28)
    n = int(SR * dur)
    ticks = [0.0] * n
    tick_len = int(SR * 0.012)
    step = SR // tick_hz
    for start in range(0, n, step):
        for j in range(min(tick_len, n - start)):
            t = j / tick_len
            ticks[start + j] += random.uniform(-1, 1) * (1 - t) * 0.5
    return env(mix(hum, ticks), attack=0.0, release=0.0)


# ---- 2. リール停止（ピコッ） ----
def reel_stop():
    a = decay(square(lambda t: 1400 - 500 * t, 0.05), 3)
    b = decay(square(lambda t: 900 - 250 * t, 0.07), 4)
    return env(cat(a, b), attack=0.001, release=0.02)


# ---- 3. リーチ（上昇スイープ×2＋ビブラート。緊張感） ----
def reach():
    def sweep(f0, f1, dur):
        return decay(
            square(lambda t: (f0 + (f1 - f0) * t) * (1 + 0.04 * math.sin(t * 60)), dur),
            1.2,
        )

    part1 = sweep(300, 900, 0.28)
    part2 = sweep(400, 1300, 0.42)
    return env(cat(part1, silence(0.04), part2), release=0.08)


# ---- 4. 激アツカットイン（ズバーン: ノイズスラッシュ＋低音ブーム） ----
def cutin():
    slash = decay(noise(0.18), 9)
    boom = decay(triangle(lambda t: 160 - 100 * t, 0.5), 5)
    sting = decay(square(lambda t: 2000 - 1400 * t, 0.12), 6)
    return env(mix(vol(slash, 0.9), vol(boom, 1.2), vol(sting, 0.5)), release=0.1)


# ---- 5. 当たりファンファーレ（上昇アルペジオ→和音） ----
NOTE = {"C5": 523.25, "E5": 659.26, "G5": 783.99, "C6": 1046.5,
        "E6": 1318.5, "G6": 1568.0, "A5": 880.0, "F5": 698.46, "D6": 1174.7}


def chord(freqs, dur, k=2.5):
    tracks = []
    for f in freqs:
        tracks.append(vol(square(f, dur), 0.5))
        tracks.append(vol(square(f * 1.005, dur), 0.25))  # デチューンで厚み
    return decay(env(mix(*tracks), release=0.06), k)


def note(f, dur):
    return decay(env(square(f, dur), release=0.02), 3)


def fanfare_win():
    seq = cat(
        note(NOTE["C5"], 0.09),
        note(NOTE["E5"], 0.09),
        note(NOTE["G5"], 0.09),
        chord([NOTE["C6"], NOTE["E5"], NOTE["G5"]], 0.55, k=2.0),
    )
    return env(seq, release=0.12)


# ---- 6. 激アツファンファーレ（タタタ タン タタタ ターーン！） ----
def fanfare_jackpot():
    def burst(f):
        return cat(note(f, 0.07), silence(0.015),
                   note(f, 0.07), silence(0.015),
                   note(f, 0.07), silence(0.015))

    seq = cat(
        burst(NOTE["C5"]),
        chord([NOTE["F5"], NOTE["A5"]], 0.22, k=1.5),
        silence(0.05),
        burst(NOTE["E5"]),
        chord([NOTE["G5"], NOTE["D6"]], 0.22, k=1.5),
        silence(0.05),
        chord([NOTE["C6"], NOTE["E6"], NOTE["G6"], NOTE["C5"]], 1.0, k=1.6),
    )
    return env(seq, release=0.2)


# ---- 7. たぬき「ぽんっ」（ピッチが跳ねるかわいいポップ音） ----
def pon():
    pop = decay(noise(0.018), 7)  # 「ぽ」の破裂
    body = decay(
        triangle(lambda t: 350 + 550 * math.sin(min(1.0, t * 1.4) * math.pi / 2), 0.13),
        4,
    )
    tail = decay(triangle(lambda t: 900 - 150 * t, 0.05), 5)
    return env(cat(vol(pop, 0.7), body, vol(tail, 0.5)),
               attack=0.001, release=0.03)


os.makedirs(OUT, exist_ok=True)
write_wav("spin_loop.wav", spin_loop(), gain=0.55)
write_wav("reel_stop.wav", reel_stop(), gain=0.75)
write_wav("reach.wav", reach(), gain=0.7)
write_wav("cutin.wav", cutin(), gain=0.85)
write_wav("fanfare_win.wav", fanfare_win(), gain=0.8)
write_wav("fanfare_jackpot.wav", fanfare_jackpot(), gain=0.8)
write_wav("pon.wav", pon(), gain=0.8)
print("done")
