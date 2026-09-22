# Kiki 0.6.66

- Keep the live meeting preview bounded to the latest 12 seconds, replacing stale pending previews instead of repeatedly processing the growing recording. The complete recording still feeds final transcription.
- Stop preview inference before beginning final meeting transcription.
- Prefer pauses near final-transcription chunk boundaries while retaining every audio sample exactly once.
- Clearly label the recent-speech preview. These changes do not add cloud processing or change audio-retention preferences.
