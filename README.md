# Kiki

<p align="center">
  <img src="Assets/kiki-portrait.png" alt="Kiki dog portrait" width="560">
</p>

A personal voice-intelligence menu bar app for macOS — dictate anywhere, capture meetings, and create speech in your own voice. Fully local: audio never leaves your Mac.

Built with Swift/AppKit, [FluidAudio](https://github.com/FluidInference/FluidAudio), and [whisper.cpp](https://github.com/ggml-org/whisper.cpp). Parakeet runs through Core ML on Apple Silicon; Whisper runs through Metal and remains available as a compatibility fallback.

## Local models

Choose and download a model from **Settings…**. All inference stays on your Mac.

| Model | Best for | Hardware | Approx. download |
| --- | --- | --- | ---: |
| Parakeet TDT v2 | Best English speed/accuracy balance | Apple Silicon | ~500 MB |
| Parakeet TDT v3 | Fast multilingual dictation (25 European languages) | Apple Silicon | ~500 MB |
| Whisper Large v3 Turbo | Maximum Whisper accuracy | Apple Silicon or Intel with ample memory | ~1.5 GB |
| Whisper Small English | Balanced compatibility fallback | Apple Silicon or Intel | ~465 MB |
| Whisper Base English | Older or memory-constrained Macs | Apple Silicon or Intel | ~142 MB |

Kiki recommends Parakeet TDT v2 on Apple Silicon and Whisper Small English on Intel. Models download only when selected and can be changed later.

## Features

- Fully local dictation with a choice of Parakeet and Whisper models
- Low-latency live transcript in Kiki's branded listening window with Parakeet
- Customizable global shortcut with hold-to-dictate and press-to-toggle modes
- Launch at login, signed automatic updates, light/dark/system appearance, brand colors, and dictation sounds
- Custom dictionary for names, jargon, abbreviations, and exact spellings
- Text-only transcription history with app/source, model, duration, and an explicit local-processing indicator
- Drag-and-drop local audio-file transcription with editable, copyable, and exportable results
- Automatic Mac output muting during recording, with the previous mute or volume restored afterward
- Zero-wait dictation chaining: begin the next recording while the previous final pass finishes
- Caret-following live preview that stays near the place where text will be inserted
- Kiki Learns You: local correction suggestions with global or per-app approval
- Optional local vocabulary imports from Contacts, upcoming Calendar events, and project folders
- Deterministic voice snippets with `{{date}}`, `{{time}}`, and `{{clipboard}}` variables
- Private-app zones and automatic secure-field protection that skip history, learning, and verification
- Standard, disfluency-assist, verbatim, and soft-speech accessibility profiles
- Optional background confidence verification using an installed Whisper model after the primary result is pasted
- Offline Meeting Mode with separate microphone/system-audio tracks, local source labels, chapters, action-item hints, and Markdown/TXT/SRT/WebVTT export
- Voice Studio with guided voice enrollment, a fully local Qwen3-TTS engine, on-device text-to-speech, playback, and WAV/M4A export
- Kiki Checkup with microphone selection, a live input meter, permission/model readiness, shortcut verification, and a guided first dictation
- Exact Undo Last Dictation plus Retry Last Dictation using only the most recent in-memory recording
- A transient Private Session that disables history, correction learning, confidence verification, and Pawprints without disabling in-memory undo
- Read Selection in My Voice, which prefills Voice Studio for review and waits for an explicit Generate click
- Opt-in Pawprints with aggregate-only local usage totals, Private Session exclusion, and complete reset
- Sanitized support bundles containing only allowlisted technical configuration and readiness fields

Kiki does not upload recordings, transcripts, dictionary entries, or history. Microphone audio is used in memory for transcription and is not added to history.

## Usage

- **Hold Right ⌥ (Option)** — record while held, transcribe and insert on release. Change the hold key in Settings.
- **⌃⌥D** — toggle mode: press to start, press again to stop and insert.
- System audio is silenced while recording by default, then restored exactly when recording stops. This can be disabled in Settings.
- A branded HUD shows Listening / Transcribing and, with Parakeet, a low-latency live transcript. The preview can be disabled in Settings.
- Press **Esc** while recording to cancel without transcribing or saving anything.
- Quick successive dictations can continue the same paragraph, and Kiki can accept another recording while the previous one finishes.
- Use **Dictionary…** to teach Kiki your preferred spellings and replacements.
- Use **Personalization Studio…** to approve learned corrections, import context vocabulary, create voice snippets, manage private apps, and review confidence disagreements.
- Use **History…** to review, copy, or delete locally stored transcript text.
- Use **Undo Last Dictation** only while Kiki can verify the exact text and caret it inserted. **Retry Last Dictation** reprocesses the same recording from memory; recordings are never written to disk for this feature.
- Use **Start Private Session** for work that should not appear in history, learning, confidence review, or Pawprints. Private Session ends when you turn it off or quit Kiki.
- Use **Kiki Checkup…** to choose the actual input device, confirm a live signal, test the shortcut, and complete a real first insertion.
- Use **Pawprints…** to opt into aggregate-only local totals or permanently reset them.
- Highlight text in an accessible app and choose **Read Selection in My Voice** to place it in Voice Studio. Kiki never starts generation without the Generate button.
- Use **Create Support Bundle…** when troubleshooting. The ZIP excludes transcripts, recordings, clipboard contents, names, vocabulary, contacts, and file paths.
- Use **Transcribe File…** to drop an audio file, edit the result, copy it, or save it as plain text.
- Use **Meeting Mode…** for longer local sessions. Microphone speech is labelled “You” and Mac system audio is labelled “Others”; headphones produce the cleanest source separation.
- Use **Voice Studio…** to record one private reference passage, download the optional 2 GB local voice engine, and turn typed text into speech in your voice. Generation works offline after the one-time model download.
- The Kiki menu bar icon provides status, settings, model controls, update checks, and local transcription tools.

### Performance design

The normal dictation path remains record → local speech model → deterministic text rules → paste. Learning observation happens after paste, confidence verification runs on a utility queue, and meeting capture uses a separate pipeline. Context vocabulary is token-indexed; the built-in benchmark averages single-digit milliseconds on the development Mac even with 2,002 terms.

## Setup

1. Build the app:
   ```bash
   ./scripts/setup-local-signing.sh  # one-time; keeps macOS permissions stable
   ./scripts/make-app.sh
   cp -R build/Kiki.app /Applications/
   ```
2. Launch Kiki and choose a model in **Settings…**. Whisper models can also be downloaded manually to `~/Library/Application Support/Kiki/models/`:
   ```bash
   ./scripts/download-model.sh large-v3-turbo   # ~1.6 GB, recommended
   ./scripts/download-model.sh base.en          # ~142 MB, fast but weaker
   ```
3. Launch Kiki and grant two permissions required for normal dictation:
   - **Microphone** — to record you.
   - **Accessibility** — to see the Right-⌥ hotkey globally and to synthesize the ⌘V that inserts text.

   Optional features request their own permission only when used:
   - **Contacts** — imports names only into local context vocabulary.
   - **Calendars** — imports upcoming titles and attendee names only.
   - **Screen Recording** — lets Meeting Mode capture Mac system audio locally.

   If insertion doesn't work, check System Settings → Privacy & Security → Accessibility and make sure Kiki is enabled. Local builds use a stable self-signed certificate after running the one-time setup command, so permission grants survive rebuilds more reliably.

Public releases must use an Apple-issued Developer ID certificate and notarization. See [Signing and distributing Kiki](DISTRIBUTING.md) for the complete local and GitHub release workflow.

Kiki uses [Sparkle](https://sparkle-project.org/) for cryptographically signed automatic updates. Contributors can install the pinned Sparkle framework and publishing tools with `./scripts/setup-sparkle.sh`; release maintainers then update the signed feed with `./scripts/update-appcast.sh` after creating a notarized archive. The private update key remains in the maintainer's macOS Keychain and is never committed.

## How it works

`HotkeyManager` (Carbon global hotkey + NSEvent modifier monitors) → `AudioRecorder` (AVAudioEngine, resampled to 16 kHz mono) → `ParakeetTranscriber` (FluidAudio/Core ML) or `WhisperTranscriber` (whisper.cpp/Metal) → custom dictionary → optional text-only history → `TextInserter` (pasteboard + synthetic ⌘V, previous clipboard restored).

Finished recordings enter an ordered in-memory job queue, allowing the next recording to start immediately. `TranscriptPostProcessor` applies snippets, approved corrections, and indexed context vocabulary synchronously; correction observation and `BackgroundConfidenceVerifier` run only after insertion. Private zones short-circuit all optional retention and learning.

Parakeet also receives a short-window stream while recording so the HUD can show an immediate, provisional transcript. Kiki discards that preview when recording ends and runs the normal full-audio pass for the text it inserts.

Whisper needs ≥ ~1 s of audio, so short clips are padded with silence; presses under 0.3 s are treated as accidental and discarded. Non-speech artifacts like `[BLANK_AUDIO]` are filtered.

### Config knobs (UserDefaults)

```bash
defaults write com.tonyricciardi.kiki language en      # or "auto", "de", ...
defaults write com.tonyricciardi.kiki model ggml-small.en.bin  # override model choice
```

### CLI test mode

Transcribe a file without the mic (useful for testing changes):

```bash
./build/Kiki.app/Contents/MacOS/Kiki --transcribe-file some-audio.m4a

# Deterministic feature checks and a large-vocabulary latency benchmark
./build/Kiki.app/Contents/MacOS/Kiki --self-test-features
./build/Kiki.app/Contents/MacOS/Kiki --benchmark-postprocessing
```

## Notes on the vendored whisper.cpp

`Vendor/whisper.cpp` is v1.7.2 — the last release with a source-build SwiftPM package. One local patch: the Metal shader resource uses `.copy` instead of `.process` so the project builds with Command Line Tools alone (no Xcode); ggml compiles the shader at runtime instead (see `MetalResources.swift`).

FluidAudio is pinned to v0.15.5 and licensed under Apache 2.0. NVIDIA's Parakeet TDT v2/v3 model weights are distributed under CC BY 4.0; Kiki should preserve model attribution in public distributions.

## Feature freeze

Public-release scope is frozen. New product ideas stay out of the release branch until the signed, notarized, updater-delivered build passes the source, packaged-app, installed-app, permission, shortcut, dictation, export, privacy, and control-click gates in `PUBLIC_RELEASE_CHECKLIST.md`.
