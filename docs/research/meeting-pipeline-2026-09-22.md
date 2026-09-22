# Meeting pipeline correction — 0.6.66

## Scope and motivation

Tester reports: sustained meeting CPU/fan activity and inadequate transcript quality.
Source inspection found that Meeting Mode reused the dictation preview, repeatedly
passing all accumulated microphone samples to ASR. Its input grew with meeting length.
The final pass separately cut tracks at fixed 30-second boundaries.

Meetily reference inspected: `a2cb62e827da7ef59f65064c97233efb2313878e`.
Its separate speech-chunk processing is useful inspiration, but its unbounded work
queue and clipping mixer were not adopted. No Meetily code was copied.

## Changes

- Meeting-only ring buffer retains 12 seconds and emits every three seconds.
- A one-element pending queue replaces stale *preview* snapshots. This never
  removes samples from the independent microphone/system capture buffers.
- Preview clearly displays recent microphone speech, not the full transcript.
- Stop halts capture, awaits preview cancellation/cleanup, then transcribes.
- Final ranges prefer a quiet run in the last six seconds of a 30-second window.
  The ranges partition the input exactly, retaining the final partial range.
- Continuous speech without a detected pause still requires a hard boundary.
- Normal dictation preview behavior and retention preferences are unchanged.

## Verification

`bash scripts/test-meeting-audio-pipeline.sh` checks an hour of simulated numbered
samples through the preview feed, bounded/coalesced output, tail flushing,
post-stop rejection, pause placement, full sample coverage, and continuous speech.

A 34.8-second synthesized speech fixture through actual Parakeet final chunks
retained the names, $12,000 budget, negated approval, and concluding decision.
This is not a representative meeting-accuracy benchmark.

Installed 0.6.66 build 99 was started through its real meeting capture UI and
stopped using Stop & Transcribe. Completion returned enabled recording/export/
summary controls and the full synthetic script on the system-audio track.
The microphone captured room audio as well; do not score that mixed recording
as a clean recognition benchmark. No retained WAV or automatic export was enabled.

## Explicit limitations / follow-up

- A paced real-model preview soak is required before publication; record its
  outcome separately. It does not reproduce Zoom plus microphone/system capture
  on the tester's hardware and cannot establish a fan-noise fix by itself.
- Full meeting capture is still held in memory; incremental checkpoints remain
  separate work requiring deliberate retention/privacy design.
- Sample coverage is not a guarantee of word accuracy. No word-timestamp-based
  overlap reconciliation is included; representative recordings are still needed.
- Existing silence rejection, source-overlap removal, model error reporting,
  approximate sentence timestamps, and summary fallback require further audit.
- No cloud integration, model replacement, or unsupported accuracy claim.
