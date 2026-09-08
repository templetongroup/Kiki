# Kiki

[![License: MIT](https://img.shields.io/badge/License-MIT-6D7B62.svg)](LICENSE)

<p align="center">
  <img src="Assets/kiki-portrait.png" alt="Kiki dog portrait" width="560">
</p>

A personal voice-intelligence menu bar app for macOS — dictate anywhere, capture meetings, and create speech in your own voice. Fully local: audio never leaves your Mac.

Built with Swift/AppKit, [FluidAudio](https://github.com/FluidInference/FluidAudio), and [whisper.cpp](https://github.com/ggml-org/whisper.cpp). Parakeet runs through Core ML on Apple Silicon; Whisper runs through Metal and remains available as a compatibility fallback.

## Local models

Choose and download a model from **Settings → Models**. All inference stays on your Mac.

| Model | Best for | Hardware | Approx. download |
| --- | --- | --- | ---: |
| Parakeet TDT v2 | Best English speed/accuracy balance | Apple Silicon | ~500 MB |
| Parakeet TDT v3 | Fast multilingual dictation (25 European languages) | Apple Silicon | ~500 MB |
| Whisper Large v3 Turbo | Maximum Whisper accuracy | Apple Silicon or Intel with ample memory | ~1.5 GB |
| Whisper Small English | Balanced compatibility fallback | Apple Silicon or Intel | ~465 MB |
| Whisper Base English | Older or memory-constrained Macs | Apple Silicon or Intel | ~142 MB |

Kiki recommends Parakeet TDT v2 on Apple Silicon and Whisper Small English on Intel. Models download only when selected and can be changed later.

## Features

- Fully local dictation into any Mac app, with hold or hands-free shortcuts and a live listening display
- **Transcripts**: recent text history, meeting recording with microphone and Mac audio, and audio-file imports
- Editable transcripts with copy and export, source labels, speaker editing, and optional meeting-folder auto-export
- **Words & Replacements**: explicit spelling replacements, approved legacy rules, optional context vocabulary, and voice snippets
- **Guided start**: an orientation home explains setup, the menu-bar workflow, the shortcut, and the first dictation
- **Settings**: microphone, shortcuts, speech style, local engines, privacy, updates, and troubleshooting
- Exact Undo Last Dictation, Retry Last Dictation from memory, Escape to cancel, and Private Session
- Private-app exclusions, secure-field protection, signed automatic updates, and sanitized support bundles

Kiki does not upload recordings, transcripts, dictionary entries, or history. Dictation audio is used in memory and is not added to history. Meeting audio is saved only when requested.

## Usage

- Hold your configured shortcut in a text field, speak, and release to insert. **⌃⌥D** also toggles hands-free recording. Change the shortcut in **Settings → Dictation**.
- Press **Esc** to cancel a recording. Use the menu-bar **Undo Last Dictation** or **Retry Last Dictation** actions for recovery.
- Open **Transcripts → Recent** to review saved text; **Record** to capture microphone and Mac audio; or **Import Audio** to transcribe a file.
- Open **Words & Replacements → Replacements** to enter an exact replacement. Existing dictionary entries and approved rules are shown together. Kiki does not monitor your edits or create a learning inbox.
- **Vocabulary** imports names and terms only from sources you choose. **Snippets** insert saved text when a dictation exactly matches a trigger; templates support `{{date}}`, `{{time}}`, and `{{clipboard}}`.
- Use **Start Private Session** in the menu bar to pause dictation history until you end the session or quit. Add private apps with the chooser in **Settings → Private Apps**.
- The listening orb uses a native Metal port of OrbKit's MIT-licensed SHDR-21 Nimbus renderer, recolored for Kiki and driven by idle, thinking, and speaking states.
- Use **Help → Troubleshoot Dictation** to test microphone, permissions, model, shortcut, and insertion. **Help → Create Support Bundle…** exports allowlisted technical details without your content.

### Focused in 0.6.51

Kiki opens to a concise Home guide so a new user knows how setup, the menu bar, the shortcut, dictation, meetings, and audio import fit together. Voice cloning, Pawprints usage tracking, background confidence comparisons, and passive correction learning are not part of the product. Models live in Settings; meeting capture and file import share Transcripts. Previously saved transcripts, dictionary entries, and approved rules are preserved; retired data files are not erased.

### Performance design

The normal path is record → local speech model → explicit text rules → paste. Finished recordings use an ordered in-memory queue, so a new recording can start while the previous transcription finishes. Optional context vocabulary uses a token index. No second-model auditing or passive edit observation runs after insertion.

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

Finished recordings enter an ordered in-memory job queue, allowing the next recording to start immediately. `TranscriptPostProcessor` applies snippets, approved corrections, and indexed context vocabulary synchronously; Private zones skip history and optional contextual processing.

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

## License

Kiki's original source code is open source under the [MIT License](LICENSE). Third-party software and model weights remain subject to their respective licenses; see [Third-Party Notices](THIRD_PARTY_NOTICES.md).

The Kiki and Templeton Technologies names, logos, and other brand assets are not licensed for use as trademarks by the MIT License.

## Feature freeze

Public-release scope is frozen. New product ideas stay out of the release branch until the signed, notarized, updater-delivered build passes the source, packaged-app, installed-app, permission, shortcut, dictation, export, privacy, and control-click gates in `PUBLIC_RELEASE_CHECKLIST.md`.

### Layout correction in 0.6.52

Setup step numbers are centered inside their badges. The Home meeting description now matches transcript editing and export.
