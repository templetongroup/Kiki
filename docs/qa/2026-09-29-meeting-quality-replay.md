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

## Further acceptance checks — still unreleased

Both independent fixtures passed together under the v32 candidate using the installed 20B engine. The warehouse case retains both actual commitments, resolves the late scope correction, excludes the cancelled courier, and renders without omissions. The independent handover case retains pricing, equipment inventory, and the correct credential/MFA prerequisites without inventing a purchase. These passes do not supersede the failed real-meeting gate.

The fresh six-part private replay failed: it accepted a proposed purchase, mishandled the scope of a real report, and produced two empty section drafts after misinterpreting the excerpt numbering. The excerpt instructions now explicitly identify the supplied text as an already bounded excerpt. Action reconstruction is being tested against original focused speech rather than a misleading first-pass task paraphrase. A diagnostic comparison also found correct scope interpretation in a short unconstrained answer but incorrect interpretation in the longer verification contract; rigid formatting alone did not account for the failure.

Application-level safeguards now serialize summary jobs across both readers and exclude concurrent meeting recording/final transcription. Native cancel/retry checks passed again after rebuilding. Local-engine generation attempts release their model on success, failure or cancellation, rather than deliberately retaining its large working set for the next recording. This release behavior still needs its runtime acceptance check; no fan or thermal improvement is claimed.

The candidate Settings → Models page now exposes summary-engine selection, on-device scope, model-download size, memory requirements, and an Open Ollama action. Native light/dark captures exist at three window sizes; the minimum-width light Models capture was inspected. Public 0.6.69 remains unchanged. No summary engine is promoted to a validated default, and no newer quality release is authorized by the current test results.

## Persistence and two-stage interpretation checks

Summary replacement now atomically writes history before reporting success or replacing the capture reader. An isolated native diagnostic passed successful save/reopen, rejection of stale-source replacement, simulated write failure without changing previous notes, and two history-reader cancel/retry cycles with byte-identical saved data. The existing capture-reader cancellation diagnostic passes in the same rebuilt bundle. Recording startup and final transcription also keep the workbench close guard active; a failed capture start no longer clears the prior transcript from the reader.

The rebuilt candidate passed the actual Parakeet boundary integration again: both synthetic boundary-spanning sentences, including a dollar amount and negation, were preserved exactly once. Audio-pipeline and meeting post-processing regressions passed. Original audio for the private failure meeting remains unavailable, so these checks do not establish a real-meeting accuracy improvement.

Action review now separates an unconstrained source interpretation from structured formatting. In focused tests, the already installed larger model retained the corrected aggregate report and pricing request and rejected a routine conditional-service explanation. The smaller model initially rejected the polite request; clarification that accepted modal requests do not require the exact words “I will” restored the requested total in its focused test, while the conditional-service rejection also passed. The purchase, administrator sequence, independent fixtures and complete fresh replay still require acceptance. A third non-private fixture distinguishes polite accepted requests, genuine approval-dependent commitments, routine conditional services and unapproved suggestions. No private inference is sent off-device.

A separate, explicitly reviewed recovery note was saved in the user's Obsidian meeting folder using both existing transcripts. Originals are unchanged. This recovery is not an automatic-engine pass or a product-quality claim.

The native cancellation diagnostic subsequently passed with an actual loaded Qwen model: Cancel Summary interrupted inference, restored controls and the prior notes, and the model disappeared from Ollama's loaded-model list. This verifies cancellation cleanup, not thermal behavior during a Zoom meeting. The runtime-only model selector used by this diagnostic does not change saved user preferences.

The smaller-model full independent run still failed the handover case: it correctly stated the access procedure as a key point but omitted it from next steps. Its fact reviewer also rejected several supported claims. A duplicate-delivery regression was found separately: an appended “no purchase approved” qualifier was counted as a purchase operation, preventing two versions of the same email task from collapsing. That operation classifier is repaired and the new regression passes. Neither a structural repair nor a warehouse-only pass establishes summary acceptance.

An evaluation-only compact 6-bit copy was prepared from the already installed higher-precision model, approximately 7.36 GB on disk. The duplicate temporary import was checksum-verified against its imported blob and removed; original model weights were not removed. This model is restricted to explicit local evaluation and is not exposed as a consumer default. It is undergoing the same independent tests. No Work MBP model installation, private hosted inference or new release has occurred.
