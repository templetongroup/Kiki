# September 29: current meeting pipeline fails real-meeting replay

Status: **FAILED — not approved for publication.** No installed app or meeting history was modified by this evaluation.

## Scope

Evaluated the September 29 user-authorized private export using the production generator on `codex/meeting-summary-reliability` at `35402b9`. This is the unpublished candidate, not the installed 0.6.68 hotfix. The saved transcript has 959 entries. Private transcripts, generated notes and competing-product output remain outside Git.

## Executed checks

- `bash scripts/test-meeting-summary.sh`: all existing checks pass. These tests establish structural properties, not semantic quality.
- `bash scripts/test-meeting-summary.sh --evaluate "$PRIVATE_MEETING_EXPORT"`: local Apple Intelligence processed all 11 parts and produced a final overview, key points and actions. Completion is not a pass.
- A separate diagnostic compiled the actual `MeetingTranscript` and `MeetingSummaryGenerator` sources. It restored the export, submitted its known-bad notes to `normalizeForDiagnostics`, and replayed an observed duplicated request through `deduplicatingSourceOverlap`. Both assertions failed: bad notes were accepted and the duplicate remained. The original export was not modified.

## Manual review of the completed candidate output

1. Invents a deadline not stated in the supporting passage.
2. Converts conditional security proposals and historical work into current action items.
3. Assigns misleading owners and reverses requester/recipient relationships.
4. Attaches unrelated but valid source entries to tasks. Range-valid evidence IDs are not evidence of support.
5. Preserves earlier statements alongside later corrections without reconciling them; reverses an important administrative-control preference and misstates equipment totals.

The earlier opening-chatter export matches the old extractive fallback: first two transcript entries as summary, first five as key points, and the first six keyword-matched entries as actions. The 0.6.68 hotfix removes that fallback. It does not establish that model-generated notes are reliable.

## Transcription boundary

The meeting pipeline labels the microphone track `You` and the entire system-audio track `Speaker 1`. This is channel attribution, not identification of individual remote speakers. Text-based duplicate suppression is not acoustic echo cancellation. An observed near-duplicate still survives the candidate filter. Do not loosen deletion thresholds without tests preserving genuine repeated speech, negations, numbers, and different speakers' commitments.

No WAV files were found in Kiki's standard meeting archive on the Work MBP during this check. This is not proof that no recording exists elsewhere. No new acoustic accuracy result is claimed. A transcript replay cannot establish a speech-model improvement.

## Required next engineering work

Replace the current unvalidated summary approach with an evaluated candidate that distinguishes current commitments, proposals, historical work, and in-meeting navigation; reconciles corrections across sections; and checks semantic evidence rather than only headings and source-ID validity. Test on held-out meetings as well as this failure case. Do not treat a longer output as higher quality.

For transcription, establish a retained, consented two-channel audio evaluation before changing capture, suppression, timing, or model defaults. Preserve raw recordings and originals during evaluation. The current published build and this candidate must not be described as Granola-equivalent or reliable for important meetings on the basis of these tests.

## Implemented changes and regression checks (same-day continuation)

- Parakeet final meeting recognition now receives 1.5 seconds of audio context at each core boundary. Acoustic word midpoints assign context words to the appropriate core; missing or inconsistent timing triggers a core-only retry rather than silent text removal.
- Unfinished clauses spanning adjacent cores are rejoined. The actual candidate executable passes `bash scripts/test-meeting-boundary-integration.sh`: two synthetic sentences split at hard boundaries are saved once and complete, retaining amounts and negation. This is a synthetic boundary regression, **not a real-meeting word-accuracy score**.
- The published capture-reader hotfix is merged into this branch. The rebuilt candidate passes `bash scripts/test-capture-reader.sh` at 820, 960 and 1200 point widths, reaching both the summary beginning and transcript end. The existing saved-reader test also passes.
- Summary grounding tests reject opening-fragment substitutes, invented dates/numbers, unrelated quotes, and the narrow case of promoting a quoted possibility into an approved plan. Exact source quotation alone is not semantic validation.
- An optional, loopback-only local-model backend is under evaluation. It is not enabled by default and has not been installed on the Work MBP. No private meeting material is sent to a cloud model or committed to Git.

Two direct full-transcript Qwen 9B runs failed manual review: missing late actions, unreconciled late answers, and proposal-to-decision errors. Quote filtering also discarded useful material when a combined claim cited only one of its supporting passages. A bounded section-by-section implementation with chronological reconciliation and multiple supporting quotes is now being evaluated. Its source-partition tests verify every entry is retained, including the last; that does not establish semantic quality. Release remains blocked on actual output quality.

The diagnostic candidate is locally built and ad-hoc signed only. No new version has been published or substituted for the installed 0.6.68 app during these checks.
