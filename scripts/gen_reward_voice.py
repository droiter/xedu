#!/usr/bin/env python3
"""生成「做题奖惩」的两句提示语音。

  - `assets/audio/punish_black.mp3`  答错超限后播报：「答错了，黑屏」
  - `assets/audio/reward_video.mp3`  一次答对后播报：「一次答对，奖励看视频」

音色与「看图问答」的朗读一致（见 `scripts/gen_qa_voice.py`），
但**不需要逐词时间轴** —— 这两句只在奖惩时整段播一遍，没有跟读高亮。

用法：
    python3 scripts/gen_reward_voice.py            # 已有就跳过
    python3 scripts/gen_reward_voice.py --force    # 重新生成

需要联网（edge-tts 走微软在线语音），生成完的 mp3 打包进 App，运行时不再联网。
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

import edge_tts

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "audio"

VOICE = "zh-CN-XiaoxiaoNeural"
RATE = "+0%"
RETRIES = 3

# 文件主名 -> 要念的文字
CLIPS = {
    "punish_black": "答错了，黑屏。",
    "reward_video": "一次答对，奖励看视频。",
}


async def synth(text: str, dest: Path) -> None:
    last_err: Exception | None = None
    for _ in range(RETRIES):
        try:
            audio = bytearray()
            async for chunk in edge_tts.Communicate(text, VOICE, rate=RATE).stream():
                if chunk["type"] == "audio":
                    audio += chunk["data"]
            if not audio:
                raise RuntimeError("没有拿到音频数据")
            dest.write_bytes(bytes(audio))
            return
        except Exception as e:  # noqa: BLE001 —— 网络抖动就重试
            last_err = e
    raise RuntimeError(f"合成失败：{text}") from last_err


async def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="已存在也重新生成")
    args = ap.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for key, text in CLIPS.items():
        dest = OUT_DIR / f"{key}.mp3"
        if dest.exists() and not args.force:
            print(f"跳过 {dest.name}（已存在，{dest.stat().st_size} B）")
            continue
        await synth(text, dest)
        print(f"生成 {dest.name}（{dest.stat().st_size} B）：{text}")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
