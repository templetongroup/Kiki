# Kiki 0.6.34

- Smoothed long Voice Studio output across generated sections so volume and transitions remain consistent.
- Added gentle edge cleanup, crossfades, and loudness matching without sending audio off the Mac.
- Added checksum verification for Whisper and Kiki's local voice models.
- Kiki now removes and repairs a corrupted model automatically instead of trying to load it or silently accepting it.
- Clarified whether Voice Studio is verifying, downloading, repairing, or generating.
