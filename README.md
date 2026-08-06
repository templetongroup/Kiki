# Kiki

<p align="center">
  <img src="Assets/kiki-portrait.png" alt="Kiki dog portrait" width="560">
</p>

A personal voice-dictation menu bar app for macOS — hold a key, speak, release, and the transcription is typed into whatever app you're using. Fully local: audio never leaves your Mac.

Built with Swift/AppKit on top of [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (vendored in `Vendor/`, running on the GPU via Metal).

## Usage

- **Hold Right ⌥ (Option)** — record while held, transcribe and insert on release.
- **⌃⌥D** — toggle mode: press to start, press again to stop and insert.
- A small HUD pill at the bottom of the screen shows Listening / Transcribing.
- The menu bar mic icon shows state and has controls (model info, models folder, quit).

## Setup

1. Build the app:
   ```bash
   ./scripts/make-app.sh
   cp -R build/Kiki.app /Applications/
   ```
2. Download a model (goes to `~/Library/Application Support/Kiki/models/`):
   ```bash
   ./scripts/download-model.sh large-v3-turbo   # ~1.6 GB, recommended
   ./scripts/download-model.sh base.en          # ~142 MB, fast but weaker
   ```
3. Launch Kiki and grant two permissions when prompted:
   - **Microphone** — to record you.
   - **Accessibility** — to see the Right-⌥ hotkey globally and to synthesize the ⌘V that inserts text.

   If insertion doesn't work, check System Settings → Privacy & Security → Accessibility and make sure Kiki is enabled. After rebuilding the app you may need to remove and re-add it there (the ad-hoc signature changes).

## How it works

`HotkeyManager` (Carbon global hotkey + NSEvent modifier monitors) → `AudioRecorder` (AVAudioEngine, resampled to 16 kHz mono) → `WhisperTranscriber` (whisper.cpp, Metal GPU) → `TextInserter` (pasteboard + synthetic ⌘V, previous clipboard restored).

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

## Feature ideas

- Press Esc while recording to cancel
- Streaming/partial transcription while speaking
- Custom vocabulary / initial prompt for names and jargon
- AI cleanup pass (punctuation, filler-word removal) before insertion
- Per-app formatting rules; history window of past dictations
- Launch at login; configurable hotkeys UI
