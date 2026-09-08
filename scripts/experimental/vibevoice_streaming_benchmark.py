#!/usr/bin/env python3
"""Benchmark a pinned VibeVoice streaming checkpoint outside Kiki's app runtime.

This harness intentionally depends on Microsoft's experimental Python package.
It records load time, first emitted chunk, total generation time, transcript, and
MPS memory so candidate models can be rejected before any native integration.
"""

from __future__ import annotations

import argparse
import json
import os
import resource
import time
from pathlib import Path

import torch

from vibevoice.modular.modeling_vibevoice_asr import (
    VibeVoiceASRForConditionalGeneration,
)
from vibevoice.processor.audio_utils import load_audio_use_ffmpeg
from vibevoice.processor.vibevoice_asr_processor import VibeVoiceASRProcessor


def frame_config(model_path: Path) -> dict[str, float]:
    with (model_path / "preprocessor_config.json").open() as handle:
        config = json.load(handle)
    frame_seconds = config["speech_tok_compress_ratio"] / config["target_sample_rate"]
    return {
        "sample_rate": config["target_sample_rate"],
        "chunk_duration": config["chunk_frames"] * frame_seconds,
        "lookahead_duration": config["lookahead_frames"] * frame_seconds,
    }


def mps_memory() -> dict[str, int]:
    if not torch.backends.mps.is_available():
        return {"current_allocated_bytes": 0, "driver_allocated_bytes": 0}
    return {
        "current_allocated_bytes": torch.mps.current_allocated_memory(),
        "driver_allocated_bytes": torch.mps.driver_allocated_memory(),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--audio", required=True, type=Path)
    parser.add_argument("--context", default=None)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--device", default="mps", choices=("mps", "cpu"))
    args = parser.parse_args()

    config = frame_config(args.model)
    started = time.perf_counter()
    processor = VibeVoiceASRProcessor.from_pretrained(args.model)
    model = VibeVoiceASRForConditionalGeneration.from_pretrained(
        args.model,
        dtype=torch.float32,
        attn_implementation="sdpa",
    ).to(args.device).eval()
    load_seconds = time.perf_counter() - started
    memory_after_load = mps_memory()

    audio, _ = load_audio_use_ffmpeg(
        str(args.audio),
        resample=True,
        target_sr=int(config["sample_rate"]),
    )
    audio_duration = len(audio) / config["sample_rate"]
    generation_started = time.perf_counter()
    first_chunk_seconds = None
    chunks: list[str] = []
    for _, _, chunk_text in model.streaming_generate(
        audio_tensor=torch.from_numpy(audio),
        tokenizer=processor.tokenizer,
        chunk_duration=config["chunk_duration"],
        text_audio_delay=config["lookahead_duration"],
        sample_rate=int(config["sample_rate"]),
        max_new_tokens_per_chunk=256,
        temperature=0.0,
        context_info=args.context,
    ):
        if first_chunk_seconds is None:
            first_chunk_seconds = time.perf_counter() - generation_started
        chunks.append(chunk_text)
    generation_seconds = time.perf_counter() - generation_started

    result = {
        "model_path": str(args.model),
        "audio_path": str(args.audio),
        "device": args.device,
        "torch_version": torch.__version__,
        "context": args.context,
        "audio_duration_seconds": audio_duration,
        "chunk_duration_seconds": config["chunk_duration"],
        "lookahead_duration_seconds": config["lookahead_duration"],
        "algorithmic_first_packet_seconds": (
            config["chunk_duration"] + config["lookahead_duration"]
        ),
        "model_load_seconds": load_seconds,
        "compute_to_first_chunk_seconds": first_chunk_seconds,
        "generation_seconds": generation_seconds,
        "real_time_factor": generation_seconds / audio_duration,
        "chunk_count": len(chunks),
        "memory_after_load": memory_after_load,
        "memory_after_generation": mps_memory(),
        "maximum_resident_set_bytes": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        "transcript": "".join(chunks).strip(),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
