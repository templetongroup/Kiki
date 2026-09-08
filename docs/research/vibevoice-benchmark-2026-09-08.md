# VibeVoice-ASR-Streaming 1.5B Apple Silicon benchmark

Tested 2026-09-08 as an isolated research runtime. Nothing from this benchmark
is linked into Kiki's application target or release bundle.

## Verdict

**Do not integrate the current 1.5B checkpoint into Kiki.** It is fast enough
once running, but its first-text delay, memory use, unreliable natural-conversation
speaker attribution, and weak hotword result outweigh the one successful clean
two-voice test. Keep Parakeet/Whisper as Kiki's production engines and revisit
VibeVoice when Microsoft provides a smaller native/quantized streaming runtime
with longer-session and Apple Silicon evidence.

## Reproducible setup

- Mac: Apple M4 Pro, 12 CPU cores, 48 GB unified memory
- macOS: 26.5.2 (25F84)
- VibeVoice code: Microsoft commit
  [`1541f590c7099820f10ea012f48d2399282df69f`](https://github.com/microsoft/VibeVoice/tree/1541f590c7099820f10ea012f48d2399282df69f)
- Checkpoint: `microsoft/VibeVoice-ASR-Streaming-1.5B`, revision
  [`4262d23d8a539a6530cf64fbd0b1751ef9a30853`](https://huggingface.co/microsoft/VibeVoice-ASR-Streaming-1.5B/tree/4262d23d8a539a6530cf64fbd0b1751ef9a30853)
- Runtime: Python 3.11.15, PyTorch 2.14.0, Transformers 4.57.6, MPS, SDPA,
  float32 as required by Microsoft's non-CUDA path
- Download footprint: 5.3 GiB checkpoint plus 1.0 GiB isolated environment
- Harness: [`scripts/experimental/vibevoice_streaming_benchmark.py`](../../scripts/experimental/vibevoice_streaming_benchmark.py)

Microsoft's released preprocessing configuration uses 2.933-second chunks and
0.533-second lookahead. A real live stream therefore cannot emit its first text
before 3.467 seconds of audio has arrived, before inference time is added
([paper limitations](https://arxiv.org/html/2609.02812v1#S6),
[checkpoint configuration](https://huggingface.co/microsoft/VibeVoice-ASR-Streaming-1.5B/blob/4262d23d8a539a6530cf64fbd0b1751ef9a30853/preprocessor_config.json)).

## Results

| Test | Audio | Generation | RTF | Compute to first chunk | Estimated earliest live text | Speaker result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Controlled Kiki two-voice sample | 17.82 s | 5.04 s | 0.283 | 1.83 s | about 5.30 s | Correct 0/1/0/1 alternation |
| Microsoft's natural chat demo | 68.99 s | 21.59 s | 0.313 | 3.90 s | about 7.37 s | Failed: every utterance was Speaker 0 |
| Microsoft's hotword demo | 17.28 s | 7.66 s | 0.443 | Not instrumented | At least 3.47 s plus compute | One speaker; “VibeVoice” was still wrong |

The controlled test supplied `Tony`, `Jordan`, `Kiki`, `Templeton Technologies`,
`Sparkle`, and `appcast` as context. Speaker turns were correct, but the model
rendered “Templeton Technologies” as “template and technology's.” Microsoft's
hotword sample likewise rendered “VibeVoice” incorrectly even though the term
was supplied as context. These two observations do not prove hotwords never
help; they do show that Kiki cannot treat them as reliable corrections.

On the controlled run, model loading took 4.77 seconds, MPS held approximately
10.37 GB after loading, the MPS driver held approximately 10.96 GB after
generation, and maximum process resident memory was approximately 12.0 GB. The
same test through Kiki's warm Parakeet TDT v2 CLI finished in 0.49 seconds with
approximately 130 MB maximum resident memory. Parakeet does not diarize a mixed
track, but Kiki already gets reliable `You` versus remote separation from its
independent microphone and system-audio captures.

## Acceptance decision

The research plan required the candidate to:

1. stay faster than real time — **pass**;
2. produce a suitably prompt first update — **fail** at roughly 5.3–7.4 seconds;
3. materially improve remote-speaker separation — **fail** on the natural chat;
4. fit Kiki's supported memory envelope — **fail** for ordinary 16 GB Macs;
5. improve important terminology through context — **not demonstrated**; and
6. remain suitable for normal meetings — **fail** because the released model
   still has an eight-minute session limit and no native timestamps
   ([paper](https://arxiv.org/html/2609.02812v1#S6)).

The result is a research rejection, not a failed installation. The checkpoint
does run correctly through MPS on this 48 GB Mac, which makes future retesting
straightforward if Microsoft publishes improved or quantized checkpoints.
