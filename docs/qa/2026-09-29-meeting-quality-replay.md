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

## Subsequent bounded fixes and independent test

The first sectioned Qwen 9B run also failed: it merged unrelated deliverables, retained superseded claims and took approximately twelve minutes. It is not release evidence. Changes following that failure separate final short-meeting instructions from intermediate section instructions, explicitly require commitments in the actions field, disallow combining unrelated deliverables, and enforce the key-point limit in the output schema.

An additional reproduced application-side filtering bug discarded correct quotations when the model included the original speaker label. The matcher now recognizes labels present in the source and requires every matched entry to belong to that speaker. Positive and wrong-speaker regression tests pass; stripping a label must never permit a match to someone else's speech.

`bash scripts/test-local-summary-quality.sh` now passes with the installed Qwen 9B model on a separate synthetic warehouse meeting. It retains both real commitments and the spoken deadline, excludes cancelled/historical/hypothetical work, resolves the later contract correction, and renders the grounded notes without omissions. The unassigned driver decision may be included as an additional supported task. This is one non-private case, not proof of general reliability. A larger-model draft also renders correctly after the speaker-label fix.

The full private meeting is being rerun with these changes. Intermediate drafts and final output are retained only under `/tmp` for diagnosis. No new claim of real-meeting summary quality is made until that output is reviewed.

## Final same-day disposition

The refined full-meeting rerun still failed. It retained the aggregate-size and pricing follow-ups but lost the administrator-setup and equipment-inventory follow-ups during quotation filtering. It also retained proposals and in-call requests as tasks. The synthetic pass therefore does not justify shipping the engine. A separate focused local-model probe correctly rejected a reversed operation-order claim; this probe is not an integrated semantic-verification stage.

A separate, enabled transcription defect was found and fixed: meeting capture reused dictation post-processing. The affected Mac has Polished Speech enabled, allowing a correction phrase to discard earlier chunk text. Meetings now bypass dictation cleanup, snippets and learned replacements. The new regression fails against the original path and passes under every profile after repair, while dictation behavior remains unchanged. Without the original audio, the amount of prior loss cannot be determined.

Only that isolated preservation repair and the already tested Whisper GPU-resource packaging fix were published as 0.6.69/build 102 from the capture-reader hotfix branch. The experimental summary engine and boundary-context changes remain excluded. Git main, GitHub release, Sparkle feed and Linear reflect the bounded release. The Work MBP accepts the staged signed/notarized artifact and compiles its GPU shader, but the running installed app is not replaced pending safe-restart confirmation. The landing-page publisher requires reauthentication and remains unchanged. Summary reliability remains unresolved.

## Continued source-backed pipeline repair

The Home MBP's installed 0.6.69/build 102 has since been verified; original history data was preserved. That installation did not fix semantic summary quality.

The candidate now retains original source-entry references, audits each distinct section action independently, retrieves related later discussion, and preserves checked deliverables instead of allowing a final prose pass to silently drop them. Topic consolidation selects existing records rather than rewriting tasks. Structural validation rejects unseen citations, empty kept claims and review instructions copied into output. Model output sizes and citation arrays are bounded. A second independent access-handover fixture tests pricing, inventory, a late account correction and password/MFA prerequisites; its model-quality result must be recorded before acceptance.

Executed unit regressions pass for source partition completeness, late corrections, interleaved-response context, valid/invalid evidence, operation-distinct action retention, and unchanged transcript restoration. These establish application invariants, not semantic truth.

Both summary surfaces now offer Cancel Summary. A native-bundle diagnostic passed two cancel/retry cycles, restored the controls and editing state, and preserved the existing summary and full transcript exactly without starting inference. `scripts/test-summary-cancellation.sh` makes this a repeatable artifact check. The installed public app is not yet changed by these candidate edits.

The source-backed Apple Intelligence candidate failed manual review of the complete real meeting: false follow-ups, copied review instructions and unsupported prerequisites. It is not an accepted verifier. The Qwen 9B direct-answer verifier also rejected genuine commitments despite receiving the relevant original speech. Its replay was stopped at that known failure rather than treated as a pass. Reasoning-enabled local verification is being tested on those exact failed passages before another full replay.

A separate interrupted run ended when the Ollama desktop service shut down and subsequently restarted. Logs establish service interruption, not a memory/model crash. Evaluation caches are local, explicit diagnostic-only files outside Git; no private meeting content is uploaded or committed. Production summary generation remains on the old engine pending semantic acceptance and an accessible local-engine setup flow.
