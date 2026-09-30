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

## Focus-scope and workflow correction — v57 candidate

The compact model still failed the handover and modal-request tests. Its imported model was missing explicit chat-renderer/parser metadata; these were corrected using the installed runtime's Ornith renderer, reusing the same weights. That correction did **not** eliminate an invented prerequisite or an unrelated task substitution. It is not an accepted summary engine.

Action review now requires the returned source references to remain anchored to the original focused exchange. A substituted task raises a failure rather than replacing saved notes. Ordered-workflow quotations are filtered against the original focused topic so overinclusive references cannot append unrelated commitments. Instructions distinguish prerequisites within agreed work from hypothetical new requests, and prohibit inferring unspoken prerequisite steps. Source-scope and overinclusive-workflow unit regressions pass; the independent modal test additionally rejects an invented requirement that the recipient supply underlying data first.

The installed 20B model passed four focused original-speech checks: the narrowed overall-total request without an invented dependency, rejection of a routine hypothetical service, publication only after the named reviewer's approval, and recipient password/MFA before administrator access. The complete three-fixture quality suite is running; focused passes do not replace that suite or the complete private-meeting replay.

The rebuilt v57 native preview passed capture-reader reachability at three widths, cancel/retry with unchanged notes, and isolated history save/reopen, stale-source rejection and simulated write-failure preservation. A diagnostic-launch script failure under macOS's bundled Bash 3 was repaired: its optional argument no longer expands an empty array under nounset. The public installed app and release remain 0.6.69. No private hosted inference or new quality release occurred.

The complete v57 warehouse run failed because extraction placed numerous unrelated topics into one oversized point. The application rejected that point rather than saving it. The response grammar had been supplied without also presenting the JSON schema in the model's instructions. The v58 transport supplies both the schema instruction and the syntax constraint, and extraction explicitly requires one topic per key point. Diagnostic cache identity includes that transport revision. Malformed note responses now report that saved notes and the transcript remain unchanged rather than exposing a generic decoding error.

The complete v58 warehouse case passed with the stronger local engine: both correct follow-ups and their roles/timing survived, the cancelled courier was excluded, and the later contract correction was preserved. Its handover and modal cases remain in progress. Additional test checks reject reversed key-point sender/recipient roles and invented doubt about an explicitly checked account correction. Structural unit tests and script syntax checks pass. No complete real-meeting or cross-machine quality acceptance is claimed by this single-fixture result.

## Subsequent action-record failures and source safeguards

The v58 complete run passed warehouse and handover but failed the modal case by substituting agreement delivery for approval-dependent publication. The narrower-evidence v59 run retained those three topics but omitted the report recipient and explicit total scope in task text. The role-field v61 run still substituted the related document task. None passed the full three-case gate.

Action records now carry explicit owner and recipient fields; missing named roles can be rendered from those fields only when the cited source contains the exact party name. Substrings and audio-channel labels cannot stand in for people. Ordered-quotation fallback also requires a dependency in the original focused exchange, so a nearby publication condition cannot replace a simple delivery task. Unit regressions cover these invariants.

The v63 extraction combined document delivery and publication and incorrectly promoted the reviewer's conditional approval into a separate promise. The source-promise recall guard was also limited by a verb whitelist, excluding “publish” and “elevate.” The v65 candidate removes that whitelist (excluding only narrow conversational transition phrases), reviews literal promises separately when generated records conflate multiple promises, and rejects assigning a conditional prerequisite to its speaker when the future predicate explicitly belongs to another person. New promise-recall and conditional-owner tests pass. Integrated tests and the complete private replay still determine acceptance; these rules are safeguards, not a substitute for semantic review.

## Full three-case pass and real-meeting role failures

The complete independent suite passed all three cases under v64 and again under the final v65 executable. This includes late corrected scope, named recipients, credential/MFA ordering, rejected proposals, and distinct delivery/publication commitments. It is not real-meeting acceptance.

The six-section private replay subsequently failed on anonymous model role placeholders. Normalizing anonymous roles let it continue, but a later inventory task used a role not literally supported by its cited exchange. A single invalid role had been aborting the entire summary. The v67 candidate instead preserves the cited original follow-up with an explicit “role needs review” label; it does not save the guessed name. Invalid source references still fail rather than manufacturing evidence. Proposed-task text also strips generic audio-channel labels before inference. Unit regressions pass for anonymous/group roles and the literal, topic-specific fallback. The complete private replay remains in progress.

Live microphone preview is now explicitly optional and off by default. Previously it repeatedly decoded overlapping twelve-second snapshots while recording. A rebuilt native artifact passed the policy test: preview-off makes zero calls to the live-inference factory, while preview-on reaches that factory. Capture cancellation, isolated history save/reopen and failure preservation also pass. The actual selected artifact passes capture-reader reachability at 820, 960 and 1200 points; its rendered capture page was inspected. The reader script now accepts an explicit artifact path and cleans its own diagnostic image. This establishes the code path, not measured Zoom fan/thermal improvement or real-meeting acoustic accuracy. No new public release or model default has been promoted.

## Reassessment: isolated reviews still fail

The complete v67 real replay reached all 31 action checks and ten point checks but failed the overview grounding gate. Manual inspection of its retained diagnostic draft also found an unapproved backup plan, repeated deliveries, a hypothetical service step promoted into a task, and incomplete workflow wording. It is not an accepted summary.

