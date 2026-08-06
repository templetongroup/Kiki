# Kiki product roadmap

Kiki studies the user experience of leading dictation products, including FluidVoice, while implementing its own code and product architecture. No GPL source code is copied into Kiki.

## Product principles

- Local-first by default; network features are explicit opt-ins.
- Fast enough to disappear into the user's writing flow.
- Every background behavior is visible, reversible, and configurable.
- Hardware-aware model choices instead of a single oversized default.
- Simple core dictation first; advanced modes never get in the way.

## Phase 1 — Reliability and everyday polish

- [x] Customizable hold/toggle trigger
- [x] Hardware-aware local model picker and downloader
- [x] Stable local code signing for persistent permissions
- [x] Silence system output during recording and restore its exact prior state
- [ ] Escape-to-cancel with no clipboard or transcription side effects
- [ ] Direct Accessibility text insertion with clipboard fallback
- [ ] Microphone picker, input-level meter, and permission diagnostics
- [ ] Launch at login
- [ ] Personal dictionary and text replacements for names and jargon

## Phase 2 — Near-instant dictation

- [ ] Streaming ASR with live partial text
- [ ] Notch-aware and standard overlay layouts
- [ ] Voice activity detection and automatic end-of-utterance handling
- [ ] Prewarm selected models and report memory/latency costs
- [ ] Hardware benchmarks and automatic model recommendations
- [ ] Confidence-aware retry with a second local model for difficult utterances

## Phase 3 — Context and local intelligence

- [ ] Optional local cleanup for punctuation, capitalization, filler words, and formatting
- [ ] Per-app profiles for tone, formatting, vocabulary, and insertion behavior
- [ ] Write/rewrite mode for selected text
- [ ] Voice command mode for approved Shortcuts and app actions
- [ ] Local searchable history with configurable retention, audio opt-in, and one-click deletion
- [ ] Usage and latency statistics stored only on-device

## Phase 4 — Kiki-only differentiators

- [ ] Audio Protection modes: mute, duck, or pause/resume compatible media apps
- [ ] Private style memory that learns corrections locally and can be reset or exported
- [ ] Adaptive formatting based on destination type: chat, email, document, code, or terminal
- [ ] “Fast first, accurate second” mode that inserts immediately and offers a non-disruptive correction
- [ ] Voice macros with a visible preview and confirmation for destructive actions
- [ ] Local automation API and Shortcuts actions
- [ ] Optional meeting/file transcription workspace kept separate from quick dictation

## Distribution

- [x] Developer ID-ready signing, notarization, stapling, and release packaging
- [ ] First notarized Apple Silicon GitHub Release
- [ ] Intel or universal build with Whisper-compatible model choices
- [ ] Automatic updates with stable and beta channels
- [ ] Repeatable release CI without committing signing credentials
