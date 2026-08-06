# Kiki

<p align="center">
  <img src="Assets/kiki-portrait.png" alt="Kiki dog portrait" width="560">
</p>

A personal voice-dictation menu bar app for macOS — hold a key, speak, release, and the transcription is typed into whatever app you're using. Fully local: audio never leaves your Mac.

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

## Usage

- **Hold Right ⌥ (Option)** — record while held, transcribe and insert on release. Change the hold key in Settings.
- **⌃⌥D** — toggle mode: press to start, press again to stop and insert.
- System audio is silenced while recording by default, then restored exactly when recording stops. This can be disabled in Settings.
- A branded HUD shows Listening / Transcribing and, with Parakeet, a low-latency live transcript. The preview can be disabled in Settings.
- The Kiki menu bar icon provides status and controls (settings, model info, models folder, quit).

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
3. Launch Kiki and grant two permissions when prompted:
   - **Microphone** — to record you.
   - **Accessibility** — to see the Right-⌥ hotkey globally and to synthesize the ⌘V that inserts text.

   If insertion doesn't work, check System Settings → Privacy & Security → Accessibility and make sure Kiki is enabled. Local builds use a stable self-signed certificate after running the one-time setup command, so permission grants survive rebuilds more reliably.

Public releases must use an Apple-issued Developer ID certificate and notarization. See [Signing and distributing Kiki](DISTRIBUTING.md) for the complete local and GitHub release workflow.

## How it works

`HotkeyManager` (Carbon global hotkey + NSEvent modifier monitors) → `AudioRecorder` (AVAudioEngine, resampled to 16 kHz mono) → `ParakeetTranscriber` (FluidAudio/Core ML) or `WhisperTranscriber` (whisper.cpp/Metal) → `TextInserter` (pasteboard + synthetic ⌘V, previous clipboard restored).

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
```

## Notes on the vendored whisper.cpp

`Vendor/whisper.cpp` is v1.7.2 — the last release with a source-build SwiftPM package. One local patch: the Metal shader resource uses `.copy` instead of `.process` so the project builds with Command Line Tools alone (no Xcode); ggml compiles the shader at runtime instead (see `MetalResources.swift`).

FluidAudio is pinned to v0.15.5 and licensed under Apache 2.0. NVIDIA's Parakeet TDT v2/v3 model weights are distributed under CC BY 4.0; Kiki should preserve model attribution in public distributions.

## Feature ideas

- Press Esc while recording to cancel
- Custom vocabulary / initial prompt for names and jargon
- AI cleanup pass (punctuation, filler-word removal) before insertion
- Per-app formatting rules; history window of past dictations
- Launch at login; configurable hotkeys UI
