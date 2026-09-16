#!/usr/bin/env python3
"""生成「看图问答」题库的中文语音，并输出逐词时间轴。

输入 `assets/data/qa_questions.json`（题目唯一真源），为每道题生成：

  - `assets/audio/qa/<file>.mp3`        题面朗读
  - `assets/audio/qa/<file>.o<i>.mp3`   选项朗读（仅低龄段，孩子还不认字）

同时写出 `assets/data/qa_voice.json`，里面是每个音频的时长和**逐词起止时间**，
App 靠它做「朗读时文字跟随高亮」。时间轴按字符下标存，直接对应题面文字。

用法：
    python3 scripts/gen_qa_voice.py            # 增量（文字没变就跳过）
    python3 scripts/gen_qa_voice.py --force    # 全量重新生成

需要联网（edge-tts 走微软在线语音），生成完的 mp3 打包进 App，运行时不再联网。
"""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import sys
from pathlib import Path

import edge_tts

ROOT = Path(__file__).resolve().parent.parent
QUESTIONS = ROOT / "assets" / "data" / "qa_questions.json"
MANIFEST = ROOT / "assets" / "data" / "qa_voice.json"
OUT_DIR = ROOT / "assets" / "audio" / "qa"

# 语音与语速固定成基准音，App 里再按用户选择变速播放。
VOICE = "zh-CN-XiaoxiaoNeural"
RATE = "+0%"
CONCURRENCY = 6
RETRIES = 3

# 只有还不认字的年龄段才给选项配音，大孩子自己读题。
SPEAK_OPTION_AGES = {"baby", "toddler", "preschool"}

# 中文标点，做兜底均分时权重比汉字低。
PUNCT = set("，。？！、；：,.?!;:…—～~ 「」『』（）()《》\"'")

AGE_CODE = {
    "baby": "B",
    "toddler": "T",
    "preschool": "P",
    "lowerGrade": "L",
    "upperGrade": "U",
}
KIND_CODE = {
    "describe": "DESC",
    "pickImage": "PICK",
    "sameDiff": "SAME",
    "add": "ADD",
    "compare": "CMP",
}


# ---------- 题号 ----------

def qid_of(q: dict) -> str:
    """结构化题号，例如 `QA.T.CMP.HIGH.trees`（主人反馈 bug 时直接贴这个）。"""
    parts = ["QA", AGE_CODE[q["age"]], KIND_CODE[q["kind"]]]
    if q.get("sub"):
        parts.append(q["sub"])
    parts.append(q["id"])
    return ".".join(parts)


def file_base(qid: str) -> str:
    return qid.replace(".", "_")


# ---------- mp3 时长（不依赖 ffmpeg，直接解析帧头） ----------

_BITRATES_V2_L3 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0]
_RATES = {0: 44100, 1: 48000, 2: 32000}


def mp3_duration(data: bytes) -> float:
    """把 mp3 各帧时长累加。edge-tts 输出是常量码率，结果足够准。"""
    i, total = 0, 0.0
    n = len(data)
    while i + 4 <= n:
        if data[i] != 0xFF or (data[i + 1] & 0xE0) != 0xE0:
            i += 1
            continue
        ver = (data[i + 1] >> 3) & 0x03          # 2 = MPEG2
        layer = (data[i + 1] >> 1) & 0x03        # 1 = Layer III
        bitrate_idx = (data[i + 2] >> 4) & 0x0F
        rate_idx = (data[i + 2] >> 2) & 0x03
        padding = (data[i + 2] >> 1) & 0x01
        if layer != 1 or bitrate_idx in (0, 15) or rate_idx == 3:
            i += 1
            continue
        if ver == 2:  # MPEG2 / MPEG2.5
            bitrate = _BITRATES_V2_L3[bitrate_idx] * 1000
            sample_rate = _RATES[rate_idx] // (2 if ver == 2 else 4)
        else:
            i += 1
            continue
        if bitrate == 0 or sample_rate == 0:
            i += 1
            continue
        frame_len = 72 * bitrate // sample_rate + padding
        if frame_len <= 4:
            i += 1
            continue
        total += 576 / sample_rate
        i += frame_len
    return total


# ---------- 时间轴对齐 ----------

def align(text: str, events: list[tuple[str, int, int]]) -> list[list] | None:
    """把 edge-tts 的逐词事件对齐成 [起字符, 止字符, 起秒, 止秒]。

    对不上（语音引擎改写了文字，比如把 "3" 念成 "三"）就返回 None，
    交给按字数均分的兜底。
    """
    spans: list[list] = []
    cursor = 0
    for word, off, dur in events:
        idx = text.find(word, cursor)
        if idx < 0:
            return None
        start, end = off / 1e7, (off + dur) / 1e7
        if idx > cursor and spans:
            # 中间的标点并进上一段：停顿期间高亮不闪断，跟在标点上很自然。
            spans[-1][1] = idx
            spans[-1][3] = start
        spans.append([idx, idx + len(word), start, end])
        cursor = idx + len(word)
    if not spans:
        return None
    spans[-1][1] = len(text)  # 收尾标点并入最后一段
    return spans


