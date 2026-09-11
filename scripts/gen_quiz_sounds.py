#!/usr/bin/env python3
"""生成「看图找规律」的答题音效（WAV，16bit 单声道 44.1kHz）。

全部用纯 Python 标准库合成，不依赖任何音频素材；
重新生成：python3 scripts/gen_quiz_sounds.py
"""

import math
import os
import struct
import wave

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')

# 音名 -> 频率（十二平均律，A4 = 440Hz）
def note(name):
    steps = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4,
             'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * (2 ** (steps[pitch] / 12.0 + (octave - 4)))


def bell(freq, t, harmonics=((1.0, 1.0), (2.0, 0.36), (3.0, 0.16), (4.6, 0.08))):
    """钟琴音色：若干泛音叠加。"""
    return sum(amp * math.sin(2 * math.pi * freq * mult * t)
               for mult, amp in harmonics)


def strike(freq, dur, attack=0.006, decay=6.0, gain=1.0):
    """敲一下 [freq]：快速起音 + 指数衰减。"""
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        if t < attack:
            env = t / attack
        else:
            env = math.exp(-decay * (t - attack))
        out.append(gain * env * bell(freq, t))
    return out


def mix(*tracks):
    length = max(offset + len(t) for t, offset in tracks)
    buf = [0.0] * length
    for track, offset in tracks:
        for i, v in enumerate(track):
            buf[offset + i] += v
    return buf


def silence(dur):
    return [0.0] * int(RATE * dur)


def normalize(samples, peak=0.86):
    top = max(abs(s) for s in samples) or 1.0
    scale = peak / top
    return [s * scale for s in samples]


def fade_out(samples, dur=0.03):
    n = min(int(RATE * dur), len(samples))
    for i in range(n):
        samples[len(samples) - n + i] *= 1 - i / n
    return samples


def write_wav(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1.0, min(1.0, s)) * 32767))
            for s in samples))
    print(f'{name}: {os.path.getsize(path) / 1024:.1f} KB, '
          f'{len(samples) / RATE:.2f}s')


def main():
    # 答对：「叮——咚」，两个音上行，明亮欢快
    write_wav('quiz_right.wav', fade_out(normalize(mix(
        (strike(note('C6'), 0.34, decay=9.0), 0),
        (strike(note('E6'), 0.40, decay=8.0), int(RATE * 0.09)),
        (strike(note('G6'), 0.36, decay=11.0, gain=0.5), int(RATE * 0.18)),
    ))))

    # 答错：两个音下行，轻、短、不吓人
    write_wav('quiz_wrong.wav', fade_out(normalize(mix(
        (strike(note('A4'), 0.22, decay=13.0, gain=0.9), 0),
        (strike(note('E4'), 0.26, decay=11.0, gain=0.8), int(RATE * 0.11)),
    ), peak=0.62), dur=0.05))

    # 通关：小号角上行琶音 + 收尾长音
    write_wav('quiz_win.wav', fade_out(normalize(mix(
        (strike(note('C5'), 0.30, decay=12.0), 0),
        (strike(note('E5'), 0.30, decay=12.0), int(RATE * 0.12)),
        (strike(note('G5'), 0.30, decay=12.0), int(RATE * 0.24)),
        (strike(note('C6'), 0.95, decay=4.2, gain=1.0), int(RATE * 0.36)),
        (strike(note('E6'), 0.95, decay=4.2, gain=0.45), int(RATE * 0.36)),
        (strike(note('G6'), 0.95, decay=4.6, gain=0.22), int(RATE * 0.36)),
    ))))


if __name__ == '__main__':
    main()
