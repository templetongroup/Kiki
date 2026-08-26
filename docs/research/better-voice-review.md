# Better Voice ideas worth adapting into Kiki

Reviewed 2026-08-26 against Better Voice `de3ee61ea2c962c44e33bb438d6e410926fed3aa` (the commit shipped as [v0.1.9](https://github.com/TarunTomar122/better-voice/releases/tag/v0.1.9)) and Kiki `fa37bdb692c0213a97bc67fac897ef3d0aeebfbd` on `codex/live-transcription`.

## Bottom line

Yes. Better Voice has one genuinely differentiated product idea and several smaller reliability ideas worth adapting. Kiki should **not** import the app wholesale: Kiki already has the broader and more mature local voice stack, while Better Voice is an experimental, Apple-Silicon-only build that is not Developer ID notarized ([README](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/README.md#L222-L250)).

The best product idea is an explicit **Visual Context mode**: speak while circling something on screen, then deliver the transcript and the referenced image together. The best low-risk engineering ideas are smarter automatic microphone fallback, safer phrase matching, and more flexible shortcut timing.

## Ranked recommendations

| Rank | Adapt for Kiki | Value | Effort | Risk | Recommendation |
| ---: | --- | --- | --- | --- | --- |
| 1 | Opt-in Visual Context mode | Very high | Large | High privacy/UX | Prototype after the public-release freeze; adapt the idea, not the storage behavior |
| 2 | Automatic microphone selection and disconnect fallback | High | Small | Low | Ship as a reliability improvement |
| 3 | Domain/path-safe dictionary and correction matching | High | Small | Low | Harden Kiki's existing matcher and add regression tests |
| 4 | Adjustable hold delay and optional double-tap activation | Medium-high | Medium | Medium shortcut conflicts | Add behind explicit settings after full installed-app shortcut testing |
| 5 | Visible language picker plus Parakeet script hint | Medium-high | Medium | Medium model/decoder behavior | Add when multilingual UX is reopened |
| 6 | Tiny ONNX grammar model | Low for Kiki | Medium-large | Wording changes/dependency weight | Do not add now |

## 1. Visual Context mode — the idea worth stealing

Better Voice watches pointer movement during recording, recognizes a roughly closed circle, captures the display under the pointer with ScreenCaptureKit, draws a highlight around the referenced area, and pastes the transcript followed by the captured images. The gesture detector is small and testable ([detector](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoiceCore/CircleGestureDetector.swift#L14-L104)); capture and highlight rendering are implemented with ScreenCaptureKit/Core Graphics ([capture](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoice/main.swift#L506-L635)); its clipboard supports text, RTF, PNG, TIFF, and file URLs ([clipboard](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoice/main.swift#L1220-L1298)).

This is a real gap in Kiki. Kiki has dictation, meetings, file transcription, personalization, Voice Studio, and private modes, but no way to pair a spoken instruction with deliberately selected screen context ([Kiki feature inventory](../../README.md#L25-L50)). It could make Kiki materially more useful with coding agents, support tickets, design feedback, and “change the thing I am pointing at” workflows.

Do **not** copy Better Voice's default privacy/storage behavior. It captures the complete display and writes sessions to `~/Desktop/BetterVoice` for up to seven days and 500 MB ([README](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/README.md#L263-L279), [storage](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoice/main.swift#L1001-L1053)). That conflicts with Kiki's stronger normal-dictation promise that microphone audio is memory-only and history is text-only ([Kiki README](../../README.md#L31-L52)).

A Kiki-native version should:

- be a separate, explicitly activated **Visual Context** mode, never silently enabled for ordinary dictation;
- request Screen Recording only when the mode is first used;
- crop to the selected window/region where feasible instead of retaining an entire display;
- keep captures in memory by default, paste them, then destroy them;
- refuse capture in secure fields, private apps, and Private Session by reusing Kiki's existing privacy policy ([`AppContextSnapshot`](../../Sources/Kiki/AppContext.swift#L4-L29));
- display a clear capture confirmation and count;
- use Kiki's current safe delivery rule: if focus moved to another app while transcription finished, copy for manual paste rather than forcibly reactivating the original app ([`DictationController`](../../Sources/Kiki/DictationController.swift#L638-L670)); and
- offer an explicit “Save visual session” action if persistent images are ever supported.

## 2. Automatic microphone fallback — small and immediately useful

Better Voice retains a user's chosen input when present, but its Automatic mode prefers the system-default external microphone, then any external input, then the system default, then any remaining input. If a saved device disappears, it clears the stale preference ([`MicrophoneManager`](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoice/main.swift#L42-L80)).

Kiki already has a visible microphone picker and Checkup meter, but an unavailable preference falls back to the first alphabetically sorted capture device ([`AudioInputDevice.selected`](../../Sources/Kiki/AudioInputDevice.swift#L10-L27)). That is deterministic but not necessarily the user's current system or external microphone.

Adapt the fallback policy and expose **Automatic — Current Device** as the first microphone option. Re-evaluate on device connect/disconnect and show a brief non-blocking notice when Kiki changes inputs. This stays completely local and does not expand permissions.

## 3. Safer dictionary matching — borrow the boundary logic and tests

Better Voice's developer cleanup and user vocabulary treat Unicode letters/combining marks, paths, domains, filenames, underscores, slashes, dots, and hyphens carefully. Its test suite explicitly checks `github.com`, `package.json`, paths, accented words, decomposed accents, and sentence-ending punctuation ([implementation](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoiceCore/DeveloperTextCleanup.swift#L67-L113), [tests](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Tests/BetterVoiceCoreTests/DeveloperTextCleanupTests.swift#L1-L112)).

Kiki's custom dictionary and learned-correction matcher currently use letter/number boundaries only ([custom dictionary](../../Sources/Kiki/CustomDictionaryStore.swift#L50-L66), [learned corrections](../../Sources/Kiki/CorrectionMemoryStore.swift#L177-L189)). A rule for `api` can therefore match inside text such as `api.example` or a path. Kiki should harden both replacement paths and add the same categories of regression tests. This improves the features Kiki already has rather than adding another developer-vocabulary toggle.

Do not import Better Voice's fixed technology-term table by default. Kiki already offers a dictionary UI, imported context vocabulary, and approved global/per-app learning ([`TranscriptPostProcessor`](../../Sources/Kiki/TranscriptPostProcessor.swift#L31-L51)). A global built-in table creates false-positive risk and weakens user control. If desired later, offer an optional “Developer terms” starter pack that the user can inspect and edit.

## 4. Shortcut ergonomics — useful, but port the state machine carefully

Better Voice supports hold, tap-to-toggle, and double-tap-to-toggle activation, adjustable 50–500 ms hold delay, and independent quick-note/long-recording modes ([trigger modes](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoiceCore/RecordingTriggerMode.swift#L3-L65), [input monitor](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoice/main.swift#L1366-L1514)). The latest release specifically fixed Command-only and Command-Option edge cases and added regression coverage ([v0.1.9 notes](https://github.com/TarunTomar122/better-voice/releases/tag/v0.1.9)).

Kiki already provides a customizable hold/toggle shortcut plus the separate fixed `⌃⌥D` hands-free toggle ([`HotkeyManager`](../../Sources/Kiki/HotkeyManager.swift#L4-L10), [`ActivationMode`](../../Sources/Kiki/Settings.swift#L194-L224)). The actual gaps are:

- no user-adjustable hold threshold to reduce accidental activations; and
- no double-tap option for users who cannot comfortably hold a modifier.

Add these only as optional accessibility/ergonomic settings. Modifier-only state handling is deceptively fragile; port or reimplement the upstream tests before changing Kiki's installed shortcut path.

## 5. Multilingual picker and script hint — Kiki has the model but not the complete UX

Better Voice keeps English on Parakeet v2, uses the multilingual model for other languages, and supplies the decoder a script hint so Cyrillic/Greek output does not drift into Latin tokens ([transcriber](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoice/main.swift#L242-L339), [language model](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoiceCore/TranscriptionLanguage.swift#L1-L94)).

Kiki exposes a Parakeet multilingual model, but its batch Parakeet call currently supplies no language hint ([model choices](../../Sources/Kiki/TranscriptionModel.swift#L3-L38), [transcription call](../../Sources/Kiki/ParakeetTranscriber.swift#L53-L61)). `Settings.language` is currently consumed by the Whisper path, not the Parakeet call ([`DictationController`](../../Sources/Kiki/DictationController.swift#L169-L177)). A proper language picker tied to the selected model and decoder hint would make the existing “multilingual” promise more controllable and testable.

## What Kiki already does better; do not duplicate it

- **Personalization:** Kiki already has a GUI dictionary, imported context vocabulary, correction observation, and user-approved global/per-app rules. Better Voice has a hand-edited JSON vocabulary and a fixed developer table.
- **Privacy controls:** Kiki has secure-field detection, private-app zones, Private Session, memory-only retry audio, and sanitized support bundles. Better Voice saves transcript/image sessions to Desktop by default.
- **Breadth:** Kiki includes file transcription, Meeting Mode, confidence verification, exact undo/retry, Voice Studio, signed Sparkle updates, notarized releases, and an installed-app checkup ([Kiki README](../../README.md#L25-L50)).
- **Delivery safety:** Kiki declines to paste into a different frontmost app after transcription and leaves the text on the clipboard; Better Voice posts the paste event back to the captured PID ([Better Voice insertion](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoice/main.swift#L1301-L1362)). Kiki's behavior is safer and should remain the default.
- **Local grammar/polish:** Kiki's deterministic speech profiles, dictionary, and correction learning preserve user control. Better Voice's optional 36 MB T5 grammar model can change wording and intentionally falls back when output is incomplete ([grammar implementation](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Sources/BetterVoice/GrammarCorrector.swift#L20-L88), [model card](https://huggingface.co/rabden/t5-tiny-gec-hone)). Do not add this dependency until an accuracy corpus proves it helps Kiki's users.

## Architecture and dependency assessment

Better Voice is a native Swift 6/macOS 14 app with one executable and a small testable core target. The cleanest reusable units are the gesture detector, shortcut state machines, vocabulary matcher, and retention policy. However, most app/system behavior remains concentrated in a 2,963-line `main.swift`, Settings is a 1,558-line SwiftUI file, and grammar inference is another 300-line file. That is a useful prototype architecture, not a structure Kiki should import wholesale ([repository map](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/docs/ARCHITECTURE.md#L1-L46)).

Dependencies are FluidAudio at a pinned revision, `swift-transformers` 1.3.3, and ONNX Runtime 1.24.2 ([Package.swift](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/Package.swift#L1-L36)). Kiki already uses FluidAudio, so the microphone, gesture, shortcut, and matcher ideas require no new model runtime. The grammar experiment would add Tokenizers, ONNX Runtime, transitive dependencies, downloadable model management, and another inference path; that cost is not justified now.

At upstream head, `swift test -Xswiftc -strict-concurrency=complete` completed successfully with **82 tests and 0 failures**. This gives reasonable confidence in the extracted gesture, shortcut, vocabulary, language, and retention algorithms; it is not evidence that the downloaded app, permissions, screen capture, clipboard delivery, or UI were exercised end to end.

## License and reuse

Better Voice is MIT licensed. Its license permits use, copying, modification, distribution, sublicensing, and sale, provided the copyright and MIT permission notice are included in copies or substantial portions ([LICENSE](https://github.com/TarunTomar122/better-voice/blob/de3ee61ea2c962c44e33bb438d6e410926fed3aa/LICENSE#L1-L21)). Therefore:

- ideas and clean-room Kiki implementations are safe to pursue;
- if Kiki copies meaningful source or tests, add `Copyright (c) 2026 Tarun Tomar` and the MIT text to `THIRD_PARTY_NOTICES.md`, and identify modified files;
- do not reuse Better Voice's name, icon, screenshots, or branding—the license does not make that useful or prudent for Kiki;
- the optional grammar model identifies itself as MIT licensed ([model card](https://huggingface.co/rabden/t5-tiny-gec-hone)), while `swift-transformers` is Apache-2.0 and ONNX Runtime is MIT; those notices would also be required if those dependencies were distributed; and
- keep Kiki's existing FluidAudio/Parakeet attribution obligations intact.

## Recommended decision

1. Implement **Automatic microphone** fallback and **domain/path-safe replacement tests** as focused reliability work.
2. Design **Visual Context mode** as a post-release experiment with memory-only captures and Kiki's private-zone protections.
3. Add adjustable hold delay/double-tap only after a dedicated shortcut regression suite and installed-app permission test.
4. Finish the multilingual language-picker/script-hint UX before adding any grammar model.