The reviewer had moved focused statements ahead of preceding conditions. Chronological source ordering and honoring the interpreter's final negative classification were tested next, with a multi-sentence conditional-service regression added. The expanded v70 run passed warehouse and handover, but failed the polite request's final scope: a role fallback retained only the acceptance sentence and lost the narrowed total request. These changes do not establish semantic acceptance. The subsequent redundant private replay was stopped at that known failure.

The next diagnostic reassesses the architecture: the installed stronger model reads the entire original spoken transcript in one 32K-token context, rather than reconstructing it from isolated claim windows. Generic audio-channel labels and literal clock prefixes are excluded from inference, but every original spoken entry, its chronology and global citation number are retained; saved data and rendered citations are unchanged. This path is evaluation-only and not a consumer default. Requests disable prompt truncation and context shifting, as supported by the installed Ollama 0.34.4 API. The first full-context run processed 15,890 input tokens but exhausted its 6,000-token response allowance, so no incomplete summary was saved. The bounded allowance was raised to 10,000 tokens for the next evaluation; that result still requires review and independent tests. Local diagnostic response files remain outside Git. Unit checks and native compilation pass; no real-meeting, thermal or acoustic-quality acceptance is claimed.

## Whole-context runtime and semantic failures

The next loader blocked in memory mapping despite ample available memory. A diagnostic-only no-mapping option bypassed that loader failure; it is not a validated consumer memory policy. Medium reasoning at greedy sampling still exhausted 10,000 response tokens without final notes. A compact alternative's complete-context request timed out after ten minutes.

Publisher sampling with low reasoning produced a complete 20B draft in 107 seconds, but manual review rejected it: proposals became tasks, corrected scope was lost, identities and account classifications were inferred, and substantive middle topics were missing. A second pass against all original speech also failed; it reinforced unsupported decisions and omitted an actual requested deliverable. Neither result is acceptable merely because JSON is valid. A separate whole-source test of the already installed 9B model is in progress, using its non-thinking general-task sampling configuration.

Local-engine preflight now checks installed-model metadata before sending transcript content. A localhost address alone does not prove inference is local: remote aliases and missing local metadata are rejected. Structural tests cover these checks, and the complete summary unit suite passes. Quality fixtures now also require named recipients and reject reversed delivery/publication roles. Evaluation cache identity distinguishes sampling and mapping configurations. No new model default, installed app, public release or private hosted inference has been promoted.

The 9B full-source draft/revision completed but is not accepted: an actual deliverable was missing, an equipment request was duplicated, credential prerequisites were incomplete, and proposals became settled policy. Rendering marked omitted evidence as an incomplete draft; a zero exit code is not semantic acceptance. A separate diagnostic now extracts actions directly from all original speech without using generated tasks as input. This is an architectural evaluation, not a shipped fallback.

The latest native preview initially failed to launch because the newly copied debug binary lacked its bundled framework search path. Adding that path and re-signing the isolated preview corrected packaging. The rerun passed immediate cancel/retry with unchanged notes, the zero-live-inference low-power policy, isolated history persistence/reopening and rejected stale/write-failed updates, and capture-reader reachability at three widths. No inference was started by this immediate-cancellation check. The selected local-engine unit suite also passes. The installed public app was not replaced.

## Additional model comparisons and actual edit/save defects

Separate full-source action extraction recovered an omitted report but still lost narrowed scope, omitted the agreed access workflow, and duplicated inventory work. A 20B medium-reasoning/publisher-sampling draft also failed semantic review, introducing company-history and ownership claims; its redundant action stage was stopped. A different installed 24B diagnostic was stopped on resource suitability: its Home-Mac engine allocation was about 19.6 GB and generation about 6.3 tokens/second. This is not an actual Work-Mac benchmark or a completed accuracy test.

The compact 9B thinking-mode full-meeting run completed in 6 minutes 48 seconds but omitted two required follow-ups. Direct Markdown comparisons without source-ID generation also failed under the installed 20B and 30B alternatives: false scope/owners, invented tasks/timing, incomplete prerequisites and topic omissions persisted. These comparisons remain diagnostic-only; valid sections, rendered output and zero process exit status do not establish accuracy. No successful real-meeting summary engine is claimed.

Two independent production data-flow defects were fixed in the candidate. Capture-window revisions now use expected-source checks before changing displayed state, so another surface's newer notes cannot be overwritten. Speaker edits also report persistence failures rather than claiming success. Visible transcript edits are now synchronized before Summary, Copy, Export and Identify Speakers instead of using the obsolete in-memory transcript. The edited Markdown is retained verbatim, summary refresh preserves its transcript bytes, and ordinary word corrections retain precise original audio timing and record identity. Malformed edits remain visible and cannot silently replace a saved meeting. Speaker updates cannot overwrite text edited while their separate window was open.

Unit regressions pass for edited inference source, exported speech, exact transcript preservation, prior notes and precise timing. The rebuilt isolated native preview passes edit-to-summary synchronization, cancellation preserving corrections, malformed-edit rejection, capture save/reopen and stale/write-failed save protection, low-power preview policy and three-width reader reachability. These fix concrete save/edit defects, not semantic model quality. Public release remains 0.6.69; private source files and saved user meetings were not overwritten. The next local comparison uses one additional general-purpose 27B model after checking Home-Mac disk capacity. Existing weights are preserved. No Work-Mac suitability is inferred, and hosted inference still requires explicit privacy approval.
