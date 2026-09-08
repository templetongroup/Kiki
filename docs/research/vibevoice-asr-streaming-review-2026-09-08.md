# VibeVoice-ASR-Streaming ideas worth testing in Kiki

> **Benchmark update:** The proposed 1.5B MPS benchmark was completed on an
> Apple M4 Pro with 48 GB unified memory. The model ran faster than real time,
> but used roughly 10.4 GB of MPS allocations, took an estimated 5.3–7.4 seconds
> to produce its first live text, failed to separate the speakers in Microsoft's
> natural two-person demo, and did not preserve “Templeton Technologies” despite
> receiving it as context. The current checkpoint does not meet Kiki's shipping
> bar. See [the benchmark report](vibevoice-benchmark-2026-09-08.md).

Reviewed 2026-09-08 against Microsoft VibeVoice commit [`1541f590c7099820f10ea012f48d2399282df69f`](https://github.com/microsoft/VibeVoice/tree/1541f590c7099820f10ea012f48d2399282df69f), the released [`VibeVoice-ASR-Streaming-7B`](https://huggingface.co/microsoft/VibeVoice-ASR-Streaming-7B) checkpoint, its 2026-09-02 [technical report](https://arxiv.org/html/2609.02812v1), and Kiki `28d2ae32f72ab6912f1487a880f5cde976f8eeb9`. Only Microsoft project sources, Microsoft model artifacts, and the authors' paper were used for upstream claims.

## Bottom line

Yes, but the value is in **Meeting Mode**, not ordinary dictation. VibeVoice-ASR-Streaming's strongest idea is one model that produces a live, speaker-attributed transcript—“who said what”—while retaining prior speech and text so speaker labels remain consistent across chunks. Its second useful idea is feeding names, technical terms, and abbreviations into recognition as context instead of correcting them only after transcription ([model card](https://huggingface.co/microsoft/VibeVoice-ASR-Streaming-7B#key-features), [architecture and contextual prompting](https://arxiv.org/html/2609.02812v1#S3.SS1)).

Do **not** add the 7B checkpoint to Kiki now. The published checkpoint is **17.35 GB of BF16 weights** and Hugging Face reports roughly 9B total parameters; Microsoft's only published real-time benchmark uses an **NVIDIA A100 80 GB** with vLLM, not Apple Silicon. The basic inference script lists MPS as a device, but deliberately loads non-CUDA devices in float32, making the weights alone roughly 34.7 GB before caches and runtime overhead ([7B files and weight metadata](https://huggingface.co/microsoft/VibeVoice-ASR-Streaming-7B/tree/main), [official MPS/device path](https://github.com/microsoft/VibeVoice/blob/1541f590c7099820f10ea012f48d2399282df69f/demo/vibevoice_asr_streaming_inference_from_file.py#L71-L123), [A100 benchmark](https://arxiv.org/html/2609.02812v1#S5.SS5)).

The right next step is a **disposable 1.5B Meeting Mode benchmark on Apple Silicon**, not a product integration. The smaller checkpoint is still 5.65 GB in BF16 and substantially less accurate at speaker attribution than the 7B model, but it is the only upstream variant with a plausible path to testing on a high-memory Mac without first building a new quantized runtime ([1.5B files](https://huggingface.co/microsoft/VibeVoice-ASR-Streaming-1.5B/tree/main), [model-scale results](https://arxiv.org/html/2609.02812v1#S5.SS2)).

## Ranked recommendations

| Rank | Adapt for Kiki | Value | Cost / risk | Decision |
| ---: | --- | --- | --- | --- |
| 1 | Live multi-speaker attribution in Meeting Mode | Very high | Heavy model; eight-minute checkpoint limit; Mac performance unknown | Benchmark the 1.5B model outside the app |
| 2 | Feed Kiki vocabulary and participant names into ASR context | High | Needs prompt-size and false-bias limits | Adapt now at the transcription-engine boundary where supported |
| 3 | Persistent speaker identity across streaming chunks | High | State grows with meeting length | Reuse as an architecture requirement for any future meeting engine |
| 4 | Ten-language meeting transcription | Medium-high | Uneven quality; larger runtime | Benchmark only after English meeting quality passes |
| 5 | Incremental transcript cards and rolling local brief | Medium | UI/state work; text may end mid-sentence per chunk | Can improve Kiki independently of VibeVoice |
| 6 | Replace Parakeet/Whisper dictation | Low | 2.5–3.5 s first packet; huge footprint | Do not pursue |
| 7 | Use its output as precise captions | Low | Streaming model emits no timestamps | Do not use without a separate aligner |

## What the model actually is

VibeVoice-ASR-Streaming builds on VibeVoice-ASR with two causal audio encoders: an Acoustic tokenizer and a Semantic tokenizer. Both reduce 24 kHz mono audio by 3,200×, producing 7.5 frames per second; their representations are concatenated and projected into a Qwen2.5 language-model backbone. Incoming audio chunks and generated speaker-attributed text chunks are interleaved in a single autoregressive context, so later chunks can reuse the full conversation's acoustic, textual, and speaker history ([paper architecture](https://arxiv.org/html/2609.02812v1#S3.SS1), [7B configuration](https://huggingface.co/microsoft/VibeVoice-ASR-Streaming-7B/blob/main/config.json)).

The released checkpoints use 22 latent frames—about **2.9 seconds of new audio**—plus four lookahead frames, about **0.5 seconds**. That configuration has a theoretical average speaker-attribution delay of 2.0 seconds, but the first text cannot arrive until the first full chunk and lookahead have been received, so published first-packet latency is **3.5 seconds**. A separately trained 15-frame configuration reduces first output to 2.5 seconds and expected attribution latency to 1.53 seconds, but Microsoft has released the 22-frame checkpoints represented by the linked preprocessing files ([released preprocessing configuration](https://huggingface.co/microsoft/VibeVoice-ASR-Streaming-7B/blob/main/preprocessor_config.json), [latency definition](https://arxiv.org/html/2609.02812v1#S4.SS2), [limitations](https://arxiv.org/html/2609.02812v1#S6)).

The model produces ordinal labels such as `Speaker 0:` and `Speaker 1:` in order of first appearance and carries them forward across later chunks. It jointly performs recognition and speaker attribution; there is no separate diarization or post-meeting clustering stage. Overlapping speech is serialized into consecutive labeled text, which works for short conversational overlap but degrades when people overlap for long periods ([output behavior](https://arxiv.org/html/2609.02812v1#S3.SS1.SSS1), [overlap limitation](https://arxiv.org/html/2609.02812v1#S6)).

## What Kiki can leverage

### 1. Upgrade Meeting Mode from source labels to actual remote speakers

Kiki currently records microphone and system audio separately, labels the microphone track `You`, labels the entire remote track `Speaker 1`, transcribes them separately, and merges their timed segments ([meeting transcription pipeline](../../Sources/Kiki/DictationController.swift#L358-L444)). That reliably distinguishes the user from the computer, but it cannot tell two remote participants apart.

A future speaker-aware engine could preserve `You` from Kiki's isolated microphone track while running speaker attribution only over the remote track. The result would be `You`, `Remote speaker 1`, `Remote speaker 2`, and so on, with Kiki's existing speaker editor mapping those ordinal labels to names once and updating the transcript and exports ([speaker editor](../../Sources/Kiki/MeetingSpeakerEditorWindowController.swift#L145-L208)). This is the clearest product improvement in VibeVoice.

Do not mix the microphone and system tracks before recognition unless a benchmark proves it improves attribution. Kiki's existing physical source separation is valuable ground truth; VibeVoice should add resolution within the remote track rather than discard that advantage.

### 2. Move custom vocabulary upstream into recognition

The streaming model accepts optional context containing names, technical terms, abbreviations, and other hotwords; that context stays available for the whole session. Microsoft's sample exposes it as `--context_info`, and the WebSocket demo accepts the same value ([official usage guide](https://github.com/microsoft/VibeVoice/blob/1541f590c7099820f10ea012f48d2399282df69f/docs/vibevoice-asr-streaming.md#L224-L236), [paper](https://arxiv.org/html/2609.02812v1#S3.SS1)).

Kiki should make this an engine-neutral capability. At meeting start, construct a bounded local context from:

- participant names entered by the user;
- approved custom-dictionary terms;
- relevant per-app learned corrections; and
- an optional meeting-title vocabulary field.

Keep Kiki's deterministic post-processing as a fallback. Context biasing improves what the recognizer hears, while Kiki's current dictionary and correction layer remains visible and reversible. Limit the number and length of terms so irrelevant vocabulary does not bias ordinary words.

### 3. Make speaker continuity a first-class streaming state

VibeVoice's useful architectural lesson is that online speaker identity depends on retained history. It keeps previous speech and generated transcript in the same context rather than treating every 2.9-second chunk independently. The paper argues that discarding history would require recreating it with an external speaker cache or later clustering ([streaming formulation](https://arxiv.org/html/2609.02812v1#S3.SS1)).

Whether Kiki eventually uses VibeVoice, Core ML, or another native engine, its meeting-transcriber protocol should preserve session state and emit stable speaker-labelled updates instead of independent text snippets. A practical event contract would include `.partial`, `.committedSegment(speakerID:text:coarseTimeRange:)`, `.speakerChanged`, and `.finished`, with Kiki retaining the mapping from stable engine IDs to user-edited names.

### 4. Extend Meeting Mode to ten languages—after English passes

The model card lists Chinese, English, French, German, Italian, Japanese, Korean, Portuguese, Russian, and Spanish. It does not require a language prior or a known speaker count in the paper's comparison ([model card](https://huggingface.co/microsoft/VibeVoice-ASR-Streaming-7B#key-features), [evaluation protocol](https://arxiv.org/html/2609.02812v1#A2.SS2)).

This is attractive for Kiki, but the results are not uniformly strong. On the paper's multilingual conversational benchmark, VibeVoice 7B trails the best comparison system in French, German, Italian, Japanese, Portuguese, and Russian recognition-only error, even though its average speaker-attribution result is strong. Language support should therefore be a measured capability matrix, not a blanket promise ([per-language results](https://arxiv.org/html/2609.02812v1#S4)).

### 5. Stream Kiki's existing brief as segments commit

VibeVoice emits text once per audio chunk. Kiki can use the same interaction pattern independently of this model: append committed transcript segments to the meeting UI, keep the newest segment visible, and incrementally refresh its existing local summary, decisions, action items, and next steps. Kiki already derives all four from `MeetingTranscript` without a cloud service ([local brief implementation](../../Sources/Kiki/MeetingTranscript.swift#L111-L214)).

VibeVoice itself does **not** generate summaries, decisions, or tasks. Those remain Kiki features. Its role would be to improve the speaker-labelled input feeding Kiki's local brief.

## Important gaps and limitations

### No true timestamps in the streaming output

The streaming checkpoint emits speaker labels and text but **no timestamps**. Microsoft's vLLM adapter fabricates segment times from chunk boundaries; those are useful coarse ranges, not word alignment. The paper explicitly states that no timestamps are emitted ([paper output format](https://arxiv.org/html/2609.02812v1#A1), [adapter's arithmetic timestamp logic](https://github.com/microsoft/VibeVoice/blob/1541f590c7099820f10ea012f48d2399282df69f/vllm_plugin/asr_streaming.py#L215-L259)).

Kiki's SRT/VTT export needs actual start and end times. Preserve Kiki's recorder timeline and either use chunk-edge times as visibly coarse segment ranges or run a separate local forced aligner after the meeting. Do not advertise word-level timing from this model.

### Eight-minute released-checkpoint limit

The released checkpoints support recordings up to eight minutes because the uncompressed retained history grows linearly with session length. This is far below normal meeting duration and blocks direct replacement of Kiki's current long-running Meeting Mode ([context cost](https://arxiv.org/html/2609.02812v1#S3.SS1), [recording-length limitation](https://arxiv.org/html/2609.02812v1#S6)).

A benchmark must test whether resetting state every several minutes destroys speaker continuity. If it does, the model is unsuitable for Kiki until Microsoft publishes longer-context checkpoints or a reliable compressed speaker memory.

### Not optimized for single-speaker dictation

The authors say short-form single-speaker audio is not the model's target and it wins none of their individual short-form test sets. Its first output takes 3.5 seconds in the released configuration ([single-speaker results](https://arxiv.org/html/2609.02812v1#S4), [first-packet limitation](https://arxiv.org/html/2609.02812v1#S6)). Kiki's normal dictation should remain on Parakeet/Whisper, where footprint, startup time, and short-utterance behavior matter more than multi-speaker identity.

### Real-time claims do not transfer to a Mac

Microsoft measures the 7B 15-frame model at RTF 0.073–0.104 using BF16 vLLM on one A100 80 GB. The project guide recommends an NVIDIA PyTorch container and CUDA/FlashAttention for deployment ([benchmark setup](https://arxiv.org/html/2609.02812v1#S5.SS5), [installation guide](https://github.com/microsoft/VibeVoice/blob/1541f590c7099820f10ea012f48d2399282df69f/docs/vibevoice-asr-streaming.md#L202-L223)). Those results do not establish Apple Silicon performance.

The direct inference script exposes `mps`, which is encouraging, but switches every non-CUDA device to float32. There is no official Mac latency, memory, power, or long-session stability result. MPS support should be described as a code path, not a validated deployment target ([inference script](https://github.com/microsoft/VibeVoice/blob/1541f590c7099820f10ea012f48d2399282df69f/demo/vibevoice_asr_streaming_inference_from_file.py#L71-L123)).

### Python is a poor shipping fit for Kiki

The official stack requires Python 3.10+, PyTorch, Transformers, Accelerate, audio/scientific packages, ffmpeg, and—for the demo—FastAPI/WebSocket components ([package dependencies](https://github.com/microsoft/VibeVoice/blob/1541f590c7099820f10ea012f48d2399282df69f/pyproject.toml#L304-L376), [usage guide](https://github.com/microsoft/VibeVoice/blob/1541f590c7099820f10ea012f48d2399282df69f/docs/vibevoice-asr-streaming.md#L202-L236)). Kiki is a native SwiftPM application using Core ML and Metal-backed native runtimes ([Kiki architecture](../../README.md#L108-L118)). Bundling the official stack would materially increase download size, signing surface, cold start, update complexity, and support risk.

A production path would need a native or tightly sandboxed sidecar runtime, a quantized checkpoint, and real installed-app tests. None exists in Microsoft's repository today.

## Apple Silicon feasibility

| Candidate | Published size / runtime | Kiki assessment |
| --- | --- | --- |
| Streaming 7B, official BF16 | 17.35 GB weights; A100 80 GB/vLLM benchmark | Reject for the shipping app; too large and no Mac evidence |
| Streaming 7B, official MPS path | Script loads float32, implying about 34.7 GB of weights before overhead | Research only on 64 GB+ Apple Silicon; likely unsuitable even there without quantization |
| Streaming 1.5B, official BF16 | 5.65 GB checkpoint; HF reports roughly 3B total parameters | Only plausible upstream Mac experiment; quality is materially below 7B |
| Quantized/native port | No Microsoft-provided MLX, Core ML, GGUF, or Metal-native release | Reconsider if a first-party or well-audited runtime appears |
| Kiki Parakeet TDT v2/v3 | About 500 MB; Core ML on Apple Silicon | Keep for dictation and as Meeting Mode baseline |

The 1.5B model's paper-average speaker-attributed error is 44.31 versus 31.55 for 7B at the released 22-frame chunk size, a large quality loss. A smaller download therefore does not automatically mean a useful meeting experience ([Table 5](https://arxiv.org/html/2609.02812v1#S5.SS2)).

## License and production posture

Microsoft publishes the repository and both model cards under the MIT License, permitting commercial use, copying, modification, distribution, sublicensing, and sale when the copyright and license notice are preserved ([repository license](https://github.com/microsoft/VibeVoice/blob/1541f590c7099820f10ea012f48d2399282df69f/LICENSE), [7B model card](https://huggingface.co/microsoft/VibeVoice-ASR-Streaming-7B#license)). If Kiki copies meaningful code or redistributes weights, add Microsoft's MIT notice to `THIRD_PARTY_NOTICES.md` and retain it with any distributed copy.

The repository also explicitly says VibeVoice is intended for research and development and is not recommended for commercial or real-world use without further testing and development. It warns about inaccurate or biased outputs and asks deployers to validate legal and responsible use ([project limitations](https://github.com/microsoft/VibeVoice/tree/1541f590c7099820f10ea012f48d2399282df69f#%EF%B8%8F-risks-and-limitations)). The MIT license allows use; the warning means Kiki still needs its own accuracy, privacy, safety, and reliability validation before making product claims.

Fully local positioning can be preserved if Kiki downloads pinned weights into Application Support, verifies checksums, performs all inference on the Mac, and never uses the Microsoft-hosted demo or a cloud endpoint. The problem is current hardware/runtime fitness, not the license or privacy architecture.

## Recommended benchmark

Run this outside the shipping app, starting with the 1.5B checkpoint on an Apple Silicon Mac with at least 32 GB unified memory:

1. Pin Microsoft commit `1541f590c7099820f10ea012f48d2399282df69f` and the exact checkpoint revision.
2. Use the direct inference script with `--device mps`; do not use the hosted demo.
3. Test real Kiki meeting captures with separate microphone and system-audio tracks, including two and three remote speakers.
4. Measure model load time, peak memory, first-text latency, per-chunk compute, total RTF, energy impact, thermal behavior, cancellation, and recovery after an eight-minute state reset.
5. Score speaker stability, speaker confusion, words lost at chunk boundaries, overlap handling, and hotword gain on names and Templeton terminology.
6. Compare against Kiki's current Parakeet pipeline using the same audio and transcript normalization.
7. Reject the engine unless it stays faster than real time, produces a stable first update, and materially improves remote-speaker separation without making a normal meeting exceed Kiki's supported memory envelope.

Do not add a model picker or public promise until this benchmark passes in the installed, signed app on representative base and Pro/Max Macs.

## Recommended decision

1. **Keep Parakeet/Whisper for ordinary dictation.** VibeVoice's footprint and startup delay are wrong for that job.
2. **Adopt context-aware vocabulary as an engine-neutral Kiki feature.** Feed participant names and approved terminology into engines that support recognition-time biasing while retaining reversible post-processing.
3. **Benchmark Streaming 1.5B as an experimental remote-speaker engine.** Use Kiki's separate audio tracks and existing speaker editor; do not discard source separation.
4. **Do not ship Streaming 7B.** Its 17.35 GB BF16 checkpoint, CUDA-centered deployment, float32 MPS path, and absent Mac benchmarks make it incompatible with Kiki's broad local-Mac promise today.
5. **Treat timestamps, summaries, and long meetings as unsolved by VibeVoice.** Kiki must keep its own timeline and local brief, and the eight-minute context limit must be resolved before product integration.