def proportional(text: str, duration: float) -> list[list]:
    """兜底：按字数（标点算 0.4 个）均分整段时长。"""
    weights = [0.4 if ch in PUNCT else (0.0 if ch.isspace() else 1.0) for ch in text]
    total = sum(weights)
    if total <= 0:
        return []
    spans, t = [], 0.0
    for i, w in enumerate(weights):
        d = duration * w / total
        spans.append([i, i + 1, round(t, 3), round(t + d, 3)])
        t += d
    return spans


# ---------- 生成 ----------

async def synth(text: str, dest: Path) -> tuple[bytes, list[tuple[str, int, int]]]:
    """合成一段语音，返回 (mp3 字节, 逐词事件)。"""
    communicate = edge_tts.Communicate(text, VOICE, rate=RATE, boundary="WordBoundary")
    audio = bytearray()
    events: list[tuple[str, int, int]] = []
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            audio += chunk["data"]
        elif chunk["type"] == "WordBoundary":
            events.append((chunk["text"], chunk["offset"], chunk["duration"]))
    if not audio:
        raise RuntimeError("没有拿到音频数据")
    dest.write_bytes(bytes(audio))
    return bytes(audio), events


def digest(text: str) -> str:
    return hashlib.sha1(f"{VOICE}|{RATE}|{text}".encode()).hexdigest()[:16]


async def build_clip(sem, key: str, text: str, cached: dict, force: bool):
    """合成一个音频片段；已有且文字没变就复用。"""
    old = cached.get(key)
    dest = OUT_DIR / f"{key}.mp3"
    if not force and old and old.get("h") == digest(text) and dest.exists():
        return key, old, False

    async with sem:
        last_err = None
        for attempt in range(RETRIES):
            try:
                data, events = await synth(text, dest)
                spans = align(text, events)
                if spans is None:
                    spans = proportional(text, mp3_duration(data))
                entry = {
                    "f": f"audio/qa/{key}.mp3",
                    "d": round(mp3_duration(data), 3),
                    "s": spans,
                    "h": digest(text),
                    "t": text,
                }
                return key, entry, True
            except Exception as exc:  # noqa: BLE001 - 网络抖动重试
                last_err = exc
                await asyncio.sleep(1.5 * (attempt + 1))
        raise RuntimeError(f"{key} 生成失败：{last_err}")


def clips_of(q: dict) -> list[tuple[str, str]]:
    """一道题要生成的音频片段：先题面，后选项（低龄段才配）。"""
    base = file_base(qid_of(q))
    out: list[tuple[str, str]] = []
    if q.get("read", True):
        out.append((base, q["prompt"]))
    if q["age"] in SPEAK_OPTION_AGES:
        for i, opt in enumerate(q["options"]):
            label = (opt.get("text") or "").strip()
            if label:
                out.append((f"{base}.o{i}", label))
    return out


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="全量重新生成")
    args = parser.parse_args()

    bank = json.loads(QUESTIONS.read_text(encoding="utf-8"))
    questions = bank["questions"]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cached: dict = {}
    if MANIFEST.exists():
        cached = json.loads(MANIFEST.read_text(encoding="utf-8")).get("clips", {})

    wanted: list[tuple[str, str]] = []
    seen: set[str] = set()
    for q in questions:
        for key, text in clips_of(q):
            if key in seen:
                print(f"  重复的音频键：{key}", file=sys.stderr)
                continue
            seen.add(key)
            wanted.append((key, text))

    print(f"题库 {len(questions)} 题，需要 {len(wanted)} 段语音")

    sem = asyncio.Semaphore(CONCURRENCY)
    results = await asyncio.gather(
        *(build_clip(sem, k, t, cached, args.force) for k, t in wanted)
    )

    clips = {k: v for k, v, _ in results}
    made = sum(1 for _, _, fresh in results if fresh)
    unaligned = sum(1 for v in clips.values() if not v["s"])

    MANIFEST.write_text(
        json.dumps(
            {
                "voice": VOICE,
                "rate": RATE,
                "generated": len(clips),
                "clips": dict(sorted(clips.items())),
            },
            ensure_ascii=False,
            indent=1,
        ),
        encoding="utf-8",
    )

    # 清掉题库里已经删掉的题目留下的老音频
    for f in OUT_DIR.glob("*.mp3"):
        if f.stem not in clips:
            f.unlink()
            print(f"  清掉过期音频 {f.name}")

    total = sum(v["d"] for v in clips.values())
    print(f"完成：新生成 {made} 段，复用 {len(clips) - made} 段，共 {len(clips)} 段 / {total:.0f} 秒")
    if unaligned:
        print(f"注意：{unaligned} 段没能对齐逐词时间，已按字数均分高亮")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
